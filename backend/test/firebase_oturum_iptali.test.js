// FIREBASE OTURUM İPTALİ (15 Eki güvenlik denetimi): şifre sıfırlama, şifre
// değiştirme ve telefon değişikliğinden sonra
//   · sunucu oturumları, yenileme belirteçleri ve gerçek zamanlı bağlantılar
//     (mevcut mekanizma) kapanır,
//   · Firebase yenileme belirteçleri iptal edilir (Admin SDK revokeRefreshTokens
//     ile aynı istek: accounts:update validSince),
//   · işlemden ÖNCE doğrulanmış Firebase belgesiyle yeni sunucu oturumu açılmaz
//     (yerel sınır + Admin SDK checkRevoked ile aynı accounts:lookup denetimi),
//   · telefon değişikliğinde Firebase Auth'taki numara da günceldir.
// Gerçek Firebase'e bağlanılmaz: Google sertifikası yerine test anahtarı,
// Identity Toolkit yerine sahte yönetim kancası kullanılır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createSign, generateKeyPairSync } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { testSertifikaGetiricisi, firebaseYonetimTestGondericisi } = await import('../src/firebase_token.js');
const { olaylar } = await import('../src/olaylar.js');

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const KID = 'iptal-anahtar';
testSertifikaGetiricisi(async () => ({ sertifikalar: { [KID]: publicKey.export({ type: 'spki', format: 'pem' }) }, sureSn: 3600 }));
const an = () => Math.floor(Date.now() / 1000);

function idToken(yuk) {
  const t = an();
  const bas = Buffer.from(JSON.stringify({ alg: 'RS256', kid: KID, typ: 'JWT' })).toString('base64url');
  const govde = Buffer.from(JSON.stringify({
    aud: 'hizmetcep-fe036', iss: 'https://securetoken.google.com/hizmetcep-fe036',
    iat: t - 5, auth_time: t - 5, exp: t + 3600, firebase: { sign_in_provider: 'phone' }, ...yuk,
  })).toString('base64url');
  return `${bas}.${govde}.${createSign('RSA-SHA256').update(`${bas}.${govde}`).sign(privateKey).toString('base64url')}`;
}

// ── Sahte Firebase kullanıcı deposu (Identity Toolkit yönetim uçları) ──
const fbKullanicilar = new Map(); // uid → { validSince, disabled, phoneNumber }
const cagrilar = [];
let yonetimDurumu = 'normal'; // 'normal' | 'kapali'
function sahteYonetim() {
  firebaseYonetimTestGondericisi(async (islem, govde) => {
    cagrilar.push({ islem, govde });
    if (yonetimDurumu === 'kapali') return { ok: false, durum: 503, kod: 'UNAVAILABLE', veri: {} };
    if (islem === 'lookup') {
      const k = fbKullanicilar.get(govde.localId[0]);
      return k ? { ok: true, durum: 200, kod: '', veri: { users: [{ localId: govde.localId[0], ...k, validSince: k.validSince ? String(k.validSince) : undefined }] } }
        : { ok: true, durum: 200, kod: '', veri: {} };
    }
    if (islem === 'delete') {
      fbKullanicilar.delete(govde.localId);
      return { ok: true, durum: 200, kod: '', veri: {} };
    }
    if (islem === 'update') {
      const k = fbKullanicilar.get(govde.localId);
      if (!k) return { ok: false, durum: 400, kod: 'USER_NOT_FOUND', veri: {} };
      if (govde.validSince) k.validSince = Number(govde.validSince);
      if (govde.phoneNumber) {
        if ([...fbKullanicilar.entries()].some(([u, x]) => u !== govde.localId && x.phoneNumber === govde.phoneNumber)) {
          return { ok: false, durum: 400, kod: 'PHONE_NUMBER_EXISTS', veri: {} };
        }
        k.phoneNumber = govde.phoneNumber;
      }
      return { ok: true, durum: 200, kod: '', veri: {} };
    }
    return { ok: false, durum: 400, kod: 'UNSUPPORTED', veri: {} };
  });
}

