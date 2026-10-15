// OTURUM SÜREKLİLİĞİ VE İLAN AKIŞI (15 Eki, kullanıcı bulguları)
//   · Aynı çerez/belirteçle eşzamanlı yenileme (iki sekme, kısayol + sekme,
//     yanıtı kaybolan istek) kullanıcıyı çıkış yaptırmaz; pay dışında tekrar
//     kullanım tespiti aynen bütün oturumları kapatır.
//   · Yeni ilan, eşleşen hizmet verenlere uygulama içi bildirim + push
//     kuyruğu üretir (uygulama kapalıyken de telefona düşer).
//   · İlan sahibi gelen teklifleri ilan detayında ve İlanlarım listesinde alır.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { mesajGovdesi, pushIzniVar } = await import('../src/fcm.js');

let db, sunucu, taban, kat, hiz, digerHiz;
const WEB = { 'X-HC-Web': '1' };

async function istek(yol, { yontem = 'GET', govde, token, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...basliklar },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null, cerezler: r.headers.getSetCookie() };
}
async function kisi(tel, rol, basliklar = {}) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%' OR key LIKE 'giris_ip:%'`).run();
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', basliklar, govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: `Kişi ${tel.slice(-2)}`, email: `o${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, refresh: r.json.refreshToken, id: me.json.id, cerezler: r.cerezler };
}
const cerez = (cerezler) => decodeURIComponent((cerezler.find((c) => c.startsWith('hc_rt=')) ?? '').split(';')[0].slice('hc_rt='.length));

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  const s = await db.prepare('SELECT c.name k, s.name h FROM services s JOIN categories c ON c.id = s.category_id ORDER BY c.name, s.name LIMIT 1').get();
  kat = s.k; hiz = s.h;
  digerHiz = (await db.prepare('SELECT s.name h FROM services s JOIN categories c ON c.id = s.category_id WHERE c.name <> ? LIMIT 1').get(kat)).h;
});
after(async () => { sunucu.closeAllConnections?.(); sunucu.close(); await db?.close(); });

