// ═══════════════════════════════════════════════════════════════
// BAKIM MODU — UYGULAMA API'Sİ KAPISI (22 Eki, kullanıcı kararı)
//
// Bakım (Duyurular › Bakım modu) açıkken kullanıcı API'si (/api/v1) 503
// "MAINTENANCE" döner; uygulama bunu görünce bakım ekranını açar. Bakım
// bilgisini veren uç (/api/v1/config/app) ve yasal metinler açık kalır.
// Admin paneli (/admin) etkilenmez.
//
// Her istekte veritabanına gidilmesin diye kısa süreli önbellek: başka
// sunucu örneğindeki değişiklik en geç ÖNBELLEK_MS içinde görülür; bu
// örnekteki değişiklik önbelleği hemen temizler.
// ═══════════════════════════════════════════════════════════════
import { createHash, randomUUID } from 'node:crypto';
import { ApiHatasi } from './http.js';
import { jwtDogrula } from './jwt.js';

const ONBELLEK_MS = 5000;
let onbellek = null; // { zaman, aktif, mesaj }

export function bakimOnbellegiTemizle() { onbellek = null; }

/** Bakım açık mı? Okunamazsa (veritabanı hatası) bakım SAYILMAZ. */
export async function bakimDurumu(db) {
  if (onbellek && Date.now() - onbellek.zaman < ONBELLEK_MS) return onbellek;
  try {
    const r = await db.prepare('SELECT maintenance_message FROM app_config WHERE maintenance_active = TRUE ORDER BY platform LIMIT 1').get();
    onbellek = { zaman: Date.now(), aktif: !!r, mesaj: r?.maintenance_message ?? null };
  } catch {
    onbellek = { zaman: Date.now(), aktif: false, mesaj: null };
  }
  return onbellek;
}

/** Bakımda da açık kalan kullanıcı uçları. */
export function bakimdaAcikMi(yol) {
  return yol === '/api/v1/config/app' || yol === '/api/v1/legal' || yol.startsWith('/api/v1/legal/');
}

// ── BAKIMDA TEST HESABI (032, 22 Eki, kullanıcı kararı) ──
// Admin'in "Bakımda erişebilecek hesaplar" listesine eklediği kullanıcı
// (users.maintenance_bypass) bakımda da şifreyle giriş yapar ve uygulamayı
// kullanır — YALNIZ önceden tanınmış cihazından (maintenance_devices).
//
// Cihaz tanıma: uygulama her cihazda bir kez rastgele cihaz kimliği üretir
// ve her istekte `X-HC-Cihaz` başlığıyla gönderir. Listedeki hesap bakım
// KAPALIYKEN o cihazda giriş yapınca / oturumu yenilenince cihaz otomatik
// kaydedilir (yalnız özeti). Bakım açıkken yeni cihaz TANITILAMAZ.
// Kararlar yalnız sunucuda verilir; cihaz tek başına kimseyi içeri almaz
// (şifre + listedeki hesap + tanınmış cihaz birlikte gerekir).

/** Bakımda kapıdan geçip içeride hesaba göre karar verilen giriş uçları. */
export const BAKIMDA_GIRIS_YOLLARI = new Set([
  '/api/v1/auth/login', '/api/v1/auth/refresh', '/api/v1/auth/firebase/session',
]);

const CIHAZ_KALIBI = /^[A-Za-z0-9_-]{32,128}$/;
const PLATFORMLAR = new Set(['android', 'ios', 'web']);

/** İstekteki cihaz kimliğinin özeti; başlık yok/bozuksa null. */
export function cihazOzeti(req) {
  const c = String(req.headers['x-hc-cihaz'] ?? '');
  return CIHAZ_KALIBI.test(c) ? createHash('sha256').update(c).digest('hex') : null;
}

async function taninmisCihazMi(db, kullaniciId, ozet) {
  if (!ozet) return false;
  return !!(await db.prepare('SELECT 1 FROM maintenance_devices WHERE user_id = ? AND device_hash = ?').get(kullaniciId, ozet));
}

