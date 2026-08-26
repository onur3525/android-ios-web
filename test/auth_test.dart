import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/domain/password_hasher.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'support/test_config.dart';

void main() {
  late AuthRepository auth;
  setUp(() => auth = AuthRepository());

  group('Güvenlik sertleştirmeleri', () {
    test('kaba kuvvet: 5 hatalı denemeden sonra geçici kilit', () {
      // ⚠ Bu İSTEMCİ TARAFI sürtünmedir; asıl sınır sunucudadır.
      // Test kuralın yürürlükte olduğunu doğrular.
      // ⚠ ŞİFRELİ GİRİŞ ARTIK E-POSTA İLEDİR (hesap modeli kararı).
      // Telefonla girişte şifre kullanılmaz; SMS OTP kullanılır ve o
      // yol `telefon_giris_otp_test.dart`'ta kanıtlanır.
      const e = 'yok@example.com';
      for (var i = 0; i < 5; i++) {
        expect(auth.girisEposta(e, 'yanlis$i'), isA<AuthFailedError>(),
            reason: 'sınır dolmadan genel hata dönmeli');
      }
      // 6. denemede artık kilit mesajı gelir — hesap var mı yok mu
      // bilgisini yine ELE VERMEZ.
      final k = auth.girisEposta(e, 'yanlis');
      expect(k, isA<ValidationError>());
      expect(k!.message.contains('Çok fazla hatalı deneme'), isTrue);
    });

    test('giriş hatası hangi alanın yanlış olduğunu SÖYLEMEZ', () {
      // Kayıtsız numara ve yanlış şifre AYNI hatayı döndürür; aksi
      // hâlde saldırgan hangi numaraların kayıtlı olduğunu öğrenir.
      final a = auth.girisEposta('yok@example.com', kTestPass);
      final b = auth.girisEposta(kTestEmail, 'kesinlikleyanlis');
      expect(a.runtimeType, b.runtimeType);
    });

    test('APK cihaz yedeğine ve düz HTTP\'ye kapalı', () {
      final m = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(m.contains('android:allowBackup="false"'), isTrue,
          reason: 'yedekte oturum jetonu dışarı çıkabilir');
      expect(m.contains('android:usesCleartextTraffic="false"'), isTrue,
          reason: 'token şifresiz taşınamaz');
      expect(m.contains('dataExtractionRules'), isTrue,
          reason: 'Android 12+ aktarım kuralı verilmeli');
    });
  });

  group('Giriş', () {
    test('yanlış şifre/kayıtsız numara genel hatayla reddedilir', () {
      expect(auth.girisEposta(kTestEmail, 'yanlis'), isA<AuthFailedError>());
      expect(auth.girisEposta('yok@example.com', kTestPass),
          isA<AuthFailedError>());
      expect(auth.loggedIn, isFalse);
      expect(auth.girisEposta(kTestEmail, kTestPass), isNull);
      expect(auth.loggedIn, isTrue);
    });

    test('giriş hesabın aktif rolüne göre panel belirler', () {
      auth.register(
          phone: '5507654321', pass: 'ustapass1', email: 'usta@example.com',
          role: Role.provider, otpVerified: true, termsAccepted: true);
      auth.logout();
      auth.girisEposta('usta@example.com', 'ustapass1');
      expect(auth.activeRole, Role.provider);
    });
  });

  group('Kayıt güvenliği (K1)', () {
    test('OTP doğrulanmadan kayıt HİÇBİR yoldan çalışmaz', () {
      final r1 = auth.register(
          phone: '5401234567', pass: 'p1', role: Role.customer, otpVerified: false);
      expect(r1.error, isA<OtpRequiredError>());
      expect(r1.account, isNull);
      expect(auth.findByPhone('5401234567'), isNull);
      expect(auth.loggedIn, isFalse);
      // kayıtlı telefona da OTP'siz rol eklenemez
      final r2 = auth.register(
          phone: kTestPhone, pass: kTestPass, role: Role.provider, otpVerified: false);
      expect(r2.error, isA<OtpRequiredError>());
      expect(auth.findByPhone(kTestPhone)!.roles, {Role.customer});
    });

    test('kayıtlı telefona YANLIŞ şifreyle rol eklenemez ve oturum açılmaz', () {
      final r = auth.register(
          phone: kTestPhone, pass: 'bambaska1', role: Role.provider, otpVerified: true, termsAccepted: true);
      expect(r.error, isA<WrongPasswordError>());
      expect(r.account, isNull);
      expect(auth.loggedIn, isFalse);
      expect(auth.findByPhone(kTestPhone)!.roles, {Role.customer}); // rol EKLENMEDİ
    });

    test('girilen şifre sessizce yok sayılmaz: yeni hesap o şifreyle açılır', () {
      auth.register(
          phone: '5401234567', pass: 'benimsifrem1', email: 'yeni@example.com',
          role: Role.customer, otpVerified: true, termsAccepted: true);
      auth.logout();
      expect(auth.girisEposta('yeni@example.com', 'benimsifrem1'), isNull);
    });

    test('çok rollü hesap: doğru şifre + OTP ile ikinci rol MEVCUT hesaba eklenir', () {
      final a1 = auth
          .register(phone: '5401234567', pass: 'p1', role: Role.customer, otpVerified: true, termsAccepted: true)
          .account!;
      final a2 = auth
          .register(phone: '5401234567', pass: 'p1', role: Role.provider, otpVerified: true, termsAccepted: true)
          .account!;
      expect(identical(a1, a2), isTrue);
      expect(a2.roles, {Role.customer, Role.provider});
      expect(a2.activeRole, Role.provider);
      expect(auth.switchRole(Role.customer), isNull);
      expect(auth.activeRole, Role.customer);
    });
  });

  // ── ROL DEĞİŞTİRME SÖZLEŞMESİ (nihai) ──
  //
  // ESKİ kural: hesapta olmayan role geçiş `UnauthorizedError` ile
  // ÇIKMAZ SOKAK üretiyordu.
  //
  // YENİ kural: kullanıcı eksik rol için ONBOARDING akışına
  // yönlendirilir; gerekli HizmetCep alanları tamamlanınca rol AYNI
  // hesaba eklenir ve aktif edilir.
  //
  // ⚠ Güvenlik zayıflamadı: rol hâlâ kendiliğinden aktif OLMAZ,
  // yalnız hata tipi yönlendirici hale geldi.
  test('rol değişimi: hesapta olmayan rol AKTİF EDİLMEZ', () {
    auth.girisEposta(kTestEmail, kTestPass);
    final acc = auth.currentAccount!;
    expect(acc.roles, {Role.customer});

    final err = auth.switchRole(Role.provider);
    expect(err, isNotNull, reason: 'rol kendiliğinden aktif olmamalı');
    // Yönlendirici hata: kullanıcı tamamlama akışına gider.
    expect(err, isA<NotFoundError>());
    expect(acc.activeRole, Role.customer, reason: 'aktif rol DEĞİŞMEDİ');
    expect(acc.roles, {Role.customer}, reason: 'rol EKLENMEDİ');
  });

  test('eksik rol: zorunlu bilgiler olmadan addRole REDDEDİLİR', () {
    auth.girisEposta(kTestEmail, kTestPass);
    final acc = auth.currentAccount!;

    // Kategori yok → reddedilir.
    expect(auth.addRole(Role.provider), isA<ValidationError>());
    expect(acc.roles, {Role.customer});

    // Yalnız kategori de yeterli değil (bölge zorunlu).
    expect(
        auth.addRole(Role.provider, categories: {'Tesisat'}),
        isA<ValidationError>());
    expect(acc.roles, {Role.customer});
  });

  test('eksik rol: bilgiler tamamlanınca rol eklenir ve aktif olur', () {
    auth.girisEposta(kTestEmail, kTestPass);
    final acc = auth.currentAccount!;

    final err = auth.addRole(Role.provider,
        categories: {'Tesisat'}, serviceDistricts: {'Bornova'});
    expect(err, isNull);
    expect(acc.roles, containsAll({Role.customer, Role.provider}));
    expect(acc.activeRole, Role.provider);
    expect(acc.categories, {'Tesisat'});
    expect(acc.serviceDistricts, {'Bornova'});

    // Rol artık mevcut: switchRole çalışır.
    expect(auth.switchRole(Role.customer), isNull);
    expect(acc.activeRole, Role.customer);
  });

  test('şifreler düz metin SAKLANMAZ (PBKDF2 + tuz)', () {
    final acc = auth.findByPhone(kTestPhone)!;
    expect(acc.passwordHash, isNot(contains(kTestPass)));
    expect(acc.salt, isNotEmpty);

    // ⚠ Test GEVŞETİLMEDİ, DARALTILDI.
    //
    // Önceki beklenti yalnız "64 karakter" idi; tek turlu SHA-256'yı
    // da geçiriyordu. Artık biçimin PBKDF2 olduğu ve tur sayısının
    // beklenen düzeyde bulunduğu AYRICA doğrulanır.
    final parcalar = acc.passwordHash.split(r'$');
    expect(parcalar.length, 3, reason: 'biçim: pbkdf2\$<tur>\$<hex>');
    expect(parcalar[0], 'pbkdf2');
    expect(int.parse(parcalar[1]), greaterThanOrEqualTo(20000),
        reason: 'tur sayısı düşürülmemeli');
    expect(parcalar[2].length, 64); // 32 bayt hex

    // Doğrulama gerçekten çalışıyor mu?
    expect(PasswordHasher.verify(kTestPass, acc.salt, acc.passwordHash), isTrue);
    expect(PasswordHasher.verify('yanlis', acc.salt, acc.passwordHash), isFalse);
  });

  test('ESKİ biçim (tek turlu SHA-256) kayıtlar doğrulanmaya devam eder', () {
    // Geriye dönük uyumluluk: sürüm yükseltmesinde mevcut hesaplar
    // kilitlenmemelidir.
    const tuz = 'eski-tuz';
    const sifre = '123456';
    final eskiOzet =
        sha256.convert(utf8.encode('$tuz::$sifre')).toString();
    expect(PasswordHasher.verify(sifre, tuz, eskiOzet), isTrue);
    expect(PasswordHasher.verify('yanlis', tuz, eskiOzet), isFalse);
  });

  test('şifre değiştir: mevcut şifre doğrulanır, yenisi hesaba işlenir', () {
    auth.girisEposta(kTestEmail, kTestPass);
    expect(auth.changePassword('yanlis', 'yeni789'), isA<WrongPasswordError>());
    expect(auth.changePassword(kTestPass, 'yeni789'), isNull);
    auth.logout();
    expect(auth.girisEposta(kTestEmail, kTestPass), isA<AuthFailedError>());
    expect(auth.girisEposta(kTestEmail, 'yeni789'), isNull);
  });

  test('şifremi unuttum: kayıtsız numara tip güvenli reddedilir; yeni şifre işlenir', () {
    // ⚠ K5: KAYITSIZ NUMARA DA BAŞARI DÖNER — hesap enumerasyonu
    // yapılmaz. Eskiden `NotFoundError` dönüyordu ve ekran
    // "Sisteme kayıtlı bir numara giriniz" yazıyordu.
    expect(auth.forgotStart('5119998877'), isNull);
    expect(auth.forgotStart(kTestPhone), isNull);
    auth.forgotSave(kTestPhone, 'sifre999');
    expect(auth.girisEposta(kTestEmail, 'sifre999'), isNull);
  });

  test('SMS doğrulamalı telefon güncelleme giriş numarasını da değiştirir', () {
    auth.girisEposta(kTestEmail, kTestPass);
    auth.updatePhoneVerified('5551112299');
    auth.logout();
    // ⚠ Telefon değişti ama E-POSTA aynı: hesap kimliği userId'dir,
    // giriş yine çalışır. Eski numarayla telefon-OTP girişi ise
    // artık mümkün değildir (findByPhone bulmaz).
    expect(auth.girisEposta(kTestEmail, kTestPass), isNull);
    expect(auth.findByPhone(kTestPhone), isNull);
    expect(auth.findByPhone('5551112299'), isNotNull);
  });
}
