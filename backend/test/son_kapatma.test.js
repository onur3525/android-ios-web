// SON KAPATMA TURU — regresyon testleri
//   Bul (hizmet veren arama) → teklif talebi → değerlendirme (uçtan uca)
//   Yüklenen dosyanın sunucuda doğrulanması (sahte depo okuyucusu)
//   Profil fotoğrafı (rol bazlı) · Hesap dondurma GERÇEK durum
//   Silme talebi eşzamanlılığı · Idempotency (ilan, talep, mesajlar)
//   Push: çok işçi, çökme/yeniden başlatma, zaman aşımı, kalıcı/geçici hata
// ⚠ Gerçek S3/R2, FCM ve PostgreSQL YOK: depo okuyucusu ve push göndericisi
// sahte; PostgreSQL'e özgü eşzamanlılık burada DOĞRULANMADI (SQLite).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
process.env.HC_S3_ENDPOINT = 'https://r2.ornek-depo.com';
process.env.HC_S3_BUCKET = 'hizmetcep-medya';
process.env.HC_S3_REGION = 'auto';
process.env.HC_S3_ACCESS_KEY_ID = 'TESTANAHTAR123';
process.env.HC_S3_SECRET_ACCESS_KEY = 'testgizlianahtar-yalnizca-test';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { olaylar } = await import('../src/olaylar.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { depoOkuyucusuAta, sihirliBaytTuru, nesneSorunu } = await import('../src/depo_dogrulama.js');
const { pushGonderiminiIsle, fcmTestGondericisi } = await import('../src/fcm.js');
const { uygulamaIciBildir } = await import('../src/routes/ilan.js');

let db, sunucu, taban, KAT, HIZ;
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1]);
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 0x49, 0x48, 0x44, 0x52]);
const EXE = Buffer.from('MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00', 'latin1');
const depo = new Map(); // sahte depo: ref → { boyut, icerikTuru, bas }
const sahteOkuyucu = async (_ayar, ref) => (depo.has(ref) ? { var: true, ...depo.get(ref) } : { var: false });
depoOkuyucusuAta(sahteOkuyucu);

async function istek(yol, { yontem = 'GET', govde, token, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}

async function kisi(tel, rol, { kategoriler, ilceler, adres } = {}) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: `Usta ${tel.slice(-3)}`, email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  const k = { token: r.json.accessToken, refresh: r.json.refreshToken, id: me.json.id, tel };
  if (kategoriler) {
    const p = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: k.token, govde: { categories: kategoriler, districts: ilceler ?? ['Konak'] } });
    assert.equal(p.durum, 200, JSON.stringify(p.json));
  }
  if (adres) await db.prepare('INSERT INTO addresses (user_id, city, district, neighborhood, updated_at) VALUES (?, ?, ?, ?, ?)').run(k.id, adres[0], adres[1], adres[2], simdi());
  return k;
}

