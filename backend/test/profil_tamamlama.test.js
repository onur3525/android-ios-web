// PROFİL TAMAMLAMA VE TELEFON SAHİPLİĞİ (4 Kas, kullanıcı kararı)
//
//  · Kayıt formu yalnız ad, soyad, telefon, e-posta, şifre ister; SMS kodu
//    İSTEMEZ, telefon doğrulanmamış kaydedilir.
//  · Telefon doğrulaması + adres (hizmet verende + kategori/bölge) sonradan,
//    tek uçta (`/profiles/me/complete`) tamamlanır; kod doğrulanmadan
//    telefon doğrulanmış sayılmaz.
//  · Kapılar SUNUCUDA: ilan açma, teklif isteme, iş listesi, teklif verme.
//  · Bir numara, bir hesap: aynı rolde ikinci kayıt yok; diğer rolde kayıt
//    şifre eşleşirse aynı hesaba rol ekler; doğrulanmamış numarayı gerçek
//    sahibi SMS koduyla alır.
//  · Firebase e-posta eşleşmesi yalnız bizde de doğrulanmış e-postada.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createSign, generateKeyPairSync } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { testSertifikaGetiricisi } = await import('../src/firebase_token.js');

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
testSertifikaGetiricisi(async () => ({ sertifikalar: { k1: publicKey.export({ type: 'spki', format: 'pem' }) }, sureSn: 3600 }));
function idToken(yuk) {
  const an = Math.floor(Date.now() / 1000);
  const bas = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'k1', typ: 'JWT' })).toString('base64url');
  const govde = Buffer.from(JSON.stringify({
    aud: 'hizmetcep-fe036', iss: 'https://securetoken.google.com/hizmetcep-fe036', iat: an - 10, auth_time: an - 10, exp: an + 3600, ...yuk,
  })).toString('base64url');
  return `${bas}.${govde}.${createSign('RSA-SHA256').update(`${bas}.${govde}`).sign(privateKey).toString('base64url')}`;
}

let db, sunucu, taban, adres, hizmet, ilce;
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
const kayitGovdesi = (tel, rol, ek = {}) => ({
  termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'GucluSifre12', name: 'Deneme Kişi',
  email: `p${tel}@ornek.com`, role: rol, ...ek,
});
async function kaydol(tel, rol, ek) {
  await temizle();
  return istek('/api/v1/auth/register', { yontem: 'POST', govde: kayitGovdesi(tel, rol, ek) });
}
async function kod(tel, amac) {
  await temizle();
  await db.prepare('DELETE FROM otp_codes WHERE phone = ?').run(tel);
  const r = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: amac } });
  assert.ok(r.durum < 300, JSON.stringify(r.json));
  return globalThis.__sonOtp;
}
const ben = async (token) => (await istek('/api/v1/users/me', { token })).json;
const ilanAc = (token) => istek('/api/v1/listings', { yontem: 'POST', token, govde: { title: hizmet, location: `${adres.neighborhood}, ${adres.district} / ${adres.city}`, description: 'banyo bataryası değişecek' } });

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
  adres = { city: a.city, district: a.district, neighborhood: a.neighborhood };
  ilce = a.district;
  hizmet = (await db.prepare('SELECT name FROM services WHERE active = TRUE LIMIT 1').get()).name;
});
after(async () => { sunucu?.closeAllConnections?.(); sunucu?.close(); await db?.close(); });

test('kayıt SMS kodu olmadan açılır; telefon doğrulanmamış, profil eksik görünür', async () => {
  const r = await kaydol('5510000001', 'CUSTOMER');
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const u = await ben(r.json.accessToken);
  assert.equal(u.phoneVerified, false);
  assert.deepEqual(u.profileMissing.customer, ['PHONE', 'ADDRESS']);
  assert.deepEqual(u.profileMissing.provider, ['PHONE', 'ADDRESS', 'SERVICES']);
});

test('geçersiz kanıtla kayıt reddedilir (eski uygulama yolu)', async () => {
  const r = await kaydol('5510000002', 'CUSTOMER', { otpCode: '000000' });
  assert.equal(r.durum, 400);
});

test('hizmet alan: profil eksikken ilan açılamaz ve teklif istenemez (sunucu kapısı)', async () => {
  const r = await kaydol('5510000003', 'CUSTOMER');
  const t = r.json.accessToken;
  const ilan = await ilanAc(t);
  assert.equal(ilan.durum, 403);
  assert.equal(ilan.json.error.code, 'PROFILE_INCOMPLETE');
  assert.deepEqual(ilan.json.error.details, { role: 'CUSTOMER', missing: ['PHONE', 'ADDRESS'] });
  const talep = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: t, govde: { saglayiciId: '00000000-0000-0000-0000-000000000000', hizmet, aciklama: 'kombi bakımı yapılacak' } });
  assert.equal(talep.durum, 403);
  assert.equal(talep.json.error.code, 'PROFILE_INCOMPLETE');
});

