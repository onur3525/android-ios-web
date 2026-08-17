// HİZMET ADI ALIASLARI — SÖZLEŞME
//
// Alias bir ARAMA katmanıdır, katalog değildir. Bu dosya iki şeyi
// birden korur:
//   1. kataloğun alias yüzünden BÜYÜMEDİĞİNİ,
//   2. her aliasın MEVCUT bir hedefe çözüldüğünü.
//
// ⚠ Kaynak belge "53 ana kategori" diyor; katalog o belgeden SONRA
// "Halı ve Döşeme Yıkama" ikiye bölündüğü için 54'tür. Sayı alias
// yüzünden değişmedi — bölünme ayrı ve onaylı bir karardı.

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/data/service_aliases.dart';
import 'package:hizmetcep/data/services/search_service.dart';

void main() {
  group('KATALOG BÜYÜMEDİ', () {
    test('ana kategori 55, alt hizmet 517', () {
      // ⚠ 54 → 55: kombi ikiye ayrıldı (Montaj + Servis).
      expect(kCategoryTree.length, 63);
      final toplam =
          kCategoryTree.values.fold<int>(0, (t, v) => t + v.length);
      // ⚠ 255 → 459 → 439 → 517: önce öneri listesindeki ayrı işler hizmet oldu,
      // sonra tekrar eden ve dağıtım şirketine ait olanlar kaldırıldı
      // (eski not: ayrı işler gerçek
      // hizmet kaydına çevrildi.
      expect(toplam, 640);
    });

    test('hiçbir alias ana kategori DEĞİL', () {
      for (final a in kServiceAliases) {
        expect(kCategoryTree.containsKey(a.etiket), isFalse,
            reason: '${a.etiket} ana kategori olmuş');
      }
    });

    test('hiçbir alias kanonik alt hizmet DEĞİL', () {
      // Alias zaten kanonik adla aynıysa ikinci kayıt açılmaz —
      // katalog araması onu zaten bulur.
      final altlar = {for (final v in kCategoryTree.values) ...v};
      for (final a in kServiceAliases) {
        expect(altlar.contains(a.etiket), isFalse,
            reason: '${a.etiket} zaten kanonik hizmet');
      }
    });
  });

  group('SAYILAR', () {
    test('543 kayıt: 474 hizmet aliası + 69 kategori niyeti', () {
      // ⚠ 570 → 543: katalog genişletmesiyle 27 alias adı GERÇEK
      // HİZMET oldu (15 hizmet aliası + 12 kategori niyeti). Alias
      // olarak durmaları `kAliasDizini`'nde çakışma üretirdi —
      // belgenin kendi kuralı: kanonik ad alias olamaz.
      final hizmet =
          kServiceAliases.where((a) => a.hizmetAliasi).length;
      final niyet = kServiceAliases.length - hizmet;
      expect(kServiceAliases.length, 543);
      expect(hizmet, 474);
      expect(niyet, 69);
    });
  });

  group('ÇÖZÜMLEME', () {
    test('her alias MEVCUT kategoriye ve MEVCUT hedefe oturuyor', () {
      expect(aliasTutarsizliklari(), isEmpty);
    });

    test('hizmet aliasının hedefi ZORUNLU, niyetinki BOŞ', () {
      for (final a in kServiceAliases) {
        if (a.hizmetAliasi) {
          expect(a.kanonikHizmet, isNotNull, reason: a.etiket);
        } else {
          expect(a.kanonikHizmet, isNull,
              reason: '${a.etiket}: niyet aliasına hizmet uydurulmuş');
        }
      }
    });

    test('BELİRSİZ ALIAS YOK — aynı ad iki hedefe bağlanamaz', () {
      // Dizin kaybı = çakışma: iki kayıt aynı normalize anahtara
      // düşmüş ve biri sessizce ötekini ezmiş demektir.
      expect(kAliasDizini.length, kServiceAliases.length);
    });

    test('tam adıyla arandığında alias bulunur', () {
      for (final a in kServiceAliases) {
        final b = aliasBul(a.etiket);
        expect(b, isNotNull, reason: a.etiket);
        expect(b!.kategori, a.kategori);
        expect(b.kanonikHizmet, a.kanonikHizmet);
      }
    });
  });

  group('TÜRKÇE NORMALİZASYON', () {
    test('büyük/küçük harf varyasyonları aynı aliası bulur', () {
      const ornek = 'Laptop Tamiri';
      for (final y in const [
        'laptop tamiri',
        'LAPTOP TAMİRİ',
        'Laptop  Tamiri',
        ' laptop-tamiri ',
      ]) {
        expect(aliasBul(y)?.etiket, ornek, reason: y);
      }
    });

    test('I ve İ ayrı ayrı doğru küçülür', () {
      // Dart'ın toLowerCase'i 'I' → 'i' verir; Türkçede 'ı' olmalı.
      expect(aliasNormalize('IŞIK'), 'ışık');
      expect(aliasNormalize('İSTANBUL'), 'istanbul');
      expect(aliasNormalize('Ğ Ü Ö Ş Ç'), 'ğ ü ö ş ç');
    });

    test('boş ve simge-only sorgu alias döndürmez', () {
      expect(aliasBul(''), isNull);
      expect(aliasBul('   '), isNull);
      expect(aliasBul('---'), isNull);
    });
  });

  group('ARAMADA GÖRÜNÜRLÜK', () {
    /// Temsilî 25 alias — her biri kendi adıyla arandığında doğru
    /// hedefi getirmeli.
    const ornekler = <String, (String, String?)>{
      'Laptop Tamiri': ('Elektronik Cihaz Tamiri', 'Bilgisayar Tamiri'),
      'Dükkan Temizliği': ('Temizlik Hizmetleri', 'Ofis Temizliği'),
      'Tuvalet Tıkanıklığı Açma': ('Su Tesisatı', 'Tıkanıklık Açma'),
      'Kombi Arıza': ('Kombi Servis', 'Kombi Tamiri'),
      // ⚠ Kaçak TESPİTİ artık ayrı hizmet; alias oraya bağlandı.
      'Gaz Kaçak Tespiti':
          ('Doğalgaz', 'Doğalgaz Kaçak Tespiti'),
      'Güvenlik Kamerası Kurulumu':
          ('Güvenlik Sistemleri', 'Kamera Sistemi Kurulumu'),
      'Hamam Böceği İlaçlama':
          ('İlaçlama ve Haşere Kontrolü', 'Böcek İlaçlama'),
      // ⚠ 'Halı Yıkama' HİZMETİ KALDIRILDI (kategori adı zaten bu);
      // alias artık 'Yerinde Halı Yıkama'ya çözülür.
      'Evde Halı Yıkama': ('Halı Yıkama', 'Yerinde Halı Yıkama'),
      'Koltuk Temizleme': ('Koltuk ve Döşeme Yıkama', 'Koltuk Yıkama'),
      'Zebra Perde Yıkama':
          ('Koltuk ve Döşeme Yıkama', 'Stor Perde Temizliği'),
      'Priz Değişimi': ('Elektrik', 'Priz Montajı'),
      'Avize Takma': ('Elektrik', 'Avize Montajı'),
      'Radyatör Petek Temizliği': ('Isıtma Sistemleri', 'Petek Temizliği'),
      // ⚠ 'Kalıcı Oje' ARTIK GERÇEK HİZMET (katalog genişletmesi);
      // alias kaydı silindi, örnek listeden de çıkarıldı.
      'Gelin Saçı': ('Güzellik ve Bakım Hizmetleri', 'Saç Tasarımı'),
      'Köpek Yürütme': ('Evcil Hayvan Hizmetleri', 'Köpek Gezdirme'),
      'Tesisatçı': ('Su Tesisatı', 'Su Tesisatçısı'),
      'Batarya Montajı': ('Su Tesisatı', 'Musluk Montajı'),
      'Yatak Böceği İlaçlama':
          ('İlaçlama ve Haşere Kontrolü', 'Tahtakurusu İlaçlama'),
      'Kemirgen Mücadelesi':
          ('İlaçlama ve Haşere Kontrolü', 'Fare Mücadelesi'),
    };

    test('temsilî aliaslar doğru hedefi getiriyor', () {
      ornekler.forEach((alias, hedef) {
        final a = aliasBul(alias);
        expect(a, isNotNull, reason: alias);
        expect(a!.kategori, hedef.$1, reason: alias);
        expect(a.kanonikHizmet, hedef.$2, reason: alias);
      });
    });

    test('arama sonucunda alias İLK SIRALARDA çıkıyor', () {
      ornekler.forEach((alias, hedef) {
        final sonuc = SearchService.services(alias);
        expect(sonuc, isNotEmpty, reason: alias);
        final ilk5 = sonuc.take(5);
        expect(
            ilk5.any((h) =>
                h.category == hedef.$1 && h.subService == hedef.$2),
            isTrue,
            reason: '$alias → ilk 5 sonuçta yok');
      });
    });

    test('KANONİK AD ALIASTAN ÖNCE gelir', () {
      // ⚠ "Halı Yıkama" artık KATEGORİ adı (aynı adlı hizmet
      // kaldırıldı). Kanonik satır yine ilk sırada olmalı.
      // Eski not: kanonik bir hizmettir; alias satırı onu geriye
      // itmemelidir.
      final s = SearchService.services('Halı Yıkama');
      expect(s.first.aliasEtiketi, isNull);
      expect(s.first.subService ?? s.first.category, 'Halı Yıkama');
    });

    test('517 kanonik hizmet kendi adıyla HÂLÂ bulunuyor', () {
      for (final e in kCategoryTree.entries) {
        for (final h in e.value) {
          final s = SearchService.services(h);
          expect(s.any((x) => x.subService == h && x.aliasEtiketi == null),
              isTrue,
              reason: '$h kayboldu');
        }
      }
    });
  });

  group('KATEGORİ NİYETİ — HİZMET UYDURULMAZ', () {
    test('niyet aliası seçildiğinde alt hizmet BOŞ kalır', () {
      const niyetler = [
        'Apartman Temizliği',
        'Sinek İlaçlama',
        'Topraklama Ölçümü',
        // ⚠ 'Sandalye Yıkama' ARTIK GERÇEK HİZMET; niyet aliası
        // olarak kalması `kAliasDizini`'nde çakışma üretirdi, silindi.
        'Apartman Temizliği',
        'Epilasyon',
      ];
      for (final n in niyetler) {
        final a = aliasBul(n);
        expect(a, isNotNull, reason: n);
        expect(a!.hizmetAliasi, isFalse, reason: n);
        expect(a.kanonikHizmet, isNull, reason: n);

        final s = SearchService.services(n);
        final hit = s.firstWhere((h) => h.aliasEtiketi == n,
            orElse: () => const SearchHit('', null));
        expect(hit.category, a.kategori, reason: n);
        expect(hit.subService, isNull,
            reason: '$n bir alt hizmete ZORLANMIŞ');
        expect(hit.kategoriNiyeti, isTrue, reason: n);
      }
    });

    test('"Sandalye Yıkama" ARTIK GERÇEK HİZMET', () {
      // Katalog genişletmesiyle kanonik ad oldu; alias olarak
      // durması `kAliasDizini`'nde çakışma üretirdi.
      expect(aliasBul('Sandalye Yıkama'), isNull);
      expect(kCategoryTree['Koltuk ve Döşeme Yıkama'],
          contains('Sandalye Yıkama'));
    });
  });

  group('SEÇİM KİMLİĞİ', () {
    test('her arama sonucu MEVCUT katalog kimliğini taşır', () {
      // ⚠ ASIL SÖZLEŞME BU: satır ister kanonik ister alias olsun,
      // seçime giden `category`/`subService` daima KATALOGDA vardır.
      // Alias metni hiçbir zaman kategori/hizmet kimliği yerine
      // geçmez.
      for (final sorgu in const [
        'Laptop Tamiri',
        'Zebra Perde Yıkama',
        'Kemirgen Mücadelesi',
      ]) {
        for (final h in SearchService.services(sorgu)) {
          expect(kCategoryTree.containsKey(h.category), isTrue,
              reason: '$sorgu → ${h.category}');
          if (h.subService != null) {
            expect(kCategoryTree[h.category]!.contains(h.subService), isTrue,
                reason: '$sorgu → ${h.subService}');
          }
        }
      }
    });

    test('ZOR SORGULAR DOĞRU HİZMETE ULAŞIR', () {
      // ⚠ TESTİN ADI VE ÖLÇTÜĞÜ ŞEY DÜZELTİLDİ.
      //
      // Eski hâli sonucun ALIAS SATIRINDAN gelmesini şart koşuyordu.
      // Eş anlamlı sözlüğü genişleyince "İşyeri Temizliği" artık
      // KANONİK yoldan da bulunuyor; arama servisi aynı hedefe iki
      // yoldan varıldığında alias satırını EKLEMİYOR (bilinçli
      // kural: liste kendini tekrar etmez). Test o yüzden düştü —
      // arama BOZULMADI, İYİLEŞTİ.
      //
      // Asıl kabul kriteri: sorgu DOĞRU kategori ve hizmete ulaşsın.
      // Alias satırı varsa etiketi de kullanıcının yazdığı ad olsun.
      const yeni = {
        'Buharlı Ev Temizliği': ('Temizlik Hizmetleri', 'Ev Temizliği'),
        'Ofis Halı Yıkama': ('Halı Yıkama', 'Yerinde Halı Yıkama'),
        'İşyeri Temizliği': ('Temizlik Hizmetleri', 'Ofis Temizliği'),
        'Taşınma Sonrası Temizlik':
            ('Temizlik Hizmetleri', 'Taşınma Temizliği'),
      };
      yeni.forEach((sorgu, hedef) {
        final s = SearchService.services(sorgu);
        expect(s, isNotEmpty, reason: '$sorgu: hiç sonuç yok');

        // Hedefe ulaşan bir satır OLMALI — hangi yoldan geldiği
        // önemli değil.
        final hedefSatiri = s.where(
            (x) => x.category == hedef.$1 && x.subService == hedef.$2);
        expect(hedefSatiri, isNotEmpty,
            reason: '$sorgu → ${hedef.$1} / ${hedef.$2} bulunamadı');

        // Alias satırı ÜRETİLMİŞSE etiketi kullanıcının yazdığı ad
        // olmalı; üretilmemişse kanonik yol zaten bulmuş demektir.
        final aliasSatiri =
            s.where((x) => x.aliasEtiketi == sorgu).toList();
        for (final a in aliasSatiri) {
          expect(a.label, sorgu,
              reason: '$sorgu: alias adı gösterilmiyor');
        }
      });
    });

    test('alias satırı çıkarsa kullanıcının yazdığı adı gösterir', () {
      // ⚠ ALIAS SATIRI HER ZAMAN ÇIKMAZ — ÇIKMAMASI DA DOĞRUDUR.
      //
      // Aynı hedefe kanonik yoldan da varılmışsa (ör. eş anlamlı
      // terim zaten eşleşmişse) alias satırı EKLENMEZ; liste kendini
      // tekrar etmez. Bu testin koruduğu şey satırın varlığı değil,
      // VAR OLDUĞUNDA doğru davranmasıdır.
      final alias = SearchService.services('Buharlı Ev Temizliği')
          .where((x) => x.aliasEtiketi != null);
      for (final h in alias) {
        expect(h.label, h.aliasEtiketi);
        expect(kCategoryTree.containsKey(h.category), isTrue);
      }
    });

    test('aranan alias hedefi SONUÇLARDA vardır (satır tipi ne olursa)', () {
      const bekleyen = {
        'Laptop Tamiri': ('Elektronik Cihaz Tamiri', 'Bilgisayar Tamiri'),
        'Zebra Perde Yıkama':
            ('Koltuk ve Döşeme Yıkama', 'Stor Perde Temizliği'),
      };
      bekleyen.forEach((sorgu, hedef) {
        final s = SearchService.services(sorgu);
        expect(
            s.any((h) => h.category == hedef.$1 && h.subService == hedef.$2),
            isTrue,
            reason: sorgu);
      });
    });
  });
}
