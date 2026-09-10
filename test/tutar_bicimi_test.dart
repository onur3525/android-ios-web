// TUTAR BİÇİMİ VE TALEP KARTI DÜZENİ — KİLİT
//
// ⚠ KULLANICI KURALLARI (9 Eyl):
//   • "TL'yi otomatik ata."
//   • "Hizmet veren fiyat girerken 1000 yazdığında 1.000 olarak
//     otomatik atasın. 1, 10, 100 haricinde sonraki büyük rakamlara
//     otomatik nokta konulsun."
//   • "Teklif bekleniyor / Teklif geldi yazıları altta olmasın, isim
//     bilgisinin yanında yer alsın; teklif geldiğinde gelen tutar da
//     görünsün."
//
// ⚠ ÖNCEDEN BİÇİM HİÇ YOKTU: tutar dört ayrı yerde
// `'${talep.teklifFiyati} TL'` diye ham yazılıyordu; 3000 ekranda
// "3000 TL" çıkıyordu. Dört kopya, biri düzeltilse ötekiler
// ayrışırdı.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/tutar_bicimi.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — BİNLİK AYRACI', () {
    test('⚠ 1, 10, 100 OLDUĞU GİBİ KALIR', () {
      expect(binlikAyir(1), '1');
      expect(binlikAyir(10), '10');
      expect(binlikAyir(100), '100');
    });

    test('dört basamak ve üstü ayrılır', () {
      expect(binlikAyir(1000), '1.000');
      expect(binlikAyir(3000), '3.000');
      expect(binlikAyir(12500), '12.500');
      expect(binlikAyir(999999), '999.999');
      expect(binlikAyir(1000000), '1.000.000');
    });

    test('sıfır ve negatif', () {
      expect(binlikAyir(0), '0');
      expect(binlikAyir(-2500), '-2.500');
    });
  });

  group('2 — "TL" TEK YERDE EKLENİR', () {
    test('tutar metni', () {
      expect(tutarMetni(3000), '3.000 TL');
      expect(tutarMetni(150), '150 TL');
    });

    test('⚠ EKRANLAR KENDİ "TL"SİNİ YAZMAZ', () {
      // Dört kopyanın geri gelmemesi için: hiçbir ekran ham
      // `${...} TL` kalıbını kullanmamalı.
      for (final yol in const [
        'lib/screens/teklif_istediklerim_screen.dart',
        'lib/screens/teklif_talebi_detay_screen.dart',
        'lib/screens/my_listings_screen.dart',
      ]) {
        expect(_kodu(yol).contains(r'teklifFiyati} TL'), isFalse,
            reason: '$yol tutarı ham yazıyor');
      }
    });
  });

  group('3 — OKUMA', () {
    test('⚠ AYRAÇLI METİN ÇÖZÜLEBİLİR', () {
      // Alan artık "3.000" tutuyor; `int.tryParse` null döner ve
      // geçerli fiyat REDDEDİLİRDİ.
      expect(int.tryParse('3.000'), isNull);
      expect(tutarOku('3.000'), 3000);
      expect(tutarOku('1.500 TL'), 1500);
    });

    test('rakamsız girişte null', () {
      expect(tutarOku(''), isNull);
      expect(tutarOku('abc'), isNull);
    });

    test('fiyat alanı okumayı `tutarOku` ile yapar', () {
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('tutarOku(_fiyat.text)'), isTrue);
      expect(k.contains('int.tryParse(_fiyat.text'), isFalse,
          reason: 'ayraçlı metin int.tryParse ile okunuyor — '
              'geçerli fiyat reddedilir');
    });
  });

  group('4 — CANLI BİÇİMLENDİRME', () {
    const f = TutarBicimlendirici();

    TextEditingValue uygula(String metin) => f.formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(
            text: metin,
            selection: TextSelection.collapsed(offset: metin.length),
          ),
        );

    test('yazarken nokta eklenir', () {
      expect(uygula('1').text, '1');
      expect(uygula('10').text, '10');
      expect(uygula('100').text, '100');
      expect(uygula('1000').text, '1.000');
      expect(uygula('1000000').text, '1.000.000');
    });

    test('zaten ayraçlı metin bozulmaz', () {
      expect(uygula('1.000').text, '1.000');
    });

    test('⚠ ALAN BOŞALTILABİLİR — "0" YAZILMAZ', () {
      // Rakam kalmadıysa boş döner; aksi hâlde kullanıcı son rakamı
      // silemez, alan "0" ile kilitlenirdi.
      expect(uygula('').text, '');
    });

    test('imleç sona alınır', () {
      final v = uygula('12500');
      expect(v.text, '12.500');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('fiyat alanı biçimlendiriciyi kullanır', () {
      final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('TutarBicimlendirici()'), isTrue);
    });
  });

  group('5 — KART DÜZENİ', () {
    final k = _kodu('lib/screens/teklif_istediklerim_screen.dart');

    test('durum rozeti ismin YANINDA, altta değil', () {
      final iAd = k.indexOf('maskeliAd(talep.saglayiciAdi)');
      final iRozet = k.indexOf('Text(metin,');
      final iIstatistik = k.indexOf('iş tamamladı');
      expect(iRozet, greaterThan(iAd), reason: 'rozet addan önce çiziliyor');
      expect(iRozet, lessThan(iIstatistik),
          reason: 'rozet hâlâ istatistiklerin altında — '
              'ismin yanına taşınmamış');
    });

    test('teklif geldiyse tutar rozetin altında', () {
      expect(k.contains('tutarMetni(talep.teklifFiyati!)'), isTrue);
      expect(k.contains('if (talep.teklifFiyati != null)'), isTrue,
          reason: 'teklif yokken tutar ya da yer tutucu gösteriliyor');
    });
  });
}
