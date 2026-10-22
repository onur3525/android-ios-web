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
