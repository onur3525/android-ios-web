
import 'package:flutter/material.dart';

import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../../core/platform/yerel_gorsel.dart';

/// TAM EKRAN FOTOĞRAF GÖRÜNTÜLEYİCİ
///
/// İlan fotoğrafına dokunulduğunda açılır. Hem HİZMET ALAN (İlan
/// Detayı) hem HİZMET VEREN (İş Detayı) tarafında AYNI bileşen
/// kullanılır — iki taraf aynı deneyimi yaşar.
///
/// Yetenekler:
///   • Çift dokunuş veya parmak açma ile YAKINLAŞTIRMA (1x–4x)
///   • Birden çok fotoğrafta YANA KAYDIRARAK geçiş
///   • Üstte "3 / 7" sayacı ve kapatma düğmesi
///   • Geri tuşu ve kapatma düğmesi ile çıkış
///
/// ⚠ Fotoğraflar CİHAZ YOLUNDAN okunur. Dosya bulunamazsa (silinmiş,
/// izin kalkmış) çökme YERİNE açıklayıcı bir yer tutucu çizilir.
class FotoGoruntuleyici extends StatefulWidget {
  const FotoGoruntuleyici({
    super.key,
    required this.yollar,
    this.baslangic = 0,
  });

  final List<String> yollar;
  final int baslangic;

  /// Görüntüleyiciyi açar. Siyah zeminli, tam ekran bir sayfadır.
  static Future<void> ac(
    BuildContext context, {
    required List<String> yollar,
    int baslangic = 0,
  }) {
    if (yollar.isEmpty) {
      return Future<void>.value();
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            FotoGoruntuleyici(yollar: yollar, baslangic: baslangic),
      ),
    );
  }

  @override
  State<FotoGoruntuleyici> createState() => _FotoGoruntuleyiciState();
}

class _FotoGoruntuleyiciState extends State<FotoGoruntuleyici> {
  late final PageController _sayfa =
      PageController(initialPage: widget.baslangic);
  late int _aktif = widget.baslangic;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cokluFoto = widget.yollar.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _sayfa,
            itemCount: widget.yollar.length,
            onPageChanged: (i) => setState(() => _aktif = i),
            itemBuilder: (_, i) => _Sayfa(yol: widget.yollar[i]),
          ),

          // ── Üst şerit: sayaç + kapat ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // ⚠ `ic_x.svg` KULLANILMAZ.
                    //
                    // O ikon DOLGULU bir daire içinde beyaz çarpıdır;
                    // tek renge boyanınca çarpı kayboluyor ve ekranda
                    // düz beyaz bir daire kalıyordu. `ic_close.svg`
                    // dolgusuzdur, yalnız çizgiden oluşur.
                    _YuvarlakDugme(
                      ikon: 'assets/svg/ic_close.svg',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (cokluFoto)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(RR.circle),
                        ),
                        child: Text(
                          '${_aktif + 1} / ${widget.yollar.length}',
                          style: refText(
                              size: RF.s135,
                              weight: RF.w600,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek fotoğraf — yakınlaştırılabilir.
class _Sayfa extends StatefulWidget {
  const _Sayfa({required this.yol});

  final String yol;

  @override
  State<_Sayfa> createState() => _SayfaState();
}

class _SayfaState extends State<_Sayfa> {
  final _kontrol = TransformationController();
  TapDownDetails? _sonDokunus;

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  /// Çift dokunuş: yakınsa uzaklaştırır, uzaksa dokunulan NOKTAYA
  /// yakınlaştırır (ekranın ortasına değil).
  void _ciftDokunus() {
    final yakin = _kontrol.value.getMaxScaleOnAxis() > 1.01;
    if (yakin) {
      _kontrol.value = Matrix4.identity();
      return;
    }
    final n = _sonDokunus?.localPosition;
    if (n == null) {
      return;
    }
    const kat = 2.5;
    // ── ⚠ KULLANIMDAN KALKAN API DEĞİŞTİRİLDİ ──
    //
    // `Matrix4.translate` ve `Matrix4.scale` deprecated; Flutter
    // bunları kaldırdığında derleme kırılır. Analyzer üç turdur
    // uyarıyordu.
    //
    // Yerine matris DOĞRUDAN kurulur: ölçek köşegende, öteleme son
    // sütunda. Davranış birebir aynı — çift dokunulan nokta ekranda
    // yerinde kalarak 2,5 kat büyür.
    final dx = -n.dx * (kat - 1);
    final dy = -n.dy * (kat - 1);
    _kontrol.value = Matrix4.identity()
      ..setEntry(0, 0, kat)
      ..setEntry(1, 1, kat)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onDoubleTapDown: (d) => _sonDokunus = d,
        onDoubleTap: _ciftDokunus,
        child: InteractiveViewer(
          transformationController: _kontrol,
          minScale: 1,
          maxScale: 4,
          child: Center(
            // ⚠ KÖPRÜ ÜZERİNDEN: mobilde `Image.file`, web'de blob
            // adresi için `Image.network`.
            child: yerelGorsel(
              widget.yol,
              fit: BoxFit.contain,
              hataYedegi: (_) => Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RefSvg('assets/svg/ic_gallery.svg',
                        size: 44, color: Color(0xFF8A94A6)),
                    const SizedBox(height: 12),
                    Text(
                      'Fotoğraf açılamadı',
                      style: refText(
                          size: RF.s145,
                          weight: RF.w600,
                          color: const Color(0xFFCBD2DC)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Siyah zemin üzerinde okunur yuvarlak düğme.
class _YuvarlakDugme extends StatelessWidget {
  const _YuvarlakDugme({required this.ikon, required this.onTap});

  final String ikon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.circle),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .55),
            shape: BoxShape.circle,
          ),
          child: RefSvg(ikon, size: 18, color: Colors.white),
        ),
      );
}