/**
 * Bakım kapalıyken listedeki hesabın cihazını kaydeder (varsa son görülmeyi
 * günceller). Bakım açıkken yalnız günceller; yeni cihaz eklemez.
 */
export async function cihaziTani(db, u, req) {
  if (u?.maintenance_bypass !== 1) return;
  const ozet = cihazOzeti(req);
  if (!ozet) return;
  const z = new Date().toISOString();
  const guncellendi = await db.prepare('UPDATE maintenance_devices SET last_seen_at = ? WHERE user_id = ? AND device_hash = ?')
    .run(z, u.id, ozet);
  if (guncellendi.changes > 0 || (await bakimDurumu(db)).aktif) return;
  const p = String(req.headers['x-hc-platform'] ?? '');
  await db.prepare(
    `INSERT INTO maintenance_devices (id, user_id, device_hash, platform, created_at, last_seen_at)
     VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT (user_id, device_hash) DO NOTHING`,
  ).run(randomUUID(), u.id, ozet, PLATFORMLAR.has(p) ? p : 'bilinmiyor', z, z);
}

/**
 * İstek, bakımda erişebilen bir hesabın açık oturumuyla VE o hesabın
 * tanınmış cihazından mı geliyor?
 *
 * Erişim jetonunun 15 dk'lık süresi dolmuş olabilir: imza doğruysa ve
 * oturum iptal edilmemiş/bitmemişse hesap yine tanınır. Böylece istek
 * uca ulaşır, uç 401 döner ve uygulama oturumu yeniler (yenileme de yalnız
 * test hesabına izin verir). Aksi hâlde test hesabı süre dolunca bakım
 * ekranına düşerdi. Askı/ban/dondurma/silinme her istekte denetlenir.
 */
export async function bakimIstisnasiMi(db, req) {
  const b = String(req.headers.authorization ?? '');
  if (!b.startsWith('Bearer ')) return false;
  const yuk = jwtDogrula(b.slice(7), { sureyiYoksay: true });
  if (!yuk) return false;
  try {
    const o = await db.prepare('SELECT user_id, revoked_at, expires_at FROM user_sessions WHERE id = ?').get(yuk.jti);
    if (!o || o.revoked_at || o.user_id !== yuk.sub || Date.parse(o.expires_at) < Date.now()) return false;
    const u = await db.prepare('SELECT status, frozen_at, maintenance_bypass FROM users WHERE id = ? AND deleted_at IS NULL').get(yuk.sub);
    if (!u || u.status !== 'ACTIVE' || u.frozen_at || u.maintenance_bypass !== 1) return false;
    return await taninmisCihazMi(db, yuk.sub, cihazOzeti(req));
  } catch {
    return false;
  }
}

/**
 * Bu cihaz, listedeki (etkin) bir hesabın tanınmış cihazı mı? Bakım
 * ekranındaki gizli giriş kapısı YALNIZ bu durumda açılır.
 */
export async function testCihaziMi(db, req) {
  const ozet = cihazOzeti(req);
  if (!ozet) return false;
  try {
    return !!(await db.prepare(
      `SELECT 1 FROM maintenance_devices d JOIN users u ON u.id = d.user_id
        WHERE d.device_hash = ? AND u.maintenance_bypass = TRUE AND u.status = 'ACTIVE'
          AND u.deleted_at IS NULL AND u.frozen_at IS NULL LIMIT 1`,
    ).get(ozet));
  } catch {
    return false;
  }
}

/**
 * Giriş uçlarında: bakım açıksa yalnız listedeki hesaba, tanınmış
 * cihazından oturum verilir. Bakım kapalıysa listedeki hesabın cihazı
 * tanınır (kaydedilir).
 */
export async function bakimGirisKapisi(db, u, req) {
  const b = await bakimDurumu(db);
  if (b.aktif && !(u?.maintenance_bypass === 1 && await taninmisCihazMi(db, u.id, cihazOzeti(req)))) {
    throw new ApiHatasi(503, 'MAINTENANCE', b.mesaj || 'Bakım çalışması sürüyor');
  }
  await cihaziTani(db, u, req);
}
