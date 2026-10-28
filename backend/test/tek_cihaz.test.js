// TEK CİHAZ KURALI (28 Eki, kullanıcı kararı): yeni bir cihazdan uygulamaya
// giriş yapılınca eski cihazın oturumu — açık olsa bile — kapanır. Telefon/
// tablet ayrımı yok. Telefon/tablet tarayıcısındaki web oturumu da kapanır;
// bilgisayardaki web oturumu kalır. Eski cihazın bildirim kayıtları silinir.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { olaylar } = await import('../src/olaylar.js');

let db, sunucu, taban;
const TELEFON_A = { 'User-Agent': 'Dart/3.5 (dart:io)' };
const TABLET = { 'User-Agent': 'Dart/3.5 (dart:io)' };
const BILGISAYAR = { 'X-HC-Web': '1', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0 Safari/537.36' };
const TEL_TARAYICI = { 'X-HC-Web': '1', 'User-Agent': 'Mozilla/5.0 (Linux; Android 14; SM-S918B) Chrome/130.0 Mobile Safari/537.36' };

async function istek(yol, { yontem = 'GET', govde, token, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, cerezler: r.headers.getSetCookie() };
}
const cerez = (cerezler) => decodeURIComponent((cerezler.find((c) => c.startsWith('hc_rt=')) ?? '').split(';')[0].slice('hc_rt='.length));

async function kayit(tel) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%' OR key LIKE 'giris_ip:%'`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', basliklar: TELEFON_A, govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `t${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { id: me.json.id, tel, token: r.json.accessToken, refresh: r.json.refreshToken };
}
async function giris(tel, basliklar) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'giris_ip:%'`).run();
  const r = await istek('/api/v1/auth/login', { yontem: 'POST', basliklar, govde: { phone: tel, password: 'sifre1234' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return { token: r.json.accessToken, refresh: r.json.refreshToken ?? cerez(r.cerezler), web: !!basliklar['X-HC-Web'] };
}
const yenile = (o, basliklar) => (o.web
  ? istek('/api/v1/auth/refresh', { yontem: 'POST', govde: {}, basliklar: { ...basliklar, Cookie: `hc_rt=${encodeURIComponent(o.refresh)}` } })
  : istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: o.refresh }, basliklar }));
const acikMi = async (o) => (await istek('/api/v1/users/me', { token: o.token })).durum === 200;
const pushKaydet = (o, token, platform, basliklar = {}) =>
  istek('/api/v1/devices/push-token', { yontem: 'POST', token: o.token, basliklar, govde: { token, platform } });
const pushVar = async (token) => !!(await db.prepare('SELECT 1 FROM push_tokens WHERE token = ?').get(token));

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('yeni cihazda uygulama girişi: eski cihaz (açık olsa bile) kapanır; yeni cihaz çalışır', async () => {
  const k = await kayit('5420000001');
  const eski = { token: k.token, refresh: k.refresh, web: false };
  assert.ok(await acikMi(eski));
  const yeni = await giris(k.tel, TABLET);
  assert.equal(await acikMi(eski), false, 'eski cihazın erişimi hemen kapanır');
  assert.equal((await yenile(eski, TELEFON_A)).durum, 401, 'eski cihaz yenileyemez → giriş ekranı');
  assert.ok(await acikMi(yeni));
  assert.equal((await yenile(yeni, TABLET)).durum, 200);
  const neden = await db.prepare(`SELECT revoke_reason r FROM user_sessions WHERE refresh_hash IS NOT NULL AND user_id = ? AND revoke_reason = 'NEW_DEVICE'`).get(k.id);
  assert.equal(neden?.r, 'NEW_DEVICE');
});

test('bilgisayardaki web kalır; telefon tarayıcısındaki web kapanır', async () => {
  const k = await kayit('5420000002');
  const pc = await giris(k.tel, BILGISAYAR);
  const telWeb = await giris(k.tel, TEL_TARAYICI);
  assert.ok(await acikMi(pc)); assert.ok(await acikMi(telWeb));
  await giris(k.tel, TABLET);
  assert.ok(await acikMi(pc), 'bilgisayar web oturumu sürer');
  assert.equal((await yenile(pc, BILGISAYAR)).durum, 200);
  assert.equal(await acikMi(telWeb), false, 'telefon tarayıcısı kapanır');
});

test('web girişi (bilgisayar ya da telefon tarayıcısı) uygulama oturumunu KAPATMAZ', async () => {
  const k = await kayit('5420000003');
  const app = { token: k.token, refresh: k.refresh, web: false };
  await giris(k.tel, BILGISAYAR);
  await giris(k.tel, TEL_TARAYICI);
  assert.ok(await acikMi(app));
});

