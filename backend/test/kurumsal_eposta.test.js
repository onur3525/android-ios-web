// KURUMSAL E-POSTA (21 Eki, kullanıcı isteği): doğrulama e-postaları
// HizmetCep tasarımıyla sunucudan gider; bağlantıyı Firebase üretir.
// ⚠ Gerçek Firebase YOK: Identity Toolkit çağrıları test kancasıyla
// yakalanır. E-posta kanalı geliştirme ortamında "log" sağlayıcısıdır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_SESSIZ = '1';
process.env.HC_TEST_OTP_KANCASI = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { firebaseYonetimTestGondericisi } = await import('../src/firebase_token.js');
const { epostaIcerigi } = await import('../src/bildirim.js');
const { kurumsalEposta, kacis } = await import('../src/eposta_tasarimi.js');

let db, sunucu, taban;
/** Firebase'deki sahte kullanıcılar ve yapılan çağrılar. */
const fbKullanicilar = new Map();
const cagrilar = [];
firebaseYonetimTestGondericisi(async (islem, govde) => {
  cagrilar.push({ islem, govde });
  if (islem === 'lookup') {
    const k = fbKullanicilar.get(govde.localId[0]);
    return k ? { ok: true, durum: 200, kod: '', veri: { users: [{ localId: govde.localId[0], ...k }] } } : { ok: false, durum: 400, kod: 'USER_NOT_FOUND', veri: {} };
  }
  if (islem === 'update') {
    fbKullanicilar.set(govde.localId, { ...(fbKullanicilar.get(govde.localId) ?? {}), email: govde.email });
    return { ok: true, durum: 200, kod: '', veri: {} };
  }
  if (islem === 'sendOobCode') {
    return { ok: true, durum: 200, kod: '', veri: { oobLink: `https://hizmetcep-fe036.firebaseapp.com/__/auth/action?mode=${govde.requestType === 'VERIFY_EMAIL' ? 'verifyEmail' : 'verifyAndChangeEmail'}&oobCode=GIZLI123` } };
  }
  return { ok: false, durum: 400, kod: 'BILINMIYOR', veri: {} };
});

async function istek(yol, { yontem = 'POST', govde, token } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const tur = r.headers.get('content-type');
  const m = await r.text();
  return { durum: r.status, json: m && tur?.includes('json') ? JSON.parse(m) : null, tur };
}

