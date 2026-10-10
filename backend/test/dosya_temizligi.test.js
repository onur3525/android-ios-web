// Kullanıcı dosyalarının fiziksel silinme yaşam döngüsü (sahte depo silicisiyle).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { simdi } = await import('../src/db.js');
const { silinmekUzereIsaretle, dosyaTemizliginiIsle, AZAMI_DENEME } = await import('../src/dosya_temizligi.js');
const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');

let db;
const silinenler = [];
let siliciBasarili = true;
const silici = async (anahtar) => { if (!siliciBasarili) return false; silinenler.push(anahtar); return true; };

async function kullanici(tel) {
  const id = randomUUID();
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
    VALUES (?, ?, NULL, 'T', 'x', TRUE, FALSE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?)`).run(id, tel, simdi(), simdi());
  return id;
}
async function dosya(sahip) {
  const ref = `u/${sahip}/${randomUUID()}.jpg`;
  await db.prepare(`INSERT INTO storage_objects (ref, owner_id, kind, content_type, size_bytes, status, created_at, attached_at) VALUES (?, ?, 'listing-photo', 'image/jpeg', 100, 'ATTACHED', ?, ?)`)
    .run(ref, sahip, simdi(), simdi());
  return ref;
}
let ilanNo = 90000000;
async function ilan(sahip, refler, durum = 'ACTIVE') {
  const id = randomUUID();
  await db.prepare(`INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, status, created_at, expires_at, updated_at)
    VALUES (?, ?, ?, 'Boya', 'Bornova', 'test', ?, ?, ?, ?, ?)`).run(id, String(ilanNo++), sahip, JSON.stringify(refler), durum, simdi(), simdi(), simdi());
  return id;
}
const kayit = (ref) => db.prepare('SELECT * FROM storage_objects WHERE ref = ?').get(ref);

before(async () => { db = await testDb(); });
after(async () => { await db?.close(); });

test('ilan silme: yalnız başka canlı kayıtta kullanılmayan fotoğraf silinir', async () => {
  const a = await kullanici('5550000001');
  const r1 = await dosya(a); const r2 = await dosya(a);
  await ilan(a, [r1, r2], 'USER_DELETED');        // silinen ilan
  await ilan(a, [r2]);                           // r2 başka AÇIK ilanda da var
  // r2 başka açık ilanda kullanıldığı için HİÇ işaretlenmez (o ilanda
  // görünür kalır; işin geri almasını beklemez).
  assert.equal(await silinmekUzereIsaretle(db, [r1, r2], a), 1);
  const k2once = await kayit(r2);
  assert.equal(k2once.status, 'ATTACHED'); assert.equal(k2once.delete_requested_at, null);
  silinenler.length = 0;
  await dosyaTemizliginiIsle(db, { silici });
  assert.deepEqual(silinenler, [r1]);
  assert.ok((await kayit(r1)).deleted_at);
  const k2 = await kayit(r2);
  assert.equal(k2.status, 'ATTACHED'); assert.equal(k2.deleted_at, null);
});

test('işaretlendikten SONRA başka canlı kayda giren dosya: iş silmez, geri alır (ikinci savunma)', async () => {
  const a = await kullanici('5550000009');
  const r = await dosya(a);
  await ilan(a, [r], 'USER_DELETED');
  assert.equal(await silinmekUzereIsaretle(db, [r], a), 1);
  await ilan(a, [r]); // arada yeni açık ilanda kullanıldı
  silinenler.length = 0;
  await dosyaTemizliginiIsle(db, { silici });
  assert.deepEqual(silinenler, []);
  assert.equal((await kayit(r)).status, 'ATTACHED');
});

test('başka kullanıcının dosyası işaretlenemez ve silinmez', async () => {
  const a = await kullanici('5550000002'); const b = await kullanici('5550000003');
  const rb = await dosya(b);
  assert.equal(await silinmekUzereIsaretle(db, [rb, `u/${a}/../${b}/x.jpg`, 'katalog/kategori/x.jpg'], a), 0);
  silinenler.length = 0;
  await dosyaTemizliginiIsle(db, { silici });
  assert.deepEqual(silinenler, []);
  assert.equal((await kayit(rb)).status, 'ATTACHED');
});

test('hesap dondurma dosyalara dokunmaz; hesap silme bütün dosyaları siler (sohbette olsa bile)', async () => {
  const c = await kullanici('5550000004');
  const r1 = await dosya(c); const r2 = await dosya(c);
  await ilan(c, [r1]);
  await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, created_at, scheduled_for) VALUES (?, ?, 'FREEZE', 'PENDING', ?, ?)`)
    .run(randomUUID(), c, simdi(), '2000-01-01T00:00:00.000Z');
  await silmeTalepleriniIsle(db);
  silinenler.length = 0;
  await dosyaTemizliginiIsle(db, { silici });
  assert.deepEqual(silinenler, [], 'dondurma: silme yok');
  await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, created_at, scheduled_for) VALUES (?, ?, 'DELETION', 'PENDING', ?, ?)`)
    .run(randomUUID(), c, simdi(), '2000-01-01T00:00:00.000Z');
  await silmeTalepleriniIsle(db);
  await dosyaTemizliginiIsle(db, { silici });
  assert.deepEqual(new Set(silinenler), new Set([r1, r2]));
  // İdempotent: ikinci tur hiçbir şey silmez
  silinenler.length = 0;
  assert.equal(await dosyaTemizliginiIsle(db, { silici }), 0);
  assert.deepEqual(silinenler, []);
});

test('depo silme başarısız: ana işlem etkilenmez, deneme ve hata kaydı tutulur, sonra yeniden denenir', async () => {
  const d = await kullanici('5550000005');
  const r = await dosya(d);
  await silinmekUzereIsaretle(db, [r], d);
  siliciBasarili = false;
  await dosyaTemizliginiIsle(db, { silici });
  let k = await kayit(r);
  assert.equal(k.delete_attempts, 1); assert.ok(k.delete_error); assert.equal(k.deleted_at, null);
  assert.ok(await db.prepare(`SELECT 1 FROM audit_log WHERE action = 'storage.delete.failed' AND target_id = ?`).get(r));
  siliciBasarili = true;
  await dosyaTemizliginiIsle(db, { silici });
  k = await kayit(r);
  assert.ok(k.deleted_at); assert.equal(k.delete_error, null);
  assert.ok(AZAMI_DENEME >= 3);
});

test('depo yapılandırılmamışsa iş kuyruğa dokunmaz', async () => {
  const e = await kullanici('5550000006');
  const r = await dosya(e);
  await silinmekUzereIsaretle(db, [r], e);
  assert.equal(await dosyaTemizliginiIsle(db), 0);
  const k = await kayit(r);
  assert.equal(k.deleted_at, null); assert.equal(k.delete_attempts, 0);
});