test('yanlış kodla tamamlama telefonu doğrulamaz; doğru kodla profil tamamlanır ve bir daha istenmez', async () => {
  const tel = '5510000004';
  const t = (await kaydol(tel, 'CUSTOMER')).json.accessToken;
  const dogru = await kod(tel, 'PHONE_VERIFY');
  const yanlis = dogru === '111111' ? '222222' : '111111';
  const k1 = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t, govde: { phone: tel, otpCode: yanlis, address: adres } });
  assert.equal(k1.durum, 400);
  assert.equal((await ben(t)).phoneVerified, false, 'yanlış kod telefonu doğrulamaz');
  assert.equal(await db.prepare('SELECT COUNT(*) n FROM addresses WHERE user_id = (SELECT id FROM users WHERE phone = ?)').get(tel).then((x) => x.n), 0,
    'başarısız istekte adres de yazılmaz');
  const k2 = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t, govde: { phone: tel, otpCode: dogru, address: adres } });
  assert.equal(k2.durum, 200, JSON.stringify(k2.json));
  assert.equal(k2.json.phoneVerified, true);
  assert.deepEqual(k2.json.profileMissing.customer, []);
  assert.equal((await ilanAc(t)).durum, 200);
  // Tamamlanmış parça yeniden istenmez: kodsuz yalnız adres güncellenebilir.
  const k3 = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t, govde: { address: adres } });
  assert.equal(k3.durum, 200);
  // Doğrulanmış telefon bu uçtan değiştirilemez (ayrı, şifreli akış).
  const k4 = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t, govde: { phone: '5510000099' } });
  assert.equal(k4.durum, 400);
});

test('hizmet veren: profil eksikken iş listesi ve teklif kapalı; tamamlanınca açılır', async () => {
  const alanTel = '5510000005';
  const alan = (await kaydol(alanTel, 'CUSTOMER')).json.accessToken;
  await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: alan, govde: { phone: alanTel, otpCode: await kod(alanTel, 'PHONE_VERIFY'), address: adres } });
  const ilan = await ilanAc(alan);
  assert.equal(ilan.durum, 200);

  const tel = '5510000006';
  const usta = (await kaydol(tel, 'PROVIDER')).json.accessToken;
  const liste = await istek('/api/v1/listings/available', { token: usta });
  assert.equal(liste.durum, 403);
  assert.equal(liste.json.error.code, 'PROFILE_INCOMPLETE');
  const teklif = () => istek('/api/v1/offers', { yontem: 'POST', token: usta, govde: { listingId: ilan.json.id, amountTl: 500, note: '' } });
  assert.equal((await teklif()).durum, 403);

  // Telefon + adres tamam, hizmet listesi yok → hâlâ kapalı.
  await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: usta, govde: { phone: tel, otpCode: await kod(tel, 'PHONE_VERIFY'), address: adres } });
  assert.deepEqual((await ben(usta)).profileMissing.provider, ['SERVICES']);
  assert.equal((await teklif()).durum, 403);

  // Boş liste kabul edilmez.
  const bos = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: usta, govde: { provider: { categories: [], districts: [ilce] } } });
  assert.equal(bos.durum, 400);
  const tam = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: usta, govde: { provider: { categories: [hizmet], districts: [ilce] } } });
  assert.equal(tam.durum, 200);
  assert.deepEqual(tam.json.profileMissing.provider, []);
  assert.equal((await istek('/api/v1/listings/available', { token: usta })).durum, 200);
  assert.equal((await teklif()).durum, 200);
});

test('hizmet veren profili boşaltılamaz', async () => {
  const tel = '5510000007';
  const usta = (await kaydol(tel, 'PROVIDER')).json.accessToken;
  const r = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: usta, govde: { categories: [], districts: [] } });
  assert.equal(r.durum, 400);
});