async function hesap(tel, { uid } = {}) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  const o = await istek('/api/v1/auth/otp/request', { govde: { phone: tel, purpose: 'REGISTER' } });
  assert.equal(o.durum, 204, JSON.stringify(o.json));
  const r = await istek('/api/v1/auth/register', { govde: { termsAccepted: true, aydinlatmaAccepted: true, phone: tel, password: 'GucluSifre12', name: 'Eposta Deneme', email: `e${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  if (uid) await db.prepare('UPDATE users SET firebase_uid = ? WHERE phone = ?').run(uid, tel);
  return r.json.accessToken;
}

const sonMesaj = (tel) => db.prepare(
  `SELECT * FROM outbound_messages WHERE user_id = (SELECT id FROM users WHERE phone = ?) ORDER BY created_at DESC LIMIT 1`,
).get(tel);

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  firebaseYonetimTestGondericisi(null);
  sunucu?.close();
  await db?.close();
});

test('şablon: logo, düğme, alt bilgi; girdi kaçışlanır; yalnız https bağlantı düğme olur', () => {
  const x = epostaIcerigi('EPOSTA_DOGRULAMA', { AD: '<script>x</script>', EPOSTA: 'a@b.com', BAGLANTI: 'https://ornek.com/a?b=1&c=2', DESTEK: 'destek@hizmetcep.com' });
  // 21 Eki: tek, büyük logo (beyaz zemin görselin içinde).
  assert.ok(x.html.includes('/eposta-varlik/eposta_logo.png'));
  assert.ok(x.html.includes('width="280"'));
  // Beyaz görünüm: koyu moda çevirme isteyen istemcilere "yalnız açık" bildirilir.
  assert.ok(x.html.includes('<meta name="color-scheme" content="light only">'));
  assert.ok(x.html.includes('E-postamı Doğrula'));
  assert.ok(x.html.includes('href="https://ornek.com/a?b=1&amp;c=2"'));
  // 21 Eki: uzun adres metin olarak yazılmaz (Gmail e-postayı küçültüyordu);
  // yalnız bağlantı olarak ve düz metin sürümünde bulunur.
  assert.equal(x.html.split('https://ornek.com/a?b=1&amp;c=2').length - 1, 2, 'adres yalnız iki href içinde olmalı');
  assert.ok(x.html.includes('bu bağlantıya dokunun'));
  assert.ok(x.html.includes('destek@hizmetcep.com'));
  assert.ok(!x.html.includes('<script>'), 'kaçışlanmamış girdi');
  assert.ok(x.html.includes('&lt;script&gt;'));
  assert.ok(x.text.includes('https://ornek.com/a?b=1&c=2'));
  const kotu = kurumsalEposta({ konu: 'k', baslik: 'b', paragraflar: ['p'], buton: { metin: 'Aç', adres: 'javascript:alert(1)' } });
  assert.ok(!kotu.html.includes('javascript:'), 'https olmayan bağlantı çizildi');
  assert.equal(kacis(`<"'&>`), '&lt;&quot;&#39;&amp;&gt;');
});

test('eski düz metin şablonları da kurumsal kalıpla çizilir', () => {
  const x = epostaIcerigi('HESAP_ASKIYA_ALINDI', { NEDEN: 'Kural <ihlali>', DESTEK: 'destek@hizmetcep.com' });
  assert.ok(x.html.includes('Hesabınız askıya alındı'));
  assert.ok(x.html.includes('Kural &lt;ihlali&gt;'));
  assert.ok(x.html.includes('/eposta-varlik/eposta_logo.png'));
});

test('logo görselleri sunulur; beyaz liste dışı ad 404', async () => {
  for (const ad of ['eposta_logo.png', 'wordmark.png', 'logo_mark.png']) {
    const r = await istek(`/eposta-varlik/${ad}`, { yontem: 'GET' });
    assert.equal(r.durum, 200, ad);
    assert.equal(r.tur, 'image/png');
  }
  assert.equal((await istek('/eposta-varlik/../../package.json', { yontem: 'GET' })).durum, 404);
  assert.equal((await istek('/eposta-varlik/logo.png', { yontem: 'GET' })).durum, 404);
});

test('mevcut adres: Firebase e-postası boşsa yazılır, bağlantı üretilir, HizmetCep e-postası gider; bağlantı kayda düz yazılmaz', async () => {
  const tel = '5421120001';
  const tk = await hesap(tel, { uid: 'fb-ep-1' });
  fbKullanicilar.set('fb-ep-1', { phoneNumber: `+90${tel}` });
  cagrilar.length = 0;
  const r = await istek('/api/v1/profiles/me/email/verification', { token: tk });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.deepEqual(r.json, { sent: true, email: `e${tel}@ornek.com` });
  // İlk okuma: kullanıcı bağlantıya zaten tıkladı mı (eşitleme).
  assert.deepEqual(cagrilar.map((c) => c.islem), ['lookup', 'lookup', 'update', 'sendOobCode']);
  assert.equal(cagrilar[2].govde.email, `e${tel}@ornek.com`);
  assert.equal(cagrilar[2].govde.emailVerified, false);
  assert.deepEqual(cagrilar[3].govde, { requestType: 'VERIFY_EMAIL', email: `e${tel}@ornek.com`, returnOobLink: true });
  const m = await sonMesaj(tel);
  assert.equal(m.channel, 'EMAIL');
  assert.equal(m.template, 'EPOSTA_DOGRULAMA');
  assert.equal(m.status, 'SENT');
  assert.equal(m.target, `e${tel}@ornek.com`);
  assert.ok(!m.body.includes('GIZLI123'), 'doğrulama bağlantısı kayda düz yazıldı');
});

test('yeni adres: "doğrula ve değiştir" bağlantısı yeni adrese gider; profil adresi DEĞİŞMEZ', async () => {
  const tel = '5421120002';
  const tk = await hesap(tel, { uid: 'fb-ep-2' });
  fbKullanicilar.set('fb-ep-2', { email: `e${tel}@ornek.com` });
  cagrilar.length = 0;
  const r = await istek('/api/v1/profiles/me/email/change-request', { token: tk, govde: { newEmail: 'Yeni.Adres@Ornek.com', currentPassword: 'GucluSifre12' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.deepEqual(r.json, { sent: true, email: 'yeni.adres@ornek.com' });
  assert.deepEqual(cagrilar.map((c) => c.islem), ['lookup', 'sendOobCode']);
  assert.deepEqual(cagrilar[1].govde, { requestType: 'VERIFY_AND_CHANGE_EMAIL', email: `e${tel}@ornek.com`, newEmail: 'yeni.adres@ornek.com', returnOobLink: true });
  const m = await sonMesaj(tel);
  assert.equal(m.template, 'EPOSTA_DEGISIKLIGI');
  assert.equal(m.target, 'yeni.adres@ornek.com');
  const u = await db.prepare('SELECT email, pending_email FROM users WHERE phone = ?').get(tel);
  assert.equal(u.email, `e${tel}@ornek.com`);
  // Bekleyen istek sunucuda kayıtlı (bağlantı tıklanınca yalnız bu adres işlenir).
  assert.equal(u.pending_email, 'yeni.adres@ornek.com');
});

test('kurallar: başka hesaptaki adres 409, aynı adres 409, Firebase adresi farklıysa 409, kimliği olmayan 409, oturumsuz 401', async () => {
  const tel = '5421120003';
  const tk = await hesap(tel, { uid: 'fb-ep-3' });
  fbKullanicilar.set('fb-ep-3', { email: 'baska@ornek.com' });
  assert.equal((await istek('/api/v1/profiles/me/email/change-request', { token: tk, govde: { newEmail: 'e5421120001@ornek.com', currentPassword: 'GucluSifre12' } })).durum, 409);
  assert.equal((await istek('/api/v1/profiles/me/email/change-request', { token: tk, govde: { newEmail: `e${tel}@ornek.com`, currentPassword: 'GucluSifre12' } })).durum, 409);
  assert.equal((await istek('/api/v1/profiles/me/email/verification', { token: tk })).durum, 409);
  const tk2 = await hesap('5421120004');
  assert.equal((await istek('/api/v1/profiles/me/email/verification', { token: tk2 })).durum, 409);
  assert.equal((await istek('/api/v1/profiles/me/email/verification', {})).durum, 401);
});

test('21 Eki: Firebase\'de doğrulanmış e-posta sunucuya eşitlenir; doğrulanmamışsa değişmez', async () => {
  const tel = '5421120006';
  const tk = await hesap(tel, { uid: 'fb-ep-6' });
  fbKullanicilar.set('fb-ep-6', { email: `e${tel}@ornek.com`, emailVerified: false });
  let r = await istek('/api/v1/profiles/me/email/sync', { token: tk });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal(r.json.emailVerified, false);
  fbKullanicilar.set('fb-ep-6', { email: `e${tel}@ornek.com`, emailVerified: true });
  r = await istek('/api/v1/profiles/me/email/sync', { token: tk });
  assert.equal(r.json.emailVerified, true);
  assert.equal(r.json.email, `e${tel}@ornek.com`);
  // Zaten onaylıysa düğme yeniden e-posta göndermez.
  assert.equal((await istek('/api/v1/profiles/me/email/verification', { token: tk })).durum, 409);
});

test('21 Eki: "doğrula ve değiştir" tamamlanınca yeni adres ve onay işlenir; başka hesaptaki adres işlenmez', async () => {
  const tel = '5421120007';
  const tk = await hesap(tel, { uid: 'fb-ep-7' });
  fbKullanicilar.set('fb-ep-7', { email: 'degisen.adres@ornek.com', emailVerified: true });
  await db.prepare('UPDATE users SET pending_email = ?, pending_email_at = ? WHERE phone = ?').run('degisen.adres@ornek.com', new Date().toISOString(), tel);
  const r = await istek('/api/v1/profiles/me/email/sync', { token: tk });
  assert.equal(r.json.email, 'degisen.adres@ornek.com');
  assert.equal(r.json.emailVerified, true);
  const tel2 = '5421120008';
  const tk2 = await hesap(tel2, { uid: 'fb-ep-8' });
  fbKullanicilar.set('fb-ep-8', { email: 'degisen.adres@ornek.com', emailVerified: true });
  await db.prepare('UPDATE users SET pending_email = ?, pending_email_at = ? WHERE phone = ?').run('degisen.adres@ornek.com', new Date().toISOString(), tel2);
  const r2 = await istek('/api/v1/profiles/me/email/sync', { token: tk2 });
  assert.equal(r2.json.email, `e${tel2}@ornek.com`);
  assert.equal(r2.json.emailVerified, false);
});

test('21 Eki: ONAYLI hesapta adres değişikliği tamamlanınca yeni adres profile işlenir', async () => {
  const tel = '5421120010';
  const tk = await hesap(tel, { uid: 'fb-ep-10' });
  await db.prepare('UPDATE users SET email_verified = TRUE WHERE phone = ?').run(tel);
  // Değişiklik bağlantısı henüz tıklanmadı: Firebase'de eski adres → değişiklik yok.
  fbKullanicilar.set('fb-ep-10', { email: `e${tel}@ornek.com`, emailVerified: true });
  let r = await istek('/api/v1/profiles/me/email/sync', { token: tk });
  assert.equal(r.json.email, `e${tel}@ornek.com`);
  assert.equal(r.json.emailVerified, true);
  // Bağlantı tıklandı: Firebase'de yeni adres doğrulanmış.
  fbKullanicilar.set('fb-ep-10', { email: 'onayli.yeni@ornek.com', emailVerified: true });
  await db.prepare('UPDATE users SET pending_email = ?, pending_email_at = ? WHERE phone = ?').run('onayli.yeni@ornek.com', new Date().toISOString(), tel);
  r = await istek('/api/v1/profiles/me/email/sync', { token: tk });
  assert.equal(r.json.email, 'onayli.yeni@ornek.com');
  assert.equal(r.json.emailVerified, true);
});

test('21 Eki: bağlantıya tıklanmışsa doğrulama düğmesi e-posta göndermez, ALREADY_VERIFIED döner', async () => {
  const tel = '5421120009';
  const tk = await hesap(tel, { uid: 'fb-ep-9' });
  fbKullanicilar.set('fb-ep-9', { email: `e${tel}@ornek.com`, emailVerified: true });
  const r = await istek('/api/v1/profiles/me/email/verification', { token: tk });
  assert.deepEqual(r.json, { sent: false, reason: 'ALREADY_VERIFIED' });
  assert.equal(await sonMesaj(tel), undefined);
  const u = await db.prepare('SELECT email_verified FROM users WHERE phone = ?').get(tel);
  assert.ok(u.email_verified);
});

test('21 Eki: e-postası Firebase\'de değişmiş hesap telefon + şifreyle giriş yapabilir; yeni adres işlenir', async () => {
  const { firebaseSifreTestDogrulayicisi } = await import('../src/firebase_token.js');
  const tel = '5421120011';
  await hesap(tel, { uid: 'fb-ep-11' });
  // Bağlantı tıklandı: Firebase'de adres yeni, sunucuda hâlâ eski.
  fbKullanicilar.set('fb-ep-11', { email: 'girisyeni@ornek.com', emailVerified: true });
  await db.prepare('UPDATE users SET pending_email = ?, pending_email_at = ? WHERE phone = ?').run('girisyeni@ornek.com', new Date().toISOString(), tel);
  firebaseSifreTestDogrulayicisi(async (email, sifre) => email === 'girisyeni@ornek.com' && sifre === 'GucluSifre12');
  try {
    await db.prepare('DELETE FROM rate_limits').run();
    const yanlis = await istek('/api/v1/auth/login', { govde: { phone: tel, password: 'YanlisSifre99' } });
    assert.equal(yanlis.durum, 401);
    const r = await istek('/api/v1/auth/login', { govde: { phone: tel, password: 'GucluSifre12' } });
    assert.equal(r.durum, 200, JSON.stringify(r.json));
    const u = await db.prepare('SELECT email, email_verified FROM users WHERE phone = ?').get(tel);
    assert.equal(u.email, 'girisyeni@ornek.com');
    assert.ok(u.email_verified);
  } finally {
    firebaseSifreTestDogrulayicisi(null);
  }
});

// ═════ 21 Eki — GÜVENLİK Y2: e-posta değişikliği yeniden kimlik doğrulama ister ═════
const degisimIste = (tk, govde) => istek('/api/v1/profiles/me/email/change-request', { token: tk, govde });
const mesajlar = (tel, sablon) => db.prepare(
  `SELECT * FROM outbound_messages WHERE user_id = (SELECT id FROM users WHERE phone = ?) AND template = ? ORDER BY created_at`,
).all(tel, sablon);

test('Y2: mevcut şifre yoksa ya da yanlışsa değişiklik başlamaz — Firebase\'e gidilmez, bekleyen istek ve e-posta yok', async () => {
  const tel = '5421120012';
  const tk = await hesap(tel, { uid: 'fb-ep-12' });
  fbKullanicilar.set('fb-ep-12', { email: `e${tel}@ornek.com` });
  cagrilar.length = 0;
  const yok = await degisimIste(tk, { newEmail: 'hedef12@ornek.com' });
  assert.equal(yok.durum, 400);
  assert.equal(yok.json.error.code, 'WRONG_PASSWORD');
  const yanlis = await degisimIste(tk, { newEmail: 'hedef12@ornek.com', currentPassword: 'YanlisSifre99' });
  assert.equal(yanlis.durum, 400);
  assert.equal(yanlis.json.error.code, 'WRONG_PASSWORD');
  assert.equal(cagrilar.length, 0, 'şifre doğrulanmadan Firebase çağrılmamalı');
  const u = await db.prepare('SELECT email, pending_email FROM users WHERE phone = ?').get(tel);
  assert.equal(u.email, `e${tel}@ornek.com`);
  assert.equal(u.pending_email, null);
  assert.equal((await mesajlar(tel, 'EPOSTA_DEGISIKLIGI')).length, 0);
  // Yanlış şifreler kritik işlem sınırına sayılır (kaba kuvvet): 10 denemeden sonra 429.
  for (let i = 0; i < 8; i++) await degisimIste(tk, { newEmail: 'hedef12@ornek.com', currentPassword: 'YanlisSifre99' });
  assert.equal((await degisimIste(tk, { newEmail: 'hedef12@ornek.com', currentPassword: 'GucluSifre12' })).durum, 429);
});

test('Y2: doğru şifreyle uçtan uca — bağlantı tıklanınca adres değişir, ESKİ adrese güvenlik bildirimi TEK kez gider (eşzamanlı ve tekrarlanan eşitleme)', async () => {
  const tel = '5421120013';
  const tk = await hesap(tel, { uid: 'fb-ep-13' });
  fbKullanicilar.set('fb-ep-13', { email: `e${tel}@ornek.com`, emailVerified: true });
  const r = await degisimIste(tk, { newEmail: 'yeni13@ornek.com', currentPassword: 'GucluSifre12' });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  // Bağlantı henüz tıklanmadı → değişiklik yok.
  assert.equal((await istek('/api/v1/profiles/me/email/sync', { token: tk })).json.email, `e${tel}@ornek.com`);
  // Tıklandı: Firebase'de yeni adres doğrulanmış. Üç eşzamanlı eşitleme.
  fbKullanicilar.set('fb-ep-13', { email: 'yeni13@ornek.com', emailVerified: true });
  const sonuc = await Promise.all([1, 2, 3].map(() => istek('/api/v1/profiles/me/email/sync', { token: tk })));
  for (const x of sonuc) assert.equal(x.durum, 200, JSON.stringify(x.json));
  // Tekrar oynatılan eşitleme yeni bir şey yapmaz.
  assert.equal((await istek('/api/v1/profiles/me/email/sync', { token: tk })).json.email, 'yeni13@ornek.com');
  const u = await db.prepare('SELECT email, email_verified, pending_email FROM users WHERE phone = ?').get(tel);
  assert.equal(u.email, 'yeni13@ornek.com');
  assert.ok(u.email_verified);
  assert.equal(u.pending_email, null);
  const bildirim = await mesajlar(tel, 'EPOSTA_DEGISTI');
  assert.equal(bildirim.length, 1, 'eski adrese bildirim tam bir kez');
  assert.equal(bildirim[0].target, `e${tel}@ornek.com`);
  assert.equal(bildirim[0].status, 'SENT');
  assert.ok(!bildirim[0].body.includes('yeni13@ornek.com'), 'yeni adres bildirimde açık yazılmaz');
  assert.ok(bildirim[0].body.includes('y***@ornek.com'));
});

test('Y2: bekleyen istek olmadan, süresi dolmuşken ya da yerine yenisi geçmişken Firebase\'deki adres işlenmez', async () => {
  const tel = '5421120014';
  const tk = await hesap(tel, { uid: 'fb-ep-14' });
  // Bekleyen istek yok: Firebase istemcisinden doğrudan değişiklik.
  fbKullanicilar.set('fb-ep-14', { email: 'dogrudan14@ornek.com', emailVerified: true });
  assert.equal((await istek('/api/v1/profiles/me/email/sync', { token: tk })).json.email, `e${tel}@ornek.com`);
  // Süresi dolmuş bekleyen istek (72 saatten eski).
  await db.prepare('UPDATE users SET pending_email = ?, pending_email_at = ? WHERE phone = ?')
    .run('dogrudan14@ornek.com', new Date(Date.now() - 73 * 3600 * 1000).toISOString(), tel);
  assert.equal((await istek('/api/v1/profiles/me/email/sync', { token: tk })).json.email, `e${tel}@ornek.com`);
  // İki eşzamanlı istek: yalnız SONUNCUSU geçerli; eskisinin bağlantısı işlenmez.
  fbKullanicilar.set('fb-ep-14', { email: `e${tel}@ornek.com`, emailVerified: true });
  const ikisi = await Promise.all([
    degisimIste(tk, { newEmail: 'birinci14@ornek.com', currentPassword: 'GucluSifre12' }),
    degisimIste(tk, { newEmail: 'ikinci14@ornek.com', currentPassword: 'GucluSifre12' }),
  ]);
  for (const x of ikisi) assert.equal(x.durum, 200, JSON.stringify(x.json));
  const bekleyen = (await db.prepare('SELECT pending_email FROM users WHERE phone = ?').get(tel)).pending_email;
  assert.ok(['birinci14@ornek.com', 'ikinci14@ornek.com'].includes(bekleyen));
  const diger = bekleyen === 'birinci14@ornek.com' ? 'ikinci14@ornek.com' : 'birinci14@ornek.com';
  fbKullanicilar.set('fb-ep-14', { email: diger, emailVerified: true });
  assert.equal((await istek('/api/v1/profiles/me/email/sync', { token: tk })).json.email, `e${tel}@ornek.com`, 'geçersizleşmiş istek işlenmemeli');
  fbKullanicilar.set('fb-ep-14', { email: bekleyen, emailVerified: true });
  assert.equal((await istek('/api/v1/profiles/me/email/sync', { token: tk })).json.email, bekleyen);
});

test('Y2: doğrulama e-postası gönderilemezse bekleyen istek silinir, hesap eski hâlinde kalır (502)', async () => {
  const { sirSifrele } = await import('../src/auth.js');
  const { onbellegiTemizle } = await import('../src/entegrasyon.js');
  const tel = '5421120015';
  const tk = await hesap(tel, { uid: 'fb-ep-15' });
  fbKullanicilar.set('fb-ep-15', { email: `e${tel}@ornek.com`, emailVerified: true });
  const z = new Date().toISOString();
  // PostgreSQL'de integrations.id UUID türündedir.
  const entegrasyonId = (await import('node:crypto')).randomUUID();
  await db.prepare(`INSERT INTO integrations (id, type, provider, active, config_json, secret_enc, created_at, updated_at)
    VALUES (?, 'EMAIL', 'webhook', TRUE, ?, ?, ?, ?)`)
    .run(entegrasyonId, JSON.stringify({ url: 'https://gecersiz-kopru.invalid/gonder' }), sirSifrele(JSON.stringify({ token: 'x' })), z, z);
  onbellegiTemizle();
  try {
    const r = await degisimIste(tk, { newEmail: 'yeni15@ornek.com', currentPassword: 'GucluSifre12' });
    assert.equal(r.durum, 502, JSON.stringify(r.json));
    const u = await db.prepare('SELECT email, pending_email FROM users WHERE phone = ?').get(tel);
    assert.equal(u.email, `e${tel}@ornek.com`);
    assert.equal(u.pending_email, null, 'gönderilemeyen istek bekletilmez');
    const m = await mesajlar(tel, 'EPOSTA_DEGISIKLIGI');
    assert.equal(m.at(-1).status, 'FAILED');
    assert.ok(!m.at(-1).body.includes('oobCode'), 'bağlantı kayda düz yazılmaz');
  } finally {
    await db.prepare('DELETE FROM integrations WHERE id = ?').run(entegrasyonId);
    onbellegiTemizle();
  }
});

test('Y1: Firebase oturum köprüsü kaldırıldı — erişim belgesiyle Firebase özel belgesi alınamaz', async () => {
  const tel = '5421120016';
  const tk = await hesap(tel, { uid: 'fb-ep-16' });
  const r = await istek('/api/v1/auth/firebase/baglanti', { token: tk });
  assert.equal(r.durum, 404);
  assert.ok(!JSON.stringify(r.json ?? {}).includes('firebaseCustomToken'));
});

test('Firebase yönetimi yoksa hiçbir değişiklik yapılmaz, { sent:false } döner (istemci Firebase gönderimine düşer)', async () => {
  const tel = '5421120005';
  const tk = await hesap(tel, { uid: 'fb-ep-5' });
  const { firebaseYonetimTestGondericisi: kanca } = await import('../src/firebase_token.js');
  kanca(null);
  try {
    const r = await istek('/api/v1/profiles/me/email/verification', { token: tk });
    assert.equal(r.durum, 200, JSON.stringify(r.json));
    assert.deepEqual(r.json, { sent: false, reason: 'CHANNEL_UNAVAILABLE' });
    assert.equal(await sonMesaj(tel), undefined);
  } finally {
    kanca(async (islem, govde) => ({ ok: false, durum: 400, kod: 'X', veri: { islem, govde } }));
  }
});
