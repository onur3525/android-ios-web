import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

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
  });

  final VoidCallback onSec;
  final Widget child;

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
        }
      },
      onPointerUp: (e) {
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
        if (e.pointer == _isaretci) {
          _sifirla();
        }
      },
      child: widget.child,
    );
  }
}
