// ALT BAR GÖSTERGELERİ — KIRMIZI NOKTA VE SAYI ROZETİ (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (12 Eyl):
//   1. "Bildirim geldiğinde bildirimler ikonu bozulmadan, dikkatli
//      bir şekilde yap; nokta MAVİ olsun, okununca normal rengine
//      dönüşsün."
//   2. "Bul ikonunda talep için bir teklif geldiğinde sayı yuvarlak
//      kırmızı daire içinde yazılmalı ama Bul ikonunu kapatmamalı."
//
// ⚠ RENK AYNI GÜN İKİ KEZ DEĞİŞTİ: önce maviden kırmızıya, sonra
// kullanıcı kararıyla tekrar maviye. Karar kullanıcınındır.
//
// ⚠ BİLİNEN SINIR: mavi, uygulamanın SEÇİLİ SEKME rengidir.
// Bildirimler sekmesi aktifken ikon da nokta da mavi olur ve nokta
// yalnız BEYAZ HALKASIYLA ayrışır — bu yüzden halka kaldırılmamalı.
//
// ⚠ BU TEST KAYNAK OKUR, PİKSEL ÖLÇMEZ: renk ve konum sabitleri
// burada kilitli. Gerçek yerleşim `sekme_rozeti_konumu_test` içinde
// pump edilerek ölçülüyor — ikisi birbirinin yerine geçmez.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// [metin] içinde [bas] ile başlayan bölümü [son] sınırına kadar döner.
///
/// ⚠ SABİT KARAKTER PENCERESİ KULLANILMAZ: araya eklenen birkaç satır
/// pencereyi kaydırıp testi KURAL BOZULMADAN düşürürdü.
String _pencere(String metin, String bas, String son) {
  final i = metin.indexOf(bas);
  if (i < 0) {
    throw StateError('"$bas" bulunamadı');
  }
  final j = metin.indexOf(son, i + bas.length);
  if (j <= i) {
    throw StateError('"$son" sınırı bulunamadı');
  }
  return metin.substring(i, j);
}

void main() {
  final w = _kod('lib/ui/ref_widgets.dart');
  // Alt bar öğesinin çizim gövdesi.
  final altBar = _pencere(w, 'if (it.rozet)', 'const SizedBox(height: 4)');

  group('1 — ⚠ BİLDİRİM NOKTASI MAVİ', () {
    test('nokta `RC.blue` ile çizilir', () {
      expect(altBar.contains('color: RC.blue,'), isTrue);
      expect(altBar.contains('color: RC.danger'), isFalse,
          reason: 'nokta yine kırmızı');
    });

    test('⚠ BEYAZ HALKA DURUYOR — MAVİDE ŞART', () {
      // Halka olmadan nokta ikonun konturuna yapışır ve ikon bozuk
      // görünür. Mavi noktada ayrıca TEK ayrışma kaynağıdır: seçili
      // sekmede ikon da mavidir.
      expect(altBar.contains('border: Border.all(color: RC.white, width: 1.5)'),
          isTrue);
    });

    test('⚠ İKON ÖLÇÜSÜ DEĞİŞMEDİ', () {
      // "Bildirimler ikonu bozulmadan" — değişen yalnız dolgu rengi
      // ve noktanın köşeye teğet konumu.
      expect(altBar.contains('width: 9'), isTrue);
      expect(altBar.contains('height: 9'), isTrue);
      expect(w.contains('size: 22,'), isTrue);
    });

    test('⚠ OKUNUNCA KENDİLİĞİNDEN KAYBOLUR', () {
      // Ayrı bir "normale dön" adımı yok: gösterge okunmamış
      // sayısından türeyen `it.rozet` bayrağına bağlı.
      expect(altBar.contains('if (it.rozet)'), isTrue);
    });
  });

  group('2 — ⚠ "Bul" SAYI ROZETİ İKONU KAPATMAZ', () {
    test('rozet ikonun dışına alındı', () {
      // En az 17 px'lik rozet, `-10 / -8` ile 22 px'lik ikonun sağ üst
      // köşesine biniyordu.
      expect(altBar.contains('right: -14'), isTrue);
      expect(altBar.contains('right: -10'), isFalse,
          reason: 'rozet yine ikonun üstüne biniyor');
    });

    test('sayı kırmızı daire içinde', () {
      final rozet =
          _pencere(w, 'class RefSayiRozeti', 'class RefSegmentTabs');
      expect(rozet.contains('color: RC.danger'), isTrue);
      expect(rozet.contains('BorderRadius.circular(RR.circle)'), isTrue);
      // ⚠ Tek haneli sayıda DAİRE kalır, yassı hap görünmez.
      expect(
          rozet.contains('BoxConstraints(minWidth: 17, minHeight: 17)'), isTrue);
    });

    test('⚠ SAYI KOŞULA BAĞLI', () {
      // Sıfırken rozet hiç çizilmez; boş bir daire "teklif var"
      // izlenimi verirdi.
      expect(altBar.contains('if (it.belirginRozetSayisi > 0)'), isTrue);
    });

    test('⚠ RENK AYRIMI BİLİNÇLİDİR', () {
      // Nokta MAVİ, "Bul" sayı rozeti KIRMIZI. Nokta "yeni var" der,
      // rozet "kaç tane" der — farklı renk, farklı dil.
      final rozet =
          _pencere(w, 'class RefSayiRozeti', 'class RefSegmentTabs');
      expect(altBar.contains('color: RC.blue,'), isTrue);
      expect(rozet.contains('color: RC.danger'), isTrue);
    });
  });
}
