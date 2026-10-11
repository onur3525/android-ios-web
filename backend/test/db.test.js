// Veritabanı katmanı: yer tutucu çevirisi ve SQLite ↔ PostgreSQL şema eşdeğerliği.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { gocDosyalari, yerTutucuCevir } from '../src/db.js';

test('? → $n çevirisi tırnak içine dokunmaz', () => {
  assert.equal(
    yerTutucuCevir("SELECT * FROM t WHERE a = ? AND b = '?' AND c = ?"),
    "SELECT * FROM t WHERE a = $1 AND b = '?' AND c = $2",
  );
});

// Her iki göç klasöründe AYNI dosyalar ve her tabloda AYNI sütunlar
// olmalı: SQLite'tan PostgreSQL'e geçiş sürpriz çıkarmasın.
function tablolar(sql) {
  const out = new Map();
  const re = /CREATE TABLE (\w+) \(([\s\S]*?)\n\s*\);/g;
  let m;
  while ((m = re.exec(sql))) {
    const sutunlar = m[2]
      .split('\n')
      .map((l) => l.trim())
      .flatMap((l) => l.split(/,\s*(?=[a-z_]+ [A-Z])/))
      .map((l) => /^([a-z_]+)\s+[A-Z]/.exec(l.trim())?.[1])
      .filter((x) => x && !['UNIQUE', 'PRIMARY', 'CHECK'].includes(x));
    out.set(m[1], new Set(sutunlar));
  }
  return out;
}

test('SQLite ve PostgreSQL göçleri birebir eşdeğer', () => {
  const s = gocDosyalari('sqlite');
  const p = gocDosyalari('postgres');
  assert.deepEqual(s.map((g) => g.id), p.map((g) => g.id), 'göç numaraları aynı olmalı');
  for (let i = 0; i < s.length; i++) {
    const ts = tablolar(s[i].sql);
    const tp = tablolar(p[i].sql);
    assert.deepEqual([...ts.keys()].sort(), [...tp.keys()].sort(), `${s[i].id}: tablolar`);
    for (const [ad, sutun] of ts) {
      assert.deepEqual([...sutun].sort(), [...tp.get(ad)].sort(), `${s[i].id}: ${ad} sütunları`);
    }
  }
});

// ═════ PostgreSQL KAPANIŞI — LISTEN bağlantısı havuzu kilitlemez ═════
//
// ⚠ GERÇEK PostgreSQL DEĞİL: sahte havuz, `pg.Pool#end()`ün davranışını
// taklit eder — dışarıda tutulan bağlantılar dönmeden end() TAMAMLANMAZ;
// end() iki kez çağrılırsa ve bağlantı iki kez bırakılırsa hata fırlatır.
// CI'da PostgreSQL adımı, olaylar.kapat() unutulan dosyanın kapanışında
// sonsuza kadar takılıyordu; bu testler o sınıfı sürücü katmanında kilitler.
function sahtePgKur({ baglantiGecikmesi } = {}) {
  class SahteIstemci {
    constructor(h) { this.h = h; this.serbest = false; this.yokEdildi = false; }
    async query() { return { rows: [], rowCount: 0 }; }
    release(hata) {
      if (this.serbest) throw new Error('Release called on client which has already been released to the pool.');
      this.serbest = true;
      this.yokEdildi = Boolean(hata);
      this.h.disarida.delete(this);
      this.h.kontrol();
    }
  }
  class SahteHavuz {
    constructor() { this.disarida = new Set(); this.endSayisi = 0; this.bitir = null; }
    async connect() {
      if (baglantiGecikmesi) await baglantiGecikmesi();
      const c = new SahteIstemci(this);
      this.disarida.add(c);
      return c;
    }
    async query() { return { rows: [], rowCount: 0 }; }
    on() {}
    end() {
      this.endSayisi += 1;
      if (this.endSayisi > 1) return Promise.reject(new Error('Called end on pool more than once'));
      return new Promise((ok) => { this.bitir = ok; this.kontrol(); });
    }
    kontrol() { if (this.bitir && this.disarida.size === 0) this.bitir(); }
  }
  return { Pool: SahteHavuz, types: { setTypeParser() {} } };
}

