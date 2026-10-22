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
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');
const { jwtImzala } = await import('../src/jwt.js');

let db, sunucu, taban;
const cerezler = {};
async function istek(yol, { yontem = 'GET', govde, rol, jeton, cihaz } = {}) {
  if (rol) await degisiklikOnayi(taban, yol, yontem, cerezler[rol]);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(rol ? { Cookie: cerezler[rol], 'X-HC-Admin': '1' } : {}),
      ...(jeton ? { Authorization: `Bearer ${jeton}` } : {}),
      ...(cihaz ? { 'X-HC-Cihaz': cihaz, 'X-HC-Platform': 'android' } : {}) },
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
  onayKimligi(c, 'GucluSifre12345', sir);
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
  // 032: giriş ucu kapıdan geçer; karar şifre doğrulandıktan sonra hesaba
  // göre verilir (test hesabı olmayan doğru şifreyle de 503 alır — aşağıda).
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5300000000', password: 'x' } })).durum, 401, 'kayıtsız/yanlış şifre');
  assert.equal((await istek('/api/v1/auth/register', { yontem: 'POST', govde: {} })).durum, 503, 'kayıt kapalı');
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

// ── 032: BAKIMDA TEST HESABI ──
const SIFRE = 'KullaniciSifre1';
async function kullanici(tel, eposta) {
  const id = randomUUID();
  await db.prepare(
    `INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, TRUE, TRUE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`,
  ).run(id, tel, eposta, `K${tel.slice(-2)}`, sifreOzetle(SIFRE), simdi(), simdi());
  return id;
}
const giris = (phone, cihaz, password = SIFRE) => istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone, password }, cihaz });
const CIHAZ_A = 'a'.repeat(43); // uygulamanın ürettiği rastgele kimlik biçimi (base64url)
const CIHAZ_B = 'b'.repeat(43);
const bakim = (active) => istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'super_admin', govde: active ? { active, message: 'Planlı bakım çalışması' } : { active } });
const cihazSayisi = async () => (await db.prepare('SELECT COUNT(*) n FROM maintenance_devices').get()).n;

