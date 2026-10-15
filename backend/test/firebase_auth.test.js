// Firebase Authentication köprüsü: ID token doğrulama ve hesap eşleştirme.
// Gerçek Google sertifikası yerine test anahtarı kullanılır (yöntem aynı:
// RS256 imza + aud/iss/exp denetimi). Gizli anahtar istemciye hiç gitmez.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createSign, generateKeyPairSync } from 'node:crypto';

process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { testSertifikaGetiricisi, firebaseTokenDogrula } = await import('../src/firebase_token.js');

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const KID = 'test-anahtar-1';
testSertifikaGetiricisi(async () => ({ sertifikalar: { [KID]: publicKey.export({ type: 'spki', format: 'pem' }) }, sureSn: 3600 }));

function idToken(yuk, { kid = KID, anahtar = privateKey } = {}) {
  const an = Math.floor(Date.now() / 1000);
  const bas = Buffer.from(JSON.stringify({ alg: 'RS256', kid, typ: 'JWT' })).toString('base64url');
  const govde = Buffer.from(JSON.stringify({
    aud: 'hizmetcep-fe036', iss: 'https://securetoken.google.com/hizmetcep-fe036',
    iat: an - 10, auth_time: an - 10, exp: an + 3600, ...yuk,
  })).toString('base64url');
  const imza = createSign('RSA-SHA256').update(`${bas}.${govde}`).sign(anahtar).toString('base64url');
  return `${bas}.${govde}.${imza}`;
}

