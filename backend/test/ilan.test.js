// Uçtan uca: ilan → teklif → seçim → iletişim → değerlendirme; süre dolumu;
// admin ilan/yorum kaldırma (gerekçe + bildirim + denetim); duyuru.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { veritabaniAc, simdi } = await import('../src/db.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { suresiDolanlariIsle } = await import('../src/routes/ilan.js');

let db, sunucu, taban, adminCerez, hizmet, musteri, usta, usta2;

async function istek(yol, { yontem = 'GET', govde, token, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(yol.startsWith('/admin/') ? { Cookie: adminCerez, 'X-HC-Admin': '1' } : {}),
      ...basliklar,
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

async function kullaniciOlustur(tel, rol) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', {
    yontem: 'POST',
    govde: { phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp },
  });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, id: me.json.id };
}

before(async () => {
  db = process.env.HC_TEST_DB === 'postgres'
    ? await veritabaniAc({ surucu: 'postgres', url: process.env.HC_DATABASE_URL, ssl: false })
    : await veritabaniAc({ surucu: 'sqlite', yol: ':memory:' });
  await tohumla(db);
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
    .run(randomUUID(), 'sa@hc.test', 'SA', sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const a = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'sa@hc.test', password: 'GucluSifre12345' }) });
  adminCerez = a.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: adminCerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  hizmet = (await db.prepare('SELECT name FROM services LIMIT 1').get()).name;
  musteri = await kullaniciOlustur('5300000001', 'CUSTOMER');
  usta = await kullaniciOlustur('5300000002', 'PROVIDER');
  usta2 = await kullaniciOlustur('5300000003', 'PROVIDER');
});
after(async () => {
  sunucu.close();
  await db.close();
});

let ilan, teklif;

test('ilan: yalnız hizmet alan, katalogdaki hizmetle; numara 10458231\'den başlar', async () => {
  assert.equal((await istek('/api/v1/listings', { yontem: 'POST', token: usta.token, govde: { title: hizmet, location: 'Karşıyaka', description: 'acil usta lazım bugün' } })).durum, 403);
  assert.equal((await istek('/api/v1/listings', { yontem: 'POST', token: musteri.token, govde: { title: 'Uydurma İş', location: 'Karşıyaka', description: 'acil usta lazım bugün' } })).durum, 400);
  assert.equal((await istek('/api/v1/listings', { yontem: 'POST', token: musteri.token, govde: { title: hizmet, location: 'Karşıyaka', description: 'kısa' } })).durum, 400);
  const r = await istek('/api/v1/listings', { yontem: 'POST', token: musteri.token, govde: { title: hizmet, location: 'Karşıyaka, İmbatlı', description: 'acil usta lazım bugün', workTiming: 'NOW' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.ilanNo, '10458231');
  assert.equal(r.json.status, 'ACTIVE');
  assert.equal(Date.parse(r.json.expiresAt) - Date.parse(r.json.createdAt), 30 * 3600 * 1000);
  ilan = r.json;
});

test('teklif kuralları: kendi ilanı yok, tekrar yok, idempotent', async () => {
  const anahtar = randomUUID();
  const t = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, basliklar: { 'Idempotency-Key': anahtar }, govde: { listingId: ilan.id, amountTl: 1500, note: 'Yarın gelebilirim' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  const ayni = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, basliklar: { 'Idempotency-Key': anahtar }, govde: { listingId: ilan.id, amountTl: 1500, note: 'Yarın gelebilirim' } });
  assert.equal(ayni.json.id, t.json.id, 'aynı anahtar aynı teklifi döner');
  const tekrar = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: ilan.id, amountTl: 1200, note: '' } });
  assert.equal(tekrar.json.error.code, 'DUPLICATE_OFFER');
  await istek('/api/v1/offers', { yontem: 'POST', token: usta2.token, govde: { listingId: ilan.id, amountTl: 1800, note: '' } });
  teklif = t.json;
  const bildirim = await istek('/api/v1/notifications/unread-count', { token: musteri.token });
  assert.equal(bildirim.json.count, 2);
});

test('iletişim: yalnız taraflar; ücretsiz açılır; karşı tarafa bildirim', async () => {
  assert.equal((await istek(`/api/v1/contact/${teklif.id}`, { token: usta2.token })).durum, 404, 'üçüncü kişi göremez');
  const kapali = await istek(`/api/v1/contact/${teklif.id}`, { token: musteri.token });
  assert.equal(kapali.json.contactOpenAt, null);
  assert.equal(kapali.json.open, undefined, 'istemci "open" anahtarını açık sanmasın');
  const ac = await istek(`/api/v1/offers/${teklif.id}/communication`, { yontem: 'POST', token: musteri.token });
  assert.equal(ac.json.open, true);
  const durum = await istek(`/api/v1/contact/${teklif.id}`, { token: usta.token });
  assert.equal(durum.json.counterpart.phone, '5300000001');
});

