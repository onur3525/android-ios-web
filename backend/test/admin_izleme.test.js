// YÖNETİCİ İZİ (28 Eki, kullanıcı isteği): süper admin her yöneticinin
// oturumlarını (açılış/kapanış saati + neden, IP, cihaz) ve bütün işlemlerini
// görür. Oturum HER kapandığında denetime yazılır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret, bostaAdminOturumlariniKapat } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

const SIFRE = 'GucluSifre12345';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0 Safari/537.36';
let db, sunucu, taban;
const admin = {};

async function istek(yol, { yontem = 'GET', govde, cerez } = {}) {
  await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), Cookie: cerez ?? '', 'X-HC-Admin': '1', 'User-Agent': UA },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, ham: m };
}
async function adminEkle(ad, rol) {
  const sir = base32Uret();
  const id = randomUUID();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, `${ad}@iz.test`, ad, rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
  admin[ad] = { id, sir, email: `${ad}@iz.test` };
  return admin[ad];
}
async function giris(ad) {
  const a = admin[ad];
  await db.prepare(`DELETE FROM rate_limits`).run();
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', 'User-Agent': UA }, body: JSON.stringify({ email: a.email, password: SIFRE }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  const m = await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1', 'User-Agent': UA }, body: JSON.stringify({ code: totpUret(a.sir) }) });
  assert.equal(m.status, 200);
  onayKimligi(c, SIFRE, a.sir);
  return c;
}
const oturumlar = async (id, cerez) => (await istek(`/admin/v1/admins/${id}/sessions`, { cerez })).json.sessions;

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  await adminEkle('patron', 'super_admin');
  await adminEkle('mod', 'moderator');
  admin.patron.cerez = await giris('patron');
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('giriş: açık oturum IP ve cihazla görünür; çıkış: kapanış saati ve neden yazılır', async () => {
  const c = await giris('mod');
  let s = await oturumlar(admin.mod.id, admin.patron.cerez);
  assert.equal(s[0].status, 'ACIK');
  assert.ok(s[0].sessionId);
  assert.equal(s[0].device, UA);
  assert.ok(s[0].ip);
  assert.equal((await istek('/admin/v1/auth/logout', { yontem: 'POST', govde: {}, cerez: c })).durum, 200);
  s = await oturumlar(admin.mod.id, admin.patron.cerez);
  assert.equal(s[0].status, 'KAPALI');
  assert.equal(s[0].closeReason, 'CIKIS');
  assert.ok(s[0].closedAt && s[0].lastActivityAt);
  // Belirteç özeti denetime yazılmaz.
  const ham = JSON.stringify(await db.prepare(`SELECT * FROM audit_log WHERE action IN ('auth.login','auth.session_end')`).all());
  const ozetler = (await db.prepare('SELECT token_hash FROM admin_sessions').all()).map((x) => x.token_hash);
  for (const o of ozetler) assert.equal(ham.includes(o), false);
});

test('15 dk hareketsiz oturum: istek gelince kapanır; kapanış = son işlem + 15 dk', async () => {
  const c = await giris('mod');
  const son = new Date(Date.now() - 20 * 60 * 1000).toISOString();
  await db.prepare(`UPDATE admin_sessions SET last_seen = ? WHERE admin_id = ? AND stage = 'full'`).run(son, admin.mod.id);
  assert.equal((await istek('/admin/v1/auth/me', { cerez: c })).durum, 401);
  const s = (await oturumlar(admin.mod.id, admin.patron.cerez))[0];
  assert.equal(s.status, 'KAPALI');
  assert.equal(s.closeReason, 'HAREKETSIZLIK');
  assert.equal(Date.parse(s.closedAt), Date.parse(son) + 15 * 60 * 1000);
});

test('tarayıcıyı kapatıp giden: dakikalık bakım oturumu kapatır ve kaydeder (bir kez)', async () => {
  await giris('mod');
  await db.prepare(`UPDATE admin_sessions SET last_seen = ? WHERE admin_id = ? AND stage = 'full'`).run(new Date(Date.now() - 16 * 60 * 1000).toISOString(), admin.mod.id);
  assert.equal(await bostaAdminOturumlariniKapat(db), 1);
  assert.equal(await bostaAdminOturumlariniKapat(db), 0, 'ikinci tur yeniden yazmaz');
  const s = (await oturumlar(admin.mod.id, admin.patron.cerez))[0];
  assert.equal(s.closeReason, 'HAREKETSIZLIK');
});

