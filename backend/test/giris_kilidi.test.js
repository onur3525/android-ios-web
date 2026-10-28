// GİRİŞ KİLİDİ (28 Eki, kullanıcı kararı: "kullanıcı admine bağlı kalmadan
// kilidi açabilmeli"): kilit deneme yapılan BAĞLANTIYA konur; başkası
// kullanıcıyı kilitleyemez; Şifremi Unuttum / SMS girişi kilidi açar.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
process.env.HC_TRUST_PROXY_HOPS = '1'; // bağlantı = X-Forwarded-For'un en sağı
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

let db, sunucu, taban;
const SALDIRGAN = '203.0.113.50';
const KULLANICI = '198.51.100.7';

async function istek(yol, { yontem = 'GET', govde, ip = KULLANICI, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), 'X-Forwarded-For': ip, 'User-Agent': 'Dart/3.5 (dart:io)', ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kayit(tel) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%' OR key LIKE 'giris_ip:%'`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'sifre1234', name: 'Kilit Deneme', email: `k${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return (await db.prepare('SELECT id FROM users WHERE phone LIKE ?').get(`%${tel}`)).id;
}
const giris = async (tel, sifre, ip) => {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'giris_ip:%'`).run();
  return istek('/api/v1/auth/login', { yontem: 'POST', ip, govde: { phone: tel, password: sifre } });
};

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('başkasının 5 hatalı denemesi yalnız KENDİ bağlantısını kilitler; gerçek kullanıcı girer', async () => {
  const tel = '5450000001';
  await kayit(tel);
  for (let i = 0; i < 5; i += 1) assert.equal((await giris(tel, 'yanlis', SALDIRGAN)).durum, 401);
  const kilit = await giris(tel, 'sifre1234', SALDIRGAN);
  assert.equal(kilit.durum, 429, 'saldırganın bağlantısı doğru şifreyle de giremez');
  assert.equal(kilit.json.error.code, 'LOGIN_LOCKED');
  assert.match(kilit.json.error.message, /Şifremi Unuttum/);
  assert.match(kilit.json.error.message, /SMS koduyla/);
  assert.equal((await giris(tel, 'sifre1234', KULLANICI)).durum, 200, 'gerçek kullanıcı kendi bağlantısından girer');
});

test('başarılı giriş bütün bağlantı kilitlerini kaldırır', async () => {
  const tel = '5450000002';
  await kayit(tel);
  for (let i = 0; i < 5; i += 1) await giris(tel, 'yanlis', SALDIRGAN);
  assert.equal((await giris(tel, 'sifre1234', SALDIRGAN)).durum, 429);
  assert.equal((await giris(tel, 'sifre1234', KULLANICI)).durum, 200);
  assert.equal((await giris(tel, 'sifre1234', SALDIRGAN)).durum, 200);
});

test('kullanıcı kendi bağlantısında kilitlenirse Şifremi Unuttum ile HEMEN açar', async () => {
  const tel = '5450000003';
  await kayit(tel);
  for (let i = 0; i < 5; i += 1) await giris(tel, 'yanlis', KULLANICI);
  assert.equal((await giris(tel, 'sifre1234', KULLANICI)).durum, 429);
  await db.prepare(`UPDATE otp_codes SET created_at = ? WHERE phone LIKE ?`).run('2000-01-01T00:00:00.000Z', `%${tel}`);
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  const o = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'FORGOT' } });
  assert.equal(o.durum, 204, JSON.stringify(o.json));
  const s = await istek('/api/v1/auth/forgot/complete', { yontem: 'POST', govde: { phone: tel, otpCode: globalThis.__sonOtp, newPassword: 'yeniSifre123' } });
  assert.ok([200, 204].includes(s.durum), JSON.stringify(s.json));
  assert.equal((await giris(tel, 'yeniSifre123', KULLANICI)).durum, 200, 'sıfırlamadan hemen sonra giriş');
});

test('farklı bağlantılardan art arda 30 hatalı şifre hesabı 60 dk kilitler; sıfırlama açar', async () => {
  const tel = '5450000004';
  const id = await kayit(tel);
  for (let i = 0; i < 30; i += 1) await giris(tel, 'yanlis', `192.0.2.${i + 1}`);
  const u = await db.prepare('SELECT locked_until FROM users WHERE id = ?').get(id);
  const dk = (Date.parse(u.locked_until) - Date.now()) / 60000;
  assert.ok(dk > 55 && dk <= 60, `kilit ~60 dk (${dk})`);
  const r = await giris(tel, 'sifre1234', KULLANICI);
  assert.equal(r.durum, 429);
  assert.equal(r.json.error.code, 'LOGIN_LOCKED');
  // 29 hata hesabı kilitlemez (eşik 30).
  const tel2 = '5450000005';
  await kayit(tel2);
  for (let i = 0; i < 29; i += 1) await giris(tel2, 'yanlis', `192.0.2.${i + 100}`);
  assert.equal((await giris(tel2, 'sifre1234', KULLANICI)).durum, 200);
});
