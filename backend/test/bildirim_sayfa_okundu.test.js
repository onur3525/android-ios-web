// SAYFA GÖRÜLDÜ → BİLDİRİM OKUNDU (21 Eki, kullanıcı isteği)
//   Bildirime dokunmadan ilgili sayfa açılınca o sayfaya ait okunmamış
//   bildirimler okunmuş sayılır. Başka sayfanın, başka kaydın, karşı rolün
//   ve başka kullanıcının bildirimleri DEĞİŞMEZ.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { uygulamaIciBildir } = await import('../src/routes/ilan.js');
const { simdi } = await import('../src/db.js');

let db, sunucu, taban;

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kisi(tel, rol) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%' OR key LIKE 'giris_ip:%'`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `b${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, id: me.json.id };
}
const kimlikler = async (u) => new Set((await db.prepare('SELECT id FROM notifications WHERE user_id = ?').all(u)).map((r) => String(r.id)));
const bildir = async (u, tur, ref) => {
  const once = await kimlikler(u);
  await uygulamaIciBildir(db, u, tur, 't', 'g', ref);
  const yeni = [...await kimlikler(u)].filter((id) => !once.has(id));
  assert.equal(yeni.length, 1);
  return yeni[0];
};
const okundu = async (id) => !!(await db.prepare('SELECT read_at FROM notifications WHERE id = ?').get(id)).read_at;
const sayfa = (token, page, refId) => istek('/api/v1/notifications/read-for-page', { yontem: 'POST', token, govde: { page, refId } });

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('ilan sayfası: yalnız o ilanın sahibine ait ilan bildirimleri okunur', async () => {
  const sahip = await kisi('5420000001', 'CUSTOMER');
  const baska = await kisi('5420000002', 'CUSTOMER');
  const ilan = randomUUID(); const digerIlan = randomUUID();
  const teklif = await bildir(sahip.id, 'NEW_OFFER', ilan);
  const sure = await bildir(sahip.id, 'LISTING_EXPIRED', ilan);
  const digerIlaninki = await bildir(sahip.id, 'NEW_OFFER', digerIlan);
  const mesaj = await bildir(sahip.id, 'NEW_MESSAGE', ilan); // başka sayfanın türü
  const baskasininki = await bildir(baska.id, 'NEW_OFFER', ilan);

  const r = await sayfa(sahip.token, 'ilan', ilan);
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.changed, 2);
  assert.ok(await okundu(teklif)); assert.ok(await okundu(sure));
  assert.equal(await okundu(digerIlaninki), false, 'başka ilan');
  assert.equal(await okundu(mesaj), false, 'başka sayfanın türü');
  assert.equal(await okundu(baskasininki), false, 'başka kullanıcı');
  assert.equal((await istek('/api/v1/notifications/unread-count', { token: sahip.token })).json.count, 2);
});

test('rol ayrımı: hizmet alan sayfası hizmet veren bildirimlerini okumaz (ve tersi)', async () => {
  const k = await kisi('5420000003', 'CUSTOMER');
  const ilan = randomUUID();
  const verenin = await bildir(k.id, 'OFFER_SELECTED', ilan);
  const alanin = await bildir(k.id, 'NEW_OFFER', ilan);
  await sayfa(k.token, 'ilan', ilan);
  assert.equal(await okundu(verenin), false);
  assert.ok(await okundu(alanin));
  const yeni = await bildir(k.id, 'NEW_OFFER', ilan);
  await sayfa(k.token, 'is', ilan);
  assert.ok(await okundu(verenin));
  assert.equal(await okundu(yeni), false);
});

test('ilan/iş sayfası o ilanın tekliflerindeki "iletişim açıldı" bildirimini de okur', async () => {
  const sahip = await kisi('5420000004', 'CUSTOMER');
  const usta = await kisi('5420000005', 'PROVIDER');
  const ilan = randomUUID(); const teklifId = randomUUID(); const disTeklif = randomUUID();
  const t = simdi();
  await db.prepare(`INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, status, created_at, expires_at, updated_at)
    VALUES (?, ?, ?, 'Boya', 'Merkez', 'açıklama', '[]', 'ACTIVE', ?, ?, ?)`).run(ilan, `T-${ilan.slice(0, 8)}`, sahip.id, t, t, t);
  await db.prepare(`INSERT INTO offers (id, listing_id, provider_id, amount_tl, note, status, created_at, updated_at)
    VALUES (?, ?, ?, 100, 'not', 'ACTIVE', ?, ?)`).run(teklifId, ilan, usta.id, t, t);
  const sahibinki = await bildir(sahip.id, 'CONTACT_OPENED', teklifId);
  const ustanin = await bildir(usta.id, 'CONTACT_OPENED', teklifId);
  const ilgisiz = await bildir(sahip.id, 'CONTACT_OPENED', disTeklif);
  assert.equal((await sayfa(sahip.token, 'ilan', ilan)).json.changed, 1);
  assert.ok(await okundu(sahibinki));
  assert.equal(await okundu(ustanin), false, 'karşı tarafınki onun sayfasında okunur');
  assert.equal(await okundu(ilgisiz), false);
  await sayfa(usta.token, 'is', ilan);
  assert.ok(await okundu(ustanin));
});

test('sohbet ve teklif talebi sayfaları kendi türlerini okur', async () => {
  const k = await kisi('5420000006', 'CUSTOMER');
  const teklif = randomUUID(); const talep = randomUUID();
  const mesaj = await bildir(k.id, 'NEW_MESSAGE', teklif);
  const talepTeklif = await bildir(k.id, 'TALEP_OFFER', talep);
  const talepMesaj = await bildir(k.id, 'TALEP_MESSAGE', talep);
  await sayfa(k.token, 'sohbet', teklif);
  assert.ok(await okundu(mesaj));
  await sayfa(k.token, 'talep', talep);
  assert.ok(await okundu(talepTeklif));
  assert.equal(await okundu(talepMesaj), false, 'mesaj, sohbet açılınca okunur');
  await sayfa(k.token, 'talep-sohbet', talep);
  assert.ok(await okundu(talepMesaj));
});

test('geçersiz sayfa/kimlik reddedilir; oturumsuz erişilemez', async () => {
  const k = await kisi('5420000007', 'CUSTOMER');
  assert.equal((await sayfa(k.token, 'yok', randomUUID())).durum, 400);
  assert.equal((await sayfa(k.token, '__proto__', randomUUID())).durum, 400);
  assert.equal((await sayfa(k.token, 'ilan', "x' OR 1=1 --")).durum, 400);
  assert.equal((await sayfa(k.token, 'ilan', '')).durum, 400);
  assert.equal((await sayfa(null, 'ilan', randomUUID())).durum, 401);
});
