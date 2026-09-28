import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'olcu.dart';

/// ═══════════════════════════════════════════════════════════════
/// MASAÜSTÜ DETAY DÜZENİ — ANA İÇERİK + SAĞ YAN PANEL
///
/// ## ⚠ NE YAPAR, NE YAPMAZ
///
/// Yalnız KONUMLANDIRIR. Verilen iki parça masaüstü web'de yan yana,
/// mobilde bugünkü gibi alt alta dizilir.
///
/// İçerik, kart, renk, ikon, düğme ve iş mantığı bu widget'ın
/// DIŞINDADIR ve değiştirilmez. Sağ panele konan şey ekranda zaten
/// var olan bir parçadır; yeni bilgi ya da yeni özellik üretilmez.
///
/// ## ⚠ MOBİL SIRASI BİREBİR KORUNUR
///
/// Masaüstü olmayan her durumda `ana` ÖNCE, `yan` SONRA çizilir —
/// yani bugünkü dikey sıra aynı kalır. Aradaki boşluk `aralik`
/// parametresiyle verilir; çağıran ekran oraya BUGÜNKÜ değeri
/// geçirerek mobil görünümü piksel piksel korur.
///
/// ## ⚠ İKİ KOŞUL BİRLİKTE
///
/// `kIsWeb` VE ≥1024 px (`EkranSinifi.masaustuMu`). Android/iOS'ta —
/// tablet dahil — ve dar tarayıcı penceresinde hiçbir şey değişmez.
/// Eşik `masaustuNav` ve `MasaustuListe` ile AYNI; biri yan yana
/// çizerken öteki alt alta kalsaydı sayfa tutarsız görünürdü.
///
/// ## ⚠ YAN PANEL SABİT GENİŞLİKTE
///
/// Ana içerik kalan yeri alır, yan panel `yanGenislik` kadar kalır.
/// İkisi de esnek olsaydı panel geniş ekranda gereksiz büyür, dar
/// ekranda okunamayacak kadar daralırdı. 360 px, liste kartlarının en
/// az genişliğiyle (`MasaustuIzgara._enAzKart`) aynı tutuldu — sayfa
/// genelinde tek bir dar-sütun ölçüsü olsun diye.
///
/// ## ⚠ KAYDIRMA ÇAĞIRANIN İŞİ
///
/// Bu widget kaydırma kurmaz. Detay ekranları kendi
/// `SingleChildScrollView` yapısını kullanmaya devam eder; buraya
/// ikinci bir kaydırma katmanı konsaydı iç içe kaydırma sorunu
/// çıkardı.
/// ═══════════════════════════════════════════════════════════════
class MasaustuDetay extends StatelessWidget {
  const MasaustuDetay({
    super.key,
    required this.ana,
    required this.yan,
    this.aralik = 16,
    this.yanGenislik = 360,
  });

  /// Sol/üst — ekranın asıl içeriği.
  final Widget ana;

  /// Sağ/alt — ekranda zaten bulunan yardımcı bölüm.
  final Widget yan;

  final double aralik;
  final double yanGenislik;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !ekranSinifi(context).masaustuMu) {
      // ⚠ BUGÜNKÜ DAVRANIŞ: alt alta, aynı sırayla, aynı boşlukla.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ana, SizedBox(height: aralik), yan],
      );
    }
    return Row(
      // ⚠ ÜSTTEN HİZALI: iki sütun farklı yükseklikte. `stretch`
      // olsaydı kısa olan panel gereksiz uzar, içindeki kartlar
      // dikeyde yayılırdı.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: ana),
        SizedBox(width: aralik),
        SizedBox(width: yanGenislik, child: yan),
      ],
    );
  }
}
