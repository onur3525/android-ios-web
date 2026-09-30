import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/region.dart';

/// BÖLGE VERİSİ — model sözleşmesi ve statik kaynak taraması.
void main() {
  const sample = {
    'cities': [
      {
        'id': 'c1',
        'name': 'İzmir',
        'districts': [
          {
            'id': 'd1',
            'name': 'Konak',
            'allDistrictsSupported': false,
            'neighborhoods': [
              {'id': 'n1', 'name': 'Alsancak'},
              {'id': 'n2', 'name': 'Güzelyalı'},
            ],
          },
        ],
      },
    ],
  };

  group('RegionTree ayrıştırma', () {
    test('sunucu cevabı doğru ayrıştırılır', () {
      final t = RegionTree.fromJson(sample);
      expect(t.cities, hasLength(1));
      expect(t.primaryCity!.name, 'İzmir');
      expect(t.primaryCity!.districtNames, ['Konak']);
      expect(t.neighborhoodsOf('Konak'), ['Alsancak', 'Güzelyalı']);
    });

    test('allDistrictsSupported BACKEND\'den okunur (sabit değil)', () {
      final t = RegionTree.fromJson(sample);
      expect(t.primaryCity!.districts.first.allDistrictsSupported, isFalse);
    });

    test('eksik alanlar çökertmez', () {
      final t = RegionTree.fromJson(const {});
      expect(t.isEmpty, isTrue);
      expect(t.primaryCity, isNull);
      expect(t.neighborhoodsOf('Konak'), isEmpty);
    });

    test('bilinmeyen ilçede boş mahalle listesi', () {
      final t = RegionTree.fromJson(sample);
      expect(t.neighborhoodsOf('Bornova'), isEmpty);
      expect(t.cityByName('Ankara'), isNull);
    });

    test('allDistrictsSupported alanı yoksa false varsayılır', () {
      final d = District.fromJson(const {'id': 'x', 'name': 'Y'});
      expect(d.allDistrictsSupported, isFalse);
    });
  });

  /// Bu testler kaynak dosyaları okur: production ekranlarının sabit
  /// bölge verisine dönmediğini ve callback'lerde watch kullanılmadığını
  /// derleyici olmadan da yakalar.
  group('Statik kaynak sözleşmesi', () {
    const screens = [
      'lib/screens/addresses_screen.dart',
      'lib/screens/register_screen.dart',
      'lib/screens/create_listing_screen.dart',
      'lib/screens/my_areas_screen.dart',
    ];

    String read(String p) => File(p).readAsStringSync();

    test('production ekranları SABİT bölge dosyalarını import ETMEZ', () {
      for (final f in screens) {
        final src = read(f);
        expect(src.contains("import '../data/izmir_neighborhoods.dart'"), isFalse,
            reason: '$f mahalle sabitini import ediyor');
        // izmir.dart yalnız KATEGORİ sabiti için kalabilir; bölge
        // sembolleri kullanılmamalı.
        expect(src.contains('kIzmirDistricts'), isFalse, reason: f);
        expect(src.contains('neighborhoodsOf(') &&
            !src.contains('RegionController'), isFalse, reason: f);
      }
    });

    test('bölge verisi RegionController üzerinden okunur', () {
      for (final f in [
        'lib/screens/addresses_screen.dart',
        'lib/screens/register_screen.dart',
        'lib/screens/create_listing_screen.dart',
        'lib/screens/my_areas_screen.dart',
      ]) {
        expect(read(f).contains('RegionController'), isTrue, reason: f);
      }
    });

    test('HATALI string interpolation yok', () {
      for (final f in screens) {
        expect(read(f).contains(r'$('), isFalse, reason: '$f hatalı interpolation');
      }
    });

    test('CALLBACK içinde watch kullanılmaz (my_areas)', () {
      final src = read('lib/screens/my_areas_screen.dart');
      // Seçim yardımcıları ve handler'lar read kullanmalı.
      expect(src.contains('_selected = {...context.watch'), isFalse);
      expect(src.contains('_selected = {...context.read'), isTrue);
    });

    test('mahalle SERBEST METİN olarak alınmaz', () {
      // ⚠ İlan akışının 2. adımında konum SORULMAZ; mahalle yalnız
      // kayıt ekranında ve adres ekranında seçilir. Bu yüzden
      // `create_listing_screen` bu kontrolden ÇIKARILDI.
      for (final f in [
        'lib/screens/register_screen.dart',
        'lib/screens/addresses_screen.dart',
      ]) {
        final src = read(f);
        // Mahalle seçici ile alınır.
        expect(src.contains('RegionPickerSheet'), isTrue, reason: f);
        expect(src.contains("labelText: 'Mahalle *'"), isFalse, reason: f);
      }
    });

    test('ilan akışında mahalle SERBEST METİN alanı YOK', () {
      final src = read('lib/screens/create_listing_screen.dart');
      expect(src.contains("labelText: 'Mahalle *'"), isFalse);
      expect(src.contains("RefFieldLabel('Mahalle'"), isFalse);
    });
  });
}
