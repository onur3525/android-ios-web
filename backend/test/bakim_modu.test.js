// BAKIM MODU (22 Eki, kullanıcı kararı)
//   Duyurular ekranından tek anahtarla bütün platformlar bakıma alınır.
//   Açıkken uygulama API'si 503 MAINTENANCE döner; bakım bilgisi ucu ve
//   yasal metinler açık kalır; admin paneli etkilenmez.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');

let db, sunucu, taban;
const cerezler = {};
async function istek(yol, { yontem = 'GET', govde, rol } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(rol ? { Cookie: cerezler[rol], 'X-HC-Admin': '1' } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, baslik: r.headers };
}
async function adminGiris(rol) {
  const sir = base32Uret();
  await db.prepare('INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(randomUUID(), `${rol}@bakim.test`, rol, rol, sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: `${rol}@bakim.test`, password: 'GucluSifre12345' }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: c, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  cerezler[rol] = c;
}

before(async () => {
  db = await testDb();
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  for (const r of ['super_admin', 'content', 'operations', 'readonly']) await adminGiris(r);
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('yetki: Duyurular rolleri (süper yönetici, içerik) yönetir; diğerleri yapamaz', async () => {
  assert.equal((await istek('/admin/v1/maintenance', { rol: 'content' })).durum, 200);
  assert.equal((await istek('/admin/v1/maintenance', { rol: 'operations' })).durum, 403);
  assert.equal((await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'readonly', govde: { active: false } })).durum, 403);
});

test('bakım açılır: bütün platformlar, uygulama API\'si 503; bakım bilgisi ve yasal metin açık; admin etkilenmez', async () => {
  assert.equal((await istek('/api/v1/categories')).durum, 200, 'önce açık');
  assert.equal((await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'content', govde: { active: true } })).durum, 400, 'mesaj zorunlu');
  const r = await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'content', govde: { active: true, message: 'Planlı bakım çalışması', endAt: '2026-10-23T03:00:00.000Z' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.deepEqual({ ...r.json, updatedAt: undefined }, { active: true, message: 'Planlı bakım çalışması', endAt: '2026-10-23T03:00:00.000Z', platforms: ['android', 'ios', 'web'], updatedAt: undefined });
  for (const p of ['android', 'ios', 'web']) {
    const c = await istek(`/api/v1/config/app?platform=${p}`);
    assert.equal(c.durum, 200);
    assert.deepEqual(c.json.maintenance, { active: true, message: 'Planlı bakım çalışması', endAt: '2026-10-23T03:00:00.000Z' });
  }
  const k = await istek('/api/v1/categories');
  assert.equal(k.durum, 503);
  assert.equal(k.json.error.code, 'MAINTENANCE');
  assert.equal(k.json.error.message, 'Planlı bakım çalışması');
  assert.equal(k.baslik.get('retry-after'), '60');
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5300000000', password: 'x' } })).durum, 503, 'giriş de kapalı');
  assert.equal((await istek('/api/v1/legal')).durum, 200, 'yasal metinler açık');
  assert.equal((await istek('/admin/v1/system/status', { rol: 'super_admin' })).durum, 200, 'admin etkilenmez');
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.on'").get());
});

test('uygulama ayarları kaydı bakımı kapatmaz (bakım alanı gönderilmezse korunur)', async () => {
  const r = await istek('/admin/v1/config/app/web', { yontem: 'PUT', rol: 'operations', govde: { minSupportedVersion: '1.0.0', latestVersion: '1.2.0' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.maintenanceActive, true);
  assert.equal(r.json.maintenanceMessage, 'Planlı bakım çalışması');
  assert.equal(r.json.latestVersion, '1.2.0');
});

test('bakım kapanır: API yeniden açılır, sürüm ayarları korunur', async () => {
  const r = await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'super_admin', govde: { active: false } });
  assert.equal(r.durum, 200);
  assert.equal(r.json.active, false);
  assert.equal((await istek('/api/v1/categories')).durum, 200);
  const c = (await istek('/api/v1/config/app?platform=web')).json;
  assert.equal(c.maintenance.active, false);
  assert.equal(c.release.latestVersion, '1.2.0', 'bakım anahtarı sürüm ayarlarına dokunmaz');
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.off'").get());
});
