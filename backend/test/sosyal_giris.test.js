// GOOGLE / APPLE İLE GİRİŞ (4 Kas, kullanıcı talebi)
//
//  · İlk girişte hesap yoksa SOCIAL_SIGNUP_REQUIRED; kayıt ad + rol + iki
//    zorunlu onayla tamamlanır, e-posta sağlayıcıda doğrulanmış olmalı.
//  · Hesap şifresiz açılır; telefon/adres kapıları e-postalı kayıttaki gibi.
//  · Aynı kimlik ikinci hesap açmaz: rol yoksa eklenir (taze giriş şartı).
//  · Başka (doğrulanmamış) hesaptaki adres devralınmaz.
//  · Şifresiz hesapta kritik işlem: şifre yerine aynı kullanıcının son 10
//    dakikadaki girişi; şifre değiştirme NO_PASSWORD.
//  · Şifreli hesapların davranışı DEĞİŞMEZ.
//  · Doğrulanmamış adresin sahibi Google ile gelirse (Firebase şifreyi
//    kaldırdıysa) eski şifre geçersiz ve açık oturumlar kapanır.
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

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
testSertifikaGetiricisi(async () => ({ sertifikalar: { k1: publicKey.export({ type: 'spki', format: 'pem' }) }, sureSn: 3600 }));
function idToken(yuk, { once = 10 } = {}) {
  const an = Math.floor(Date.now() / 1000);
  const bas = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'k1', typ: 'JWT' })).toString('base64url');
  const govde = Buffer.from(JSON.stringify({
    aud: 'hizmetcep-fe036', iss: 'https://securetoken.google.com/hizmetcep-fe036', iat: an - 10, auth_time: an - once, exp: an + 3600, ...yuk,
  })).toString('base64url');
  return `${bas}.${govde}.${createSign('RSA-SHA256').update(`${bas}.${govde}`).sign(privateKey).toString('base64url')}`;
}
const google = (sub, email, ek = {}, se) => idToken({ sub, email, email_verified: true, firebase: { sign_in_provider: 'google.com' }, ...ek }, se);
const apple = (sub, email, ek = {}, se) => idToken({ sub, email, email_verified: true, firebase: { sign_in_provider: 'apple.com' }, ...ek }, se);