test('seçim: yalnız sahip; diğer teklifler kapanır; değerlendirme bir kez', async () => {
  assert.equal((await istek(`/api/v1/listings/${ilan.id}/selected-offer`, { yontem: 'PUT', token: usta.token, govde: { offerId: teklif.id } })).durum, 403);
  const s = await istek(`/api/v1/listings/${ilan.id}/selected-offer`, { yontem: 'PUT', token: musteri.token, govde: { offerId: teklif.id } });
  assert.equal(s.json.selectedOfferId, teklif.id);
  const usta2Teklif = (await istek('/api/v1/offers/my', { token: usta2.token })).json[0];
  assert.equal(usta2Teklif.status, 'CLOSED');
  const y = await istek(`/api/v1/listings/${ilan.id}/review`, { yontem: 'POST', token: musteri.token, govde: { stars: 5, text: 'Çok memnun kaldım' } });
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  assert.equal((await istek(`/api/v1/listings/${ilan.id}/review`, { yontem: 'POST', token: musteri.token, govde: { stars: 4, text: 'tekrar' } })).durum, 409);
  const liste = await istek(`/api/v1/providers/${usta.id}/reviews`, { token: usta2.token });
  assert.equal(liste.json.average, 5);
});

test('süre dolumu: 30 saat sonra kapanır, teklif verilemez, sahibine bir kez bildirim', async () => {
  const r = await istek('/api/v1/listings', { yontem: 'POST', token: musteri.token, govde: { title: hizmet, location: 'Bornova', description: 'boya badana işi var' } });
  await db.prepare('UPDATE listings SET expires_at = ? WHERE id = ?').run('2000-01-01T00:00:00.000Z', r.json.id);
  await suresiDolanlariIsle(db);
  await suresiDolanlariIsle(db);
  const t = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: r.json.id, amountTl: 900, note: '' } });
  assert.equal(t.json.error.code, 'LISTING_EXPIRED');
  const b = (await istek('/api/v1/notifications', { token: musteri.token })).json.filter((n) => n.type === 'LISTING_EXPIRED');
  assert.equal(b.length, 1);
});

test('admin ilan kaldırma: gerekçe zorunlu, ADMIN_REMOVED, SMS kaydı, denetim', async () => {
  const r = await istek('/api/v1/listings', { yontem: 'POST', token: musteri.token, govde: { title: hizmet, location: 'Konak', description: 'uygunsuz içerikli ilan metni' } });
  assert.equal((await istek(`/admin/v1/listings/${r.json.id}/remove`, { yontem: 'POST', govde: {} })).durum, 400);
  const k = await istek(`/admin/v1/listings/${r.json.id}/remove`, { yontem: 'POST', govde: { reason: 'Kullanım koşullarına aykırı içerik' } });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  assert.equal((await istek(`/api/v1/listings/${r.json.id}`, { token: musteri.token })).json.status, 'ADMIN_REMOVED');
  const sms = await db.prepare(`SELECT * FROM outbound_messages WHERE template = 'ILAN_KALDIRILDI' AND channel = 'SMS'`).get();
  assert.equal(sms.status, 'SENT');
  assert.match(sms.body, /Kullanım koşullarına aykırı içerik/);
  assert.match(sms.body, new RegExp(r.json.ilanNo));
  const kayit = await db.prepare(`SELECT * FROM audit_log WHERE action = 'listing.remove'`).get();
  assert.equal(kayit.reason, 'Kullanım koşullarına aykırı içerik');
});

test('admin yorum kaldırma → kullanıcı listesinden düşer; duyuru herkese gider', async () => {
  const y = (await istek('/admin/v1/reviews')).json[0];
  assert.equal((await istek(`/admin/v1/reviews/${y.id}/remove`, { yontem: 'POST', govde: { reason: 'Kişisel veri içeriyor' } })).durum, 200);
  assert.equal((await istek(`/api/v1/providers/${usta.id}/reviews`, { token: musteri.token })).json.reviews.length, 0);
  const d = await istek('/admin/v1/announcements', { yontem: 'POST', govde: { title: 'Bakım', body: 'Pazar gecesi kısa bir bakım yapılacak.', target: 'PROVIDER' } });
  assert.equal(d.json.recipients, 2);
  const b = (await istek('/api/v1/notifications', { token: usta.token })).json.find((n) => n.type === 'ANNOUNCEMENT');
  assert.equal(b.title, 'Bakım');
});
