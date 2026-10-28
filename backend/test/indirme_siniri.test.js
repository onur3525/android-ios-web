// İNDİRME SINIRI (28 Eki): fotoğraf/PDF/varlık uçları — eşzamanlılık sırası,
// dakika sınırı, 429 + Retry-After, bağlantı kapanınca sıradan çıkış.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { createServer } from 'node:http';
import { indirmeSiniriKur } from '../src/indirme_siniri.js';

const bekle = (ms) => new Promise((ok) => setTimeout(ok, ms));

test('IP başına eşzamanlı sınır: fazlası REDDEDİLMEZ, sıra bekler; bitince devam eder', async () => {
  const s = indirmeSiniriKur({ ipEsz: 2, toplamEsz: 10, ipDakika: 100, beklemeMs: 2000 });
  const a = await s.al('1.1.1.1');
  const b = await s.al('1.1.1.1');
  assert.ok(a.ok && b.ok);
  let ucuncu = null;
  const p = s.al('1.1.1.1').then((v) => { ucuncu = v; });
  await bekle(20);
  assert.equal(ucuncu, null, 'üçüncü sırada bekler');
  // Başka IP etkilenmez.
  const baska = await s.al('2.2.2.2');
  assert.ok(baska.ok);
  a.birak();
  await p;
  assert.ok(ucuncu.ok, 'yer açılınca başlar');
  a.birak(); // ikinci kez bırakmak sayacı bozmaz
  b.birak(); ucuncu.birak(); baska.birak();
  assert.equal(s.durum().toplamAktif, 0);
});

test('genel eşzamanlı sınır tüm IP\'ler için geçerli', async () => {
  const s = indirmeSiniriKur({ ipEsz: 5, toplamEsz: 2, ipDakika: 100, beklemeMs: 2000 });
  const a = await s.al('1.0.0.1');
  const b = await s.al('1.0.0.2');
  let c = null;
  const p = s.al('1.0.0.3').then((v) => { c = v; });
  await bekle(20);
  assert.equal(c, null);
  b.birak();
  await p;
  assert.ok(c.ok);
  a.birak(); c.birak();
});

test('sırada bekleme süresi dolarsa 429 (Retry-After)', async () => {
  const s = indirmeSiniriKur({ ipEsz: 1, toplamEsz: 10, ipDakika: 100, beklemeMs: 50 });
  const a = await s.al('3.3.3.3');
  const r = await s.al('3.3.3.3');
  assert.equal(r.ok, false);
  assert.ok(r.sonraSn >= 1);
  assert.equal(s.durum().sira, 0);
  a.birak();
});

test('sıra dolu ise hemen 429', async () => {
  const s = indirmeSiniriKur({ ipEsz: 1, toplamEsz: 10, ipDakika: 100, beklemeMs: 5000, ipKuyruk: 2 });
  const a = await s.al('4.4.4.4');
  const k1 = s.al('4.4.4.4');
  const k2 = s.al('4.4.4.4');
  const r = await s.al('4.4.4.4');
  assert.equal(r.ok, false, 'IP sırası dolu');
  a.birak();
  const x = await k1; x.birak();
  const y = await k2; y.birak();
  assert.equal(s.durum().sira, 0);
});

test('dakika sınırı: aşan 429; yeni dakikada sıfırlanır', async () => {
  let t = 0;
  const s = indirmeSiniriKur({ ipEsz: 10, toplamEsz: 10, ipDakika: 3, simdi: () => t });
  for (let i = 0; i < 3; i += 1) (await s.al('5.5.5.5')).birak();
  const r = await s.al('5.5.5.5');
  assert.equal(r.ok, false);
  assert.ok(r.sonraSn >= 1 && r.sonraSn <= 60);
  assert.ok((await s.al('6.6.6.6')).ok, 'başka IP etkilenmez');
  t = 60_000;
  const y = await s.al('5.5.5.5');
  assert.ok(y.ok);
  y.birak();
});

test('istemci sırada beklerken bağlantıyı kaparsa sıradan çıkar, yer tutmaz', async () => {
  const s = indirmeSiniriKur({ ipEsz: 1, toplamEsz: 10, ipDakika: 100, beklemeMs: 5000 });
  const a = await s.al('7.7.7.7');
  const baglanti = new EventEmitter();
  const p = s.al('7.7.7.7', baglanti);
  await bekle(10);
  assert.equal(s.durum().sira, 1);
  baglanti.emit('close');
  const r = await p;
  assert.equal(r.ok, false);
  assert.equal(s.durum().sira, 0);
  a.birak();
  assert.equal(s.durum().toplamAktif, 0);
});

test('sunucu: katalog varlığı ucu dakika sınırını aşınca 429 + Retry-After; diğer uçlar etkilenmez', async () => {
  process.env.HC_TEST_OTP_KANCASI = '1';
  process.env.HC_SESSIZ = '1';
  const eski = process.env.HC_INDIRME_IP_DAKIKA;
  process.env.HC_INDIRME_IP_DAKIKA = '3';
  const { testDb } = await import('./destek.js');
  const { uygulamaKur } = await import('../src/server.js');
  const db = await testDb();
  const sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  const taban = `http://127.0.0.1:${sunucu.address().port}`;
  try {
    const yol = `${taban}/katalog-varlik/assets/categories/alci.jpg`;
    for (let i = 0; i < 3; i += 1) {
      const r = await fetch(yol);
      assert.equal(r.status, 200);
      await r.arrayBuffer();
    }
    const r = await fetch(yol);
    assert.equal(r.status, 429);
    assert.ok(Number(r.headers.get('retry-after')) >= 1);
    await r.text();
    const saglik = await fetch(`${taban}/api/v1/categories`);
    assert.equal(saglik.status, 200);
    await saglik.text();
    const eposta = await fetch(`${taban}/eposta-varlik/yok.png`);
    assert.equal(eposta.status, 404, 'e-posta görselleri sınırsız (404 = sınıra takılmadı)');
    await eposta.text();
  } finally {
    if (eski === undefined) delete process.env.HC_INDIRME_IP_DAKIKA; else process.env.HC_INDIRME_IP_DAKIKA = eski;
    sunucu.closeAllConnections?.(); sunucu.close(); await db.close();
  }
});

test('dakika payını yalnız başlayan indirmeler kullanır (reddedilen denemeler saymaz)', async () => {
  const s = indirmeSiniriKur({ ipEsz: 1, toplamEsz: 10, ipDakika: 3, beklemeMs: 5000, ipKuyruk: 1 });
  const a = await s.al('8.8.8.8');
  const kuyruk = s.al('8.8.8.8');
  for (let i = 0; i < 10; i += 1) assert.equal((await s.al('8.8.8.8')).ok, false, 'sıra dolu');
  a.birak();
  const b = await kuyruk;
  assert.ok(b.ok);
  b.birak();
  const c = await s.al('8.8.8.8');
  assert.ok(c.ok, '10 red payı tüketmedi: 3. indirme yapılabilir');
  c.birak();
  assert.equal((await s.al('8.8.8.8')).ok, false, '4. indirme dakika sınırında');
});
