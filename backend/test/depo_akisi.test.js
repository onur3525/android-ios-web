// Depodan akış (28 Eki): fotoğraf/PDF belleğe alınmadan akıtılır; depo
// koparsa, yanıt vermezse ya da istemci vazgeçerse SÜREÇ DÜŞMEZ.
// Önceden: `return fotoGonder(...)` (await yok) + tam indirme → tek yavaş
// indirme işlenmemiş hatayla süreci kapatıyordu.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';

const BUYUK = Buffer.alloc(3 * 1024 * 1024, 7); BUYUK.set([0xff, 0xd8, 0xff, 0xe0]);
let kip = 'normal'; // normal | kopar | baslikBekle | govdeBekle | yavas | turKotu
let depoKapandi = 0;
const depo = createServer((req, res) => {
  req.socket.on('close', () => { depoKapandi += 1; });
  if (kip === 'baslikBekle') return; // hiç yanıt yok
  const tur = kip === 'turKotu' ? 'text/html' : (req.url.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg');
  res.writeHead(200, { 'Content-Type': tur, 'Content-Length': BUYUK.length });
  if (kip === 'kopar') { res.write(BUYUK.subarray(0, 64 * 1024)); setTimeout(() => res.destroy(), 30); return; }
  if (kip === 'govdeBekle') { res.write(BUYUK.subarray(0, 1024)); return; } // gerisi hiç gelmez
  if (kip === 'yavas') {
    let i = 0;
    const t = setInterval(() => {
      if (res.destroyed) return clearInterval(t);
      const p = BUYUK.subarray(i, i + 256 * 1024); i += p.length;
      if (!p.length) { clearInterval(t); return res.end(); }
      res.write(p);
    }, 20);
    return;
  }
  res.end(BUYUK);
});
await new Promise((ok) => depo.listen(0, ok));
process.env.HC_S3_ENDPOINT = `http://127.0.0.1:${depo.address().port}`;
process.env.HC_S3_BUCKET = 'hc';
process.env.HC_S3_PATH_STYLE = 'true';
process.env.HC_S3_ACCESS_KEY_ID = 'TESTANAHTAR123';
process.env.HC_S3_SECRET_ACCESS_KEY = 'testgizlianahtar-yalnizca-test';
process.env.HC_SESSIZ = '1';

const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { depodanAkit } = await import('../src/depo_akisi.js');
const { depolamaAyari } = await import('../src/entegrasyon.js');

const FOTO = 'katalog/kategori/11111111-2222-3333-4444-555555555555.jpg';
let db, sunucu, taban;

before(async () => {
  db = await testDb();
  await tohumla(db);
  const cati = await db.prepare('SELECT key FROM catalog_roofs ORDER BY sort LIMIT 1').get();
  await db.prepare('UPDATE catalog_roofs SET photo_ref = ? WHERE key = ?').run(FOTO, cati.key);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
// Açık bağlantılar (yarıda bırakılan akışlar) dosyanın kapanmasını engellemesin.
after(async () => {
  sunucu?.closeAllConnections(); sunucu?.close();
  depo.closeAllConnections(); depo.close();
  await db?.close();
});

const ayakta = async () => (await fetch(`${taban}/api/v1/legal/support`)).status === 200;

// Canlıda işlenmemiş söz hatası SÜRECİ kapatır; test sürecinde ise
// yalnız raporlanır. Bu yüzden ayrıca sayılır ve sıfır olması istenir.
const islenmemis = [];
process.on('unhandledRejection', (e) => islenmemis.push(e));

test('normal: içerik birebir akıtılır; başlıklar korunur', async () => {
  kip = 'normal';
  const r = await fetch(`${taban}/api/v1/categories/photo/${FOTO}`);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get('content-type'), 'image/jpeg');
  assert.equal(r.headers.get('cache-control'), 'public, max-age=31536000, immutable');
  assert.equal(r.headers.get('content-length'), String(BUYUK.length));
  assert.ok(Buffer.from(await r.arrayBuffer()).equals(BUYUK));
});

test('izin dışı içerik türü önceki gibi application/octet-stream', async () => {
  kip = 'turKotu';
  const r = await fetch(`${taban}/api/v1/categories/photo/${FOTO}`);
  assert.equal(r.headers.get('content-type'), 'application/octet-stream');
  await r.arrayBuffer();
});

test('depo indirmenin ortasında koparsa süreç DÜŞMEZ', async () => {
  kip = 'kopar';
  const once = islenmemis.length;
  await assert.rejects(async () => {
    const r = await fetch(`${taban}/api/v1/categories/photo/${FOTO}`, { signal: AbortSignal.timeout(5000) });
    await r.arrayBuffer();
  });
  await new Promise((ok) => setTimeout(ok, 100));
  assert.equal(islenmemis.length - once, 0, 'işlenmemiş hata canlıda süreci kapatırdı');
  assert.ok(await ayakta(), 'sunucu yanıt vermeye devam etmeli');
});

test('yavaş ama akan depo: tamamı gelir (toplam süre sınırı yok)', async () => {
  kip = 'yavas';
  const r = await fetch(`${taban}/api/v1/categories/photo/${FOTO}`);
  assert.ok(Buffer.from(await r.arrayBuffer()).equals(BUYUK));
});

test('istemci yarıda vazgeçerse depo bağlantısı da kapanır; süreç düşmez', async () => {
  kip = 'yavas';
  const once = depoKapandi;
  await new Promise((ok) => {
    const q = request(`${taban}/api/v1/categories/photo/${FOTO}`, (r) => {
      r.once('data', () => { q.destroy(); setTimeout(ok, 300); });
    });
    q.on('error', () => {});
    q.end();
  });
  assert.ok(depoKapandi > once, 'depodan okuma iptal edilmeli');
  assert.ok(await ayakta());
});

// Kısa zaman aşımlarıyla doğrudan yardımcı (uç noktadaki 10/20 sn ve 30 sn yerine).
async function yardimciyla(kipAdi, secenek) {
  kip = kipAdi;
  const ayar = await depolamaAyari(db);
  let sonuc;
  const s = createServer(async (_q, res) => {
    sonuc = await depodanAkit(ayar, FOTO, res, () => ({ 'Content-Type': 'image/jpeg' }), secenek);
    if (!sonuc) { res.writeHead(404); res.end(); }
  });
  await new Promise((ok) => s.listen(0, ok));
  let durum = null; let hata = null;
  try {
    const r = await fetch(`http://127.0.0.1:${s.address().port}/`);
    durum = r.status;
    await r.arrayBuffer();
  } catch (e) { hata = e; }
  s.close();
  return { sonuc, durum, hata };
}

test('depo başlık süresinde yanıt vermezse 404 (yanıt yazılmaz)', async () => {
  const { sonuc, durum } = await yardimciyla('baslikBekle', { baslikMs: 200, bostaMs: 5000 });
  assert.equal(sonuc, false);
  assert.equal(durum, 404);
});

test('içerik başlayıp durursa boşta süresinde kesilir; hata fırlatılmaz', async () => {
  const { sonuc, durum, hata } = await yardimciyla('govdeBekle', { baslikMs: 2000, bostaMs: 200 });
  assert.equal(sonuc, true);
  assert.equal(durum, 200);
  assert.ok(hata, 'istemci yarıda kesilen yanıtı hata olarak görür');
  assert.ok(await ayakta());
});

test('hiçbir senaryoda işlenmemiş hata kalmadı', () => {
  assert.deepEqual(islenmemis.map((e) => String(e?.message ?? e)), []);
});

test('server.js: ham yanıt yazan yardımcılar await ile çağrılır; güvenlik ağı var', async () => {
  const { readFile } = await import('node:fs/promises');
  const k = await readFile(new URL('../src/server.js', import.meta.url), 'utf8');
  for (const ad of ['fotoGonder', 'pdfGonder', 'varlikGonder', 'epostaVarligiGonder']) {
    assert.equal(new RegExp(`return ${ad}\\(`).test(k), false, `${ad} await'siz dönmemeli`);
  }
  assert.ok(k.includes('return uygulama(req, res).catch('));
});
