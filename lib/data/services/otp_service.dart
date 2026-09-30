import '../../core/test_modu.dart';

/// SMS doğrulama soyutlaması. Production'da backend'e bağlanır;
/// prototipte YALNIZ debug derlemede sabit kod kabul edilir
/// (release derlemede mock doğrulama kapalıdır — güvenlik kuralı).
abstract class OtpService {
  Future<void> sendCode(String phone);
  Future<bool> verify(String phone, String code);
}

class MockOtpService implements OtpService {
  static const _debugCode = '123456';

  @override
  Future<void> sendCode(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
  }

  @override
  Future<bool> verify(String phone, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // ⚠ YALNIZ TEST MODUNDA (bkz. `TestModu`): release'te ve varsayılan
    // web derlemesinde sabit kod KABUL EDİLMEZ.
    return TestModu.etkin && code == _debugCode;
  }
}