async function yukle(k, { tur = 'listing-photo', icerik = 'image/jpeg', beyan = 200000, gercek = { boyut: 150000, icerikTuru: 'image/jpeg', bas: JPEG } } = {}) {
  const r = await istek('/api/v1/storage/upload-ref', { yontem: 'POST', token: k.token, govde: { kind: tur, contentType: icerik, sizeBytes: beyan } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  if (gercek) depo.set(r.json.storageRef, gercek);
  return r.json.storageRef;
}

before(async () => {
  db = await testDb();
  await olaylar.kur(db);
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const s = await db.prepare('SELECT s.name hizmet, c.name kategori FROM services s JOIN categories c ON c.id = s.category_id ORDER BY s.name LIMIT 1').get();
  KAT = s.kategori; HIZ = s.hizmet;
});
after(async () => {
  depoOkuyucusuAta(null);
  fcmTestGondericisi(null);
  sunucu.closeAllConnections?.();
  sunucu.close();
  // Önce LISTEN bağlantısı (olcekleme.test.js ile aynı sıra), sonra havuz.
  await olaylar.kapat();
  await db?.close();
});

// ═════ BUL ═════
test('Bul: yalnız o hizmeti seçmiş etkin hizmet verenler; gizli bilgi dönmez; müşterinin ilçesi önde', async () => {
  const alan = await kisi('5380000001', 'CUSTOMER');
  const u1 = await kisi('5380000002', 'PROVIDER', { kategoriler: [HIZ], ilceler: ['Bornova'], adres: ['İzmir', 'Bornova', 'Kazımdirik'] });
  const u2 = await kisi('5380000003', 'PROVIDER', { kategoriler: [KAT], ilceler: ['Konak'], adres: ['İzmir', 'Konak', 'Alsancak'] });
  const baskaKat = (await db.prepare('SELECT name FROM categories WHERE name <> ? LIMIT 1').get(KAT)).name;
  const ilgisiz = await kisi('5380000004', 'PROVIDER', { kategoriler: [baskaKat] });
  const askida = await kisi('5380000005', 'PROVIDER', { kategoriler: [HIZ] });
  await db.prepare(`UPDATE users SET status = 'SUSPENDED' WHERE id = ?`).run(askida.id);
  const r = await istek(`/api/v1/providers/search?category=${encodeURIComponent(KAT)}&service=${encodeURIComponent(HIZ)}&district=Konak`, { token: alan.token });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.deepEqual(r.json.map((x) => x.id), [u2.id, u1.id], "Konak'a hizmet veren önde; ilgisiz ve askıdaki yok");
  assert.ok(!r.json.some((x) => [ilgisiz.id, askida.id].includes(x.id)));
  const ham = JSON.stringify(r.json);
  for (const gizli of ['5380000002', '5380000003', '@ornek.com', 'Kazımdirik', 'Alsancak', 'password', '"phone"', '"email"']) assert.ok(!ham.includes(gizli), `sızıntı: ${gizli}`);
  assert.deepEqual(r.json[1].address, { city: 'İzmir', district: 'Bornova' });
  assert.deepEqual(r.json[1].serviceDistricts, ['Bornova']);
  assert.ok(!(await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`, { token: u1.token })).json.some((x) => x.id === u1.id), 'kendini görmez');
  assert.equal((await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`)).durum, 401);
  assert.equal((await istek('/api/v1/providers/search', { token: alan.token })).durum, 400);
  for (const joker of ['%', '_', '%"%']) assert.deepEqual((await istek(`/api/v1/providers/search?service=${encodeURIComponent(joker)}`, { token: alan.token })).json, [], `joker ${joker}`);
});

test('Bul → teklif talebi → teklif → seçim → tamamla → değerlendirme (uçtan uca, gerçek API)', async () => {
  const alan = await kisi('5380000011', 'CUSTOMER');
  const usta = await kisi('5380000012', 'PROVIDER', { kategoriler: [HIZ] });
  assert.ok((await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`, { token: alan.token })).json.some((x) => x.id === usta.id));
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: KAT, hizmet: HIZ, aciklama: 'mutfak musluğu damlatıyor acil', iletisimTercihi: 'yalnizMesaj' } });
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  assert.equal(t.json.degerlendirme, null);
  assert.ok(await db.prepare('SELECT 1 FROM notifications WHERE user_id = ? AND ref_id = ?').get(usta.id, t.json.id), 'hizmet verene bildirim');
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/review`, { yontem: 'POST', token: alan.token, govde: { stars: 5, text: 'x' } })).durum, 409, 'tamamlanmadan değerlendirilemez');
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 750 } })).durum, 200);
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/sec`, { yontem: 'POST', token: alan.token })).durum, 200);
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/tamamla`, { yontem: 'POST', token: alan.token })).durum, 200);
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/review`, { yontem: 'POST', token: usta.token, govde: { stars: 5, text: 'x' } })).durum, 403, 'yalnız talep sahibi');
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/review`, { yontem: 'POST', token: alan.token, govde: { stars: 6, text: 'x' } })).durum, 400);
  assert.equal((await istek(`/api/v1/teklif-talepleri/${t.json.id}/review`, { yontem: 'POST', token: alan.token, govde: { stars: 4, text: 'a'.repeat(1001) } })).durum, 400);
  const y = await Promise.all([1, 2, 3].map(() => istek(`/api/v1/teklif-talepleri/${t.json.id}/review`, { yontem: 'POST', token: alan.token, govde: { stars: 5, text: 'Çok iyi iş' } })));
  assert.equal(y.filter((r) => r.durum === 200).length, 1);
  for (const r of y) assert.ok(r.durum < 500);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM reviews WHERE talep_id = ?').get(t.json.id)).n, 1);
  assert.equal((await istek('/api/v1/teklif-talepleri', { token: alan.token })).json.find((x) => x.id === t.json.id).degerlendirme.stars, 5);
  const sonra = (await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`, { token: alan.token })).json.find((x) => x.id === usta.id);
  assert.equal(sonra.rating, 5); assert.equal(sonra.reviewCount, 1); assert.equal(sonra.completedJobs, 1);
});

// ═════ YÜKLEME DOĞRULAMASI ═════
test('sihirli bayt ve nesne denetimi (saf; her denetim ayrı)', () => {
  assert.equal(sihirliBaytTuru(JPEG), 'image/jpeg');
  assert.equal(sihirliBaytTuru(PNG), 'image/png');
  assert.equal(sihirliBaytTuru(Buffer.from('RIFF\0\0\0\0WEBPVP8 ', 'latin1')), 'image/webp');
  assert.equal(sihirliBaytTuru(Buffer.from('\0\0\0\x18ftypheic\0\0\0\0', 'latin1')), 'image/heic');
  assert.equal(sihirliBaytTuru(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg">', 'latin1')), null, 'SVG kabul edilmez');
  assert.equal(sihirliBaytTuru(EXE), null);
  const sahip = randomUUID();
  const o = { ref: `u/${sahip}/${randomUUID()}.jpg`, owner_id: sahip, kind: 'listing-photo', content_type: 'image/jpeg', size_bytes: 1000 };
  const iyi = { var: true, boyut: 900, icerikTuru: 'image/jpeg', bas: JPEG };
  assert.equal(nesneSorunu(o, iyi), null);
  assert.match(nesneSorunu(o, { ...iyi, boyut: 5000 }), /büyük/);
  assert.match(nesneSorunu(o, { ...iyi, icerikTuru: 'application/octet-stream' }), /tür/);
  assert.match(nesneSorunu(o, { ...iyi, bas: EXE }), /içeriği/);
  assert.match(nesneSorunu({ ...o, owner_id: randomUUID() }, iyi), /sahip/);
  assert.match(nesneSorunu({ ...o, ref: `u/${sahip}/../x.jpg` }, iyi), /anahtar/);
  assert.match(nesneSorunu({ ...o, ref: o.ref.replace('.jpg', '.png') }, iyi), /uzantı/);
  assert.match(nesneSorunu({ ...o, kind: 'svg' }, iyi), /tür/);
  assert.match(nesneSorunu(o, { var: false }), /yüklenmemiş/);
});

test('yükleme: büyük dosya, sahte tür, yüklenmemiş dosya bağlanamaz; geçersiz nesne silme kuyruğuna girer', async () => {
  const k = await kisi('5380000021', 'CUSTOMER');
  const ilan = (refs) => istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde: { title: HIZ, location: 'Konak', description: 'salon boyanacak acil iş', photoRefs: refs } });
  const buyuk = await yukle(k, { beyan: 100000, gercek: { boyut: 9_000_000, icerikTuru: 'image/jpeg', bas: JPEG } });
  const sahte = await yukle(k, { gercek: { boyut: 1000, icerikTuru: 'image/jpeg', bas: EXE } });
  const yok = await yukle(k, { gercek: null });
  for (const ref of [buyuk, sahte]) {
    assert.equal((await ilan([ref])).durum, 400, ref);
    const o = await db.prepare('SELECT status, delete_requested_at FROM storage_objects WHERE ref = ?').get(ref);
    assert.equal(o.status, 'DISCARDED'); assert.ok(o.delete_requested_at, 'öksüz kalmaz');
  }
  assert.equal((await ilan([yok])).durum, 400);
  assert.equal((await db.prepare('SELECT status FROM storage_objects WHERE ref = ?').get(yok)).status, 'PENDING', 'kullanıcı yeniden yükleyebilir');
  depoOkuyucusuAta(async () => { throw new Error('ağ yok'); });
  try { assert.equal((await ilan([yok])).durum, 503); } finally { depoOkuyucusuAta(sahteOkuyucu); }
  const iyi = await yukle(k);
  assert.equal((await ilan([iyi])).durum, 200);
  const o = await db.prepare('SELECT status, verified_at FROM storage_objects WHERE ref = ?').get(iyi);
  assert.equal(o.status, 'ATTACHED'); assert.ok(o.verified_at);
  assert.equal((await ilan([await yukle(k, { tur: 'profile-photo' })])).durum, 400, 'profil türü ilana bağlanamaz');
  const { dosyalariBagla } = await import('../src/routes/depolama_entegrasyon.js');
  const ham = await yukle(k);
  await assert.rejects(db.tx(() => dosyalariBagla(db, [ham], k.id)), /doğrulanmadı/, 'doğrulama atlanamaz');
  assert.equal((await istek('/api/v1/storage/upload-ref', { yontem: 'POST', token: k.token, govde: { kind: 'listing-photo', contentType: 'image/svg+xml', sizeBytes: 100 } })).durum, 400, 'SVG yüklenemez');
});

// ═════ PROFİL FOTOĞRAFI ═════
test('profil fotoğrafı: rol bazlı kaydedilir, okunur, değişince eskisi silinir, kaldırılır; başkası görebilir', async () => {
  const k = await kisi('5380000031', 'PROVIDER', { kategoriler: [HIZ] });
  const baska = await kisi('5380000032', 'CUSTOMER');
  const f1 = await yukle(k, { tur: 'profile-photo', icerik: 'image/png', gercek: { boyut: 5000, icerikTuru: 'image/png', bas: PNG } });
  const r1 = await istek('/api/v1/profiles/me', { yontem: 'PATCH', token: k.token, govde: { photoRef: f1, photoRole: 'PROVIDER' } });
  assert.equal(r1.durum, 200, JSON.stringify(r1.json));
  assert.match(r1.json.photos.provider, /^https:\/\/hizmetcep-medya\.r2\.ornek-depo\.com\/u\//);
  assert.equal(r1.json.photos.customer, null, 'öteki role sızmaz');
  assert.match((await istek('/api/v1/users/me', { token: k.token })).json.photos.provider, /X-Amz-Signature/);
  assert.ok((await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`, { token: baska.token })).json.find((x) => x.id === k.id).photoUrl);
  assert.equal((await istek(`/api/v1/storage/resolve?ref=${encodeURIComponent(f1)}`, { token: baska.token })).durum, 200);
  assert.equal((await istek('/api/v1/profiles/me', { yontem: 'PATCH', token: k.token, govde: { photoRef: f1, photoRole: 'CUSTOMER' } })).durum, 400, 'sahip olmadığı rol');
  const yabanci = await yukle(baska, { tur: 'profile-photo' });
  assert.equal((await istek('/api/v1/profiles/me', { yontem: 'PATCH', token: k.token, govde: { photoRef: yabanci, photoRole: 'PROVIDER' } })).durum, 400, 'başkasının dosyası');
  const f2 = await yukle(k, { tur: 'profile-photo' });
  assert.equal((await istek('/api/v1/profiles/me', { yontem: 'PATCH', token: k.token, govde: { photoRef: f2, photoRole: 'PROVIDER' } })).durum, 200);
  assert.ok((await db.prepare('SELECT delete_requested_at FROM storage_objects WHERE ref = ?').get(f1)).delete_requested_at, 'eski fotoğraf silme kuyruğunda');
  assert.equal((await istek(`/api/v1/storage/resolve?ref=${encodeURIComponent(f1)}`, { token: baska.token })).durum, 404);
  const r3 = await istek('/api/v1/profiles/me', { yontem: 'PATCH', token: k.token, govde: { photoRef: null, photoRole: 'PROVIDER' } });
  assert.equal(r3.json.photos.provider, null);
  assert.ok((await db.prepare('SELECT delete_requested_at FROM storage_objects WHERE ref = ?').get(f2)).delete_requested_at);
});

