// ADMİN EKSİKLERİ (28 Eki, kullanıcı onayı):
//   1) Kullanıcı detayında oturumun cihaz türü (tek cihaz kuralı),
//   2) Giriş kilidi görünür ve gerekçeyle kaldırılır,
//   3) İndirme sınırına takılan istekler Sistem Durumu'nda ayrı sayılır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
// Bu dosyada indirme sınırı dakikada 1: ikinci istek 429 (DOWNLOAD_LIMIT).
process.env.HC_INDIRME_IP_DAKIKA = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

const SIFRE = 'GucluSifre12345';
let db, sunucu, taban;
const cerezler = {};

async function istek(yol, { yontem = 'GET', govde, rol = 'super_admin', basliklar = {} } = {}) {
  const admin = yol.startsWith('/admin/');
  if (admin) await degisiklikOnayi(taban, yol, yontem, cerezler[rol]);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(admin ? { Cookie: cerezler[rol] ?? '', 'X-HC-Admin': '1' } : {}), ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  let json = null;
  try { json = m ? JSON.parse(m) : null; } catch { json = null; }
  return { durum: r.status, json, ham: m };
}
async function adminGiris(rol) {
  const sir = base32Uret();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(randomUUID(), `${rol}@eksik.test`, rol, rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: `${rol}@eksik.test`, password: SIFRE }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  const m = await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  assert.equal(m.status, 200);
  cerezler[rol] = c;
  onayKimligi(c, SIFRE, sir);
}
async function kayit(tel) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%' OR key LIKE 'giris_ip:%'`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', basliklar: { 'User-Agent': 'Dart/3.5 (dart:io)' }, govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `e${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, r.ham);
  return (await db.prepare('SELECT id FROM users WHERE phone LIKE ?').get(`%${tel}`)).id;
}
const giris = async (tel, sifre, basliklar = {}) => {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'giris_ip:%'`).run();
  return istek('/api/v1/auth/login', { yontem: 'POST', basliklar, govde: { phone: tel, password: sifre } });
};

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  await adminGiris('super_admin');
  await adminGiris('operations');
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('kullanıcı detayı: oturumların cihaz türü (uygulama / telefon tarayıcısı / bilgisayar) döner', async () => {
  const tel = '5430000001';
  const id = await kayit(tel);
  await giris(tel, 'sifre1234', { 'X-HC-Web': '1', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0' });
  await giris(tel, 'sifre1234', { 'X-HC-Web': '1', 'User-Agent': 'Mozilla/5.0 (Linux; Android 14) Chrome/130.0 Mobile Safari/537.36' });
  const d = await istek(`/admin/v1/users/${id}`);
  assert.equal(d.durum, 200, d.ham);
  const turler = d.json.sessions.map((o) => o.device).sort();
  assert.deepEqual(turler, ['mobil', 'web', 'web_mobil']);
  // 042 öncesi satır (istemci boş) user_agent'tan sınıflanır.
  await db.prepare('UPDATE user_sessions SET istemci = NULL WHERE user_id = ?').run(id);
  const d2 = await istek(`/admin/v1/users/${id}`);
  assert.deepEqual(d2.json.sessions.map((o) => o.device).sort(), ['mobil', 'web', 'web_mobil']);
});

test('giriş kilidi: 5 hatalı şifreden sonra detayda görünür; gerekçeyle kaldırılır, denetime yazılır', async () => {
  const tel = '5430000002';
  const id = await kayit(tel);
  let d = await istek(`/admin/v1/users/${id}`);
  assert.equal(d.json.loginLockedUntil, null);
  for (let i = 0; i < 5; i += 1) assert.equal((await giris(tel, 'yanlis-sifre')).durum, 401);
  assert.equal((await giris(tel, 'sifre1234')).durum, 429, 'doğru şifre de kilitte reddedilir');
  d = await istek(`/admin/v1/users/${id}`);
  assert.ok(d.json.loginLockedUntil && Date.parse(d.json.loginLockedUntil) > Date.now());

  const gerekcesiz = await istek(`/admin/v1/users/${id}/unlock-login`, { yontem: 'POST', govde: {} });
  assert.equal(gerekcesiz.durum, 400, 'gerekçe zorunlu');
  const yetkisiz = await istek(`/admin/v1/users/${id}/unlock-login`, { yontem: 'POST', rol: 'operations', govde: { reason: 'Kullanıcı destek talebiyle bildirdi' } });
  assert.equal(yetkisiz.durum, 403);
  const k = await istek(`/admin/v1/users/${id}/unlock-login`, { yontem: 'POST', govde: { reason: 'Kullanıcı destek talebiyle bildirdi' } });
  assert.equal(k.durum, 200, k.ham);
  assert.equal(k.json.loginLockedUntil, null);
  assert.equal((await giris(tel, 'sifre1234')).durum, 200, 'kilit kalkınca giriş açılır');
  const denetim = await db.prepare(`SELECT 1 FROM audit_log WHERE action = 'user.login.unlock' AND target_id = ?`).get(id);
  assert.ok(denetim, 'denetim kaydı');
  const tekrar = await istek(`/admin/v1/users/${id}/unlock-login`, { yontem: 'POST', govde: { reason: 'Kullanıcı destek talebiyle bildirdi' } });
  assert.equal(tekrar.durum, 409, 'kilit yoksa kaldırılacak bir şey yok');
  const durum = await db.prepare('SELECT status FROM users WHERE id = ?').get(id);
  assert.equal(durum.status, 'ACTIVE', 'hesap durumu değişmez');
});

test('Sistem Durumu: indirme sınırına takılan istek ayrı sayılır (4xx içinde de)', async () => {
  const bas = (await istek('/admin/v1/system/status')).json.apiMetrics.last15m;
  assert.equal(typeof bas.downloadLimited, 'number');
  const yol = `/api/v1/categories/photo/katalog/kategori/${randomUUID()}.jpg`;
  assert.equal((await istek(yol)).durum, 404, 'ilk istek sınır içinde (bağlı fotoğraf yok → 404)');
  const r = await istek(yol);
  assert.equal(r.durum, 429);
  const s = (await istek('/admin/v1/system/status')).json.apiMetrics.last15m;
  assert.equal(s.downloadLimited - bas.downloadLimited, 1);
  assert.ok(s.errors4xx - bas.errors4xx >= 2);
});
