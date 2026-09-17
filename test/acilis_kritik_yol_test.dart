// AÇILIŞIN KRİTİK YOLU — PBKDF2 YOK, SİNYAL HEDEF ROTADAN
//
// İki iddia korunur:
//   1. İlk Flutter karesi → boot → navigasyon → hedef kare zincirinde
//      20.000 turluk PBKDF2 ÇALIŞMAZ.
//   2. Native splash'ı bırakma sinyali hedef içeriğin KENDİ kare
//      döngüsünden gider; `Navigator` çağrısının dönmesinden değil.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'support/test_config.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/repositories/demo_hesap_ozetleri.dart';
import 'package:hizmetcep/domain/password_hasher.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  group('ÖNCEDEN HESAPLANMIŞ DEMO ÖZETLERİ', () {
    test('özetler GERÇEKTEN doğrulanıyor', () {
      // ⚠ En kritik test: sabit yanlışsa demo hesaplar giriş yapamaz.
      expect(
          PasswordHasher.verify(kTestPass, kDemoMusteriTuz, kDemoMusteriOzet),
          isTrue,
          reason: 'müşteri özeti geçersiz');
      expect(PasswordHasher.verify(kTestPass, kDemoUstaTuz, kDemoUstaOzet),
          isTrue,
          reason: 'usta özeti geçersiz');
    });

    test('yanlış şifre kabul EDİLMEZ', () {
      expect(PasswordHasher.verify('123457', kDemoUstaTuz, kDemoUstaOzet),
          isFalse);
      expect(PasswordHasher.verify('123456', kDemoMusteriTuz, kDemoUstaOzet),
          isFalse,
          reason: 'tuz/özet çifti karışmış');
    });

    test('tur sayısı değişirse yakalanır', () {
      // Özetler `pbkdf2$<tur>$<hex>` biçimindedir; tur sayısı
      // `PasswordHasher` ile aynı kalmalı.
      final h = _kod('lib/domain/password_hasher.dart');
      final tur = RegExp(r'_turSayisi = (\d+)').firstMatch(h)!.group(1)!;
      expect(kDemoMusteriOzet.startsWith('pbkdf2\$$tur\$'), isTrue);
      expect(kDemoUstaOzet.startsWith('pbkdf2\$$tur\$'), isTrue);
    });
  });

  group('AÇILIŞ YOLUNDA PBKDF2 YOK', () {
    test('AuthRepository KURUCUSU hash hesaplamaz', () {
      // Kurucu `buildPorts` içinde, yani `runApp`'ten ÖNCE çalışır.
      final a = _kod('lib/data/repositories/auth_repository.dart');
      final i = a.indexOf('_seed(hazirTuz: kDemoMusteriTuz');
      expect(i, greaterThan(0), reason: 'tohum hazır özete bağlı değil');
    });

    test('demo usta kaydı da hazır özet kullanır', () {
      final m = _kod('lib/main.dart');
      expect(m.contains('hazirTuz: kDemoUstaTuz, hazirOzet: kDemoUstaOzet'),
          isTrue);
    });

    test('hazır özet verilmeyince davranış AYNI (gerçek kayıt bozulmaz)', () {
      final auth = AuthRepository(seedTestAccount: false);
      final r = auth.register(
        phone: '5551112233',
        pass: 'abc123',
        email: 'a1@example.com',
        role: Role.customer,
        otpVerified: true,
        termsAccepted: true,
      );
      expect(r.account, isNotNull);
      expect(r.account!.passwordHash.startsWith('pbkdf2\$'), isTrue);
      expect(r.account!.salt, isNot(kDemoUstaTuz));
      // ⚠ `login` DomainError? döner: null = BAŞARILI.
      expect(auth.girisEposta('a1@example.com', 'abc123'), isNull);
      expect(auth.currentAccount, isNotNull);
    });

    test('binding YOKKEN de tohumlama çöker DEĞİL, senkron çalışır', () {
      // ⚠ `buildPorts` widget olmayan birim testlerinden de çağrılır.
      // Orada `WidgetsBinding.instance` hata atar; tohumlama bunu
      // yakalayıp doğrudan çalışmalıdır (di_and_guard_test bunu
      // yakalamıştı).
      final m = _kod('lib/main.dart');
      expect(m.contains('} on FlutterError {'), isTrue,
          reason: 'binding yokluğu karşılanmıyor');
      final i = m.indexOf('} on FlutterError {');
      final govde = m.substring(i, i + 200);
      expect(govde.contains("BootLog.olc('SEED_DEMO'"), isTrue,
          reason: 'yedek yolda tohumlama yapılmıyor');
    });

    test('hazır özetle kurulan hesap normal yoldan giriş yapar', () {
      final auth = AuthRepository();
      expect(auth.girisEposta(kTestEmail, kTestPass), isNull,
          reason: 'demo müşteri giriş yapamıyor');
      expect(auth.currentAccount, isNotNull);
    });

    test('yalnız biri verilirse hazır yol KULLANILMAZ', () {
      final auth = AuthRepository(seedTestAccount: false);
      final r = auth.register(
        phone: '5551112244',
        pass: 'abc123',
        email: 'a2@example.com',
        role: Role.customer,
        otpVerified: true,
        termsAccepted: true,
        hazirTuz: kDemoUstaTuz,
      );
      expect(r.account!.salt, isNot(kDemoUstaTuz),
          reason: 'eksik çift kabul edilmiş');
      expect(auth.girisEposta('a2@example.com', 'abc123'), isNull);
      expect(auth.currentAccount, isNotNull);
    });
  });

  group('SİNYAL NAVİGASYONDAN SONRAKİ KARENİN SONUNDA GİDER', () {
    final sp = _kod('lib/screens/splash_screen.dart');
    final m = _kod('lib/main.dart');

    test('geri çağrı NAVİGASYON ÇAĞRISINDAN SONRA kaydedilir', () {
      // Öncesinde kaydedilirse hedef rotayı içermeyen bir karenin
      // sonunda tetiklenir ve splash erken kalkar.
      final i = sp.indexOf("BootLog.olay('NAVIGATION_START', '/home')");
      expect(i, greaterThan(0));
      final iCagri = sp.indexOf('pushReplacementNamed', i);
      final iKayit = sp.indexOf("_navSonrasiKareyiBekle('/home')", i);
      expect(iCagri, greaterThan(i));
      expect(iKayit, greaterThan(iCagri));
    });

    test('sinyal POST_NAV_FRAME_END sonrasında gider', () {
      final i = sp.indexOf('void _navSonrasiKareyiBekle(String hedef) {');
      final govde = sp.substring(i, sp.indexOf('\n  }', i));
      expect(govde.contains('addPostFrameCallback'), isTrue);
      final iOlay = govde.indexOf("POST_NAV_FRAME_END");
      final iBirak = govde.indexOf('_splashBirak()');
      expect(iOlay, greaterThan(-1));
      expect(iBirak, greaterThan(iOlay));
    });

    test('bootReady TEK yerden ve TEK KEZ', () {
      expect('NativeSplash.bootReady()'.allMatches(sp).length, 1);
      expect(sp.contains('bool _splashBirakildi = false;'), isTrue);
      expect(sp.contains('if (_splashBirakildi) {'), isTrue);
    });

    test('kök sarmalayıcı KALDIRILDI', () {
      expect(File('lib/core/ilk_kare_bildirimi.dart').existsSync(), isFalse);
      expect(sp.contains('IlkKareBildirimi'), isFalse);
      expect(m.contains('IlkKareBildirimi'), isFalse);
      // Mevcut builder davranışı korundu.
      expect(
          m.contains(
              'OfflineBanner(child: child ?? const SizedBox.shrink())'),
          isTrue);
    });

    test('yanlış olay adları kullanılmaz', () {
      for (final e in const [
        'TARGET_ROUTE_FIRST_FRAME',
        'TARGET_ROUTE_USABLE',
      ]) {
        expect(sp.contains(e), isFalse, reason: '$e adı geri gelmiş');
      }
    });
  });
}
