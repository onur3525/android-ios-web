// Uçtan uca: kayıt → giriş → yenileme → profil; admin askı/ban → erişim engeli + bildirim.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';

const { veritabaniAc, simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');

let db, sunucu, taban, adminCerez, adminSir;
const TEL = '5321112233';

async function istek(yol, { yontem = 'GET', govde, token, cerez } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(cerez ? { Cookie: cerez } : {}),
      ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1' } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, setCookie: r.headers.get('set-cookie') };
}

async function otpAl(tel, amac) {
  // OTP zaman sınırı (60 sn) testte geri alınır: son kaydın zamanı eskitilir.
  await db.prepare(`UPDATE otp_codes SET created_at = ? WHERE phone = ?`).run('2000-01-01T00:00:00.000Z', tel);
  const r = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: amac } });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
  return globalThis.__sonOtp;
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  adminSir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'moderator', ?, ?, ?)`)
    .run(randomUUID(), 'mod@hc.test', 'Moderatör', sifreOzetle('GucluSifre12345'), sirSifrele(adminSir), simdi());
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const a = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'mod@hc.test', password: 'GucluSifre12345' } });
  const c = a.setCookie.split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(adminSir) }) });
  adminCerez = c;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

let erisim, yenileme, kullaniciId;

test('kayıt: OTP olmadan reddedilir, doğru OTP ile hesap + oturum', async () => {
  const yanlis = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234', name: 'Ayşe Yılmaz', email: 'ayse@ornek.com', role: 'CUSTOMER', otpCode: '000000' } });
  assert.equal(yanlis.durum, 400);
  const kod = await otpAl(TEL, 'REGISTER');
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234', name: 'Ayşe Yılmaz', email: 'ayse@ornek.com', role: 'CUSTOMER', otpCode: kod } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.ok(r.json.accessToken && r.json.refreshToken);
  erisim = r.json.accessToken;
  yenileme = r.json.refreshToken;
  const me = await istek('/api/v1/users/me', { token: erisim });
  assert.equal(me.json.phone, TEL);
  assert.deepEqual(me.json.roles, ['CUSTOMER']);
  assert.equal(me.json.phoneVerified, true);
  kullaniciId = me.json.id;
  // OTP kayda düz yazılmamış olmalı
  const m = await db.prepare(`SELECT body FROM outbound_messages WHERE template = 'OTP' ORDER BY created_at DESC LIMIT 1`).get();
  assert.ok(!m.body.includes(kod));
});

test('aynı OTP ikinci kez kullanılamaz; aynı numara ikinci kez kayıt olamaz', async () => {
  const r = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: TEL, purpose: 'REGISTER' } });
  assert.equal(r.durum, 409);
});

test('giriş + yenileme rotasyonu; eski yenileme token\'ı tekrar kullanılırsa tüm oturumlar düşer', async () => {
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '0532 111 22 33', password: 'sifre1234' } });
  assert.equal(g.durum, 200);
  const y1 = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: g.json.refreshToken } });
  assert.equal(y1.durum, 200);
  const tekrar = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: g.json.refreshToken } });
  assert.equal(tekrar.durum, 401);
  // yeniden kullanım tespit edildi → yeni token da geçersiz
  assert.equal((await istek('/api/v1/users/me', { token: y1.json.accessToken })).durum, 401);
  // Yeni giriş
  const g2 = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234' } });
  erisim = g2.json.accessToken;
  yenileme = g2.json.refreshToken;
});

test('yanlış şifre genel hata; adres yalnız aktif bölgeden', async () => {
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'yanlis-sifre' } });
  assert.equal(g.durum, 401);
  assert.equal(g.json.error.code, 'WRONG_PASSWORD');
  const kotu = await istek('/api/v1/profiles/me/address', { yontem: 'PUT', token: erisim, govde: { city: 'İzmir', district: 'Uydurma', neighborhood: 'Yok' } });
  assert.equal(kotu.durum, 400);
  const mah = await db.prepare(`SELECT d.name d, n.name n FROM neighborhoods n JOIN districts d ON d.id = n.district_id LIMIT 1`).get();
  const iyi = await istek('/api/v1/profiles/me/address', { yontem: 'PUT', token: erisim, govde: { city: 'İzmir', district: mah.d, neighborhood: mah.n } });
  assert.equal(iyi.durum, 200);
  assert.equal((await istek('/api/v1/profiles/me/address', { token: erisim })).json.district, mah.d);
});

test('askıya alma: gerekçe zorunlu, oturumlar düşer, giriş engellenir, bildirim kaydedilir', async () => {
  const gerekcesiz = await istek(`/admin/v1/users/${kullaniciId}/suspend`, { yontem: 'POST', cerez: adminCerez, govde: {} });
  assert.equal(gerekcesiz.durum, 400);
  const r = await istek(`/admin/v1/users/${kullaniciId}/suspend`, { yontem: 'POST', cerez: adminCerez, govde: { reason: 'Topluluk kurallarına aykırı içerik' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.status, 'SUSPENDED');
  // SMS doğrulanmış → gönderildi (geliştirme sağlayıcısı); e-posta doğrulanmamış → FAILED kaydı
  assert.deepEqual(r.json.notifications.map((n) => n.status).sort(), ['FAILED', 'SENT']);
  // Mevcut token artık çalışmaz
  assert.equal((await istek('/api/v1/users/me', { token: erisim })).durum, 401);
  // Giriş de engellenir
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234' } });
  assert.equal(g.durum, 403);
  assert.equal(g.json.error.code, 'ACCOUNT_SUSPENDED');
  // Yenileme ile de giremez
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: yenileme } })).durum, 401);
  const d = await istek(`/admin/v1/users/${kullaniciId}`, { cerez: adminCerez });
  assert.equal(d.json.statusHistory[0].reason, 'Topluluk kurallarına aykırı içerik');
  const sms = d.json.notifications.find((n) => n.channel === 'SMS');
  assert.equal(sms.template, 'HESAP_ASKIYA_ALINDI');
});

test('askıyı kaldır → giriş açılır; ban → ACCOUNT_BANNED; ban kaldır', async () => {
  assert.equal((await istek(`/admin/v1/users/${kullaniciId}/unsuspend`, { yontem: 'POST', cerez: adminCerez, govde: { reason: 'İnceleme tamamlandı' } })).durum, 200);
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234' } })).durum, 200);
  assert.equal((await istek(`/admin/v1/users/${kullaniciId}/ban`, { yontem: 'POST', cerez: adminCerez, govde: { reason: 'Tekrarlanan dolandırıcılık girişimi' } })).durum, 200);
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234' } });
  assert.equal(g.json.error.code, 'ACCOUNT_BANNED');
  // Geçersiz geçiş: banlıya askı uygulanamaz
  assert.equal((await istek(`/admin/v1/users/${kullaniciId}/suspend`, { yontem: 'POST', cerez: adminCerez, govde: { reason: 'Geçersiz geçiş denemesi' } })).durum, 409);
  assert.equal((await istek(`/admin/v1/users/${kullaniciId}/unban`, { yontem: 'POST', cerez: adminCerez, govde: { reason: 'İtiraz kabul edildi' } })).durum, 200);
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234' } })).durum, 200);
  await assert.rejects(db.prepare('DELETE FROM user_status_history').run(), /silinemez/);
});

test('hizmet veren onayı yok: rol eklenince doğrudan APPROVED', async () => {
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234' } });
  const t = g.json.accessToken;
  const kod = await otpAl(TEL, 'ROLE_ADD');
  const r = await istek('/api/v1/auth/roles/add', { yontem: 'POST', token: t, govde: { role: 'PROVIDER', password: 'sifre1234', otpCode: kod } });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
  const o = await istek('/api/v1/profiles/me/provider/approval', { token: t });
  assert.equal(o.json.status, 'APPROVED');
  const ilk = await db.prepare(`SELECT c.name k, s.name h FROM services s JOIN categories c ON c.id = s.category_id LIMIT 1`).get();
  const ilce = await db.prepare('SELECT name FROM districts LIMIT 1').get();
  const p = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: t, govde: { categories: [ilk.h], districts: [ilce.name] } });
  assert.equal(p.durum, 200);
  const kotu = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: t, govde: { categories: ['Uydurma Hizmet'], districts: [] } });
  assert.equal(kotu.durum, 400);
});
