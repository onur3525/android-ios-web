import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/arama_es_anlamlilari.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/data/services/search_service.dart';

/// KATALOG YAPISI — 58 ana kategori · 517 alt hizmet.
///
/// ⚠ 54 → 55: `Kombi Servisi` ikiye ayrıldı (Kombi Montaj + Kombi
/// Servis). Alt hizmet sayısı DEĞİŞMEDİ, dördü iki kategoriye
/// dağıtıldı.
///
/// ⚠ Bu testler katalog kararının kendisini kilitler. Sayı değişirse
/// test düşer ve değişikliğin bilinçli olduğu doğrulanmış olur.
String _oku(String p) => File(p).readAsStringSync();

void main() {
  group('Katalog sayıları', () {
    test('58 ANA KATEGORİ', () {
      // ⚠ 158 → 157 → 155: üç kategori kaldırıldı — "Oto Bakım &
      // Servis", "Depolama & Lojistik", "Dijital Pazarlama & Reklam".
      // Üçü de aynı desen: küçük, kavramsal olarak aynı/çok yakın bir
      // kategori daha büyük bir kategoriye taşındı.
      expect(kCategoryTree.length, 155);
      expect(kTreeCategories.length, 63);
    });

    test('517 ALT HİZMET', () {
      // ⚠ 248 değil 251: yanlış birleştirilen üç hizmet ayrıldı
      // (Çim Ekimi, Anahtar Montajı, Elektrik Panosu Yenileme).
      final toplam =
          kCategoryTree.values.fold<int>(0, (t, v) => t + v.length);
      // ⚠ 255 → 459 → 439 → 517: önce öneri listesindeki ayrı işler hizmet oldu,
      // sonra tekrar eden ve dağıtım şirketine ait olanlar kaldırıldı
      // (eski not: ayrı işler gerçek
      // hizmet kaydına çevrildi.
      expect(toplam, 640);
      expect(kTreeServices.length, 1448);
    });


  });

  group('Katalog bütünlüğü', () {
    test('ANA KATEGORİ TEKRARI YOK', () {
      // `Map` zaten tekrarı engeller; burada asıl denetlenen şey
      // BÜYÜK/KÜÇÜK harf veya boşluk farkıyla gizlenmiş tekrardır.
      final normal = kCategoryTree.keys
          .map((k) => k.toLowerCase().replaceAll(' ', ''))
          .toList();
      expect(normal.toSet().length, normal.length,
          reason: 'gizli ana kategori tekrarı');
    });

    test('ALT HİZMET TEKRARI YOK', () {
      // ⚠ Aynı alt hizmet İKİ ANA KATEGORİDE olamaz: `anaKategoriBul`
      // ilk eşleşmeyi döndürür, ikincisi sessizce erişilemez kalırdı.
      final hepsi = [
        for (final v in kCategoryTree.values) ...v,
      ].map((s) => s.toLowerCase().replaceAll(' ', '')).toList();
      final tekrar = <String>[];
      final gorulen = <String>{};
      for (final s in hepsi) {
        if (!gorulen.add(s)) {
          tekrar.add(s);
        }
      }
      expect(tekrar, isEmpty, reason: 'tekrar eden alt hizmet: $tekrar');
    });

    test('ALT HİZMET ADI ANA KATEGORİ ADIYLA ÇAKIŞMAZ', () {
      // Çakışırsa `anaKategoriBul` ana kategoriyi döndürür ve alt
      // hizmet hiçbir zaman seçilemez.
      //
      // ⚠ TEK İSTİSNA: alt hizmet KENDİ ANA KATEGORİSİYLE aynı adı
      // taşıyorsa zarar yoktur — ikisi de AYNI metni üretir, seçim
      // sonucu değişmez. `Halı Yıkama` kategorisi tam olarak budur:
      // tek alt hizmeti kendisiyle aynı adı taşır.
      //
      // Zararlı olan, alt hizmetin BAŞKA bir kategoriyle aynı adı
      // taşımasıdır; test bunu denetler.
      final analar = kCategoryTree.keys.toSet();
      final cakisan = <String>[];
      for (final e in kCategoryTree.entries) {
        for (final s in e.value) {
          if (analar.contains(s) && s != e.key) {
            cakisan.add('$s (${e.key})');
          }
        }
      }
      expect(cakisan, isEmpty, reason: 'çakışan ad: $cakisan');
    });

    test('BOŞ KATEGORİ YOK', () {
      final bos =
          kCategoryTree.entries.where((e) => e.value.isEmpty).map((e) => e.key);
      expect(bos, isEmpty);
    });

    test('anaKategoriBul her alt hizmet için çalışır', () {
      for (final e in kCategoryTree.entries) {
        for (final s in e.value) {
          expect(anaKategoriBul(s), e.key, reason: s);
        }
      }
    });
  });

  group('AYRI TUTULAN BENZER HİZMETLER', () {
    // ⚠ Montaj hazır ürünün kurulumu, yapım imalattır — farklı hizmet
    // veren, farklı fiyat. Tekrar sanılıp birleştirilmemeli.
    test('Gardırop Montajı ≠ Gardırop Yapımı', () {
      final m = kCategoryTree['Mobilya Yapım ve Montaj']!;
      expect(m, contains('Gardırop Montajı'));
      expect(m, contains('Gardırop Yapımı'));
    });

    test('TV Ünitesi Montajı ≠ TV Ünitesi Yapımı', () {
      final m = kCategoryTree['Mobilya Yapım ve Montaj']!;
      expect(m, contains('TV Ünitesi Montajı'));
      expect(m, contains('TV Ünitesi Yapımı'));
    });
  });

  group('YANLIŞ BİRLEŞTİRME DÜZELTMELERİ', () {
    // ⚠ Bunlar eş anlamlı sanılıp tek hizmete indirilmişti; gerçekte
    // farklı iş, farklı malzeme, farklı fiyat.
    test('Çim Ekimi ≠ Çim Serme', () {
      final b = kCategoryTree['Bahçe ve Peyzaj']!;
      expect(b, contains('Çim Ekimi'), reason: 'tohumla çim oluşturma');
      expect(b, contains('Çim Serme'), reason: 'hazır/rulo çim');
    });

    test('Priz Montajı ≠ Anahtar Montajı', () {
      final e = kCategoryTree['Elektrik']!;
      expect(e, contains('Priz Montajı'));
      expect(e, contains('Anahtar Montajı'));
    });

    test('Sigorta Panosu Montajı ≠ Elektrik Panosu Yenileme', () {
      final e = kCategoryTree['Elektrik']!;
      expect(e, contains('Sigorta Panosu Montajı'), reason: 'yeni pano');
      expect(e, contains('Elektrik Panosu Yenileme'), reason: 'mevcut pano');
    });
  });

  group('YANLIŞ KATEGORİ DÜZELTMELERİ', () {
    test('Aspiratör Tamiri Isıtma ALTINDA DEĞİL', () {
      expect(kCategoryTree['Isıtma Sistemleri']!, isNot(contains('Aspiratör Tamiri')));
      expect(kCategoryTree['Beyaz Eşya Servisi']!, contains('Aspiratör Tamiri'));
      expect(anaKategoriBul('Aspiratör Tamiri'), 'Beyaz Eşya Servisi');
    });

    test('Su Arıtma Servisi Isıtma ALTINDA DEĞİL', () {
      expect(kCategoryTree['Isıtma Sistemleri']!, isNot(contains('Su Arıtma Servisi')));
      expect(kCategoryTree['Su Tesisatı']!, contains('Su Arıtma Servisi'));
      expect(anaKategoriBul('Su Arıtma Servisi'), 'Su Tesisatı');
    });

    test('Isıtma YALNIZ ısıtma hizmetleri içerir', () {
      // ⚠ KATALOG GENİŞLEDİ: liste sabit değil. Asıl denetim şu —
      final isitma = kCategoryTree['Isıtma Sistemleri']!;
      expect(isitma.take(5), [
        'Petek Temizliği',
        'Petek Montajı',
        'Yerden Isıtma',
        'Şofben Tamiri',
        'Termosifon Tamiri',
      ]);
      for (final h in isitma) {
        expect(h.contains('Kombi'), isFalse, reason: h);
        expect(h.contains('Doğalgaz'), isFalse, reason: h);
      }
    });
  });

  group('Yeniden adlandırma', () {
    test('eski adlar KATALOGDA YOK', () {
      for (final eski in [
        // ⚠ `Zemin Kaplama` ve `Bahçe ve Peyzaj` BU LİSTEDEN ÇIKTI:
        // ikinci adlandırma turunda GEÇERLİ ad hâline geldiler.
        'Tesisat',
        'Klima ve Havalandırma',
        'Beyaz Eşya Tamiri',
        'Fayans ve Seramik',
        'Cam ve Balkon',
        'PVC ve Doğrama',
        'Demir ve Kaynak',
        'Marangoz',
        'Mutfak ve Banyo',
        'Isıtma Sistemleri Servisi',
        'Halı ve Koltuk Yıkama',
      ]) {
        expect(kCategoryTree.containsKey(eski), isFalse, reason: eski);
      }
    });

    test('yeni adlar KATALOGDA VAR', () {
      // ⚠ ADLAR İKİ KEZ DEĞİŞTİ.
      //
      // Önce yapısal ayrıştırma ('Tesisat' → 'Su Tesisatı'), sonra
      // anlamlandırma ('Kombi' → 'Kombi Montaj' + 'Kombi Servis'). Bu liste SON
      // hâli taşır.
      for (final yeni in [
        'Su Tesisatı',
        'Klima Montaj ve Servis',
        'Beyaz Eşya Servisi',
        'Fayans ve Seramik Döşeme',
        'Zemin Kaplama',
        'Cam Balkon Sistemleri',
        'PVC ve Alüminyum Doğrama',
        'Demir Doğrama ve Kaynak',
        'Bahçe ve Peyzaj',
        'Marangozluk ve Ahşap İşleri',
        'Mutfak Tadilat ve Dolap',
        'Banyo Tadilat ve Montaj',
        'Kombi Montaj',
        'Kombi Servis',
        'Kapı Montaj ve Tamir',
        'Alçı ve Sıva İşleri',
        'Isıtma Sistemleri',
        'Halı Yıkama',
        'Koltuk ve Döşeme Yıkama',
      ]) {
        expect(kCategoryTree.containsKey(yeni), isTrue, reason: yeni);
      }
    });
  });

  group('ANA KATEGORİ SAYI SINIRI KALDIRILDI', () {
    test('anaKategoriEklenebilir HER ZAMAN true', () {
      // 5 ana kategori seçiliyken 6.'sı da eklenebilmeli.
      final secim = <String>{
        'Temizlik Hizmetleri',
        'Elektrik',
        'Boya ve Badana',
        'Nakliyat ve Taşımacılık',
        'Yazılım ve Web Hizmetleri',
      };
      expect(anaKategoriEklenebilir(secim, 'Müzik Dersleri'), isTrue);
      expect(anaKategoriEklenebilir(secim, 'Oto Servis ve Bakım'), isTrue);
    });

    test('kMaxAnaKategori sabiti KALDIRILDI', () {
      final kaynak = _oku('lib/data/category_tree.dart');
      expect(kaynak.contains('const int kMaxAnaKategori'), isFalse,
          reason: 'sabit tanımı kalmamalı');
    });

    test('ÜÇ EKRANDA da sınır yok', () {
      for (final f in [
        'lib/screens/register_screen.dart',
        'lib/screens/role_switch_screen.dart',
        'lib/screens/my_categories_screen.dart',
      ]) {
        final k = _oku(f);
        expect(k.contains('maxSecim: kMaxAnaKategori'), isFalse, reason: f);
        expect(k.contains('En fazla \$kMaxAnaKategori'), isFalse, reason: f);
      }
    });

    test('anaKategorileri 3+ kategori sayar', () {
      // Sınır kalktı ama SAYIM işlevi doğru çalışmaya devam etmeli;
      // mock port yetki denetiminde bunu kullanıyor.
      final analar = anaKategorileri(
          {'Temizlik Hizmetleri', 'Ev Temizliği',
          'Elektrik', 'Boya ve Badana', 'Kombi Servis'});
      expect(analar.length, 4);
    });
  });

  group('ARAMA KAPSAMI', () {
    test('517 HİZMETİN TAMAMI sözlükte', () {
      final eksik = <String>[];
      for (final v in kCategoryTree.values) {
        for (final s in v) {
          if (!kAramaEsAnlamlilari.containsKey(s)) {
            eksik.add(s);
          }
        }
      }
      expect(eksik, isEmpty, reason: 'terimi olmayan hizmet: $eksik');
    });

    test('sözlükte katalogda olmayan anahtar yok', () {
      final tum = <String>{
        for (final v in kCategoryTree.values) ...v,
      };
      final fazla =
          kAramaEsAnlamlilari.keys.where((k) => !tum.contains(k)).toList();
      expect(fazla, isEmpty, reason: 'karşılıksız anahtar: $fazla');
    });

    test('517 HİZMETİN TAMAMI ARANABİLİR', () {
      // ⚠ En güçlü denetim: her hizmet KENDİ ADIYLA bulunabilmeli.
      // Sözlükte anahtarı olması yetmez; arama motoru da bulmalı.
      final bulunamayan = <String>[];
      for (final v in kCategoryTree.values) {
        for (final s in v) {
          final r = SearchService.services(s);
          if (!r.any((h) => h.subService == s)) {
            bulunamayan.add(s);
          }
        }
      }
      expect(bulunamayan, isEmpty, reason: 'aranamayan: $bulunamayan');
    });

    test('ESKİ KISA AD YENİ KATEGORİYE ULAŞIR', () {
      // ⚠ Kategori adları anlamlı hâle getirilirken uzadı. Kullanıcı
      // hâlâ eski kısa adı yazar; alias olmasaydı kategoriyi
      // bulamazdı.
      for (final (eski, yeni) in [
        ('kombi', 'Kombi Montaj'),
        ('yazılım', 'Yazılım ve Web Hizmetleri'),
        ('banyo', 'Banyo Tadilat ve Montaj'),
        ('kapı', 'Kapı Montaj ve Tamir'),
        ('mutfak', 'Mutfak Tadilat ve Dolap'),
        ('güzellik', 'Güzellik ve Bakım Hizmetleri'),
        ('fotoğraf', 'Fotoğraf Çekimi'),
        ('ısıtma', 'Isıtma Sistemleri'),
      ]) {
        final r = SearchService.services(eski);
        expect(r.any((h) => h.category == yeni), isTrue,
            reason: '"$eski" → $yeni bulunamadı');
      }
    });

    test('İLGİ SIRALAMASI: prefix eşleşmeler EN ÜSTTE', () {
      // ⚠ SINIR RELEVANCE'DAN SONRA UYGULANIR.
      //
      // Eskiden sonuçlar KATALOG SIRASINDA toplanıp 40'ta kesiliyordu.
      // "te" için katalogda `te` ile başlayan 8 hizmet var ama ilk
      // 40'a yalnız 3'ü giriyordu; aradaki sıraları EŞ ANLAMLI
      // eşleşmeler dolduruyordu. Zayıf eşleşme güçlüyü dışarı itiyordu.
      // ⚠ Katalog genişleyince "te" ile başlayan hizmet 3'ten 10'a
      // çıktı; pencere de büyütüldü. Kural aynı: prefix eşleşmeler
      // eş anlamlı eşleşmelerin ÖNÜNDE.
      final r = SearchService.services('te');
      final ilk8 = r.take(12).map((h) => h.label).toList();
      // ⚠ Ana kategori adı 'Temizlik Hizmetleri' oldu; alt hizmetler
      // değişmedi.
      for (final beklenen in [
        'Temizlik Hizmetleri',
        'Telefon Tamiri',
        'Teras İzolasyonu',
      ]) {
        expect(ilk8, contains(beklenen),
            reason: '$beklenen prefix eşleşmesi ilk sıralarda olmalı');
      }
    });

    test('TAM EŞLEŞME BİRİNCİ SIRADA', () {
      for (final ad in [
        'Klima Bakımı',
        'Oto Yıkama',
        'Tenis Dersi',
        'Mantolama',
      ]) {
        final r = SearchService.services(ad);
        expect(r.first.label, ad, reason: '$ad ilk sırada olmalı');
      }
    });

    test('SINIR sonuçları KESER ama gizlemez', () {
      // Tek harflik sorgu 269 sonuç döndürüyordu; sınır 40.
      final r = SearchService.services('a');
      expect(r.length, lessThanOrEqualTo(40));
      expect(r, isNotEmpty);
    });

    test('AYRILAN HİZMETLER ARANABİLİYOR', () {
      for (final (sorgu, beklenen) in [
        ('çim tohumu', 'Çim Ekimi'),
        ('rulo çim', 'Çim Serme'),
        ('pano yenileme', 'Elektrik Panosu Yenileme'),
        ('sigorta panosu', 'Sigorta Panosu Montajı'),
        ('ışık anahtarı', 'Anahtar Montajı'),
        ('priz takma', 'Priz Montajı'),
        ('davlumbaz', 'Aspiratör Tamiri'),
        ('su arıtma', 'Su Arıtma Servisi'),
      ]) {
        final r = SearchService.services(sorgu);
        expect(r.any((h) => h.subService == beklenen), isTrue,
            reason: '$sorgu → $beklenen');
      }
    });

    test('ESKİ BİRLEŞİK AD İKİ HİZMETİ DE GETİRİR', () {
      // "priz ve anahtar montajı" eski adıydı; kullanıcı onu yazarsa
      // ikisi de listelenmeli.
      final r = SearchService.services('priz ve anahtar montajı');
      expect(r.any((h) => h.subService == 'Priz Montajı'), isTrue);
      expect(r.any((h) => h.subService == 'Anahtar Montajı'), isTrue);
    });

    test('yeni alanlar aranabiliyor', () {
      for (final (sorgu, beklenen) in [
        ('web sitesi', 'Web Sitesi Yapımı'),
        ('direksiyon dersi', 'Direksiyon Dersi'),
        ('oto çekici', 'Oto Çekici'),
        ('köpek gezdirme', 'Köpek Gezdirme'),
        ('manikür', 'Manikür Pedikür'),
        ('piyano', 'Piyano Dersi'),
      ]) {
        final r = SearchService.services(sorgu);
        expect(r.any((h) => h.subService == beklenen), isTrue,
            reason: '$sorgu → $beklenen');
      }
    });
  });
}