let db, sunucu, taban;
async function istek(yol, govde, token) {
  const r = await fetch(taban + yol, {
    method: govde ? 'POST' : 'GET',
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('geçersiz tokenlar reddedilir: yanlış proje, süresi dolmuş, başka anahtar, bozuk', async () => {
  assert.equal(await firebaseTokenDogrula(idToken({ sub: 'u1', aud: 'baska-proje' })), null);
  assert.equal(await firebaseTokenDogrula(idToken({ sub: 'u1', exp: 1000 })), null);
  const yabanci = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;
  assert.equal(await firebaseTokenDogrula(idToken({ sub: 'u1' }, { anahtar: yabanci })), null);
  assert.equal(await firebaseTokenDogrula('a.b.c'), null);
  assert.equal((await firebaseTokenDogrula(idToken({ sub: 'u1' }))).sub, 'u1');
});

test('Firebase telefon doğrulamasıyla kayıt: uid hesaba bağlanır; numara eşleşmezse red', async () => {
  const yanlis = await istek('/api/v1/auth/register', { termsAccepted: true, ageConfirmed: true, phone: '5401112233', password: 'sifre1234', name: 'Fb Kişi', email: 'fb@ornek.com', role: 'CUSTOMER', firebaseIdToken: idToken({ sub: 'fb-uid-1', phone_number: '+905409999999' }) });
  assert.equal(yanlis.durum, 400);
  const r = await istek('/api/v1/auth/register', { termsAccepted: true, ageConfirmed: true, phone: '5401112233', password: 'sifre1234', name: 'Fb Kişi', email: 'fb@ornek.com', role: 'PROVIDER', firebaseIdToken: idToken({ sub: 'fb-uid-1', phone_number: '+905401112233' }) });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = await db.prepare('SELECT firebase_uid, phone_verified, email_verified FROM users WHERE phone = ?').get('5401112233');
  assert.equal(u.firebase_uid, 'fb-uid-1');
  assert.equal(u.email_verified, 0);
  // Aynı Firebase kullanıcısı ikinci hesaba bağlanamaz
  const iki = await istek('/api/v1/auth/register', { termsAccepted: true, ageConfirmed: true, phone: '5401112244', password: 'sifre1234', name: 'Xx Yy', email: 'x@ornek.com', role: 'CUSTOMER', firebaseIdToken: idToken({ sub: 'fb-uid-1', phone_number: '+905401112244' }) });
  assert.equal(iki.durum, 409);
});

test('Firebase oturumu: uid ile giriş; e-posta doğrulanınca hesapta işaretlenir', async () => {
  const r = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-1', email: 'fb@ornek.com', email_verified: true }) });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', null, r.json.accessToken);
  assert.equal(me.json.phone, '5401112233');
  assert.equal(me.json.emailVerified, true);
  assert.deepEqual(me.json.roles, ['PROVIDER']);
});

test('Firebase oturumu: eski (bağsız) hesap doğrulanmış telefonla ilk kez bağlanır; kayıtsız → bulunamadı', async () => {
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, created_at, updated_at)
    VALUES ('11111111-1111-1111-1111-111111111111', '5402223344', 'eski@ornek.com', 'Eski', 'x', TRUE, FALSE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')`).run();
  const r = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-2', phone_number: '+905402223344' }) });
  assert.equal(r.durum, 200);
  assert.equal((await db.prepare('SELECT firebase_uid FROM users WHERE phone = ?').get('5402223344')).firebase_uid, 'fb-uid-2');
  // Başka bir Firebase kullanıcısı aynı hesabı devralamaz
  const devral = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-3', phone_number: '+905402223344' }) });
  assert.equal(devral.durum, 401);
  const yok = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-9', phone_number: '+905409998877' }) });
  assert.equal(yok.durum, 404);
});

test('Firebase\'de doğrulanmış yeni e-posta hesaba işlenir', async () => {
  const r = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-1', email: 'yeni@ornek.com', email_verified: true }) });
  const me = await istek('/api/v1/users/me', null, r.json.accessToken);
  assert.equal(me.json.email, 'yeni@ornek.com');
  assert.equal(me.json.emailVerified, true);
});

test('askıdaki hesap Firebase ile de giremez', async () => {
  await db.prepare(`UPDATE users SET status = 'SUSPENDED' WHERE phone = ?`).run('5402223344');
  const r = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-2', phone_number: '+905402223344' }) });
  assert.equal(r.json.error.code, 'ACCOUNT_SUSPENDED');
});

test('şifre sıfırlama Firebase telefon kanıtıyla', async () => {
  const r = await istek('/api/v1/auth/forgot/complete', { phone: '5401112233', newPassword: 'yeniSifre99', firebaseIdToken: idToken({ sub: 'fb-uid-1', phone_number: '+905401112233' }) });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
});

test('E-posta değiştirme: yalnız hesaba bağlı ve DOĞRULANMIŞ Firebase adresi işlenir', async () => {
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, firebase_uid, created_at, updated_at)
    VALUES ('22222222-2222-2222-2222-222222222222', '5403334455', 'once@ornek.com', 'Degisen', 'x', TRUE, TRUE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, 'fb-uid-e1', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')`).run();
  const oturum = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-e1', phone_number: '+905403334455' }) });
  assert.equal(oturum.durum, 200);
  const erisim = oturum.json.accessToken;
  const yol = '/api/v1/profiles/me/email/change';
  // Firebase doğrulaması olmadan değişiklik YOK
  assert.equal((await istek(yol, { newEmail: 'degisim-yeni@ornek.com' }, erisim)).durum, 400);
  // Doğrulanmamış adres işlenmez
  assert.equal((await istek(yol, { firebaseIdToken: idToken({ sub: 'fb-uid-e1', email: 'degisim-yeni@ornek.com', email_verified: false }) }, erisim)).durum, 409);
  // Başka Firebase kimliğinin token'ı reddedilir
  assert.equal((await istek(yol, { firebaseIdToken: idToken({ sub: 'baska-uid', email: 'degisim-yeni@ornek.com', email_verified: true }) }, erisim)).durum, 403);
  // İstenen adres token'daki adresle aynı olmalı
  assert.equal((await istek(yol, { newEmail: 'farkli@ornek.com', firebaseIdToken: idToken({ sub: 'fb-uid-e1', email: 'degisim-yeni@ornek.com', email_verified: true }) }, erisim)).durum, 409);
  // Doğrulanmış adres işlenir
  const ok = await istek(yol, { newEmail: 'DEGISIM-YENI@ornek.com', firebaseIdToken: idToken({ sub: 'fb-uid-e1', email: 'degisim-yeni@ornek.com', email_verified: true }) }, erisim);
  assert.equal(ok.durum, 200, JSON.stringify(ok.json));
  const u = await db.prepare('SELECT email, email_verified FROM users WHERE id = ?').get('22222222-2222-2222-2222-222222222222');
  assert.equal(u.email, 'degisim-yeni@ornek.com');
  // Başka hesabın adresi alınamaz
  const cak = await istek(yol, { firebaseIdToken: idToken({ sub: 'fb-uid-e1', email: 'eski@ornek.com', email_verified: true }) }, erisim);
  assert.equal(cak.durum, 409);
  // Oturumsuz istek reddedilir
  assert.equal((await istek(yol, { firebaseIdToken: idToken({ sub: 'fb-uid-e1', email: 'x@ornek.com', email_verified: true }) })).durum, 401);
});

test('GÜVENLİK: profil güncellemesiyle doğrulamasız e-posta değişimi reddedilir', async () => {
  await db.prepare(`INSERT INTO users (id, phone, email, name, password_hash, phone_verified, email_verified, roles, active_role, status, terms_accepted, failed_logins, firebase_uid, created_at, updated_at)
    VALUES ('33333333-3333-3333-3333-333333333333', '5404445566', 'sabit@ornek.com', 'Profil', 'x', TRUE, TRUE, 'CUSTOMER', 'CUSTOMER', 'ACTIVE', TRUE, 0, 'fb-uid-p1', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z')`).run();
  const oturum = await istek('/api/v1/auth/firebase/session', { idToken: idToken({ sub: 'fb-uid-p1', phone_number: '+905404445566' }) });
  const r = await fetch(`${taban}/api/v1/profiles/me`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${oturum.json.accessToken}` }, body: JSON.stringify({ email: 'baskasi@ornek.com' }) });
  assert.equal(r.status, 400);
  const u = await db.prepare('SELECT email, email_verified FROM users WHERE id = ?').get('33333333-3333-3333-3333-333333333333');
  assert.equal(u.email, 'sabit@ornek.com'); assert.equal(u.email_verified, 1);
  // Ad güncellemesi aynen çalışır
  const r2 = await fetch(`${taban}/api/v1/profiles/me`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${oturum.json.accessToken}` }, body: JSON.stringify({ name: 'Yeni Ad' }) });
  assert.equal(r2.status, 200);
});
