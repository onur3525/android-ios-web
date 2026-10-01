// Uçtan uca: gerçek HTTP sunucusu + bellek içi SQLite + GERÇEK Flutter verisi.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { veritabaniAc, simdi } from '../src/db.js';
import { uygulamaKur } from '../src/server.js';
import { tohumla, flutterVerisiniOku } from '../scripts/seed_from_flutter.js';
import { base32Uret, sifreOzetle, sirSifrele, totpUret } from '../src/auth.js';

let db, sunucu, taban;
const SIFRE = 'GucluSifre12345';
const sirlar = {};

async function adminEkle(email, rol) {
  const sir = base32Uret();
  sirlar[email] = sir;
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .run(randomUUID(), email, email, rol, sifreOzetle(SIFRE), sirSifrele(sir), simdi());
}

async function istek(yol, { yontem = 'GET', govde, cerez, csrf = true } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde ? { 'Content-Type': 'application/json' } : {}),
      ...(cerez ? { Cookie: cerez } : {}),
      ...(csrf && yontem !== 'GET' ? { 'X-HC-Admin': '1' } : {}),
    },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const metin = await r.text();
  return { durum: r.status, json: metin ? JSON.parse(metin) : null, setCookie: r.headers.get('set-cookie') };
}

async function girisYap(email) {
  const a = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email, password: SIFRE } });
  assert.equal(a.durum, 200);
  const cerez = a.setCookie.split(';')[0];
  const b = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: totpUret(sirlar[email]) }, cerez });
  assert.equal(b.durum, 200, JSON.stringify(b.json));
  return cerez;
}

before(async () => {
  // CI'da aynı testler gerçek PostgreSQL'e karşı da koşar:
  //   HC_TEST_DB=postgres HC_DATABASE_URL=postgres://... npm test
  db = process.env.HC_TEST_DB === 'postgres'
    ? await veritabaniAc({ surucu: 'postgres', url: process.env.HC_DATABASE_URL, ssl: false })
    : await veritabaniAc({ surucu: 'sqlite', yol: ':memory:' });
  await tohumla(db);
  await adminEkle('super@hc.test', 'super_admin');
  await adminEkle('icerik@hc.test', 'content');
  await adminEkle('okur@hc.test', 'readonly');
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  sunucu.close();
  await db.close();
});

test('başlangıç verisi Flutter kaynağıyla birebir (demo değil)', async () => {
  const v = flutterVerisiniOku();
  const r = await istek('/api/v1/categories');
  assert.equal(r.durum, 200);
  assert.equal(r.json.items.length, v.katalog.size);
  const ilk = [...v.katalog.entries()][0];
  assert.equal(r.json.items[0].category, ilk[0], 'sıra korunmalı');
  assert.deepEqual(r.json.items[0].services, ilk[1]);
  let toplam = 0;
  for (const k of r.json.items) toplam += k.services.length;
  let beklenen = 0;
  for (const [, l] of v.katalog) beklenen += l.length;
  assert.equal(toplam, beklenen);
});

test('bölge ağacı istemci biçiminde, İzmir 30 ilçe', async () => {
  const r = await istek('/api/v1/regions/tree');
  assert.equal(r.json.cities.length, 1);
  assert.equal(r.json.cities[0].name, 'İzmir');
  assert.equal(r.json.cities[0].districts.length, 30);
  const d = r.json.cities[0].districts[0];
  assert.ok('allDistrictsSupported' in d && Array.isArray(d.neighborhoods));
});

test('destek ve ayar uçları istemci biçiminde', async () => {
  const d = await istek('/api/v1/legal/support');
  assert.equal(d.json.email, 'destek@hizmetcep.com');
  const c = await istek('/api/v1/config/app?platform=web');
  assert.deepEqual(Object.keys(c.json).sort(), ['maintenance', 'release']);
  assert.equal(c.json.maintenance.active, false);
});

