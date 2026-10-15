// İSTEMCİ IP'Sİ — TEK GÜVENİLİR KAYNAK (http.js istemciIp)
//
// Kilitlenenler:
//   · X-Forwarded-For SAĞDAN, güvenilen altyapının başlığa eklediği DEĞER
//     sayısı kadar sayılarak okunur (fiziksel proxy sayısı değil);
//     istemcinin yazabildiği EN SOL değer asla seçilmez
//   · proxy'ye güvenilmiyorsa (0) başlık tamamen yok sayılır
//   · eksik başlık / yetersiz değer / geçersiz IP → soket adresi
//   · hız sınırları (giriş, Firebase oturumu, OTP, admin giriş/MFA/yeniden
//     doğrulama) sahte en sol değerle AŞILAMAZ
//   · kullanıcı oturumu, yenileme, admin oturumu ve denetim kayıtları AYNI
//     IP'yi taşır
//   · kaynakta başka bir IP okuma yeri kalmaz
//
// ⚠ Testler 127.0.0.1'den bağlanır (soket adresi). 198.51.100.0/24 ve
// 203.0.113.0/24 belgelendirme için ayrılmış adreslerdir.
import { test, before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createSign, generateKeyPairSync, randomUUID } from 'node:crypto';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { config } = await import('../src/config.js');
const { istemciIp } = await import('../src/http.js');
const { base32Uret, sifreOzetle, sirSifrele, totpUret } = await import('../src/auth.js');
const { testSertifikaGetiricisi } = await import('../src/firebase_token.js');

// ── Firebase test anahtarı (firebase_auth.test.js ile aynı yöntem) ──
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const KID = 'ip-test-anahtari';
testSertifikaGetiricisi(async () => ({ sertifikalar: { [KID]: publicKey.export({ type: 'spki', format: 'pem' }) }, sureSn: 3600 }));
function idToken(yuk) {
  const an = Math.floor(Date.now() / 1000);
  const bas = Buffer.from(JSON.stringify({ alg: 'RS256', kid: KID, typ: 'JWT' })).toString('base64url');
  const govde = Buffer.from(JSON.stringify({
    aud: 'hizmetcep-fe036', iss: 'https://securetoken.google.com/hizmetcep-fe036',
    iat: an - 10, auth_time: an - 10, exp: an + 3600, ...yuk,
  })).toString('base64url');
  const imza = createSign('RSA-SHA256').update(`${bas}.${govde}`).sign(privateKey).toString('base64url');
  return `${bas}.${govde}.${imza}`;
}

const GERCEK = '198.51.100.7';
const sahte = (i) => `203.0.113.${(i % 250) + 1}`;
const xff = (...d) => ({ 'X-Forwarded-For': d.join(', ') });

let db, sunucu, taban;
const SIFRE = 'GucluSifre12345';
const ADMIN = 'ip-admin@hc.test';
const ADMIN_SIR = base32Uret();

