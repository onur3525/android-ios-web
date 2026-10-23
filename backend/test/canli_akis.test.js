// UÇTAN UCA GERÇEK API AKIŞI (15 Eki denetimi) — Flutter'ın API modunda
// kullandığı uçlarla: kayıt (sunucu OTP doğrulaması), ilan oluşturma,
// hizmet verenin ilan listesi, teklif ve bildirim kaydı.
// ⚠ SQLite + yerel sunucu. Gerçek SMS/Firebase/push YOK: kayıt kodu test
// kancasından okunur (yalnız geliştirme; üretimde kanca reddedilir), push
// yapılandırılmadığı için bildirim yalnız uygulama içi kayıttır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';

const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { baslangicVerisiniHazirla } = await import('../src/baslangic_verisi.js');
const { pushGonderiminiIsle } = await import('../src/fcm.js');

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
async function kaydol(tel, rol, ad, email) {
  const o = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  assert.equal(o.durum, 204, JSON.stringify(o.json));
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'GucluSifre12', name: ad, email, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  return r.json.accessToken;
}

before(async () => {
  db = await testDb();
  // ⚠ `npm run seed` ÇAĞRILMADI: katalog açılıştaki otomatik aktarımla dolar.
  const s = await baslangicVerisiniHazirla(db);
  assert.ok(s.kategori > 0 && s.hizmet > 0 && s.ilce > 0, JSON.stringify(s));
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('başlangıç verisi: yalnız boş tablolara; ikinci çağrı hiçbir şey yazmaz; kapatılabilir', async () => {
  const ikinci = await baslangicVerisiniHazirla(db);
  assert.ok(Object.values(ikinci).every((n) => n === 0), JSON.stringify(ikinci));
  assert.equal(await baslangicVerisiniHazirla(db, { HC_OTOMATIK_TOHUM: 'false' }), null);
});

test('OTP: sabit test kodu (123456) ve sahte Firebase kanıtı sunucuda REDDEDİLİR', async () => {
  const tel = '5401110001';
  const govde = { termsAccepted: true, aydinlatmaAccepted: true, ageConfirmed: true, phone: tel, password: 'GucluSifre12', name: 'Deneme Kişi', email: 'deneme@ornek.com', role: 'CUSTOMER' };
  // Kod hiç istenmeden "123456".
  const a = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { ...govde, otpCode: '123456' } });
  assert.equal(a.durum, 400, JSON.stringify(a.json));
  assert.match(a.json.error.code, /^OTP_(EXPIRED|INVALID)$/, 'red OTP kaynaklı olmalı');
  // Kod istendikten sonra yanlış kod ("123456" gerçek koda eşit değilse).
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const gercek = globalThis.__sonOtp;
  const yanlis = gercek === '123456' ? '654321' : '123456';
  const b = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { ...govde, otpCode: yanlis } });
  assert.equal(b.durum, 400);
  assert.equal(b.json.error.code, 'OTP_INVALID');
  // İmzasız/sahte Firebase ID token.
  const c = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { ...govde, firebaseIdToken: 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ4In0.sahte' } });
  assert.equal(c.durum, 401, JSON.stringify(c.json));
  assert.equal(c.json.error.code, 'AUTH_FAILED');
  // Hiçbiri hesap açmadı.
  assert.equal(await db.prepare('SELECT id FROM users WHERE phone = ?').get(tel), undefined);
});