test('oturumsuz admin isteği 401, CSRF başlıksız yazma 403', async () => {
  assert.equal((await istek('/admin/v1/catalog/categories')).durum, 401);
  const c = await girisYap('super@hc.test');
  const r = await istek('/admin/v1/catalog/categories', { yontem: 'POST', govde: { name: 'X Deneme' }, cerez: c, csrf: false });
  assert.equal(r.durum, 403);
});

test('yanlış TOTP reddedilir; mfa aşamasındaki oturum tam yetki vermez', async () => {
  const a = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'okur@hc.test', password: SIFRE } });
  const cerez = a.setCookie.split(';')[0];
  assert.equal((await istek('/admin/v1/auth/me', { cerez })).durum, 401);
  const b = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: '000000' }, cerez });
  assert.equal(b.durum, 401);
});

test('kategori ekle → hizmet ekle → kullanıcı API\'sinde görünür; pasif hizmet gizlenir', async () => {
  const c = await girisYap('icerik@hc.test');
  const k = await istek('/admin/v1/catalog/categories', { yontem: 'POST', govde: { name: 'Admin Test Kategorisi' }, cerez: c });
  assert.equal(k.durum, 200);
  const h1 = await istek(`/admin/v1/catalog/categories/${k.json.id}/services`, { yontem: 'POST', govde: { name: 'Hizmet A' }, cerez: c });
  const h2 = await istek(`/admin/v1/catalog/categories/${k.json.id}/services`, { yontem: 'POST', govde: { name: 'Hizmet B' }, cerez: c });
  assert.equal(h2.durum, 200);
  let pub = (await istek('/api/v1/categories')).json.items.find((x) => x.category === 'Admin Test Kategorisi');
  assert.deepEqual(pub.services, ['Hizmet A', 'Hizmet B']);
  await istek(`/admin/v1/catalog/services/${h1.json.id}`, { yontem: 'PATCH', govde: { active: false }, cerez: c });
  pub = (await istek('/api/v1/categories')).json.items.find((x) => x.category === 'Admin Test Kategorisi');
  assert.deepEqual(pub.services, ['Hizmet B']);
  // gerekçesiz silme reddedilir
  assert.equal((await istek(`/admin/v1/catalog/categories/${k.json.id}`, { yontem: 'DELETE', govde: {}, cerez: c })).durum, 400);
  assert.equal((await istek(`/admin/v1/catalog/categories/${k.json.id}`, { yontem: 'DELETE', govde: { reason: 'Test temizliği' }, cerez: c })).durum, 204);
  pub = (await istek('/api/v1/categories')).json.items.find((x) => x.category === 'Admin Test Kategorisi');
  assert.equal(pub, undefined);
});

test('salt okunur rol yazamaz', async () => {
  const c = await girisYap('okur@hc.test');
  assert.equal((await istek('/admin/v1/catalog/categories', { cerez: c })).durum, 200);
  assert.equal((await istek('/admin/v1/catalog/categories', { yontem: 'POST', govde: { name: 'Yasak' }, cerez: c })).durum, 403);
});

test('mahalle pasif → ağaçta active:false', async () => {
  const c = await girisYap('icerik@hc.test');
  const iller = (await istek('/admin/v1/regions/cities', { cerez: c })).json;
  const ilce = (await istek(`/admin/v1/regions/districts?cityId=${iller[0].id}`, { cerez: c })).json[0];
  const mah = (await istek(`/admin/v1/regions/neighborhoods?districtId=${ilce.id}`, { cerez: c })).json[0];
  const p = await istek(`/admin/v1/regions/neighborhoods/${mah.id}`, { yontem: 'PATCH', govde: { active: false }, cerez: c });
  assert.equal(p.json.active, false);
  const agac = (await istek('/api/v1/regions/tree')).json;
  const bulunan = agac.cities[0].districts.find((d) => d.id === ilce.id).neighborhoods.find((m) => m.id === mah.id);
  assert.equal(bulunan.active, false);
});

