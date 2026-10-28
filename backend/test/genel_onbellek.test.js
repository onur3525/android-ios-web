// Herkese açık yanıt önbelleği (28 Eki): süre, tek uçuş, nesil (yarış),
// hata/bayat veri, dondurma ve admin değişikliğinde ANINDA geçersiz kılma.
import { test, before, after, mock } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { simdi } = await import('../src/db.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const oc = await import('../src/genel_onbellek.js');
import { degisiklikOnayi, onayKimligi } from './admin_onay.js';

let db, sunucu, taban, cerez;

async function istek(yol, { yontem = 'GET', govde, basliklar = {} } = {}) {
  await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: cerez ?? '', ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const t = await r.text();
  let j = null; try { j = t ? JSON.parse(t) : null; } catch { j = t; }
  return { durum: r.status, json: j };
}

const ertelenmis = () => { let coz, red; const s = new Promise((a, b) => { coz = a; red = b; }); return { s, coz, red }; };

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
    .run(randomUUID(), 'onbellek@hc.test', 'O', sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' },
    body: JSON.stringify({ email: 'onbellek@hc.test', password: 'GucluSifre12345' }),
  });
  cerez = g.headers.get('set-cookie').split(';')[0];
  await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: totpUret(sir) } });
  onayKimligi(cerez, 'GucluSifre12345', sir);
});
after(async () => { sunucu?.close(); await db?.close(); });

// ── Birim davranışları ──

test('tek uçuş: aynı anahtara eşzamanlı 50 istek TEK yükleme yapar', async () => {
  oc.onbellekTemizle();
  let n = 0; const e = ertelenmis();
  const sozler = Array.from({ length: 50 }, () => oc.onbellekten('t:tek', () => { n += 1; return e.s; }));
  e.coz({ a: 1 });
  const sonuclar = await Promise.all(sozler);
  assert.equal(n, 1);
  assert.ok(sonuclar.every((x) => x.a === 1));
  await oc.onbellekten('t:tek', () => { n += 1; return { a: 2 }; });
  assert.equal(n, 1, 'süre dolmadan yeniden yüklenmez');
});

test('süre: 60 sn dolunca yeniden yüklenir; dolmadan yüklenmez', async () => {
  oc.onbellekTemizle();
  mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  try {
    let n = 0; const y = async () => ({ n: ++n });
    assert.equal((await oc.onbellekten('t:sure', y)).n, 1);
    mock.timers.tick(oc.ONBELLEK_TTL_MS - 1);
    assert.equal((await oc.onbellekten('t:sure', y)).n, 1);
    mock.timers.tick(2);
    assert.equal((await oc.onbellekten('t:sure', y)).n, 2);
  } finally { mock.timers.reset(); }
});

test('nesil: temizlikten önce başlayan okuma sonucunu önbelleğe YAZMAZ', async () => {
  oc.onbellekTemizle();
  const e = ertelenmis();
  const eski = oc.onbellekten('t:nesil', () => e.s);
  oc.onbellekTemizle(); // ör. admin değişikliği, okuma sürerken
  e.coz({ surum: 'eski' });
  assert.equal((await eski).surum, 'eski', 'bekleyen istek yanıtını yine alır');
  const yeni = await oc.onbellekten('t:nesil', async () => ({ surum: 'yeni' }));
  assert.equal(yeni.surum, 'yeni', 'eski sonuç takılı kalmadı');
});

test('nesil: temizlikten sonra gelen istek eski uçuşa katılmaz', async () => {
  oc.onbellekTemizle();
  const e = ertelenmis(); let n = 0;
  const eski = oc.onbellekten('t:katilma', () => { n += 1; return e.s; });
  oc.onbellekTemizle();
  const yeni = oc.onbellekten('t:katilma', async () => { n += 1; return { v: 'yeni' }; });
  e.coz({ v: 'eski' });
  assert.equal((await eski).v, 'eski');
  assert.equal((await yeni).v, 'yeni');
  assert.equal(n, 2);
});

