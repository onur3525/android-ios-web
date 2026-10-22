// BÖLGELER (22 Eki, kullanıcı kararı): iller SİLİNMEZ — pasif edilir ve
// düzenlenir; ilçeler (değişebildiği için) mahalleleriyle birlikte silinebilir.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { simdi } = await import('../src/db.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { degisiklikOnayi, onayKimligi } = await import('./admin_onay.js');

let db, sunucu, taban, cerez;
async function istek(yol, { yontem = 'GET', govde } = {}) {
  await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, { method: yontem, headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: cerez }, body: govde ? JSON.stringify(govde) : undefined });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const sir = base32Uret();
  await db.prepare("INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, 'b@hc.test', 'B', 'content', ?, ?, ?)")
    .run(randomUUID(), sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'b@hc.test', password: 'GucluSifre12345' }) });
  cerez = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cerez, 'X-HC-Admin': '1' }, body: JSON.stringify({ code: totpUret(sir) }) });
  onayKimligi(cerez, 'GucluSifre12345', sir);
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('il silinmez (409); pasif edilir, yeniden aktif edilir, adı düzenlenir', async () => {
  const il = (await istek('/admin/v1/regions/cities')).json[0];
  const s = await istek(`/admin/v1/regions/cities/${il.id}`, { yontem: 'DELETE', govde: { reason: 'deneme gerekçesi' } });
  assert.equal(s.durum, 409);
  assert.match(s.json.error.message, /İller silinmez/);
  assert.ok(await db.prepare('SELECT 1 FROM cities WHERE id = ? AND deleted_at IS NULL').get(il.id), 'il yerinde');
  assert.ok(Number((await db.prepare('SELECT COUNT(*) n FROM districts WHERE city_id = ? AND deleted_at IS NULL').get(il.id)).n) > 0, 'ilçeler yerinde');
  assert.equal((await istek(`/admin/v1/regions/cities/${il.id}`, { yontem: 'PATCH', govde: { active: false } })).json.active, false);
  assert.equal((await istek(`/admin/v1/regions/cities/${il.id}`, { yontem: 'PATCH', govde: { active: true } })).json.active, true);
  assert.equal((await istek(`/admin/v1/regions/cities/${il.id}`, { yontem: 'PATCH', govde: { name: 'İzmir İli' } })).json.name, 'İzmir İli');
});

test('ilçe mahalleleriyle birlikte silinir; il ve diğer ilçeler etkilenmez', async () => {
  const il = (await istek('/admin/v1/regions/cities')).json[0];
  const ilceler = (await istek(`/admin/v1/regions/districts?cityId=${il.id}`)).json;
  const hedef = ilceler[0];
  const mahalle = Number((await db.prepare('SELECT COUNT(*) n FROM neighborhoods WHERE district_id = ? AND deleted_at IS NULL').get(hedef.id)).n);
  assert.ok(mahalle > 0);
  assert.equal((await istek(`/admin/v1/regions/districts/${hedef.id}`, { yontem: 'DELETE', govde: { reason: 'ilçe kaldırıldı' } })).durum, 204);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM neighborhoods WHERE district_id = ? AND deleted_at IS NULL').get(hedef.id)).n), 0);
  const kalan = (await istek(`/admin/v1/regions/districts?cityId=${il.id}`)).json;
  assert.equal(kalan.length, ilceler.length - 1);
  assert.ok(await db.prepare('SELECT 1 FROM cities WHERE id = ? AND deleted_at IS NULL').get(il.id));
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'region.district.delete' AND target_id = ?").get(hedef.id));
});

// ── HAZIR İL / İLÇE LİSTESİ (22 Eki) ──
test('hazır liste: 81 il, 973 ilçe; kaynak bilgisi; ekli il işaretli', async () => {
  const k = await istek('/admin/v1/regions/catalog');
  assert.equal(k.durum, 200);
  assert.equal(k.json.cities.length, 81);
  assert.equal(k.json.cities.reduce((a, c) => a + c.districtCount, 0), 973);
  assert.match(k.json.source.depo, /github\.com\/muratgozel\/turkey-neighbourhoods/);
  assert.equal(k.json.cities.find((c) => c.code === '34').added, false);
  const ist = (await istek('/admin/v1/regions/catalog/34')).json;
  assert.equal(ist.name, 'İstanbul');
  assert.equal(ist.districts.length, 39);
  assert.equal(ist.cityId, null);
});

test('İstanbul tek seferde ilçeleriyle eklenir; tekrar ekleme atlanır; listede olmayan ad reddedilir', async () => {
  assert.equal((await istek('/admin/v1/regions/import', { yontem: 'POST', govde: { cityCode: '34', districts: ['Kadıköy', 'Uydurma İlçe'] } })).durum, 400);
  assert.equal((await istek('/admin/v1/regions/import', { yontem: 'POST', govde: { cityCode: '99', districts: 'all' } })).durum, 400);
  const r1 = await istek('/admin/v1/regions/import', { yontem: 'POST', govde: { cityCode: '34', districts: ['Kadıköy', 'Üsküdar'] } });
  assert.equal(r1.durum, 200, JSON.stringify(r1.json));
  assert.deepEqual({ ...r1.json, cityId: undefined }, { cityId: undefined, city: 'İstanbul', cityAdded: true, districtsAdded: 2, skipped: 0 });
  const r2 = await istek('/admin/v1/regions/import', { yontem: 'POST', govde: { cityCode: '34', districts: 'all' } });
  assert.deepEqual({ ...r2.json, cityId: undefined }, { cityId: undefined, city: 'İstanbul', cityAdded: false, districtsAdded: 37, skipped: 2 });
  assert.equal(r2.json.cityId, r1.json.cityId, 'aynı il');
  assert.equal((await istek(`/admin/v1/regions/districts?cityId=${r1.json.cityId}`)).json.length, 39);
  assert.ok((await istek('/admin/v1/regions/catalog/34')).json.districts.every((d) => d.added));
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'region.import'").get());
});

test('mevcut il (elle eklenmiş, ilçesiz) listeden ilçeleriyle tamamlanır; ikinci il oluşmaz', async () => {
  const el = await istek('/admin/v1/regions/cities', { yontem: 'POST', govde: { name: 'Ankara' } });
  assert.equal(el.durum, 200);
  const r = await istek('/admin/v1/regions/import', { yontem: 'POST', govde: { cityCode: '06', districts: 'all' } });
  assert.equal(r.json.cityAdded, false);
  assert.equal(r.json.cityId, el.json.id);
  assert.equal(r.json.districtsAdded, 25);
  assert.equal(Number((await db.prepare("SELECT COUNT(*) n FROM cities WHERE name = 'Ankara' AND deleted_at IS NULL").get()).n), 1);
});

test('hazır liste dosyası üretim imajına kopyalanır', async () => {
  const { readFileSync } = await import('node:fs');
  assert.match(readFileSync(new URL('../Dockerfile', import.meta.url), 'utf8'), /^COPY backend\/veri \.\/veri$/m);
});
