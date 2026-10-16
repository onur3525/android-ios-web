// CANLIYA ÇIKIŞ ÖNCESİ FİNAL DENETİM — düzeltilen bulguların regresyon testleri
//   · ReDoS: e-posta deseni uzun girdide olay döngüsünü kilitlemez
//   · scrypt olay döngüsünü kilitlemez (giriş sürerken başka istek yanıtlanır)
//   · Admin MFA: hatalı TOTP hesap başına sayılır ve hesabı kilitler
//   · Yarış durumları: teklif seçimi, iletişim açma, çift teklif, çift yorum,
//     yenileme token'ı tekrarı, OTP çift tüketimi, teklif talebi geçişleri
//   · Kötüye kullanım sınırları: ilan / teklif / mesaj / teklif talebi
//   · Kayıt bakımı: eski teknik kayıtlar silinir, geçerli olanlar KALIR
//   · WebSocket: kullanıcı başına bağlantı sınırı
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { gercekZamanliKur } = await import('../src/gercek_zamanli.js');
const { olaylar } = await import('../src/olaylar.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { kayitBakimi } = await import('../src/bakim.js');

let db, sunucu, taban;

async function istek(yol, { yontem = 'GET', govde, token, cerez, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1', ...(cerez ? { Cookie: cerez } : {}) } : {}),
      ...basliklar,
    },
    body: govde !== undefined ? (typeof govde === 'string' ? govde : JSON.stringify(govde)) : undefined,
  });
  const m = await r.text();
  let json = null;
  try { json = m ? JSON.parse(m) : null; } catch { json = m; }
  return { durum: r.status, json, cerez: r.headers.get('set-cookie')?.split(';')[0] };
}

async function kisi(tel, rol) {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  await db.prepare('UPDATE otp_codes SET created_at = ? WHERE phone = ?').run('2000-01-01T00:00:00.000Z', tel);
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' } });
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Deneme Kişi', email: `k${tel}@ornek.com`, role: rol, otpCode: globalThis.__sonOtp } });
  assert.equal(r.durum, 200, JSON.stringify(r.json));
  const me = await istek('/api/v1/users/me', { token: r.json.accessToken });
  return { token: r.json.accessToken, refresh: r.json.refreshToken, id: me.json.id };
}

let hiz;
before(async () => {
  db = await testDb();
  await olaylar.kur(db);
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  gercekZamanliKur(sunucu, db);
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  hiz = (await db.prepare('SELECT name FROM services LIMIT 1').get()).name;
});
after(async () => {
  sunucu.closeAllConnections?.();
  sunucu.close();
  // Önce LISTEN bağlantısı (olcekleme.test.js ile aynı sıra), sonra havuz.
  await olaylar.kapat();
  await db?.close();
});

async function ilanVeTeklif(sahip, ...ustalar) {
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil iş' } });
  assert.equal(l.durum, 200, JSON.stringify(l.json));
  const teklifler = [];
  for (const u of ustalar) {
    const o = await istek('/api/v1/offers', { yontem: 'POST', token: u.token, govde: { listingId: l.json.id, amountTl: 500, note: '' } });
    assert.equal(o.durum, 200, JSON.stringify(o.json));
    teklifler.push(o.json);
  }
  return { l: l.json, teklifler };
}

// ═════ GİRDİ / OLAY DÖNGÜSÜ ═════
test('ReDoS: çok uzun e-posta olay döngüsünü kilitlemez (oturumsuz kayıt ucu)', async () => {
  const kotu = `a@${'.'.repeat(400_000)}@`;
  const t0 = Date.now();
  const r = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: '5370000001', password: 'sifre1234', name: 'Ad Soyad', email: kotu, role: 'CUSTOMER', otpCode: '123456' } });
  assert.equal(r.durum, 400);
  assert.ok(Date.now() - t0 < 2000, `yanıt ${Date.now() - t0} ms sürdü (önceden dakikalar)`);
});

