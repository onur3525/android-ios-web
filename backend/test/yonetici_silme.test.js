// YÖNETİCİ SİLME (22 Eki, kullanıcı kararı): süper yönetici diğer yönetici
// hesaplarını siler. Kendini ve son etkin süper yöneticiyi silemez; geçmiş
// (denetim kaydı) korunur; aynı e-posta yeniden kullanılabilir.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

const SIFRE = 'GucluSifre12345';
let db, sunucu, taban;
const hesaplar = {};

async function istek(yol, { yontem = 'GET', govde, kim = 'super' } = {}) {
  const c = hesaplar[kim]?.cerez;
  await degisiklikOnayi(taban, yol, yontem, c);
  const r = await fetch(taban + yol, { method: yontem, headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', ...(c ? { Cookie: c } : {}) }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function yonetici(kim, rol) {
  const sir = base32Uret(); const id = randomUUID();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, `${kim}@sil.test`, kim, rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
  await db.prepare('DELETE FROM rate_limits').run();
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: `${kim}@sil.test`, password: SIFRE }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  onayKimligi(c, SIFRE, sir);
  hesaplar[kim] = { id, cerez: c, sir };
}

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  await yonetici('super', 'super_admin');
  await yonetici('mod', 'moderator');
  await yonetici('okur', 'readonly');
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('yalnız süper yönetici siler; gerekçe zorunlu; kendini silemez', async () => {
  assert.equal((await istek(`/admin/v1/admins/${hesaplar.okur.id}`, { yontem: 'DELETE', govde: { reason: 'deneme gerekçesi' }, kim: 'mod' })).durum, 403);
  assert.equal((await istek(`/admin/v1/admins/${hesaplar.okur.id}`, { yontem: 'DELETE', govde: {} })).durum, 400);
  const k = await istek(`/admin/v1/admins/${hesaplar.super.id}`, { yontem: 'DELETE', govde: { reason: 'deneme gerekçesi' } });
  assert.equal(k.durum, 409);
  assert.match(k.json.error.message, /Kendi hesabınızı/);
});

test('silinen yönetici: listeden kalkar, oturumu düşer, giriş yapamaz, düzenlenemez; denetim kaydı eski e-postayı tutar', async () => {
  const r = await istek(`/admin/v1/admins/${hesaplar.mod.id}`, { yontem: 'DELETE', govde: { reason: 'görevden ayrıldı' } });
  assert.equal(r.durum, 204);
  const liste = (await istek('/admin/v1/admins')).json;
  assert.ok(!liste.some((a) => a.id === hesaplar.mod.id));
  const me = await fetch(`${taban}/admin/v1/auth/me`, { headers: { Cookie: hesaplar.mod.cerez } });
  assert.equal(me.status, 401, 'açık oturum kapandı');
  await db.prepare('DELETE FROM rate_limits').run();
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'mod@sil.test', password: SIFRE }) });
  assert.equal(g.status, 401, 'silinen hesapla giriş yok');
  assert.equal((await istek(`/admin/v1/admins/${hesaplar.mod.id}`, { yontem: 'PATCH', govde: { active: true } })).durum, 404, 'yeniden etkinleştirilemez');
  assert.equal((await istek(`/admin/v1/admins/${hesaplar.mod.id}`, { yontem: 'DELETE', govde: { reason: 'ikinci kez' } })).durum, 404);
  const d = await db.prepare("SELECT before_json, reason FROM audit_log WHERE action = 'admin.delete' AND target_id = ?").get(hesaplar.mod.id);
  assert.equal(JSON.parse(d.before_json).email, 'mod@sil.test');
  assert.equal(d.reason, 'görevden ayrıldı');
});

test('aynı e-postayla yeniden yönetici eklenebilir', async () => {
  const r = await istek('/admin/v1/admins', { yontem: 'POST', govde: { email: 'mod@sil.test', name: 'Yeni Moderatör', role: 'moderator', password: 'YeniGucluSifre123' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
});

test('süper yönetici başka bir süper yöneticiyi ve pasif süper yöneticiyi silebilir', async () => {
  await yonetici('super2', 'super_admin');
  // super2, super'i siler (super2 hâlâ etkin) → izin verilir.
  assert.equal((await istek(`/admin/v1/admins/${hesaplar.super.id}`, { yontem: 'DELETE', govde: { reason: 'devir teslim' }, kim: 'super2' })).durum, 204);
  // (Son etkin süper yönetici kuralı: silen kişi her zaman etkin bir süper
  // yönetici olduğundan kendini silme yasağıyla birlikte hiç süper yöneticisiz kalınmaz.)
  const id = randomUUID();
  await db.prepare("INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, active, created_at) VALUES (?, 'pasif@sil.test', 'P', 'super_admin', ?, NULL, FALSE, ?)").run(id, sifreOzetle(SIFRE), simdi());
  assert.equal((await istek(`/admin/v1/admins/${id}`, { yontem: 'DELETE', govde: { reason: 'pasif hesap' }, kim: 'super2' })).durum, 204, 'pasif süper yönetici silinebilir (etkin olan kalıyor)');
});
