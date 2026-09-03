import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'sonuclar_screen.dart';

/// "BUL" AKIŞI — 2. EKRAN: HİZMET VERENLER TARANIYOR
///
/// `FindProviderScreen`'de hizmet seçilip "Ara" basıldığında açılır.
/// Tarama bitince `SonuclarScreen`'e geçer (aşama 3).
///
/// ⚠ GERÇEK SONUÇ SAYISINA GÖRE AŞAMA ATLAMA henüz YOK: hizmet veren
/// dizini şimdilik `MockSaglayici` (bkz. `mock_saglayici_dizini.dart`)
/// — gerçek backend değildir. Bu yüzden üç aşama SABİT SÜREYLE
/// ilerliyor; "bu ilçede yeterli sonuç var mı" kararını henüz
/// VEREMİYOR. Gerçek dizin bağlandığında bu metot güncellenmelidir.
class ScanningScreen extends StatefulWidget {
  const ScanningScreen({
    super.key,
    required this.kategori,
    required this.hizmet,
    required this.ilce,
    required this.il,
  });

  final String kategori;
  final String hizmet;
  final String ilce;
  final String il;

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;

  /// 0: ilçe · 1: yakın ilçeler · 2: il geneli.
  int _asama = 0;

  /// ⚠ Her aşama bu süre kadar görünür kalır — SABİT, gerçek sonuç
  /// sayısına bağlı DEĞİL (yukarıdaki not).
  static const _asamaSuresi = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    // ⚠ SÜREKLİ DÖNEN TARAMA IŞINI: 2,4 saniyede bir tam tur —
    // radar "gerçekten tarıyormuş" hissi verecek hızda.
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _asamalariBaslat();
  }

  Future<void> _asamalariBaslat() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(_asamaSuresi);
      if (!mounted) return;
      if (i < 2) {
        setState(() => _asama = i + 1);
      }
    }
    if (!mounted) return;
    _taramaTamamlaninca();
  }

  /// Tarama bitince "Sonuçlar" ekranına geçer.
  ///
  /// ⚠ `pushReplacement`: geri tuşu donmuş bir tarama ekranına değil,
  /// hizmet seçim ekranına dönmeli.
  void _taramaTamamlaninca() {
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SonuclarScreen(
          kategori: widget.kategori,
          hizmet: widget.hizmet,
          ilce: widget.ilce,
          il: widget.il,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠ İlk aşama etiketi SABİT DEĞİL — her zaman kullanıcının
    // GERÇEK profil ilçesidir; "Yakın İlçeler" listesi doluysa
    // parantez içinde ilk birkaçı gösterilir (yalnız bilgi amaçlı).
    final asamaEtiketleri = [widget.ilce, 'Yakın İlçeler', '${widget.il} Geneli'];

    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ÜST BAR: SOL GERİ · ORTA BAŞLIK · SAĞ KONUM ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  const RefBackButton(),
                  Expanded(
                    child: Text('Hizmet Verenler Taranıyor',
                        textAlign: TextAlign.center,
                        style: refText(
                            size: RF.s16, weight: RF.w700, color: RC.text)),
                  ),
                  // ⚠ AŞAMA 1'DEKİYLE AYNI İKON/RENK — üç ekranın
                  // aynı akışın parçası olduğu görsel olarak belli
                  // olsun diye.
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: RefSvg('assets/svg/ic_pin.svg',
                        size: 22, color: HC.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── ARANAN HİZMET — DİNAMİK ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: refText(
                          size: RF.s15, weight: RF.w700, color: RC.text),
                      children: [
                        TextSpan(text: '${widget.hizmet} '),
                        const TextSpan(
                          text: 'aranıyor...',
                          style: TextStyle(color: HC.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Konum: ${widget.ilce} / ${widget.il}',
                      style: refText(
                          size: RF.s13, weight: RF.w500, color: RC.textSoft)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── RADAR — YALNIZ DAİRENİN İÇİ KOYU ──
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _radar,
                  builder: (_, __) =>
                      _RadarDairesi(aci: _radar.value * 2 * math.pi),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text('${widget.ilce} ve çevresi taranıyor...',
                textAlign: TextAlign.center,
                style:
                    refText(size: RF.s13, weight: RF.w500, color: RC.text)),
            const SizedBox(height: 12),

            // ── ÜÇ AŞAMALI GÖSTERGE ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i <= _asama
                              ? HC.green
                              : const Color(0xFFE1E5EC),
                        ),
                      ),
                    _AsamaNoktasi(
                      etiket: asamaEtiketleri[i],
                      aktif: i == _asama,
                      tamam: i < _asama,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: RefInfoBox(
                child: Row(
                  children: [
                    const RefSvg('assets/svg/ic_shield.svg',
                        size: 18, color: RC.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sizi en iyi hizmet verenlerle buluşturmak için '
                        'tarama yapıyoruz. Lütfen bekleyiniz.',
                        style: refText(
                            size: RF.s125,
                            weight: RF.w500,
                            color: RC.textSoft),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsamaNoktasi extends StatelessWidget {
  const _AsamaNoktasi(
      {required this.etiket, required this.aktif, required this.tamam});

  final String etiket;
  final bool aktif;
  final bool tamam;

  @override
  Widget build(BuildContext context) {
    final renk = (aktif || tamam) ? HC.green : const Color(0xFFA8ADB4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tamam ? HC.green : RC.white,
            border: Border.all(color: renk, width: 2),
          ),
          child: tamam
              ? const Icon(Icons.check, size: 8, color: RC.white)
              : null,
        ),
        const SizedBox(height: 6),
        Text(etiket,
            textAlign: TextAlign.center,
            style: refText(
                size: RF.s11,
                weight: aktif ? RF.w700 : RF.w500,
                color: renk)),
      ],
    );
  }
}

/// ── ⚠ RADAR — YALNIZ KENDİ DAİRESİ KOYU, EKRAN BEYAZ KALIR ──
///
/// Prosedürel çizim (`CustomPainter`): yeni bir SVG/asset
/// ÜRETİLMEDİ. Halkalar ve tarama ışını `Canvas` ile çizilir; hizmet
/// veren noktaları var olan `ic_worker_w.svg` ikonuyla gösterilir.
class _RadarDairesi extends StatelessWidget {
  const _RadarDairesi({required this.aci});

  /// Tarama ışınının o anki açısı (radyan).
  final double aci;

  static const _cap = 240.0;

  /// ⚠ SABİT NOKTALAR — GERÇEK HİZMET VEREN KONUMU DEĞİL.
  ///
  /// Aşama 3'te gerçek bulunan hizmet veren sayısına göre
  /// üretilecek; şimdilik yalnız "tarama oluyor" hissi için
  /// yerleştirilmiş sabit açı/uzaklık çiftleridir.
  static const _noktalar = [
    (aci: 0.6, uzaklik: 0.55),
    (aci: 2.1, uzaklik: 0.75),
    (aci: 3.4, uzaklik: 0.4),
    (aci: 4.8, uzaklik: 0.68),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cap,
      height: _cap,
      child: ClipOval(
        child: Container(
          color: HC.dark,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(_cap, _cap),
                painter: _RadarPainter(aci: aci),
              ),
              // ⚠ Noktalar yalnız kendi taraması geçtikten SONRA
              // belirir — ışının o noktayı "bulduğu" izlenimi verir.
              for (final n in _noktalar)
                if (_gecildiMi(n.aci, aci))
                  _RadarNoktasi(aci: n.aci, uzaklik: n.uzaklik, cap: _cap),
            ],
          ),
        ),
      ),
    );
  }

  /// Işın son turunda bu açıyı geçti mi? (basit modulo karşılaştırma —
  /// ışın her turda noktaları yeniden "bulur", kaybolup gelirler.)
  bool _gecildiMi(double noktaAci, double isinAci) {
    final fark = (isinAci % (2 * math.pi)) - noktaAci;
    return fark > 0 && fark < 1.2;
  }
}

class _RadarNoktasi extends StatelessWidget {
  const _RadarNoktasi(
      {required this.aci, required this.uzaklik, required this.cap});

  final double aci;
  final double uzaklik;
  final double cap;

  @override
  Widget build(BuildContext context) {
    final r = (cap / 2) * uzaklik;
    final dx = math.cos(aci) * r;
    final dy = math.sin(aci) * r;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: HC.green.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: const RefSvg('assets/svg/ic_worker_w.svg', size: 12),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.aci});

  final double aci;

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = size.center(Offset.zero);
    final yaricap = size.width / 2;

    // ── EŞ MERKEZLİ HALKALAR ──
    final halkaBoyasi = Paint()
      ..color = HC.green.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(merkez, yaricap * i / 3, halkaBoyasi);
    }

    // ── TARAMA IŞINI — merkezden dönen kama ──
    final tarayici = SweepGradient(
      startAngle: aci,
      endAngle: aci + math.pi / 3,
      colors: [
        HC.green.withValues(alpha: 0.45),
        HC.green.withValues(alpha: 0),
      ],
    );
    final isinBoyasi = Paint()
      ..shader = tarayici
          .createShader(Rect.fromCircle(center: merkez, radius: yaricap));
    canvas.drawCircle(merkez, yaricap, isinBoyasi);

    // ── MERKEZ NOKTASI ──
    canvas.drawCircle(merkez, 4, Paint()..color = HC.green);

    // ── İNCE IŞIN ÇİZGİSİ (kamanın ön kenarı, belirgin olsun) ──
    final ucNokta = Offset(
      merkez.dx + yaricap * math.cos(aci),
      merkez.dy + yaricap * math.sin(aci),
    );
    canvas.drawLine(
      merkez,
      ucNokta,
      Paint()
        ..color = HC.green.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.aci != aci;
}
