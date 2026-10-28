// ═══════════════════════════════════════════════════════════════
// ANLIK HABER — uygulama içi bildirim oluşunca açık uygulamaya haber
// (28 Eki, kullanıcı kararı: "Ekran 30 saniyede bir yenilenmesin; yeni
// teklif veya ilan gelince yenilensin.")
//
// Her uygulama içi bildirim (yeni ilan, yeni teklif, teklif seçildi,
// talep, mesaj, süre doldu, duyuru) `uygulamaIciBildir`den geçer; işlem
// KAYDEDİLDİKTEN sonra buraya düşer. Haber yalnız KİMİN ve HANGİ TÜR
// olduğunu taşır (içerik yok); uygulama ilgili veriyi kendisi yeniden alır.
//
// Toplu bildirimde (duyuru, yeni ilan → 1000'e kadar hizmet veren) her
// alıcı için ayrı veritabanı olayı yayınlamamak için kısa sürede biriken
// haberler tekilleştirilip PAKETLER hâlinde yayınlanır (PG NOTIFY yük
// sınırı ~8 KB → paket başına en çok 100 alıcı). Çok örnekli kurulumda her
// örnek kendi soketlerine iletir (gercek_zamanli.js).
// ═══════════════════════════════════════════════════════════════
import { olaylar } from './olaylar.js';

export const ANLIK_HABER_KANALI = 'notification.new';
const PAKET = 100;
const BEKLEME_MS = 30;

let bekleyen = [];
let zamanlayici = null;

/** İşlem kaydedildikten sonra çağrılır (commitSonrasi). */
export function anlikHaberEkle(kullaniciId, tur) {
  bekleyen.push([String(kullaniciId), String(tur)]);
  if (!zamanlayici) {
    zamanlayici = setTimeout(() => { anlikHaberleriYayinla().catch(() => {}); }, BEKLEME_MS);
    zamanlayici.unref?.();
  }
}

/** Biriken haberleri tekilleştirip paketler hâlinde yayınlar. */
export async function anlikHaberleriYayinla() {
  clearTimeout(zamanlayici);
  zamanlayici = null;
  const liste = bekleyen;
  bekleyen = [];
  const tekil = [...new Map(liste.map((x) => [`${x[0]}|${x[1]}`, x])).values()];
  for (let i = 0; i < tekil.length; i += PAKET) {
    // Haber kaybolursa uygulama öne gelince/yeniden bağlanınca zaten yeniler.
    await olaylar.yayinla(ANLIK_HABER_KANALI, { h: tekil.slice(i, i + PAKET) }).catch(() => {});
  }
}
