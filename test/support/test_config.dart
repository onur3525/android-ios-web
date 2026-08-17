/// YALNIZ test ortamı kimlik bilgileri — lib/ altında tutulmaz.
const String kTestOtp = '123456';
const String kTestPhone = '5321112233';
const String kTestPass = '123456';

/// ⚠ ŞİFRELİ GİRİŞ ARTIK E-POSTA İLEDİR.
///
/// Hesap modeli kararı: telefonla girişte şifre kullanılmaz, SMS OTP
/// kullanılır. Testler de bu yüzden `girisEposta` çağırır.
/// Bu adres tohumlanan demo hesaba aittir.
const String kTestEmail = 'test@hizmetcep.com';
