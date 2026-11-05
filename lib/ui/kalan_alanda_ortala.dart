import 'package:flutter/foundation.dart' show kIsWeb;
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
/// 6 Kas (kullanıcı kararı): İlanlarım ve Bildirimler boş durumu MOBİLDE de
/// bu bileşenle ortalanır. Mobilde ekranın altında alt menü vardır; ölçü
/// ekranın değil KAYDIRMA ALANININ görünen altına göre yapılır ve metin bu
/// görünen alanın dikey ortasına konur. Web ölçüsü değişmedi.
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

  /// Yalnız mobil: metnin ortalanacağı görünen alan yüksekliği.
  double? _gorunen;

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
    if (!kIsWeb) {
      _olcMobil(mq, ust);
      return;
    }
    final kalan = mq.size.height - mq.padding.bottom - widget.altBosluk - ust;
    final yeni = kalan < widget.enAz ? widget.enAz : kalan;
    if (_yukseklik == null || (yeni - _yukseklik!).abs() > 1) {
      setState(() => _yukseklik = yeni);
    }
  }

  /// MOBİL: görünen alan = bu bileşenin üstünden kaydırma alanının görünen
  /// altına (alt menünün üstü) kadar. Kutu, kaydırma alanının alt dolgusu
  /// kadar kısa tutulur (boş sayfa boşuna kaymaz); metin yine görünen
  /// alanın ORTASINDA çizilir.
  void _olcMobil(MediaQueryData mq, double ust) {
    var alt = mq.size.height - mq.padding.bottom;
    final kaydirma = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (kaydirma is RenderBox && kaydirma.hasSize) {
      alt = kaydirma.localToGlobal(Offset.zero).dy + kaydirma.size.height;
    }
    final dolgu = context
            .findAncestorWidgetOfExactType<SingleChildScrollView>()
            ?.padding
            ?.resolve(Directionality.of(context))
            .bottom ??
        0.0;
    var gorunen = alt - ust;
    if (gorunen < widget.enAz) {
      gorunen = widget.enAz;
    }
    var yuk = gorunen - dolgu - widget.altBosluk;
    if (yuk < widget.enAz) {
      yuk = widget.enAz;
    }
    if (_yukseklik == null ||
        _gorunen == null ||
        (yuk - _yukseklik!).abs() > 1 ||
        (gorunen - _gorunen!).abs() > 1) {
      setState(() {
        _yukseklik = yuk;
        _gorunen = gorunen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Her çizimden sonra konum yeniden okunur (pencere boyu değişince).
    WidgetsBinding.instance.addPostFrameCallback((_) => _olc());
    final gorunen = _gorunen;
    if (gorunen != null) {
      return SizedBox(
        height: _yukseklik ?? widget.enAz,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: gorunen,
              child: Center(child: widget.child),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: _yukseklik ?? widget.enAz,
      child: Center(child: widget.child),
    );
  }
}
