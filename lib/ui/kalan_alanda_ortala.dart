import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// KALAN GÖRÜNÜR ALANIN DİKEY ORTASI — TEK KAYNAK
///
/// Boş durum / bilgilendirme metinleri web'de başlığın hemen altında,
/// üst kenarda kalıyordu. Kaydırılabilir bir listenin içinde
/// `Expanded`/`Center` kalan yüksekliği bilemez (yükseklik sınırsız).
/// Bu bileşen ilk çizimden sonra ekrandaki kendi üst konumunu ölçer,
/// ekranın altına kadar kalan alanı kaplar ve çocuğu bu alanın
/// ortasına koyar. Konum değişirse (pencere boyu) yeniden ölçer.
///
/// Kullananlar: Bildirimler (boş liste) · Sonuçlar (hizmet veren yok).
/// Yeni bir ekranda aynı ihtiyaç doğarsa BU bileşen kullanılır; ekran
/// kendi ortalamasını yazmaz.
///
/// ⚠ YALNIZ WEB DALLARINDAN ÇAĞRILIR: mobil düzenler değişmez.
/// ═══════════════════════════════════════════════════════════════
class KalanAlandaOrtala extends StatefulWidget {
  const KalanAlandaOrtala({
    super.key,
    required this.child,
    this.altBosluk = 0,
    this.enAz = 100,
  });

  final Widget child;

  /// Kapsayan listenin alt dolgusu: kaplanan alandan düşülür, sayfa
  /// gereksiz yere kaymaz.
  final double altBosluk;

  /// Kalan alan çok küçükse bile en az bu kadar yer kaplanır.
  final double enAz;

  @override
  State<KalanAlandaOrtala> createState() => _KalanAlandaOrtalaState();
}

class _KalanAlandaOrtalaState extends State<KalanAlandaOrtala> {
  double? _yukseklik;

  void _olc() {
    if (!mounted) {
      return;
    }
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      return;
    }
    final mq = MediaQuery.of(context);
    final ust = ro.localToGlobal(Offset.zero).dy;
    final kalan = mq.size.height - mq.padding.bottom - widget.altBosluk - ust;
    final yeni = kalan < widget.enAz ? widget.enAz : kalan;
    if (_yukseklik == null || (yeni - _yukseklik!).abs() > 1) {
      setState(() => _yukseklik = yeni);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Her çizimden sonra konum yeniden okunur (pencere boyu değişince).
    WidgetsBinding.instance.addPostFrameCallback((_) => _olc());
    return SizedBox(
      height: _yukseklik ?? widget.enAz,
      child: Center(child: widget.child),
    );
  }
}