test('scrypt olay döngüsünü kilitlemez: eşzamanlı girişlerde döngü gecikmesi düşük kalır', async () => {
  await kisi('5370000002', 'CUSTOMER');
  // Sunucu bu süreçte çalışıyor: olay döngüsü gecikmesi doğrudan ölçülür.
  const { monitorEventLoopDelay } = await import('node:perf_hooks');
  const h = monitorEventLoopDelay({ resolution: 5 });
  h.enable();
  const girisler = await Promise.all(Array.from({ length: 6 }, () => istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5370000002', password: 'sifre1234' } })));
  h.disable();
  for (const g of girisler) assert.equal(g.durum, 200);
  const enCok = h.max / 1e6;
  // Eşzamanlı scrypt'te her giriş döngüyü ~100 ms KİLİTLER (ölçülen: tek çağrı ≈105 ms).
  assert.ok(enCok < 60, `olay döngüsü ${enCok.toFixed(0)} ms kilitlendi`);
});

// ═════ ADMIN MFA ═════
test('admin MFA: hatalı TOTP hesap başına sayılır; şifre girişi sayacı SIFIRLAMAZ; eşikte hesap kilitlenir', async () => {
  const sir = base32Uret();
  const id = randomUUID();
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
    .run(id, 'mfa@hc.test', 'Mfa', sifreOzetle('GucluSifre12345'), sirSifrele(sir), simdi());
  const dogru = totpUret(sir);
  const yanlis = dogru === '000000' ? '111111' : '000000';
  // Saldırgan şifreyi biliyor; her denemede yeniden giriş yapıp farklı IP'den TOTP dener.
  for (let i = 0; i < 5; i++) {
    await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'admin_giris:%'`).run();
    const g = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'mfa@hc.test', password: 'GucluSifre12345' } });
    if (g.durum !== 200) break;
    const m = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: yanlis }, cerez: g.cerez });
    assert.equal(m.durum, 401);
  }
  const a = await db.prepare('SELECT locked_until FROM admins WHERE id = ?').get(id);
  assert.ok(a.locked_until && Date.parse(a.locked_until) > Date.now(), 'hesap kilitlenmeli');
  // Kilitliyken DOĞRU şifre + DOĞRU kod da giremez.
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'admin_giris:%'`).run();
  const g = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'mfa@hc.test', password: 'GucluSifre12345' } });
  assert.equal(g.durum, 429);
  // Kilit kalkınca doğru kodla girilir ve sayaç sıfırlanır.
  await db.prepare('UPDATE admins SET locked_until = NULL WHERE id = ?').run(id);
  const g2 = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'mfa@hc.test', password: 'GucluSifre12345' } });
  const m2 = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: totpUret(sir) }, cerez: g2.cerez });
  assert.equal(m2.durum, 200);
  assert.equal((await db.prepare('SELECT failed_count FROM admins WHERE id = ?').get(id)).failed_count, 0);
});

// ═════ YARIŞ DURUMLARI ═════
// ⚠ DÜRÜSTLÜK NOTU: SQLite sürücüsü işlemleri tek bağlantıda SIRAYA koyduğu
// için bu testler ESKİ kodda da geçiyordu (ölçüldü) — yarışın kendisini burada
// üretemezler. Düzeltmeler (koşullu UPDATE, ON CONFLICT, tekil ihlal eşlemesi)
// PostgreSQL'deki eşzamanlı bağlantılar içindir ve orada DOĞRULANMADI. Bu
// testler yalnız düzeltilmiş kodun doğru SONUCU verdiğini kilitler.
test('eşzamanlı iki FARKLI teklif seçimi: yalnız biri SELECTED olur', async () => {
  const sahip = await kisi('5370000011', 'CUSTOMER');
  const u1 = await kisi('5370000012', 'PROVIDER');
  const u2 = await kisi('5370000013', 'PROVIDER');
  const { l, teklifler } = await ilanVeTeklif(sahip, u1, u2);
  const sonuc = await Promise.all(teklifler.map((o) => istek(`/api/v1/listings/${l.id}/selected-offer`, { yontem: 'PUT', token: sahip.token, govde: { offerId: o.id } })));
  assert.equal(sonuc.filter((r) => r.durum === 200).length, 1);
  const secili = await db.prepare(`SELECT COUNT(*) n FROM offers WHERE listing_id = ? AND status = 'SELECTED'`).get(l.id);
  assert.equal(secili.n, 1, 'iki teklif birden seçili kalmamalı');
  const ilan = await db.prepare('SELECT selected_offer_id FROM listings WHERE id = ?').get(l.id);
  assert.equal((await db.prepare('SELECT status FROM offers WHERE id = ?').get(ilan.selected_offer_id)).status, 'SELECTED');
});