test('test hesabı: yalnız listedeki hesap, önceden tanınmış cihazından bakımda giriş yapar; kapı yalnız o cihazda açılır', async () => {
  const testciId = await kullanici('5321112233', 'testci@ornek.test');
  await kullanici('5324445566', 'normal@ornek.test');
  await bakim(false);
  const normalOturum = (await giris('5324445566', CIHAZ_B)).json;
  assert.equal(await cihazSayisi(), 0, 'listede olmayan hesabın cihazı kaydedilmez');

  // Liste yetkisi yalnız süper yönetici; e-posta ya da telefonla bulunur.
  assert.equal((await istek('/admin/v1/maintenance/testers', { rol: 'content' })).durum, 403);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'content', govde: { account: 'testci@ornek.test' } })).durum, 403);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: 'yok@ornek.test' } })).durum, 404);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: '123' } })).durum, 400);
  const ek = await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: 'Testci@Ornek.test' } });
  assert.equal(ek.durum, 200, JSON.stringify(ek.json));
  assert.equal(ek.json.id, testciId);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: '0532 111 22 33' } })).durum, 409);
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.tester.add' AND target_id = ?").get(testciId));

  // Bakım kapalıyken giriş cihazı tanıtır; cihaz başlığı yoksa/bozuksa tanıtmaz.
  assert.equal((await giris('5321112233', undefined)).durum, 200);
  assert.equal((await giris('5321112233', 'kisa')).durum, 200);
  assert.equal(await cihazSayisi(), 0);
  assert.equal((await giris('5321112233', CIHAZ_A)).durum, 200);
  assert.equal((await giris('5321112233', CIHAZ_A)).durum, 200);
  assert.equal(await cihazSayisi(), 1, 'aynı cihaz bir kez');
  const kayit = await db.prepare('SELECT * FROM maintenance_devices').get();
  assert.notEqual(kayit.device_hash, CIHAZ_A, 'ham kimlik saklanmaz');
  const liste = (await istek('/admin/v1/maintenance/testers', { rol: 'super_admin' })).json;
  assert.deepEqual(liste.map((u) => [u.id, u.devices.map((d) => d.platform)]), [[testciId, ['android']]]);

  await bakim(true);
  // Gizli kapı yalnız tanınmış cihazda; oturumsuz da bilinir (giriş için).
  const cfg = async (o) => (await istek('/api/v1/config/app?platform=android', o)).json.maintenance;
  assert.equal((await cfg({ cihaz: CIHAZ_A })).testerDevice, true);
  assert.equal('testerDevice' in await cfg({ cihaz: CIHAZ_B }), false);
  assert.equal('testerDevice' in await cfg({}), false);

  // Bakımda: tanınmamış cihazdan, ya da listede olmayan hesapla oturum yok.
  assert.equal((await giris('5321112233', CIHAZ_B)).durum, 503);
  assert.equal((await giris('5321112233', undefined)).durum, 503);
  assert.equal((await giris('5324445566', CIHAZ_A)).json.error.code, 'MAINTENANCE');
  assert.equal((await giris('5321112233', CIHAZ_A, 'YanlisSifre1')).durum, 401);
  assert.equal(await cihazSayisi(), 1, 'bakımda yeni cihaz tanıtılamaz');

  // Tanınmış cihazdan test hesabı girer ve kullanır.
  const g = await giris('5321112233', CIHAZ_A);
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  const jeton = g.json.accessToken;
  assert.equal((await istek('/api/v1/categories', { jeton, cihaz: CIHAZ_A })).durum, 200);
  assert.equal((await istek('/api/v1/categories', { jeton, cihaz: CIHAZ_B })).durum, 503, 'jeton başka cihazda işe yaramaz');
  assert.equal((await istek('/api/v1/categories', { jeton })).durum, 503);
  assert.equal((await cfg({ jeton, cihaz: CIHAZ_A })).bypass, true);
  assert.equal('bypass' in await cfg({ jeton, cihaz: CIHAZ_B }), false);
  const y = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: g.json.refreshToken }, cihaz: CIHAZ_A });
  assert.equal(y.durum, 200, 'test hesabının oturumu yenilenir');

  // Erişim jetonunun süresi dolmuş olsa da (imza doğru, oturum açık) tanınır;
  // döndürülmüş (iptal) oturumun jetonu tanınmaz.
  const yukOku = (t) => JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString());
  const eski = (t) => jwtImzala({ ...yukOku(t), exp: Math.floor(Date.now() / 1000) - 60 });
  assert.equal((await istek('/api/v1/categories', { jeton: eski(y.json.accessToken), cihaz: CIHAZ_A })).durum, 200);
  assert.equal((await istek('/api/v1/categories', { jeton, cihaz: CIHAZ_A })).durum, 503, 'yenilemeyle iptal edilen oturum');

  // Normal hesap: API 503; yenileme 503 ama oturum SİLİNMEZ.
  assert.equal((await istek('/api/v1/categories', { jeton: normalOturum.accessToken, cihaz: CIHAZ_A })).durum, 503);
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: normalOturum.refreshToken }, cihaz: CIHAZ_A })).durum, 503);
  assert.equal((await istek('/api/v1/categories', { jeton: 'bozuk', cihaz: CIHAZ_A })).durum, 503);

  // Cihaz silinince o cihazda kapı da erişim de kapanır.
  const cihazId = liste[0].devices[0].id;
  assert.equal((await istek(`/admin/v1/maintenance/testers/${testciId}/devices/${cihazId}`, { yontem: 'DELETE', rol: 'super_admin', govde: {} })).durum, 204);
  assert.equal((await istek('/api/v1/categories', { jeton: y.json.accessToken, cihaz: CIHAZ_A })).durum, 503);
  assert.equal('testerDevice' in await cfg({ cihaz: CIHAZ_A }), false);
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.device.remove' AND target_id = ?").get(testciId));

  // Listeden çıkarılınca cihazları da silinir.
  await bakim(false);
  await giris('5321112233', CIHAZ_A);
  assert.equal(await cihazSayisi(), 1);
  assert.equal((await istek(`/admin/v1/maintenance/testers/${testciId}`, { yontem: 'DELETE', rol: 'super_admin', govde: {} })).durum, 204);
  assert.equal(await cihazSayisi(), 0);
  assert.equal((await istek(`/admin/v1/maintenance/testers/${testciId}`, { yontem: 'DELETE', rol: 'super_admin', govde: {} })).durum, 404);
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.tester.remove' AND target_id = ?").get(testciId));
  // Bakım kapalıyken normal hesabın oturumu sürer.
  assert.equal((await istek('/api/v1/categories', { jeton: normalOturum.accessToken })).durum, 200);
  await bakim(true);
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
