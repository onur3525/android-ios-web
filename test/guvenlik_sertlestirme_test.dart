// GÜVENLİK SERTLEŞTİRME — SÖZLEŞME
//
// ⚠ Bu dosya davranışı değil, KURALIN YERİNDE DURDUĞUNU denetler.
// Bir sertleştirme sessizce geri alınırsa burada düşer.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/cihaz_butunlugu.dart';
import 'package:hizmetcep/core/ekran_korumasi.dart';
import 'package:hizmetcep/data/remote/sertifika_sabitleme.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  // ⚠ `MethodChannel` kullanan kod binding olmadan çalışmaz.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EKRAN KORUMASI', () {
    setUp(EkranKorumasi.sayaciSifirla);

    test('HASSAS EKRANLARDA açık', () {
      // Kart, bakiye ve iletişim bilgisi gösteren yüzeyler.
      for (final yol in const [
        'lib/screens/wallet_screen.dart',
        'lib/screens/topup_screen.dart',
        'lib/screens/offer_detail_screen.dart',
      ]) {
        expect(_kod(yol).contains('EkranKorumaliState'), isTrue, reason: yol);
      }
    });

    test('HER EKRANDA AÇILMAZ', () {
      // ⚠ Kullanıcı ilanının ekran görüntüsünü alıp paylaşabilmeli.
      for (final yol in const [
        'lib/screens/home_screen.dart',
        'lib/screens/my_listings_screen.dart',
        'lib/screens/category_screen.dart',
      ]) {
        expect(_kod(yol).contains('EkranKorumaliState'), isFalse, reason: yol);
      }
    });

    test('İÇ İÇE ekranlarda koruma ERKEN KAPANMAZ', () async {
      // Cüzdan → kart formu: ikisi de ister, biri çıkınca kapanmamalı.
      await EkranKorumasi.ac();
      await EkranKorumasi.ac();
      expect(EkranKorumasi.isteyenSayisi, 2);
      await EkranKorumasi.kapat();
      expect(EkranKorumasi.isteyenSayisi, 1,
          reason: 'ilk ekran hâlâ korumayı istiyor');
      await EkranKorumasi.kapat();
      expect(EkranKorumasi.isteyenSayisi, 0);
    });

    test('FAZLA KAPATMA sayacı eksiye düşürmez', () async {
      await EkranKorumasi.kapat();
      await EkranKorumasi.kapat();
      expect(EkranKorumasi.isteyenSayisi, 0);
    });

    test('YEREL KÖPRÜ tanımlı', () {
      final k = File('android/app/src/main/kotlin/com/hizmetcep/app/'
              'MainActivity.kt')
          .readAsStringSync();
      expect(k.contains('hizmetcep/ekran_korumasi'), isTrue);
      expect(k.contains('FLAG_SECURE'), isTrue);
      expect(k.contains('clearFlags'), isTrue,
          reason: 'koruma kapatılamıyor — ekrandan çıkınca açık kalır');
    });
  });

  group('TEŞHİS BAYRAKLARI RELEASE\'TE KAPALI', () {
    test('üç bayrak da kReleaseMode ile kapatılmış', () {
      final k = _kod('lib/core/teshis.dart');
      for (final ad in const ['focusLog', 'noOnChanged', 'staticRegion']) {
        expect(k.contains('$ad = _${ad}Tanim && !kReleaseMode'), isTrue,
            reason: '$ad sürümde açılabilir');
      }
    });

    test('ham fromEnvironment DOĞRUDAN kullanılmıyor', () {
      // ⚠ `bool.fromEnvironment` sonucu doğrudan dışa verilirse
      // sürümde define ile açılabilir.
      final k = _kod('lib/core/teshis.dart');
      expect(k.contains('static const bool focusLog = bool.fromEnvironment'),
          isFalse);
    });
  });

  group('KART ALANLARINDA PANO KAPALI', () {
    final k = _kod('lib/screens/widgets/saved_cards_section.dart');

    test('numara ve CVV kopyalanamaz', () {
      expect('enableInteractiveSelection: false'.allMatches(k).length,
          greaterThanOrEqualTo(2));
      expect('contextMenuBuilder: null'.allMatches(k).length,
          greaterThanOrEqualTo(2));
    });
  });

  group('SERTİFİKA SABİTLEME', () {
    test('PİN YOKKEN devre dışı — davranış değişmez', () {
      // ⚠ Yanlış pinle çıkılan sürüm uygulamayı tamamen kırar; bu
      // yüzden pin verilmedikçe sabitleme kapalıdır.
      expect(SertifikaSabitleme.etkin, isFalse);
      expect(SertifikaSabitleme.pinler, isEmpty);
      expect(SertifikaSabitleme.dogrula(null), isTrue,
          reason: 'kapalıyken her şey geçmeli');
    });

    test('istemci pin yokken SADE döner', () {
      final c = SertifikaSabitleme.istemci();
      expect(c, isA<HttpClient>());
      c.close(force: true);
    });

    test('ApiClient sabitlemeyi KOŞULLU kullanır', () {
      final k = _kod('lib/data/remote/api_client.dart');
      expect(k.contains('SertifikaSabitleme.etkin'), isTrue);
      expect(k.contains('IOClient(SertifikaSabitleme.istemci())'), isTrue);
    });
  });

  group('SERTLEŞTİRME BELGESİ', () {
    test('sürümde yapılacaklar YAZILI', () {
      final d = File('docs/guvenlik_sertlestirme.md').readAsStringSync();
      for (final konu in const [
        'CERT_PINS',
        '--obfuscate',
        'assetlinks.json',
        'FLAG_SECURE',
      ]) {
        expect(d.contains(konu), isTrue, reason: konu);
      }
    });
  });


  group('EKRAN KORUMASI — İLETİŞİM BİLGİSİ EKRANLARI', () {
    test('sohbet ve iş detayında AÇIK', () {
      // ⚠ İletişim açıldıktan sonra karşı tarafın adı ve telefon
      // numarası bu ekranlarda görünür.
      for (final yol in const [
        'lib/screens/chat_screen.dart',
        'lib/screens/job_detail_screen.dart',
      ]) {
        expect(_kod(yol).contains('EkranKorumaliState'), isTrue, reason: yol);
      }
    });
  });

  group('CİHAZ BÜTÜNLÜĞÜ', () {
    tearDown(() => CihazButunlugu.durumuAta(null));

    test('TEMİZ cihaz riskli sayılmaz', () {
      expect(const CihazDurumu().paraIcinRiskli, isFalse);
    });

    test('ROOT ve HATA AYIKLAYICI riskli', () {
      expect(const CihazDurumu(root: true).paraIcinRiskli, isTrue);
      expect(const CihazDurumu(hataAyiklayiciBagli: true).paraIcinRiskli,
          isTrue);
    });

    test('ÖYKÜNÜCÜ riskli SAYILMAZ', () {
      // ⚠ Geliştirme ve test öykünücüde yapılır; riskli saymak günlük
      // çalışmayı bozar.
      expect(const CihazDurumu(oykunucu: true).paraIcinRiskli, isFalse);
    });

    test('BEKLENEN İMZA verilmemişse denetim yapılmaz', () {
      // Yanlış özetle çıkılan sürüm uygulamayı kullanılamaz kılar.
      expect(CihazButunlugu.beklenenImza, isEmpty);
      expect(const CihazDurumu(imzaOzeti: null).imzaBekleneneUyuyor, isTrue);
    });

    test('okuma BAŞARISIZSA kullanıcı engellenmez', () async {
      // Köprü yoksa (test ortamı) temiz kabul edilir.
      final d = await CihazButunlugu.durum();
      expect(d.paraIcinRiskli, isFalse);
    });

    test('YEREL KÖPRÜ tanımlı', () {
      final k = File('android/app/src/main/kotlin/com/hizmetcep/app/'
              'MainActivity.kt')
          .readAsStringSync();
      expect(k.contains('hizmetcep/cihaz_butunlugu'), isTrue);
      expect(k.contains('rootIzleriVar'), isTrue);
      expect(k.contains('imzaOzeti'), isTrue);
      expect(k.contains('isDebuggerConnected'), isTrue);
    });

    test('UYARI ŞERİDİ yalnız riskliyken çizilir', () {
      final t = _kod('lib/screens/topup_screen.dart');
      expect(t.contains('_cihaz?.paraIcinRiskli ?? false'), isTrue);
      // ⚠ İşlem ENGELLENMEZ: düğme yalnız tutar kuralına bakar.
      expect(t.contains('paraIcinRiskli ? null :'), isFalse,
          reason: 'riskli ortamda işlem engellenmiş — yanlış pozitif riski');
    });
  });

  group('SÜRÜM DERLEMESİ KARARTMALI', () {
    final y = File('codemagic.yaml').readAsStringSync();

    test('karartma ve semboller', () {
      expect(y.contains('--obfuscate'), isTrue);
      expect(y.contains('--split-debug-info=build/symbols'), isTrue);
      expect(y.contains('build/symbols/**'), isTrue,
          reason: 'semboller saklanmıyor — çökme raporu çözülemez');
    });

    test('güvenlik tanımları geçiliyor', () {
      for (final t in const [
        'API_BASE_URL',
        'CERT_PINS',
        'APK_SIGNATURE_SHA256',
      ]) {
        expect(y.contains(t), isTrue, reason: t);
      }
    });
  });


  group('MAĞAZA YAYINI HAZIRLIĞI', () {
    test('SÜRÜM mağaza biçiminde', () {
      final pub = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pub);
      expect(m, isNotNull);
      final s = m!.group(1)!;
      // ⚠ Yükleme numarası (+n) ZORUNLU: Play kimliği odur.
      expect(s.contains('+'), isTrue, reason: 'yükleme numarası yok');
      expect(s.startsWith('1.'), isTrue,
          reason: 'mağaza sürümü 1.x olmalı, taslak değil');
    });

    test('AAB üretimi TANIMLI', () {
      final y = File('codemagic.yaml').readAsStringSync();
      // ⚠ Play `.apk` kabul etmez.
      expect(y.contains('flutter build appbundle --release'), isTrue);
      expect(y.contains('bundle/release/*.aab'), isTrue,
          reason: 'aab artefakt olarak toplanmıyor');
    });

    test('İMZASIZ paket SESSİZCE üretilmez', () {
      final y = File('codemagic.yaml').readAsStringSync();
      // Anahtar yoksa iş akışı durur.
      expect(y.contains(r'if [ -z "$KEYSTORE_B64" ]'), isTrue);
      expect(y.contains('exit 1'), isTrue);

      // Gradle tarafı da debug anahtarına düşmez.
      final g = File('android/app/build.gradle').readAsStringSync();
      expect(g.contains('hasKeystore ? signingConfigs.release : null'),
          isTrue);
    });

    test('ANAHTAR DEPOYA GİRMEZ', () {
      final gi = File('android/.gitignore').readAsStringSync();
      expect(gi.contains('key.properties'), isTrue);
      expect(gi.contains('*.jks'), isTrue);
      expect(gi.contains('*.keystore'), isTrue);
      // Örnek dosya kalır (gerçek değer içermez).
      expect(File('android/key.properties.example').existsSync(), isTrue);
      expect(File('android/key.properties').existsSync(), isFalse,
          reason: 'gerçek anahtar dosyası depoda!');
    });

    test('YAYIN BELGESİ eksiksiz', () {
      final d = File('docs/play_store_yayin.md').readAsStringSync();
      for (final konu in const [
        'keytool -genkey',
        'KEYSTORE_B64',
        'appbundle',
        'Gizlilik politikası',
        'Veri güvenliği',
      ]) {
        expect(d.contains(konu), isTrue, reason: konu);
      }
    });
  });


  group('YEREL REFERANS AYRIMI', () {
    test('iptal kararı ApiConfig ile DEĞİL, referansla verilir', () {
      // ⚠ `ApiConfig` ile ayırmak testleri kırıyordu: testler mock
      // modda çalışır ama SAHTE SUNUCU referansı kullanır ve iptal
      // yolunun gerçekten çağrıldığını doğrular.
      final k = _kod('lib/screens/widgets/photo_picker.dart');
      expect(k.contains('bool yerelRef'), isTrue);
      expect(k.contains('if (p.yerelRef) {'), isTrue);
    });

    test('yerel referans SUNUCUYA iptal göndermez', () {
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect(c.contains('!p.yerelRef'), isTrue,
          reason: 'yerel referans için iptal isteği atılıyor');
    });
  });
}