test('MFA tamamlanmamış (yarım) oturum kapanınca oturum kaydı oluşmaz', async () => {
  const once = Number((await db.prepare(`SELECT COUNT(*) n FROM audit_log WHERE action = 'auth.session_end'`).get()).n);
  await db.prepare('DELETE FROM rate_limits').run();
  await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: admin.mod.email, password: SIFRE }) });
  await db.prepare(`UPDATE admin_sessions SET last_seen = ? WHERE admin_id = ?`).run(new Date(Date.now() - 16 * 60 * 1000).toISOString(), admin.mod.id);
  await bostaAdminOturumlariniKapat(db);
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM audit_log WHERE action = 'auth.session_end'`).get()).n), once);
});

test('şifre değişince diğer oturumlar SIFRE_DEGISTI; pasife alınınca YONETICI_PASIF; silinince YONETICI_SILINDI', async () => {
  const c1 = await giris('mod');
  const c2 = await giris('mod');
  // Şifre değişikliği her değişiklik gibi şifre + kod onayı ister (/auth/ yolları ortak yardımcıda atlanır).
  assert.equal((await istek('/admin/v1/auth/reauth', { yontem: 'POST', govde: { password: SIFRE, code: totpUret(admin.mod.sir) }, cerez: c2 })).durum, 200);
  const r = await istek('/admin/v1/auth/password', { yontem: 'POST', govde: { newPassword: 'YeniGucluSifre987' }, cerez: c2 });
  assert.equal(r.durum, 200, r.ham);
  let s = await oturumlar(admin.mod.id, admin.patron.cerez);
  const kapanan = s.find((o) => o.closeReason === 'SIFRE_DEGISTI');
  assert.ok(kapanan, JSON.stringify(s.slice(0, 3)));
  assert.equal((await istek('/admin/v1/auth/me', { cerez: c1 })).durum, 401);
  await db.prepare('UPDATE admins SET password_hash = ? WHERE id = ?').run(sifreOzetle(SIFRE), admin.mod.id);

  await giris('mod');
  assert.equal((await istek(`/admin/v1/admins/${admin.mod.id}`, { yontem: 'PATCH', govde: { active: false }, cerez: admin.patron.cerez })).durum, 200);
  s = await oturumlar(admin.mod.id, admin.patron.cerez);
  assert.ok(s.some((o) => o.closeReason === 'YONETICI_PASIF'));
  assert.equal((await istek(`/admin/v1/admins/${admin.mod.id}`, { yontem: 'PATCH', govde: { active: true }, cerez: admin.patron.cerez })).durum, 200);

  await adminEkle('gecici', 'content');
  await giris('gecici');
  assert.equal((await istek(`/admin/v1/admins/${admin.gecici.id}`, { yontem: 'DELETE', govde: { reason: 'Görevden ayrıldı' }, cerez: admin.patron.cerez })).durum, 204);
  s = await oturumlar(admin.gecici.id, admin.patron.cerez);
  assert.equal(s[0].closeReason, 'YONETICI_SILINDI');
  const d = await istek(`/admin/v1/admins/${admin.gecici.id}/detail`, { cerez: admin.patron.cerez });
  assert.equal(d.durum, 200, 'silinmiş yöneticinin izi de görülür');
  assert.ok(d.json.deletedAt);
});

test('işlemler: yaptığı değişiklikler gerekçe ve öncesi/sonrasıyla; tür, tarih süzgeci ve sayfalama', async () => {
  const c = await giris('mod');
  await adminEkle('icerik', 'content');
  const ci = await giris('icerik');
  const k = await istek('/admin/v1/catalog/categories', { yontem: 'POST', govde: { name: 'İz Deneme Kategorisi' }, cerez: ci });
  assert.ok([200, 201].includes(k.durum), k.ham);
  const kid = k.json.id;
  assert.equal((await istek(`/admin/v1/catalog/categories/${kid}`, { yontem: 'PATCH', govde: { name: 'İz Deneme 2' }, cerez: ci })).durum, 200);
  assert.equal((await istek(`/admin/v1/catalog/categories/${kid}`, { yontem: 'DELETE', govde: { reason: 'Deneme bitti' }, cerez: ci })).durum, 204);

  const tum = (await istek(`/admin/v1/admins/${admin.icerik.id}/activity`, { cerez: admin.patron.cerez })).json.items;
  const islemler = tum.map((x) => x.action);
  for (const a of ['catalog.category.create', 'catalog.category.update', 'catalog.category.delete', 'auth.login']) assert.ok(islemler.includes(a), a);
  const guncelle = tum.find((x) => x.action === 'catalog.category.update');
  assert.equal(guncelle.before.name, 'İz Deneme Kategorisi');
  assert.equal(guncelle.after.name, 'İz Deneme 2');
  assert.equal(tum.find((x) => x.action === 'catalog.category.delete').reason, 'Deneme bitti');
  assert.ok(tum.every((x) => x.adminId === admin.icerik.id), 'yalnız o yönetici');

  const katalog = (await istek(`/admin/v1/admins/${admin.icerik.id}/activity?type=catalog`, { cerez: admin.patron.cerez })).json.items;
  assert.ok(katalog.length >= 3 && katalog.every((x) => x.action.startsWith('catalog.')));
  const yarin = new Date(Date.now() + 2 * 86400000).toISOString().slice(0, 10);
  assert.equal((await istek(`/admin/v1/admins/${admin.icerik.id}/activity?from=${yarin}`, { cerez: admin.patron.cerez })).json.items.length, 0);
  const s1 = (await istek(`/admin/v1/admins/${admin.icerik.id}/activity?limit=2`, { cerez: admin.patron.cerez })).json;
  assert.equal(s1.items.length, 2);
  assert.ok(s1.nextBefore);
  const s2 = (await istek(`/admin/v1/admins/${admin.icerik.id}/activity?limit=2&before=${s1.nextBefore}`, { cerez: admin.patron.cerez })).json;
  assert.ok(s2.items.every((x) => x.id < s1.nextBefore));

  const genel = (await istek(`/admin/v1/audit-log?adminId=${admin.icerik.id}`, { cerez: admin.patron.cerez })).json;
  assert.ok(genel.length >= 4 && genel.every((x) => x.adminId === admin.icerik.id && x.adminName === 'icerik'));
  void c;
});

test('yalnız süper admin görür', async () => {
  const c = await giris('mod');
  for (const y of ['detail', 'sessions', 'activity']) {
    assert.equal((await istek(`/admin/v1/admins/${admin.patron.id}/${y}`, { cerez: c })).durum, 403, y);
  }
  assert.equal((await istek('/admin/v1/audit-log', { cerez: c })).durum, 403);
  assert.equal((await istek(`/admin/v1/admins/${randomUUID()}/detail`, { cerez: admin.patron.cerez })).durum, 404);
});
