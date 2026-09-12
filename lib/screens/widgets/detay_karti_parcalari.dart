import 'package:flutter/material.dart';

import '../../domain/hizmet_alan_ozeti.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import 'profil_avatari.dart';

/// ═══════════════════════════════════════════════════════════════
/// DETAY KARTI PARÇALARI — İKİ AKIŞ İÇİN TEK KAYNAK
///
/// ## NİÇİN ORTAK
///
/// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "İlan oluştururken görülen
/// ekran Bul ekranında da aynı düzende olmalı. Aynı butonlar, aynı
/// yerleşim, aynı assetler. Hizmet veren ilanı nereden oluşturursa
/// oluştursun aynı ekran yapısını görmeli."
///
/// Bu üç parça ilan akışının detay ekranında (`job_detail_screen`)
/// yazılmıştı ve `private` oldukları için Bul akışı onları GÖREMİYOR,
/// kendi benzerlerini yazıyordu. Sonuç: aynı bilgi iki ekranda
/// farklı ölçü, farklı ikon, farklı hizayla çiziliyordu.
///
/// ⚠ ARTIK İKİ EKRAN DA BURADAN OKUR. Biri değişirse öteki de değişir
/// — kopyalayıp uyarlamak YASAK.
/// ═══════════════════════════════════════════════════════════════

/// ── KARŞI TARAF ÖZETİ ──
///
/// Avatar + ad + tamamlanan iş + üyelik tarihi.
///
/// ⚠ KİMİN GÖSTERİLECEĞİNE ÇAĞIRAN KARAR VERİR: ilan akışında ilan
/// sahibi, Bul akışında talebi açan hizmet alan. Bileşen taraf
/// bilmez, yalnız çizer.
///
/// ⚠ [acik] KİMLİĞİN AÇIK OLUP OLMADIĞIDIR. Kapalıyken referansın
/// kilitli avatarı (`ic_avlock`) çizilir; ad yine görünür ama
/// maskelemeyi ÇAĞIRAN uygular — bu bileşen metni değiştirmez.

class SahipKarti extends StatelessWidget {
  const SahipKarti({
    required this.adSoyad,
    required this.acik,
    required this.tamamlananIs,
    this.fotoYolu = '',
    this.kayitTarihi,
  });

  final String adSoyad;
  final bool acik;
  final int tamamlananIs;

  /// ── ⚠ KARŞI TARAFIN PROFİL FOTOĞRAFI (12 Eyl, kullanıcı bulgusu) ──
  ///
  /// Kural: kimlik AÇILDIĞINDA (iletişim açıldı ya da teklif verildi)
  /// taraflar birbirinin fotoğrafını görebilmeli. Önceden yalnız baş
  /// harf çiziliyordu — fotoğraf yüklenmiş olsa bile.
  ///
  /// ⚠ [acik] FALSE İKEN HİÇ KULLANILMAZ: kilitli avatar çizilir,
  /// fotoğraf yolu okunmaz bile. Maskeleme kararı tek yerde kalır.
  final String fotoYolu;
  // ⚠ `teklifSayisi` KALDIRILDI (9 Eyl): teklif sayısı rozeti bu
  // ekrandan çıkarıldı, alan da gereksiz kaldı.

