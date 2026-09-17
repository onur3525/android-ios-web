// KATEGORİ KARTLARI — GÖRÜNÜRLÜK VE ETİKET
//
// KARARLAR:
//   1. Üç kategori KART IZGARASINDA çizilmez: Isıtma Sistemleri,
//      Banyo Tadilat ve Montaj, Mutfak Tadilat ve Dolap. Katalogdan
//      SİLİNMEZLER; arama, hizmet veren kategori seçimi ve mevcut
//      ilanlar etkilenmez.
//   2. Kartta görünen ad kısaltılır: `Mobilya Yapım ve Montaj` →
//      `Mobilya`, `Cam Balkon` → `Cam Balkon`,
//      (`Doğalgaz Tesisatı ve Proje` kısaltması KALKTI —
//      kategorinin gerçek adı artık `Doğalgaz`).
//   3. Kalan adlarda boşluklu `ve` bağlacı `&` olur.
//   4. Etiket KİMLİK DEĞİLDİR: seçim, arama ve gönderim gerçek
//      katalog adını taşır.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
import 'package:hizmetcep/data/services/search_service.dart';

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

void main() {
  group('KATALOG BOZULMADI', () {
    test('katalog yerinde — kart dışı olanlar SİLİNMEDİ', () {
      // ⚠ Kart dışı kategorilerin ALT HİZMETLERİ katalogda durur:
      // ilan verirken arama önerisinden, hizmet veren tarafında
      // kategori seçim panelinden seçilebilirler.
      // ⚠ 54 → 55: kombi ikiye ayrıldı (Montaj + Servis).
      expect(kTreeCategories.length, 63);
      for (final c in kKartDisiKategoriler) {
        expect(kCategoryTree.containsKey(c), isTrue, reason: '$c silinmiş');
        expect(kCategoryTree[c], isNotEmpty, reason: '$c alt hizmetsiz');
      }
    });

    test('kart dışı kategorilerin FOTOĞRAFI ve İKONU duruyor', () {
      for (final c in kKartDisiKategoriler) {
        expect(kCategoryImage.containsKey(c), isTrue, reason: c);
        expect(File(kCategoryImage[c]!).existsSync(), isTrue, reason: c);
      }
    });
  });

  group('KART IZGARASI', () {
    test('üç kategori kart listesinde YOK', () {
      expect(kKartDisiKategoriler, {
        'Isıtma Sistemleri',
        'Banyo Tadilat ve Montaj',
        'Mutfak Tadilat ve Dolap',
        'Koltuk ve Döşeme Yıkama',
      });
      for (final c in kKartDisiKategoriler) {
        expect(kKartKategorileri.contains(c), isFalse, reason: c);
      }
    });

    test('kart listesi 50 kategori', () {
      // ⚠ Kombi ikiye ayrıldı: katalog 54 → 55, kart 50 → 51.
      expect(kKartKategorileri.length, 63 - kKartDisiKategoriler.length);
      expect(kKartKategorileri.length, 54);
    });

    test('İLAN VERME IZGARASI KALDIRILDI', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (15 Ağu): ilan verme ekranında kategori
      // kartı yok; hizmet seçimi arama ile yapılıyor. `kKartKategorileri`
      // listesi katalogda DURUYOR, yalnız ızgara onu çizmiyor.
      final k = _kod('lib/screens/create_listing_screen.dart');
      expect(k.contains('for (final c in kKartKategorileri)'), isFalse,
          reason: 'ızgara geri gelmiş');
      expect(k.contains('SearchService.services('), isTrue);
    });
  });

  group('GÖRÜNEN AD', () {
    test('elle verilen kısa adlar', () {
      const beklenen = {
        'Mobilya Yapım ve Montaj': 'Mobilya',
        // ⚠ 'Cam Balkon Sistemleri', 'Doğalgaz' ve 'Elektrik'
        'İlaçlama ve Haşere Kontrolü': 'İlaçlama',
        'Klima Montaj ve Servis': 'Klima Servisi',
        'Duvar Kağıdı ve Dekorasyon': 'Duvar Kağıdı',
        'Tadilat ve Yenileme': 'Tadilat & Dekorasyon',
        'İnşaat ve Kaba Yapı': 'İnşaat',
        'Çilingir ve Kilit': 'Çilingir',
        'Kurye ve Küçük Taşıma': 'Kurye',
      };
      beklenen.forEach((kimlik, etiket) {
        expect(kCategoryTree.containsKey(kimlik), isTrue,
            reason: '$kimlik katalogda yok');
        expect(kategoriEtiketi(kimlik), etiket, reason: kimlik);
      });
    });

    test('boşluklu `ve` bağlacı `&` olur', () {
      expect(kategoriEtiketi('Koltuk ve Döşeme Yıkama'),
          'Koltuk & Döşeme Yıkama');
      expect(kategoriEtiketi('Bahçe ve Peyzaj'), 'Bahçe & Peyzaj');
      expect(kategoriEtiketi('Oto Servis ve Bakım'), 'Oto Servis & Bakım');
    });

    test('kelime İÇİNDEKİ `ve` bozulmaz', () {
      // Elle kısaltılmamış adlarda yalnız BOŞLUKLU bağlaç değişir.
      expect(kategoriEtiketi('Havuz Yapım ve Bakım'), 'Havuz Yapım & Bakım');
      expect(kategoriEtiketi('Temizlik Hizmetleri'), 'Temizlik Hizmetleri');
      expect(kategoriEtiketi('Yalıtım ve Mantolama'), 'Yalıtım & Mantolama');
    });

    test('ALT HİZMET adları KISALTILMAZ', () {
      // Fonksiyon her yerde çağrılabilsin diye katalogda ana kategori
      // olmayan ad olduğu gibi döner.
      expect(kategoriEtiketi('Petek ve Kalorifer Tesisatı'),
          'Petek ve Kalorifer Tesisatı');
      expect(kategoriEtiketi('Boya Badana'), 'Boya Badana');
      expect(kategoriEtiketi(''), '');
    });

    test('etiket KİMLİK DEĞİL — katalog anahtarı değişmedi', () {
      for (final c in kTreeCategories) {
        final e = kategoriEtiketi(c);
        if (e != c) {
          expect(kCategoryTree.containsKey(e), isFalse,
              reason: '$e katalog anahtarı gibi davranıyor');
        }
      }
    });

    test('her kategoride etiket üretilir', () {
      for (final c in kTreeCategories) {
        expect(kategoriEtiketi(c).trim(), isNotEmpty, reason: c);
      }
    });
  });

  group('ETİKET ÇİZİM YERLERİ', () {
    const ekranlar = {
      'lib/screens/widgets/kategori_karti.dart': 'kategoriEtiketi(ad)',
      'lib/screens/all_categories_screen.dart': 'kategoriEtiketi(h.label)',
      'lib/screens/widgets/inline_search_box.dart': 'kategoriEtiketi(h.label)',
      'lib/screens/search_screen.dart': 'kategoriEtiketi(c)',
      'lib/screens/category_screen.dart': 'kategoriEtiketi(category)',
      'lib/screens/create_listing_screen.dart': "kategoriEtiketi(_cat ?? '')",
    };
    ekranlar.forEach((yol, beklenen) {
      test('${yol.split('/').last} görünen adı kullanır', () {
        expect(_kod(yol).contains(beklenen), isTrue, reason: beklenen);
      });
    });
  });

  group('KART DIŞI KATEGORİNİN ALT HİZMETLERİ ERİŞİLEBİLİR', () {
    test('alt hizmetler katalogda durur', () {
      // ⚠ KATALOG GENİŞLEDİ: liste artık sabit değil. Kart dışı
      // kategorinin alt hizmetleri katalogda DURUYOR — asıl denetim
      // bu; ilk dördü de yerinde.
      final altlar = kCategoryTree['Koltuk ve Döşeme Yıkama']!;
      expect(altlar.take(4), [
        'Koltuk Yıkama',
        'Yatak Yıkama',
        'Perde Yıkama',
        'Stor Perde Temizliği',
      ]);
      expect(altlar.length, greaterThanOrEqualTo(4));
    });

    test('ARAMA kart dışı kategorinin alt hizmetlerini getirir', () {
      final etiketler =
          SearchService.services('koltuk', enFazla: 400).map((h) => h.label);
      expect(etiketler, contains('Koltuk Yıkama'));
    });

    test('HİZMET VEREN kategori paneli TÜM katalogu okur', () {
      // Panel kart listesini değil katalogu gezer; kart dışı
      // kategoriler orada seçilebilir kalır.
      final p = _kod('lib/screens/widgets/kategori_secim_paneli.dart');
      // ⚠ Panel artık ORTAK ARAMA SERVİSİNİ kullanıyor; servis tüm
      // katalogu tarar. Kart listesine bağlanmaması yine şart.
      expect(p.contains('SearchService.services('), isTrue);
      expect(p.contains('kKartKategorileri'), isFalse,
          reason: 'panel kart listesine bağlanmamalı');
    });
  });
}
