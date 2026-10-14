// /api/v1/auth/roles/add — ikinci rol ekleme (15 Eki sertleştirmesi).
//   · kullanıcı başına hız sınırı (15 dk'da 5; yanlış şifre ve geçersiz
//     kanıt da sayılır),
//   · Firebase kanıtı: imza/proje/süre/telefon denetimleri KORUNUR ve ayrıca
//     yakın zamanda TELEFONLA yeniden doğrulama şartı (auth_time ≤ 10 dk,
//     firebase.sign_in_provider = 'phone', ve auth_time bu sunucu oturumu
//     açıldıktan EN AZ 30 sn SONRA → giriş belgesi yeniden kullanılamaz),
//   · geçersiz kanıt 400 (401 değil: istemci 401'de isteği tekrarlar),
//   · eski sunucu OTP yolunda istenmemiş kod (ör. 123456) reddedilir,
//   · kayıt ve giriş davranışı DEĞİŞMEZ.
// ⚠ Gerçek Firebase YOK: test anahtarıyla imzalanan belgeler (aynı denetim yolu).
// Ağ çağrısı yapılmaz (HC_FIREBASE_WEB_API_KEY tanımsız → yerel şifre özeti).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createSign, generateKeyPairSync } from 'node:crypto';

process.env.HC_SESSIZ = '1';
process.env.HC_TEST_OTP_KANCASI = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { testSertifikaGetiricisi } = await import('../src/firebase_token.js');

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const KID = 'rol-test-anahtari';
testSertifikaGetiricisi(async () => ({ sertifikalar: { [KID]: publicKey.export({ type: 'spki', format: 'pem' }) }, sureSn: 3600 }));

const an = () => Math.floor(Date.now() / 1000);
function belge(yuk, { anahtar = privateKey } = {}) {
  const t = an();
  const bas = Buffer.from(JSON.stringify({ alg: 'RS256', kid: KID, typ: 'JWT' })).toString('base64url');
  const govde = Buffer.from(JSON.stringify({
    aud: 'hizmetcep-fe036', iss: 'https://securetoken.google.com/hizmetcep-fe036',
    iat: t - 5, auth_time: t - 5, exp: t + 3600, firebase: { sign_in_provider: 'phone' }, ...yuk,
  })).toString('base64url');
  return `${bas}.${govde}.${createSign('RSA-SHA256').update(`${bas}.${govde}`).sign(anahtar).toString('base64url')}`;
}

