// Katalog görselleri: fotoğraf YALNIZ çatılarda (MEVCUT nesne depolama);
// kategoride yalnız ikon — kategori fotoğrafı ucu yok (22 Eki, kullanıcı kararı).
// Depo olarak bellek içi, yol biçimli S3 benzeri yerel sunucu (yalnız test).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

const depo = new Map();
const s3 = createServer((req, res) => {
  const anahtar = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (req.method === 'PUT') {
    const parca = [];
    req.on('data', (c) => parca.push(c));
    req.on('end', () => { depo.set(anahtar, { tur: req.headers['content-type'], veri: Buffer.concat(parca) }); res.end(); });
  } else if (req.method === 'GET') {
    const o = depo.get(anahtar);
    if (!o) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': o.tur }); res.end(o.veri);
  } else if (req.method === 'DELETE') { depo.delete(anahtar); res.writeHead(204); res.end(); }
});
await new Promise((ok) => s3.listen(0, ok));
process.env.HC_S3_ENDPOINT = `http://127.0.0.1:${s3.address().port}`;
process.env.HC_S3_BUCKET = 'hc';
process.env.HC_S3_PATH_STYLE = 'true';
process.env.HC_S3_ACCESS_KEY_ID = 'TESTANAHTAR123';
process.env.HC_S3_SECRET_ACCESS_KEY = 'testgizlianahtar-yalnizca-test';
process.env.HC_SESSIZ = '1';

const { testDb } = await import('./destek.js');
const { simdi } = await import('../src/db.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { s3ImzaliAdres } = await import('../src/entegrasyon.js');
import { degisiklikOnayi, onayKimligi } from './admin_onay.js';

let db, sunucu, taban, cerez, kat;
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 7)]);
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(200, 3)]);

async function istek(yol, { yontem = 'GET', govde } = {}) {
  await degisiklikOnayi(taban, yol, yontem, cerez);
  const r = await fetch(taban + yol, { method: yontem, headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: cerez ?? '' }, body: govde ? JSON.stringify(govde) : undefined });
  const t = await r.text();
  let j = null; try { j = t ? JSON.parse(t) : null; } catch { j = t; }
  return { durum: r.status, json: j, tur: r.headers.get('content-type'), baslik: r.headers };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
    .run(randomUUID(), 'foto@hc.test', 'F', sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'foto@hc.test', password: 'GucluSifre12345' } });
  cerez = g.baslik.get('set-cookie').split(';')[0];
  await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: totpUret(sir) } });
  onayKimligi(cerez, 'GucluSifre12345', sir);
  kat = (await istek('/admin/v1/catalog/categories')).json[0];
});
after(async () => { sunucu?.close(); s3.close(); await db?.close(); });

test('imza: AWS belge örneği (sanal-host, https) hâlâ birebir', () => {
  const u = s3ImzaliAdres({ endpoint: 'https://s3.amazonaws.com', region: 'us-east-1', bucket: 'examplebucket', accessKeyId: 'AKIAIOSFODNN7EXAMPLE', secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' },
    { yontem: 'GET', anahtar: 'test.txt', sureSn: 86400, simdi: new Date('2013-05-24T00:00:00Z') });
  assert.ok(u.endsWith('X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404'));
});

test('kategori ikonu admin için gerçekten sunulur; yol dışı istek reddedilir', async () => {
  assert.ok(kat.iconUrl);
  const i = await istek(kat.iconUrl);
  assert.equal(i.durum, 200); assert.equal(i.tur, 'image/svg+xml');
  assert.equal((await istek('/katalog-varlik/assets/../backend/src/config.js')).durum, 404);
  assert.equal((await istek('/katalog-varlik/lib/main.dart')).durum, 404);
});

test('yükleme doğrulaması: tür, içerik (sihirli bayt), boyut', async () => {
  const y = (tur, veri) => istek('/admin/v1/catalog/roofs/ev/photo', { yontem: 'POST', govde: { contentType: tur, data: veri.toString('base64') } });
  assert.equal((await y('image/svg+xml', Buffer.from('<svg/>'))).durum, 400);
  assert.equal((await y('image/png', JPEG)).durum, 400, 'tür/içerik uyuşmazlığı');
  assert.equal((await y('image/jpeg', Buffer.concat([JPEG, Buffer.alloc(5 * 1024 * 1024)]))).durum, 400, '5 MB üstü');
});

test('kategoride fotoğraf yok: yükleme/kaldırma ucu yok, admin ve uygulama yanıtında fotoğraf alanı yok', async () => {
  const yukle = await istek(`/admin/v1/catalog/categories/${kat.id}/photo`, { yontem: 'POST', govde: { contentType: 'image/jpeg', data: JPEG.toString('base64') } });
  assert.equal(yukle.durum, 404);
  assert.equal((await istek(`/admin/v1/catalog/categories/${kat.id}/photo`, { yontem: 'DELETE', govde: {} })).durum, 404);
  assert.equal([...depo.keys()].filter((a) => a.includes('katalog/kategori/')).length, 0, 'depoya bir şey yazılmadı');
  for (const alan of ['photo', 'photoRef', 'photoUrl', 'bundledPhotoUrl']) assert.equal(alan in kat, false, alan);
  // Eski kayıtta fotoğraf bağı kalmış olsa bile uygulamaya gitmez.
  await db.prepare('UPDATE categories SET photo_ref = ? WHERE id = ?').run('katalog/kategori/00000000-0000-0000-0000-000000000000.jpg', kat.id);
  const ust = (await istek('/api/v1/categories')).json.items[0];
  assert.equal(ust.category, kat.name);
  assert.equal('photoUrl' in ust, false);
  assert.equal('photoUrl' in (await istek('/admin/v1/catalog/categories')).json[0], false);
  await db.prepare('UPDATE categories SET photo_ref = NULL WHERE id = ?').run(kat.id);
});

test('katalog sırası değişmez', async () => {
  const liste = (await istek('/admin/v1/catalog/categories')).json;
  assert.equal(liste.length, 166);
  assert.equal(liste[0].id, kat.id);
});

// ── ANA SAYFA ÇATILARI (029, 22 Eki) ──
test('çatılar: uygulamadaki 24 çatı ve 166 kategori bağıyla gelir; uygulama yanıtında da var', async () => {
  const r = await istek('/admin/v1/catalog/roofs');
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.roofs.length, 24);
  const ev = r.json.roofs[0];
  assert.equal(ev.key, 'ev');
  assert.equal(ev.name, 'Ev & Yaşam');
  assert.equal(ev.description, 'Tesisatçı, Elektrikçi');
  assert.equal(ev.bundledPhotoUrl, '/katalog-varlik/assets/alanlar/ev.jpg');
  assert.ok(ev.categories.some((k) => k.name === 'Su Tesisatı' && k.iconUrl));
  assert.equal(r.json.roofs.reduce((a, c) => a + c.categories.length, 0), 166);
  assert.deepEqual(r.json.unassigned, []);
  assert.equal(r.json.roofs.find((c) => c.name === 'İnşaat & Dekorasyon').cardLabel, 'İnşaat\nDekorasyon', 'kart kısaltması uygulamadakiyle aynı');
  const f = await istek(ev.bundledPhotoUrl);
  assert.equal(f.durum, 200); assert.equal(f.tur, 'image/jpeg');
  const uyg = (await istek('/api/v1/categories')).json;
  assert.equal(uyg.roofs.length, 24);
  assert.deepEqual(uyg.roofs[0], { key: 'ev', name: 'Ev & Yaşam', description: 'Tesisatçı, Elektrikçi', categories: ev.categories.map((k) => k.name) });
});