async function istek(yol, { yontem = 'GET', govde, token, cerez, basliklar = {} } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: {
      ...(govde !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(yol.startsWith('/admin/') ? { 'X-HC-Admin': '1', ...(cerez ? { Cookie: cerez } : {}) } : {}),
      ...basliklar,
    },
    body: govde !== undefined ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  let json = null;
  try { json = m ? JSON.parse(m) : null; } catch { json = m; }
  return { durum: r.status, json, cerez: r.headers.get('set-cookie')?.split(';')[0] };
}

before(async () => {
  db = await testDb();
  await tohumla(db);
  await db.prepare(`INSERT INTO admins (id, email, name, role, password_hash, totp_secret_enc, created_at) VALUES (?, ?, ?, 'super_admin', ?, ?, ?)`)
    .run(randomUUID(), ADMIN, 'IP Admin', sifreOzetle(SIFRE), sirSifrele(ADMIN_SIR), simdi());
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
});
after(async () => {
  config.guvenilirProxySayisi = 0;
  sunucu.closeAllConnections?.();
  sunucu.close();
  await db?.close();
});
// Her test kendi hop değerini kurar ve sayaçları temiz başlar.
afterEach(async () => {
  config.guvenilirProxySayisi = 0;
  await db.prepare('DELETE FROM rate_limits').run();
});

// ═════ A. istemciIp — fonksiyon düzeyi ═════
const req = (baslik, soket = '10.9.8.7') => ({
  socket: { remoteAddress: soket },
  headers: baslik === undefined ? {} : { 'x-forwarded-for': baslik },
});

test('A1 · proxy güvenilmiyorken (0) başlık tamamen yok sayılır', () => {
  config.guvenilirProxySayisi = 0;
  assert.equal(istemciIp(req(`${sahte(1)}, ${GERCEK}`)), '10.9.8.7');
  assert.equal(istemciIp(req(GERCEK)), '10.9.8.7');
});

test('A2 · hop 1: en sağdaki değer seçilir; sahte en sol değer ASLA seçilmez', () => {
  config.guvenilirProxySayisi = 1;
  assert.equal(istemciIp(req(`${sahte(1)}, ${GERCEK}`)), GERCEK);
  assert.equal(istemciIp(req(`${sahte(1)}, ${sahte(2)}, ${GERCEK}`)), GERCEK);
  assert.equal(istemciIp(req(GERCEK)), GERCEK);
});

test('A3 · hop 2: sondan ikinci değer (yük dengeleyicinin eklediği istemci) seçilir', () => {
  config.guvenilirProxySayisi = 2;
  assert.equal(istemciIp(req(`${sahte(1)}, ${GERCEK}, 130.211.0.1`)), GERCEK);
  assert.equal(istemciIp(req(`${GERCEK}, 130.211.0.1`)), GERCEK);
});

test('A4 · eksik başlık ya da hop sayısından az değer → soket adresi', () => {
  config.guvenilirProxySayisi = 1;
  assert.equal(istemciIp(req(undefined)), '10.9.8.7');
  assert.equal(istemciIp(req('')), '10.9.8.7');
  assert.equal(istemciIp(req('   ')), '10.9.8.7');
  config.guvenilirProxySayisi = 2;
  assert.equal(istemciIp(req(GERCEK)), '10.9.8.7');
  config.guvenilirProxySayisi = 3;
  assert.equal(istemciIp(req(`${GERCEK}, 130.211.0.1`)), '10.9.8.7');
});

test('A5 · seçilen değer geçerli bir IP değilse → soket adresi', () => {
  config.guvenilirProxySayisi = 1;
  for (const kotu of ['unknown', '1.2.3.4:80', '999.1.1.1', '<script>', 'a'.repeat(80), `${GERCEK}x`, '1.2.3', '']) {
    assert.equal(istemciIp(req(`${GERCEK}, ${kotu}`)), '10.9.8.7', kotu);
  }
  // Sahte değer geçersiz olsa bile doğru konumdaki geçerli değer seçilir.
  assert.equal(istemciIp(req(`<script>, ${GERCEK}`)), GERCEK);
});

test('A6 · geçerli IPv6 kabul edilir; birleşik ve dizi başlık doğru okunur', () => {
  config.guvenilirProxySayisi = 1;
  assert.equal(istemciIp(req(`${sahte(1)}, 2001:db8::1`)), '2001:db8::1');
  // Node, tekrarlanan X-Forwarded-For başlıklarını "a, b" olarak birleştirir.
  assert.equal(istemciIp(req(`${sahte(1)},${GERCEK}`)), GERCEK);
  assert.equal(istemciIp(req([sahte(1), GERCEK])), GERCEK);
});

test('A7 · soket adresi yoksa "bilinmiyor" (önceki davranış korunur)', () => {
  config.guvenilirProxySayisi = 0;
  assert.equal(istemciIp({ headers: {} }), 'bilinmiyor');
});

// ═════ A8–A10. IPv4-eşlenmiş IPv6 tek yazıma iner ═════
// Çift yığınlı sunucuda IPv4 istemcinin soket adresi `::ffff:a.b.c.d`
// gelir. Aynı adres iki yazımla kaydedilirse hız sınırı sayacı bölünür.
test('A8 · soket adresi: IPv4 aynen, IPv4-eşlenmiş IPv6 → IPv4, diğer IPv6 aynen', () => {
  config.guvenilirProxySayisi = 0;
  assert.equal(istemciIp(req(undefined, '127.0.0.1')), '127.0.0.1');
  assert.equal(istemciIp(req(undefined, '::ffff:127.0.0.1')), '127.0.0.1');
  assert.equal(istemciIp(req(undefined, '::FFFF:198.51.100.7')), GERCEK);
  assert.equal(istemciIp(req(undefined, '::ffff:c633:6407')), GERCEK); // onaltılık yazım
  assert.equal(istemciIp(req(undefined, '0:0:0:0:0:ffff:c633:6407')), GERCEK); // uzun yazım
  assert.equal(istemciIp(req(undefined, '::1')), '::1');
  assert.equal(istemciIp(req(undefined, '2001:db8::1')), '2001:db8::1');
  // Eşlenmiş OLMAYAN v4 gömülü biçimler dönüştürülmez.
  assert.equal(istemciIp(req(undefined, '64:ff9b::a00:1')), '64:ff9b::a00:1');
  assert.equal(istemciIp(req(undefined, '::ffff:0:127.0.0.1')), '::ffff:0:127.0.0.1');
});

test('A9 · güvenilir konumdaki eşlenmiş değer IPv4\'e iner; seçim kuralı DEĞİŞMEZ', () => {
  config.guvenilirProxySayisi = 1;
  assert.equal(istemciIp(req(`${sahte(1)}, ::ffff:${GERCEK}`)), GERCEK);
  // Sahte EN SOL değer eşlenmiş yazımla gelse de seçilmez.
  assert.equal(istemciIp(req(`::ffff:${sahte(1)}, ${GERCEK}`)), GERCEK);
  assert.equal(istemciIp(req(`::ffff:${sahte(1)}, ::ffff:${sahte(2)}, 2001:db8::1`)), '2001:db8::1');
  config.guvenilirProxySayisi = 2;
  assert.equal(istemciIp(req(`::ffff:${sahte(1)}, ::ffff:${GERCEK}, 130.211.0.1`)), GERCEK);
  // Başlık yetersiz/geçersizse soket adresine düşülür; o da tekleştirilir.
  assert.equal(istemciIp(req(`::ffff:${GERCEK}`, '::ffff:10.9.8.7')), '10.9.8.7');
  config.guvenilirProxySayisi = 1;
  assert.equal(istemciIp(req(`${GERCEK}, ::ffff:999.1.1.1`, '::ffff:10.9.8.7')), '10.9.8.7');
});

test('A10 · hop 0: eşlenmiş yazımlı sahte başlık da yok sayılır', () => {
  config.guvenilirProxySayisi = 0;
  assert.equal(istemciIp(req(`::ffff:${GERCEK}`, '::ffff:10.9.8.7')), '10.9.8.7');
  assert.equal(istemciIp(req(`::ffff:${sahte(1)}, ::ffff:${GERCEK}`, '10.9.8.7')), '10.9.8.7');
});

// ═════ C. Hız sınırları sahte başlıkla aşılamaz ═════
test('C1 · kullanıcı girişi (15 dk / 30): en sol değer her seferinde değişse de 31. istek 429', async () => {
  config.guvenilirProxySayisi = 1;
  for (let i = 0; i < 30; i++) {
    const r = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5350009001', password: 'yanlis-sifre' }, basliklar: xff(sahte(i), GERCEK) });
    assert.equal(r.durum, 401, `deneme ${i + 1}`);
  }
  const son = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5350009001', password: 'yanlis-sifre' }, basliklar: xff(sahte(99), GERCEK) });
  assert.equal(son.durum, 429);
  // Kontrol: gerçek adres farklıysa ayrı sayaç (başlık GERÇEKTEN okunuyor).
  const baska = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5350009001', password: 'yanlis-sifre' }, basliklar: xff(sahte(1), '198.51.100.8') });
  assert.equal(baska.durum, 401);
  // Sayaç anahtarlarında sahte değer YOK, gerçek değer VAR.
  const anahtarlar = (await db.prepare('SELECT key FROM rate_limits').all()).map((x) => x.key);
  assert.ok(anahtarlar.includes(`giris_ip:${GERCEK}`), anahtarlar.join());
  assert.ok(!anahtarlar.some((k) => k.includes('203.0.113.')), anahtarlar.join());
});

test('C2 · Firebase oturumu girişle AYNI sayacı paylaşır; geçersiz token da sayılır', async () => {
  config.guvenilirProxySayisi = 1;
  for (let i = 0; i < 30; i++) {
    const r = await istek('/api/v1/auth/firebase/session', { yontem: 'POST', govde: { idToken: 'gecersiz.token.degeri' }, basliklar: xff(sahte(i), GERCEK) });
    assert.equal(r.durum, 401, `deneme ${i + 1}`);
  }
  const giris = await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5350009001', password: 'x' }, basliklar: xff(sahte(77), GERCEK) });
  assert.equal(giris.durum, 429);
});

test('C3 · OTP (saatte 20): farklı numara + farklı sahte değerle 21. istek 429', async () => {
  config.guvenilirProxySayisi = 1;
  for (let i = 0; i < 20; i++) {
    const tel = `53600${String(i).padStart(5, '0')}`;
    const r = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: tel, purpose: 'REGISTER' }, basliklar: xff(sahte(i), GERCEK) });
    assert.equal(r.durum, 204, `deneme ${i + 1}: ${JSON.stringify(r.json)}`);
  }
  const son = await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: '5360099999', purpose: 'REGISTER' }, basliklar: xff(sahte(55), GERCEK) });
  assert.equal(son.durum, 429);
});

