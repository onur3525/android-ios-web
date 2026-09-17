import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/yonlendirme.dart';
import 'package:hizmetcep/ui/olcu.dart';

/// EKRAN YÖNLENDİRMESİ — TELEFON DİKEY, TABLET SERBEST (KİLİT)
///
/// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): telefonda dikey kilitlenir,
/// tablette yatay kullanıma izin verilir.
///
/// ⚠ BU TESTİN VAR OLMA NEDENİ — İKİ SESSİZ BOZULMA YOLU:
///
///   1. Manifest'e `android:screenOrientation` eklenmesi. Statik
///      kısıt çalışma zamanı kararından önce gelir ve TABLETİ DE
///      kilitler. Derleme geçer, test geçer, yalnız tablette yanlış
///      davranış olur.
///   2. Eşiğin ikinci kez yazılması. Sınır `Kirilma.tablet`tir;
///      ayrı bir 600 yazılırsa biri değişip öteki kalabilir.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  group('1 — Cihaz sınıfı eşiği', () {
    test('sınır değerleri `Kirilma.tablet` ile aynı', () {
      expect(telefonMu(Kirilma.tablet - 1), isTrue);
      expect(telefonMu(Kirilma.tablet), isFalse);
    });

    test('gerçek cihaz ölçüleriyle', () {
      // Telefon en kısa kenarları (dp).
      for (final d in <double>[320, 360, 393, 411, 480, 599]) {
        expect(telefonMu(d), isTrue, reason: '$d dp telefon olmalı');
      }
      // Tablet / katlanabilir açık hâl en kısa kenarları (dp).
      for (final d in <double>[600, 720, 800, 834, 1024]) {
        expect(telefonMu(d), isFalse, reason: '$d dp tablet olmalı');
      }
    });
  });

  group('2 — İzin verilen yönler', () {
    test('telefon YALNIZ dikey yukarı', () {
      expect(kTelefonYonleri, <DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
    });

    test('tablet kısıtsız (boş liste = sistem varsayılanı)', () {
      expect(kTabletYonleri, isEmpty,
          reason: 'tablette yatay izinli olmalı');
    });
  });

  group('3 — ⚠ MANIFEST YÖNLENDİRME YAZMAZ', () {
    test('screenOrientation tanımlı DEĞİL', () {
      final m = oku('android/app/src/main/AndroidManifest.xml');
      expect(m.contains('screenOrientation'), isFalse,
          reason: 'statik kısıt tableti de kilitler; karar çalışma '
              'zamanında verilir');
    });

    test('orientation yapılandırma değişikliği Activity\'de kalır', () {
      // Yön değişiminde Activity yeniden yaratılmamalı.
      final m = oku('android/app/src/main/AndroidManifest.xml');
      expect(m.contains('orientation'), isTrue,
          reason: 'configChanges listesinde orientation olmalı');
    });
  });

  group('4 — ⚠ TEK ÇAĞRI YERİ', () {
    test('main.dart kuralı bir kez uygular', () {
      final m = oku('lib/main.dart');
      expect(m.contains("import 'core/yonlendirme.dart';"), isTrue);
      expect('yonlendirmeyiUygula()'.allMatches(m).length, 1,
          reason: 'kural birden çok yerden uygulanıyor');
    });

    test('ekranlar kendi yönlendirmesini AYARLAMAZ', () {
      final dizin = Directory('lib/screens');
      for (final f in dizin
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        expect(f.readAsStringSync().contains('setPreferredOrientations'),
            isFalse,
            reason: '${f.path}: ekran yönlendirme kısıtını değiştiriyor');
      }
    });

    test('kısıt YALNIZ yonlendirme.dart içinde kurulur', () {
      final dizin = Directory('lib');
      final yerler = <String>[];
      for (final f in dizin
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('setPreferredOrientations')) {
          yerler.add(f.path);
        }
      }
      expect(yerler, ['lib/core/yonlendirme.dart'],
          reason: 'ikinci bir yönlendirme kaynağı oluşmuş');
    });
  });

  group('5 — ⚠ EŞİK ÇOĞALTILMADI', () {
    test('yonlendirme.dart kendi sayısını yazmaz', () {
      final k = oku('lib/core/yonlendirme.dart');
      expect(k.contains('Kirilma.tablet'), isTrue);
    });
  });
}