test('çatı adı değişir (kart kısaltması kalkar); geçersiz/çakışan ad reddedilir; denetim kaydı', async () => {
  const p = (key, name) => istek(`/admin/v1/catalog/roofs/${key}`, { yontem: 'PATCH', govde: { name } });
  assert.equal((await p('yok', 'Bir Ad')).durum, 404);
  assert.equal((await p('insaat', 'X')).durum, 400, 'çok kısa');
  assert.equal((await p('insaat', 'Ev & Yaşam')).durum, 409, 'başka çatının adı');
  const r = await p('insaat', 'Yapı ve Dekorasyon');
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.name, 'Yapı ve Dekorasyon');
  assert.equal(r.json.cardLabel, null);
  assert.equal((await istek('/api/v1/categories')).json.roofs.find((c) => c.key === 'insaat').name, 'Yapı ve Dekorasyon');
  assert.ok(await db.prepare("SELECT 1 FROM audit_log WHERE action = 'catalog.roof.update' AND target_id = 'insaat'").get());
});

test('çatı fotoğrafı: yükle → uygulamada görünür → değiştir → kaldır (paket fotoğrafına döner)', async () => {
  const y1 = await istek('/admin/v1/catalog/roofs/ev/photo', { yontem: 'POST', govde: { contentType: 'image/jpeg', data: JPEG.toString('base64') } });
  assert.equal(y1.durum, 200, JSON.stringify(y1.json));
  const ilk = y1.json.photoRef;
  const uyg = (await istek('/api/v1/categories')).json.roofs[0];
  assert.equal(uyg.photoUrl, `/api/v1/categories/photo/${ilk}`);
  const g = await istek(uyg.photoUrl);
  assert.equal(g.durum, 200); assert.equal(g.tur, 'image/jpeg');
  const y2 = await istek('/admin/v1/catalog/roofs/ev/photo', { yontem: 'POST', govde: { contentType: 'image/png', data: PNG.toString('base64') } });
  assert.ok(!depo.has(`/hc/${ilk}`), 'eski nesne silinir');
  assert.equal((await istek(`/api/v1/categories/photo/${ilk}`)).durum, 404);
  const k = await istek('/admin/v1/catalog/roofs/ev/photo', { yontem: 'DELETE', govde: {} });
  assert.equal(k.json.photoRef, null);
  assert.ok(!depo.has(`/hc/${y2.json.photoRef}`));
  assert.equal((await istek('/api/v1/categories')).json.roofs[0].photoUrl, undefined);
  assert.equal((await istek('/admin/v1/catalog/roofs/ev/photo', { yontem: 'DELETE', govde: {} })).durum, 409);
  assert.equal((await istek('/admin/v1/catalog/roofs/ev/photo', { yontem: 'POST', govde: { contentType: 'image/svg+xml', data: 'PHN2Zy8+' } })).durum, 400);
});
