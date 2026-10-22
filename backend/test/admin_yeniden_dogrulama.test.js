// HER DEĞİŞİKLİKTE ŞİFRE + DOĞRULAMA KODU (22 Eki, kullanıcı kuralı)
//   Açık kalmış bir admin ekranında kimse değişiklik yapamasın: GET dışı her
//   admin isteği, hemen öncesinde mevcut şifre + TOTP ile yapılmış TEK
//   KULLANIMLIK doğrulama ister. Görüntüleme serbesttir. Admin kendi
//   şifresini değiştirebilir; diğer oturumları kapanır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');

const SIFRE = 'GucluSifre12345';
let db, sunucu, taban;

async function istek(yol, { yontem = 'GET', govde, cerez } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(cerez ? { Cookie: cerez } : {}), ...(yontem !== 'GET' ? { 'X-HC-Admin': '1' } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, cerez: r.headers.get('set-cookie')?.split(';')[0] };
}

async function yonetici(email, rol = 'super_admin') {
  const sir = base32Uret();
  const id = randomUUID();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, email, 'Yönetici', rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
  return { id, email, sir };
}
async function giris(a, sifre = SIFRE) {
  await db.prepare('DELETE FROM rate_limits').run();
  const g = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: a.email, password: sifre } });
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  const m = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: totpUret(a.sir) }, cerez: g.cerez });
  assert.equal(m.durum, 200, JSON.stringify(m.json));
  return g.cerez;
}
const onayla = (cerez, a, { password = SIFRE, code = totpUret(a.sir) } = {}) =>
  istek('/admin/v1/auth/reauth', { yontem: 'POST', govde: { password, code }, cerez });
const destek = (cerez, aciklama) => istek('/admin/v1/support', { yontem: 'PUT', govde: { description: aciklama, email: 'destek@hizmetcep.com' }, cerez });

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('giriş tek başına değişiklik izni vermez; görüntüleme serbest', async () => {
  const a = await yonetici('g1@hc.test');
  const c = await giris(a);
  assert.equal((await istek('/admin/v1/support', { cerez: c })).durum, 200, 'görüntüleme şifre istemez');
  assert.equal((await istek('/admin/v1/catalog/categories', { cerez: c })).durum, 200);
  const r = await destek(c, 'Destek açıklaması bir');
  assert.equal(r.durum, 403);
  assert.equal(r.json.error.code, 'REAUTH_REQUIRED');
  // Kritik sayılmayan yazmalar da (ör. destek talebi kapatma) sorar.
  const k = await istek(`/admin/v1/support/tickets/${randomUUID()}/close`, { yontem: 'POST', govde: {}, cerez: c });
  assert.equal(k.json.error.code, 'REAUTH_REQUIRED');
});

test('yalnız kod ya da yalnız şifre yetmez; ikisi doğruysa değişiklik yapılır', async () => {
  const a = await yonetici('g2@hc.test');
  const c = await giris(a);
  const dogru = totpUret(a.sir);
  const yanlisKod = dogru === '000000' ? '111111' : '000000';
  assert.equal((await istek('/admin/v1/auth/reauth', { yontem: 'POST', govde: { code: dogru }, cerez: c })).durum, 401, 'şifresiz');
  assert.equal((await onayla(c, a, { password: 'YanlisSifre999' })).durum, 401, 'yanlış şifre');
  assert.equal((await onayla(c, a, { code: yanlisKod })).durum, 401, 'yanlış kod');
  assert.equal((await destek(c, 'Destek açıklaması iki')).json.error.code, 'REAUTH_REQUIRED', 'hatalı denemeler izin vermez');
  assert.equal((await onayla(c, a)).durum, 200);
  assert.equal((await destek(c, 'Destek açıklaması iki')).durum, 200);
  // Hatalı deneme sayacı başarılı doğrulamada sıfırlanır.
  assert.equal(Number((await db.prepare('SELECT failed_count FROM admins WHERE id = ?').get(a.id)).failed_count), 0);
});

test('doğrulama tek kullanımlıktır: ikinci değişiklik yeniden sorar', async () => {
  const a = await yonetici('g3@hc.test');
  const c = await giris(a);
  assert.equal((await onayla(c, a)).durum, 200);
  assert.equal((await destek(c, 'Destek açıklaması üç')).durum, 200);
  const ikinci = await destek(c, 'Destek açıklaması dört');
  assert.equal(ikinci.durum, 403);
  assert.equal(ikinci.json.error.code, 'REAUTH_REQUIRED');
});