test('eşzamanlı iletişim açma: 500 yok, kayıt ve bildirim TEK', async () => {
  const sahip = await kisi('5370000021', 'CUSTOMER');
  const u1 = await kisi('5370000022', 'PROVIDER');
  const { teklifler: [o] } = await ilanVeTeklif(sahip, u1);
  const sonuc = await Promise.all([
    istek(`/api/v1/offers/${o.id}/communication`, { yontem: 'POST', token: sahip.token }),
    istek(`/api/v1/offers/${o.id}/communication`, { yontem: 'POST', token: sahip.token }),
    istek(`/api/v1/offers/${o.id}/communication`, { yontem: 'POST', token: sahip.token }),
  ]);
  for (const r of sonuc) assert.equal(r.durum, 200, JSON.stringify(r.json));
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM contacts WHERE offer_id = ?').get(o.id)).n, 1);
  assert.equal((await db.prepare(`SELECT COUNT(*) n FROM notifications WHERE type = 'CONTACT_OPENED' AND ref_id = ?`).get(o.id)).n, 1);
});

test('16 Eki: iletişimi hizmet veren de açar; iki taraf birbirini görür; bildirim karşı tarafa', async () => {
  const sahip = await kisi('5370000025', 'CUSTOMER');
  const u1 = await kisi('5370000026', 'PROVIDER');
  const { teklifler: [o] } = await ilanVeTeklif(sahip, u1);
  const ac = await istek(`/api/v1/offers/${o.id}/communication`, { yontem: 'POST', token: u1.token });
  assert.equal(ac.durum, 200, JSON.stringify(ac.json));
  assert.equal(ac.json.open, true);
  assert.equal((await db.prepare(`SELECT user_id FROM notifications WHERE type = 'CONTACT_OPENED' AND ref_id = ?`).get(o.id)).user_id, sahip.id, 'açan hizmet veren → bildirim ilan sahibine');
  const ustaGorur = await istek(`/api/v1/contact/${o.id}`, { yontem: 'GET', token: u1.token });
  const sahipGorur = await istek(`/api/v1/contact/${o.id}`, { yontem: 'GET', token: sahip.token });
  assert.ok(ustaGorur.json.counterpart.phone, 'hizmet veren, numarasını gizlemeyen hizmet alanın telefonunu görür');
  assert.ok(sahipGorur.json.counterpart.phone, 'hizmet alan, hizmet verenin telefonunu görür');
  // İkinci açma isteği yeni paylaşım/bildirim üretmez.
  assert.equal((await istek(`/api/v1/offers/${o.id}/communication`, { yontem: 'POST', token: sahip.token })).durum, 200);
  assert.equal(Number((await db.prepare(`SELECT COUNT(*) n FROM notifications WHERE type = 'CONTACT_OPENED' AND ref_id = ?`).get(o.id)).n), 1);
});

