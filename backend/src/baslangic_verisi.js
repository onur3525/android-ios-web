// ═══════════════════════════════════════════════════════════════
// BAŞLANGIÇ VERİSİ — açılışta, BOŞ tablolar için otomatik aktarım
//
// Sorun (15 Eki): ilan açmak katalogda AKTİF bir hizmet ister
// (POST /api/v1/listings → "Geçerli bir hizmet seçiniz"). Katalog,
// bölge, yasal metin ve destek tabloları yalnız `npm run seed` ile
// doluyordu; canlı sunucuda bu komut çalıştırılmadıysa (ör. kabuk
// erişimi olmayan barındırma) bütün ilanlar reddedilir.
//
// Çözüm: sunucu açılırken MEVCUT aktarım (`scripts/seed_from_flutter.js`
// → `tohumla`) çağrılır. `tohumla` YALNIZ BOŞ tablolara yazar; admin'in
// sonradan yaptığı değişikliklerin üzerine yazmaz (idempotent). Çok
// örnekte danışma kilidiyle yalnız biri çalıştırır.
// ⚠ Veri DEMO DEĞİLDİR: uygulamanın kendi katalog/bölge/yasal dosyaları.
// Kapatmak için: HC_OTOMATIK_TOHUM=false.
// ═══════════════════════════════════════════════════════════════
import { tohumla } from '../scripts/seed_from_flutter.js';

/** @returns {Promise<object|null>} aktarılan satır sayıları; kapalıysa/kilit başkasındaysa null */
export async function baslangicVerisiniHazirla(db, env = process.env) {
  if (env.HC_OTOMATIK_TOHUM === 'false') return null;
  return db.isKilidi('is:baslangic_verisi', () => tohumla(db));
}