test('C4 · admin girişi ve MFA (15 dk / 10): sahte değerle 11. istek 429', async () => {
  config.guvenilirProxySayisi = 1;
  for (let i = 0; i < 10; i++) {
    const r = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'yok@hc.test', password: 'yanlis' }, basliklar: xff(sahte(i), GERCEK) });
    assert.equal(r.durum, 401, `giriş ${i + 1}`);
  }
  assert.equal((await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: 'yok@hc.test', password: 'yanlis' }, basliklar: xff(sahte(60), GERCEK) })).durum, 429);
  for (let i = 0; i < 10; i++) {
    const r = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: '000000' }, basliklar: xff(sahte(i), GERCEK) });
    assert.equal(r.durum, 401, `mfa ${i + 1}`);
  }
  assert.equal((await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: '000000' }, basliklar: xff(sahte(61), GERCEK) })).durum, 429);
});

async function adminGirisi(basliklar) {
  const g = await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: ADMIN, password: SIFRE }, basliklar });
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  const m = await istek('/admin/v1/auth/mfa', { yontem: 'POST', govde: { code: totpUret(ADMIN_SIR) }, cerez: g.cerez, basliklar });
  assert.equal(m.durum, 200, JSON.stringify(m.json));
  return g.cerez;
}

test('C5 · admin yeniden doğrulama (15 dk / 10): sahte değerle 11. istek 429', async () => {
  config.guvenilirProxySayisi = 1;
  const cerez = await adminGirisi(xff(sahte(0), GERCEK));
  const dogru = totpUret(ADMIN_SIR);
  const yanlis = dogru === '000000' ? '111111' : '000000';
  for (let i = 0; i < 10; i++) {
    const r = await istek('/admin/v1/auth/reauth', { yontem: 'POST', govde: { code: yanlis }, cerez, basliklar: xff(sahte(i), GERCEK) });
    assert.equal(r.durum, 401, `yeniden doğrulama ${i + 1}`);
  }
  assert.equal((await istek('/admin/v1/auth/reauth', { yontem: 'POST', govde: { code: yanlis }, cerez, basliklar: xff(sahte(62), GERCEK) })).durum, 429);
});