// ═════ DONDURMA ═════
test('dondurma GERÇEK durum: oturum/yenileme geçersiz, aramada yok, push yok; yeniden giriş etkinleştirir, veri silinmez', async () => {
  const k = await kisi('5380000041', 'PROVIDER', { kategoriler: [HIZ] });
  const alan = await kisi('5380000042', 'CUSTOMER');
  await db.prepare(`INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen) VALUES (?, ?, 'android', ?, ?)`).run('dondur-jeton-xxxxxxxxxxxxxxxxxxx', k.id, simdi(), simdi());
  assert.equal((await istek('/api/v1/profiles/me/freeze', { yontem: 'POST', token: k.token, govde: {} })).durum, 200);
  const u = await db.prepare('SELECT frozen_at, deleted_at, name FROM users WHERE id = ?').get(k.id);
  assert.ok(u.frozen_at); assert.equal(u.deleted_at, null); assert.equal(u.name, 'Usta 041');
  assert.equal((await istek('/api/v1/users/me', { token: k.token })).durum, 401);
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } })).durum, 401);
  assert.ok(!(await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`, { token: alan.token })).json.some((x) => x.id === k.id));
  const giden = [];
  fcmTestGondericisi({ gonder: async (t) => { giden.push(t); return 'ok'; } });
  await uygulamaIciBildir(db, k.id, 'NEW_MESSAGE', 'x', 'y', randomUUID(), 'mesaj');
  await new Promise((ok) => setTimeout(ok, 30));
  await pushGonderiminiIsle(db);
  assert.ok(!giden.includes('dondur-jeton-xxxxxxxxxxxxxxxxxxx'), 'dondurulmuşa push yok');
  fcmTestGondericisi(null);
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: k.tel, password: 'sifre1234' } });
  assert.equal(g.durum, 200);
  assert.equal((await db.prepare('SELECT frozen_at FROM users WHERE id = ?').get(k.id)).frozen_at, null);
  assert.equal((await istek('/api/v1/users/me', { token: g.json.accessToken })).durum, 200);
  assert.ok((await istek(`/api/v1/providers/search?service=${encodeURIComponent(HIZ)}`, { token: alan.token })).json.some((x) => x.id === k.id));
});

// ═════ SİLME TALEBİ EŞZAMANLILIĞI ═════
test('eşzamanlı 5 silme talebi: tek bekleyen kayıt (veritabanı tekil dizini)', async () => {
  const k = await kisi('5380000051', 'CUSTOMER');
  const r = await Promise.all(Array.from({ length: 5 }, () => istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: k.token, govde: { password: 'sifre1234' } })));
  assert.equal(r.filter((x) => x.durum === 200).length, 1);
  for (const x of r.filter((y) => y.durum !== 200)) assert.equal(x.json.error.code, 'CONFLICT');
  assert.equal((await db.prepare(`SELECT COUNT(*) n FROM account_requests WHERE user_id = ? AND type = 'DELETION' AND status = 'PENDING'`).get(k.id)).n, 1);
  await assert.rejects(db.prepare(`INSERT INTO account_requests (id, user_id, type, status, created_at) VALUES (?, ?, 'DELETION', 'PENDING', ?)`).run(randomUUID(), k.id, simdi()), 'DB düzeyinde de engelli');
  await istek('/api/v1/profiles/me/deletion-request', { yontem: 'DELETE', token: k.token });
  assert.equal((await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: k.token, govde: { password: 'sifre1234' } })).durum, 200, 'iptal sonrası yeni talep');
});

// ═════ IDEMPOTENCY ═════
test('idempotency: aynı anahtarla 2/5/10 eşzamanlı ilan → tek kayıt; farklı gövde → 409; farklı anahtar → yeni kayıt', async () => {
  const k = await kisi('5380000061', 'CUSTOMER');
  const govde = { title: HIZ, location: 'Konak', description: 'bahçe kapısı tamiri gerekli' };
  for (const adet of [2, 5, 10]) {
    const anahtar = `ilan-${adet}-${randomUUID()}`;
    const r = await Promise.all(Array.from({ length: adet }, () => istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde, basliklar: { 'Idempotency-Key': anahtar } })));
    for (const x of r) assert.equal(x.durum, 200, JSON.stringify(x.json));
    assert.equal(new Set(r.map((x) => x.json.id)).size, 1, `${adet} istek → tek ilan`);
    assert.equal((await db.prepare('SELECT COUNT(*) n FROM listings WHERE owner_id = ? AND idempotency_key = ?').get(k.id, anahtar)).n, 1);
  }
  const a = `ilan-x-${randomUUID()}`;
  await istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde, basliklar: { 'Idempotency-Key': a } });
  const farkli = await istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde: { ...govde, description: 'başka bir iş açıklaması burada' }, basliklar: { 'Idempotency-Key': a } });
  assert.equal(farkli.durum, 409); assert.equal(farkli.json.error.code, 'IDEMPOTENCY_KEY_REUSED');
  const once = (await db.prepare('SELECT COUNT(*) n FROM listings WHERE owner_id = ?').get(k.id)).n;
  await istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde, basliklar: { 'Idempotency-Key': `yeni-${randomUUID()}` } });
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM listings WHERE owner_id = ?').get(k.id)).n, once + 1);
});

test('idempotency: teklif talebi ve iki sohbet türünde tekrar → tek kayıt, tek bildirim', async () => {
  const alan = await kisi('5380000071', 'CUSTOMER');
  const usta = await kisi('5380000072', 'PROVIDER', { kategoriler: [HIZ] });
  const anahtar = `talep-${randomUUID()}`;
  const govde = { saglayiciId: usta.id, kategori: KAT, hizmet: HIZ, aciklama: 'kombi bakımı yapılacak acil', iletisimTercihi: 'yalnizMesaj' };
  const t = await Promise.all(Array.from({ length: 5 }, () => istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde, basliklar: { 'Idempotency-Key': anahtar } })));
  for (const x of t) assert.equal(x.durum, 200, JSON.stringify(x.json));
  assert.equal(new Set(t.map((x) => x.json.id)).size, 1);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND ref_id = ?').get(usta.id, t[0].json.id)).n, 1);
  const id = t[0].json.id;
  await istek(`/api/v1/teklif-talepleri/${id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 500 } });
  const mk = `tmesaj-${randomUUID()}`;
  await Promise.all(Array.from({ length: 5 }, () => istek(`/api/v1/teklif-talepleri/${id}/mesajlar`, { yontem: 'POST', token: alan.token, govde: { metin: 'Yarın gelebilir misiniz?' }, basliklar: { 'Idempotency-Key': mk } })));
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM teklif_mesajlari WHERE talep_id = ? AND gonderen_id = ?').get(id, alan.id)).n, 1);
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: HIZ, location: 'Konak', description: 'cam balkon temizliği gerekli' } });
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: usta.token, govde: { listingId: l.json.id, amountTl: 300, note: '' } });
  await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: alan.token });
  const ik = `mesaj-${randomUUID()}`;
  const m = await Promise.all(Array.from({ length: 5 }, () => istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: o.json.id, text: 'Merhaba' }, basliklar: { 'Idempotency-Key': ik } })));
  assert.equal(new Set(m.map((x) => x.json.id)).size, 1);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM messages WHERE offer_id = ?').get(o.json.id)).n, 1);
  assert.equal((await istek('/api/v1/messages', { yontem: 'POST', token: alan.token, govde: { offerId: o.json.id, text: 'Başka metin' }, basliklar: { 'Idempotency-Key': ik } })).durum, 409);
});