let db, sunucu, taban, adres, hizmet;
async function istek(yol, { yontem = 'GET', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
const temizle = () => db.prepare('DELETE FROM rate_limits').run();
const oturum = async (idTok) => { await temizle(); return istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: idTok } }); };
const sosyalKayit = async (idTok, ek = {}) => {
  await temizle();
  return istek('/api/v1/auth/firebase/register', {
    yontem: 'POST', govde: { idToken: idTok, role: 'CUSTOMER', name: 'Sosyal Kişi', termsAccepted: true, aydinlatmaAccepted: true, platform: 'ios', ...ek },
  });
};
const ben = async (token) => (await istek('/api/v1/users/me', { token }));
const kullaniciSayisi = async (mail) => (await db.prepare('SELECT COUNT(*) n FROM users WHERE lower(email) = ?').get(mail)).n;

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const a = await db.prepare(
    `SELECT c.name city, d.name district, n.name neighborhood FROM neighborhoods n JOIN districts d ON d.id = n.district_id
       JOIN cities c ON c.id = d.city_id WHERE n.active = TRUE AND d.active = TRUE AND c.active = TRUE LIMIT 1`,
  ).get();
  adres = a;
  hizmet = (await db.prepare('SELECT name FROM services WHERE active = TRUE LIMIT 1').get()).name;
});
after(async () => { firebaseYonetimTestGondericisi(null); sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('Google: hesap yoksa SOCIAL_SIGNUP_REQUIRED; kayıt şifresiz hesap açar, onaylar kaydedilir, kapılar aynen', async () => {
  const t = google('g-yeni-1', 'yeni1@gmail.com');
  const ilk = await oturum(t);
  assert.equal(ilk.durum, 404);
  assert.equal(ilk.json.error.code, 'SOCIAL_SIGNUP_REQUIRED');
  assert.equal(await kullaniciSayisi('yeni1@gmail.com'), 0, 'girişte hesap AÇILMAZ');

  const k = await sosyalKayit(t);
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  const u = (await ben(k.json.accessToken)).json;
  assert.equal(u.email, 'yeni1@gmail.com');
  assert.equal(u.emailVerified, true);
  assert.equal(u.phone, '');
  assert.equal(u.phoneVerified, false);
  assert.equal(u.hasPassword, false);
  assert.equal(u.socialProvider, 'google.com');
  assert.deepEqual(u.roles, ['CUSTOMER']);
  assert.ok(u.profileMissing.customer.includes('PHONE') && u.profileMissing.customer.includes('ADDRESS'));
  // Onaylanan belgeler e-postalı kayıttakiyle AYNI kaynaktan yazılır (yayımdaki sürümler).
  const yayimda = (await db.prepare(`SELECT COUNT(*) n FROM legal_versions v JOIN legal_documents d ON d.slug = v.slug
    WHERE v.slug IN ('terms','kvkk','privacy') AND v.status = 'PUBLISHED' AND d.active = TRUE`).get()).n;
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM legal_acceptances WHERE user_id = ?').get(u.id)).n, yayimda);
  // Profil kapısı Google hesabında da AYNI.
  const ilan = await istek('/api/v1/listings', { yontem: 'POST', token: k.json.accessToken, govde: { title: hizmet, location: `${adres.neighborhood}, ${adres.district} / ${adres.city}`, description: 'banyo bataryası değişecek' } });
  assert.equal(ilan.durum, 403);
  assert.equal(ilan.json.error.code, 'PROFILE_INCOMPLETE');
  // Sonraki girişler oturum açar, ikinci hesap yok.
  const ikinci = await oturum(google('g-yeni-1', 'yeni1@gmail.com'));
  assert.equal(ikinci.durum, 200);
  assert.equal(await kullaniciSayisi('yeni1@gmail.com'), 1);
});

test('Apple: aynı akış; kayıt zorunlu onaylar, doğrulanmış e-posta ve Google/Apple belgesi ister', async () => {
  assert.equal((await sosyalKayit(apple('a-1', 'gizli@privaterelay.appleid.com'), { termsAccepted: false })).json.error.code, 'TERMS_REQUIRED');
  assert.equal((await sosyalKayit(apple('a-1', 'gizli@privaterelay.appleid.com'), { aydinlatmaAccepted: false })).json.error.code, 'AYDINLATMA_REQUIRED');
  assert.equal((await sosyalKayit(apple('a-1', 'gizli@privaterelay.appleid.com', { email_verified: false }))).json.error.code, 'EMAIL_REQUIRED');
  assert.equal((await sosyalKayit(apple('a-1', undefined))).json.error.code, 'EMAIL_REQUIRED');
  // E-posta/şifre ya da telefon belgesiyle bu uçtan hesap açılmaz.
  const sifreli = await sosyalKayit(idToken({ sub: 'p-1', email: 'x@ornek.com', email_verified: true, firebase: { sign_in_provider: 'password' } }));
  assert.equal(sifreli.durum, 400);
  assert.equal(await kullaniciSayisi('x@ornek.com'), 0);
  const k = await sosyalKayit(apple('a-1', 'gizli@privaterelay.appleid.com'), { role: 'PROVIDER' });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  const u = (await ben(k.json.accessToken)).json;
  assert.equal(u.socialProvider, 'apple.com');
  assert.deepEqual(u.roles, ['PROVIDER']);
  assert.ok(u.profileMissing.provider.includes('SERVICES'));
});

test('aynı kimlikle ikinci kayıt hesap açmaz: rol yoksa eklenir (taze giriş), varsa yalnız oturum', async () => {
  await sosyalKayit(google('g-rol', 'rol@gmail.com'));
  const eski = await sosyalKayit(google('g-rol', 'rol@gmail.com', {}, { once: 11 * 60 }), { role: 'PROVIDER' });
  assert.equal(eski.durum, 401);
  assert.equal(eski.json.error.code, 'REAUTH_REQUIRED');
  const r = await sosyalKayit(google('g-rol', 'rol@gmail.com'), { role: 'PROVIDER', name: undefined, termsAccepted: undefined });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = (await ben(r.json.accessToken)).json;
  assert.deepEqual([...u.roles].sort(), ['CUSTOMER', 'PROVIDER']);
  assert.equal(u.activeRole, 'PROVIDER');
  const ayni = await sosyalKayit(google('g-rol', 'rol@gmail.com'), { role: 'PROVIDER' });
  assert.equal(ayni.durum, 200);
  assert.equal(await kullaniciSayisi('rol@gmail.com'), 1);
});

test('adres başka hesapta: doğrulanmamışsa devralınmaz (409), doğrulanmışsa o hesaba bağlanır', async () => {
  // Şifreyle açılmış, e-postası DOĞRULANMAMIŞ hesap.
  await temizle();
  const kayit = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, phone: '05321110011', password: 'GucluSifre12', name: 'Eski Kişi', email: 'eski@gmail.com', role: 'CUSTOMER' } });
  assert.equal(kayit.durum, 200);
  const g = google('g-eski', 'eski@gmail.com');
  assert.equal((await oturum(g)).json.error.code, 'SOCIAL_SIGNUP_REQUIRED');
  const r = await sosyalKayit(g);
  assert.equal(r.durum, 409);
  assert.equal(await kullaniciSayisi('eski@gmail.com'), 1);
  // Doğrulanmış adres: giriş ve kayıt aynı hesaba bağlanır.
  await db.prepare(`UPDATE users SET email_verified = TRUE WHERE lower(email) = 'eski@gmail.com'`).run();
  const o = await oturum(g);
  assert.equal(o.durum, 200);
  const u = (await ben(o.json.accessToken)).json;
  assert.equal(u.phone, '5321110011');
  assert.equal(u.hasPassword, true, 'şifreli hesabın şifresi korunur');
  assert.equal(await kullaniciSayisi('eski@gmail.com'), 1);
});