test('hata: elde ≤5 dk veri varsa bayat veri döner; yoksa hata aynen iletilir', async () => {
  oc.onbellekTemizle();
  mock.timers.enable({ apis: ['Date'], now: 2_000_000 });
  try {
    await oc.onbellekten('t:hata', async () => ({ v: 1 }));
    mock.timers.tick(oc.ONBELLEK_TTL_MS + 1);
    const b = await oc.onbellekten('t:hata', async () => { throw new Error('veritabanı yok'); });
    assert.equal(b.v, 1, 'bayat veri');
    mock.timers.tick(5 * 60_000);
    await assert.rejects(oc.onbellekten('t:hata', async () => { throw new Error('veritabanı yok'); }), /veritabanı yok/);
    await assert.rejects(oc.onbellekten('t:yok', () => { throw new Error('ilk yükleme'); }), /ilk yükleme/, 'senkron hata da iletilir');
    await oc.onbellekten('t:yok', async () => ({ v: 'toparlandı' }));
  } finally { mock.timers.reset(); }
});

test('hata: admin temizliğinden sonra eski veri bayat olarak da sunulmaz', async () => {
  oc.onbellekTemizle();
  await oc.onbellekten('t:temiz', async () => ({ v: 'eski' }));
  oc.onbellekTemizle();
  await assert.rejects(oc.onbellekten('t:temiz', async () => { throw new Error('düştü'); }), /düştü/);
});

test('undefined önbelleğe alınmaz; değerler dondurulur', async () => {
  oc.onbellekTemizle();
  let n = 0;
  await oc.onbellekten('t:undef', async () => { n += 1; return undefined; });
  await oc.onbellekten('t:undef', async () => { n += 1; return undefined; });
  assert.equal(n, 2);
  const d = await oc.onbellekten('t:donuk', async () => ({ ic: { liste: [1] } }));
  assert.ok(Object.isFrozen(d) && Object.isFrozen(d.ic) && Object.isFrozen(d.ic.liste));
});

// ── Uçtan uca (HTTP) ──

test('katalog: ikinci istek veritabanına gitmez; yanıt biçimi aynı kalır', async () => {
  oc.onbellekTemizle();
  const once = oc.onbellekDurumu();
  const a = await istek('/api/v1/categories');
  const b = await istek('/api/v1/categories');
  const sonra = oc.onbellekDurumu();
  assert.equal(a.durum, 200);
  assert.deepEqual(a.json, b.json);
  assert.ok(Array.isArray(a.json.items) && Array.isArray(a.json.roofs));
  assert.equal(sonra.iskalama - once.iskalama, 1);
  assert.equal(sonra.isabet - once.isabet, 1);
});

test('admin katalog değişikliği ANINDA görünür (60 sn beklenmez)', async () => {
  await istek('/api/v1/categories'); // önbelleğe al
  const k = await istek('/admin/v1/catalog/categories', { yontem: 'POST', govde: { name: 'Önbellek Deneme Kategorisi' } });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  const h = await istek(`/admin/v1/catalog/categories/${k.json.id}/services`, { yontem: 'POST', govde: { name: 'Önbellek Deneme Hizmeti' } });
  assert.equal(h.durum, 200, JSON.stringify(h.json));
  const c = await istek('/api/v1/categories');
  const bulunan = c.json.items.find((x) => x.category === 'Önbellek Deneme Kategorisi');
  assert.deepEqual(bulunan?.services, ['Önbellek Deneme Hizmeti']);
});

test('başarısız admin isteği de önbelleği temizler (yarım kalan değişiklik riski yok)', async () => {
  await istek('/api/v1/categories');
  const t0 = oc.onbellekDurumu().temizlik;
  const r = await istek('/admin/v1/catalog/categories', { yontem: 'POST', govde: { name: '' } });
  assert.equal(r.durum, 400);
  assert.ok(oc.onbellekDurumu().temizlik > t0);
});

