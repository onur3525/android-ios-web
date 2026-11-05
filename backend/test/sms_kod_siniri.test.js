// SMS KODU GÖNDERİM KURALI — TEK KAYNAK (4 Kas, kullanıcı kuralı)
//
//  · İki kod arasında en az 60 saniye (OTP_WAIT, kalan saniye).
//  · Bir numaraya en fazla 3 kod; üçüncüden sonra doğrulama yapılmazsa son
//    gönderimden itibaren 5 dakika yeni kod yok (OTP_LOCKED, kalan süre; 5 Kas: 15 → 5 dk).
//  · 5 dakika dolunca hak yeniden 3; doğrulama başarılı olunca sıfır.
//  · Firebase yolu (/auth/otp/permit) ile sunucu SMS yolu (/auth/otp/request)
//    AYNI sayacı kullanır; kayıtlı/kayıtsız numarada davranış aynı.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
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
const izin = (phone, purpose = 'PHONE_VERIFY') => istek('/api/v1/auth/otp/permit', { yontem: 'POST', govde: { phone, purpose } });
const kodIste = (phone, purpose) => istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone, purpose } });
/** Zamanı ileri sarmak yerine son gönderimi geriye alır. */
const gerial = (tel, ms) => db.prepare('UPDATE rate_limits SET window_start = window_start - ? WHERE key = ?').run(ms, `sms:${tel}`);
const ipSayaciniSil = () => db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('60 sn bekleme, en fazla 3 kod, sonra 5 dk kilit; süre dolunca hak yeniden 3', async () => {
  const tel = '5321234001';
  const a = await izin(tel);
  assert.equal(a.durum, 200, JSON.stringify(a.json));
  assert.deepEqual(a.json, { retryAfterSec: 60, remaining: 2 });

  const erken = await izin(tel);
  assert.equal(erken.durum, 429);
  assert.equal(erken.json.error.code, 'OTP_WAIT');
  assert.ok(erken.json.error.details.retryAfterSec > 50 && erken.json.error.details.retryAfterSec <= 60);

  await gerial(tel, 61_000);
  assert.equal((await izin(tel)).json.remaining, 1);
  await gerial(tel, 61_000);
  assert.equal((await izin(tel)).json.remaining, 0);

  await gerial(tel, 61_000);
  const kilit = await izin(tel);
  assert.equal(kilit.durum, 429);
  assert.equal(kilit.json.error.code, 'OTP_LOCKED');
  const kalan = kilit.json.error.details.retryAfterSec;
  assert.ok(kalan > 3 * 60 && kalan <= 4 * 60, `kalan ${kalan}`);
  assert.match(kilit.json.error.message, /^Çok fazla kod istendi\. 4 dakika sonra tekrar deneyin\.$/);

  await gerial(tel, 4 * 60_000);
  const yeni = await izin(tel);
  assert.equal(yeni.durum, 200);
  assert.equal(yeni.json.remaining, 2, '5 dk sonra hak yeniden 3');
});

test('Firebase izni ve sunucu SMS yolu AYNI sayacı kullanır; amaç fark etmez', async () => {
  await ipSayaciniSil();
  const tel = '5321234002';
  assert.equal((await izin(tel, 'LOGIN')).durum, 200);
  await gerial(tel, 61_000);
  assert.equal((await izin(tel, 'FORGOT')).json.remaining, 1);
  await gerial(tel, 61_000);
  const ucuncu = await kodIste(tel, 'PHONE_VERIFY');
  assert.equal(ucuncu.durum, 204, JSON.stringify(ucuncu.json));
  await gerial(tel, 61_000);
  const dorduncu = await kodIste(tel, 'PHONE_VERIFY');
  assert.equal(dorduncu.json.error.code, 'OTP_LOCKED');
});

test('kayıtlı ve kayıtsız numarada aynı yanıt ve aynı sınır (bilgi sızmaz)', async () => {
  await ipSayaciniSil();
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'kayit_ip:%'`).run();
  const kayitli = '5321234003';
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, phone: kayitli, password: 'GucluSifre12', name: 'Sınır Kişi', email: 'sinir@ornek.com', role: 'CUSTOMER' } });
  assert.equal(r.durum, 200);
  await db.prepare('UPDATE users SET phone_verified = TRUE WHERE phone = ?').run(kayitli);
  const kayitsiz = '5321234004';
  for (const tel of [kayitli, kayitsiz]) {
    const ilk = await kodIste(tel, 'FORGOT');
    assert.equal(ilk.durum, 204, tel);
    assert.equal((await kodIste(tel, 'FORGOT')).json.error.code, 'OTP_WAIT', tel);
  }
});

test('doğrulama başarılı olunca sayaç sıfırlanır', async () => {
  await ipSayaciniSil();
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'kayit_ip:%'`).run();
  const tel = '5321234005';
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'GucluSifre12', name: 'Sayaç Kişi', email: 'sayac@ornek.com', role: 'CUSTOMER' } });
  const token = r.json.accessToken;
  await kodIste(tel, 'PHONE_VERIFY');
  await gerial(tel, 61_000);
  await kodIste(tel, 'PHONE_VERIFY');
  const kod = globalThis.__sonOtp;
  assert.match(String(kod), /^\d{6}$/);
  assert.ok(await db.prepare('SELECT 1 FROM rate_limits WHERE key = ?').get(`sms:${tel}`));
  const t = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token, govde: { phone: tel, otpCode: kod } });
  assert.ok(t.durum < 300, JSON.stringify(t.json));
  assert.equal(await db.prepare('SELECT 1 FROM rate_limits WHERE key = ?').get(`sms:${tel}`), undefined, 'sayaç sıfırlandı');
});

test('geçersiz amaç ve numara reddedilir', async () => {
  await ipSayaciniSil();
  assert.equal((await izin('5321234006', 'BASKA')).durum, 400);
  assert.equal((await izin('12', 'LOGIN')).durum, 400);
});
