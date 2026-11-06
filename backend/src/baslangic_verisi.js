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
import { gocDosyalari } from './db.js';

// ── YASAL METİNLER — YENİ KURULUM (5 Kas) ──
// Yasal göçler yalnız belge kaydı VARSA yazar; yeni kurulumda göçler belge
// kayıtlarından (bu aktarım) ÖNCE koştuğu için metinler yayımlanmıyordu.
// Belgeler bu aktarımla ilk kez oluştuysa güncel yasal göç bir kez daha
// çalıştırılır (sabit sürüm kimlikleriyle idempotent; panelden yayımlanmış
// sürümlere dokunmaz).
export const GUNCEL_YASAL_GOC = '053_yasal_yeni_surum';
// 6 Kas: 054 yalnız terms/kvkk/privacy'yi günceller; 053 (marketing, cookies)
// ÖNCE, ardından 054 sırayla çalışır.
export const GUNCEL_YASAL_GOCLER = [GUNCEL_YASAL_GOC, '054_yasal_sistem_uyumu'];

/** @returns {Promise<object|null>} aktarılan satır sayıları; kapalıysa/kilit başkasındaysa null */
export async function baslangicVerisiniHazirla(db, env = process.env) {
  if (env.HC_OTOMATIK_TOHUM === 'false') return null;
  return db.isKilidi('is:baslangic_verisi', async () => {
    const s = await tohumla(db);
    if (s?.belge > 0) {
      for (const ad of GUNCEL_YASAL_GOCLER) {
        const goc = gocDosyalari(db.surucu).find((g) => g.id === ad);
        if (goc) await db.exec(goc.sql);
      }
    }
    return s;
  });
}
