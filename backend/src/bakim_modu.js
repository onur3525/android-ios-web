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
// kullanır. Ayrım YALNIZ sunucuda, oturumun ait olduğu hesaba bakılarak
// yapılır: gizli adres, başlık ya da anahtar yoktur.

/** Bakımda kapıdan geçip içeride hesaba göre karar verilen giriş uçları. */
export const BAKIMDA_GIRIS_YOLLARI = new Set([
  '/api/v1/auth/login', '/api/v1/auth/refresh', '/api/v1/auth/firebase/session',
]);

/**
 * İstek, bakımda erişebilen bir hesabın açık oturumuyla mı geliyor?
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
    return !!u && u.status === 'ACTIVE' && !u.frozen_at && u.maintenance_bypass === 1;
  } catch {
    return false;
  }
}

/** Giriş uçlarında: bakım açıksa yalnız listedeki hesaba oturum verilir. */
export async function bakimGirisKapisi(db, u) {
  const b = await bakimDurumu(db);
  if (b.aktif && u?.maintenance_bypass !== 1) {
    throw new ApiHatasi(503, 'MAINTENANCE', b.mesaj || 'Bakım çalışması sürüyor');
  }
}