test('yasal: taslak → yayın (yeniden doğrulama) → kullanıcıya görünür; eski sürüm arşivde kalır', async () => {
  const c = await girisYap('icerik@hc.test');
  const v1 = await istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { body: 'KVKK aydınlatma metni sürüm bir — gerçek metin admin tarafından girilir.' }, cerez: c });
  assert.equal(v1.json.status, 'DRAFT');
  assert.equal((await istek('/api/v1/legal/kvkk')).durum, 404, 'taslak görünmez');
  // Giriş sırasında reauth_at yazıldı → 5 dk içinde yayın serbest
  const y1 = await istek('/admin/v1/legal/kvkk/versions/1/publish', { yontem: 'POST', govde: {}, cerez: c });
  assert.equal(y1.json.status, 'PUBLISHED');
  const v2 = await istek('/admin/v1/legal/kvkk/versions', { yontem: 'POST', govde: { body: 'KVKK aydınlatma metni sürüm iki — güncellenmiş metin admin tarafından girilir.' }, cerez: c });
  await istek(`/admin/v1/legal/kvkk/versions/${v2.json.version}/publish`, { yontem: 'POST', govde: {}, cerez: c });
  const pub = (await istek('/api/v1/legal/kvkk')).json;
  assert.equal(pub.version, '2');
  const surumler = (await istek('/admin/v1/legal/kvkk/versions', { cerez: c })).json;
  assert.deepEqual(surumler.map((s) => s.status), ['PUBLISHED', 'ARCHIVED']);
  assert.match(surumler[0].sha256, /^[0-9a-f]{64}$/);
  await assert.rejects(db.prepare('DELETE FROM legal_versions').run(), /silinemez/);
});

test('iade belgesi (kalıntı) kullanıcıya yayınlanmaz', async () => {
  assert.equal((await istek('/api/v1/legal/refund')).durum, 404);
});

test('bakım modu yeniden doğrulama ister; süresi geçince reddedilir', async () => {
  const c = await girisYap('super@hc.test');
  await db.prepare("UPDATE admin_sessions SET reauth_at = '2000-01-01T00:00:00.000Z'").run();
  const r = await istek('/admin/v1/config/app/web', { yontem: 'PUT', govde: { maintenanceActive: true, maintenanceMessage: 'Planlı bakım yapılıyor' }, cerez: c });
  assert.equal(r.durum, 403);
  assert.equal(r.json.error.code, 'REAUTH_REQUIRED');
  const ra = await istek('/admin/v1/auth/reauth', { yontem: 'POST', govde: { code: totpUret(sirlar['super@hc.test']) }, cerez: c });
  assert.equal(ra.durum, 200);
  const r2 = await istek('/admin/v1/config/app/web', { yontem: 'PUT', govde: { maintenanceActive: true, maintenanceMessage: 'Planlı bakım yapılıyor', minSupportedVersion: '1.0.0' }, cerez: c });
  assert.equal(r2.durum, 200);
  const pub = (await istek('/api/v1/config/app?platform=web')).json;
  assert.equal(pub.maintenance.active, true);
  assert.equal(pub.release.minSupportedVersion, '1.0.0');
});

test('denetim kaydı yazılır ve değiştirilemez', async () => {
  const c = await girisYap('super@hc.test');
  const kayit = (await istek('/admin/v1/audit-log?limit=500', { cerez: c })).json;
  assert.ok(kayit.some((x) => x.action === 'catalog.category.delete' && x.reason === 'Test temizliği'));
  await assert.rejects(db.prepare('UPDATE audit_log SET reason = NULL').run(), /değiştirilemez/);
});

test('5 yanlış şifre hesabı kilitler', async () => {
  await adminEkle('kilit@hc.test', 'readonly');
  for (let i = 0; i < 5; i++) {
    await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'kilit@hc.test', password: 'yanlis-sifre-123' } });
  }
  const r = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'kilit@hc.test', password: SIFRE } });
  assert.equal(r.durum, 429);
});