test('eşzamanlı iki değişiklikten yalnız biri tek doğrulamayla geçer', async () => {
  const a = await yonetici('g4@hc.test');
  const c = await giris(a);
  assert.equal((await onayla(c, a)).durum, 200);
  const r = await Promise.all([destek(c, 'Eşzamanlı açıklama A'), destek(c, 'Eşzamanlı açıklama B')]);
  assert.deepEqual(r.map((x) => x.durum).sort(), [200, 403]);
});

test('süresi geçen doğrulama kullanılamaz', async () => {
  const a = await yonetici('g5@hc.test');
  const c = await giris(a);
  assert.equal((await onayla(c, a)).durum, 200);
  await db.prepare('UPDATE admin_sessions SET reauth_at = ? WHERE admin_id = ?').run(new Date(Date.now() - 3 * 60_000).toISOString(), a.id);
  assert.equal((await destek(c, 'Destek açıklaması beş')).json.error.code, 'REAUTH_REQUIRED');
});

test('5 hatalı doğrulama hesabı kilitler ve açık oturumu kapatır', async () => {
  const a = await yonetici('g6@hc.test');
  const c = await giris(a);
  for (let i = 0; i < 4; i++) assert.equal((await onayla(c, a, { password: `YanlisSifre${i}99` })).durum, 401);
  assert.equal((await istek('/admin/v1/support', { cerez: c })).durum, 200, '4 hatada oturum sürer');
  assert.equal((await onayla(c, a, { password: 'YanlisSifre599' })).durum, 401);
  assert.equal((await istek('/admin/v1/support', { cerez: c })).durum, 401, '5. hatada oturum kapanır');
  const kilit = await db.prepare('SELECT locked_until FROM admins WHERE id = ?').get(a.id);
  assert.ok(kilit.locked_until && Date.parse(kilit.locked_until) > Date.now(), 'hesap kilitli');
  const g = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: a.email, password: SIFRE } });
  assert.equal(g.durum, 429, 'doğru şifreyle de giriş yapılamaz');
  const kayit = await db.prepare("SELECT COUNT(*) n FROM audit_log WHERE admin_id = ? AND action = 'auth.reauth_failed'").get(a.id);
  assert.equal(Number(kayit.n), 5);
});

test('şifre değiştirme: kurallar, eski şifre geçersiz, diğer oturumlar kapanır', async () => {
  const a = await yonetici('g7@hc.test');
  const c1 = await giris(a);
  const c2 = await giris(a); // başka cihaz
  const degistir = (cerez, yeni) => istek('/admin/v1/auth/password', { yontem: 'POST', govde: { newPassword: yeni }, cerez });
  assert.equal((await degistir(c1, 'YeniSifre12345')).json.error.code, 'REAUTH_REQUIRED', 'onaysız değişmez');
  await onayla(c1, a);
  assert.equal((await degistir(c1, 'kisa1')).durum, 400, 'kısa şifre');
  await onayla(c1, a);
  assert.equal((await degistir(c1, 'sadeceharflerdenoluyor')).durum, 400, 'rakamsız şifre');
  await onayla(c1, a);
  assert.equal((await degistir(c1, SIFRE)).durum, 400, 'mevcutla aynı');
  await onayla(c1, a);
  assert.equal((await degistir(c1, 'YeniSifre12345')).durum, 200);
  assert.equal((await istek('/admin/v1/support', { cerez: c1 })).durum, 200, 'bu oturum sürer');
  assert.equal((await istek('/admin/v1/support', { cerez: c2 })).durum, 401, 'diğer cihaz kapanır');
  // Yeni şifreyle onay ve giriş; eskisiyle olmaz.
  assert.equal((await onayla(c1, a)).durum, 401, 'eski şifreyle onay yok');
  assert.equal((await onayla(c1, a, { password: 'YeniSifre12345' })).durum, 200);
  await db.prepare('DELETE FROM rate_limits').run();
  assert.equal((await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: a.email, password: SIFRE } })).durum, 401);
  assert.equal((await giris(a, 'YeniSifre12345')).length > 0, true);
  const kayit = await db.prepare("SELECT COUNT(*) n FROM audit_log WHERE admin_id = ? AND action = 'auth.password_changed'").get(a.id);
  assert.equal(Number(kayit.n), 1);
});

test('çıkış ve yeniden doğrulama uçları onay istemez; yetkisiz rol onaylı da olsa yapamaz', async () => {
  const a = await yonetici('g8@hc.test', 'readonly');
  const c = await giris(a);
  assert.equal((await onayla(c, a)).durum, 200);
  assert.equal((await destek(c, 'Salt okunur deneme')).durum, 403, 'yetki denetimi sürer');
  assert.equal((await istek('/admin/v1/auth/logout', { yontem: 'POST', govde: {}, cerez: c })).durum, 200);
  assert.equal((await istek('/admin/v1/support', { cerez: c })).durum, 401);
});
