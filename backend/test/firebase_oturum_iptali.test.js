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
import { createSign, createVerify, generateKeyPairSync } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { testSertifikaGetiricisi, firebaseYonetimTestGondericisi } = await import('../src/firebase_token.js');
const { olaylar } = await import('../src/olaylar.js');
const { firebaseIslemKuyrugunuIsle } = await import('../src/firebase_islemleri.js');

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
  // Bu dosya çok sayıda Firebase oturumu açar: IP başına giriş/OTP sınırı
  // kurulumu engellemesin (sınırların kendisi başka dosyalarda sınanır).
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'giris_ip:%' OR key LIKE 'otp_ip:%'`).run();
  fbKullanicilar.set(uid, { validSince: null, disabled: false, phoneNumber: `+90${tel}` });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'İptal Deneme',
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

// ═════ E-POSTA BAĞLANTISIYLA ŞİFRE SIFIRLAMA (Firebase'de, sunucu habersiz) ═════
const yenile = (rt) => istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: rt } });
const kontrolSifirla = (tel) => db.prepare('UPDATE users SET firebase_checked_at = NULL WHERE phone = ?').run(tel);

test('e-postayla sıfırlama: sonraki yenilemede eski sunucu oturumları kapanır, eski belge reddedilir, yeni şifreyle açılan oturum kalır', async () => {
  const h = await hesap('5390000020', 'fb-eposta-1');
  // Firebase sıfırlamada belirteçleri kendisi iptal eder ve kayda yazar (gerçek alanlar: validSince, passwordUpdatedAt).
  const vs = an() + 1;
  Object.assign(fbKullanicilar.get(h.uid), { validSince: vs, passwordUpdatedAt: String(vs * 1000) });
  await kontrolSifirla(h.tel);
  let yayin = null;
  olaylar.once('user.sessions.revoked', (d) => (yayin = d));
  const r = await yenile(h.a.refreshToken);
  assert.equal(r.durum, 401, 'sıfırlama öncesi oturum yenilenemez');
  assert.equal((await istek('/api/v1/users/me', { token: h.b.accessToken })).durum, 401, 'diğer oturum da kapandı');
  assert.ok(yayin, 'soketleri kapatan olay yayınlandı');
  const u = await db.prepare('SELECT firebase_valid_since, password_hash FROM users WHERE phone = ?').get(h.tel);
  assert.equal(Number(u.firebase_valid_since), vs);
  assert.ok(u.password_hash.startsWith('firebase-disi$'), 'yedek doğrulama eski şifreyi kabul etmez');
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: h.tel, password: 'sifre1234' } })).durum, 401, 'eski şifre (yerel yedek) geçersiz');
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() - 30 })).durum, 401, 'sıfırlama öncesi Firebase belgesi');
  const yeni = await firebaseOturumu(h.uid, h.tel, { auth_time: vs, iat: vs });
  assert.equal(yeni.durum, 200, JSON.stringify(yeni.json));
  await kontrolSifirla(h.tel);
  assert.equal((await yenile(yeni.json.refreshToken)).durum, 200, 'sıfırlama sonrası oturum yenilenir');
});

test('uzlaştırma: en çok 5 dakikada bir okunur; Firebase\'e ulaşılamazsa yenileme engellenmez; devre dışı kullanıcının oturumları kapanır', async () => {
  const h = await hesap('5390000021', 'fb-eposta-2');
  await kontrolSifirla(h.tel);
  const ilk = await yenile(h.a.refreshToken);
  assert.equal(ilk.durum, 200);
  Object.assign(fbKullanicilar.get(h.uid), { validSince: an() + 1 });
  const ikinci = await yenile(ilk.json.refreshToken);
  assert.equal(ikinci.durum, 200, 'aralık dolmadan yeniden okunmaz');
  yonetimDurumu = 'kapali';
  try {
    await kontrolSifirla(h.tel);
    assert.equal((await yenile(ikinci.json.refreshToken)).durum, 200 /* fail-open */);
  } finally { yonetimDurumu = 'normal'; }
  const u = await db.prepare('SELECT firebase_checked_at FROM users WHERE phone = ?').get(h.tel);
  assert.ok(u.firebase_checked_at, 'deneme zamanı kaydedildi (bir sonraki aralıkta yine denenir)');
  // Devre dışı bırakılmış Firebase kullanıcısı.
  const h2 = await hesap('5390000022', 'fb-eposta-3');
  fbKullanicilar.get(h2.uid).disabled = true;
  await kontrolSifirla(h2.tel);
  assert.equal((await yenile(h2.a.refreshToken)).durum, 401);
  assert.equal((await istek('/api/v1/users/me', { token: h2.b.accessToken })).durum, 401);
});

test('sunucunun kendi iptali uzlaştırmada "dış değişiklik" sayılmaz: şifre değiştiren cihazın oturumu yenilenmeye devam eder', async () => {
  const h = await hesap('5390000023', 'fb-eposta-4');
  assert.equal((await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.a.accessToken, govde: { currentPassword: 'sifre1234', newPassword: 'Degisti2026' } })).durum, 204);
  await kontrolSifirla(h.tel);
  assert.equal((await yenile(h.a.refreshToken)).durum, 200);
  assert.equal((await yenile(h.b.refreshToken)).durum, 401);
});

// ═════ YARIM KALAN İŞLEMLER — KALICI KUYRUK ═════
const kuyruk = (tel) => db.prepare('SELECT q.* FROM firebase_islem_kuyrugu q JOIN users u ON u.id = q.user_id WHERE u.phone = ? ORDER BY q.islem').all(tel);

test('Firebase iptali başarısızsa işlem tamamlanır, yerel sınır hemen geçerli olur, iptal kuyrukta yeniden denenir ve hata kaydedilir', async () => {
  const h = await hesap('5390000030', 'fb-kuyruk-1');
  yonetimDurumu = 'kapali';
  try {
    assert.equal((await istek('/api/v1/auth/password/change', { yontem: 'POST', token: h.a.accessToken, govde: { currentPassword: 'sifre1234', newPassword: 'Degisti2026' } })).durum, 204);
    assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() - 30 })).durum, 401, 'yerel sınır Firebase\'den bağımsız');
    let q = await kuyruk(h.tel);
    assert.deepEqual(q.map((x) => x.islem), ['REVOKE']);
    const deger = Number(q[0].deger);
    assert.ok(Math.abs(deger - an()) <= 5);
    await db.prepare('UPDATE firebase_islem_kuyrugu SET sonraki_deneme = ?').run('2000-01-01T00:00:00.000Z');
    await firebaseIslemKuyrugunuIsle(db);
    q = await kuyruk(h.tel);
    assert.equal(q[0].deneme, 1);
    assert.ok(q[0].son_hata.includes('HTTP 503'));
    assert.ok(new Date(q[0].sonraki_deneme) > new Date(), 'artan aralıkla ertelendi');
  } finally { yonetimDurumu = 'normal'; }
  await db.prepare('UPDATE firebase_islem_kuyrugu SET sonraki_deneme = ?').run('2000-01-01T00:00:00.000Z');
  // Bu arada daha yeni bir iptal oldu: eski kuyruk değeri sınırı GERİ ALMAZ.
  const yeniSinir = an() + 100;
  await db.prepare('UPDATE users SET firebase_valid_since = ? WHERE phone = ?').run(yeniSinir, h.tel);
  await firebaseIslemKuyrugunuIsle(db);
  assert.equal(fbKullanicilar.get(h.uid).validSince, yeniSinir, 'gönderilen değer güncel sınırdan küçük olamaz');
  assert.deepEqual(await kuyruk(h.tel), [], 'başarıda satır silinir');
});

test('telefon değişikliği yarıda kalırsa (istemci Firebase\'i değiştirdi, sunucu reddetti) Firebase numarası hesabın numarasına geri eşitlenir; başarıda iş boşa yazmaz', async () => {
  const h = await hesap('5390000031', 'fb-kuyruk-2');
  const baskasi = await hesap('5390000032', 'fb-kuyruk-3');
  // İstemci updatePhoneNumber yaptı, ama numara başka hesapta kayıtlı → 409.
  fbKullanicilar.get(h.uid).phoneNumber = `+90${baskasi.tel}`;
  const r = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: baskasi.tel, currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h.uid, phone_number: `+90${baskasi.tel}` }) } });
  assert.equal(r.durum, 409);
  assert.deepEqual((await kuyruk(h.tel)).map((x) => x.islem), ['SYNC_PHONE']);
  await firebaseIslemKuyrugunuIsle(db);
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, `+90${h.tel}`, 'Firebase numarası hesabınkine döndü');
  assert.deepEqual(await kuyruk(h.tel), []);

  // Yanlış şifrede de aynı kurtarma.
  fbKullanicilar.get(h.uid).phoneNumber = '+905390000033';
  const y = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: '5390000033', currentPassword: 'yanlis999', firebaseIdToken: idToken({ sub: h.uid, phone_number: '+905390000033' }) } });
  assert.equal(y.json.error.code, 'WRONG_PASSWORD');
  await firebaseIslemKuyrugunuIsle(db);
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, `+90${h.tel}`);

  // Başarı: Firebase zaten yeni numarada; kuyruk okur, YAZMAZ.
  fbKullanicilar.get(h.uid).phoneNumber = '+905390000034';
  assert.equal((await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
    newPhone: '5390000034', currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h.uid, phone_number: '+905390000034' }) } })).durum, 200);
  cagrilar.length = 0;
  await firebaseIslemKuyrugunuIsle(db);
  assert.equal(cagrilar.filter((c) => c.islem === 'update' && c.govde.phoneNumber).length, 0, 'eşit numara yeniden yazılmaz');
  assert.equal(fbKullanicilar.get(h.uid).phoneNumber, '+905390000034');
});

// ═════ İŞLEMİ YAPAN CİHAZ: ÖZEL BELGEYLE YENİDEN BAĞLANMA ═════
test('telefon değişikliği yanıtı, servis hesabıyla imzalı kısa ömürlü Firebase özel belgesi taşır (createCustomToken biçimi)', async () => {
  const anahtar = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const eski = process.env.HC_FCM_SERVICE_ACCOUNT;
  process.env.HC_FCM_SERVICE_ACCOUNT = JSON.stringify({ type: 'service_account', project_id: 'hizmetcep-fe036', client_email: 'test-sa@hizmetcep-fe036.iam.gserviceaccount.com', private_key: anahtar.privateKey.export({ type: 'pkcs8', format: 'pem' }) });
  try {
    const h = await hesap('5390000040', 'fb-ozel-1');
    fbKullanicilar.get(h.uid).phoneNumber = '+905390000041';
    const r = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h.a.accessToken, govde: {
      newPhone: '5390000041', currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h.uid, phone_number: '+905390000041' }) } });
    assert.equal(r.durum, 200, JSON.stringify(r.json));
    const [b, g, imza] = r.json.firebaseCustomToken.split('.');
    assert.ok(createVerify('RSA-SHA256').update(`${b}.${g}`).verify(anahtar.publicKey, Buffer.from(imza, 'base64url')), 'servis hesabıyla imzalı');
    const yuk = JSON.parse(Buffer.from(g, 'base64url').toString());
    assert.equal(yuk.uid, h.uid);
    assert.equal(yuk.iss, 'test-sa@hizmetcep-fe036.iam.gserviceaccount.com');
    assert.equal(yuk.sub, yuk.iss);
    assert.equal(yuk.aud, 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit');
    assert.equal(yuk.exp - yuk.iat, 300);
    const sinir = Number((await db.prepare('SELECT firebase_valid_since FROM users WHERE id = (SELECT id FROM users WHERE phone = ?)').get('5390000041')).firebase_valid_since);
    assert.ok(yuk.iat >= sinir, 'özel belge iptal sınırından sonra üretildi (bu cihazın yeni oturumu iptale takılmaz)');
  } finally {
    if (eski === undefined) delete process.env.HC_FCM_SERVICE_ACCOUNT; else process.env.HC_FCM_SERVICE_ACCOUNT = eski;
  }
  // Servis hesabı yoksa alan hiç dönmez (sözleşme eklemelidir).
  const h2 = await hesap('5390000042', 'fb-ozel-2');
  fbKullanicilar.get(h2.uid).phoneNumber = '+905390000043';
  const r2 = await istek('/api/v1/profiles/me/phone/change', { yontem: 'POST', token: h2.a.accessToken, govde: {
    newPhone: '5390000043', currentPassword: 'sifre1234', firebaseIdToken: idToken({ sub: h2.uid, phone_number: '+905390000043' }) } });
  assert.equal(r2.durum, 200);
  assert.equal('firebaseCustomToken' in r2.json, false);
});

test('21 Eki (kullanıcı kuralı + Y2): şifreyle başlatılmış e-posta değişikliği oturumu KAPATMAZ — Firebase sınırı ilerlese de açık oturumlar yenilenir, yeni adres işlenir', async () => {
  const h = await hesap('5390000071', 'fb-eposta-degisim-1');
  // Kullanıcı profilden şifresiyle değişiklik istedi (bekleyen istek), sonra
  // "doğrula ve değiştir" bağlantısına tıkladı: Firebase belirteçleri iptal
  // eder (validSince ileri), şifre DEĞİŞMEZ, yeni adres doğrulanmış.
  await db.prepare('UPDATE users SET pending_email = ?, pending_email_at = ? WHERE phone = ?').run('degisen@ornek.com', new Date().toISOString(), h.tel);
  const vs = an() + 1;
  Object.assign(fbKullanicilar.get(h.uid), { validSince: vs, email: 'degisen@ornek.com', emailVerified: true });
  await kontrolSifirla(h.tel);
  const r = await yenile(h.a.refreshToken);
  assert.equal(r.durum, 200, 'e-posta değişikliği oturumu kapattı');
  assert.equal((await istek('/api/v1/users/me', { token: h.b.accessToken })).durum, 200, 'diğer oturum da açık');
  const u = await db.prepare('SELECT email, email_verified, firebase_valid_since, pending_email FROM users WHERE phone = ?').get(h.tel);
  assert.equal(u.email, 'degisen@ornek.com');
  assert.ok(u.email_verified);
  assert.equal(u.pending_email, null);
  assert.equal(Number(u.firebase_valid_since), vs, 'eski Firebase belgeleriyle yeni oturum açılmasın');
  assert.equal((await firebaseOturumu(h.uid, h.tel, { auth_time: an() - 30 })).durum, 401);
});

test('21 Eki (Y2): bekleyen istek OLMADAN Firebase\'de yapılan e-posta değişikliği işlenmez ve dış iptal sayılır (oturumlar kapanır)', async () => {
  const h = await hesap('5390000072', 'fb-eposta-degisim-2');
  const vs = an() + 1;
  Object.assign(fbKullanicilar.get(h.uid), { validSince: vs, email: 'saldirgan@ornek.com', emailVerified: true });
  await kontrolSifirla(h.tel);
  assert.equal((await yenile(h.a.refreshToken)).durum, 401, 'yetkisiz değişiklik sonrası eski oturum kapanmalı');
  const u = await db.prepare('SELECT email FROM users WHERE phone = ?').get(h.tel);
  assert.equal(u.email, `i${h.tel}@ornek.com`, 'adres değişmemeli');
});
