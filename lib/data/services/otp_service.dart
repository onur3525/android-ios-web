import 'package:flutter/foundation.dart';

/// SMS doğrulama soyutlaması. API modunda doğrulama Firebase ve
/// backend tarafından yapılır; bu sınıf yalnız mock (bellek içi) mod
/// içindir.
abstract class OtpService {
  Future<void> sendCode(String phone);
  Future<bool> verify(String phone, String code);
}

/// Mock mod OTP servisi — KAPALI VARSAYILAN (fail-closed).
///
/// ⚠ CANLI HAZIRLIĞI (15 Eki): kaynakta SABİT TEST KODU YOKTUR ve
/// hiçbir derlemede (debug, profile, release, web) bir kod kabul
/// edilmez. Doğrulayıcı yalnız TEST KODUNDAN takılabilir
/// (`test/flutter_test_config.dart`); release derlemede takılmış
/// olsa bile yok sayılır.
class MockOtpService implements OtpService {
  /// Yalnız testler kurar. Uygulama kodu bu alana DOKUNMAZ.
  @visibleForTesting
  static bool Function(String phone, String code)? testDogrulayici;

  @override
  Future<void> sendCode(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
  }

  @override
  Future<bool> verify(String phone, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final d = testDogrulayici;
    if (kReleaseMode || d == null) {
      return false;
    }
    return d(phone, code);
  }
}