test('eski cihazın bildirim kayıtları silinir; bilgisayar web kaydı kalır', async () => {
  const k = await kayit('5420000004');
  const eski = { token: k.token, refresh: k.refresh, web: false };
  const pc = await giris(k.tel, BILGISAYAR);
  const telWeb = await giris(k.tel, TEL_TARAYICI);
  const T = (s) => `${s}_${'x'.repeat(30)}`;
  assert.equal((await pushKaydet(eski, T('eski_android'), 'android')).durum, 204);
  assert.equal((await pushKaydet(pc, T('pc_web'), 'web', BILGISAYAR)).durum, 204);
  assert.equal((await pushKaydet(telWeb, T('tel_web'), 'web', TEL_TARAYICI)).durum, 204);
  const yeni = await giris(k.tel, TABLET);
  assert.equal(await pushVar(T('eski_android')), false);
  assert.equal(await pushVar(T('tel_web')), false);
  assert.equal(await pushVar(T('pc_web')), true);
  // Yeni cihaz girişten sonra kendi kaydını yapar.
  assert.equal((await pushKaydet(yeni, T('yeni_ios'), 'ios')).durum, 204);
  assert.equal(await pushVar(T('yeni_ios')), true);
});

test('eski cihazın açık gerçek zamanlı bağlantısı için kapatma olayı yayınlanır', async () => {
  const k = await kayit('5420000005');
  const eskiOturum = (await db.prepare('SELECT id FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL').get(k.id)).id;
  const olay = [];
  const dinle = (v) => olay.push(v);
  olaylar.on('user.sessions.revoked', dinle);
  try {
    await giris(k.tel, TABLET);
  } finally { olaylar.off('user.sessions.revoked', dinle); }
  assert.ok(olay.some((v) => v.userId === k.id && v.oturumId === eskiOturum), JSON.stringify(olay));
});

test('eski cihazın ESKİ (döndürülmüş) belirteci yeni cihazı DÜŞÜRMEZ (tekrar kullanım sayılmaz)', async () => {
  const k = await kayit('5420000006');
  const y = await istek('/api/v1/auth/refresh', { yontem: 'POST', basliklar: TELEFON_A, govde: { refreshToken: k.refresh } });
  assert.equal(y.durum, 200);
  // Pay dışına it (mobilde pay süresizdir; halef artık kapalı olacak).
  const yeni = await giris(k.tel, TABLET);
  const r = await istek('/api/v1/auth/refresh', { yontem: 'POST', basliklar: TELEFON_A, govde: { refreshToken: k.refresh } });
  assert.equal(r.durum, 401);
  assert.ok(await acikMi(yeni), 'yeni cihazın oturumu kapanmamalı');
  assert.equal(await db.prepare(`SELECT 1 FROM user_sessions WHERE user_id = ? AND revoke_reason = 'REUSE_DETECTED'`).get(k.id), undefined);
});

test('aynı cihazda çıkış + tekrar giriş sorunsuz; yenileme başka cihazı kapatmaz', async () => {
  const k = await kayit('5420000007');
  const pc = await giris(k.tel, BILGISAYAR);
  const app = { token: k.token, refresh: k.refresh, web: false };
  const y = await yenile(app, TELEFON_A);
  assert.equal(y.durum, 200);
  assert.ok(await acikMi(pc), 'yenileme kuralı tetiklemez');
  assert.equal((await istek('/api/v1/auth/logout', { yontem: 'POST', token: y.json.accessToken })).durum, 204);
  const tekrar = await giris(k.tel, TELEFON_A);
  assert.ok(await acikMi(tekrar));
  assert.ok(await acikMi(pc));
});

test('042 öncesi satırlar user_agent ile sınıflanır (Dart → uygulama, masaüstü tarayıcı → kalır)', async () => {
  const k = await kayit('5420000008');
  const pc = await giris(k.tel, BILGISAYAR);
  await db.prepare('UPDATE user_sessions SET istemci = NULL WHERE user_id = ?').run(k.id);
  const app = { token: k.token, refresh: k.refresh, web: false };
  await giris(k.tel, TABLET);
  assert.equal(await acikMi(app), false);
  assert.ok(await acikMi(pc));
});

test('istemci türü ve soy döndürmede korunur', async () => {
  const k = await kayit('5420000009');
  const ilk = await db.prepare('SELECT id, istemci, soy_id FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL').get(k.id);
  assert.equal(ilk.istemci, 'mobil');
  assert.equal(ilk.soy_id, ilk.id);
  await istek('/api/v1/auth/refresh', { yontem: 'POST', basliklar: TELEFON_A, govde: { refreshToken: k.refresh } });
  const sonraki = await db.prepare('SELECT istemci, soy_id FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL').get(k.id);
  assert.equal(sonraki.istemci, 'mobil');
  assert.equal(sonraki.soy_id, ilk.id);
});
