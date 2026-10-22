// ═══════════════════════════════════════════════════════════════
// ADMİN KİMLİĞİ — şifre (scrypt), TOTP (RFC 6238), oturum, RBAC
//
// Admin hesapları kullanıcı hesaplarından TAMAMEN AYRI tablodadır;
// kullanıcı token'ı admin API'sinde hiçbir anlam taşımaz.
//
// Oturum: rastgele 32 bayt → yalnız SHA-256 özeti veritabanında;
// çerez HttpOnly + SameSite=Strict (+ üretimde Secure). İki aşama:
//   'mfa'  — şifre doğru, TOTP bekleniyor (yalnız /auth/mfa çağrılabilir)
//   'full' — tam oturum
// Hareketsizlikte düşer (config.adminOturumBosta), mutlak 8 saatte biter.
// ⚠ HER DEĞİŞİKLİK (GET dışı her admin isteği) mevcut şifre + TOTP ile
// yeniden doğrulama ister (22 Eki, kullanıcı kuralı: açık kalmış ekranda
// kimse değişiklik yapamasın; izleme/görüntüleme serbest). Doğrulama TEK
// KULLANIMLIKTIR: yalnız ardından gelen ilk değişikliği açar ve kısa
// sürede (config.yenidenDogrulamaSuresi) kullanılmazsa geçersizleşir.
// ═══════════════════════════════════════════════════════════════
import {
  createCipheriv, createDecipheriv, createHash, createHmac,
  randomBytes, scrypt, scryptSync, timingSafeEqual,
} from 'node:crypto';
import { config } from './config.js';
import { simdi } from './db.js';
import { hata, istemciIp } from './http.js';

