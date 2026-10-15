// HESAP SİLME — Firebase kimlik kaydı da silinir (15 Eki güvenlik denetimi).
// Önceden yerel hesap anonimleştiriliyor, Firebase kullanıcısı (telefon/e-posta)
// kalıyordu. Firebase çağrısı SAHTE (gerçek ağ yok).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');
const { firebaseSilmeKuyrugunuIsle } = await import('../src/firebase_silme.js');
const { firebaseYonetimTestGondericisi } = await import('../src/firebase_token.js');

async function silinecekKullanici(db, uid) {
  const id = randomUUID();
  const z = simdi();
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role,
                      status, terms_accepted, failed_logins, created_at, updated_at, firebase_uid)
                    VALUES (?, ?, ?, 'Silinecek Kişi', 'x', TRUE, FALSE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, ?, ?, ?)`)
    .run(id, `53${Math.floor(Math.random() * 1e8).toString().padStart(8, '0')}`, `${id}@ornek.com`, z, z, uid);
  await db.prepare(`INSERT INTO account_requests (id, user_id, type, status, created_at, scheduled_for) VALUES (?, ?, 'DELETION', 'PENDING', ?, ?)`)
    .run(randomUUID(), id, z, '2000-01-01T00:00:00.000Z');
  return id;
}

test('silme: Firebase uid kuyruğa yazılır, iş Firebase kullanıcısını siler, kuyruk boşalır', async () => {
  const db = await testDb();
  const uid = `fb-${randomUUID()}`;
  const id = await silinecekKullanici(db, uid);
  await silmeTalepleriniIsle(db);
  const u = await db.prepare('SELECT firebase_uid, deleted_at FROM users WHERE id = ?').get(id);
  assert.equal(u.firebase_uid, null);
  assert.ok(u.deleted_at);
  assert.ok(await db.prepare('SELECT 1 FROM firebase_silme_kuyrugu WHERE uid = ?').get(uid), 'uid kuyruğa yazılmalı');
  const cagrilar = [];
  firebaseYonetimTestGondericisi(async (islem, govde) => { cagrilar.push([islem, govde.localId]); return { ok: true, durum: 200, kod: '' }; });
  try {
    assert.equal(await firebaseSilmeKuyrugunuIsle(db), 1);
  } finally { firebaseYonetimTestGondericisi(null); }
  assert.deepEqual(cagrilar, [['delete', uid]]);
  assert.equal(await db.prepare('SELECT 1 FROM firebase_silme_kuyrugu WHERE uid = ?').get(uid), undefined);
});

test('silme: Firebase hatasında kayıt kalır ve ileri tarihe ertelenir; USER_NOT_FOUND başarı sayılır', async () => {
  const db = await testDb();
  const uid = `fb-${randomUUID()}`;
  await silinecekKullanici(db, uid);
  await silmeTalepleriniIsle(db);
  firebaseYonetimTestGondericisi(async () => ({ ok: false, durum: 503, kod: 'UNAVAILABLE' }));
  try {
    await firebaseSilmeKuyrugunuIsle(db);
    const k = await db.prepare('SELECT * FROM firebase_silme_kuyrugu WHERE uid = ?').get(uid);
    assert.equal(k.deneme, 1);
    assert.ok(Date.parse(k.sonraki_deneme) > Date.now(), 'yeniden deneme ileri tarihe ertelenmeli');
    assert.match(k.son_hata, /HTTP 503/);
    assert.equal(await firebaseSilmeKuyrugunuIsle(db), 0, 'zamanı gelmeden yeniden denenmez');
    await db.prepare('UPDATE firebase_silme_kuyrugu SET sonraki_deneme = ? WHERE uid = ?').run('2000-01-01T00:00:00.000Z', uid);
    firebaseYonetimTestGondericisi(async () => ({ ok: false, durum: 400, kod: 'USER_NOT_FOUND' }));
    await firebaseSilmeKuyrugunuIsle(db);
    assert.equal(await db.prepare('SELECT 1 FROM firebase_silme_kuyrugu WHERE uid = ?').get(uid), undefined);
  } finally { firebaseYonetimTestGondericisi(null); }
});

test('silme: Firebase\'e bağlı olmayan hesapta kuyruğa bir şey yazılmaz', async () => {
  const db = await testDb();
  await silinecekKullanici(db, null);
  await silmeTalepleriniIsle(db);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM firebase_silme_kuyrugu').get()).n), 0);
});