test('bir numara bir hesap: aynı rolde ikinci kayıt yok; diğer rolde şifre eşleşirse aynı hesaba rol eklenir', async () => {
  const tel = '5510000008';
  const ilk = await kaydol(tel, 'CUSTOMER');
  assert.equal(ilk.durum, 200);
  const sayi = async () => (await db.prepare('SELECT COUNT(*) n FROM users WHERE phone = ?').get(tel)).n;

  const ayniRol = await kaydol(tel, 'CUSTOMER', { email: 'baska1@ornek.com' });
  assert.equal(ayniRol.durum, 409);

  const yanlisSifre = await kaydol(tel, 'PROVIDER', { email: 'baska2@ornek.com', password: 'BaskaSifre99' });
  assert.equal(yanlisSifre.durum, 409, 'başkasının hesabına rol eklenemez');

  const ek = await kaydol(tel, 'PROVIDER', { email: 'baska3@ornek.com' });
  assert.equal(ek.durum, 200, JSON.stringify(ek.json));
  assert.equal(await sayi(), 1, 'ikinci hesap açılmaz');
  const u = await ben(ek.json.accessToken);
  assert.deepEqual([...u.roles].sort(), ['CUSTOMER', 'PROVIDER']);
  assert.equal(u.activeRole, 'PROVIDER', 'kayıtta seçilen rolle açılır');
});

test('doğrulanmamış numarayı gerçek sahibi SMS koduyla alır (kayıtta ve tamamlamada); doğrulanmış numara alınamaz', async () => {
  const tel = '5510000009';
  const isgalci = (await kaydol(tel, 'CUSTOMER', { email: 'isgal@ornek.com' })).json.accessToken;
  const kodsuz = await kaydol(tel, 'CUSTOMER', { email: 'sahip@ornek.com', password: 'SahipSifre123' });
  assert.equal(kodsuz.durum, 409);
  assert.equal(kodsuz.json.error.code, 'PHONE_CLAIM_REQUIRED');

  const sahip = await kaydol(tel, 'CUSTOMER', { email: 'sahip@ornek.com', password: 'SahipSifre123', otpCode: await kod(tel, 'REGISTER') });
  assert.equal(sahip.durum, 200, JSON.stringify(sahip.json));
  assert.equal((await ben(sahip.json.accessToken)).phoneVerified, true);
  const eski = await ben(isgalci);
  assert.equal(eski.phone, '');
  assert.ok(eski.profileMissing.customer.includes('PHONE'), 'eski hesaba telefon yeniden sorulur');

  // Artık doğrulanmış: ne kayıtta ne tamamlamada alınabilir.
  assert.equal((await kaydol(tel, 'CUSTOMER', { email: 'ucuncu@ornek.com', password: 'UcuncuSifre12' })).durum, 409);
  const tamamla = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: isgalci, govde: { phone: tel, otpCode: '123456', address: adres } });
  assert.equal(tamamla.durum, 409);

  // Tamamlamada sahiplenme: doğrulanmamış numara kanıtı veren hesaba geçer.
  const tel2 = '5510000010';
  const a = (await kaydol(tel2, 'CUSTOMER', { email: 'a2@ornek.com' })).json.accessToken;
  const bTel = '5510000011';
  const b = (await kaydol(bTel, 'CUSTOMER', { email: 'b2@ornek.com' })).json.accessToken;
  const al = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: b, govde: { phone: tel2, otpCode: await kod(tel2, 'PHONE_VERIFY'), address: adres } });
  assert.equal(al.durum, 200, JSON.stringify(al.json));
  assert.equal(al.json.phone, tel2);
  assert.equal((await ben(a)).phone, '');
});

test('SMS ile şifre sıfırlama ve Firebase telefon girişi yalnız doğrulanmış numarada', async () => {
  const tel = '5510000012';
  await kaydol(tel, 'CUSTOMER', { email: 'sifirla@ornek.com' });
  await temizle();
  await db.prepare('DELETE FROM otp_codes WHERE phone = ?').run(tel);
  globalThis.__sonOtp = undefined;
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'FORGOT' } });
  assert.equal(globalThis.__sonOtp, undefined, 'doğrulanmamış numaraya sıfırlama kodu gitmez');
  const fb = await istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: idToken({ sub: 'fb-tel-1', phone_number: `+90${tel}` }) } });
  assert.equal(fb.durum, 404, 'numaranın doğrulanmamış hesabına Firebase telefon girişi açılmaz');
});

test('Firebase e-posta eşleşmesi yalnız bizde de doğrulanmış e-postada (hesap ele geçirme önlemi)', async () => {
  const r = await kaydol('5510000013', 'CUSTOMER', { email: 'kurban@ornek.com' });
  assert.equal(r.durum, 200);
  const fb = () => istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: idToken({ sub: 'fb-eposta-1', email: 'kurban@ornek.com', email_verified: true }) } });
  assert.equal((await fb()).durum, 404, 'bizde doğrulanmamış e-posta eşleşmez');
  await db.prepare(`UPDATE users SET email_verified = TRUE WHERE email = 'kurban@ornek.com'`).run();
  await temizle();
  assert.equal((await fb()).durum, 200, 'doğrulanmış e-postada eşleşme sürer');
});