test('admin GET istekleri önbelleği temizlemez', async () => {
  await istek('/api/v1/categories');
  const t0 = oc.onbellekDurumu().temizlik;
  await istek('/admin/v1/catalog/categories');
  assert.equal(oc.onbellekDurumu().temizlik, t0);
});

test('yasal: 404 önbelleğe girmez; yayınlanan ve güncellenen sürüm ANINDA görünür', async () => {
  const slug = 'onbellek-belgesi';
  assert.equal((await istek(`/api/v1/legal/${slug}`)).durum, 404);
  const liste0 = await istek('/api/v1/legal');
  assert.ok(!liste0.json.some((x) => x.slug === slug));
  assert.equal((await istek('/admin/v1/legal', { yontem: 'POST', govde: { slug, title: 'Önbellek Belgesi' } })).durum, 200);
  const v1 = await istek(`/admin/v1/legal/${slug}/versions`, { yontem: 'POST', govde: { publish: true, body: 'Birinci sürüm metni, önbellek denemesi için yazıldı.' } });
  assert.equal(v1.durum, 200, JSON.stringify(v1.json));
  const a = await istek(`/api/v1/legal/${slug}`);
  assert.equal(a.durum, 200, 'önceki 404 takılı kalmadı');
  assert.equal(a.json.version, '1');
  assert.deepEqual((await istek(`/api/v1/legal/${slug}`)).json, a.json);
  assert.ok((await istek('/api/v1/legal')).json.some((x) => x.slug === slug && x.version === '1'));
  const v2 = await istek(`/admin/v1/legal/${slug}/versions`, { yontem: 'POST', govde: { publish: true, body: 'İkinci sürüm metni, önbellek denemesi için yazıldı.' } });
  assert.equal(v2.durum, 200, JSON.stringify(v2.json));
  assert.equal((await istek(`/api/v1/legal/${slug}`)).json.version, '2');
  assert.ok((await istek('/api/v1/legal')).json.some((x) => x.slug === slug && x.version === '2'));
  assert.equal((await istek('/api/v1/legal/olmayan-belge')).durum, 404);
  assert.equal((await istek('/api/v1/legal/support')).durum, 200);
});

test('ayar: bakım açılınca ANINDA görünür; kişiye özel alanlar önbellekten sızmaz', async () => {
  const once = await istek('/api/v1/config/app?platform=android');
  assert.equal(once.json.maintenance.active, false);
  const r = await istek('/admin/v1/maintenance', { yontem: 'PUT', govde: { active: true, message: 'Önbellek testi bakımı' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const a = await istek('/api/v1/config/app?platform=android');
  assert.equal(a.json.maintenance.active, true);
  assert.equal(a.json.maintenance.message, 'Önbellek testi bakımı');
  // Oturumsuz/cihazsız istek: kişiye özel alan YOK (başka isteğin sonucu sızmaz).
  assert.equal(a.json.maintenance.bypass, undefined);
  assert.equal(a.json.maintenance.testerDevice, undefined);
  await istek('/admin/v1/maintenance', { yontem: 'PUT', govde: { active: false } });
  assert.equal((await istek('/api/v1/config/app?platform=android')).json.maintenance.active, false);
  assert.equal((await istek('/api/v1/config/app?platform=solaris')).durum, 400);
});

test('admin dışı (doğrudan veritabanı) değişiklik en geç süre dolunca görünür', async () => {
  oc.onbellekTemizle();
  mock.timers.enable({ apis: ['Date'], now: Date.now() });
  try {
    await istek('/api/v1/regions/tree');
    await db.prepare('UPDATE cities SET name = ? WHERE deleted_at IS NULL').run('Önbellek İli');
    assert.notEqual((await istek('/api/v1/regions/tree')).json.cities[0].name, 'Önbellek İli', 'süre içinde önbellekten');
    mock.timers.tick(oc.ONBELLEK_TTL_MS + 1);
    assert.equal((await istek('/api/v1/regions/tree')).json.cities[0].name, 'Önbellek İli');
  } finally { mock.timers.reset(); }
});
