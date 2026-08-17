import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/domain/failures.dart';

/// KAYIT · SMS OTP · E-POSTA DOĞRULAMA · GOOGLE AKIŞI
///
/// Talimat: `HizmetCep_Kayit_Dogrulama_Google_Akisi_Claude_Talimati`
/// 18 kabul testi.
void main() {
  late AuthRepository auth;
  setUp(() => auth = AuthRepository(seedTestAccount: false));

  /// Zorunlu alanları tamamlar (adres + kategori/bölge).
  void tamamla(Account a, {bool provider = false}) {
    a.address = Address(id: 'a1', district: 'Bornova', neighborhood: 'Erzene');
    if (provider) {
      a.categories.add('Tesisat');
      a.serviceDistricts.add('Bornova');
    }
  }

  group('Normal kayıt — Hizmet Alan', () {
    test('1. SMS OTP olmadan kayıt tamamlanamaz', () {
      final r = auth.register(
          phone: '5401112233',
          pass: '123456',
          role: Role.customer,
          otpVerified: false,
          termsAccepted: true);
      expect(r.error, isA<OtpRequiredError>());
      expect(auth.findByPhone('5401112233'), isNull);
    });

    test('2. e-posta doğrulanmadan kayıt TAMAMLANMIŞ sayılmaz', () {
      final r = auth.register(
          phone: '5401112233',
          pass: '123456',
          role: Role.customer,
          otpVerified: true,
          name: 'Ali Veli',
          email: 'ali@ornek.com',
          termsAccepted: true);
      expect(r.error, isNull);
      final a = r.account!;
      tamamla(a);
      // Telefon doğrulandı, e-posta doğrulanmadı.
      expect(a.phoneVerified, isTrue);
      expect(a.emailVerified, isFalse);
      expect(a.customerOnboardingComplete, isFalse);
      expect(a.missingSteps, contains(OnboardingStep.emailVerification));
    });

    test('3. İl/İlçe/Mahalle eksikken tamamlanamaz', () {
      final a = auth
          .register(
              phone: '5401112233',
              pass: '123456',
              role: Role.customer,
              otpVerified: true,
              name: 'Ali Veli',
              email: 'ali@ornek.com',
              termsAccepted: true)
          .account!;
      auth.completeEmailVerification('123456');
      expect(a.customerOnboardingComplete, isFalse);
      expect(a.missingSteps, contains(OnboardingStep.address));
    });

    test('4. sözleşme kabul edilmeden kayıt yapılamaz', () {
      final r = auth.register(
          phone: '5401112233',
          pass: '123456',
          role: Role.customer,
          otpVerified: true,
          termsAccepted: false);
      expect(r.error, isA<ValidationError>());
      expect(auth.findByPhone('5401112233'), isNull);
    });

    test('tüm zorunluluklar tamamlanınca onboarding biter', () {
      final a = auth
          .register(
              phone: '5401112233',
              pass: '123456',
              role: Role.customer,
              otpVerified: true,
              name: 'Ali Veli',
              email: 'ali@ornek.com',
              termsAccepted: true)
          .account!;
      tamamla(a);
      auth.completeEmailVerification('123456');
      expect(a.customerOnboardingComplete, isTrue);
      expect(a.missingSteps, isEmpty);
    });
  });

  group('Normal kayıt — Hizmet Veren', () {
    Account kur() => auth
        .register(
            phone: '5402223344',
            pass: '123456',
            role: Role.provider,
            otpVerified: true,
            name: 'Usta Veli',
            email: 'usta@ornek.com',
            termsAccepted: true)
        .account!;

    test('9. SMS OTP + e-posta doğrulaması zorunludur', () {
      final a = kur();
      tamamla(a, provider: true);
      expect(a.phoneVerified, isTrue);
      expect(a.emailVerified, isFalse);
      expect(a.providerOnboardingComplete, isFalse,
          reason: 'e-posta doğrulanmadan rol aktif olmaz');
      auth.completeEmailVerification('123456');
      expect(a.providerOnboardingComplete, isTrue);
    });

    test('10. kategori/bölge eksikken rol aktif olmaz', () {
      final a = kur();
      a.address =
          Address(id: 'a1', district: 'Bornova', neighborhood: 'Erzene');
      auth.completeEmailVerification('123456');
      expect(a.providerOnboardingComplete, isFalse);
      expect(a.missingSteps, contains(OnboardingStep.providerCategories));
      expect(a.missingSteps, contains(OnboardingStep.providerAreas));

      a.categories.add('Tesisat');
      expect(a.providerOnboardingComplete, isFalse,
          reason: 'yalnız kategori yeterli değil');
      a.serviceDistricts.add('Bornova');
      expect(a.providerOnboardingComplete, isTrue);
    });
  });

  group('Google ile kayıt', () {
    Account google({required Role role}) => auth
        .register(
            phone: '5403334455',
            pass: 'g-oauth',
            role: role,
            otpVerified: true,
            name: 'Ayşe Yılmaz',
            email: 'ayse@gmail.com',
            termsAccepted: true,
            // Google doğrulanmış e-posta ile gelir.
            emailVerified: true,
            googleSub: 'google-sub-001')
        .account!;

    test('5/11. Google e-postası için İKİNCİ doğrulama istenmez', () {
      final a = google(role: Role.customer);
      expect(a.emailVerified, isTrue);
      expect(a.missingSteps, isNot(contains(OnboardingStep.emailVerification)));
    });

    test('6/12. telefon + SMS OTP olmadan tamamlanamaz', () {
      // OTP doğrulanmadan Google akışı da kayıt üretemez.
      final r = auth.register(
          phone: '5403334455',
          pass: 'g-oauth',
          role: Role.customer,
          otpVerified: false,
          termsAccepted: true,
          emailVerified: true,
          googleSub: 'google-sub-001');
      expect(r.error, isA<OtpRequiredError>());
    });

    test('7. Google Hizmet Alan: adres eksikken tamamlanamaz', () {
      final a = google(role: Role.customer);
      expect(a.customerOnboardingComplete, isFalse);
      expect(a.missingSteps, contains(OnboardingStep.address));
      tamamla(a);
      expect(a.customerOnboardingComplete, isTrue);
    });

    test('8/14. sözleşme onayı Google akışında da ZORUNLU', () {
      final r = auth.register(
          phone: '5403334455',
          pass: 'g-oauth',
          role: Role.customer,
          otpVerified: true,
          termsAccepted: false,
          emailVerified: true,
          googleSub: 'google-sub-001');
      expect(r.error, isA<ValidationError>(),
          reason: 'Google kaydı sözleşme onayını bypass EDEMEZ');
    });

    test('13. Google Hizmet Veren: kategori/bölge eksikken tamamlanamaz', () {
      final a = google(role: Role.provider);
      a.address =
          Address(id: 'a1', district: 'Bornova', neighborhood: 'Erzene');
      expect(a.providerOnboardingComplete, isFalse);
      expect(a.missingSteps, contains(OnboardingStep.providerCategories));
      expect(a.missingSteps, contains(OnboardingStep.providerAreas));
    });

    test('18. aynı Google sub İKİNCİ hesap üretmez', () {
      final a = google(role: Role.customer);
      expect(auth.findByGoogleSub('google-sub-001')!.id, a.id);
      // Aynı sub başka hesaba bağlanamaz.
      final ikinci = auth
          .register(
              phone: '5405556677',
              pass: '123456',
              role: Role.customer,
              otpVerified: true,
              termsAccepted: true)
          .account!;
      auth.currentAccount = ikinci;
      final err = auth.linkGoogle(
          sub: 'google-sub-001',
          email: 'ayse@gmail.com',
          googleEmailVerified: true);
      expect(err, isA<ValidationError>());
      expect(ikinci.googleSub, isNull);
    });
  });

  group('Yarım kayıt ve e-posta değişikliği', () {
    test('15. tamamlanan bilgiler korunur, eksik adım bilinir', () {
      final a = auth
          .register(
              phone: '5401112233',
              pass: '123456',
              role: Role.customer,
              otpVerified: true,
              name: 'Ali Veli',
              email: 'ali@ornek.com',
              termsAccepted: true)
          .account!;
      // Yarım bırakıldı: adres yok, e-posta doğrulanmadı.
      expect(a.missingSteps, contains(OnboardingStep.address));
      expect(a.missingSteps, contains(OnboardingStep.emailVerification));
      // Tekrar girişte girilen bilgiler KAYBOLMAZ.
      expect(a.name, 'Ali Veli');
      expect(a.email, 'ali@ornek.com');
      expect(a.phoneVerified, isTrue);
      expect(a.termsAccepted, isTrue);
    });

    test('16. e-posta değişince ESKİ adres korunur, yenisi BEKLER (K4)', () {
      final a = auth
          .register(
              phone: '5401112233',
              pass: '123456',
              role: Role.customer,
              otpVerified: true,
              name: 'Ali Veli',
              email: 'ali@ornek.com',
              termsAccepted: true)
          .account!;
      auth.completeEmailVerification('123456');
      expect(a.emailVerified, isTrue);

      auth.updateProfile(email: 'yeni@ornek.com');

      // ⚠ SÖZLEŞME DEĞİŞTİ (K4) — TEST GEVŞETİLMEDİ, YENİDEN YAZILDI.
      //
      // Eskiden yeni adres HEMEN yazılıyor ve `emailVerified=false`
      // yapılıyordu. Sonuç: kullanıcı adresi yanlış yazarsa hem eski
      // DOĞRULANMIŞ adresini kaybediyor hem yenisini doğrulayamıyor
      // — hesap kurtarma kanalsız kalıyordu.
      //
      // Artık yeni adres BEKLEYEN alanda tutulur; hesabın geçerli
      // e-postası doğrulama tamamlanana kadar ESKİSİDİR.
      expect(a.email, 'ali@ornek.com', reason: 'eski adres kaybedildi');
      expect(a.emailVerified, isTrue,
          reason: 'eski adres hâlâ doğrulanmış olmalı');
      expect(a.bekleyenEposta, 'yeni@ornek.com');

      // Doğrulama tamamlanınca geçiş TEK ADIMDA olur.
      expect(auth.epostaDogrula(), isNull);
      expect(a.email, 'yeni@ornek.com');
      expect(a.emailVerified, isTrue);
      expect(a.bekleyenEposta, isNull);
    });

    test('17. doğrulanmamış e-posta ile emailVerified üretilmez', () {
      final a = auth
          .register(
              phone: '5401112233',
              pass: '123456',
              role: Role.customer,
              otpVerified: true,
              email: 'ali@ornek.com',
              termsAccepted: true,
              // Google akışı DEĞİL: emailVerified verilmedi.
              )
          .account!;
      expect(a.emailVerified, isFalse);
      expect(a.googleSub, isNull);
    });
  });
}
