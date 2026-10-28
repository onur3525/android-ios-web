// ═══════════════════════════════════════════════════════════════
// HERKESE AÇIK YANITLARIN KISA SÜRELİ ÖNBELLEĞİ (28 Eki, kullanıcı kararı)
//
// Kapsam (YALNIZ giriş istemeyen, herkese aynı veri):
//   katalog               → GET /api/v1/categories
//   bolgeler              → GET /api/v1/regions/tree
//   yasal:liste           → GET /api/v1/legal (yalnız YAYINDAKİ sürümler)
//   yasal:<slug>          → GET /api/v1/legal/:slug (yalnız YAYINDAKİ sürüm)
//   ayar:<platform>       → app_config SATIRI (android/ios/web). Bakımdaki
//                           kişiye özel alanlar (bypass, testerDevice) her
//                           istekte AYRICA hesaplanır, önbelleğe GİRMEZ.
// Kullanıcıya, oturuma ya da yöneticiye özel hiçbir veri buraya konmaz.
//
// Kurallar:
//   · Süre (TTL) 60 sn. Süre dolunca ilk istek veritabanından yeniler.
//   · TEK UÇUŞ: aynı anahtar için aynı anda gelen istekler TEK sorguyu
//     bekler (süre dolduğunda veritabanına yüzlerce eşzamanlı sorgu gitmez).
//   · GEÇERSİZ KILMA: admin API'sinde değişiklik yapan (GET dışı) her
//     istek bitince önbellek BÜTÜNÜYLE temizlenir ve olay yoluyla
//     (PostgreSQL LISTEN/NOTIFY) BÜTÜN sunucu örneklerine duyurulur.
//     Admin değişiklikleri seyrektir; tümünü temizlemek, hangi yolun hangi
//     tabloyu değiştirdiğini tek tek eşlemekten güvenlidir (unutulan yol yok).
//     Olay yolu koparsa üst sınır yine 60 sn'dir.
//   · NESİL: temizlikten ÖNCE başlamış bir okuma, temizlikten SONRA bitse
//     bile sonucunu önbelleğe YAZMAZ (eski veri 60 sn takılı kalmaz).
//   · HATA: yenileme başarısızsa ve elde en çok BAYAT_AZAMI_MS yaşında veri
//     varsa o veri döner (veritabanı kısa süre erişilemezken katalog açık
//     kalır); yoksa hata aynen yukarı iletilir (önceki davranış).
//     Temizlenen (admin değişikliği) veri bayat olarak da SUNULMAZ.
//   · BELLEK: anahtar sayısı sabit ve küçüktür (≈ 4 + yasal belge sayısı +
//     3 platform); güvenlik için en çok AZAMI_ANAHTAR tutulur. Bulunamayan
//     (404) yasal belge önbelleğe alınmaz.
//   · Önbellekteki nesneler DONDURULUR (Object.freeze): paylaşılan nesne
//     yanlışlıkla değiştirilemez.
// ═══════════════════════════════════════════════════════════════
import { olaylar } from './olaylar.js';

export const ONBELLEK_TTL_MS = 60_000;
const BAYAT_AZAMI_MS = 5 * 60_000;
const AZAMI_ANAHTAR = 64;
const OLAY = 'genel_onbellek_temizle';

const kayitlar = new Map(); // anahtar → { deger, zaman }
const ucuslar = new Map(); // anahtar → { nesil, soz }
let nesil = 0;
const sayac = { isabet: 0, iskalama: 0, bayat: 0, temizlik: 0 };

function dondur(x) {
  if (x !== null && typeof x === 'object' && !Object.isFrozen(x)) {
    Object.freeze(x);
    for (const v of Object.values(x)) dondur(v);
  }
  return x;
}

/**
 * Anahtarın değerini döner; yoksa / süresi dolmuşsa `yukle()` ile (tek
 * uçuşla) yeniler. `yukle()` undefined dönerse sonuç önbelleğe ALINMAZ.
 */
export async function onbellekten(anahtar, yukle) {
  const k = kayitlar.get(anahtar);
  if (k && Date.now() - k.zaman < ONBELLEK_TTL_MS) { sayac.isabet += 1; return k.deger; }
  const ucus = ucuslar.get(anahtar);
  if (ucus && ucus.nesil === nesil) return ucus.soz;
  sayac.iskalama += 1;
  const basNesil = nesil;
  const yeni = { nesil: basNesil, soz: null };
  ucuslar.set(anahtar, yeni);
  yeni.soz = (async () => {
    try {
      const deger = await yukle();
      if (deger !== undefined && basNesil === nesil) {
        if (!kayitlar.has(anahtar) && kayitlar.size >= AZAMI_ANAHTAR) kayitlar.delete(kayitlar.keys().next().value);
        kayitlar.set(anahtar, { deger: dondur(deger), zaman: Date.now() });
      }
      return deger;
    } catch (e) {
      const eski = kayitlar.get(anahtar);
      if (eski && basNesil === nesil && Date.now() - eski.zaman < BAYAT_AZAMI_MS) {
        sayac.bayat += 1;
        return eski.deger;
      }
      throw e;
    } finally {
      if (ucuslar.get(anahtar) === yeni) ucuslar.delete(anahtar);
    }
  })();
  return yeni.soz;
}

/** Bu örnekteki önbelleği hemen temizler (yürüyen okumalar sonucu yazmaz). */
export function onbellekTemizle() {
  nesil += 1;
  kayitlar.clear();
  ucuslar.clear();
  sayac.temizlik += 1;
}

/**
 * Bu örnekte HEMEN (eşzamanlı) + BÜTÜN örneklerde (olay yolu, beklenmez)
 * temizler. Hata fırlatmaz; isteği yavaşlatmaz. Olay yolu ulaşmazsa diğer
 * örnekler en geç ONBELLEK_TTL_MS içinde yeniler.
 */
export function onbellegiHerYerdeTemizle() {
  onbellekTemizle();
  Promise.resolve()
    .then(() => olaylar.yayinla(OLAY, {}))
    .catch((e) => console.error('genel_onbellek', e?.message));
}

// Başka örnekten (ya da kendimizden, NOTIFY ile COMMIT sonrası) gelen duyuru.
olaylar.on(OLAY, () => onbellekTemizle());

/** Teşhis/test: sayaçlar ve anahtar sayısı. */
export function onbellekDurumu() {
  return { ...sayac, anahtar: kayitlar.size };
}
