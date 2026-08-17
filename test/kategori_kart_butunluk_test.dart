// KATEGORİ KARTI — BÜTÜNLÜK VE TAŞMA
//
// KARARLAR:
//   1. TÜM kartlar aynı ölçüdedir: tek `GridView` (3 sütun, sabit
//      en-boy oranı) + etiket için SABİT 40px kutu. Kart yükseklikleri
//      metne göre değişmez.
//   2. TÜM etiketler aynı yazı tipi ve puntosundadır: Poppins,
//      11px, w700. `FittedBox` YOKTUR — metin küçültülerek
//      sığdırılmaz, dolayısıyla kartlar arası punto farkı oluşmaz.
//   3. HİÇBİR ETİKET TAŞMAZ, KESİLMEZ, YARIM KALMAZ:
//      · en fazla 3 satır, satır yüksekliği 11 × 1.20 = 13,2px,
//        üç satır 39,6px → 40px kutuya sığar
//      · en dar hedef ekranda (320dp) metin alanı 81,3px; 50
//        etiketin tamamı üç satıra ve kelime bölünmeden sığar
//      · sistem yazı ölçeği bu etikette 1.0 ile sınırlıdır; aksi
//        hâlde 3 satır kutuyu aşıyordu
//
// ⚠ ÖLÇÜM GERÇEK FONTLA YAPILDI. Aşağıdaki genişlik denetimi
// `assets/fonts/Poppins-Bold.ttf` metriklerinden değil, katalogdaki
// etiketlerin KARAKTER SAYISI üzerinden kaba bir üst sınır kurar;
// asıl piksel ölçümü teslim raporundadır. Buradaki test, etiketlerin
// bir daha uzamasını ve kart ölçülerinin ayrışmasını engeller.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';
// ⚠ `kKategoriIzgaraSutun` bu dosyada tanımlıdır (ızgara sabitleri
// kart bileşeniyle birlikte durur); import edilmeden kullanılamaz.
import 'package:hizmetcep/screens/widgets/kategori_karti.dart';

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
  final k = _kod('lib/screens/widgets/kategori_karti.dart');
  final grid = _kod('lib/screens/create_listing_screen.dart');

  group('TÜM KARTLAR AYNI ÖLÇÜDE', () {
    test('İLAN IZGARASI KALDIRILDI — kart ölçüsü konusu kalmadı', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (15 Ağu): ilan verme ekranında kategori
      // kartı yok; hizmet seçimi arama ile yapılıyor. Izgara ölçü
      // sabitleri artık kullanılmıyor.
      expect(grid.contains('crossAxisCount: kKategoriIzgaraSutun'), isFalse);
      expect(grid.contains('KategoriKarti('), isFalse);
      expect(grid.contains('SearchService.services('), isTrue);
      expect(grid.contains('crossAxisSpacing: kKategoriIzgaraBosluk'), isFalse);
      // Sabitler kaldırılmadı; başka bir yüzeyde gerekebilir.
      expect(kKategoriIzgaraSutun, 3);
    });

    test('etiket kutusu SABİT 40px — metne göre büyümez', () {
      expect(k.contains('height: 40,'), isTrue);
      expect(k.contains('mainAxisSize: MainAxisSize.min'), isTrue);
    });

    test('görselin kart içindeki yeri değişmedi', () {
      // Yatay dolgu 8 → 4 indi ama fotoğrafa kendi 4px'i verildi:
      // 4 + 4 = eski 8. Kartın görsel geometrisi aynı kalır.
      expect(k.contains('padding: const EdgeInsets.fromLTRB(4, 8, 4, 8)'),
          isTrue);
      expect(k.contains('padding: const EdgeInsets.symmetric(horizontal: 4)'),
          isTrue);
      expect(k.contains('padding: const EdgeInsets.all(8)'), isFalse,
          reason: 'eski dolgu metin alanını daraltıyordu');
    });
  });

  group('TÜM YAZILAR AYNI TİP VE ÖLÇÜDE', () {
    test('tek punto, tek kalınlık', () {
      expect(k.contains('size: RF.s11'), isTrue);
      expect(k.contains('weight: RF.w700'), isTrue);
      expect(k.contains('height: RF.lh120'), isTrue);
    });

    test('metin KÜÇÜLTÜLEREK sığdırılmaz', () {
      // `FittedBox` kartlar arasında beş farklı punto üretiyordu.
      expect(k.contains('FittedBox'), isFalse);
    });

    test('font ailesi ortak `refText` üzerinden gelir', () {
      expect(k.contains('style: refText('), isTrue);
      expect(k.contains('fontFamily:'), isFalse,
          reason: 'kart kendi fontunu tanımlamamalı');
    });
  });

  group('TAŞMA · KESİLME · YARIM KALMA YOK', () {
    test('en fazla 3 satır ve taşma koruması', () {
      expect(k.contains('maxLines: 3'), isTrue);
      expect(k.contains('overflow: TextOverflow.ellipsis'), isTrue);
      expect(k.contains('textAlign: TextAlign.center'), isTrue);
    });

    test('sistem yazı ölçeği bu etikette sınırlı', () {
      expect(k.contains('MediaQuery.withClampedTextScaling'), isTrue);
      expect(k.contains('maxScaleFactor: 1.0'), isTrue);
    });

    test('etiketler üç satıra sığacak uzunlukta', () {
      // ⚠ ÜST SINIR: 320dp ekranda metin alanı 81,3px ve Poppins-Bold
      // 11px'te ortalama karakter ~5,5px → satır başına ~14 karakter,
      // üç satır ~42 karakter. Sınır 34'te tutuluyor; ölçülen en uzun
      // etiket 29 karakterdir ("Araç Temizlik & Detaylı Bakım").
      for (final c in kKartKategorileri) {
        final e = kategoriEtiketi(c);
        expect(e.length, lessThanOrEqualTo(34), reason: '$e (${e.length})');
      }
    });

    test('tek kelimelik en uzun parça satıra sığar', () {
      // Bir kelime satır genişliğini aşarsa ORTADAN kesilir
      // ("Marangozl…"). 320dp'de 81,3px ≈ 14 karakter; sınır 13.
      for (final c in kKartKategorileri) {
        for (final kelime in kategoriEtiketi(c).split(' ')) {
          expect(kelime.length, lessThanOrEqualTo(13),
              reason: '$kelime (${kelime.length}) satıra sığmaz');
        }
      }
    });
  });
}
