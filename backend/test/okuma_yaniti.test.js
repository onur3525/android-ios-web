// OKUMA YANITI (28 Eki, telefon performansı): kullanıcı API'sinin GET
// yanıtları gzip ile sıkıştırılır ve ETag taşır; değişmediyse gövdesiz 304.
// Fotoğraf adresleri 15 dakikalık kovada aynı kalır (yoksa fotoğraflı ilan
// listesi her yanıtta "değişmiş" görünür, 304 hiç işlemezdi).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';
import { gunzipSync } from 'node:zlib';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
process.env.HC_CORS_ORIGINS = 'https://onur3525.github.io';
Object.assign(process.env, {
  HC_S3_ENDPOINT: 'https://s3.example', HC_S3_BUCKET: 'kova',
  HC_S3_ACCESS_KEY_ID: 'yalniz-test', HC_S3_SECRET_ACCESS_KEY: 'yalniz-test-gizli', HC_S3_PATH_STYLE: 'true',
});

const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { IMZA_KOVASI_SN, imzaZamani } = await import('../src/gorsel_adresleri.js');

let db, sunucu, port, token, kullaniciId;

/** Ham HTTP isteği: sıkıştırılmış gövde ve başlıklar olduğu gibi görülür. */
function ham(yol, { yontem = 'GET', baslik = {}, govde } = {}) {
  return new Promise((ok, red) => {
    const r = request({ host: '127.0.0.1', port, path: yol, method: yontem, headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...baslik,
    } }, (y) => {
      const p = [];
      y.on('data', (c) => p.push(c));
      y.on('end', () => ok({ durum: y.statusCode, baslik: y.headers, govde: Buffer.concat(p) }));
    });
    r.on('error', red);
    r.end(govde ? JSON.stringify(govde) : undefined);
  });
}
const coz = (y) => JSON.parse((y.baslik['content-encoding'] === 'gzip' ? gunzipSync(y.govde) : y.govde).toString('utf8'));

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  port = sunucu.address().port;
  const tel = '5357770091';
  assert.equal((await ham('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } })).durum, 204);
  const k = await ham('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Okuma Deneme', email: 'okuma@ornek.com', role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(k.durum, 200);
  token = coz(k).accessToken;
  kullaniciId = coz(await ham('/api/v1/users/me')).id;
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('büyük GET yanıtı gzip ile gelir; içerik aynı; Vary Accept-Encoding', async () => {
  const duz = await ham('/api/v1/categories');
  const sik = await ham('/api/v1/categories', { baslik: { 'Accept-Encoding': 'gzip, deflate, br' } });
  assert.equal(duz.durum, 200);
  assert.equal(sik.durum, 200);
  assert.equal(duz.baslik['content-encoding'], undefined, 'kabul etmeyen istemciye sıkıştırma yok');
  assert.equal(sik.baslik['content-encoding'], 'gzip');
  assert.ok(sik.govde.length < duz.govde.length / 2, `sıkıştırma etkisiz: ${sik.govde.length} / ${duz.govde.length}`);
  assert.deepEqual(coz(sik), coz(duz));
  assert.match(sik.baslik.vary, /Accept-Encoding/);
  assert.equal(sik.baslik['cache-control'], 'no-store', 'güvenlik başlıkları korunur');
  assert.equal(sik.baslik.etag, duz.baslik.etag, 'özet sıkıştırmadan bağımsız');
});

test('aynı özetle istenen değişmemiş yanıt gövdesiz 304; veri değişince yeni özet', async () => {
  const ilk = await ham('/api/v1/listings/my');
  assert.equal(ilk.durum, 200);
  const etiket = ilk.baslik.etag;
  assert.match(etiket, /^W\/"[A-Za-z0-9_-]+"$/);
  const ayni = await ham('/api/v1/listings/my', { baslik: { 'If-None-Match': etiket } });
  assert.equal(ayni.durum, 304);
  assert.equal(ayni.govde.length, 0);
  assert.equal(ayni.baslik.etag, etiket);
  const l = await ham('/api/v1/listings', { yontem: 'POST', govde: { title: (await db.prepare('SELECT name FROM services WHERE deleted_at IS NULL LIMIT 1').get()).name, location: 'Bornova', description: 'iki oda boyanacak deneme' } });
  assert.ok(l.durum < 300, l.govde.toString());
  const yeni = await ham('/api/v1/listings/my', { baslik: { 'If-None-Match': etiket } });
  assert.equal(yeni.durum, 200, 'değişen veri yeniden gönderilmeli');
  assert.notEqual(yeni.baslik.etag, etiket);
  assert.equal(coz(yeni).length, coz(ilk).length + 1);
});

test('GET dışı yanıtlar sıkıştırılmaz ve özet taşımaz', async () => {
  const r = await ham('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5357770092', purpose: 'REGISTER' }, baslik: { 'Accept-Encoding': 'gzip' } });
  assert.equal(r.baslik.etag, undefined);
  assert.equal(r.baslik['content-encoding'], undefined);
});

test('CORS: web istemcisi If-None-Match gönderebilir ve ETag okuyabilir', async () => {
  const on = await ham('/api/v1/categories', { yontem: 'OPTIONS', baslik: { Origin: 'https://onur3525.github.io', 'Access-Control-Request-Method': 'GET' } });
  assert.equal(on.baslik['access-control-allow-origin'], 'https://onur3525.github.io');
  assert.match(on.baslik['access-control-allow-headers'], /If-None-Match/);
  const r = await ham('/api/v1/categories', { baslik: { Origin: 'https://onur3525.github.io' } });
  assert.equal(r.baslik['access-control-expose-headers'], 'ETag');
  assert.equal(r.baslik.vary, 'Origin, Accept-Encoding', 'köken ve sıkıştırma birlikte');
});

test('fotoğraflı ilan listesi aynı 15 dakika içinde birebir aynı (304 çalışır)', async () => {
  const ref = `u/${kullaniciId}/${randomUUID()}.jpg`;
  await db.prepare(`INSERT INTO storage_objects (ref, owner_id, kind, content_type, size_bytes, status, created_at) VALUES (?, ?, 'listing-photo', 'image/jpeg', 100, 'ATTACHED', ?)`)
    .run(ref, kullaniciId, simdi());
  await db.prepare(`INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, status, created_at, expires_at, updated_at)
    VALUES (?, ?, ?, 'Fotoğraflı', 'Bornova', 'fotoğraflı deneme ilanı', ?, 'ACTIVE', ?, ?, ?)`)
    .run(randomUUID(), '8800091', kullaniciId, JSON.stringify([ref]), simdi(), new Date(Date.now() + 86_400_000).toISOString(), simdi());
  // Kova sınırına yakınsak bekle (testin kova değişiminde yanlış sonuç vermemesi için).
  const kalan = IMZA_KOVASI_SN * 1000 - (Date.now() % (IMZA_KOVASI_SN * 1000));
  if (kalan < 3000) await new Promise((ok) => setTimeout(ok, kalan + 50));
  const a = await ham('/api/v1/listings/my');
  await new Promise((ok) => setTimeout(ok, 1100)); // eskiden saniye değişince imza değişirdi
  const b = await ham('/api/v1/listings/my', { baslik: { 'If-None-Match': a.baslik.etag } });
  assert.match(coz(a).find((x) => x.ilanNo === '8800091').photoUrls[0], /X-Amz-Signature=/);
  assert.equal(b.durum, 304, 'fotoğraflı liste değişmediği hâlde yeniden gönderildi');
});

test('imza zamanı kova başına yuvarlanır; verilen adresin en az 45 dk ömrü kalır', () => {
  const kova = IMZA_KOVASI_SN * 1000;
  const t = Date.UTC(2026, 9, 28, 10, 7, 31);
  assert.equal(imzaZamani(t).getTime(), Date.UTC(2026, 9, 28, 10, 0, 0));
  assert.equal(imzaZamani(t + 1000).getTime(), imzaZamani(t).getTime());
  assert.equal(imzaZamani(Date.UTC(2026, 9, 28, 10, 15, 0)).getTime() % kova, 0);
  assert.ok(3600 - IMZA_KOVASI_SN >= 45 * 60);
});