let db, sunucu, taban;
async function istek(yol, { yontem = 'POST', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
/** Sunucu OTP yoluyla (test kancası) hizmet alan hesabı açar → erişim token'ı. */
async function hizmetAlan(tel) {
  assert.equal((await istek('/api/v1/auth/otp/request', { govde: { phone: tel, purpose: 'REGISTER' } })).durum, 204);
  const r = await istek('/api/v1/auth/register', { govde: { phone: tel, password: 'GucluSifre12', name: 'Rol Deneme', email: `r${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return r.json.accessToken;
}
const rolEkle = (token, govde) => istek('/api/v1/auth/roles/add', { token, govde: { role: 'PROVIDER', password: 'GucluSifre12', ...govde } });
/** Testte "kullanıcı bir süre önce giriş yaptı" durumu: oturum açılışını geri al. */
const oturumuEskit = (tel, sn = 300) => db.prepare(
  'UPDATE user_sessions SET created_at = ? WHERE user_id = (SELECT id FROM users WHERE phone = ?)',
).run(new Date(Date.now() - sn * 1000).toISOString(), tel);
const roller = async (tel) => (await db.prepare('SELECT roles, active_role FROM users WHERE phone = ?').get(tel));

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

test('doğru şifre + taze telefon doğrulaması: rol eklenir, aktif rol değişir; ikinci kez 409', async () => {
  const tel = '5421110001';
  const tk = await hizmetAlan(tel);
  await oturumuEskit(tel);
  const r = await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-1', phone_number: `+90${tel}` }) });
  assert.equal(r.durum, 204, JSON.stringify(r.json));
  assert.deepEqual({ ...(await roller(tel)) }, { roles: 'CUSTOMER,PROVIDER', active_role: 'PROVIDER' });
  // Hizmet veren profili ve ilan listesi artık açılır.
  const ilce = (await db.prepare('SELECT name FROM districts WHERE active = TRUE ORDER BY name LIMIT 1').get()).name;
  const kat = (await db.prepare('SELECT name FROM categories WHERE active = TRUE ORDER BY sort LIMIT 1').get()).name;
  assert.equal((await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: tk, govde: { categories: [kat], districts: [ilce] } })).durum, 200);
  assert.equal((await istek('/api/v1/listings/available', { yontem: 'GET', token: tk })).durum, 200);
  const tekrar = await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-1', phone_number: `+90${tel}` }) });
  assert.equal(tekrar.durum, 409);
});

test('yanlış şifre, numara uyuşmazlığı ve yakın doğrulama eksikliği reddedilir; rol eklenmez', async () => {
  const tel = '5421110002';
  const tk = await hizmetAlan(tel);
  await oturumuEskit(tel);
  const iyi = { sub: 'fb-rol-2', phone_number: `+90${tel}` };

  const a = await rolEkle(tk, { password: 'YanlisSifre99', firebaseIdToken: belge(iyi) });
  assert.equal(a.durum, 400); assert.equal(a.json.error.code, 'WRONG_PASSWORD');

  const b = await rolEkle(tk, { firebaseIdToken: belge({ ...iyi, phone_number: '+905429999999' }) });
  assert.equal(b.durum, 400); assert.equal(b.json.error.code, 'OTP_INVALID');

  // Belge YENİ (iat taze) ama son doğrulama 11 dk önce → yeniden doğrulama şart.
  const c = await rolEkle(tk, { firebaseIdToken: belge({ ...iyi, auth_time: an() - 11 * 60 }) });
  assert.equal(c.durum, 400); assert.equal(c.json.error.code, 'REAUTH_REQUIRED');

  // Taze ama son oturum ŞİFREYLE açılmış (telefon değil).
  const d = await rolEkle(tk, { firebaseIdToken: belge({ ...iyi, firebase: { sign_in_provider: 'password' } }) });
  assert.equal(d.durum, 400); assert.equal(d.json.error.code, 'REAUTH_REQUIRED');

  // Yöntem bilgisi hiç yok.
  const e = await rolEkle(tk, { firebaseIdToken: belge({ ...iyi, firebase: undefined }) });
  assert.equal(e.durum, 400); assert.equal(e.json.error.code, 'REAUTH_REQUIRED');

  assert.equal((await roller(tel)).roles, 'CUSTOMER');
});

test('giriş belgesi yeniden kullanılamaz: doğrulama oturum açıldıktan SONRA yapılmalı', async () => {
  // Telefonla giriş: Firebase doğrulaması (auth_time) sunucu oturumundan
  // hemen ÖNCE olur. Aynı belge (ya da yenilenmiş hâli: iat yeni, auth_time
  // aynı) 10 dk içinde bile rol eklemede KABUL EDİLMEZ.
  const tel = '5421110007';
  const tk = await hizmetAlan(tel);
  await oturumuEskit(tel, 120); // oturum 2 dk önce açıldı
  const giris = an() - 125; // girişteki telefon doğrulaması oturumdan 5 sn önce
  const a = await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-7', phone_number: `+90${tel}`, auth_time: giris, iat: an() - 2 }) });
  assert.equal(a.durum, 400); assert.equal(a.json.error.code, 'REAUTH_REQUIRED');
  // Oturumdan hemen sonra (30 sn pay içinde) yapılan doğrulama da kabul edilmez.
  const b = await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-7', phone_number: `+90${tel}`, auth_time: an() - 110 }) });
  assert.equal(b.durum, 400); assert.equal(b.json.error.code, 'REAUTH_REQUIRED');
  // Rol ekleme sırasında YENİ kod doğrulandı → kabul.
  const c = await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-7', phone_number: `+90${tel}`, auth_time: an() - 3 }) });
  assert.equal(c.durum, 204, JSON.stringify(c.json));
});

test('imza, proje ve süre denetimleri korunur; istenmemiş sunucu kodu (123456) reddedilir', async () => {
  const tel = '5421110003';
  const tk = await hizmetAlan(tel);
  await oturumuEskit(tel);
  const iyi = { sub: 'fb-rol-3', phone_number: `+90${tel}` };
  const yabanci = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;

  // ⚠ 400 (401 DEĞİL): istemci 401'de oturumu yenileyip isteği tekrarlardı.
  const a = await rolEkle(tk, { firebaseIdToken: belge(iyi, { anahtar: yabanci }) });
  assert.equal(a.durum, 400); assert.equal(a.json.error.code, 'PHONE_PROOF_INVALID');
  const b = await rolEkle(tk, { firebaseIdToken: belge({ ...iyi, aud: 'baska-proje', iss: 'https://securetoken.google.com/baska-proje' }) });
  assert.equal(b.durum, 400); assert.equal(b.json.error.code, 'PHONE_PROOF_INVALID');
  const c = await rolEkle(tk, { firebaseIdToken: belge({ ...iyi, exp: an() - 60 }) });
  assert.equal(c.durum, 400); assert.equal(c.json.error.code, 'PHONE_PROOF_INVALID');
  // Oturum hâlâ geçerli (kanıt hatası oturumu kapatmaz).
  assert.equal((await istek('/api/v1/users/me', { yontem: 'GET', token: tk })).durum, 200);
  // Firebase kanıtı yok; sunucudan ROLE_ADD kodu hiç istenmedi.
  const d = await rolEkle(tk, { otpCode: '123456' });
  assert.equal(d.durum, 400);
  assert.match(d.json.error.code, /^OTP_(EXPIRED|INVALID)$/);

  assert.equal((await roller(tel)).roles, 'CUSTOMER');
});

test('kullanıcı başına hız sınırı: 15 dk içinde 6. deneme 429 (doğru bilgiyle bile)', async () => {
  const tel = '5421110004';
  const tk = await hizmetAlan(tel);
  await oturumuEskit(tel);
  const yabanci = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;
  // Yanlış şifre (3) + geçersiz telefon kanıtı (2): HEPSİ sınırı tüketir.
  for (let i = 0; i < 3; i++) {
    assert.equal((await rolEkle(tk, { password: `Yanlis${i}Sifre9`, firebaseIdToken: belge({ sub: 'fb-rol-4', phone_number: `+90${tel}` }) })).durum, 400);
  }
  assert.equal((await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-4', phone_number: `+90${tel}` }, { anahtar: yabanci }) })).durum, 400);
  assert.equal((await rolEkle(tk, { otpCode: '123456' })).durum, 400);
  const r = await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-4', phone_number: `+90${tel}` }) });
  assert.equal(r.durum, 429);
  assert.equal(r.json.error.code, 'RATE_LIMITED');
  assert.equal((await roller(tel)).roles, 'CUSTOMER');
  // 429 oturumu kapatmaz.
  assert.equal((await istek('/api/v1/users/me', { yontem: 'GET', token: tk })).durum, 200);
  // Sınır kullanıcıya özeldir: başka kullanıcı etkilenmez.
  const tel2 = '5421110005';
  const tk2 = await hizmetAlan(tel2);
  await oturumuEskit(tel2);
  assert.equal((await rolEkle(tk2, { firebaseIdToken: belge({ sub: 'fb-rol-5', phone_number: `+90${tel2}` }) })).durum, 204);
});

test('kayıt davranışı DEĞİŞMEDİ: yakın doğrulama şartı yalnız rol eklemede', async () => {
  // Kayıtta auth_time/sign_in_provider aranmaz (önceki davranış).
  const tel = '5421110006';
  const r = await istek('/api/v1/auth/register', { govde: {
    phone: tel, password: 'GucluSifre12', name: 'Kayit Deneme', email: 'kd@ornek.com', role: 'CUSTOMER',
    firebaseIdToken: belge({ sub: 'fb-rol-6', phone_number: `+90${tel}`, auth_time: an() - 50 * 60, firebase: undefined }),
  } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
});

test('zaman karşılaştırması: SQLite (ISO metin) ve PostgreSQL (timestamptz → ISO) biçimleri aynı sonucu verir', async () => {
  const { yakinTelefonDogrulamasi } = await import('../src/routes/kullanici.js');
  const simdi = Date.parse('2026-10-15T12:00:00.000Z');
  const sn = (iso) => Math.floor(Date.parse(iso) / 1000);
  // Aynı an, farklı yazımlar: SQLite simdi() çıktısı, PostgreSQL ayrıştırıcısının
  // (db.js setTypeParser 1184 → toISOString) çıktısı, ofsetli yazım ve Date nesnesi.
  const acilislar = ['2026-10-15T11:55:00.000Z', '2026-10-15T11:55:00.123Z', '2026-10-15T14:55:00.000+03:00', new Date('2026-10-15T11:55:00.000Z')];
  const gecer = (acilis, auth) => {
    try { yakinTelefonDogrulamasi({ firebase: { sign_in_provider: 'phone' }, auth_time: auth }, acilis, simdi); return true; } catch (e) { assert.equal(e.kod, 'REAUTH_REQUIRED'); return false; }
  };
  for (const a of acilislar) {
    const acilis = typeof a === 'string' ? sn(a) : Math.floor(a.getTime() / 1000);
    assert.equal(gecer(a, acilis + 30), true, `sınır (açılış+30 sn) kabul: ${a}`);
    assert.equal(gecer(a, acilis + 29), false, `açılış+29 sn red: ${a}`);
    assert.equal(gecer(a, acilis - 1), false, `oturumdan önce red: ${a}`);
  }
  // 10 dakika penceresi (saniye birimi): tam 600 sn kabul, 601 sn red.
  const eski = '2026-10-15T11:00:00.000Z';
  assert.equal(gecer(eski, sn('2026-10-15T11:50:00.000Z')), true);
  assert.equal(gecer(eski, sn('2026-10-15T11:49:59.000Z')), false);
  // Geçersiz ya da boş açılış zamanı denetimi ETKİSİZLEŞTİRMEZ (0 = 1970'e dönüşmez).
  for (const bos of ['gecersiz-tarih', null, undefined, '']) {
    assert.equal(gecer(bos, sn('2026-10-15T11:59:00.000Z')), false, String(bos));
  }
  // auth_time saniye birimindedir; yanlışlıkla milisaniye gelse "gelecek" sayılır ve
  // Firebase doğrulaması (firebaseTokenDogrula: auth_time > şimdi+60 → red) geçmez.
  const { firebaseTokenDogrula } = await import('../src/firebase_token.js');
  assert.equal(await firebaseTokenDogrula(belge({ sub: 'ms', phone_number: '+905420000000', auth_time: Date.now() })), null);
});

test('rol kuralları değişmedi: iki rolü olan SMS olmadan geçiş yapar; mevcut rol yeniden eklenemez; yalnız iki rol', async () => {
  const tel = '5421110008';
  const tk = await hizmetAlan(tel);
  await oturumuEskit(tel);
  // Geçersiz rol adı.
  assert.equal((await rolEkle(tk, { role: 'ADMIN', firebaseIdToken: belge({ sub: 'fb-rol-8', phone_number: `+90${tel}` }) })).durum, 400);
  // Mevcut rol (CUSTOMER) yeniden eklenemez — doğru kanıtla bile.
  const ayni = await rolEkle(tk, { role: 'CUSTOMER', firebaseIdToken: belge({ sub: 'fb-rol-8', phone_number: `+90${tel}` }) });
  assert.equal(ayni.durum, 409);
  // Yeni rol yeni telefon doğrulamasıyla eklenir.
  assert.equal((await rolEkle(tk, { firebaseIdToken: belge({ sub: 'fb-rol-8', phone_number: `+90${tel}` }) })).durum, 204);
  assert.equal((await roller(tel)).roles, 'CUSTOMER,PROVIDER');
  // İki rolü olan kullanıcı: rol değişimi şifre/SMS İSTEMEZ ve hız sınırını tüketmez.
  for (let i = 0; i < 4; i++) {
    const hedef = i % 2 === 0 ? 'CUSTOMER' : 'PROVIDER';
    const r = await istek('/api/v1/users/me/active-role', { token: tk, govde: { role: hedef } });
    assert.equal(r.durum, 200, JSON.stringify(r.json));
    assert.equal((await roller(tel)).active_role, hedef);
  }
  // Hesapta olmayan rol değişimle eklenemez (değişmeyen kural).
  const tel2 = '5421110009';
  const tk2 = await hizmetAlan(tel2);
  assert.equal((await istek('/api/v1/users/me/active-role', { token: tk2, govde: { role: 'PROVIDER' } })).durum, 403);
  assert.equal((await roller(tel2)).roles, 'CUSTOMER');
});
