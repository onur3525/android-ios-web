// YENİDEN KİMLİK DOĞRULAMA — telefon değiştirme ve hesap silme talebi mevcut
// şifreyi SUNUCUDA ister (15 Eki güvenlik denetimi, karar 2). Önceden yalnız
// oturum + yeni numaraya gelen kod yetiyordu; çalınmış oturumla numara
// değiştirilip "şifremi unuttum" ile hesap ele geçirilebilirdi.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

let db, sunucu, taban;
before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const h = { 'Content-Type': 'application/json' };
  if (token) h.Authorization = `Bearer ${token}`;
  const r = await fetch(taban + yol, { method: yontem, headers: h, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kod(tel, amac) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: amac } });
  return globalThis.__sonOtp;
}
async function hesap(tel) {
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Yeniden Doğrulama',
    email: `r${tel}@ornek.com`, role: 'CUSTOMER', otpCode: await kod(tel, 'REGISTER') } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return { tel, token: r.json.accessToken };
}

test('telefon değiştirme: şifresiz/yanlış şifre reddedilir, kod harcanmaz; doğru şifreyle değişir ve diğer oturumlar kapanır', async () => {
  const h = await hesap('5370000001');
  const ikinci = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: h.tel, password: 'sifre1234' } });
  assert.equal(ikinci.durum, 200);
  const yeni = '5370000002';
  const otp = await kod(yeni, 'PHONE_CHANGE');

  const sifresiz = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.token, govde: { newPhone: yeni, otpCode: otp } });
  assert.equal(sifresiz.durum, 400);
  assert.equal(sifresiz.json.error.code, 'WRONG_PASSWORD');
  const yanlis = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.token, govde: { newPhone: yeni, otpCode: otp, currentPassword: 'yanlis999' } });
  assert.equal(yanlis.json.error.code, 'WRONG_PASSWORD');
  assert.ok(await db.prepare('SELECT 1 FROM users WHERE phone = ?').get(h.tel), 'numara değişmedi');

  // Aynı kod hâlâ geçerli: yanlış şifre telefon kanıtını tüketmez.
  const dogru = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.token, govde: { newPhone: yeni, otpCode: otp, currentPassword: 'sifre1234' } });
  assert.equal(dogru.durum, 200, JSON.stringify(dogru.json));
  assert.equal(dogru.json.phone, yeni);
  assert.equal((await istek('/api/v1/users/me', { token: ikinci.json.accessToken })).durum, 401, 'diğer cihaz oturumu kapandı');
  assert.equal((await istek('/api/v1/users/me', { token: h.token })).durum, 200, 'işlemi yapan oturum açık kalır');
});

test('hesap silme talebi: şifresiz/yanlış şifreyle açılmaz; doğru şifreyle açılır', async () => {
  const h = await hesap('5370000003');
  const sayi = async () => (await db.prepare(`SELECT COUNT(*) AS n FROM account_requests WHERE type = 'DELETION' AND user_id = (SELECT id FROM users WHERE phone = ?)`).get(h.tel)).n;
  const sifresiz = await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: h.token, govde: {} });
  assert.equal(sifresiz.durum, 400);
  assert.equal(sifresiz.json.error.code, 'WRONG_PASSWORD');
  assert.equal(Number(await sayi()), 0);
  assert.equal((await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: h.token, govde: { password: 'yanlis999' } })).durum, 400);
  assert.equal((await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: h.token, govde: { password: 'sifre1234' } })).durum, 200);
  assert.equal(Number(await sayi()), 1);
});

test('oturumla şifre denemesi sınırlı: 15 dakikada 10 denemeden sonra 429', async () => {
  const h = await hesap('5370000004');
  for (let i = 0; i < 10; i++) {
    assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'yanlis999' } })).durum, 400);
  }
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: h.token, govde: { password: 'sifre1234' } })).durum, 429);
  assert.equal((await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: h.token, govde: { password: 'sifre1234' } })).durum, 429, 'sayaç kritik işlemlerde ortak');
});