test('16 Eki: "Sadece Uygulama İçi Mesaj" seçen hizmet alanın telefonu hizmet verene gösterilmez', async () => {
  const sahip = await kisi('5370000027', 'CUSTOMER');
  const u1 = await kisi('5370000028', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil iş', iletisimTercihi: 'yalnizMesaj' } });
  assert.equal(l.durum, 200, JSON.stringify(l.json));
  assert.equal(l.json.iletisimTercihi, 'yalnizMesaj');
  const o = await istek('/api/v1/offers', { yontem: 'POST', token: u1.token, govde: { listingId: l.json.id, amountTl: 500, note: '' } });
  assert.equal((await istek(`/api/v1/offers/${o.json.id}/communication`, { yontem: 'POST', token: u1.token })).durum, 200);
  const ustaGorur = await istek(`/api/v1/contact/${o.json.id}`, { token: u1.token });
  assert.equal(ustaGorur.json.open, true, 'mesajlaşma açık');
  assert.equal(ustaGorur.json.counterpart.phone, null, 'gizli numara paylaşılmaz');
  assert.ok((await istek(`/api/v1/contact/${o.json.id}`, { token: sahip.token })).json.counterpart.phone, 'hizmet verenin numarası görünür');
  assert.equal((await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil iş', iletisimTercihi: 'baska' } })).durum, 400);
});

test('eşzamanlı çift teklif ve çift yorum: 500 değil anlamlı hata, kayıt TEK', async () => {
  const sahip = await kisi('5370000031', 'CUSTOMER');
  const u1 = await kisi('5370000032', 'PROVIDER');
  const l = await istek('/api/v1/listings', { yontem: 'POST', token: sahip.token, govde: { title: hiz, location: 'Konak', description: 'mutfak dolabı montajı gerekli' } });
  const teklif = () => istek('/api/v1/offers', { yontem: 'POST', token: u1.token, govde: { listingId: l.json.id, amountTl: 700, note: '' } });
  const t = await Promise.all([teklif(), teklif(), teklif()]);
  assert.equal(t.filter((r) => r.durum === 200).length, 1);
  for (const r of t.filter((x) => x.durum !== 200)) assert.equal(r.json.error.code, 'DUPLICATE_OFFER');
  const oid = t.find((r) => r.durum === 200).json.id;
  await istek(`/api/v1/listings/${l.json.id}/selected-offer`, { yontem: 'PUT', token: sahip.token, govde: { offerId: oid } });
  const yorum = () => istek(`/api/v1/listings/${l.json.id}/review`, { yontem: 'POST', token: sahip.token, govde: { stars: 5, text: 'iyi' } });
  const y = await Promise.all([yorum(), yorum()]);
  assert.equal(y.filter((r) => r.durum === 200).length, 1);
  for (const r of y.filter((x) => x.durum !== 200)) assert.ok(r.durum < 500, `yorum tekrarı ${r.durum}`);
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM reviews WHERE offer_id = ?').get(oid)).n, 1);
});

test('aynı yenileme token\'ı eşzamanlı iki kez: oturum soyu TEK kalır, kullanıcı çıkış yapmaz', async () => {
  // 15 Eki: iki sekme / yanıtı kaybolan istek aynı belirteçle yeniler. Pay
  // içinde ikinci istek soyun güncel halkasını döndürür (bkz. kullanici.js);
  // iki ayrı oturum açılmaz ve bütün oturumlar kapatılmaz.
  const k = await kisi('5370000041', 'CUSTOMER');
  const r = await Promise.all([1, 2].map(() => istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } })));
  for (const x of r) assert.ok(x.durum === 200 || x.durum === 401, `${x.durum}`);
  const aktif = await db.prepare('SELECT COUNT(*) n FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL').get(k.id);
  assert.equal(Number(aktif.n), 1, `aktif oturum ${aktif.n}`);
  assert.equal(await db.prepare(`SELECT 1 FROM user_sessions WHERE user_id = ? AND revoke_reason = 'REUSE_DETECTED'`).get(k.id), undefined);
});