test('şifresiz hesapta kritik işlem: yalnız aynı kullanıcının son 10 dakikadaki girişi; şifre değiştirme NO_PASSWORD', async () => {
  const t = (await sosyalKayit(google('g-kritik', 'kritik@gmail.com'))).json.accessToken;
  const dogrula = async (deger) => { await temizle(); return istek('/api/v1/auth/verify-password', { yontem: 'POST', token: t, govde: { password: deger } }); };
  assert.equal((await dogrula('herhangi-bir-sifre')).durum, 400);
  assert.equal((await dogrula('')).durum, 400);
  assert.equal((await dogrula(google('g-baskasi', 'kritik@gmail.com'))).durum, 400, 'başka kullanıcının belgesi geçmez');
  assert.equal((await dogrula(google('g-kritik', 'kritik@gmail.com', {}, { once: 11 * 60 }))).durum, 400, 'eski giriş geçmez');
  assert.ok((await dogrula(google('g-kritik', 'kritik@gmail.com'))).durum < 300);
  // 5 Kas: rol ekleme kimlik kanıtı İSTEMEZ (şifresiz hesapta da).
  await temizle();
  const rol = await istek('/api/v1/auth/roles/add', { yontem: 'POST', token: t, govde: { role: 'PROVIDER' } });
  assert.ok(rol.durum < 300, JSON.stringify(rol.json));
  // Silme talebi ise AYNI kanıtı ister.
  await temizle();
  const silme = await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: t, govde: { password: 'tahmin' } });
  assert.equal(silme.durum, 400);
  await temizle();
  const sd = await istek('/api/v1/auth/password/change', { yontem: 'POST', token: t, govde: { currentPassword: '', newPassword: 'YeniSifre123' } });
  assert.equal(sd.durum, 400);
  assert.equal(sd.json.error.code, 'NO_PASSWORD');
});

test('şifreli hesapta davranış aynı: Firebase belgesi şifre yerine geçmez', async () => {
  await temizle();
  const kayit = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, phone: '05321110022', password: 'GucluSifre12', name: 'Şifreli Kişi', email: 'sifreli@ornek.com', role: 'CUSTOMER' } });
  const t = kayit.json.accessToken;
  assert.equal((await ben(t)).json.hasPassword, true);
  await temizle();
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: t, govde: { password: google('g-yok', 'sifreli@ornek.com') } })).durum, 400);
  await temizle();
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: t, govde: { password: 'GucluSifre12' } })).durum < 300, true);
});

