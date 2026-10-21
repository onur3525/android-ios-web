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
  const r = await istek('/api/v1/auth/register', { govde: { termsAccepted: true, phone: tel, password: 'GucluSifre12', name: 'Eposta Deneme', email: `e${tel}@ornek.com`, role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
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
  const r = await istek('/api/v1/profiles/me/email/change-request', { token: tk, govde: { newEmail: 'Yeni.Adres@Ornek.com' } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.deepEqual(r.json, { sent: true, email: 'yeni.adres@ornek.com' });
  assert.deepEqual(cagrilar.map((c) => c.islem), ['lookup', 'sendOobCode']);
  assert.deepEqual(cagrilar[1].govde, { requestType: 'VERIFY_AND_CHANGE_EMAIL', email: `e${tel}@ornek.com`, newEmail: 'yeni.adres@ornek.com', returnOobLink: true });
  const m = await sonMesaj(tel);
  assert.equal(m.template, 'EPOSTA_DEGISIKLIGI');
  assert.equal(m.target, 'yeni.adres@ornek.com');
  const u = await db.prepare('SELECT email FROM users WHERE phone = ?').get(tel);
  assert.equal(u.email, `e${tel}@ornek.com`);
});

test('kurallar: başka hesaptaki adres 409, aynı adres 409, Firebase adresi farklıysa 409, kimliği olmayan 409, oturumsuz 401', async () => {
  const tel = '5421120003';
  const tk = await hesap(tel, { uid: 'fb-ep-3' });
  fbKullanicilar.set('fb-ep-3', { email: 'baska@ornek.com' });
  assert.equal((await istek('/api/v1/profiles/me/email/change-request', { token: tk, govde: { newEmail: 'e5421120001@ornek.com' } })).durum, 409);
  assert.equal((await istek('/api/v1/profiles/me/email/change-request', { token: tk, govde: { newEmail: `e${tel}@ornek.com` } })).durum, 409);
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
  const r = await istek('/api/v1/profiles/me/email/sync', { token: tk });
  assert.equal(r.json.email, 'degisen.adres@ornek.com');
  assert.equal(r.json.emailVerified, true);
  const tel2 = '5421120008';
  const tk2 = await hesap(tel2, { uid: 'fb-ep-8' });
  fbKullanicilar.set('fb-ep-8', { email: 'degisen.adres@ornek.com', emailVerified: true });
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