let db, sunucu, taban;
async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
async function kod(tel, amac) {
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: amac } });
  return globalThis.__sonOtp;
}
/** Firebase'e bağlı hesap + iki sunucu oturumu (iki cihaz). */
async function hesap(tel, uid) {
  fbKullanicilar.set(uid, { validSince: null, disabled: false, phoneNumber: `+90${tel}` });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'İptal Deneme',
    email: `i${tel}@ornek.com`, role: 'CUSTOMER', firebaseIdToken: idToken({ sub: uid, phone_number: `+90${tel}` }) } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const ikinci = await istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: idToken({ sub: uid, phone_number: `+90${tel}` }) } });
  assert.equal(ikinci.durum, 200, JSON.stringify(ikinci.json));
  return { tel, uid, a: r.json, b: ikinci.json };
}
const firebaseOturumu = (uid, tel, ek = {}) => istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: idToken({ sub: uid, phone_number: `+90${tel}`, ...ek }) } });

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  sahteYonetim();
});
after(async () => { firebaseYonetimTestGondericisi(null); sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

test('şifre sıfırlama: sunucu oturumları + yenileme belirteci + soketler kapanır; Firebase belirteçleri iptal; eski belgeyle oturum açılmaz, yenisiyle açılır', async () => {
  const h = await hesap('5390000001', 'fb-iptal-1');
  const eskiAuth = an() - 120; // sıfırlamadan ÖNCE açılmış başka cihazdaki Firebase oturumu
  let yayin = null;
  olaylar.once('user.sessions.revoked', (d) => (yayin = d));
  cagrilar.length = 0;
  const r = await istek('/api/v1/auth/forgot/complete', { yontem: 'POST', govde: { phone: h.tel, otpCode: await kod(h.tel, 'FORGOT'), newPassword: 'YeniSifre26' } });
  assert.equal(r.durum, 204, JSON.stringify(r.json));

  // Mevcut mekanizma bozulmadı: erişim, yenileme ve gerçek zamanlı bağlantı.
  assert.equal((await istek('/api/v1/users/me', { token: h.a.accessToken })).durum, 401);
  assert.equal((await istek('/api/v1/users/me', { token: h.b.accessToken })).durum, 401);
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: h.b.refreshToken } })).durum, 401);
  assert.equal(yayin?.userId, (await db.prepare('SELECT id FROM users WHERE phone = ?').get(h.tel)).id, 'soketleri kapatan olay yayınlandı');

  // Firebase yenileme belirteçleri iptal edildi (validSince yazıldı).
  const iptal = cagrilar.find((c) => c.islem === 'update' && c.govde.localId === h.uid && c.govde.validSince);
  assert.ok(iptal, 'Firebase validSince güncellenmedi');
  assert.ok(Math.abs(Number(iptal.govde.validSince) - an()) <= 5);

  const eski = await firebaseOturumu(h.uid, h.tel, { auth_time: eskiAuth, iat: an() - 5 });
  assert.equal(eski.durum, 401, 'yenilenmiş ama eski kimlik doğrulamalı belge reddedilmeli');
  assert.equal(eski.json.error.code, 'AUTH_REVOKED');
  const yeni = await firebaseOturumu(h.uid, h.tel, { auth_time: an() + 2, iat: an() + 2 });
  assert.equal(yeni.durum, 200, JSON.stringify(yeni.json));
  assert.equal((await istek('/api/v1/users/me', { token: yeni.json.accessToken })).durum, 200);
});

test('şifre değiştirme: işlemi yapan oturum açık kalır, diğerleri ve eski Firebase belgeleri reddedilir', async () => {
  const h = await hesap('5390000002', 'fb-iptal-2');
  cagrilar.length = 0;
  const r = await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.a.accessToken, govde: { currentPassword: 'sifre1234', newPassword: 'Degisti2026' } });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
  assert.equal((await istek('/api/v1/users/me', { token: h.a.accessToken })).durum, 200);
  assert.equal((await istek('/api/v1/users/me', { token: h.b.accessToken })).durum, 401);
  assert.ok(cagrilar.some((c) => c.islem === 'update' && c.govde.localId === h.uid && c.govde.validSince));
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() - 60 })).durum, 401);
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() + 2, iat: an() + 2 })).durum, 200);
});

test('Firebase tarafı denetim (checkRevoked): yerel sınır yokken de Firebase\'de iptal edilmiş, devre dışı ya da silinmiş kullanıcının belgesi reddedilir; Google\'a ulaşılamazsa 503', async () => {
  const h = await hesap('5390000003', 'fb-iptal-3');
  // Ör. kullanıcı şifresini Firebase e-posta bağlantısıyla sıfırladı (sunucu haberdar değil).
  fbKullanicilar.get(h.uid).validSince = an();
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() - 30 })).json.error.code, 'AUTH_REVOKED');
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() + 2, iat: an() + 2 })).durum, 200);
  fbKullanicilar.get(h.uid).disabled = true;
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() + 2, iat: an() + 2 })).durum, 401, 'devre dışı');
  fbKullanicilar.get(h.uid).disabled = false;
  yonetimDurumu = 'kapali';
  try {
    assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() + 2, iat: an() + 2 })).durum, 503, 'doğrulanamayan belgeyle oturum açılmaz');
  } finally { yonetimDurumu = 'normal'; }
  fbKullanicilar.delete(h.uid);
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() + 2, iat: an() + 2 })).durum, 401, 'Firebase\'de silinmiş');
});

