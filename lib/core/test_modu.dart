import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// TEST MODU — geliştirme/test mekanizmalarının TEK KAPISI
///
/// Kapıdan geçen mekanizmalar:
///   · sabit test OTP'si (`MockOtpService`, `123456`)
///   · OTP ekranındaki "Geliştirme sürümü test kodu" ipucu
///   · demo hesabın tohumlanması (`AuthRepository.seedTestAccount`)
///
/// ## KURAL
///
///   · RELEASE derlemede HİÇBİR KOŞULDA açılmaz — `kReleaseMode`
///     derleme sabitidir; hiçbir `--dart-define` bunu aşamaz.
///   · MOBİL/VM debug ve profile derlemelerinde açıktır (yerel
///     geliştirme, Codemagic teşhis derlemeleri ve `flutter test`
///     bugünkü gibi çalışır).
///   · WEB'de VARSAYILAN KAPALIDIR. Web derlemeleri herkese açık bir
///     adreste yayınlanıyor (GitHub Pages); debug derlemesi olsa bile
///     orada sabit OTP ve demo hesap ÇALIŞMAZ. Web'de yalnız derleme
///     komutuna AÇIKÇA `--dart-define=HC_TEST_MODU=true` verilirse
///     açılır — bu, yayını bilerek "demo" yapmak demektir.
///
/// ⚠ Bir mekanizma test amaçlıysa `kDebugMode`a DEĞİL buraya bağlanır.
/// ═══════════════════════════════════════════════════════════════
abstract final class TestModu {
  /// Web'de test modunu açık bir derleme bayrağıyla ister.
  static const bool _webIstegi = bool.fromEnvironment('HC_TEST_MODU');

  static const bool etkin = !kReleaseMode && (!kIsWeb || _webIstegi);
}
