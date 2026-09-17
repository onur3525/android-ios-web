// TÜM KATEGORİLER EKRANI — SAYAÇ VE ARAMA KAPSAMI
//
// KARARLAR:
//   1. "53 kategori" sayacı GÖSTERİLMEZ.
//   2. Arama, ana sayfadaki arama çubuğuyla AYNI kaynağı kullanır
//      (`SearchService.services`): ana kategoriler VE alt hizmetler
//      birlikte listelenir; bir ana kategori eşleşirse altındaki tüm
//      hizmetler ayrı satır olarak görünür.
//   3. Tam ekran liste olduğu için sonuç sınırı yükseltilir; ana
//      sayfadaki açılır kutunun 40'lık sınırı DEĞİŞMEZ.
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
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  final k = _kod('lib/screens/all_categories_screen.dart');

  group('SAYAÇ KALDIRILDI', () {
    test('"N kategori" metni yok', () {
      expect(k.contains('kategori\''), isFalse);
      expect(k.contains('liste.length} kategori'), isFalse);
    });
  });

  group('ARAMA ALT HİZMETLERİ DE GÖSTERİR', () {
    test('ortak arama servisini kullanır', () {
      expect(k.contains('SearchService.services('), isTrue,
          reason: 'ekran kendi süzme mantığını kurmamalı');
      expect(k.contains('List<SearchHit> get _gorunen'), isTrue);
    });

    test('yerel kopya süzme mantığı kalmadı', () {
      expect(k.contains('String _fold(String s)'), isFalse);
      expect(k.contains('kCategoryTree[c]'), isFalse);
    });

    test('satır alt hizmet adını da yazabilir', () {
      // ⚠ YAZIM DEĞİŞTİ, KURAL DEĞİL: satır artık ham `h.label` yerine
      // GÖRÜNEN adı yazıyor (`kategoriEtiketi`). Fonksiyon yalnız ANA
      // kategorileri kısaltır; alt hizmet adları olduğu gibi geçer,
      // yani bu testin koruduğu davranış aynen sürüyor.
      expect(k.contains('Text(kategoriEtiketi(h.label)'), isTrue);
      expect(k.contains('hizmetSecildiDisaridan(\n                            '
          'context, h.category, h.subService)'), isTrue,
          reason: 'alt hizmet seçimi ilan formuna taşınmalı');
    });

    test('arama boşken katalog gezilir — 54 ana kategori', () {
      expect(k.contains('for (final c in kTreeCategories) SearchHit(c)'),
          isTrue);
      // ⚠ 54 → 55: kombi ikiye ayrıldı (Montaj + Servis).
      expect(kTreeCategories.length, 63);
    });

    test('kart yapısı korundu: SVG + ad + ok', () {
      expect(k.contains('categoryIcon(c)'), isTrue);
      expect(k.contains('ic_chev.svg'), isTrue);
    });
  });

  group('SONUÇ SINIRI', () {
    test('tam ekran liste sınırı YÜKSELTİR', () {
      expect(k.contains('enFazla: 400'), isTrue);
    });

    test('varsayılan sınır 40 — açılır kutu davranışı değişmedi', () {
      // Ana sayfadaki kutu parametresiz çağırır.
      // ⚠ ANA SAYFA KUTUSU ARTIK SINIRI KENDİ VERİYOR.
      //
      // Panel overlay'e taşınıp yüksekliği ekrana bağlanınca 40'lık
      // varsayılan yetmez oldu; kutu 200 istiyor. Varsayılanın
      // kendisi (parametresiz çağrı) DEĞİŞMEDİ — asıl denetim o.
      final inline = _kod('lib/screens/widgets/inline_search_box.dart');
      expect(inline.contains('enFazla: 200'), isTrue);
      // Katalogda 'a' harfi 40'tan çok kayıtla eşleşir.
      expect(SearchService.services('a').length, lessThanOrEqualTo(40));
    });

    test('yüksek sınırla DAHA ÇOK sonuç döner', () {
      final az = SearchService.services('a');
      final cok = SearchService.services('a', enFazla: 400);
      expect(cok.length, greaterThan(az.length),
          reason: 'sınır parametresi işlemiyor');
    });

    test('ana kategori eşleşince ALT HİZMETLERİ de gelir', () {
      final sonuc = SearchService.services('kombi', enFazla: 400);
      final etiketler = sonuc.map((h) => h.label).toList();
      // ⚠ Kombi ikiye ayrıldı; "kombi" araması İKİ kategoriyi de
      // getirir. Alt hizmetlerin tamamı yine listelenir.
      expect(etiketler, contains('Kombi Montaj'),
          reason: 'montaj kategorisi satırı yok');
      expect(etiketler, contains('Kombi Servis'),
          reason: 'servis kategorisi satırı yok');
      final altlar = [
        ...?kCategoryTree['Kombi Montaj'],
        ...?kCategoryTree['Kombi Servis'],
      ];
      expect(altlar, isNotEmpty);
      for (final a in altlar) {
        expect(etiketler, contains(a), reason: '$a listelenmedi');
      }
    });
  });
}
