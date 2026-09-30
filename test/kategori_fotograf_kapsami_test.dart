// KATEGORİ FOTOĞRAFI — KAPSAM KİLİDİ
//
// İŞ KURALI: kategori fotoğrafı (`assets/categories/*.jpg`) YALNIZCA
// ilan verme ekranında görünür:
//   · `/customer/new-listing` — kayıtlı kullanıcı
//   · `/listing/new`          — kayıtsız (ana sayfa arama çubuğu akışı)
// İkisi de ortak `CreateListingScreen`'i çizer.
//
// Diğer tüm ekranlarda (ana sayfa, Tüm Kategoriler, kategori detayı,
// arama sonucu, kayıt, rol değiştirme, kategorilerim) SVG ikon
// kullanılır.
//
// ⚠ Bu dosya KAYNAK METNİ denetler. Yorum satırları elenir; aksi hâlde
// açıklamalarda geçen `kCategoryImage` sözcüğü yanlış alarm verir.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/screens/category_ui.dart';

/// Dosyanın YORUMSUZ kaynağı.
String _kod(String yol) {
  final f = File(yol);
  // ⚠ BURADA `expect` KULLANILMAZ.
  //
  // Bu yardımcı `group(...)` gövdesinde de çağrılıyor; `expect` bir
  // test gövdesi dışında çalışınca `OutsideTestException` atar ve
  // DOSYANIN TAMAMI yüklenemez ("Failed to load"). Eksik dosya
  // durumu düz bir istisnayla bildirilir.
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

/// `lib/` altındaki tüm dart dosyaları.
List<String> _libDosyalari() {
  final out = <String>[];
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      out.add(e.path);
    }
  }
  out.sort();
  return out;
}

void main() {
  group('FOTOĞRAF YALNIZ İLAN VERME EKRANINDA', () {
    test('kategori fotoğrafını HİÇBİR dosya çizmez', () {
      // ⚠ ÖLÇÜLDÜ: fotoğrafı çizen tek bileşen olan `KategoriKarti`
      // hiçbir ekranda kullanılmıyordu (ölü kod) ve SİLİNDİ. Artık
      // `kCategoryImage`'ı bir Image widget'ına veren dosya YOK; biri
      // çizmeye başlarsa bu test kırılır — kırılması DOĞRUDUR.
      final cizenler = <String>[];
      for (final yol in _libDosyalari()) {
        final k = _kod(yol);
        final okur = k.contains('kCategoryImage[') || k.contains('categoryAsset(');
        final cizer = k.contains('Image.asset(');
        if (okur && cizer) {
          cizenler.add(yol);
        }
      }
      expect(cizenler, isEmpty,
          reason: 'fotoğrafı çizen beklenmeyen dosya: $cizenler');
    });

    test('KategoriKarti YALNIZ ilan verme ekranında kullanılır', () {
      final kullananlar = <String>[];
      for (final yol in _libDosyalari()) {
        if (_kod(yol).contains('KategoriKarti(')) {
          kullananlar.add(yol);
        }
      }
      // ⚠ ARTIK HİÇBİR EKRAN KULLANMIYOR. İlan verme ekranındaki
      expect(kullananlar, isEmpty,
          reason: 'fotoğraflı kart geri gelmiş: $kullananlar');
    });

    test('CreateListingScreen İKİ ROTADAN da çizilir', () {
      // Kayıtlı akış main.dart'ta, kayıtsız akış PreLoginListingRoute'ta.
      expect(_kod('lib/main.dart').contains('CreateListingScreen'), isTrue,
          reason: 'kayıtlı ilan verme rotası kaybolmuş');
      expect(
          _kod('lib/screens/prelogin_listing_route.dart')
              .contains('CreateListingScreen'),
          isTrue,
          reason: 'kayıtsız ilan verme rotası kaybolmuş');
    });
  });

  group('DİĞER EKRANLARDA FOTOĞRAF YOK', () {
    // ⚠ Liste ELLE tutulur: yeni bir ekran fotoğraf çizmeye başlarsa
    // yukarıdaki "tek dosya" testi zaten yakalar; buradakiler geçmişte
    // fotoğraf göstermiş veya gösterme riski yüksek olan ekranlardır.
    const ekranlar = [
      'lib/screens/home_screen.dart',
      'lib/screens/category_screen.dart',
      'lib/screens/my_categories_screen.dart',
      'lib/screens/register_screen.dart',
      'lib/screens/role_switch_screen.dart',
      'lib/screens/widgets/inline_search_box.dart',
      'lib/screens/widgets/kategori_secim_paneli.dart',
    ];

    for (final yol in ekranlar) {
      test('${yol.split('/').last} fotoğraf OKUMAZ', () {
        final k = _kod(yol);
        expect(k.contains('kCategoryImage'), isFalse, reason: yol);
        expect(k.contains('categoryAsset('), isFalse, reason: yol);
        expect(k.contains('assets/categories/'), isFalse, reason: yol);
      });
    }

    test('CategoryBadge SVG rozetidir — fotoğraf çizmez', () {
      final k = _kod('lib/screens/category_ui.dart');
      final bas = k.indexOf('class CategoryBadge');
      expect(bas, greaterThan(-1));
      final govde = k.substring(bas);
      expect(govde.contains('Image.asset('), isFalse,
          reason: 'CategoryBadge fotoğrafa dönmüş');
      expect(govde.contains('categoryIcon('), isTrue,
          reason: 'CategoryBadge SVG çizmiyor');
    });

    test('ölü fotoğraf bileşeni CategoryCover kalmadı', () {
      expect(_kod('lib/screens/category_ui.dart').contains('class CategoryCover'),
          isFalse);
    });
  });

  group('KATALOG İKİ SEVİYELİDİR', () {
    test('54 ana kategori, her birinin alt hizmeti var', () {
      // ⚠ 54 → 55: kombi ikiye ayrıldı (Montaj + Servis).
      expect(kTreeCategories.length, 63);
      for (final c in kTreeCategories) {
        expect(kCategoryTree[c], isNotEmpty, reason: '$c alt hizmetsiz');
      }
    });

    test('fotoğraf ANA KATEGORİ seviyesindedir', () {
      // Alt hizmetlerin ayrı fotoğrafı YOKTUR; ızgara ana kategori
      // gösterir, alt hizmet arama önerisinden seçilir.
      // ⚠ İSTİSNA: alt hizmet KENDİ ANA KATEGORİSİYLE aynı adı
      // taşıyorsa fotoğraf zaten ana kategorininkidir, ayrı bir
      // fotoğraf tanımlanmış olmaz. `Halı Yıkama` böyledir.
      final altlar = <String>{};
      for (final e in kCategoryTree.entries) {
        for (final a in e.value) {
          if (a != e.key) {
            altlar.add(a);
          }
        }
      }
      for (final k in kCategoryImage.keys) {
        expect(kTreeCategories.contains(k), isTrue, reason: 'ana değil: $k');
      }
      final altFotografli = altlar.where(kCategoryImage.containsKey).toList();
      expect(altFotografli, isEmpty,
          reason: 'alt hizmete fotoğraf tanımlanmış: $altFotografli');
    });

    test('her ana kategorinin SVG ikonu var (53/53)', () {
      for (final c in kTreeCategories) {
        expect(File(categoryIcon(c)).existsSync(), isTrue, reason: c);
      }
    });
  });
}
