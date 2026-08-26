import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/screens/category_ui.dart';

/// KATEGORİ SUNUM SİSTEMİ — SVG · ad · ana ekran.
///
/// ⚠ Bu testler GERÇEK MAPPING'İ denetler, kaynak metni değil.
String _oku(String p) => File(p).readAsStringSync();

void main() {
  group('58/58 SVG MAPPING', () {
    test('HER KATEGORİNİN İKONU TANIMLI', () {
      // ⚠ EN KRİTİK DENETİM: hiçbir kategori fallback'e düşmemeli.
      final eksik =
          kTreeCategories.where((c) => !kKategoriIkonu.containsKey(c)).toList();
      expect(eksik, isEmpty, reason: 'ikonu olmayan kategori: $eksik');
      expect(kKategoriIkonu.length, 63);
    });

    test('HİÇBİR KATEGORİ FALLBACK İKONA DÜŞMEZ', () {
      for (final c in kTreeCategories) {
        expect(categoryIcon(c), isNot('assets/svg/ic_build.svg'), reason: c);
      }
    });

    test('KATEGORİ SVG DOSYALARI DİSKTE VAR', () {
      for (final c in kTreeCategories) {
        final y = categoryIcon(c);
        expect(File(y).existsSync(), isTrue, reason: '$c → $y yok');
      }
    });

    test('DUPLICATE SVG MAPPING — yalnız ONAYLI istisna', () {
      // İki kategori aynı dosyaya düşerse biri yanlış görünür.
      //
      // ⚠ ONAYLI İSTİSNA: `Halı Yıkama` ile `Koltuk ve Döşeme Yıkama`
      // aynı çizgi ikonu paylaşır. Kategori ikiye bölünürken döşeme
      // yıkama için AYRI bir SVG üretilemedi; kart FOTOĞRAFLARI
      // farklıdır, ızgarada karışmazlar. Ayrı çizim gelince bu
      // istisna kaldırılacaktır.
      // ⚠ İKİNCİ ONAYLI PAYLAŞIM: `Kombi Montaj` + `Kombi Servis`.
      // Kategori ikiye ayrılırken ayrı çizim üretilmedi; ikisi de
      // aynı cihazın işi. Ayrı ikon gelince istisna kaldırılacak.
      const onayliPaylasim = {
        'Halı Yıkama', 'Koltuk ve Döşeme Yıkama',
        'Kombi Montaj', 'Kombi Servis',
      };

      final sayim = <String, List<String>>{};
      kKategoriIkonu.forEach((kategori, yol) {
        sayim.putIfAbsent(yol, () => []).add(kategori);
      });
      final beklenmeyen = sayim.entries
          .where((e) => e.value.length > 1)
          .where((e) => !e.value.every(onayliPaylasim.contains))
          .map((e) => '${e.key} → ${e.value}')
          .toList();
      expect(beklenmeyen, isEmpty,
          reason: 'aynı SVG birden fazla kategoride: $beklenmeyen');
    });

    test('haritada KATALOGDA OLMAYAN anahtar yok', () {
      final fazla = kKategoriIkonu.keys
          .where((k) => !kCategoryTree.containsKey(k))
          .toList();
      expect(fazla, isEmpty, reason: 'ölü anahtar: $fazla');
    });

    test('TÜM SVG AYNI TASARIM AİLESİNDEN', () {
      for (final c in kTreeCategories) {
        final svg = _oku(categoryIcon(c));
        expect(svg.contains('viewBox="0 0 24 24"'), isTrue, reason: c);
        expect(svg.contains('#1D6BE3'), isTrue,
            reason: '$c tek renk sistemine uymuyor');
        expect(svg.contains('.png'), isFalse, reason: '$c raster içeriyor');
      }
    });

    test('hepsi assets/svg/categories/ altında', () {
      for (final c in kTreeCategories) {
        expect(categoryIcon(c).startsWith('assets/svg/categories/'), isTrue,
            reason: c);
      }
    });

    test('BİLİNMEYEN ad teknik fallback döner (çökme yok)', () {
      expect(categoryIcon('Uzay Mühendisliği'), 'assets/svg/ic_build.svg');
      expect(categoryIcon(''), 'assets/svg/ic_build.svg');
      expect(File('assets/svg/ic_build.svg').existsSync(), isTrue);
    });
  });

  group('KATEGORİ ADLARI', () {
    test('58 ana kategori · 517 alt hizmet', () {
      expect(kCategoryTree.length, 160);
      expect(kCategoryTree.values.fold<int>(0, (t, v) => t + v.length), 640);
    });

    test('BOŞ AD YOK', () {
      for (final c in kTreeCategories) {
        expect(c.trim(), isNotEmpty);
      }
    });

    test('DUPLICATE AD YOK', () {
      final n = kTreeCategories
          .map((c) => c.toLowerCase().replaceAll(' ', ''))
          .toList();
      expect(n.toSet().length, n.length);
    });

    test('anlamlandırılan adlar KATALOGDA', () {
      // Tek kelimelik belirsiz başlıklar şemsiye ada çevrildi.
      for (final y in [
        'Kombi Servis',
        'Isıtma Sistemleri',
        'Banyo Tadilat ve Montaj',
        'Mutfak Tadilat ve Dolap',
        'Kapı Montaj ve Tamir',
        'Zemin Kaplama',
        'Mobilya Yapım ve Montaj',
        'Doğalgaz',
        'Yazılım ve Web Hizmetleri',
        'Fotoğraf Çekimi',
        'Güzellik ve Bakım Hizmetleri',
        'Araç Temizlik ve Detaylı Bakım',
      ]) {
        expect(kCategoryTree.containsKey(y), isTrue, reason: y);
      }
    });

    test('ESKİ TEK KELİMELİK adlar KATALOGDA YOK', () {
      for (final e in [
        'Kombi',
        'Isıtma',
        'Banyo',
        'Mutfak',
        'Kapı',
        'Zemin',
        'Fotoğraf',
        'Güzellik',
      ]) {
        expect(kCategoryTree.containsKey(e), isFalse, reason: e);
      }
    });
  });

  group('ANA EKRAN — 12 HIZLI KATEGORİ', () {
    // ⚠ ANA SAYFA VE İLAN EKRANI BİLİNÇLİ OLARAK FARKLI.
    //
    // Bir tur birleştirildi (53 fotoğraflı kart) ve geri alındı:
    // sayfa 18 satır kaydırmaya çıkıyor, 33 fotoğraf + 20 çizim ikon
    // yan yana düşüp görsel bütünlük bozuluyordu.
    //
    //   ana sayfa   → vitrin: sade tek renk ikon
    //   ilan ekranı → seçim: fotoğraf
    // ⚠ `kHizliKategoriler` KALDIRILDI (15 Ağu, ürün kararı).
    //
    // Ana sayfadaki 12 sabit kategori kısayolu yerini ON ÇATIYA
    // bıraktı (`kHizmetAlanlari`). Çatı kapsamı ve bütünlüğü artık
    // `test/hizmet_alanlari_test.dart` içinde denetleniyor.
    test('eski hızlı kategori listesi KALDIRILDI', () {
      final h = _oku('lib/screens/home_screen.dart');
      expect(h.contains('kHizliKategoriler = ['), isFalse,
          reason: 'liste geri gelmiş');
      expect(h.contains('class _CategoryItem'), isFalse,
          reason: 'sade ikon kartı geri gelmiş');
    });

    test('ana sayfada ÇATI PANELİ var', () {
      final h = _oku('lib/screens/home_screen.dart');
      expect(h.contains('HizmetAlanlariPaneli'), isTrue);
      expect(h.contains('kHizmetAlanlari'), isTrue);
      // ⚠ Panel SABİT, içi kayar.
      expect(h.contains('ListView.builder'), isTrue);
    });

    test('TÜM KATEGORİLER bağlantısı KALDIRILDI', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (15 Ağu, ürün kararı).
      //
      // Eskiden ana sayfada 12 sabit kategori kısayolu vardı ve
      // kalanlara "Tüm Kategoriler"den ulaşılıyordu. Artık 12 ÇATI
      // var ve 58 kategorinin HEPSİ bir çatıya bağlı — ayrı tam
      // liste bağlantısı hem gereksiz hem de çatı ayrımını
      // zayıflatıyordu.
      //
      // ⚠ Ekran dosyası (all_categories_screen.dart) silinmedi;
      // yalnız ana sayfadan bağlantısı kaldırıldı.
      final h = _oku('lib/screens/home_screen.dart');
      expect(h.contains('AllCategoriesScreen'), isFalse,
          reason: 'bağlantı geri gelmiş');
      expect(h.contains("'Tüm Kategoriler'"), isFalse);
    });
  });

  group('TÜM KATEGORİLER EKRANI', () {
    test('ALT HİZMET SAYACI YOK', () {
      // ⚠ "7 hizmet" / "5 hizmet" metinleri kaldırıldı: sayı
      // kullanıcıya bir şey anlatmıyordu.
      final k = _oku('lib/screens/all_categories_screen.dart');
      expect(k.contains('altlar.length'), isFalse, reason: 'sayaç kalmış');
    });

    test('kart yapısı: SVG + ad + ok', () {
      final k = _oku('lib/screens/all_categories_screen.dart');
      expect(k.contains('categoryIcon(c)'), isTrue, reason: 'SVG yok');
      expect(k.contains('ic_chev.svg'), isTrue, reason: 'sağ ok yok');
    });

    test('KATALOGDAKİ TÜM kategorileri okur', () {
      final k = _oku('lib/screens/all_categories_screen.dart');
      expect(k.contains('kTreeCategories'), isTrue);
      expect(kTreeCategories.length, 63);
    });
  });

  group('KATEGORİ GÖRSELİ (fotoğraf)', () {
    test('tanımlı fotoğrafların dosyası VAR', () {
      for (final c in kTreeCategories) {
        final a = categoryAsset(c);
        if (a != null) {
          expect(File(a).existsSync(), isTrue, reason: '$c → $a yok');
        }
      }
    });

    test('fotoğrafı OLMAYAN kategori SVG ile çizilir', () {
      // ⚠ Kart HİÇBİR ZAMAN boş kalmaz: fotoğraf yoksa SVG devreye
      // girer ve o da 53/53 tanımlıdır.
      for (final c in kTreeCategories.where((c) => categoryAsset(c) == null)) {
        expect(File(categoryIcon(c)).existsSync(), isTrue, reason: c);
      }
    });

    test('YENİ FOTOĞRAFLAR HARİTADA', () {
      // ⚠ Önceki turda 10 kategori eklenmişti (33 → 43).
      //
      // `Mühendislik ve Proje` daha önce BOZUK görsel (gri degrade)
      // yüzünden haritadan çıkarılmıştı; gerçek fotoğrafla geri geldi.
      for (final k in [
        'Kombi Servis',
        'Alçı ve Sıva İşleri',
        'Kapı Montaj ve Tamir',
        'Oto Çekici ve Yol Yardım',
        'Banyo Tadilat ve Montaj',
        'Oto Servis ve Bakım',
        'Araç Temizlik ve Detaylı Bakım',
        'Mühendislik ve Proje',
        'Özel Ders',
        'Yabancı Dil Eğitimi',
      ]) {
        expect(kCategoryImage.containsKey(k), isTrue, reason: k);
        expect(File(kCategoryImage[k]!).existsSync(), isTrue, reason: k);
      }
    });

    test('SON 10 FOTOĞRAF HARİTADA', () {
      // ⚠ Harita bu turda 43 → 53 oldu; eğitim, dijital, kişisel ve
      // etkinlik kategorileri fotoğrafsız kalan son gruptu.
      for (final k in [
        'Sürücü Eğitimi',
        'Spor ve Kişisel Antrenör',
        'Müzik Dersleri',
        'Yazılım ve Web Hizmetleri',
        'Grafik ve Logo Tasarım',
        'Dijital Pazarlama',
        'Fotoğraf Çekimi',
        'Etkinlik ve Organizasyon',
        'Evcil Hayvan Hizmetleri',
        'Güzellik ve Bakım Hizmetleri',
      ]) {
        expect(kCategoryImage.containsKey(k), isTrue, reason: k);
        expect(File(kCategoryImage[k]!).existsSync(), isTrue, reason: k);
      }
    });

    test('HER KATEGORİNİN FOTOĞRAFI VAR', () {
      // ⚠ Fotoğrafsız kategori HEDEFİ 0'dır. Yeni kategori eklenirse
      // bu test kırılır — kırılması DOĞRUDUR, fotoğrafı da eklenmelidir.
      final fotografsiz =
          kTreeCategories.where((c) => categoryAsset(c) == null).toList();
      expect(fotografsiz, isEmpty, reason: 'fotoğrafsız: $fotografsiz');
      expect(kCategoryImage.length, 63);
    });

    test('FOTOĞRAFLAR TEKNİK ÖLÇÜTE UYAR', () {
      // ⚠ Kart görseli KARE alana yerleşir; dikdörtgen dosyanın
      // kenarları kırpılır. Dosya boyutu da APK'yı şişirmemeli.
      for (final v in kCategoryImage.values) {
        final f = File(v);
        expect(f.existsSync(), isTrue, reason: v);
        expect(v.endsWith('.jpg'), isTrue, reason: '$v jpg değil');
        expect(f.lengthSync(), lessThan(12 * 1024),
            reason: '$v çok büyük (${f.lengthSync() ~/ 1024} KB)');
      }
    });

    test('fotoğraf haritasında ÖLÜ anahtar yok', () {
      // Eski adlarda kalmış kayıt hiçbir kategoriyle eşleşmez.
      for (final k in kCategoryImage.keys) {
        expect(kCategoryTree.containsKey(k), isTrue, reason: 'ölü: $k');
      }
    });
  });
}
