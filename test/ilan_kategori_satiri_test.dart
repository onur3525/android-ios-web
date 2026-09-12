import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/screens/category_ui.dart';

/// ÜST KATEGORİ ADI GÖSTERİLMEZ — YALNIZ SEÇİLEN HİZMET
///
/// ⚠ ÜRÜN KARARI TERSİNE DÖNDÜ (12 Eyl, kullanıcı).
///
/// ESKİ KURAL: hizmet adı tek başına ayırt etmiyor sayılıyordu ve
/// kartlarda/detaylarda adın ÜSTÜNE kategorisi yazılıyordu:
///
///     Doğalgaz                  ← üst kategori
///     Doğalgaz Kaçak Kontrolü   ← seçilen hizmet
///
/// YENİ KURAL: üst satır KALDIRILDI. Kullanıcının seçtiği hizmet ne
/// ise yalnız o yazılır. Ayırt ediciliği KATEGORİ İKONU taşır —
/// bu yüzden ikon artık kartlarda da çizilir.
///
/// ⚠ `kategoriAdi` SİLİNMEDİ: ikon çözümü (`ilanIkonu`) başlıktan
/// kategoriye geçmek için onu kullanır. Yani fonksiyon yaşıyor,
/// GÖRÜNTÜLENMESİ kalktı. Bu ayrım önemlidir: fonksiyonu da silmek
/// ikon çözümünü kırardı.
///
/// ⚠ BU DOSYA ARTIK YOKLUK DENETİMİ YAPAR. Satırın geri gelmesi
/// sessiz bir gerilemedir: derleme geçer, hiçbir test düşmez, yalnız
/// kullanıcı kararı bozulur.
String _kod(String p) => File(p)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — kategoriAdi doğru çalışır', () {
    test('alt hizmet → kategorisini döner', () {
      expect(kategoriAdi('Sözleşme İnceleme'), 'Avukatlık ve Hukuk');
      expect(kategoriAdi('Bordro Hazırlama'), 'Muhasebe ve Mali Müşavirlik');
      expect(kategoriAdi('Marka Tescili'), 'Marka ve Patent');
      expect(kategoriAdi('DASK'), 'Sigorta');
      expect(kategoriAdi('Ev Temizliği'), 'Temizlik Hizmetleri');
      expect(kategoriAdi('Zemin Etüdü'), 'Mühendislik ve Proje');
    });

    test('⚠ KATALOGDAKİ 640 HİZMETİN TAMAMI kategori döner', () {
      // ⚠ EN GÜÇLÜ KİLİT: "hangi hizmet olursa olsun üstünde
      // kategorisi yazsın" kuralı buradan denetlenir. Tek bir hizmet
      // bile boş dönerse test düşer.
      //
      // ⚠ Eskiden yalnız `SearchService` sıralamasına bakılıyordu;
      // arama alias ve kısmi eşleşmeyi de sıraladığı için ilk vuruş
      // aranan hizmetin kendisi olmayabilirdi. Artık önce KESİN
      // eşleşme aranıyor.
      final bos = <String>[];
      final yanlis = <String>[];
      for (final h in kTreeServices) {
        final ad = kategoriAdi(h.service);
        if (ad == null) {
          bos.add(h.service);
        } else if (ad != h.category) {
          yanlis.add('${h.service} → $ad (olması gereken ${h.category})');
        }
      }
      expect(bos, isEmpty, reason: 'kategorisi bulunamayan hizmet');
      expect(yanlis, isEmpty, reason: 'yanlış kategori');
    });

    test('başlığın KENDİSİ kategoriyse null döner', () {
      // ⚠ Aynı ad iki kez alt alta yazılmaz.
      for (final k in kCategoryTree.keys.take(8)) {
        expect(kategoriAdi(k), isNull, reason: k);
      }
    });

    test('boş ve tanınmayan başlıkta null döner', () {
      // ⚠ Uydurma ad ya da "Diğer" gibi bir etiket ÜRETİLMEZ;
      // çağıran taraf satırı hiç çizmez.
      expect(kategoriAdi(''), isNull);
      expect(kategoriAdi('   '), isNull);
      expect(kategoriAdi('zzzqqq xyzzy'), isNull);
    });
  });

  group('2 — ⚠ HİÇBİR YÜZEYDE GÖSTERİLMEZ', () {
    // Kartlar ve detaylar; hizmet alan ve hizmet veren tarafı.
    final yuzeyler = {
      'ilan detayı': 'lib/screens/listing_detail_screen.dart',
      'iş detayı': 'lib/screens/job_detail_screen.dart',
      'İlanlarım kartı': 'lib/screens/my_listings_screen.dart',
      'Uygun İşler kartı': 'lib/screens/jobs_screen.dart',
      'ilan verme': 'lib/screens/create_listing_screen.dart',
      'ortak başlık satırı': 'lib/screens/widgets/ilan_baslik_satiri.dart',
    };
    yuzeyler.forEach((ad, yol) {
      test('$ad kategori adı ÇİZMEZ', () {
        final s = _kod(yol);
        expect(s.contains('Text(kategoriAdi('), isFalse,
            reason: '$ad: üst kategori adı geri gelmiş');
        expect(s.contains('kategoriAdi(listing.title)!'), isFalse,
            reason: ad);
        expect(s.contains('kategoriAdi(l.title)!'), isFalse, reason: ad);
      });
    });

    test('⚠ KATEGORİ İKONU KARTLARDA ÇİZİLİR', () {
      // Üst kategori adı kalkınca ayırt ediciliği ikon taşır.
      // Hizmet verenin gördüğü iş kartı bu yüzden ikon gösterir.
      final j = _kod('lib/screens/jobs_screen.dart');
      expect(j.contains('IlanKategoriIkonu('), isTrue,
          reason: 'iş kartında kategori ikonu yok');
    });

    test('⚠ İKON BİLEŞENİ TEK YERDE TANIMLI', () {
      final yerler = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('class IlanKategoriIkonu')) {
          yerler.add(f.path);
        }
      }
      expect(yerler, ['lib/screens/widgets/ilan_baslik_satiri.dart']);
    });
  });

  group('3 — Tek kaynak', () {
    test('yardımcı category_ui.dart içinde', () {
      final u = _kod('lib/screens/category_ui.dart');
      expect(u.contains('String? kategoriAdi(String baslik)'), isTrue);
      // ⚠ Kategori ilanda SAKLANMIYOR; ad katalogda geriye aranıyor.
      expect(u.contains('SearchService.services('), isTrue);
    });

    test('⚠ İKON ÇÖZÜMÜ AYNI YARDIMCIYI KULLANIR', () {
      // İki ayrı "başlıktan kategoriye" mantığı tutulursa biri
      // değişip öteki kalır. Bu, iş detayında bir kez yaşandı:
      // ekran `categoryIcon`u BAŞLIKLA çağırıyor, harita KATEGORİ
      // ADIYLA anahtarlı olduğu için her ilanda yedek ikon çıkıyordu.
      final w = _kod('lib/screens/widgets/ilan_baslik_satiri.dart');
      expect(w.contains('kategoriAdi(t)'), isTrue,
          reason: 'ikon çözücüsü kendi arama mantığını yazmış');
    });

    test('⚠ ANAHTAR KELİME YEDEĞİ GERÇEK KATEGORİ ADI VERİR', () {
      // Yedek tablodaki adlar katalogda YOKSA `categoryIcon` sessizce
      // genel yedek ikona düşer — hata görünmez. Dört ad tam olarak
      // bu yüzden yanlıştı ("Tesisat", "Temizlik", "Boya",
      // "Fayans ve Seramik").
      final w = _kod('lib/screens/widgets/ilan_baslik_satiri.dart');
      final govde = w.substring(w.indexOf('const kelimeler = {'));
      final adlar = RegExp(r"'[^']+': '([^']+)'")
          .allMatches(govde.substring(0, govde.indexOf('};')))
          .map((m) => m.group(1)!);
      expect(adlar, isNotEmpty);
      for (final ad in adlar) {
        expect(kCategoryTree.containsKey(ad), isTrue,
            reason: '$ad katalogda yok — ikon yedeğe düşer');
      }
    });

    test('ekranlar kendi arama mantığını YAZMAZ', () {
      // Aynı kural ORTAK ARAMA SERVİSİ kuralının uzantısıdır.
      for (final yol in const [
        'lib/screens/my_listings_screen.dart',
        'lib/screens/jobs_screen.dart',
      ]) {
        final s = _kod(yol);
        expect(s.contains('kCategoryTree.entries'), isFalse,
            reason: '$yol: ekran katalogda kendi kendine arıyor');
      }
    });
  });
}
