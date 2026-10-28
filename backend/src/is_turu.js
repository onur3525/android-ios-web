// ═══════════════════════════════════════════════════════════════
// ARKA PLAN İŞ TURU — SINIRLI EŞZAMANLILIK (28 Eki, yük denetimi)
//
// Sorun: 60 sn'lik turda 12 iş AYNI ANDA başlıyordu. Her iş havuzdan bir
// bağlantıyı danışma kilidi için TUTUYOR, işin sorguları için ikinci bir
// bağlantı bekliyordu. Havuz 10 iken (1'i LISTEN) bütün bağlantılar kilit
// tutan işlerde kalıyor, hiçbiri ilerleyemiyordu → bağlantı zaman aşımına
// (10 sn) dek API dahil HER ŞEY bekliyordu. Yerel ölçüm: yük YOKKEN bile
// dakikada bir ~10 sn donma, işlerde "timeout exceeded" hataları.
//
// Çözüm: işler en çok `esZamanli` tane (varsayılan 2) aynı anda koşar.
// Kilit + iş sorgusu ≈ 2 bağlantı/iş → tur en çok ~4 bağlantı kullanır.
//
// ⚠ TAKILAN İŞ TURU KİLİTLEMEZ: bir iş `azamiBeklemeMs` içinde bitmezse
// yuvası bırakılır, sıradaki işler sürer (takılan iş arka planda devam
// eder; kendi danışma kilidi sonraki turda aynı işin ikinci kez
// başlamasını zaten engeller).
// ⚠ Bir işin hatası diğerlerini durdurmaz (`hata` geri çağrısına iletilir).
// ═══════════════════════════════════════════════════════════════

/**
 * @param isler [[ad, () => Promise], ...]
 * @param hata (ad, e) => void
 */
export async function isTuru(isler, hata, { esZamanli = 2, azamiBeklemeMs = 5 * 60_000 } = {}) {
  let sira = 0;
  const isci = async () => {
    while (sira < isler.length) {
      const [ad, f] = isler[sira++];
      let zamanlayici;
      const sinir = new Promise((ok) => { zamanlayici = setTimeout(ok, azamiBeklemeMs); zamanlayici.unref?.(); });
      const is = Promise.resolve().then(f).catch((e) => hata(ad, e));
      await Promise.race([is, sinir]);
      clearTimeout(zamanlayici);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, Math.min(esZamanli, isler.length)) }, isci));
}
