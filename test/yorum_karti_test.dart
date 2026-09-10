// YORUM KARTI — AD, TARİH, HİZMET, AÇ/KAPA (KİLİT)
//
// ⚠ KULLANICI KURALLARI (9 Eyl):
//   • Profil fotoğrafı olmayacak.
//   • Ad "Gönül B." biçiminde — SOYAD HİÇBİR ŞEKİLDE görünmeyecek.
//   • Kartın sağ üstünde gün.ay.yıl biçiminde tarih.
//   • Adın altında, alınan hizmetin adı.
//   • Uzun yorumda "Göster" / "Küçült" ile kart açılıp kapanacak.
//
// ⚠ SOYADIN GÖRÜNMEMESİ EN KRİTİK MADDE: kart üç ekranda birden
// kullanılıyor (`provider_reviews`, `teklif_iste`,
// `teklif_talebi_detay`). Tek kopya olduğu için kural bir yerde
// bozulup ötekilerde kalamaz.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/yorum_gorunumu.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — AD KISALTMA', () {
    test('soyad yalnız baş harf', () {
      expect(kisaYazarAdi('Gönül Bütün'), 'Gönül B.');
      expect(kisaYazarAdi('Onur Bütün'), 'Onur B.');
    });

    test('⚠ ÜÇ KELİMEDE DE SOYAD SIZMAZ', () {
      // Son kelime soyad sayılır; aradakiler ada dâhildir.
      expect(kisaYazarAdi('Ayşe Nur Yılmaz'), 'Ayşe Nur Y.');
    });

    test('tek kelimede soyad yoktur', () {
      expect(kisaYazarAdi('Onur'), 'Onur');
    });

    test('boş ad çökertmez', () {
      expect(kisaYazarAdi('   '), 'Hizmet Alan');
    });

    test('⚠ TAM SOYAD HİÇBİR ÇIKTIDA YOK', () {
      for (final ad in const ['Gönül Bütün', 'Ayşe Nur Yılmaz']) {
        final soyad = ad.split(' ').last;
        expect(kisaYazarAdi(ad).contains(soyad), isFalse,
            reason: '$ad için soyad sızıyor');
      }
    });
  });

  group('2 — TARİH BİÇİMİ', () {
    test('gün.ay.yıl, iki haneli', () {
      expect(yorumTarihi(DateTime(2026, 9, 10)), '10.09.2026');
      expect(yorumTarihi(DateTime(2026, 1, 3)), '03.01.2026');
    });
  });

  group('3 — UZUN YORUM EŞİĞİ', () {
    test('kısa yorum açılır kapanır DEĞİLDİR', () {
      expect(uzunYorumMu('Çok iyi'), isFalse);
    });

    test('eşik üstü uzundur', () {
      expect(uzunYorumMu('a' * (kUzunYorumEsigi + 1)), isTrue);
      expect(uzunYorumMu('a' * kUzunYorumEsigi), isFalse);
    });
  });

  group('4 — KART SÖZLEŞMESİ', () {
    final k = _kodu('lib/screens/provider_reviews_screen.dart');

    test('⚠ PROFİL FOTOĞRAFI YOK', () {
      expect(k.contains('RefBasHarfAvatar'), isFalse,
          reason: 'yorum kartında avatar geri gelmiş');
    });

    test('ad, tarih, hizmet ve aç/kapa ortak kurallardan gelir', () {
      expect(k.contains('kisaYazarAdi('), isTrue);
      expect(k.contains('yorumTarihi(r.createdAt)'), isTrue);
      expect(k.contains('yorumHizmetAdi(context, r)'), isTrue);
      expect(k.contains('uzunYorumMu(metin)'), isTrue);
    });

    test('açıkken "Küçült", kapalıyken "Göster"', () {
      expect(k.contains("_acik ? 'Küçült' : 'Göster'"), isTrue);
    });

    test('⚠ KAPALIYKEN ÜÇ SATIR, AÇIKKEN SINIRSIZ', () {
      // Kart yüksekliğinin sabit kalması listenin düzenini korur.
      expect(k.contains('maxLines: (uzun && !_acik) ? 3 : null'), isTrue);
    });

    test('⚠ HİZMET ADI BULUNAMAZSA SATIR ÇİZİLMEZ', () {
      expect(k.contains('if (hizmet != null)'), isTrue,
          reason: 'hizmet adı yokken boş satır ya da uydurma metin');
    });
  });
}