// Takılırsa test SONSUZA KADAR beklemesin, anlamlı biçimde düşsün.
// Zamanlayıcı bilerek `unref` EDİLMEZ (bekleyen tek şey bir söz olduğunda
// olay döngüsü boşalıp testi iptal ettirirdi); sonuç gelince temizlenir.
async function sureyleBitir(p, ms = 1000) {
  let zaman;
  const sinir = new Promise((ok) => { zaman = setTimeout(() => ok('takıldı'), ms); });
  try {
    return await Promise.race([p.then(() => 'bitti'), sinir]);
  } finally {
    clearTimeout(zaman);
  }
}

test('PostgreSQL close(): açık LISTEN bağlantısı sonlandırılır, havuz kapanır (olaylar.kapat unutulsa da)', async () => {
  const { PostgresDbSinif } = await import('../src/db.js');
  const pdb = new PostgresDbSinif(sahtePgKur(), 'postgres://x', { havuz: 2 });
  const dinleyici = await pdb.dinleyiciAc();
  assert.equal(await sureyleBitir(pdb.close()), 'bitti', 'kapanış LISTEN bağlantısını bekleyip takıldı');
  assert.equal(dinleyici.yokEdildi, true, 'LISTEN bağlantısı havuza geri konmamalı, sonlandırılmalı');
  assert.equal(pdb.havuz.endSayisi, 1);
});

test('PostgreSQL close(): önce olaylar.kapat() benzeri bırakma, sonra close() — çift bırakma hatası yok', async () => {
  const { PostgresDbSinif } = await import('../src/db.js');
  const pdb = new PostgresDbSinif(sahtePgKur(), 'postgres://x', { havuz: 2 });
  const dinleyici = await pdb.dinleyiciAc();
  dinleyici.release(true); // olaylar.kapat()
  dinleyici.release(true); // ikinci bırakma yok sayılır
  assert.equal(await sureyleBitir(pdb.close()), 'bitti');
  assert.equal(pdb.dinleyiciler.size, 0);
});

test('PostgreSQL close(): iki kez çağrılabilir; havuz bir kez kapanır', async () => {
  const { PostgresDbSinif } = await import('../src/db.js');
  const pdb = new PostgresDbSinif(sahtePgKur(), 'postgres://x', { havuz: 2 });
  await pdb.dinleyiciAc();
  const [a, b] = [pdb.close(), pdb.close()];
  assert.equal(a, b, 'ikinci çağrı aynı kapanışı beklemeli');
  assert.equal(await sureyleBitir(Promise.all([a, b])), 'bitti');
  await pdb.close();
  assert.equal(pdb.havuz.endSayisi, 1, 'havuz birden fazla kez kapatıldı');
});

test('PostgreSQL close(): kapanış başladıktan sonra yeni dinleyici verilmez; yolda olan bağlantı sonlandırılır', async () => {
  const { PostgresDbSinif } = await import('../src/db.js');
  let kapi;
  const bekle = new Promise((ok) => { kapi = ok; });
  const pg = sahtePgKur({ baglantiGecikmesi: () => bekle });
  const pdb = new PostgresDbSinif(pg, 'postgres://x', { havuz: 2 });
  const yolda = pdb.dinleyiciAc(); // bağlantı alınırken…
  const kapanis = pdb.close(); // …kapanış başlar
  kapi();
  await assert.rejects(yolda, /kapanıyor/);
  assert.equal(await sureyleBitir(kapanis), 'bitti', 'yolda kalan bağlantı havuzu kilitledi');
  await assert.rejects(pdb.dinleyiciAc(), /kapanıyor/);
});

test('PostgreSQL close(): normal sorgu bağlantısı SONLANDIRILMAZ; işlem bitince havuz kapanır', async () => {
  const { PostgresDbSinif } = await import('../src/db.js');
  const pdb = new PostgresDbSinif(sahtePgKur(), 'postgres://x', { havuz: 2 });
  let islemIstemcisi;
  let devam;
  const islem = pdb.tx(async () => {
    islemIstemcisi = pdb.als.getStore();
    await new Promise((ok) => { devam = ok; });
  });
  await new Promise((ok) => setImmediate(ok));
  const kapanis = pdb.close();
  assert.equal(await sureyleBitir(kapanis, 50), 'takıldı', 'süren işlem beklenmeden havuz kapandı');
  devam();
  await islem;
  assert.equal(await sureyleBitir(kapanis), 'bitti');
  assert.equal(islemIstemcisi.yokEdildi, false, 'normal bağlantı sonlandırılmamalı, havuza dönmeli');
});
