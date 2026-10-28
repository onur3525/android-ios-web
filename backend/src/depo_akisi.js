// ═══════════════════════════════════════════════════════════════
// DEPODAN İSTEMCİYE AKIŞ (28 Eki, yük/güvenlik denetimi)
//
// Sorun: katalog fotoğrafı (≤5 MB) ve yasal PDF (≤10 MB) uçları dosyanın
// TAMAMINI önce belleğe indiriyor (`arrayBuffer`), sonra gönderiyordu.
// Kimlik istemeyen bu uçlara eşzamanlı istekte süreç belleği yüzlerce
// MB'a çıkıyor, süreç çöküyordu (yerel ölçüm: 50 eşzamanlı PDF → 690 MB,
// çökme). Ayrıca indirme zaman aşımı yakalanmıyor, TEK yavaş indirme
// süreci kapatıyordu.
//
// Çözüm: içerik depodan parça parça okunup DOĞRUDAN istemciye akıtılır
// (geri basınç: istemci yavaşsa depodan okuma da yavaşlar; bellekte
// yalnız birkaç parça durur). Yanıt biçimi ve başlıklar AYNIDIR.
//
// Zaman aşımı İKİ AŞAMALI (önceden tek ve toplam süreydi):
//   · başlık: depo `baslikMs` içinde yanıt vermezse istek düşer (404);
//   · akış: içerik başladıktan sonra `bostaMs` boyunca HİÇ parça gelmezse
//     akış kesilir. Toplam süre sınırı YOK: yavaş mobil bağlantıda 10 MB
//     PDF yarıda kesilmesin.
// ⚠ Bu fonksiyon HATA FIRLATMAZ: başlık gönderildikten sonra hata olursa
// yanıt yarıda kapatılır (res.destroy); çağıranın hata yanıtı yazmaya
// çalışması (ERR_HTTP_HEADERS_SENT) süreci düşürürdü.
// ═══════════════════════════════════════════════════════════════
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { s3ImzaliAdres } from './entegrasyon.js';

/**
 * Depodaki nesneyi istemciye akıtır.
 * @param ayar depolama ayarı (depolamaAyari)
 * @param anahtar nesne anahtarı (çağıran doğrulamış olmalı)
 * @param res HTTP yanıtı
 * @param basliklar (depoYaniti) => yanıt başlıkları; null dönerse içerik reddedilir
 * @returns true: yanıt yazıldı (tam ya da yarıda kesildi); false: hiçbir şey yazılmadı (çağıran 404 döner)
 */
export async function depodanAkit(ayar, anahtar, res, basliklar, { baslikMs = 10_000, bostaMs = 30_000 } = {}) {
  const ac = new AbortController();
  let zamanlayici = setTimeout(() => ac.abort(), baslikMs);
  let r;
  try {
    r = await fetch(s3ImzaliAdres(ayar, { yontem: 'GET', anahtar, sureSn: 120 }), { signal: ac.signal });
  } catch {
    clearTimeout(zamanlayici);
    return false;
  }
  clearTimeout(zamanlayici);
  const ek = r.ok && r.body ? basliklar(r) : null;
  if (!ek) {
    r.body?.cancel().catch(() => {});
    return false;
  }
  const uzunluk = r.headers.get('content-length');
  res.writeHead(200, { ...ek, ...(uzunluk && /^\d{1,12}$/.test(uzunluk) ? { 'Content-Length': uzunluk } : {}) });
  const bekle = () => {
    clearTimeout(zamanlayici);
    zamanlayici = setTimeout(() => ac.abort(), bostaMs);
  };
  bekle();
  try {
    await pipeline(
      Readable.fromWeb(r.body),
      async function* (kaynak) {
        for await (const parca of kaynak) {
          bekle();
          yield parca;
        }
      },
      res,
    );
  } catch {
    // Depo koptu / boşta kaldı ya da istemci bağlantıyı kapattı:
    // başlık gitti, yanıt yarıda kapatılır. Süreç ETKİLENMEZ.
    if (!res.destroyed) res.destroy();
  } finally {
    clearTimeout(zamanlayici);
  }
  return true;
}