// ═════ PUSH: ÇÖKME / YENİDEN BAŞLATMA / ZAMAN AŞIMI ═════
test('push: işçi çökmesi (SENDING takılı) → 5 dk sonra başka işçi devralır; zaman aşımı geçici sayılır, jeton korunur', async () => {
  const k = await kisi('5380000081', 'CUSTOMER');
  await db.prepare(`INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen) VALUES (?, ?, 'android', ?, ?)`).run('cokme-jeton-xxxxxxxxxxxxxxxxxxxx', k.id, simdi(), simdi());
  fcmTestGondericisi({ gonder: async () => 'ok' });
  await uygulamaIciBildir(db, k.id, 'NEW_MESSAGE', 'x', 'y', randomUUID(), 'mesaj');
  await new Promise((ok) => setTimeout(ok, 30));
  await pushGonderiminiIsle(db);
  // İşçi sahiplenip ÇÖKTÜ: satır SENDING'de kaldı.
  const n = await db.prepare('SELECT id FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(k.id);
  await db.prepare(`UPDATE notifications SET push_status = 'SENDING', push_claimed_at = ? WHERE id = ?`).run(new Date().toISOString(), n.id);
  const giden = [];
  fcmTestGondericisi({ gonder: async (t) => { giden.push(t); return 'ok'; } });
  await pushGonderiminiIsle(db);
  assert.equal(giden.length, 0, 'sahiplik süresi dolmadan devralınmaz (çift gönderim yok)');
  await db.prepare('UPDATE notifications SET push_claimed_at = ? WHERE id = ?').run('2000-01-01T00:00:00.000Z', n.id);
  await pushGonderiminiIsle(db); // "yeniden başlatılmış" işçi
  assert.deepEqual(giden, ['cokme-jeton-xxxxxxxxxxxxxxxxxxxx']);
  assert.equal((await db.prepare('SELECT push_status FROM notifications WHERE id = ?').get(n.id)).push_status, 'SENT');
  // Zaman aşımı → geçici: jeton silinmez, yeniden denenir.
  fcmTestGondericisi({ gonder: async () => 'gecici' });
  await uygulamaIciBildir(db, k.id, 'NEW_MESSAGE', 'x', 'y', randomUUID(), 'mesaj');
  await new Promise((ok) => setTimeout(ok, 30));
  await pushGonderiminiIsle(db);
  assert.ok(await db.prepare('SELECT 1 FROM push_tokens WHERE token = ?').get('cokme-jeton-xxxxxxxxxxxxxxxxxxxx'), 'geçici hatada jeton korunur');
  // Kalıcı geçersiz → jeton silinir.
  fcmTestGondericisi({ gonder: async () => 'gecersiz' });
  await db.prepare('UPDATE notifications SET push_claimed_at = ? WHERE user_id = ? AND push_status IS NULL').run('2000-01-01T00:00:00.000Z', k.id);
  await pushGonderiminiIsle(db);
  assert.equal(await db.prepare('SELECT 1 FROM push_tokens WHERE token = ?').get('cokme-jeton-xxxxxxxxxxxxxxxxxxxx'), undefined);
  fcmTestGondericisi(null);
});

// ═════ SAYFALAMA / N+1 ═════
test('ilan akışı: 500\'ü aşan açık ilanda hizmet verenin KENDİ hizmetindeki eski ilan da gelir', async () => {
  const sahip = await kisi('5380000091', 'CUSTOMER');
  const usta = await kisi('5380000092', 'PROVIDER', { kategoriler: [HIZ] });
  const baskaHizmet = (await db.prepare('SELECT s.name FROM services s JOIN categories c ON c.id = s.category_id WHERE c.name <> ? LIMIT 1').get(KAT)).name;
  const z = Date.now();
  const ekle = (baslik, dk) => db.prepare(
    `INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, status, expiry_notified, created_at, expires_at, updated_at)
     VALUES (?, ?, ?, ?, 'Konak', 'deneme ilan açıklaması', '[]', 'ACTIVE', FALSE, ?, ?, ?)`,
  ).run(randomUUID(), String(9_000_000 + dk), sahip.id, baslik, new Date(z - dk * 60_000).toISOString(), new Date(z + 86_400_000).toISOString(), new Date(z).toISOString());
  await ekle(HIZ, 900); // EN ESKİ — ustanın kendi hizmeti
  for (let i = 0; i < 520; i++) await ekle(baskaHizmet, i); // daha yeni 520 ilgisiz ilan
  const r = await istek('/api/v1/listings/available', { token: usta.token });
  assert.equal(r.durum, 200);
  assert.ok(r.json.some((l) => l.title === HIZ), 'kendi hizmetindeki ilan kesmeye takılmamalı');
  assert.ok(r.json.length <= 2000 + 500);
  assert.equal(new Set(r.json.map((l) => l.id)).size, r.json.length, 'tekrar yok');
});

test('sohbet listesi (toplu okuma): karşı taraf, son mesaj ve okunmamış sayısı doğru', async () => {
  const alan = await kisi('5380000101', 'CUSTOMER');
  const u1 = await kisi('5380000102', 'PROVIDER', { kategoriler: [HIZ] });
  const u2 = await kisi('5380000103', 'PROVIDER', { kategoriler: [HIZ] });
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: HIZ, location: 'Konak', description: 'dolap kapağı ayarı gerekli' } });
  const sohbet = async (u, metinler) => {
    const o = await istek('/api/v1/offers', { yontem: 'POST', token: u.token, govde: { listingId: l.json.id, amountTl: 400, note: '' } });
    await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: alan.token });
    for (const m of metinler) {
      await istek('/api/v1/messages', { yontem: 'POST', token: u.token, govde: { offerId: o.json.id, text: m } });
      await new Promise((ok) => setTimeout(ok, 5));
    }
    return o.json.id;
  };
  const o1 = await sohbet(u1, ['bir', 'iki', 'üç']);
  const o2 = await sohbet(u2, ['tek']);
  const liste = (await istek('/api/v1/messages/conversations', { token: alan.token })).json;
  const s1 = liste.find((x) => x.offer.id === o1); const s2 = liste.find((x) => x.offer.id === o2);
  assert.equal(s1.counterpart.id, u1.id); assert.equal(s1.counterpart.name, 'Usta 102');
  assert.equal(s1.lastMessage.text, 'üç'); assert.equal(s1.unread, 3);
  assert.equal(s2.lastMessage.text, 'tek'); assert.equal(s2.unread, 1);
  assert.equal((await istek('/api/v1/messages/conversations', { token: u1.token })).json.find((x) => x.offer.id === o1).unread, 0);
});