test('aynı OTP eşzamanlı iki kayıtta kullanılamaz', async () => {
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'otp_ip:%'`).run();
  await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5370000051', purpose: 'REGISTER' } });
  const kod = globalThis.__sonOtp;
  const kayit = (mail) => istek('/api/v1/auth/register', { yontem: 'POST', govde: { termsAccepted: true, ageConfirmed: true, phone: '5370000051', password: 'sifre1234', name: 'Ad Soyad', email: mail, role: 'CUSTOMER', otpCode: kod } });
  const r = await Promise.all([kayit('x1@ornek.com'), kayit('x2@ornek.com')]);
  assert.equal(r.filter((x) => x.durum === 200).length, 1);
  for (const x of r) assert.ok(x.durum < 500, `${x.durum} ${JSON.stringify(x.json)}`);
  assert.equal((await db.prepare(`SELECT COUNT(*) n FROM users WHERE phone = '5370000051'`).get()).n, 1);
});

test('teklif talebi: eşzamanlı ret + teklif tutarsız durum üretmez', async () => {
  const alan = await kisi('5370000061', 'CUSTOMER');
  const usta = await kisi('5370000062', 'PROVIDER');
  const t = await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: 'x', hizmet: hiz, aciklama: 'acil tesisat işi var', iletisimTercihi: 'yalnizMesaj' } });
  if (t.durum !== 200) {
    const s = await db.prepare('SELECT s.name hizmet, c.name kategori FROM services s JOIN categories c ON c.id = s.category_id WHERE s.name = ?').get(hiz);
    Object.assign(t, await istek('/api/v1/teklif-talepleri', { yontem: 'POST', token: alan.token, govde: { saglayiciId: usta.id, kategori: s.kategori, hizmet: s.hizmet, aciklama: 'acil tesisat işi var', iletisimTercihi: 'yalnizMesaj' } }));
  }
  assert.equal(t.durum, 200, JSON.stringify(t.json));
  const [red, teklif] = await Promise.all([
    istek(`/api/v1/teklif-talepleri/${t.json.id}/reddet`, { yontem: 'POST', token: alan.token, govde: {} }),
    istek(`/api/v1/teklif-talepleri/${t.json.id}/teklif`, { yontem: 'POST', token: usta.token, govde: { fiyat: 900 } }),
  ]);
  assert.ok(red.durum < 500 && teklif.durum < 500);
  const son = await db.prepare('SELECT durum, teklif_fiyati FROM teklif_talepleri WHERE id = ?').get(t.json.id);
  // Ya reddedildi (teklif yazılmadı) ya da teklif geldi ve ret o anki duruma göre işlendi — ama
  // "REDDEDILDI iken teklif bildirimi" ya da "TEKLIF_GELDI iken ret kaybı" gibi yarım durum yok.
  if (son.durum === 'REDDEDILDI') assert.ok(red.durum === 200);
  if (teklif.durum === 200 && red.durum === 200) assert.equal(son.durum, 'REDDEDILDI');
  if (teklif.durum !== 200) assert.equal(teklif.json.error.code, 'INVALID_STATE');
});

// ═════ KÖTÜYE KULLANIM SINIRLARI ═════
test('ilan oluşturma kullanıcı başına sınırlı (saatte 30); başka kullanıcı etkilenmez', async () => {
  const k = await kisi('5370000071', 'CUSTOMER');
  const b = await kisi('5370000072', 'CUSTOMER');
  await db.prepare('INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 30)').run(`ilan_olustur:${k.id}`, Math.floor(Date.now() / 3_600_000));
  const r = await istek('/api/v1/listings', { yontem: 'POST', token: k.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil iş' } });
  assert.equal(r.durum, 429);
  assert.equal((await istek('/api/v1/listings', { yontem: 'POST', token: b.token, govde: { title: hiz, location: 'Konak', description: 'salon boyanacak acil iş' } })).durum, 200);
});

test('mesaj gönderimi kullanıcı başına dakikada 60 ile sınırlı', async () => {
  const sahip = await kisi('5370000081', 'CUSTOMER');
  const u1 = await kisi('5370000082', 'PROVIDER');
  const { teklifler: [o] } = await ilanVeTeklif(sahip, u1);
  await istek(`/api/v1/offers/${o.id}/communication`, { yontem: 'POST', token: sahip.token });
  assert.equal((await istek('/api/v1/messages', { yontem: 'POST', token: sahip.token, govde: { offerId: o.id, text: 'merhaba' } })).durum, 200);
  await db.prepare('UPDATE rate_limits SET count = 60 WHERE key = ?').run(`mesaj:${sahip.id}`);
  assert.equal((await istek('/api/v1/messages', { yontem: 'POST', token: sahip.token, govde: { offerId: o.id, text: 'merhaba' } })).durum, 429);
  assert.equal((await istek('/api/v1/messages', { yontem: 'POST', token: u1.token, govde: { offerId: o.id, text: 'selam' } })).durum, 200);
});

// ═════ KAYIT BAKIMI ═════
test('kayıt bakımı: yalnız süresi geçmiş teknik kayıtlar silinir', async () => {
  const k = await kisi('5370000091', 'CUSTOMER');
  const simdiPencere = Math.floor(Date.now() / 3_600_000);
  await db.prepare('INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 3)').run('ilan_olustur:eski', simdiPencere - 5);
  await db.prepare('INSERT INTO rate_limits (key, window_start, count) VALUES (?, ?, 3)').run('ilan_olustur:guncel', simdiPencere);
  await db.prepare(`INSERT INTO otp_codes (id, phone, purpose, code_hash, expires_at, attempts, created_at) VALUES (?, '5370000099', 'REGISTER', 'x', ?, 0, ?)`)
    .run(randomUUID(), '2000-01-01T00:05:00.000Z', '2000-01-01T00:00:00.000Z');
  // İptal edilmiş ama SÜRESİ DOLMAMIŞ oturum: yenileme tekrarını yakalamak için KALMALI.
  await db.prepare(`UPDATE user_sessions SET revoked_at = ?, revoke_reason = 'ROTATED' WHERE user_id = ?`).run(simdi(), k.id);
  const eskiOturum = randomUUID();
  await db.prepare(`INSERT INTO user_sessions (id, user_id, refresh_hash, created_at, last_used, expires_at) VALUES (?, ?, ?, ?, ?, ?)`)
    .run(eskiOturum, k.id, `eski-${eskiOturum}`, '2000-01-01T00:00:00.000Z', '2000-01-01T00:00:00.000Z', '2000-02-01T00:00:00.000Z');
  const s = await kayitBakimi(db);
  assert.ok(s.hiz >= 1 && s.otp >= 1 && s.oturum >= 1);
  assert.equal(await db.prepare('SELECT 1 FROM rate_limits WHERE key = ?').get('ilan_olustur:eski'), undefined);
  assert.ok(await db.prepare('SELECT 1 FROM rate_limits WHERE key = ?').get('ilan_olustur:guncel'));
  assert.equal(await db.prepare('SELECT 1 FROM user_sessions WHERE id = ?').get(eskiOturum), undefined);
  assert.ok((await db.prepare('SELECT COUNT(*) n FROM user_sessions WHERE user_id = ?').get(k.id)).n >= 1, 'geçerli oturumlar kalır');
  // Yenileme tekrarı hâlâ yakalanır.
  assert.equal((await istek('/api/v1/auth/refresh', { yontem: 'POST', govde: { refreshToken: k.refresh } })).durum, 401);
});

// ═════ WEBSOCKET ═════
test('WebSocket: kullanıcı başına en çok 10 bağlantı; fazlası en eskisini kapatır', async () => {
  const k = await kisi('5370000101', 'CUSTOMER');
  const soketler = [];
  for (let i = 0; i < 11; i++) {
    const ws = new WebSocket(`${taban.replace('http', 'ws')}/socket.io/?EIO=4&transport=websocket`);
    const d = { ws, kapandi: false, bagli: false };
    ws.onclose = () => { d.kapandi = true; };
    ws.onmessage = (e) => {
      const p = String(e.data);
      if (p === '2') return ws.send('3');
      if (p.startsWith('0')) return ws.send(`40/ws,${JSON.stringify({ token: k.token })}`);
      if (p.startsWith('40/ws')) d.bagli = true;
    };
    soketler.push(d);
    const son = Date.now() + 3000;
    while (!d.bagli && Date.now() < son) await new Promise((ok) => setTimeout(ok, 20));
    assert.ok(d.bagli, `soket ${i} bağlanamadı`);
  }
  const son = Date.now() + 2000;
  while (!soketler[0].kapandi && Date.now() < son) await new Promise((ok) => setTimeout(ok, 20));
  assert.equal(soketler[0].kapandi, true, 'en eski bağlantı kapanmalı');
  assert.equal(soketler.slice(1).filter((d) => !d.kapandi).length, 10);
  for (const d of soketler) d.ws.close();
});

// ═════ BİLDİRİM TERCİHLERİ (sunucu) ═════
test('bildirim tercihleri sunucuda: varsayılan açık, PATCH yalnız gönderilen alanı değiştirir, girişten sonra korunur', async () => {
  const k = await kisi('5370000111', 'CUSTOMER');
  const baska = await kisi('5370000112', 'CUSTOMER');
  assert.deepEqual((await istek('/api/v1/users/me', { token: k.token })).json.notificationPrefs, { offer: true, message: true, announcement: true, email: true });
  const r = await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', token: k.token, govde: { offer: false, announcement: false } });
  assert.equal(r.durum, 200);
  assert.deepEqual(r.json, { offer: false, message: true, announcement: false, email: true });
  assert.equal((await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', token: k.token, govde: { message: 'hayir' } })).durum, 400);
  assert.equal((await istek('/api/v1/profiles/me/notifications', { yontem: 'PATCH', govde: { offer: false } })).durum, 401);
  // Yeniden girişte tercih kaybolmaz; başka kullanıcı etkilenmez.
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5370000111', password: 'sifre1234' } });
  assert.deepEqual((await istek('/api/v1/users/me', { token: g.json.accessToken })).json.notificationPrefs, { offer: false, message: true, announcement: false, email: true });
  assert.equal((await istek('/api/v1/users/me', { token: baska.token })).json.notificationPrefs.offer, true);
});

// ═════ İŞLEM BAĞLAMI SIZINTISI (PostgreSQL'de kritik) ═════
test('commitSonrasi: görev YALNIZ commit sonrası ve işlem bağlamı DIŞINDA koşar; geri alınan işlemde koşmaz', async () => {
  const kayit = [];
  await db.tx(async () => {
    db.commitSonrasi(() => kayit.push({ ad: 'commit', baglam: db.als.getStore() }));
    await new Promise((ok) => setTimeout(ok, 10)); // görev bu arada koşmamalı
    assert.equal(kayit.length, 0, 'commit öncesi koştu');
  });
  await new Promise((ok) => setImmediate(ok));
  assert.equal(kayit.length, 1);
  assert.equal(kayit[0].baglam, undefined, 'görev işlem bağlamını miras aldı');
  await assert.rejects(db.tx(async () => {
    db.commitSonrasi(() => kayit.push({ ad: 'geri-alinan' }));
    throw new Error('geri al');
  }));
  await new Promise((ok) => setTimeout(ok, 10));
  assert.equal(kayit.length, 1, 'geri alınan işlemin görevi koştu');
});

test('PostgreSQL sürücüsü (sahte havuz): iş kilidi ayrı bağlantıda oturum kilidi; iş, işlem bağlamı dışında; commit sonrası görev bağlantıyı kullanmaz', async () => {
  // ⚠ GERÇEK PostgreSQL DEĞİL: yalnız sürücü katmanının hangi bağlantıya ne
  // gönderdiği sınanır (PostgreSQL üzerinde DOĞRULANMADI).
  const { veritabaniAc } = await import('../src/db.js');
  const gunluk = [];
  let no = 0;
  class SahteIstemci {
    constructor() { this.no = ++no; }
    async query(q, p) { gunluk.push([this.no, typeof q === 'string' ? q : q.text, p]); return { rows: [{ ok: true }], rowCount: 1 }; }
    release() { gunluk.push([this.no, 'RELEASE']); }
  }
  class SahteHavuz {
    async connect() { return new SahteIstemci(); }
    async query(q, p) { gunluk.push([0, q, p]); return { rows: [{ ok: 1 }], rowCount: 1 }; }
    on() {}
    async end() {}
  }
  const sahtePg = { Pool: SahteHavuz, types: { setTypeParser() {} } };
  const { PostgresDbSinif } = await import('../src/db.js');
  assert.ok(PostgresDbSinif, 'PostgresDb sınıfı test için dışa açık olmalı');
  const pdb = new PostgresDbSinif(sahtePg, 'postgres://x', { havuz: 2 });
  // 1) İş kilidi: oturum düzeyinde, ayrı bağlantı; işin sorguları HAVUZDAN (0) gider.
  await pdb.isKilidi('is:deneme', async () => { await pdb.prepare('SELECT 1').get(); });
  assert.ok(gunluk.some(([, q]) => /pg_try_advisory_lock\(/.test(q)), 'oturum kilidi alınmalı');
  assert.ok(!gunluk.some(([, q]) => /xact_lock/.test(q)), 'işlem kilidi (tek işlem içinde iş) kullanılmamalı');
  assert.ok(gunluk.some(([n, q]) => n === 0 && q === 'SELECT 1'), 'iş sorgusu kilit bağlantısında değil havuzda koşmalı');
  assert.ok(gunluk.some(([, q]) => /pg_advisory_unlock\(/.test(q)), 'kilit çözülmeli');
  // 2) İşlem içinden tetiklenen görev: commit SONRASI ve istemci bağlamı dışında.
  gunluk.length = 0;
  let gorevBaglami = 'yok';
  await pdb.tx(async () => {
    await pdb.prepare('INSERT 1').run();
    pdb.commitSonrasi(() => { gorevBaglami = pdb.als.getStore(); pdb.prepare('SELECT gorev').get(); });
  });
  await new Promise((ok) => setImmediate(ok));
  await new Promise((ok) => setImmediate(ok));
  const islemNo = gunluk.find(([, q]) => q === 'BEGIN')[0];
  const sira = gunluk.map(([n, q]) => `${n}:${q}`);
  assert.ok(sira.indexOf(`${islemNo}:COMMIT`) < sira.indexOf('0:SELECT gorev'), 'görev commit öncesi koştu');
  assert.ok(!sira.includes(`${islemNo}:SELECT gorev`), 'görev isteğin işlem bağlantısını kullandı');
  assert.equal(gorevBaglami, undefined);
  // veritabaniAc import'u yalnız modülün yüklendiğini doğrular.
  assert.equal(typeof veritabaniAc, 'function');
});