test('telefon değişikliği (Firebase belgesi): belge AYNI Firebase kullanıcısından ve yeni numarayla olmalı; değişiklik sonrası eski belgeler reddedilir', async () => {
  const h = await hesap('5390000004', 'fb-iptal-4');
  const yeniTel = '5390000005';
  // İstemci `updatePhoneNumber` yaptı: Firebase kullanıcısının numarası yeni numara.
  fbKullanicilar.get(h.uid).phoneNumber = `+90${yeniTel}`;
  // E-posta kimliği de taşıyan başka bir Firebase kullanıcısının belgesi reddedilir (silinmez).
  fbKullanicilar.set('fb-yabanci', { validSince: null, disabled: false, phoneNumber: `+90${yeniTel}`, email: 'baska@ornek.com', providerUserInfo: [{ providerId: 'phone' }, { providerId: 'password' }] });
  const yabanci = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: yeniTel, currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: 'fb-yabanci', phone_number: `+90${yeniTel}` }) } });
  assert.equal(yabanci.durum, 400);
  assert.equal(yabanci.json.error.code, 'PHONE_PROOF_INVALID');
  assert.ok(fbKullanicilar.has('fb-yabanci'), 'başkasının Firebase kaydına dokunulmadı');
  assert.ok(await db.prepare('SELECT 1 FROM users WHERE phone = ?').get(h.tel), 'numara değişmedi');
  fbKullanicilar.delete('fb-yabanci');
  // Eski numaralı belge (Firebase'de numara güncellenmemiş) de reddedilir.
  const eskiNumara = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: yeniTel, currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h.uid, phone_number: `+90${h.tel}` }) } });
  assert.equal(eskiNumara.durum, 400);

  cagrilar.length = 0;
  const dogru = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: yeniTel, currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h.uid, phone_number: `+90${yeniTel}` }) } });
  assert.equal(dogru.durum, 200, JSON.stringify(dogru.json));
  assert.equal(dogru.json.phone, yeniTel);
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, `+90${yeniTel}`, 'Firebase Auth numarası yeni numara');
  assert.equal((await istek('/api/v1/users/me', { token: h.a.accessToken })).durum, 200, 'işlemi yapan oturum açık');
  assert.equal((await istek('/api/v1/users/me', { token: h.b.accessToken })).durum, 401, 'diğer cihaz kapandı');
  assert.ok(cagrilar.some((c) => c.islem === 'update' && c.govde.localId === h.uid && c.govde.validSince), 'Firebase belirteçleri iptal');
  assert.equal((await firebaseOturumu(h.uid, yeniTel, { auth_time: an() - 60 })).durum, 401, 'değişiklik öncesi belge');
  assert.equal((await firebaseOturumu(h.uid, yeniTel, { auth_time: an() + 2, iat: an() + 2 })).durum, 200);
});

test('telefon değişikliği (sunucu kodu yolu, Firebase\'e bağlı hesap): numara Firebase\'e sunucuca yazılır; yazılamazsa yerel numara da değişmez', async () => {
  const h = await hesap('5390000006', 'fb-iptal-6');
  const yeniTel = '5390000007';
  yonetimDurumu = 'kapali';
  try {
    const r = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: { newPhone: yeniTel, currentPassword: 'sifre1234', otpCode: await kod(yeniTel, 'PHONE_CHANGE') } });
    assert.equal(r.durum, 503);
  } finally { yonetimDurumu = 'normal'; }
  assert.ok(await db.prepare('SELECT 1 FROM users WHERE phone = ?').get(h.tel), 'yerel numara değişmedi');
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, `+90${h.tel}`);
  const r2 = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: { newPhone: yeniTel, currentPassword: 'sifre1234', otpCode: await kod(yeniTel, 'PHONE_CHANGE') } });
  assert.equal(r2.durum, 200, JSON.stringify(r2.json));
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, `+90${yeniTel}`);
  assert.equal((await istek('/api/v1/users/me', { token: h.b.accessToken })).durum, 401);
});

test('telefon değişikliği (istemcide Firebase oturumu yok): yeni numarayla açılan bağsız Firebase kaydı silinir, numara hesabın Firebase kaydına yazılır', async () => {
  const h = await hesap('5390000008', 'fb-iptal-8');
  const yeniTel = '5390000009';
  // Telefon + şifreyle girmiş istemci kodu doğrulayınca Firebase yeni numarayla AYRI bir kullanıcı açtı.
  fbKullanicilar.set('fb-gecici-9', { validSince: null, disabled: false, phoneNumber: `+90${yeniTel}`, providerUserInfo: [{ providerId: 'phone' }] });
  const r = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: yeniTel, currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: 'fb-gecici-9', phone_number: `+90${yeniTel}` }) } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(fbKullanicilar.has('fb-gecici-9'), false, 'geçici kayıt silindi');
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, `+90${yeniTel}`, 'hesabın Firebase kaydında yeni numara');
  assert.equal((await db.prepare('SELECT firebase_uid FROM users WHERE phone = ?').get(yeniTel)).firebase_uid, h.uid, 'hesap aynı Firebase kimliğinde kaldı');
  // Başka bir HizmetCep hesabına bağlı Firebase kaydının belgesi asla kabul edilmez.
  const diger = await hesap('5390000010', 'fb-iptal-10');
  const r2 = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: diger.a.accessToken, govde: {
    newPhone: '5390000011', currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h.uid, phone_number: '+905390000011' }) } });
  assert.equal(r2.durum, 400);
  assert.ok(fbKullanicilar.has(h.uid), 'bağlı kayıt silinmedi');
});