// ═════ TEKRARLANABİLİR DERLEME ═════
test('Dockerfile: kilit dosyası yoksa üretim derlemesi SESSİZCE npm install\'a düşmez', async () => {
  const { readFileSync } = await import('node:fs');
  const d = readFileSync(new URL('../Dockerfile', import.meta.url), 'utf8');
  assert.match(d, /if \[ -f package-lock\.json \]; then npm ci --omit=dev;/);
  assert.match(d, /elif \[ "\$KILITSIZ" = "1" \]; then npm install --omit=dev;/);
  assert.match(d, /else echo .*exit 1; fi/);
  assert.match(d, /ARG KILITSIZ=0/);
});

test('push: HC_PUSH_PARALEL=3 yuva, 3 eşzamanlı çalıştırıcı, 1200 bildirim → hepsi TEK kez; tur sınırı (500) aşılır', async () => {
  const { config } = await import('../src/config.js');
  const { pushKuyrugunuIsle } = await import('../src/fcm.js');
  const onceki = config.pushParalel;
  config.pushParalel = 3;
  const sayac = new Map();
  fcmTestGondericisi({ gonder: async (_t, m) => { sayac.set(m.data.bildirimId, (sayac.get(m.data.bildirimId) ?? 0) + 1); return 'ok'; } });
  try {
    const k = await kisi('5380000111', 'CUSTOMER');
    await db.prepare(`INSERT INTO push_tokens (token, user_id, platform, created_at, last_seen) VALUES (?, ?, 'android', ?, ?)`).run('yuva-jeton-xxxxxxxxxxxxxxxxxxxxx', k.id, simdi(), simdi());
    // Bu dosyanın önceki testlerinin kuyrukta bıraktığı bildirimler (ör. yeni
    // ilan bildirimleri) sayımı karıştırmasın: yalnız bu testin 1200 satırı.
    await db.prepare(`UPDATE notifications SET push_status = 'SKIPPED' WHERE push_status IS NULL`).run();
    const z = simdi();
    for (let i = 0; i < 1200; i++) {
      await db.prepare(`INSERT INTO notifications (id, user_id, type, title, body, ref_id, created_at) VALUES (?, ?, 'NEW_MESSAGE', 'x', 'y', ?, ?)`).run(randomUUID(), k.id, randomUUID(), z);
    }
    const sonuc = await Promise.all([pushKuyrugunuIsle(db), pushKuyrugunuIsle(db), pushKuyrugunuIsle(db)]);
    const gonderilen = await db.prepare(`SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND push_status = 'SENT'`).get(k.id);
    assert.equal(gonderilen.n, 1200, 'bir çağrıda kuyruk tükendi (tur sınırında durmadı)');
    assert.equal([...sayac.values()].filter((x) => x > 1).length, 0, 'çift gönderim yok');
    assert.equal(sonuc.reduce((a, b) => a + (b ?? 0), 0), 1200);
  } finally {
    config.pushParalel = onceki;
    fcmTestGondericisi(null);
  }
});

