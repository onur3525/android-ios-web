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
///   · WEB DEBUG derlemesinde de AÇIKTIR (kullanıcı kararı, 1 Eki):
///     GitHub Pages'teki debug/mock sürümü bir DEMO sitesidir; demo
///     hesap kutusu, demo hesap ve OTP test kodu orada da görünür.
///     İstenirse web debug derlemesinde
///     `--dart-define=HC_TEST_MODU=false` ile kapatılabilir.
///     RELEASE web derlemesinde yine HİÇBİR KOŞULDA açılmaz.
///
/// ⚠ Bir mekanizma test amaçlıysa `kDebugMode`a DEĞİL buraya bağlanır.
/// ═══════════════════════════════════════════════════════════════
abstract final class TestModu {
  /// Web debug derlemesinde varsayılan AÇIK; `HC_TEST_MODU=false` kapatır.
  static const bool _webIstegi =
      bool.fromEnvironment('HC_TEST_MODU', defaultValue: true);

  static const bool etkin = !kReleaseMode && (!kIsWeb || _webIstegi);
}