test('C6 · hop 0: başlıktaki değerler ne olursa olsun tek soket sayacı (127.0.0.1)', async () => {
  config.guvenilirProxySayisi = 0;
  for (let i = 0; i < 30; i++) {
    await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5350009001', password: 'x' }, basliklar: xff(`198.51.100.${i + 10}`) });
  }
  assert.equal((await istek('/api/v1/auth/login', { yontem: 'POST', govde: { phone: '5350009001', password: 'x' }, basliklar: xff('198.51.100.200') })).durum, 429);
  const anahtarlar = (await db.prepare('SELECT key FROM rate_limits').all()).map((x) => x.key);
  assert.deepEqual(anahtarlar.filter((k) => k.startsWith('giris_ip:')), ['giris_ip:127.0.0.1']);
});

// ═════ D. Oturum IP'si ve denetim kayıtları tutarlı ═════
test('D1 · kayıt, giriş, yenileme ve Firebase oturumu AYNI gerçek IP\'yi yazar', async () => {
  config.guvenilirProxySayisi = 1;
  const tel = '5370001234';
  const b = xff(sahte(3), GERCEK);
  const k = await istek('/api/v1/auth/register', { yontem: 'POST', basliklar: b, govde: { termsAccepted: true, ageConfirmed: true, phone: tel, password: 'sifre1234', name: 'Ip Kişi', email: 'ip@ornek.com', role: 'CUSTOMER', firebaseIdToken: idToken({ sub: 'ip-uid-1', phone_number: `+90${tel}` }) } });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', basliklar: xff(sahte(4), GERCEK), govde: { phone: tel, password: 'sifre1234' } });
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  const y = await istek('/api/v1/auth/refresh', { yontem: 'POST', basliklar: xff(sahte(5), GERCEK), govde: { refreshToken: g.json.refreshToken } });
  assert.equal(y.durum, 200, JSON.stringify(y.json));
  const f = await istek('/api/v1/auth/firebase/session', { yontem: 'POST', basliklar: xff(sahte(6), GERCEK), govde: { idToken: idToken({ sub: 'ip-uid-1', phone_number: `+90${tel}` }) } });
  assert.equal(f.durum, 200, JSON.stringify(f.json));
  const u = await db.prepare('SELECT id FROM users WHERE phone = ?').get(tel);
  const ipler = (await db.prepare('SELECT ip FROM user_sessions WHERE user_id = ?').all(u.id)).map((x) => x.ip);
  assert.equal(ipler.length, 4, 'kayıt + giriş + yenileme + Firebase oturumu');
  assert.deepEqual([...new Set(ipler)], [GERCEK]);
});

