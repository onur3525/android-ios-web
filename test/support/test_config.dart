/// YALNIZ test ortamı kimlik bilgileri — lib/ altında tutulmaz.
const String kTestOtp = '123456';
const String kTestPhone = '5321112233';
// ⚠ 16 Ağu: demo şifre 6 → 8 hane. Asgari uzunluk 8 olunca demo
// hesabın kurala uymaması kuralı kâğıt üstünde bırakıyordu.
// Depodaki tohum değer ve `demo_hesap_ozetleri.dart` içindeki
// ⚠ 30 Eyl: eski demo şifre kişisel görünümlü olduğu için DEĞİŞTİRİLDİ
// (güvenlik denetimi M-01). Bu değer YALNIZ testlerde durur; `lib/`
// altında düz hâli YOKTUR, orada yalnız PBKDF2 özeti vardır.
const String kTestPass = 'hc-Demo-7Kq2xVw9';

/// ⚠ ŞİFRELİ GİRİŞ ARTIK E-POSTA İLEDİR.
///
/// Hesap modeli kararı: telefonla girişte şifre kullanılmaz, SMS OTP
/// kullanılır. Testler de bu yüzden `girisEposta` çağırır.
/// Bu adres tohumlanan demo hesaba aittir.
const String kTestEmail = 'test@hizmetcep.com';
