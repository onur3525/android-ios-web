// TİCARİ ELEKTRONİK İLETİ İZNİ (4 Kas, kullanıcı kararı)
//  · Kayıttaki isteğe bağlı kutu "Duyurular ve kampanyalar" tercihini belirler;
//    işaretlenmezse KAPALI (önceden onay şartı).
//  · İşlem bildirimleri (teklif, mesaj) etkilenmez.
//  · Her değişiklik zamanı ve kaynağıyla kaydedilir (kayıt, ayarlar, hesap silme).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

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
async function kaydol(tel, ek = {}) {
  await db.prepare('DELETE FROM rate_limits').run();
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'GucluSifre12', name: 'İzin Kişi', email: `i${tel}@ornek.com`, role: 'CUSTOMER', ...ek } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = (await istek('/api/v1/users/me', { token: r.json.accessToken })).json;
  return { token: r.json.accessToken, id: me.id, tercih: me.notificationPrefs };
}
const gecmis = (id) => db.prepare('SELECT granted, source FROM marketing_consents WHERE user_id = ? ORDER BY created_at, source').all(id);

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('kutu işaretlenmezse kampanya izni KAPALI; işlem bildirimleri açık; kayıt düşülür', async () => {
  const k = await kaydol('5380000001');
  assert.deepEqual(k.tercih, { offer: true, message: true, announcement: false, email: true });
  assert.deepEqual((await gecmis(k.id)).map((x) => [Number(x.granted), x.source]), [[0, 'REGISTER']]);
  const u = await db.prepare('SELECT marketing_consent_at FROM users WHERE id = ?').get(k.id);
  assert.ok(u.marketing_consent_at, 'iznin zamanı kayıtlı');
});

test('kutu işaretlenirse izin açık ve zamanıyla kayıtlı', async () => {
  const k = await kaydol('5380000002', { marketingConsent: true });
  assert.equal(k.tercih.announcement, true);
  assert.deepEqual((await gecmis(k.id)).map((x) => [Number(x.granted), x.source]), [[1, 'REGISTER']]);
  // Yalnız gerçek true kabul edilir.
  const s = await kaydol('5380000003', { marketingConsent: 'evet' });
  assert.equal(s.tercih.announcement, false);
});

test('ayarlardan değiştirilince her değişiklik kaydedilir; aynı değer tekrar kayıt üretmez', async () => {
  const k = await kaydol('5380000004');
  const ac = await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', token: k.token, govde: { announcement: true } });
  assert.equal(ac.json.announcement, true);
  await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', token: k.token, govde: { announcement: true } });
  await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', token: k.token, govde: { offer: false } });
  const kapa = await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', token: k.token, govde: { announcement: false } });
  assert.equal(kapa.json.announcement, false);
  const g = (await gecmis(k.id)).map((x) => [Number(x.granted), x.source]);
  assert.deepEqual(g, [[0, 'REGISTER'], [1, 'SETTINGS'], [0, 'SETTINGS']]);
});

test('052 göçü iki veritabanında aynı mantık', async () => {
  const { readFileSync } = await import('node:fs');
  const oku = (d) => readFileSync(new URL(`../migrations/${d}/052_ticari_ileti_izni.sql`, import.meta.url), 'utf8');
  const sade = (m) => m.replace(/UUID|TIMESTAMPTZ/g, 'T').replace(/TEXT/g, 'T');
  assert.equal(sade(oku('postgres')), sade(oku('sqlite')));
});