// ═════ OTURUM ═════
test('web: iki sekme aynı çerezle aynı anda yenilerse ikisi de oturumda kalır; bütün oturumlar kapanmaz', async () => {
  const k = await kisi('5410000001', 'CUSTOMER', WEB);
  const rt = cerez(k.cerezler);
  const [a, b] = await Promise.all([1, 2].map(() => istek('/api/v1/auth/refresh', { yontem: 'POST', govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(rt)}` } })));
  assert.equal(a.durum, 200);
  assert.equal(b.durum, 200, 'ikinci sekme çıkış yaptırılmamalı');
  // Son yanıtın çerezi tarayıcıda kalır; onunla oturum sürer.
  const son = cerez(b.cerezler);
  const c = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: {}, basliklar: { ...WEB, Cookie: `hc_rt=${encodeURIComponent(son)}` } });
  assert.equal(c.durum, 200);
  assert.equal((await istek('/api/v1/users/me', { token: c.json.accessToken })).durum, 200);
  assert.equal(Number((await db.prepare('SELECT COUNT(*) n FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL').get(k.id)).n), 1);
});

test('mobil: yanıtı kaybolan yenileme 60 sn içinde tekrarlanabilir; pay dışında tekrar kullanım bütün oturumları kapatır', async () => {
  const k = await kisi('5410000002', 'CUSTOMER');
  const y1 = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } });
  assert.equal(y1.durum, 200);
  // İstemci yanıtı alamadı, eski belirteçle yeniden denedi.
  const y2 = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } });
  assert.equal(y2.durum, 200);
  assert.equal((await istek('/api/v1/users/me', { token: y2.json.accessToken })).durum, 200);
  // Saldırgan aynı eski belirteci 2 dk sonra kullanırsa: tespit + bütün oturumlar.
  await db.prepare(`UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoke_reason = 'ROTATED'`).run(new Date(Date.now() - 120_000).toISOString(), k.id);
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } })).durum, 401);
  assert.equal((await istek('/api/v1/users/me', { token: y2.json.accessToken })).durum, 401);
});

test('pay başka cihazın oturumunu döndürmez (aynı soy + aynı cihaz şartı)', async () => {
  const k = await kisi('5410000003', 'CUSTOMER');
  const y1 = await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } });
  assert.equal(y1.durum, 200);
  // Halefin cihaz bilgisi farklı (başka cihazdan çalınmış belirteç senaryosu).
  await db.prepare(`UPDATE user_sessions SET user_agent = 'baska-cihaz' WHERE user_id = ? AND revoked_at IS NULL`).run(k.id);
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } })).durum, 401);
});

// ═════ YENİ İLAN BİLDİRİMİ ═════
async function ustaProfili(u, kategoriler, ilceler) {
  const r = await istek('/api/v1/profiles/me/provider', { yontem: 'PUT', token: u.token, govde: { categories: kategoriler, districts: ilceler } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
}
const bildirimleri = (id) => db.prepare(`SELECT * FROM notifications WHERE user_id = ? AND type = 'NEW_LISTING'`).all(id);

test('yeni ilan: kategorisi ve ilçesi eşleşen hizmet verene bildirim + push kuyruğu; eşleşmeyene, sahibine ve kurulumu bitmemişe gitmez', async () => {
  const [ilce, ikinciIlce] = (await db.prepare(`SELECT d.name FROM districts d WHERE d.active = TRUE AND d.deleted_at IS NULL ORDER BY d.name LIMIT 2`).all()).map((x) => x.name);
  assert.ok(ilce && ikinciIlce, 'tohum verisinde iki ilçe olmalı');
  const eslesen = await kisi('5410000011', 'PROVIDER');
  await ustaProfili(eslesen, [hiz], [ilce]);
  const kategoriSecen = await kisi('5410000012', 'PROVIDER');
  await ustaProfili(kategoriSecen, [kat], []);
  const baskaIlce = await kisi('5410000013', 'PROVIDER');
  await ustaProfili(baskaIlce, [hiz], [ikinciIlce]);
  const baskaHizmet = await kisi('5410000014', 'PROVIDER');
  await ustaProfili(baskaHizmet, [digerHiz], []);
  const kurulmamis = await kisi('5410000015', 'PROVIDER');
  const alan = await kisi('5410000016', 'CUSTOMER');

  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: `Merkez, ${ilce} / İzmir`, description: 'acil tamir işi var' } });
  assert.equal(l.durum, 200, JSON.stringify(l.json));

  const [b] = await bildirimleri(eslesen.id);
  assert.ok(b, 'eşleşen hizmet verene bildirim');
  assert.equal(b.ref_id, l.json.id);
  assert.equal(b.push_target, 'is', 'push dokununca hizmet verenin iş ekranı açılır');
  assert.equal(b.push_status, null, 'push kuyruğunda (gönderim işi telefona iletir)');
  const govde = mesajGovdesi(b);
  assert.ok(govde.notification.title && govde.notification.body, 'bildirim yükü: uygulama kapalıyken de sistem bildirimi gösterilir');
  assert.deepEqual([govde.data.hedef, govde.data.id], ['is', l.json.id]);
  assert.equal((await bildirimleri(kategoriSecen.id)).length, 1, 'kategorinin tamamını seçen de alır');
  for (const u of [baskaIlce, baskaHizmet, kurulmamis, alan]) assert.equal((await bildirimleri(u.id)).length, 0, u.id);

  // Aynı anahtarla yeniden deneme yeni bildirim üretmez.
  const idem = { 'Idempotency-Key': 'ilan-tekrar-1' };
  const l2 = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, basliklar: idem, govde: { title: hiz, location: `Merkez, ${ilce} / İzmir`, description: 'ikinci acil iş var' } });
  await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, basliklar: idem, govde: { title: hiz, location: `Merkez, ${ilce} / İzmir`, description: 'ikinci acil iş var' } });
  assert.equal((await bildirimleri(eslesen.id)).filter((x) => x.ref_id === l2.json.id).length, 1);
});

test('push tercihi: "Yeni teklifler" kapalıysa yeni ilan push\'u gönderilmez (uygulama içi bildirim kalır)', () => {
  assert.equal(pushIzniVar({ notif_offer: 0 }, 'NEW_LISTING'), false);
  assert.equal(pushIzniVar({ notif_offer: 1 }, 'NEW_LISTING'), true);
});

// ═════ HİZMET ALAN TEKLİFLERİ GÖRÜR ═════
test('ilan sahibi gelen teklifleri ilan detayında ve İlanlarım listesinde alır; hizmet veren başkasının teklifini görmez', async () => {
  const alan = await kisi('5410000021', 'CUSTOMER');
  const u1 = await kisi('5410000022', 'PROVIDER');
  const u2 = await kisi('5410000023', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: alan.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil' } });
  const o1 = await istek('/api/v1/offers', { yontem: 'POST', token: u1.token, govde: { listingId: l.json.id, amountTl: 900, note: 'yarın gelirim' } });
  await istek('/api/v1/offers', { yontem: 'POST', token: u2.token, govde: { listingId: l.json.id, amountTl: 800, note: '' } });

  const d = await istek(`/api/v1/listings/${l.json.id}`, { token: alan.token });
  assert.equal(d.json.offers.length, 2);
  const t = d.json.offers.find((x) => x.id === o1.json.id);
  assert.deepEqual([t.providerId, t.amountTl, t.note, t.status], [u1.id, 900, 'yarın gelirim', 'ACTIVE']);
  const benim = await istek('/api/v1/listings/my', { token: alan.token });
  assert.equal(benim.json.find((x) => x.id === l.json.id).offers.length, 2);
  // Hizmet veren ilan detayında teklif listesi ALMAZ (rakip teklifler gizli).
  const u = await istek(`/api/v1/listings/${l.json.id}`, { token: u1.token });
  assert.equal(u.durum, 200);
  assert.equal('offers' in u.json, false);
});
