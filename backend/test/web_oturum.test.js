// WEB OTURUMU — HttpOnly yenileme çerezi (15 Eki).
//   · Web istemcisi (X-HC-Web: 1) girişte HttpOnly/Secure/SameSite=None
//     çerez alır; yalnız /api/v1/auth yoluna gider.
//   · Sayfa yenilenince token'sız /auth/refresh çerezle oturumu sürdürür.
//   · Çerez YALNIZ başlıkla kabul edilir (CSRF); mobil davranış aynen.
//   · Çıkışta ve geçersiz çerezde çerez silinir; döndürülmüş çerezin
//     yeniden kullanımı bütün oturumları kapatır (mevcut kural).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');

let db, sunucu, taban;
const WEB = { 'X-HC-Web': '1' };

async function istek(yol, { yontem = 'POST', govde, token, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, cerezler: r.headers.getSetCookie() };
}
const rtCerezi = (cerezler) => cerezler.find((c) => c.startsWith('hc_rt='));
const deger = (c) => decodeURIComponent(c.split(';')[0].slice('hc_rt='.length));

async function kayit(tel, basliklar = {}) {
  await istek('/api/v1/auth/otp/request', { govde: { phone: tel, purpose: 'REGISTER' } });
  return istek('/api/v1/auth/register', { govde: { phone: tel, password: 'sifre1234', name: 'Web Deneme', email: `w${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp }, basliklar });
}

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('mobil (başlıksız): çerez yazılmaz', async () => {
  const r = await kayit('5330000001');
  assert.equal(r.durum, 200);
  assert.equal(rtCerezi(r.cerezler), undefined);
  const g = await istek('/api/v1/auth/login', { govde: { phone: '5330000001', password: 'sifre1234' } });
  assert.equal(rtCerezi(g.cerezler), undefined);
});

test('web: kayıt/giriş HttpOnly çerez yazar; sayfa yenilenince çerezle oturum sürer', async () => {
  const r = await kayit('5330000002', WEB);
  assert.equal(r.durum, 200);
  const c = rtCerezi(r.cerezler);
  assert.ok(c, 'çerez yok');
  for (const parca of ['HttpOnly', 'Secure', 'SameSite=None', 'Path=/api/v1/auth']) assert.ok(c.includes(parca), parca);
  assert.match(c, /Max-Age=\d+/);
  assert.equal(deger(c), r.json.refreshToken);

  // Sayfa yenilendi: bellekte token yok, yalnız çerez.
  const y = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(deger(c))}` } });
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  assert.ok(y.json.accessToken);
  const yeni = rtCerezi(y.cerezler);
  assert.ok(yeni, 'döndürülen çerez yazılmadı');
  assert.notEqual(deger(yeni), deger(c));
  const me = await istek('/api/v1/users/me', { yontem: 'GET', token: y.json.accessToken });
  assert.equal(me.durum, 200);
});

test('CSRF: çerez başlıksız kabul edilmez', async () => {
  const r = await kayit('5330000003', WEB);
  const c = rtCerezi(r.cerezler);
  const y = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: { Cookie: `hc_rt=${encodeURIComponent(deger(c))}` } });
  assert.equal(y.durum, 401);
});

test('döndürülmüş çerezin yeniden kullanımı: 401, çerez silinir, bütün oturumlar kapanır', async () => {
  const r = await kayit('5330000004', WEB);
  const eski = deger(rtCerezi(r.cerezler));
  const y1 = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(eski)}` } });
  assert.equal(y1.durum, 200);
  const y2 = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(eski)}` } });
  assert.equal(y2.durum, 401);
  assert.match(rtCerezi(y2.cerezler) ?? '', /Max-Age=0/);
  // Yeni (döndürülmüş) token da artık geçersiz.
  const y3 = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(deger(rtCerezi(y1.cerezler)))}` } });
  assert.equal(y3.durum, 401);
});

test('web çıkış: oturum kapanır ve çerez silinir', async () => {
  const r = await kayit('5330000005', WEB);
  const c = deger(rtCerezi(r.cerezler));
  const o = await istek('/api/v1/auth/logout', { token: r.json.accessToken, basliklar: WEB });
  assert.equal(o.durum, 204);
  assert.match(rtCerezi(o.cerezler) ?? '', /Max-Age=0/);
  const y = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(c)}` } });
  assert.equal(y.durum, 401);
});

test('çerez yoksa (hiç giriş yapılmamış) 401', async () => {
  const y = await istek('/api/v1/auth/refresh', { govde: {}, basliklar: WEB });
  assert.equal(y.durum, 401);
});