  /// ⚠ YENİ — hizmet alanın üyelik tarihi (tamamlanan iş sayısının
  /// altında gösterilir). `null` ise (hesap bulunamazsa) satır hiç
  /// çizilmez.
  final DateTime? kayitTarihi;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── .pl-av — kapalıyken KİLİTLİ avatar, açıkken profil ──
          //
          // ⚠ DOĞRULAMA ROZETİ KALDIRILDI (12 Eyl, kullanıcı isteği):
          // avatarın köşesindeki kalkan-tik (`ic_vbadge`) artık
          // çizilmiyor. Rozet "kimliği doğrulanmış" anlamı taşıyordu
          // ama platformda resmî bir kimlik doğrulaması YOK; her
          // avatarda koşulsuz görünüyordu.
          //
          // ⚠ ROZET GİTTİ, `Stack` DE GİTTİ: üst üste bindirilecek
          // başka bir öğe kalmadı.
          //
          // ⚠ FOTOĞRAFA DOKUNULUNCA TAM EKRAN AÇILIR — kural
          // `ProfilAvatari` içinde tek yerde; bu kart kendi açma
          // kodunu yazmaz.
          SizedBox(
            width: 46,
            height: 46,
            child: acik
                ? (fotoYolu.trim().isNotEmpty
                    ? ProfilAvatari(ad: adSoyad, fotoYolu: fotoYolu)
                    : Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: RC.blue, shape: BoxShape.circle),
                        child: Text(
                          _basHarfler(adSoyad),
                          style: refText(
                              size: 16, weight: RF.w700, color: RC.white),
                        ),
                      ))
                // ⚠ `IC_AVLOCK` — referansın KİLİTLİ AVATARI.
                //
                // Gri daire + kilit ikonu elle çiziliyordu; referansta
                // hazır bir görsel var ve iki tarafta farklı
                // görünmemesi için o kullanılır.
                : const RefSvg('assets/svg/ic_avlock.svg', size: 46),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // .pl-oname{15.5px/800;ls .3}
                  Text(adSoyad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: 15.5,
                          weight: RF.w700,
                          color: RC.text,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  // .pl-osub{11.8px;#5B6472}
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    // ⚠ `ic_briefcase` — ÇANTA (kullanıcı kararı, 9 Eyl).
                    //
                    // ÖNCEDEN `ic_shieldok` (onay işaretli kalkan)
                    // kullanılıyordu. Kalkan "doğrulanmış / güvenli"
                    // anlatır; buradaki sayı ise YAPILAN İŞ sayısıdır.
                    // Çanta o anlamı doğrudan taşır.
                    //
                    // ⚠ KAPSAM: değişiklik YALNIZ "iş tamamladı"
                    // satırlarını kapsar (7 yer). "Onaylı Hizmet
                    // Veren", "İletişim Açıldı" ve bildirim türü
                    // ikonları HÂLÂ `ic_shieldok`tur — onların anlamı
                    // gerçekten doğrulama/onaydır.
                    const RefSvg('assets/svg/ic_briefcase.svg',
                        size: 15, color: Color(0xFF5B6472)),
                    const SizedBox(width: 5),
                    Text('$tamamlananIs iş tamamladı',
                        style: refText(
                            size: 11.8,
                            weight: RF.w400,
                            color: const Color(0xFF5B6472))),
                  ]),
                  // ⚠ YENİ — kullanıcı isteği: üyelik tarihi,
                  // tamamlanan iş sayısının altında.
                  if (kayitTarihi != null) ...[
                    const SizedBox(height: 3),
                    Text(uyelikTarihiMetni(kayitTarihi!),
                        style: refText(
                            size: 11.8,
                            weight: RF.w400,
                            color: const Color(0xFF5B6472))),
                  ],
                ]),
          ),
          // ⚠ TEKLİF SAYISI ROZETİ KALDIRILDI (kullanıcı isteği,
          // 9 Eyl): hizmet veren zaten KENDİ teklifini görüyor;
          // ilanın kaç teklif aldığı onun kararını ilgilendirmiyor
          // ve kartın üst satırını kalabalıklaştırıyordu.
        ],
      );

  static String _basHarfler(String ad) {
    final p = ad.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    if (p.isEmpty) {
      return '?';
    }
    return p.take(2).map((k) => k.characters.first.toUpperCase()).join();
  }
}

/// ── `.pl-row` — ETİKET / DEĞER SATIRI ──
///
/// Alt bilgi tablosunun tek satırı: solda ikon + etiket, sağda değer.
///
/// ⚠ İKİ AKIŞTA AYNI: "İl / İlçe / Mahalle" ve tarih satırı her iki
/// detay ekranında da bu bileşenle çizilir.
class BilgiSatiri extends StatelessWidget {
  const BilgiSatiri({
    required this.ikon,
    required this.etiket,
    required this.deger,
  });