// ── Şifre ─────────────────────────────────────────────────────
const SCRYPT = { N: 1 << 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

export function sifreOzetle(sifre) {
  const tuz = randomBytes(16);
  const ozet = scryptSync(sifre, tuz, 64, SCRYPT);
  return `scrypt$${tuz.toString('base64')}$${ozet.toString('base64')}`;
}

// ── ASENKRON SÜRÜMLER — İSTEK YOLLARINDA BUNLAR KULLANILIR ──
//
// scrypt (N=2^15) tek çağrıda ~100 ms CPU harcar. Eşzamanlı (`scryptSync`)
// çağrı bu süre boyunca Node olay döngüsünü KİLİTLER: o örnekteki BÜTÜN
// istekler, WebSocket'ler ve zamanlayıcılar bekler. Saniyede ~10 giriş bile
// bir örneği doyururdu. Asenkron `scrypt` hesabı libuv iş parçacığı havuzuna
// taşır (UV_THREADPOOL_SIZE, varsayılan 4). Sonuç ve biçim AYNIDIR.
// Eşzamanlı sürümler yalnız betikler (create_admin) ve testler içindir.
const scryptP = (sifre, tuz, uzunluk) => new Promise((coz, reddet) => {
  scrypt(sifre, tuz, uzunluk, SCRYPT, (e, ozet) => (e ? reddet(e) : coz(ozet)));
});

export async function sifreOzetleAsenkron(sifre) {
  const tuz = randomBytes(16);
  const ozet = await scryptP(sifre, tuz, 64);
  return `scrypt$${tuz.toString('base64')}$${ozet.toString('base64')}`;
}

export async function sifreDogrulaAsenkron(sifre, kayit) {
  const [tur, tuzB64, ozetB64] = String(kayit).split('$');
  if (tur !== 'scrypt' || !tuzB64 || !ozetB64) return false;
  const beklenen = Buffer.from(ozetB64, 'base64');
  const ozet = await scryptP(sifre, Buffer.from(tuzB64, 'base64'), beklenen.length);
  return timingSafeEqual(ozet, beklenen);
}

export function sifreDogrula(sifre, kayit) {
  const [tur, tuzB64, ozetB64] = String(kayit).split('$');
  if (tur !== 'scrypt' || !tuzB64 || !ozetB64) return false;
  const beklenen = Buffer.from(ozetB64, 'base64');
  const ozet = scryptSync(sifre, Buffer.from(tuzB64, 'base64'), beklenen.length, SCRYPT);
  return timingSafeEqual(ozet, beklenen);
}

/** Admin şifre kuralı: en az 12 karakter, harf ve rakam. */
export function sifreKurali(sifre) {
  if (typeof sifre !== 'string' || sifre.length < 12 || sifre.length > 128) {
    return 'Şifre 12-128 karakter olmalıdır';
  }
  if (!/[A-Za-zÇĞİÖŞÜçğıöşü]/.test(sifre) || !/\d/.test(sifre)) {
    return 'Şifre harf ve rakam içermelidir';
  }
  return null;
}

// ── Sır şifreleme (AES-256-GCM, ana anahtar) ─────────────────
export function sirSifrele(duz) {
  const iv = randomBytes(12);
  const c = createCipheriv('aes-256-gcm', config.anaAnahtar, iv);
  const icerik = Buffer.concat([c.update(String(duz), 'utf8'), c.final()]);
  return `v1.${iv.toString('base64')}.${c.getAuthTag().toString('base64')}.${icerik.toString('base64')}`;
}

/**
 * ── ANA ANAHTAR PARMAK İZİ (16 Eki) ──
 * Ana anahtarın (HC_MASTER_KEY) kendisini değil, anahtarla üretilmiş tek
 * yönlü bir HMAC'in ilk 16 hanesini verir. Amaç: sunucu dışında çalışan
 * bakım aracının (GitHub Actions — admin MFA yenileme) kullandığı anahtarın
 * canlı sunucununkiyle AYNI olduğunu doğrulamak; aksi hâlde yeni sır yine
 * çözülemeyen bir anahtarla yazılırdı. Parmak izinden anahtar elde edilemez.
 */
export function anahtarParmakIzi(anahtar = config.anaAnahtar) {
  return createHmac('sha256', anahtar).update('hizmetcep-ana-anahtar-parmak-izi-v1').digest('hex').slice(0, 16);
}

export function sirCoz(kayit) {
  const [s, iv, etiket, icerik] = String(kayit).split('.');
  if (s !== 'v1') throw new Error('Bilinmeyen sır biçimi');
  const d = createDecipheriv('aes-256-gcm', config.anaAnahtar, Buffer.from(iv, 'base64'));
  d.setAuthTag(Buffer.from(etiket, 'base64'));
  return Buffer.concat([d.update(Buffer.from(icerik, 'base64')), d.final()]).toString('utf8');
}

// ── TOTP (RFC 6238 · SHA-1 · 30 sn · 6 hane) ─────────────────
const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Uret(bayt = 20) {
  const b = randomBytes(bayt);
  let bitler = '';
  for (const x of b) bitler += x.toString(2).padStart(8, '0');
  let out = '';
  for (let i = 0; i + 5 <= bitler.length; i += 5) out += B32[parseInt(bitler.slice(i, i + 5), 2)];
  return out;
}

function base32Coz(s) {
  let bitler = '';
  for (const ch of s.replace(/=+$/, '').toUpperCase()) {
    const i = B32.indexOf(ch);
    if (i < 0) throw new Error('Geçersiz base32');
    bitler += i.toString(2).padStart(5, '0');
  }
  const out = [];
  for (let i = 0; i + 8 <= bitler.length; i += 8) out.push(parseInt(bitler.slice(i, i + 8), 2));
  return Buffer.from(out);
}

export function totpUret(sir, zamanMs = Date.now()) {
  const sayac = Math.floor(zamanMs / 30000);
  const b = Buffer.alloc(8);
  b.writeBigUInt64BE(BigInt(sayac));
  const h = createHmac('sha1', base32Coz(sir)).update(b).digest();
  const o = h[h.length - 1] & 0x0f;
  const kod = ((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).toString().padStart(6, '0');
  return kod;
}

/** ±1 adım (30 sn) saat kayması toleransı. */
export function totpDogrula(sir, kod, zamanMs = Date.now()) {
  if (!/^\d{6}$/.test(String(kod))) return false;
  for (const kayma of [-1, 0, 1]) {
    const beklenen = Buffer.from(totpUret(sir, zamanMs + kayma * 30000));
    if (timingSafeEqual(beklenen, Buffer.from(String(kod)))) return true;
  }
  return false;
}

// ── RBAC ─────────────────────────────────────────────────────
export const ROLLER = ['super_admin', 'moderator', 'content', 'operations', 'readonly'];

const YETKI = {
  'users.read': ['super_admin', 'moderator', 'readonly'],
  'users.contact.read': ['super_admin', 'moderator'],
  'users.status.write': ['super_admin', 'moderator'],
  'content.read': ['super_admin', 'moderator', 'readonly'],
  'messages.read': ['super_admin', 'moderator'],
  'listings.remove': ['super_admin', 'moderator'],
  'reviews.remove': ['super_admin', 'moderator'],
  'catalog.read': ['super_admin', 'content', 'moderator', 'operations', 'readonly'],
  'catalog.write': ['super_admin', 'content'],
  'regions.read': ['super_admin', 'content', 'moderator', 'operations', 'readonly'],
  'regions.write': ['super_admin', 'content'],
  'legal.read': ['super_admin', 'content', 'readonly'],
  'legal.write': ['super_admin', 'content'],
  'support.write': ['super_admin', 'content'],
  'config.read': ['super_admin', 'operations', 'readonly'],
  'config.write': ['super_admin', 'operations'],
  'announcements.write': ['super_admin', 'content'],
  'notifications.read': ['super_admin', 'moderator', 'operations'],
  'integrations.read': ['super_admin', 'operations'],
  'integrations.write': ['super_admin', 'operations'],
  'integrations.secret': ['super_admin'],
  'feedback.read': ['super_admin', 'moderator', 'readonly'],
  // Gelen Talepler (kullanıcıların destek talepleri): okuma menüdeki
  // rollerle aynı; yanıt/kapatma yalnız kullanıcıyla yazışabilen roller.
  'support.tickets.read': ['super_admin', 'moderator', 'readonly'],
  'support.tickets.write': ['super_admin', 'moderator'],
  // Hesap silme kuyrukları (Firebase kaydı, dosyalar): teknik izleme ve
  // yeniden deneme. Kişisel veri göstermez (kimlikler özetlenmiş).
  'deletion.queues.read': ['super_admin', 'operations'],
  'deletion.queues.retry': ['super_admin', 'operations'],
  'admins.manage': ['super_admin'],
  'audit.read': ['super_admin'],
};

export function yetkiliMi(rol, yetki) {
  return (YETKI[yetki] || []).includes(rol);
}

export function yetkiIste(admin, yetki) {
  if (!admin || !yetkiliMi(admin.role, yetki)) throw hata.yetki();
}

// ── Oturum ───────────────────────────────────────────────────
export const OTURUM_CEREZI = 'hc_admin';
const ozetle = (t) => createHash('sha256').update(t).digest('hex');

export async function oturumAc(db, adminId, asama, req) {
  const token = randomBytes(32).toString('base64url');
  const z = simdi();
  await db.prepare(
    `INSERT INTO admin_sessions (token_hash, admin_id, stage, created_at, last_seen, ip, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(ozetle(token), adminId, asama, z, z, istemciIp(req),
    String(req.headers['user-agent'] || '').slice(0, 200));
  return token;
}

export async function oturumKapat(db, token) {
  if (token) await db.prepare('DELETE FROM admin_sessions WHERE token_hash = ?').run(ozetle(token));
}

export async function oturumYukselt(db, token) {
  const z = simdi();
  // ⚠ await ŞART: PostgreSQL sürücüsünde sorgu asenkron; beklenmezse
  // çerez yanıtla gider ama oturum henüz 'mfa' aşamasında kalabilir
  // (hemen gelen ilk istek 401 alır).
  // Giriş, değişiklik izni VERMEZ (reauth_at boş): ilk değişiklik de sorar.
  await db.prepare(`UPDATE admin_sessions SET stage = 'full', last_seen = ?, reauth_at = NULL WHERE token_hash = ?`)
    .run(z, ozetle(token));
}

export async function yenidenDogrulandi(db, token) {
  await db.prepare('UPDATE admin_sessions SET reauth_at = ? WHERE token_hash = ?').run(simdi(), ozetle(token));
}

/**
 * Tek kullanımlık yeniden doğrulamayı TÜKETİR (atomik). Son
 * config.yenidenDogrulamaSuresi içinde şifre + TOTP doğrulandıysa true
 * döner ve izin silinir; aynı izinle ikinci değişiklik yapılamaz
 * (eşzamanlı iki istekten yalnız biri geçer).
 */
export async function yenidenDogrulamayiTuket(db, token) {
  if (!token) return false;
  const sinir = new Date(Date.now() - config.yenidenDogrulamaSuresi).toISOString();
  const r = await db.prepare('UPDATE admin_sessions SET reauth_at = NULL WHERE token_hash = ? AND reauth_at IS NOT NULL AND reauth_at >= ?')
    .run(ozetle(token), sinir);
  return (r.changes ?? 0) === 1;
}

/** Yeniden doğrulama istenen hata (panel bunu görünce şifre + kod sorar). */
export function yenidenDogrulamaHatasi() {
  const e = hata.yetki('Bu değişiklik için şifrenizi ve doğrulama kodunuzu girin');
  e.kod = 'REAUTH_REQUIRED';
  return e;
}

/** Token → { admin, oturum } ya da null. Süresi dolanı siler. */
export async function oturumCoz(db, token, beklenenAsama = 'full') {
  if (!token) return null;
  const o = await db.prepare('SELECT * FROM admin_sessions WHERE token_hash = ?').get(ozetle(token));
  if (!o) return null;
  const an = Date.now();
  const bosta = an - Date.parse(o.last_seen) > config.adminOturumBosta;
  const mutlak = an - Date.parse(o.created_at) > config.adminOturumMutlak;
  if (bosta || mutlak || o.stage !== beklenenAsama) {
    if (bosta || mutlak) await oturumKapat(db, token);
    return null;
  }
  const admin = await db.prepare('SELECT * FROM admins WHERE id = ? AND active = TRUE').get(o.admin_id);
  if (!admin) return null;
  await db.prepare('UPDATE admin_sessions SET last_seen = ? WHERE token_hash = ?').run(simdi(), o.token_hash);
  return { admin, oturum: o };
}

/**
 * Kritik işlem: istek, tek kullanımlık şifre + TOTP doğrulamasıyla gelmiş
 * olmalı. (Asıl denetim server.js'te HER değişiklik için yapılır ve izni
 * tüketir; bu ikinci, rota içi güvencedir: oturum satırı izin tüketilmeden
 * ÖNCE okunduğundan reauth_at burada hâlâ doludur.)
 */
export function yenidenDogrulamaIste(oturum) {
  if (!oturum.reauth_at || Date.now() - Date.parse(oturum.reauth_at) > config.yenidenDogrulamaSuresi) {
    throw yenidenDogrulamaHatasi();
  }
}
