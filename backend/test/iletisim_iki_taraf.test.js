// İLETİŞİM İKİ TARAF İÇİN DE AÇIK (29 Eki, kullanıcı isteği): kim açarsa
// açsın teklif görünümleri `contactOpen: true` taşır; karşı tarafın
// uygulaması da iletişimi kendiliğinden açık görür.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

let db, sunucu, taban, alan, usta, hiz;
async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, { method: yontem, headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol) {
  await db.prepare('DELETE FROM rate_limits').run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'sifre1234', name: 'Kişi', email: `i${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  return { token: r.json.accessToken, id: (await istek('/api/v1/users/me', { token: r.json.accessToken })).json.id };
}
async function teklifAc() {
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Konak', description: 'banyo bataryası değişecek' } });
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 500, note: '' } });
  return { ilan: l.json.id, teklif: o.json.id };
}
const ustaGorur = async (teklif) => (await istek('/api/v1/offers/my', { token: usta.token })).json.find((o) => o.id === teklif).contactOpen;
const alanGorur = async (ilan, teklif) => {
  const liste = (await istek('/api/v1/listings/my', { token: alan.token })).json.find((l) => l.id === ilan).offers.find((o) => o.id === teklif).contactOpen;
  const detay = (await istek(`/api/v1/listings/${ilan}`, { token: alan.token })).json.offers.find((o) => o.id === teklif).contactOpen;
  assert.equal(liste, detay, 'liste ve detay aynı');
  return liste;
};

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  hiz = (await db.prepare('SELECT name FROM services LIMIT 1').get()).name;
  alan = await kisi('5500000001', 'CUSTOMER');
  usta = await kisi('5500000002', 'PROVIDER');
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('açılmadan iki tarafta da kapalı', async () => {
  const { ilan, teklif } = await teklifAc();
  assert.equal(await ustaGorur(teklif), false);
  assert.equal(await alanGorur(ilan, teklif), false);
});

test('hizmet alan açınca hizmet verende de açık', async () => {
  const { ilan, teklif } = await teklifAc();
  await istek(`/api/v1/offers/${teklif}/communication`, { yontem: 'POST', token: alan.token });
  assert.equal(await ustaGorur(teklif), true);
  assert.equal(await alanGorur(ilan, teklif), true);
});

test('hizmet veren açınca hizmet alanda da açık', async () => {
  const { ilan, teklif } = await teklifAc();
  await istek(`/api/v1/offers/${teklif}/communication`, { yontem: 'POST', token: usta.token });
  assert.equal(await alanGorur(ilan, teklif), true);
  assert.equal(await ustaGorur(teklif), true);
});