test('D2 · admin oturumu, giriş/başarısız giriş/işlem denetim kayıtları ve denetim API\'si AYNI IP', async () => {
  config.guvenilirProxySayisi = 1;
  const b = xff(sahte(8), GERCEK);
  const once = (await db.prepare('SELECT COALESCE(MAX(id), 0) n FROM audit_log').get()).n;
  // Başarısız giriş (mevcut hesap, yanlış şifre) → auth.login_failed
  assert.equal((await istek('/admin/v1/auth/login', { yontem: 'POST', govde: { email: ADMIN, password: 'yanlis-sifre' }, basliklar: b })).durum, 401);
  const cerez = await adminGirisi(xff(sahte(9), GERCEK));
  // Örnek bir admin işlemi → user.view
  const u = await db.prepare('SELECT id FROM users LIMIT 1').get();
  assert.ok(u, 'en az bir kullanıcı olmalı (D1)');
  assert.equal((await istek(`/admin/v1/users/${u.id}`, { cerez, basliklar: xff(sahte(10), GERCEK) })).durum, 200);
  const satirlar = await db.prepare('SELECT action, ip FROM audit_log WHERE id > ? ORDER BY id').all(once);
  const islemler = satirlar.map((x) => x.action);
  for (const beklenen of ['auth.login_failed', 'auth.login', 'user.view']) assert.ok(islemler.includes(beklenen), islemler.join());
  assert.deepEqual([...new Set(satirlar.map((x) => x.ip))], [GERCEK]);
  const oturumlar = await db.prepare(`SELECT s.ip FROM admin_sessions s JOIN admins a ON a.id = s.admin_id WHERE a.email = ?`).all(ADMIN);
  assert.ok(oturumlar.length >= 1);
  assert.deepEqual([...new Set(oturumlar.map((x) => x.ip))], [GERCEK]);
  // Denetim API'si de aynı değeri döndürür.
  const kayit = await istek('/admin/v1/audit-log?limit=20', { cerez, basliklar: xff(sahte(11), GERCEK) });
  assert.equal(kayit.durum, 200);
  const api = kayit.json.filter((x) => ['auth.login_failed', 'auth.login', 'user.view'].includes(x.action)).map((x) => x.ip);
  assert.ok(api.length >= 3);
  assert.deepEqual([...new Set(api)], [GERCEK]);
});

test('D3 · hop 0: oturum ve denetim kayıtlarına soket adresi yazılır (başlık yok sayılır)', async () => {
  config.guvenilirProxySayisi = 0;
  const once = (await db.prepare('SELECT COALESCE(MAX(id), 0) n FROM audit_log').get()).n;
  const g = await istek('/api/v1/auth/login', { yontem: 'POST', basliklar: xff(GERCEK), govde: { phone: '5370001234', password: 'sifre1234' } });
  assert.equal(g.durum, 200, JSON.stringify(g.json));
  const u = await db.prepare('SELECT id FROM users WHERE phone = ?').get('5370001234');
  const s = await db.prepare('SELECT ip FROM user_sessions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(u.id);
  assert.equal(s.ip, '127.0.0.1');
  await adminGirisi(xff(GERCEK));
  const satirlar = await db.prepare('SELECT ip FROM audit_log WHERE id > ?').all(once);
  assert.ok(satirlar.length >= 1);
  assert.deepEqual([...new Set(satirlar.map((x) => x.ip))], ['127.0.0.1']);
});

// ═════ E. Kaynak taraması ═════
test('E1 · backend/src içinde http.js dışında soket adresi ya da X-Forwarded-For okunmaz', () => {
  const kok = new URL('../src/', import.meta.url).pathname;
  const dosyalar = [];
  const gez = (d) => {
    for (const a of readdirSync(d)) {
      const y = join(d, a);
      if (statSync(y).isDirectory()) gez(y);
      else if (y.endsWith('.js')) dosyalar.push(y);
    }
  };
  gez(kok);
  // ⚠ Yorum satırları elenir: açıklamada başlığın adının geçmesi okuma değildir.
  const kod = (y) => readFileSync(y, 'utf8').split('\n')
    .filter((l) => !/^\s*(\/\/|\/?\*)/.test(l)).join('\n');
  const ihlal = dosyalar
    .filter((y) => !y.endsWith('/src/http.js'))
    .filter((y) => /remoteAddress|x-forwarded-for/i.test(kod(y)));
  assert.deepEqual(ihlal, []);
});