test('doğrulanmamış adresin sahibi Google ile geldi (Firebase şifreyi kaldırdı): eski şifre ve oturumlar geçersiz', async () => {
  const mail = 'sahip@gmail.com';
  await temizle();
  const kayit = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
    termsAccepted: true, aydinlatmaAccepted: true, phone: '05321110033', password: 'BaskasininSifresi1', name: 'Başkası Kişi', email: mail, role: 'CUSTOMER',
    firebaseEmailToken: idToken({ sub: 'fb-sahip', email: mail, email_verified: false, firebase: { sign_in_provider: 'password' } }) } });
  assert.equal(kayit.durum, 200, JSON.stringify(kayit.json));
  const eskiOturum = kayit.json.accessToken;
  let saglayicilar = ['google.com'];
  firebaseYonetimTestGondericisi(async (islem, govde) => (islem === 'lookup'
    ? { ok: true, durum: 200, kod: '', veri: { users: [{ localId: govde.localId[0], email: mail, emailVerified: true, providerUserInfo: saglayicilar.map((providerId) => ({ providerId })) }] } }
    : { ok: true, durum: 200, kod: '', veri: {} }));
  try {
    const o = await oturum(google('fb-sahip', mail));
    assert.equal(o.durum, 200, JSON.stringify(o.json));
    const u = (await ben(o.json.accessToken)).json;
    assert.equal(u.hasPassword, false);
    assert.equal(u.emailVerified, true);
    assert.equal((await ben(eskiOturum)).durum, 401, 'açık oturumlar kapandı');
    assert.ok(await db.prepare(`SELECT 1 FROM user_sessions WHERE user_id = ? AND revoke_reason = 'SOCIAL_CLAIM'`).get(u.id), 'kapanış nedeni kayıtlı');
    await temizle();
    const giris = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '05321110033', password: 'BaskasininSifresi1' } });
    assert.equal(giris.durum, 401, 'eski şifre geçersiz');

    // Firebase şifreyi KORUDUYSA (şifre sağlayıcısı duruyor) hesaba dokunulmaz.
    saglayicilar = ['password', 'google.com'];
    const mail2 = 'korunan@gmail.com';
    await temizle();
    const k2 = await istek('/api/v1/auth/register', { yontem: 'POST', govde: {
      termsAccepted: true, aydinlatmaAccepted: true, phone: '05321110044', password: 'KendiSifresi12', name: 'Kendi Kişi', email: mail2, role: 'CUSTOMER',
      firebaseEmailToken: idToken({ sub: 'fb-korunan', email: mail2, email_verified: false, firebase: { sign_in_provider: 'password' } }) } });
    const o2 = await oturum(google('fb-korunan', mail2));
    assert.equal(o2.durum, 200);
    const u2 = (await ben(o2.json.accessToken)).json;
    assert.equal(u2.hasPassword, true);
    assert.equal(await db.prepare(`SELECT 1 FROM user_sessions WHERE user_id = ? AND revoke_reason = 'SOCIAL_CLAIM'`).get(u2.id), undefined);
    assert.equal(k2.durum, 200);
  } finally {
    firebaseYonetimTestGondericisi(null);
  }
});

test('051 göçü iki veritabanında aynı', async () => {
  const { readFileSync } = await import('node:fs');
  const oku = (d) => readFileSync(new URL(`../migrations/${d}/051_sosyal_giris.sql`, import.meta.url), 'utf8');
  assert.equal(oku('postgres'), oku('sqlite'));
});

test('5 Kas: Google/Apple hesabına şifre oluşturma — taze kanıtla; sonra e-posta + şifreyle giriş; ikinci kez 409', async () => {
  const t = (await sosyalKayit(google('g-sifre', 'sifre-olustur@gmail.com'))).json.accessToken;
  const olustur = async (govde) => { await temizle(); return istek('/api/v1/auth/password/set', { yontem: 'POST', token: t, govde }); };
  // Kanıtsız, başkasının ya da eski girişin belgesi geçmez.
  assert.equal((await olustur({ newPassword: 'YeniSifre123' })).json.error.code, 'WRONG_PASSWORD');
  assert.equal((await olustur({ newPassword: 'YeniSifre123', firebaseIdToken: google('g-baskasi', 'sifre-olustur@gmail.com') })).durum, 400);
  assert.equal((await olustur({ newPassword: 'YeniSifre123', firebaseIdToken: google('g-sifre', 'sifre-olustur@gmail.com', {}, { once: 11 * 60 }) })).durum, 400);
  // Şifre kuralı aynı (zayıf şifre reddedilir).
  assert.equal((await olustur({ newPassword: '123', firebaseIdToken: google('g-sifre', 'sifre-olustur@gmail.com') })).durum, 400);
  assert.equal((await ben(t)).json.hasPassword, false);
  // Taze kanıtla oluşturulur; oturum kapanmaz.
  const r = await olustur({ newPassword: 'YeniSifre123', firebaseIdToken: google('g-sifre', 'sifre-olustur@gmail.com') });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
  const u = (await ben(t)).json;
  assert.equal(u.hasPassword, true);
  assert.equal(u.socialProvider, 'google.com', 'giriş yöntemi bilgisi korunur');
  // Hesap artık şifreli: kritik işlem kanıtı da şifre olur (Firebase
  // belgesi yerine). Şifre doğru → geçer, yanlış → reddedilir.
  await temizle();
  assert.ok((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: t, govde: { password: 'YeniSifre123' } })).durum < 300);
  await temizle();
  assert.equal((await istek('/api/v1/auth/verify-password', { yontem: 'POST', token: t, govde: { password: 'YanlisSifre99' } })).durum, 400);
  // İkinci kez oluşturulamaz (Şifre Değiştir kullanılır).
  const tekrar = await olustur({ newPassword: 'BaskaSifre456', firebaseIdToken: google('g-sifre', 'sifre-olustur@gmail.com') });
  assert.equal(tekrar.durum, 409);
});
