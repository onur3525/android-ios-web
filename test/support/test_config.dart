import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/services/otp_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// YALNIZ TEST ORTAMI kimlik bilgileri ve fikstürleri.
///
/// ⚠ CANLI HAZIRLIĞI (15 Eki): demo hesap, sabit OTP kodu ve hazır
/// şifre özetleri `lib/` altından TAMAMEN kaldırıldı. Uygulama hiçbir
/// derlemede bunları içermez. Testlerin ihtiyaç duyduğu hesap ve OTP
/// doğrulayıcısı yalnız burada tanımlanır ve
/// `test/flutter_test_config.dart` tarafından her test dosyasından
/// önce kurulur (`testOrtaminiKur`).
/// ═══════════════════════════════════════════════════════════════

const String kTestOtp = '123456';
const String kTestPhone = '5321112233';
// ⚠ Bu değer YALNIZ testlerde durur; `lib/` altında YOKTUR.
const String kTestPass = 'hc-Demo-7Kq2xVw9';

/// ⚠ ŞİFRELİ GİRİŞ E-POSTA İLEDİR.
///
/// Hesap modeli kararı: telefonla girişte şifre kullanılmaz, SMS OTP
/// kullanılır. Testler de bu yüzden `girisEposta` çağırır.
/// Bu adres test tohumunun hesabına aittir.
const String kTestEmail = 'test@hizmetcep.com';

/// Test hesaplarının ÖNCEDEN HESAPLANMIŞ şifre özetleri (`kTestPass`).
///
/// PBKDF2-HMAC-SHA256, 20.000 tur, 32 bayt; biçim `pbkdf2$<tur>$<hex>`.
/// Her test kurulumunda 20.000 tur hesaplanmasın diye sabittir;
/// `acilis_kritik_yol_test` değerlerin `PasswordHasher` ile birebir
/// doğrulandığını denetler.
const String kDemoMusteriTuz = 'hc-demo-musteri-v1';
const String kDemoMusteriOzet =
    'pbkdf2\$20000\$fd814658c855411900c2ba7e6b0188235faa0123e38ceb45dc462e018610fbe0';
const String kDemoUstaTuz = 'hc-demo-usta-v1';
const String kDemoUstaOzet =
    'pbkdf2\$20000\$ce76b65253fd0cac83a3bbdfb7cbe9162801a6205f40d691c419b959fef3d6b7';

/// Test müşterisi — eski uygulama içi tohumla BİREBİR aynı alanlar.
void testHesabiTohumla(AuthRepository repo) {
  repo.testHesabiEkle(
      hazirTuz: kDemoMusteriTuz,
      hazirOzet: kDemoMusteriOzet,
      phone: kTestPhone,
      pass: '',
      roles: {Role.customer},
      name: 'Onur Bütün',
      email: kTestEmail,
      ilce: 'Karşıyaka',
      mahalle: 'İmbatlı');
}

/// Test OTP doğrulayıcısı: yalnız `kTestOtp` kabul edilir.
bool testOtpDogrula(String phone, String code) => code == kTestOtp;

/// Test kancalarını kurar. `flutter_test_config.dart` her test
/// dosyasından önce çağırır.
void testOrtaminiKur() {
  MockOtpService.testDogrulayici = testOtpDogrula;
  AuthRepository.testTohumu = testHesabiTohumla;
}

/// Kancaları söker — "uygulama kodu kendi başına" davranışını
/// denetleyen testler için. Test sonunda `testOrtaminiKur` ile geri
/// kurulmalıdır.
void testOrtaminiSok() {
  MockOtpService.testDogrulayici = null;
  AuthRepository.testTohumu = null;
}
