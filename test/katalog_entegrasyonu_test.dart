import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/data/hizmet_alanlari.dart';
import 'package:hizmetcep/data/remote/api/category_api.dart';
import 'package:hizmetcep/data/services/search_service.dart';

/// KATALOG ENTEGRASYONU — GERÇEK VERİ AKIŞI
///
/// ⚠ Bu dosya string aramasıyla yetinmez: sunucudan katalog gelmiş
/// gibi davranıp uygulamanın gerçekten yeni veriyi kullandığını
/// ölçer.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  // ⚠ Her testten sonra sunucu verisi geri alınır; sızma olursa
  // sonraki testler sahte katalogla çalışırdı.
  tearDown(() => KatalogKaynagi.i.sifirla());

  group('1 — KANONİK UÇ', () {
    test('GET /categories kullanılır', () {
      final k = _kodu('lib/data/remote/api/category_api.dart');
      expect(k.contains("c.get('/categories')"), isTrue);
    });

    test('⚠ ALTERNATİF KATALOG UCU YOK', () {
      final klasor = Directory('lib/data/remote/api');
      for (final f in klasor.listSync().whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final k = _kodu(f.path);
        for (final yasak in const [
          "'/categories/me'",
          "'/my/categories'",
          "'/mobile/categories'",
          "'/app/categories'",
          "'/catalog'",
        ]) {
          expect(k.contains(yasak), isFalse, reason: '${f.path}: $yasak');
        }
      }
    });
  });

  group('2 — SUNUCU VERİSİ ESAS ALINIR', () {
    test('başlangıçta gömülü katalog kullanılır', () {
      expect(KatalogKaynagi.i.sunucudanGeldi, isFalse);
      expect(kCategoryTree.length, kGomuluKatalog.length);
    });

    test('⚠ SUNUCU KATALOĞU GELİNCE O KULLANILIR', () {
      KatalogKaynagi.i.guncelle({
        'Yeni Meslek': ['Yeni Hizmet A', 'Yeni Hizmet B'],
      });
      expect(KatalogKaynagi.i.sunucudanGeldi, isTrue);
      expect(kCategoryTree.length, 1);
      expect(kCategoryTree['Yeni Meslek'], ['Yeni Hizmet A', 'Yeni Hizmet B']);
      // ⚠ Gömülü liste ÜZERİNE YAZMAZ: kaynak değişti, eski liste
      // artık okunmuyor.
      expect(kCategoryTree.containsKey('Temizlik Hizmetleri'), isFalse);
    });

    test('⚠ ADMIN\'İN EKLEDİĞİ KATEGORİ SÜRÜM OLMADAN GÖRÜNÜR', () {
      final oncekiSayi = kCategoryTree.length;
      final genisletilmis = <String, List<String>>{
        ...kGomuluKatalog,
        'Drone Çekimi': ['Havadan Fotoğraf', 'Havadan Video'],
      };
      KatalogKaynagi.i.guncelle(genisletilmis);
      expect(kCategoryTree.length, oncekiSayi + 1);
      // Arama da yeni kategoriyi görür — çünkü aynı kaynaktan okuyor.
      final vurus = SearchService.services('Drone');
      expect(vurus.any((h) => h.category == 'Drone Çekimi'), isTrue,
          reason: 'yeni kategori aramada çıkmıyor');
    });

    test('⚠ BOŞ KATALOG KABUL EDİLMEZ', () {
      // Geçici sunucu hatası uygulamayı kategorisiz bırakmamalı.
      final oncekiSayi = kCategoryTree.length;
      KatalogKaynagi.i.guncelle({});
      expect(kCategoryTree.length, oncekiSayi);
      expect(KatalogKaynagi.i.sunucudanGeldi, isFalse);
    });
  });

  group('3 — YANIT ÇÖZÜMLEME', () {
    test('sunucu yanıtı doğru çevrilir', () {
      final m = CategoryApi.parse({
        'items': [
          {
            'category': 'Avukatlık ve Hukuk',
            'services': ['Dava Takibi', 'Sözleşme İnceleme'],
          },
        ],
      });
      expect(m, {
        'Avukatlık ve Hukuk': ['Dava Takibi', 'Sözleşme İnceleme'],
      });
    });

    test('⚠ PASİF KATEGORİ ALINMAZ', () {
      // Pasifleştirilen kategori yeni ilanda seçilememeli.
      final m = CategoryApi.parse({
        'items': [
          {'category': 'Aktif', 'services': ['A'], 'active': true},
          {'category': 'Pasif', 'services': ['B'], 'active': false},
        ],
      });
      expect(m.keys, ['Aktif']);
    });

    test('active alanı YOKSA aktif sayılır', () {
      // Yokluğu "pasif" saymak tüm katalogu boşaltırdı.
      final m = CategoryApi.parse({
        'items': [
          {'category': 'Adsız Değil', 'services': ['A']},
        ],
      });
      expect(m.keys, ['Adsız Değil']);
    });

    test('⚠ BOZUK KAYIT ATLANIR, TAHMİN EDİLMEZ', () {
      final m = CategoryApi.parse({
        'items': [
          {'services': ['A']}, // ad yok
          {'category': '  ', 'services': ['A']}, // ad boş
          {'category': 'Hizmetsiz', 'services': []}, // hizmet yok
          {'category': 'Geçerli', 'services': ['A']},
        ],
      });
      expect(m.keys, ['Geçerli']);
    });

    test('items yoksa boş döner', () {
      expect(CategoryApi.parse({}), isEmpty);
      expect(CategoryApi.parse({'items': 'bozuk'}), isEmpty);
    });
  });

  group('4 — KİMLİK İSTEMCİDE ÜRETİLMEZ', () {
    test('⚠ addan/index\'ten kimlik türetilmez', () {
      final k = _kodu('lib/data/remote/api/category_api.dart');
      // Kimlik üretimine işaret eden desenler bulunmamalı.
      for (final yasak in const [
        'hashCode', 'Random', 'indexOf(', 'toString().hashCode'
      ]) {
        expect(k.contains(yasak), isFalse, reason: 'kimlik üretimi: $yasak');
      }
    });

    test('kategori ve hizmet ADIYLA taşınır', () {
      // Bu sistemde kimlik ADIN kendisidir; uydurma bir kimlik alanı
      // EKLENMEDİ (mevcut veri modelinde yok).
      final m = CategoryApi.parse({
        'items': [
          {'category': 'Sigorta', 'services': ['DASK']},
        ],
      });
      expect(m['Sigorta'], ['DASK']);
    });
  });

  group('5 — ÜÇ PLATFORM AYNI KAYNAK', () {
    test('platforma özel katalog dosyası yok', () {
      final pf = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.dart') &&
              RegExp(r'categor.*(android|ios|web)|(android|ios|web).*categor',
                      caseSensitive: false)
                  .hasMatch(f.path))
          .toList();
      expect(pf, isEmpty, reason: 'platforma özel katalog: $pf');
    });

    test('katalog çekimi platform dallanması İÇERMEZ', () {
      final k = _kodu('lib/screens/splash_screen.dart');
      final i = k.indexOf('CATALOG_FETCH_START');
      expect(i, greaterThan(0), reason: 'katalog çekimi yok');
      final blok = k.substring(i, i + 400);
      for (final yasak in const ['Platform.isAndroid', 'Platform.isIOS', 'kIsWeb']) {
        expect(blok.contains(yasak), isFalse, reason: 'platform dalı: $yasak');
      }
    });
  });

  group('6 — GERİYE DÖNÜK UYUMLULUK', () {
    test('⚠ AÇILIŞ BLOKLANMAZ — katalog alınamazsa gömülü kalır', () {
      final k = _kodu('lib/screens/splash_screen.dart');
      final i = k.indexOf('CATALOG_FETCH_START');
      final blok = k.substring(i, i + 500);
      expect(blok.contains('catch'), isTrue,
          reason: 'hata yutulmuyor — açılış kırılabilir');
    });

    test('çatısız kategori uygulamayı KIRMAZ', () {
      KatalogKaynagi.i.guncelle({
        ...kGomuluKatalog,
        'Çatısız Yeni': ['Bir Hizmet'],
      });
      // Çatı eşlemesi gömülüdür; yeni kategori çatısızdır ama bu
      // sorun değil — arama ve katalog erişimi çalışır.
      expect(catisizKategoriler(), contains('Çatısız Yeni'));
      expect(hizmetAlani('Çatısız Yeni', 'Bir Hizmet'), isNull);
      expect(kCategoryTree.containsKey('Çatısız Yeni'), isTrue);
    });

    test('gömülü katalog bütünlüğü korunur', () {
      // ⚠ Denetim GÖMÜLÜ katalog üzerindedir; sunucudan gelen yeni
      // kategoriler bunun dışındadır.
      expect(alanKapsamiTam(), isTrue);
    });
  });
}
