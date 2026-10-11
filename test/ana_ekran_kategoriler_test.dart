import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/screens/category_ui.dart';

/// KATEGORİ SUNUM SİSTEMİ — SVG · ad · ana ekran.
///
/// ⚠ Bu testler GERÇEK MAPPING'İ denetler, kaynak metni değil.
String _oku(String p) => File(p).readAsStringSync();

/// ONAYLI SVG PAYLAŞIMI — TEK KAYNAK (iki test de buradan okur).
///
/// Ayrıntılı gerekçe `DUPLICATE SVG MAPPING` testindeki yorumdadır.
const _onayliPaylasim = <String, Set<String>>{
  'assets/svg/categories/hali_yikama.svg': {
    'Halı Yıkama', 'Koltuk ve Döşeme Yıkama',
  },
  'assets/svg/categories/elektrik.svg': {
    'Elektrik', 'Elektrik Projeleri', 'Jeneratör Servisi',
  },
  'assets/svg/categories/guvenlik.svg': {
    'Güvenlik Sistemleri', 'Özel Güvenlik',
  },
  'assets/svg/categories/klima.svg': {
    'Klima Montaj ve Servis', 'Havalandırma Sistemleri',
  },
  'assets/svg/categories/insaat.svg': {
    'İnşaat ve Kaba Yapı', 'Emlak Danışmanlığı',
  },
  'assets/svg/categories/ozel_ders.svg': {
    'Özel Ders', 'Kişisel Gelişim ve Koçluk', "Kur'an-ı Kerim Eğitimi",
  },
  'assets/svg/categories/yabanci_dil.svg': {
    'Yabancı Dil Eğitimi', 'Tercüme ve Çeviri Hizmetleri',
  },
  'assets/svg/categories/muzik.svg': {
    'Müzik Dersleri', 'Müzik & Ses Prodüksiyonu', 'Müzik & Eğlence',
    'İlahi ve Dini Musiki',
  },
  'assets/svg/categories/yazilim.svg': {
    'Yazılım ve Web Hizmetleri', 'Kodlama ve Yazılım Eğitimi',
  },
  'assets/svg/categories/organizasyon.svg': {
    'Etkinlik ve Organizasyon', 'Nikah ve Tören Hizmetleri',
  },
};

void main() {
  group('58/58 SVG MAPPING', () {
    test('HER KATEGORİNİN İKONU TANIMLI', () {
      // ⚠ EN KRİTİK DENETİM: hiçbir kategori fallback'e düşmemeli.
      final eksik =
          kTreeCategories.where((c) => !kKategoriIkonu.containsKey(c)).toList();
      expect(eksik, isEmpty, reason: 'ikonu olmayan kategori: $eksik');
      expect(kKategoriIkonu.length, 166);
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
      // ⚠ ONAYLI PAYLAŞIM GRUP BAZLIDIR (11 Eki, kullanıcı onayı).
      //
      // Eskiden düz bir ad kümesiydi: kümedeki HERHANGİ iki kategori
      // aynı dosyaya düşse test geçerdi (ilgisiz iki onaylı kategori
      // sessizce aynı ikonu paylaşabilirdi). Artık her izin TEK BİR
      // dosyaya bağlıdır; o dosyayı kullanan kategorilerin TAMAMI o
      // dosyanın izin kümesinde olmalıdır.
      //
      // Kabul ölçütü: aynı KONU, FARKLI çatı. Aynı çatı ekranında
      // yan yana duran kategoriler ayırt edilebilmeli; onlara izin
      // VERİLMEZ, ayrı ikon gerekir.
      //
      //   · Halı Yıkama + Koltuk ve Döşeme Yıkama — kategori ikiye
      //     bölünürken ayrı SVG üretilemedi (eski onaylı istisna).
      //   · Diğerleri — aynı konunun başka çatıdaki karşılığı
      //     (müzik, yazılım, dil, eğitim, bina, kalkan, klima, tören).
      //
      // ⚠ Eski `Kombi Montaj` + `Kombi Servis` istisnası KALDIRILDI:
      // kilitli katalogda ayrı "Kombi Montaj" kategorisi yok.
      final sayim = <String, List<String>>{};
      kKategoriIkonu.forEach((kategori, yol) {
        sayim.putIfAbsent(yol, () => []).add(kategori);
      });
      final beklenmeyen = <String>[];
      for (final e in sayim.entries) {
        if (e.value.length < 2) {
          continue;
        }
        final izinli = _onayliPaylasim[e.key] ?? const <String>{};
        final izinsiz = e.value.where((k) => !izinli.contains(k)).toList();
        if (izinsiz.isNotEmpty) {
          beklenmeyen.add('${e.key} → izinsiz: $izinsiz');
        }
      }
      expect(beklenmeyen, isEmpty,
          reason: 'aynı SVG birden fazla kategoride: $beklenmeyen');
    });

    test('ONAYLI PAYLAŞIM LİSTESİNDE ÖLÜ KAYIT YOK', () {
      // ⚠ NİÇİN VAR: eski `Kombi Montaj` istisnası kategori katalogdan
      // çıktıktan sonra da listede kaldı ve kimse fark etmedi. İzin
      // verilen her kategori katalogda olmalı ve GERÇEKTEN o dosyayı
      // kullanmalı.
      //
      // Liste TEK KAYNAKTIR (`_onayliPaylasim`); burada yalnız
      // dosya → kategori bağının canlı olduğu denetlenir.
      final olu = <String>[];
      for (final e in _onayliPaylasim.entries) {
        for (final k in e.value) {
          if (!kCategoryTree.containsKey(k)) {
            olu.add('$k (katalogda yok)');
          } else if (kKategoriIkonu[k] != e.key) {
            olu.add('$k (artık ${e.key} kullanmıyor)');
          }
        }
      }
      expect(olu, isEmpty, reason: 'ölü istisna kaydı: $olu');
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
      expect(kCategoryTree.length, 166);
      expect(kCategoryTree.values.fold<int>(0, (t, v) => t + v.length), 1587);
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
        // ⚠ Kilitli katalogda kapı kategorisinin adı 'Kapı Sistemleri'.
        'Kapı Sistemleri',
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
      // ⚠ Ekran dosyası (all_categories_screen.dart) ölü koddu ve SİLİNDİ;
      final h = _oku('lib/screens/home_screen.dart');
      expect(h.contains('AllCategoriesScreen'), isFalse,
          reason: 'bağlantı geri gelmiş');
      expect(h.contains("'Tüm Kategoriler'"), isFalse);
    });
  });

  group('TÜM KATEGORİLER EKRANI', () {
    test('ölü ekran SİLİNDİ, bağlantı yok', () {
      expect(File('lib/screens/all_categories_screen.dart').existsSync(),
          isFalse);
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
        // ⚠ Kilitli katalog adları: 'Kapı Montaj ve Tamir' →
        // 'Kapı Sistemleri' (aynı `kapi.jpg`). 'Mühendislik ve Proje'
        // kategorisi bölündüğü için listeden çıktı.
        'Kapı Sistemleri',
        'Oto Çekici ve Yol Yardım',
        'Banyo Tadilat ve Montaj',
        'Oto Servis ve Bakım',
        'Araç Temizlik ve Detaylı Bakım',
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
        // ⚠ Kilitli katalogda adı 'Spor' (aynı `spor.jpg`).
        'Spor',
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
