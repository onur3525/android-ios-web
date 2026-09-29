import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../core/arama_izi.dart';

/// ═══════════════════════════════════════════════════════════════
/// WEB ARAMA ÖNERİSİ DOKUNUŞU — TEK KAYNAK
///
/// ⚠ YALNIZ WEB'DE KULLANILIR. Mobil öneri satırları bu bileşene
/// bağlanmaz; onların davranışı olduğu gibi kalır.
///
/// İki web araması (ana sayfa kutusu ve masaüstü başlık araması)
/// seçimi buradan yapar. Ayrı ayrı yazılsaydı biri düzeltilip
/// öteki unutulurdu.
///
/// ## ⚠ SEÇİM PARMAK / FARE KALKINCA YAPILIR
///
/// Önceki yol seçimi `onPointerDown`da yapıyordu. Telefon
/// tarayıcısında bunun iki sorunu vardı:
///
///   · Listeyi parmakla kaydırmaya başlamak, dokunulan satırı SEÇİYORDU.
///   · Metin alanı odağı kaybedince panel kaldırılıyor, dokunuşun
///     tamamlanıp tamamlanmadığı belirsiz kalıyordu.
///
/// Burada seçim `onPointerUp`ta yapılır ve yalnız parmak/fare
/// basıldığı yerden kayma eşiğinden AZ kaydıysa geçerlidir (eşik
/// cihazın jest ayarından, yoksa `kTouchSlop`).
/// Kaydırma hareketi seçim sayılmaz.
///
/// ⚠ PANEL KALDIRILSA BİLE ÇALIŞIR: Flutter, bir işaretçinin
/// kalkış olayını basıldığı andaki isabet yoluna teslim eder. Odak
/// kaybı ya da tarayıcı klavyesinin kapanması paneli ağaçtan
/// kaldırsa bile bu dinleyici kalkış olayını alır.
///
/// ⚠ ÇİFT TETİKLEME: satırın kendi `onTap`ı (klavyeyle Enter için
/// korunur) aynı dokunuşta ikinci kez çağrı yapabilir; çağıran
/// taraf tek-sefer korumasını zaten taşır (`_sec` listeyi boşaltır).
/// ═══════════════════════════════════════════════════════════════
class WebOneriDokunusu extends StatefulWidget {
  const WebOneriDokunusu({
    super.key,
    required this.onSec,
    required this.child,
    this.izEtiketi,
  });

  final VoidCallback onSec;
  final Widget child;

  /// Ölçüm kaydında satırı tanıtan kısa ad (yalnız ARAMA_IZ açıkken
  /// verilir). ⚠ Davranışa hiçbir etkisi yok.
  final String? izEtiketi;

  @override
  State<WebOneriDokunusu> createState() => _WebOneriDokunusuState();
}

class _WebOneriDokunusuState extends State<WebOneriDokunusu> {
  /// Basılan işaretçi ve basıldığı nokta (genel koordinat).
  int? _isaretci;
  Offset? _baslangic;
  bool _kaydi = false;

  /// ⚠ Geri çağrı BASILDIĞI ANDA yakalanır: satır parmak kalkmadan
  /// ağaçtan kaldırılırsa `widget`a bir daha güvenilmez.
  VoidCallback? _bekleyen;

  /// ⚠ Kayma eşiği basış anında CİHAZIN jest ayarından okunur
  /// (`MediaQuery` jest ayarı; yoksa `kTouchSlop`). Sayfa kaydırıcısı da
  /// aynı ayarı kullandığı için "kaydırma başladı" ile "seçim iptal"
  /// her cihazda AYNI noktada olur: eşiği aşan hareket kaydırmadır ve
  /// seçmez, aşmayan hareket seçimdir ve kaydırmaz.
  double _esik = kTouchSlop;

  /// Ölçüm: MOVE kaydı eşik İLK aşıldığında bir kez yazılır.
  bool _izMoveYazildi = false;

  /// Ölçüm: satır adı BASIŞTA yakalanır (satır kalkıştan önce ağaçtan
  /// kalkarsa `widget`a bir daha güvenilmez).
  String _izEtiket = '-';

  void _iz(String olay, PointerEvent e, [String ek = '']) {
    if (!kAramaIzi) {
      return;
    }
    aramaIzi(
        olay,
        '[$_izEtiket] id=${e.pointer} tur=${e.kind.name} '
        'genel=${izNokta(e.position)}${ek.isEmpty ? '' : ' $ek'}');
  }

  double _esikOku() {
    final ayar = MediaQuery.maybeGestureSettingsOf(context);
    return ayar?.touchSlop ?? kTouchSlop;
  }

  void _sifirla() {
    _bekleyen = null;
    _isaretci = null;
    _baslangic = null;
    _kaydi = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (kAramaIzi) {
          _izEtiket = widget.izEtiketi ?? '-';
          _izMoveYazildi = false;
          _iz('SEARCH_RESULT_POINTER_DOWN', e,
              'dugmeler=${e.buttons} satir=${izRect(izGenelRect(context))}');
        }
        // ⚠ Fareyle yalnız birincil düğme seçer.
        if (e.kind == PointerDeviceKind.mouse &&
            e.buttons != kPrimaryMouseButton) {
          return;
        }
        _isaretci = e.pointer;
        _bekleyen = widget.onSec;
        _esik = _esikOku();
        _baslangic = e.position;
        _kaydi = false;
      },
      onPointerMove: (e) {
        if (e.pointer != _isaretci || _baslangic == null) {
          return;
        }
        if ((e.position - _baslangic!).distance > _esik) {
          _kaydi = true;
          if (kAramaIzi && !_izMoveYazildi) {
            _izMoveYazildi = true;
            _iz('SEARCH_RESULT_POINTER_MOVE', e,
                'esik_asildi mesafe=${(e.position - _baslangic!).distance.toStringAsFixed(1)} esik=$_esik');
          }
        }
      },
      onPointerUp: (e) {
        if (kAramaIzi) {
          final eslesti = e.pointer == _isaretci && _baslangic != null;
          final mesafe = _baslangic == null
              ? -1.0
              : (e.position - _baslangic!).distance;
          _iz(
              'SEARCH_RESULT_POINTER_UP',
              e,
              'eslesti=$eslesti mesafe=${mesafe.toStringAsFixed(1)} '
              'esik=$_esik kaydi=$_kaydi '
              'gecerli=${eslesti && !_kaydi && mesafe <= _esik} '
              'monte=$mounted');
        }
        if (e.pointer != _isaretci || _baslangic == null) {
          return;
        }
        final gecerli =
            !_kaydi && (e.position - _baslangic!).distance <= _esik;
        final cagri = _bekleyen;
        _sifirla();
        if (gecerli && cagri != null) {
          cagri();
        }
      },
      onPointerCancel: (e) {
        if (kAramaIzi) {
          _iz('SEARCH_RESULT_POINTER_CANCEL', e,
              'eslesti=${e.pointer == _isaretci}');
        }
        if (e.pointer == _isaretci) {
          _sifirla();
        }
      },
      child: widget.child,
    );
  }
}