test('ilan → veritabanı → hizmet verenin listesi → teklif → bildirim kaydı', async () => {
  const hizmet = await db.prepare(
    `SELECT s.name hizmet, c.name kategori FROM services s JOIN categories c ON c.id = s.category_id
      WHERE s.active = TRUE AND c.active = TRUE ORDER BY c.sort, s.sort LIMIT 1`,
  ).get();
  const baska = await db.prepare(
    `SELECT s.name hizmet FROM services s JOIN categories c ON c.id = s.category_id
      WHERE s.active = TRUE AND c.active = TRUE AND c.name <> ? ORDER BY c.sort, s.sort LIMIT 1`,
  ).get(hizmet.kategori);
  const ilce = (await db.prepare('SELECT name FROM districts WHERE active = TRUE ORDER BY name LIMIT 1').get()).name;

  const musteri = await kaydol('5401110010', 'CUSTOMER', 'Ayşe Müşteri', 'ayse@ornek.com');
  // Hizmet veren rolü ilan VEREMEZ.
  const usta = await kaydol('5401110020', 'PROVIDER', 'Mehmet Usta', 'mehmet@ornek.com');
  const ustaIlan = await istek('/api/v1/listings', { yontem: 'POST', token: usta, govde: { title: hizmet.hizmet, location: `${ilce}, Merkez`, description: 'evde küçük bir onarım işi var' } });
  assert.equal(ustaIlan.durum, 403);

  // Katalog dışı başlık reddedilir.
  const uydurma = await istek('/api/v1/listings', { yontem: 'POST', token: musteri, govde: { title: 'Olmayan Hizmet', location: `${ilce}, Merkez`, description: 'bu ilan açılmamalı aslında' } });
  assert.equal(uydurma.durum, 400);

  const ilan = await istek('/api/v1/listings', { yontem: 'POST', token: musteri, govde: { title: hizmet.hizmet, location: `${ilce}, Merkez`, description: 'evde küçük bir onarım işi var', workTiming: 'THIS_WEEK' } });
  assert.equal(ilan.durum, 200, JSON.stringify(ilan.json));
  const satir = await db.prepare('SELECT status, title, owner_id FROM listings WHERE id = ?').get(ilan.json.id);
  assert.equal(satir.status, 'ACTIVE');
  assert.equal(satir.title, hizmet.hizmet);
  const ikinci = await istek('/api/v1/listings', { yontem: 'POST', token: musteri, govde: { title: baska.hizmet, location: `${ilce}, Merkez`, description: 'başka bir kategoride iş var' } });
  assert.equal(ikinci.durum, 200);

  // Hizmet veren profili: kategori + ilçe (katalogda olmalı).
  const prof = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: usta, govde: { categories: [hizmet.kategori], districts: [ilce] } });
  assert.equal(prof.durum, 200, JSON.stringify(prof.json));
  const gecersiz = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: usta, govde: { categories: ['Uydurma Kategori'], districts: [ilce] } });
  assert.equal(gecersiz.durum, 400, 'katalog dışı kategori sessizce kaydedilmez');

  // Hizmet alan bu listeyi göremez; hizmet veren kendi kategorisini ÖNCE görür.
  assert.equal((await istek('/api/v1/listings/available', { token: musteri })).durum, 403);
  const liste = await istek('/api/v1/listings/available', { token: usta });
  assert.equal(liste.durum, 200);
  const sira = liste.json.map((l) => l.id);
  assert.ok(sira.includes(ilan.json.id) && sira.includes(ikinci.json.id));
  assert.ok(sira.indexOf(ilan.json.id) < sira.indexOf(ikinci.json.id), 'kendi kategorisindeki ilan önce');

  // Teklif → ilan sahibine bildirim KAYDI.
  const teklif = await istek('/api/v1/offers', { yontem: 'POST', token: usta, govde: { listingId: ilan.json.id, amountTl: 750, note: 'yarın gelebilirim' } });
  assert.equal(teklif.durum, 200, JSON.stringify(teklif.json));
  const b = (await istek('/api/v1/notifications', { token: musteri })).json.find((n) => n.refId === ilan.json.id);
  assert.equal(b.type, 'NEW_OFFER');
  assert.equal(b.target, 'ilan');
  // FCM yapılandırılmadı: push GÖNDERİLMEZ, satır SKIPPED olarak kapanır.
  await pushGonderiminiIsle(db);
  const durum = await db.prepare('SELECT push_status FROM notifications WHERE ref_id = ? AND type = ?').get(ilan.json.id, 'NEW_OFFER');
  assert.equal(durum.push_status, 'SKIPPED');
});
