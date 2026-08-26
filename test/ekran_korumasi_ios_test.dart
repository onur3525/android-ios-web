import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/ekran_korumasi.dart';

/// EKRAN KORUMASI — İKİ PLATFORM, TEK SÖZLEŞME
///
/// ⚠ ANDROID DALI DEĞİŞMEDİ. Bu turda yalnız iOS eklendi; Android'in
/// `FLAG_SECURE` davranışı, sayaç mantığı ve hata yutma kuralı aynen
/// duruyor. Aşağıdaki testler bunu ayrıca kilitler.
///
/// ⚠ YAPILAN İŞ İKİ PLATFORMDA FARKLIDIR ve farklı olmak zorundadır:
///   • Android → `FLAG_SECURE` (ekran görüntüsü + kayıt + önizleme)
///   • iOS     → yalnız ÖNİZLEME KARARTMASI (arka plan örtüsü)
/// iOS'ta ekran görüntüsü ENGELLENEMEZ; işletim sistemi böyle bir
/// anahtar sunmaz. Bu bir eksiklik değil, platform gerçeğidir.
String _oku(String p) => File(p).readAsStringSync();

void main() {
  // ⚠ BINDING ZORUNLU — TEST BUNSUZ HİÇ ÇALIŞMIYORDU.
  //
  // `EkranKorumasi.ac()` bir `MethodChannel` çağırır; kanal
  // `ServicesBinding.instance` üzerinden mesajlaşır. Binding
  // başlatılmadan çağrılınca "Binding has not yet been initialized"
  // hatası atar ve test daha ilk satırda düşer.
  //
  // ⚠ Yerel köprü YİNE YOKTUR: kanal `MissingPluginException` atar ve
  // sınıf onu bilerek yutar. Ölçtüğümüz şey kanalın cevabı değil,
  // SAYACIN davranışıdır.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(EkranKorumasi.sayaciSifirla);
  tearDown(EkranKorumasi.sayaciSifirla);

  /// ⚠ Platform geçersiz kılması GÖVDE BİTMEDEN sıfırlanır.
  ///
  /// Flutter, gövdenin hemen ardından
  /// `debugAssertAllFoundationVarsUnset` denetimi yapıyor. NE
  /// `tearDown` NE `addTearDown` yetiyor — ikisi de o denetimden
  /// SONRA çalışıyor ve test "foundation debug variable was changed"
  /// diye düşüyor. (İkisi de ayrı koşularda denendi.)
  ///
  /// Doğrusu sıfırlamayı gövdenin içinde, `finally` ile yapmaktır.
  Future<void> platformda(
      TargetPlatform p, Future<void> Function() govde) async {
    debugDefaultTargetPlatformOverride = p;
    try {
      await govde();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('1 — Desteklenen platformlar', () {
    // ⚠ Test ortamında yerel köprü YOKTUR; `invokeMethod`
    // `MissingPluginException` atar ve sınıf onu bilerek yutar.
    // Ölçtüğümüz şey SAYAÇ: platform destekleniyorsa sayaç artar.
    test('ANDROID: sayaç artar (davranış korundu)', () async {
      await platformda(TargetPlatform.android, () async {
        await EkranKorumasi.ac();
        expect(EkranKorumasi.isteyenSayisi, 1,
            reason: 'Android koruması kapanmış');
        await EkranKorumasi.kapat();
        expect(EkranKorumasi.isteyenSayisi, 0);
      });
    });

    test('iOS: sayaç artar (YENİ)', () async {
      await platformda(TargetPlatform.iOS, () async {
        await EkranKorumasi.ac();
        expect(EkranKorumasi.isteyenSayisi, 1,
            reason: 'iOS dalı eklenmemiş');
        await EkranKorumasi.kapat();
        expect(EkranKorumasi.isteyenSayisi, 0);
      });
    });

    test('desteklenmeyen platformda sayaç ARTMAZ', () async {
      await platformda(TargetPlatform.linux, () async {
        await EkranKorumasi.ac();
        expect(EkranKorumasi.isteyenSayisi, 0);
      });
    });
  });

  group('2 — Sayaç mantığı (iç içe ekranlar) DEĞİŞMEDİ', () {
    // Cüzdan → kart formu: iki ekran üst üste biner. İkincisi
    // kapanınca koruma kapanmamalı, alttaki cüzdan hâlâ hassas.
    test('iki isteyen, biri çıkınca koruma sürer', () async {
      await platformda(TargetPlatform.iOS, () async {
        await EkranKorumasi.ac();
        await EkranKorumasi.ac();
        expect(EkranKorumasi.isteyenSayisi, 2);
        await EkranKorumasi.kapat();
        expect(EkranKorumasi.isteyenSayisi, 1,
            reason: 'üstteki ekran kapanınca alttaki korumasız kaldı');
        await EkranKorumasi.kapat();
        expect(EkranKorumasi.isteyenSayisi, 0);
      });
    });

    test('fazladan kapat sayacı eksiye düşürmez', () async {
      await platformda(TargetPlatform.android, () async {
        await EkranKorumasi.kapat();
        expect(EkranKorumasi.isteyenSayisi, 0);
      });
    });
  });

  group('3 — Kaynak sözleşmesi', () {
    test('Android dalı yerinde', () {
      final k = _oku('lib/core/ekran_korumasi.dart');
      expect(k.contains('defaultTargetPlatform == TargetPlatform.android'),
          isTrue,
          reason: 'Android koşulu kaldırılmış');
      expect(k.contains('defaultTargetPlatform == TargetPlatform.iOS'), isTrue,
          reason: 'iOS koşulu yok');
      expect(k.contains('!kIsWeb'), isTrue,
          reason: 'web koruması kalkmış');
    });

    test('Android yerel tarafı DEĞİŞMEDİ — FLAG_SECURE duruyor', () {
      final m = _oku(
          'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt');
      expect(m.contains('FLAG_SECURE'), isTrue);
      expect(m.contains('hizmetcep/ekran_korumasi'), isTrue,
          reason: 'Android kanal adı değişmiş');
    });

    test('iOS yerel tarafı örtü mekanizmasını kurar', () {
      final a = _oku('ios/Runner/AppDelegate.swift');
      expect(a.contains('hizmetcep/ekran_korumasi'), isTrue,
          reason: 'iOS AYNI kanal adını kullanmalı');
      // ⚠ Örtü `willResignActive`'de konur: sistem görev değiştirici
      // görüntüsünü uygulama tam arka plana düşmeden ÖNCE alır.
      expect(a.contains('applicationWillResignActive'), isTrue,
          reason: 'örtü geç konuyor — önizleme karesi yakalanır');
      expect(a.contains('applicationDidBecomeActive'), isTrue,
          reason: 'örtü kaldırılmıyor — ekran kapalı kalır');
      expect(a.contains('addPrivacyCover'), isTrue);
      expect(a.contains('removePrivacyCover'), isTrue);
      // `kapat` gelince örtü de bırakılmalı.
      expect(a.contains('case "kapat"'), isTrue);
      expect(a.contains('case "ac"'), isTrue);
    });
  });

  group('4 — Hassas ekranlar karışımı kullanıyor', () {
    // İki platform da AYNI beş ekranı korur; ekran listesi
    // platforma göre AYRILMAZ.
    for (final yol in [
      'lib/screens/wallet_screen.dart',
      'lib/screens/topup_screen.dart',
      'lib/screens/job_detail_screen.dart',
      'lib/screens/chat_screen.dart',
      'lib/screens/offer_detail_screen.dart',
    ]) {
      test(yol, () {
        final k = _oku(yol);
        expect(k.contains('EkranKoruma'), isTrue,
            reason: '$yol koruma karışımını kullanmıyor');
      });
    }
  });
}