test('hesap silme: destek talebi konu/mesajı anonimleşir, açık talep kapanır', async () => {
  const { silmeTalepleriniIsle } = await import('../src/routes/sohbet_talep.js');
  const k = await kisi('5380000121', 'CUSTOMER');
  const t = await istek('/api/v1/support/tickets', { yontem: 'POST', token: k.token, govde: { subject: 'Adresim Bornova 12. sokak', message: 'Telefonum 05321234567, beni arayın lütfen.' } });
  assert.equal(t.durum, 200);
  await istek('/api/v1/profiles/me/deletion-request', { yontem: 'POST', token: k.token, govde: { password: 'sifre1234' } });
  await db.prepare('UPDATE account_requests SET scheduled_for = ? WHERE user_id = ?').run('2000-01-01T00:00:00.000Z', k.id);
  await silmeTalepleriniIsle(db);
  const r = await db.prepare('SELECT subject, message, status, ticket_no FROM support_tickets WHERE id = ?').get(t.json.id);
  assert.equal(r.status, 'CLOSED');
  assert.ok(!r.subject.includes('Bornova') && !r.message.includes('0532'));
  assert.equal(r.ticket_no, t.json.ticketNo, 'kayıt numarası kalır');
});

test('admin kullanıcı detayı dondurulmuş hesabı gösterir', async () => {
  const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
  const sir = base32Uret();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, 'dondur@hc.test', 'A', 'moderator', ?, ?, ?)`)
    .run(randomUUID(), sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const g = await fetch(`${taban}/admin/v1/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1' }, body: JSON.stringify({ email: 'dondur@hc.test', password: 'GucluSifre12345' }) });
  const c = g.headers.get('set-cookie').split(';')[0];
  await fetch(`${taban}/admin/v1/auth/mfa`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: c }, body: JSON.stringify({ code: totpUret(sir) }) });
  const k = await kisi('5380000131', 'CUSTOMER');
  await istek('/api/v1/profiles/me/freeze', { yontem: 'POST', token: k.token, govde: {} });
  const r = await fetch(`${taban}/admin/v1/users/${k.id}`, { headers: { Cookie: c } }).then((x) => x.json());
  assert.equal(r.status, 'ACTIVE');
  assert.ok(r.frozenAt, 'dondurma admin\'de görünür');
});
