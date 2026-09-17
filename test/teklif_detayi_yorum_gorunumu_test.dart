// TEKLİF DETAYI — YORUM VE PUAN GÖRÜNÜMÜ ORTAK (KİLİT)
//
// ⚠ KULLANICI BULGULARI (10 Eyl):
//   • "Yorum grafiği tutarsız ve yıldız verme oranları %'li
//     görünüyor. Burada % değil, kaç kişi kaç yıldız verdiyse
//     karşısına yazılacak."
//   • "Çubuk barlar teklif aldaki sistem gibi dolmalı veya azalmalı."
//   • "Hizmet alan yorum kartı tamamen teklif al ekranlarındaki gibi
//     olmalı; profil fotoğrafı olmayacak, soyad tam yazılmayacak
//     (Gönül B.), yıldızların yanında '5 puan' yazmayacak."
//   • "Bu ekrandaki tüm yıldızlar diğer ekranlardaki gibi sarı
//     olacak."
//
// ⚠ KÖK NEDEN — HER ŞEYİN İKİ KOPYASI VARDI: bu ekran hem dağılım
// satırını hem yorum kartını KENDİ çiziyordu. İkisi de yeni
// kuralların hiçbirini almamıştı; üstelik çubuk `heightFactor`
// verilmediği için HİÇ dolmuyordu — "tutarsız" denen şey buydu.
//
// ⚠ YÜZDE YANILTICIYDI: tek yorumu olan hizmet veren için "%100"
// yazıyordu. Sayı büyük görünüyor ama arkasında bir kişi var.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final teklif = _kodu('lib/screens/offer_detail_screen.dart');
  final dagilim = _kodu('lib/screens/widgets/puan_dagilim_satiri.dart');
  final puanim = _kodu('lib/screens/my_reviews_screen.dart');

  group('1 — PUAN DAĞILIMI TEK KAYNAKTAN', () {
    test('iki ekran da ortak satırı kullanır', () {
      expect(teklif.contains('PuanDagilimSatiri('), isTrue);
      expect(puanim.contains('PuanDagilimSatiri('), isTrue);
    });

    test('⚠ KOPYA ÇİZİM GERİ GELMEDİ', () {
      expect(teklif.contains('class _DagilimSatiri'), isFalse);
      expect(teklif.contains('FractionallySizedBox'), isFalse,
          reason: 'ekran kendi çubuğunu çiziyor');
      expect(puanim.contains('FractionallySizedBox'), isFalse);
    });

    test('⚠ ADET YAZILIR, YÜZDE DEĞİL', () {
      expect(dagilim.contains(r"Text('$adet'"), isTrue);
      expect(teklif.contains(r"'%$yuzde'"), isFalse);
    });

    test('⚠ ÇUBUK GERÇEKTEN DOLAR', () {
      // `heightFactor` olmadan dolgunun yüksekliği sıfır kalır.
      expect(dagilim.contains('heightFactor: 1'), isTrue);
      expect(dagilim.contains('widthFactor: oran'), isTrue);
    });

    test('⚠ SIFIRDA BOŞ, SIFIRA BÖLME YOK', () {
      expect(dagilim.contains('toplam == 0 ? 0.0 : adet / toplam'), isTrue);
      expect(dagilim.contains('0.03'), isFalse,
          reason: 'taban dolgu geri gelmiş — 0 oy dolu görünür');
    });
  });

  group('2 — YORUM KARTI ORTAK', () {
    test('ekran ortak kartı kullanır', () {
      expect(teklif.contains('YorumKarti('), isTrue);
    });

    test('⚠ KOPYA YORUM SATIRI KALDIRILDI', () {
      // Fotoğraf, tam soyad, "N puan" ve aç/kapa eksikliği hep o
      // kopyadan geliyordu.
      expect(teklif.contains('_YorumSatiri'), isFalse);
      expect(teklif.contains('RefBasHarfAvatar'), isFalse);
      expect(teklif.contains(r"'${review.stars} puan'"), isFalse);
    });
  });

  group('3 — YILDIZLAR SARI', () {
    test('mavi yıldız kalmadı', () {
      expect(teklif.contains('ic_starb'), isFalse,
          reason: 'mavi yıldız (`ic_starb`) hâlâ kullanılıyor');
    });

    test('dağılım satırında da sarı', () {
      expect(dagilim.contains('0xFFF5A319'), isTrue);
    });
  });

  group('4 — TUTAR BİÇİMİ', () {
    test('ortak biçimden gelir', () {
      expect(teklif.contains('tutarMetni(offer.amount)'), isTrue);
      expect(teklif.contains('tl(offer.amount)'), isFalse);
    });
  });
}
