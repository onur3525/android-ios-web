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
async function istek(yol, { yontem = 'GET', govde, rol, jeton } = {}) {
  if (rol) await degisiklikOnayi(taban, yol, yontem, cerezler[rol]);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(rol ? { Cookie: cerezler[rol], 'X-HC-Admin': '1' } : {}),
      ...(jeton ? { Authorization: `Bearer ${jeton}` } : {}) },
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
const giris = (phone, password = SIFRE) => istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone, password } });

test('test hesabı: listedeki hesap bakımda giriş yapar ve kullanır; diğerleri bakım ekranında kalır', async () => {
  const testciId = await kullanici('5321112233', 'testci@ornek.test');
  await kullanici('5324445566', 'normal@ornek.test');
  // Bakım açıkken normal hesabın önceden açılmış oturumu da 503 alır.
  await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'super_admin', govde: { active: false } });
  const normalOturum = (await giris('5324445566')).json;
  await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'super_admin', govde: { active: true, message: 'Planlı bakım çalışması' } });

  // Liste yetkisi yalnız süper yönetici.
  assert.equal((await istek('/admin/v1/maintenance/testers', { rol: 'content' })).durum, 403);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'content', govde: { account: 'testci@ornek.test' } })).durum, 403);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: 'yok@ornek.test' } })).durum, 404);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: '123' } })).durum, 400);

  // Listede olmayan: doğru şifreyle bile oturum verilmez.
  const red = await giris('5321112233');
  assert.equal(red.durum, 503);
  assert.equal(red.json.error.code, 'MAINTENANCE');
  assert.equal((await giris('5321112233', 'YanlisSifre1')).durum, 401);

  // E-postayla listeye eklenir (telefonla da bulunur — aynı hesap: 409).
  const ek = await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: 'Testci@Ornek.test' } });
  assert.equal(ek.durum, 200, JSON.stringify(ek.json));
  assert.equal(ek.json.id, testciId);
  assert.equal((await istek('/admin/v1/maintenance/testers', { yontem: 'POST', rol: 'super_admin', govde: { account: '0532 111 22 33' } })).durum, 409);
  assert.deepEqual((await istek('/admin/v1/maintenance/testers', { rol: 'super_admin' })).json.map((u) => u.id), [testciId]);
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.tester.add' AND target_id = ?").get(testciId));

  // Test hesabı giriş yapar, API'yi kullanır; bakım bilgisi ona "bypass" der.
  const g = await giris('5321112233');
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  const jeton = g.json.accessToken;
  assert.equal((await istek('/api/v1/categories', { jeton })).durum, 200);
  assert.equal((await istek('/api/v1/config/app?platform=android', { jeton })).json.maintenance.bypass, true);
  assert.equal('bypass' in (await istek('/api/v1/config/app?platform=android')).json.maintenance, false, 'oturumsuz istekte yok');
  const y = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: g.json.refreshToken } });
  assert.equal(y.durum, 200, 'test hesabının oturumu yenilenir');
  // Erişim jetonunun süresi dolmuş olsa da (imza doğru, oturum açık) test
  // hesabı tanınır; döndürülmüş (iptal) oturumun jetonu tanınmaz.
  const yukOku = (t) => JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString());
  const eski = (t) => jwtImzala({ ...yukOku(t), exp: Math.floor(Date.now() / 1000) - 60 });
  assert.equal((await istek('/api/v1/categories', { jeton: eski(y.json.accessToken) })).durum, 200);
  assert.equal((await istek('/api/v1/config/app?platform=ios', { jeton: eski(y.json.accessToken) })).json.maintenance.bypass, true);
  assert.equal((await istek('/api/v1/categories', { jeton: jeton })).durum, 503, 'yenilemeyle iptal edilen oturum');
  assert.equal((await istek('/api/v1/categories', { jeton: eski(normalOturum.accessToken) })).durum, 503);

  // Normal hesap: API 503; yenileme 503 ama oturum SİLİNMEZ (bakım bitince sürer).
  assert.equal((await istek('/api/v1/categories', { jeton: normalOturum.accessToken })).durum, 503);
  assert.equal('bypass' in (await istek('/api/v1/config/app?platform=web', { jeton: normalOturum.accessToken })).json.maintenance, false);
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: normalOturum.refreshToken } })).durum, 503);
  // Geçersiz jeton istisna sayılmaz.
  assert.equal((await istek('/api/v1/categories', { jeton: 'bozuk' })).durum, 503);

  // Listeden çıkarılınca test hesabı da bakım ekranını görür.
  assert.equal((await istek(`/admin/v1/maintenance/testers/${testciId}`, { yontem: 'DELETE', rol: 'super_admin', govde: {} })).durum, 204);
  assert.equal((await istek('/api/v1/categories', { jeton: y.json.accessToken })).durum, 503);
  assert.equal((await istek(`/admin/v1/maintenance/testers/${testciId}`, { yontem: 'DELETE', rol: 'super_admin', govde: {} })).durum, 404);
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'maintenance.tester.remove' AND target_id = ?").get(testciId));

  // Bakım kapanınca normal hesabın oturumu sürer.
  await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'super_admin', govde: { active: false } });
  assert.equal((await istek('/api/v1/categories', { jeton: normalOturum.accessToken })).durum, 200);
  await istek('/admin/v1/maintenance', { yontem: 'PUT', rol: 'super_admin', govde: { active: true, message: 'Planlı bakım çalışması' } });
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
