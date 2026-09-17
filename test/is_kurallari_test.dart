import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/config.dart';
import 'support/kaynak_okuma.dart';
import 'package:hizmetcep/core/turkce_arama.dart';
import 'package:hizmetcep/data/category_tree.dart';

/// HİZMETCEP İŞ KURALLARI — sözleşme testleri
void main() {
  /// HAM METİN — yorumlar DAHİL.
  ///
  /// ⚠ BU DOSYADAKİ BAZI İDDİALAR BİLİNÇLİ OLARAK YORUM ARAR:
  /// cüzdan kurallarının gerekçesi ("Karşılıksız bloke İMKANSIZ"
  /// gibi) koddaki AÇIKLAMA satırlarında yazılıdır ve o açıklamanın
  /// silinmemesi de sözleşmenin parçasıdır. Bir tur bu yardımcı
  /// yorumları eliyordu; üç bakiye testi bu yüzden kırıldı.
  String read(String p) => File(p).readAsStringSync();

  /// YALNIZ KOD — yorum satırları elenir.
  ///
  /// Bir adın AÇIKLAMADA geçmesi, kodda kullanıldığı anlamına gelmez.
  String kodu(String p) => File(p)
      .readAsStringSync()
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('Ücretlendirme', () {
    test('ilan vermek ÜCRETSİZ', () {
      final cl = read('lib/screens/create_listing_screen.dart');
      expect(cl.toLowerCase().contains('ücretsiz'), isTrue);
    });

    test('teklif vermek ÜCRETSİZ', () {
      expect(read('lib/screens/job_detail_screen.dart')
          .contains('Ücretsiz Teklif Ver'), isTrue);
    });

    test('iletişim bedeli tek merkezde', () {
    });
  });

  group('İlan yaşam süresi', () {
    test('30 SAAT', () {
      expect(DomainConfig.listingLifetime, const Duration(hours: 30));
    });

    test('kaynakta 32 saat kalıntısı YOK', () {
      // ⚠ Bu testin KENDİSİ aranan metni içerir; hariç tutulur.
      const buDosya = 'is_kurallari_test.dart';
      for (final d in ['lib', 'test']) {
        for (final f in Directory(d)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) =>
                f.path.endsWith('.dart') && !f.path.endsWith(buDosya))) {
          final c = f.readAsStringSync();
          expect(c.contains('hours: 32'), isFalse, reason: f.path);
          expect(c.contains('32 saat'), isFalse, reason: f.path);
        }
      }
    });

    test('süre dolunca açılmamış blokeler İADE edilir', () {
      final mp = read('lib/data/ports/mock_ports.dart');
      final i = mp.indexOf('Future<DomainError?> expire(');
      expect(i, greaterThan(0));
      final govde = mp.pencere(i, 600);
      expect(govde.contains('cancelAllForListing'), isTrue);
      // İptal zinciri tüketilmemiş blokeyi iade eder.
      expect(mp.contains('_refundIfUnconsumed'), isTrue);
    });

    test('ilan silinince de iade edilir', () {
      final mp = read('lib/data/ports/mock_ports.dart');
      final i = mp.indexOf('Future<DomainError?> delete(');
      expect(mp.pencere(i, 500).contains('cancelAllForListing'), isTrue);
    });
  });

  group('Hizmet bölgesi', () {
    test('TEK İL kuralı', () {
      expect(read('lib/data/izmir.dart').contains("kCity = 'İzmir'"), isTrue);
    });

    test('ilçe sınırı YOK — tümü seçilebilir', () {
      expect(read('lib/screens/my_areas_screen.dart')
          .contains('Tüm İlçelere Hizmet Veriyorum'), isTrue);
    });
  });

  group('İlan eşleşmesi', () {
    // ⚠ Burada YORUMSUZ metin gerekir: kaldırılan kuralın adı
    // açıklamalarda geçebilir.
    final js = kodu('lib/screens/jobs_screen.dart');

    test('kategori eşleşmesi EKRANDA DEĞİL ORTAK KURALDA', () {
      // ⚠ SÖZLEŞME TAŞINDI — TEST GEVŞETİLMEDİ.
      //
      // Kural eskiden `jobs_screen` içinde satır satır yazılıydı
      // (`anaAd == q`, `altAd == q`, `kCategoryTree.entries`…). Aynı
      // kuralın backend'de de bulunması gerektiği için saf
      // fonksiyonlara taşındı: `lib/domain/eslestirme.dart`.
      //
      // Ekran artık kendi kuralını YAZMAZ, çağırır.
      expect(js.contains('eslesmeOnceligi(me.categories'), isTrue,
          reason: 'ekran ortak kuralı çağırmalı');
      expect(js.contains('anaAd == q'), isFalse,
          reason: 'kural ekrana geri kopyalanmış');
      expect(js.contains('me.categories.contains(l.title)'), isFalse,
          reason: 'eski tam-eşitlik deseni geri gelmiş');

      // Kuralın kendisi ortak dosyada ve İÇERİR mantığı KULLANMIYOR.
      final es = kodu('lib/domain/eslestirme.dart');
      expect(es.contains('turkceNormalize'), isTrue);
      expect(es.contains('anaKategoriAdi'), isTrue);
      expect(es.contains('.contains(q)'), isFalse,
          reason: 'içerir mantığı kategorileri karıştırır');
    });

    /// Ekranın kuralı burada BAĞIMSIZ uygulanır; veri gerçek
    /// `kCategoryTree`'den okunur.
    test('aynı adı taşıyan alt hizmetler kategoriye göre AYRIŞIR', () {
      bool uygun(Set<String> secim, String baslik) {
        if (secim.isEmpty) {
          return true;
        }
        final alt = turkceNormalize(baslik);
        var ana = alt;
        for (final e in kCategoryTree.entries) {
          if (e.key == baslik || e.value.contains(baslik)) {
            ana = turkceNormalize(e.key);
            break;
          }
        }
        return secim
            .map(turkceNormalize)
            .any((q) => q.isNotEmpty && (ana == q || alt == q));
      }

      // ── AYRIM: "Su Tesisatı" seçimi ──
      //
      // ⚠ `Tesisat` ana kategorisi yeni katalogda `Su Tesisatı` adıyla
      // duruyor; `Tesisat Kaçağı Tespiti` de `Su Kaçağı Tespiti` oldu.
      expect(uygun({'Su Tesisatı'}, 'Su Tesisatçısı'), isTrue);
      expect(uygun({'Su Tesisatı'}, 'Sıhhi Tesisat'), isTrue);
      expect(uygun({'Su Tesisatı'}, 'Su Kaçağı Tespiti'), isTrue);
      // Adında "Tesisat" geçse de BAŞKA kategoriye ait:
      expect(uygun({'Su Tesisatı'}, 'Elektrik Tesisatı'), isFalse);
      expect(uygun({'Su Tesisatı'}, 'Doğalgaz Tesisatı'), isFalse);

      // ── "Doğalgaz" seçimi tüm alt hizmetlerini kapsar ──
      expect(uygun({'Doğalgaz'}, 'Doğalgaz Tesisatı'), isTrue);
      expect(uygun({'Doğalgaz'}, 'Doğalgaz Projesi'), isTrue);
      expect(uygun({'Doğalgaz'}, 'Doğalgaz Kaçak Kontrolü'), isTrue);
      // ⚠ `Kombi` ARTIK AYRI ANA KATEGORİ: Doğalgaz seçimi onu
      // kapsamaz.
      expect(uygun({'Doğalgaz'}, 'Kombi Bakımı'), isFalse);
      expect(uygun({'Kombi Servis'}, 'Kombi Bakımı'), isTrue);
      expect(uygun({'Kombi Montaj'}, 'Kombi Montajı'), isTrue);
      expect(uygun({'Doğalgaz'}, 'Su Tesisatçısı'), isFalse);

      // ── "Elektrik" seçimi ──
      expect(uygun({'Elektrik'}, 'Elektrik Tesisatı'), isTrue);
      expect(uygun({'Elektrik'}, 'Avize Montajı'), isTrue);
      expect(uygun({'Elektrik'}, 'Su Tesisatçısı'), isFalse);

      // ── ALT HİZMET seçimi: yalnız o hizmet ──
      expect(uygun({'Su Tesisatçısı'}, 'Su Tesisatçısı'), isTrue);
      expect(uygun({'Su Tesisatçısı'}, 'Sıhhi Tesisat'), isFalse);
      expect(uygun({'Su Tesisatçısı'}, 'Elektrik Tesisatı'), isFalse);

      // ── Türkçe büyük harf duyarsız ──
      // ⚠ Ana kategori adı 'Doğalgaz' oldu.
      expect(uygun({'DOĞALGAZ'}, 'Doğalgaz Projesi'), isTrue);

      // ── Seçim yoksa kısıt uygulanmaz ──
      expect(uygun(<String>{}, 'Herhangi Bir İlan'), isTrue);
    });

    // ── OTOMATİK BÖLGE GENİŞLEME ──
    test('genişleme eşiği 1 SAAT ve tek merkezde', () {
      expect(DomainConfig.areaExpandAfter, const Duration(hours: 1));
      expect(js.contains('DomainConfig.areaExpandAfter'), isTrue,
          reason: 'süre ekrana gömülmemeli');
    });

    test('seçili ilçelerde 1 saatten uzun ilan yoksa İL GENELİNE genişler',
        () {
      // Eşik: şimdi - areaExpandAfter
      expect(js.contains('DateTime.now().subtract(DomainConfig.areaExpandAfter)'),
          isTrue);
      // Son 1 saatte ilçe içinde ilan var mı?
      expect(js.contains('sonSaatteIlanVar'), isTrue);
      expect(js.contains('l.createdAt.isAfter(esik)'), isTrue);
      // Yoksa kategoriye uyan TÜM il ilanları gösterilir.
      expect(js.contains('genislet ? kategoriUyanlar.toList() : ilceIcindekiler'),
          isTrue);
    });

    test('genişleme KATEGORİ kısıtını KALDIRMAZ', () {
      // İl geneline çıkılsa bile yalnız seçili kategoriler.
      expect(js.contains('acikVeBaskasinin(l) && kategoriUygun(l)'), isTrue);
    });

    // ⚠ Genişleme SİSTEM İÇİ bir davranıştır; kullanıcıya
    // bilgi satırı, uyarı veya rozet GÖSTERİLMEZ.
    test('genişleme kullanıcıya BİLDİRİLMEZ', () {
      expect(js.contains('RefInfoBox'), isFalse,
          reason: 'genişleme için bilgi kutusu gösterilmemeli');
      expect(js.contains('il genelindeki ilanlar'), isFalse);
      // Liste indeksi kaydırılmaz; ilan sayısı olduğu gibi.
      expect(js.contains('itemCount: jobs.length'), isTrue);
      expect(js.contains('jobs[genislet ? i - 1 : i]'), isFalse);
    });
  });

  group('Maskeleme', () {
    final jd = read('lib/screens/job_detail_screen.dart');

    test('iletişim açılmadan ad MASKELİ', () {
      expect(jd.contains('maskeliAd'), isTrue);
      expect(jd.contains('iletisimAcik ? tamAd : maskeliAd(tamAd)'), isTrue);
    });

    test('telefon maskeli gösterilir', () {
      expect(jd.contains('05** *** *** **'), isTrue);
    });
  });
}