  final String ikon;
  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 1),
        decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0xFFF2F4F7)))),
        child: Row(children: [
          // .pl-rl{12.8px;#3A4658;gap:8px}
          RefSvg(ikon, size: 17, color: const Color(0xFF3A4658)),
          const SizedBox(width: 8),
          Text(etiket,
              style: refText(
                  size: 12.8,
                  weight: RF.w400,
                  color: const Color(0xFF3A4658))),
          const SizedBox(width: 10),
          // .pl-rv{12.8px/600;#16233D;text-align:right}
          Expanded(
            child: Text(deger,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: refText(
                    size: 12.8, weight: RF.w600, color: RC.text)),
          ),
        ]),
      );
}

/// ── `.pr-cbox` — İLETİŞİM KUTUSU (telefon / mesajlaşma) ──
///
/// ⚠ BUL AKIŞINDA AYRI BİR KOPYA VARDI (`_MiniIletisimKutusu`): daha
/// küçük daire, farklı punto, kilit rozeti yok. Aynı iki düğme iki
/// ekranda iki farklı boyda duruyordu. O kopya kaldırıldı.
///
/// ```css
/// .pr-cbox{gap:8px;1px #ECEEF1;r11;padding:9px;#fff}
/// .pr-cic{34px daire;#EAF1FB;ikon 17px #1D6BE3}
/// .pr-cl{12px #5B6472}
/// .pr-cv{14px/700;#16233D;tek satır, taşarsa …}
/// .pr-cv2{11px/500;#16233D;1.35}
/// .pr-clock{30px daire;#EEF0F4}
/// ```
///
/// ⚠ Kutu KAPALIYKEN de çizilir: maskeli değer, açıklama ve kilit
/// rozetiyle. Kullanıcı ücreti ödemeden önce neyin açılacağını görür.
class IletisimKutusu extends StatelessWidget {
  const IletisimKutusu({
    required this.ikon,
    required this.etiket,
    required this.deger,
    required this.not,
    required this.kilitli,
    required this.onTap,
    this.altiCizili = false,
  });

  final String ikon;
  final String etiket;

  /// Açıkken gösterilen değer (telefon numarası / "Sohbeti aç").
  final String? deger;

  /// Kapalıyken gösterilen açıklama.
  final String? not;

  final bool kilitli;
  final VoidCallback? onTap;

  /// Değer bağlantı gibi altı çizili gösterilsin mi?
  final bool altiCizili;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.r11),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: RC.white,
            border: Border.all(color: RC.border),
            borderRadius: BorderRadius.circular(RR.r11),
          ),
          child: Row(children: [
            // `.pr-cic`
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF1FB),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: RefSvg(ikon, size: 17, color: RC.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // `.pr-cl`
                  Text(etiket,
                      style: refText(
                          size: RF.s12, weight: RF.w400, color: RC.textSoft)),
                  if (deger != null) ...[
                    const SizedBox(height: 2),
                    // `.pr-cv`
                    Text(deger!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s14,
                            weight: RF.w700,
                            color: RC.text,
                            decoration: altiCizili
                                ? TextDecoration.underline
                                : null)),
                  ],
                  if (not != null) ...[
                    const SizedBox(height: 2),
                    // `.pr-cv2`
                    //
                    // ⚠ EK GÜVENLİK — metin artık kısa ("İletişim
                    // açılınca görünür.") ama yine de `maxLines`/
                    // `overflow` eklendi: çok dar bir ekranda taşarsa
                    // "…" ile kesilir, kelime ORTASINDAN BÖLÜNMEZ.
                    Text(not!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s11,
                            weight: RF.w500,
                            color: RC.text,
                            height: RF.lh135)),
                  ],
                ],
              ),
            ),
            if (kilitli) ...[
              const SizedBox(width: 6),
              // `.pr-clock`
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF0F4),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const RefSvg('assets/svg/ic_plock.svg',
                    size: 14, color: RC.greyLight),
              ),
            ],
          ]),
        ),
      );
}