test('ilan konumu tanımlı bir ilçe içermeli', async () => {
  const tel = '5510000014';
  const t = (await kaydol(tel, 'CUSTOMER')).json.accessToken;
  await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t, govde: { phone: tel, otpCode: await kod(tel, 'PHONE_VERIFY'), address: adres } });
  const bozuk = await istek('/api/v1/listings', { yontem: 'POST', token: t, govde: { title: hizmet, location: 'Mahalle, null / İzmir', description: 'banyo bataryası değişecek' } });
  assert.equal(bozuk.durum, 400);
});

test('kayıt IP başına sınırlıdır', async () => {
  await temizle();
  let son;
  for (let i = 0; i < 31; i++) {
    son = await istek('/api/v1/auth/register', { yontem: 'POST', govde: kayitGovdesi(`55200000${String(i).padStart(2, '0')}`, 'CUSTOMER') });
  }
  assert.equal(son.durum, 429);
});

test('doğrulama kodu yanıtta ve gönderim kaydında açık metin olarak bulunmaz', async () => {
  const tel = '5510000015';
  await kaydol(tel, 'CUSTOMER');
  await temizle();
  await db.prepare('DELETE FROM otp_codes WHERE phone = ?').run(tel);
  const r = await fetch(`${taban}/api/v1/auth/otp/request`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ phone: tel, purpose: 'PHONE_VERIFY' }) });
  const metin = await r.text();
  const kodu = globalThis.__sonOtp;
  assert.ok(kodu && !metin.includes(kodu), 'kod yanıtta yok');
  const kayit = await db.prepare('SELECT code_hash FROM otp_codes WHERE phone = ?').get(tel);
  assert.notEqual(kayit.code_hash, kodu, 'kod özet olarak saklanır');
  for (const m of await db.prepare('SELECT * FROM outbound_messages').all()) {
    assert.ok(!JSON.stringify(m).includes(kodu), 'gönderim kaydında kod yok');
  }
});

test('e-posta ile giriş korunur: SMS\'siz kayıt Firebase e-posta kullanıcısına bağlanır; telefon sonra aynı kullanıcıya eklenir', async () => {
  const tel = '5510000016';
  const yanlis = await kaydol(tel, 'CUSTOMER', { email: 'bag@ornek.com', firebaseEmailToken: idToken({ sub: 'fb-bag-0', email: 'baska@ornek.com' }) });
  assert.equal(yanlis.durum, 400, 'başka adresin belgesi kabul edilmez');
  const r = await kaydol(tel, 'CUSTOMER', { email: 'bag@ornek.com', firebaseEmailToken: idToken({ sub: 'fb-bag-1', email: 'bag@ornek.com', email_verified: false }) });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal((await db.prepare('SELECT firebase_uid FROM users WHERE phone = ?').get(tel)).firebase_uid, 'fb-bag-1');
  // E-posta ile giriş (Firebase) aynı hesaba açılır.
  await temizle();
  const giris = await istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: idToken({ sub: 'fb-bag-1', email: 'bag@ornek.com' }) } });
  assert.equal(giris.durum, 200);
  // Tamamlama: telefon aynı Firebase kullanıcısına eklenmiş belgeyle doğrulanır.
  const t = giris.json.accessToken;
  const k = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t, govde: {
    phone: tel, firebaseIdToken: idToken({ sub: 'fb-bag-1', phone_number: `+90${tel}`, email: 'bag@ornek.com' }), address: adres,
  } });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  assert.equal(k.json.phoneVerified, true);
  assert.deepEqual(k.json.profileMissing.customer, []);
  // Başka numaranın belgesi kabul edilmez.
  const tel2 = '5510000017';
  const t2 = (await kaydol(tel2, 'CUSTOMER', { email: 'bag2@ornek.com' })).json.accessToken;
  const kotu = await istek('/api/v1/profiles/me/complete', { yontem: 'POST', token: t2, govde: {
    phone: tel2, firebaseIdToken: idToken({ sub: 'fb-bag-2', phone_number: '+905519999999' }), address: adres,
  } });
  assert.equal(kotu.durum, 400);
  assert.equal((await ben(t2)).phoneVerified, false);
});
