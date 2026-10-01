import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/firebase/firebase_baslatici.dart';
import 'package:hizmetcep/core/push/firebase_secenekleri.dart';
import 'package:hizmetcep/data/remote/firebase_kimlik.dart';

/// FIREBASE AUTHENTICATION — istemci tarafı
///
/// Gerçek Firebase bağlantısı `flutter test` ortamında YOKTUR (yerel
/// eklenti yok). Testler: seçeneklerin doğruluğu, başlatıcının ve kimlik
/// hizmetinin Firebase'e ulaşılamadığında ÇÖKMEDEN açık hata döndürmesi,
/// mock/demo akışının değişmemesi ve mimari kilitler.
String _kod(String y) => File(y)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SEÇENEKLER', () {
    test('tek proje; Android/iOS/Web kimlikleri doğru', () {
      expect(FirebaseSecenekleri.android.projectId, 'hizmetcep-fe036');
      expect(FirebaseSecenekleri.android.appId, '1:262578778971:android:bba810a8706baec30b207e');
      expect(FirebaseSecenekleri.ios.appId, '1:262578778971:ios:c86fad4c01cbcf890b207e');
      expect(FirebaseSecenekleri.ios.iosBundleId, 'com.hizmetcep.app');
      expect(FirebaseSecenekleri.web.appId, '1:262578778971:web:9e7e25bb909ab7720b207e');
      expect(FirebaseSecenekleri.web.authDomain, 'hizmetcep-fe036.firebaseapp.com');
    });

    test('Android debug (.debug paketi) kendi Firebase uygulamasını kullanır', () {
      expect(FirebaseSecenekleri.androidDebug.appId, '1:262578778971:android:21cd554a3ae33c500b207e');
      expect(FirebaseSecenekleri.androidDebug.projectId, 'hizmetcep-fe036');
      expect(FirebaseSecenekleri.android.appId, isNot(FirebaseSecenekleri.androidDebug.appId));
    });

    test('seçim derleme türüne göre otomatik; dart-define gerekmez', () {
      final k = _kod('lib/core/push/firebase_secenekleri.dart');
      expect(k.contains('TargetPlatform.android => kDebugMode ? androidDebug : android,'), isTrue);
      expect(k.contains('String.fromEnvironment'), isFalse);
      expect(_kod('android/app/build.gradle').contains('applicationIdSuffix = ".debug"'), isTrue);
    });
  });

  group('BAŞLATMA', () {
    test('Firebase yokken başlatıcı null döner, çökmez', () async {
      expect(await firebaseHazirla(), isNull);
    });

    test('kimlik hizmeti Firebase yokken AÇIK HATA döner, sahte başarı yok', () async {
      final k = await FirebaseKimlik.i.kodGonder('5321112233');
      expect(k.id, isNull);
      expect(k.error, isNotNull);
      final d = await FirebaseKimlik.i.kodDogrula('yok', '123456');
      expect(d.idToken, isNull);
      expect(d.error, isNotNull);
      expect((await FirebaseKimlik.i.epostaSifreGiris('a@b.com', 'x')).idToken, isNull);
    });
  });

  group('MİMARİ KİLİTLER', () {
    test('mock/demo OTP akışı DEĞİŞMEDİ (123456 yalnız test modunda)', () {
      expect(_kod('lib/data/services/otp_service.dart').contains('return TestModu.etkin && code == _debugCode;'), isTrue);
      // Mock port Firebase'i HİÇ kullanmaz.
      expect(_kod('lib/data/ports/mock_ports.dart').contains('FirebaseKimlik'), isFalse);
    });

    test('API modu: Firebase kanıtı sunucuya gider; oturum sunucudan', () {
      final p = _kod('lib/data/ports/api_ports.dart');
      expect(p.contains('return repo.firebaseOturum(r.idToken!);'), isTrue);
      expect(p.contains('firebaseIdToken: kayitYetkisi);'), isTrue);
      expect(p.contains('FirebaseKimlik.i.sifreSifirlamaEpostasi(email)'), isTrue);
    });

    test('istemcide gizli anahtar yok; web Firebase oturumu depoya yazılmaz', () {
      for (final y in ['lib/data/remote/firebase_kimlik.dart', 'lib/core/push/firebase_secenekleri.dart',
          'lib/core/firebase/firebase_baslatici.dart']) {
        final s = File(y).readAsStringSync();
        expect(s.contains('PRIVATE KEY'), isFalse, reason: y);
        expect(s.contains('private_key'), isFalse, reason: y);
      }
      expect(_kod('lib/data/remote/firebase_kimlik.dart').contains('await a.setPersistence(Persistence.NONE);'), isTrue);
    });

    test('push ortak başlatıcıyı kullanır (tek Firebase uygulaması)', () {
      expect(_kod('lib/core/push/push_platform_mobil.dart').contains('if (await firebaseHazirla() == null) {'), isTrue);
    });

    test('iOS reCAPTCHA dönüş şeması tanımlı (APNs yokken telefon doğrulaması)', () {
      expect(File('ios/Runner/Info.plist').readAsStringSync()
          .contains('<string>app-1-262578778971-ios-c86fad4c01cbcf890b207e</string>'), isTrue);
    });
  });

  test('derleme modu bilgisi (rapor)', () {
    debugPrint('kDebugMode=$kDebugMode');
  });
}
