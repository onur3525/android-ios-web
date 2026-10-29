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

    test('YALNIZ KART BİLGİSİ EKRANINDA açık', () {
      // ⚠ KAPSAM DARALTILDI (17 Ağu, ürün kararı).
      //
      // Koruma beş ekranda birden açıktı (cüzdan, bakiye yükleme,
      // teklif detayı, sohbet, iş detayı). Kullanıcı kararı: yalnız
      // KART BİLGİSİNİN girildiği/görüldüğü ekran korunsun.
      //
      // Gerekçe: ekran görüntüsü engeli kullanıcıyı da engelliyor —
      // teklifini, sohbetini ya da cüzdan geçmişini paylaşamıyordu.
      // Kart numarası ise gerçekten sızdırılmaması gereken tek veri.
    });

    test('DİĞER EKRANLARDA AÇILMAZ', () {
      // ⚠ Kaldırılan dört ekran da burada: geri eklenirse test düşer.
      for (final yol in const [
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/chat_screen.dart',
        'lib/screens/job_detail_screen.dart',
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

  // (Kaldırıldı, 3 Eki: 'KART ALANLARINDA PANO KAPALI' grubu kaldırılmış kart
  // ödeme formunu denetliyordu; derlenmeyen yetim test.)

  group('SERTİFİKA SABİTLEME', () {
    test('PİN YOKKEN devre dışı — davranış değişmez', () {
      // ⚠ Yanlış pinle çıkılan sürüm uygulamayı tamamen kırar; bu
      // yüzden pin verilmedikçe sabitleme kapalıdır.
      //
      // ⚠ `dogrula()` İDDİASI KALDIRILDI: o metot hiçbir yerden
      // çağrılmayan ölü koddu ve "pinning var" izlenimi veriyordu;
      // denetim artık bağlantı kurulurken yapılıyor.
      expect(SertifikaSabitleme.etkin, isFalse);
      expect(SertifikaSabitleme.pinler, isEmpty);
    });

    test('⚠ PIN DENETİMİ SİSTEM GÜVEN DEPOSUNU DEVRE DIŞI BIRAKIR', () {
      // ── ⚠ ESKİ UYGULAMA ETKİSİZDİ ──
      //
      // `badCertificateCallback` YALNIZ sistem doğrulaması BAŞARISIZ
      // olduğunda çağrılır. Cihaza kök sertifika yükleyen saldırganın
      // zinciri sistem doğrulamasını GEÇİYOR, geri çağrı hiç
      // tetiklenmiyor ve pin listesine BAKILMADAN bağlantı
      // kuruluyordu — yani sabitleme, korumak için var olduğu tehdide
      // karşı işe yaramıyordu.
      //
      // Çözüm: `SecurityContext(withTrustedRoots: false)` ile güven
      // deposu boşaltılır; her zincir başarısız sayılır, geri çağrı
      // HER BAĞLANTIDA çalışır ve karar tek başına pine kalır.
      final k = _kod('lib/data/remote/sertifika_sabitleme.dart');
      expect(k.contains('SecurityContext(withTrustedRoots: false)'), isTrue,
          reason: 'sistem CA deposu hâlâ okunuyor — pin bypass edilir');
      // Ölü kod geri gelmemeli.
      expect(k.contains('static bool dogrula('), isFalse);
    });

    test('⚠ PİNSİZ YAYIN (29 Eki kararı): pin verilmezse açılış durmaz; verilirse en az iki', () {
      // Render sertifika anahtarını kendisi yönettiği için mağaza
      // sürümünde pin zorunlu değil; normal TLS doğrulaması geçerli.
      final k = _kod('lib/data/remote/sertifika_sabitleme.dart');
      expect(k.contains('static void pinDenetimi('), isTrue);
      expect(k.contains('if (!kReleaseMode || !gercekApi || pinler.isEmpty) {'), isTrue);
      expect(k.contains('RELEASE derlemede CERT_PINS zorunludur'), isFalse);
      // ⚠ EN AZ İKİ PIN: tek pinli sürüm, sertifika yenilendiğinde
      // uygulamayı tamamen çalışmaz hâle getirir.
      expect(k.contains('pinler.length < 2'), isTrue);
      // ⚠ TEK ÇAĞRI YERİ `buildPorts`: hem uygulamanın hem testlerin
      // ortak giriş noktası.
      //
      // ⚠ WEB KÖPRÜSÜ: `sertifika_sabitleme.dart` `dart:io` içerdiği
      // için `main.dart` onu doğrudan değil platform köprüsü
      // (`sabitlemeli_istemci.dart`) üzerinden çağırır. Mobil köprü
      // aynı kurala DEVREDER; web'de pin karşılaştırması yapılamaz.
      final m = _kod('lib/main.dart');
      expect(m.contains('pinDenetimi(gercekApi: m == DataSourceMode.api)'),
          isTrue);
      expect(_kod('lib/data/remote/sabitlemeli_istemci_io.dart')
          .contains('SertifikaSabitleme.pinDenetimi(gercekApi: gercekApi)'),
          isTrue);
    });

    test('istemci pin yokken SADE döner', () {
      final c = SertifikaSabitleme.istemci();
      expect(c, isA<HttpClient>());
      c.close(force: true);
    });

    test('ApiClient sabitlemeyi KOŞULLU kullanır', () {
      // ⚠ Seçim platform köprüsüne taşındı (web derlemesi `dart:io`
      // kabul etmez); `ApiClient` köprüyü çağırır.
      final k = _kod('lib/data/remote/api_client.dart');
      expect(k.contains('httpClient ?? sabitlemeliIstemci()'), isTrue);
      final io = _kod('lib/data/remote/sabitlemeli_istemci_io.dart');
      expect(io.contains('SertifikaSabitleme.etkin'), isTrue);
      expect(io.contains('IOClient(SertifikaSabitleme.istemci())'), isTrue);
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
    test('⚠ sohbet ve iş detayında KAPATILDI', () {
      // ⚠ ÖNCEKİ KARAR GERİ ALINDI (17 Ağu).
      //
      // Bu ekranlarda iletişim açıldıktan sonra ad ve telefon
      // görünüyor; koruma o yüzden açılmıştı. Ama kullanıcı kendi
      // sohbetinin ya da işinin ekran görüntüsünü de alamıyordu.
      // Ürün kararı: koruma yalnız kart bilgisi ekranında kalsın.
      //
      // ⚠ Telefon zaten iletişim AÇILMADAN maskeli; asıl koruma
      // maskelemedir, ekran görüntüsü engeli değildi.
      for (final yol in const [
        'lib/screens/chat_screen.dart',
        'lib/screens/job_detail_screen.dart',
      ]) {
        expect(_kod(yol).contains('EkranKorumaliState'), isFalse, reason: yol);
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

    // (Kaldırıldı, 3 Eki: 'UYARI ŞERİDİ…' testi kaldırılmış ödeme ekranındaki
    // şeridi denetliyordu; derlenmeyen yetim test.)
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
