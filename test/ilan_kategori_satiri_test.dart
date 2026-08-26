import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/screens/category_ui.dart';

/// İLAN KATEGORİ SATIRI
///
/// ⚠ SORUN: hizmet adı tek başına AYIRT ETMİYORDU. "Sözleşme
/// İnceleme" başlığını gören kullanıcı bunun hukuk işi mi, tesisat mı,
/// elektrik mi olduğunu anlayamıyordu. Aynı belirsizlik ilan
/// kartlarında da vardı — ilana girmeden ayırt edilemiyordu.
///
/// ⚠ ÇATI DEĞİL KATEGORİ gösterilir: "Sözleşme İnceleme" için çatı
/// "Mühendislik & Danışmanlık"tır ve hiçbir şeyi ayırt etmez.
///
/// ⚠ Bu, "ana/alt kategori ayrımı kullanıcıya gösterilmez" kararının
/// BİLİNÇLİ İSTİSNASIDIR. Gösterilen şey bir kırılım yolu ("Ana >
/// Alt") değil, işin ait olduğu alanın TEK adıdır.
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

  group('2 — BEŞ YÜZEYDE de gösterilir', () {
    // ⚠ Kullanıcı ilana GİRMEDEN ayırt edebilmeli: kartlar da dahil.
    final yuzeyler = {
      'ilan detayı': 'lib/screens/listing_detail_screen.dart',
      'iş detayı': 'lib/screens/job_detail_screen.dart',
      'İlanlarım kartı': 'lib/screens/my_listings_screen.dart',
      'Uygun İşler kartı': 'lib/screens/jobs_screen.dart',
      'ilan verme': 'lib/screens/create_listing_screen.dart',
    };
    yuzeyler.forEach((ad, yol) {
      test(ad, () {
        final s = _kod(yol);
        expect(s.contains('kategoriAdi('), isTrue,
            reason: '$ad: kategori satırı yok');
        // ⚠ null gelirse satır HİÇ çizilmemeli.
        expect(s.contains('if (kategoriAdi('), isTrue,
            reason: '$ad: null denetimi yok — boş satır çizilebilir');
      });
    });

    test('ilan verme ekranında İKİ adımda birden', () {
      // Seçili Hizmet kartı (adım 2) ve Önizle & Yayınla (adım 3).
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect('kategoriAdi('.allMatches(c).length, greaterThanOrEqualTo(4),
          reason: 'iki adımda da gösterilmiyor');
    });
  });

  group('3 — Tek kaynak', () {
    test('yardımcı category_ui.dart içinde', () {
      final u = _kod('lib/screens/category_ui.dart');
      expect(u.contains('String? kategoriAdi(String baslik)'), isTrue);
      // ⚠ Kategori ilanda SAKLANMIYOR; ad katalogda geriye aranıyor.
      // İkon seçimi de aynı yolu kullanıyor, yeni kırılganlık yok.
      expect(u.contains('SearchService.services('), isTrue);
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
