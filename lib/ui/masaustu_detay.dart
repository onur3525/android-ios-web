import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'olcu.dart';

/// ═══════════════════════════════════════════════════════════════
/// DETAY DÜZENİ — ANA İÇERİK + YARDIMCI BÖLÜM, TEK SÜTUN
///
/// ## ⚠ MASAÜSTÜNDE DE ALT ALTA (14 Eki, kullanıcı kararı)
///
/// Önceden masaüstü web'de (≥1024 px) iki parça YAN YANA çiziliyordu:
/// solda detay kartı, sağda 360 px'lik yan panel (iletişim kutuları,
/// teklif formu / verilen teklif). Kullanıcı bulgusu: telefonun
/// tarayıcısında "Masaüstü sitesi" seçilince dar yan panelde kutular
/// sıkışıyor, sayfa mobildeki düzenden kopuyordu. Karar: "Masaüstü
/// görünümde yan yana olmamalı — sayfa tek sütun olsun."
///
/// Artık HER ekran sınıfında `ana` ÖNCE, `yan` SONRA, alt alta çizilir.
/// Masaüstünde sütun okunabilir genişlikte (`IcerikGenisligi.liste`)
/// ortalanır; kenardan kenara gerilmez.
///
/// ## ⚠ TEK YER
///
/// İki detay ekranı (ilan akışı `job_detail_screen`, Bul akışı
/// `teklif_talebi_detay_screen`) bu widget'ı kullanır; ikisi bu depoda
/// defalarca birbirine eşitlendi. Kural burada değiştiği için ikisi
/// birlikte tek sütuna geçer — biri iki kolon kalıp öteki tek kolona
/// geçseydi yeniden ayrışırlardı.
///
/// ## ⚠ MOBİL BİREBİR AYNI
///
/// Masaüstü olmayan her durumda çıktı öncekiyle aynıdır: aynı sıra,
/// aynı `aralik`.
///
/// ## ⚠ KAYDIRMA ÇAĞIRANIN İŞİ
///
/// Bu widget kaydırma kurmaz; detay ekranları kendi kaydırma yapısını
/// kullanmaya devam eder.
/// ═══════════════════════════════════════════════════════════════
class MasaustuDetay extends StatelessWidget {
  const MasaustuDetay({
    super.key,
    required this.ana,
    required this.yan,
    this.aralik = 16,
  });

  /// Üst — ekranın asıl içeriği.
  final Widget ana;

  /// Alt — ekranda zaten bulunan yardımcı bölüm.
  final Widget yan;

  final double aralik;

  @override
  Widget build(BuildContext context) {
    final sutun = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [ana, SizedBox(height: aralik), yan],
    );
    if (!kIsWeb || !ekranSinifi(context).masaustuMu) {
      // ⚠ BUGÜNKÜ DAVRANIŞ: alt alta, aynı sırayla, aynı boşlukla.
      return sutun;
    }
    // Masaüstü: aynı tek sütun, okunabilir genişlikte ve ortalı.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: IcerikGenisligi.liste),
        child: sutun,
      ),
    );
  }
}
