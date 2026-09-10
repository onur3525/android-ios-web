// HİZMET VEREN KARTLARI AYNI BİLGİYİ GÖSTERİR — KİLİT
//
// ⚠ KULLANICI KURALI (9 Eyl): "Bu kartlar ayrı ayrı değerlere,
// bilgilere sahip olamaz. Bir iş tamamladıysa iş tamamlama, yorum
// aldıysa yorum, puan aldıysa puan, adres değiştiyse adres, isim
// değiştiyse isim — bilgileri tüm bu kartlarda AYNI ANDA değişmeli."
//
// ⚠ ÖLÇÜLEN ÜÇ SAPMA (hepsi düzeltildi):
//   1. PUAN — "Sonuçlar" hiç yorumu olmayana `0.0`, "Teklif İste"
//      `—` yazıyordu.
//   2. KONUM — "Sonuçlar" müşterinin ilçesini tercih ediyor, "Teklif
//      İste" her zaman ilk bölgeyi gösteriyordu; aynı kişi iki
//      ekranda farklı ilçede görünüyordu.
//   3. TAMAMLANAN İŞ — sayım üç dosyada AYRI AYRI yazılmıştı.
//
// ⚠ KAYNAK METNİ OKUNUR: iki ekranın da kurulması gerçek hesap,
// ilan, teklif ve yorum verisi ister; bu ortamda Flutter SDK yok,
// widget testi yazılıp KOŞULAMIYOR. Bu test yapısal sözleşmeyi
// kilitler — "ekranda doğru görünüyor" iddiası ETMEZ.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final sonuclar = _kodu('lib/screens/sonuclar_screen.dart');
  final teklifIste = _kodu('lib/screens/teklif_iste_screen.dart');
  final ozet = _kodu('lib/domain/saglayici_ozeti.dart');
  final satir = _kodu('lib/screens/widgets/saglayici_ozet_satiri.dart');

  group('1 — TEK ÇİZİM', () {
    test('iki ekran da ortak bilgi satırını kullanır', () {
      expect(sonuclar.contains('SaglayiciOzetSatiri('), isTrue);
      expect(teklifIste.contains('SaglayiciOzetSatiri('), isTrue);
    });

    test('⚠ KOPYA ÇİZİM GERİ GELMEDİ', () {
      // Dört satırın metinleri artık YALNIZ ortak bileşende üretilir.
      // Ekranlardan biri kendi satırını yazmaya başlarsa ikisi
      // yeniden ayrışabilir.
      for (final k in <String>[sonuclar, teklifIste]) {
        expect(k.contains('iş tamamladı'), isFalse,
            reason: 'ekran kendi bilgi satırını çiziyor');
        expect(k.contains('yorum)'), isFalse,
            reason: 'ekran kendi yorum sayısını çiziyor');
      }
      expect(satir.contains('iş tamamladı'), isTrue);
      expect(satir.contains('yorum)'), isTrue);
    });
  });

  group('2 — TEK VERİ KAYNAĞI', () {
    test('iki ekran da özeti aynı fonksiyondan alır', () {
      expect(sonuclar.contains('gercekSaglayiciOzeti('), isTrue);
      expect(teklifIste.contains('gercekSaglayiciOzeti('), isTrue);
    });

    test('tamamlanan iş sayımı TEK yerde tanımlı', () {
      // Ortak tanım burada.
      expect(ozet.contains('int tamamlananIsSayisi('), isTrue);
      // Üç ekran da ona DELEGE eder, kendi döngüsünü kurmaz.
      //
      // ⚠ `isTamamlanmisIs` yokluğu ARANMAZ: `offer_detail_screen`
      // aynı alanı BAŞKA bir iş için (ilan süzme) de okuyor; yokluk
      // denetimi orada yanlış alarm verirdi. Onun yerine delegasyon
      // ARANIR — varlık denetimi güvenlidir.
      expect(_kodu('lib/screens/offer_detail_screen.dart')
              .contains('tamamlananIsSayisi('), isTrue,
          reason: 'offer_detail ortak sayıma delege etmiyor');
      expect(sonuclar.contains('tamamlananIsSayisi('), isTrue);
      // ⚠ `teklif_iste` sayımı DOĞRUDAN çağırmaz — özeti
      // `gercekSaglayiciOzeti` üzerinden alır, sayım da onun içinde
      // yapılır. Zinciri kısaltmak iki kartı yeniden ayırırdı.
      // Kendi sayım döngüsü kalmamalı — bu iki dosyada `isTamamlanmisIs`
      // başka bir işte KULLANILMIYOR, yokluk denetimi güvenli.
      expect(sonuclar.contains('isTamamlanmisIs'), isFalse);
      expect(teklifIste.contains('isTamamlanmisIs'), isFalse);
    });

    test('konum kuralı TEK yerde: müşterinin ilçesi varsa o', () {
      expect(ozet.contains('bolgeler.contains(musteriIlcesi)'), isTrue);
      // Ekranlar kendi konum kuralını yazmamalı.
      expect(teklifIste.contains('serviceDistricts.first'), isFalse,
          reason: 'Teklif İste hâlâ kendi konum kuralını uyguluyor');
    });
  });

  group('3 — PUANIN BOŞ HÂLİ TEK BİÇİM', () {
    test('hiç yorum yoksa "—", "0.0" DEĞİL', () {
      expect(satir.contains("ozet.puan == null"), isTrue);
      expect(satir.contains("'—'"), isTrue);
      // ⚠ Kartın GÖSTERDİĞİ değer sıfıra düşürülmemeli. Listeyi
      // kuran `MockSaglayici.puan` alanı `double` (null olamaz) ve
      // sıralama için kullanılır; karta giderken "yorum yoksa null"
      // dönüşümü uygulanır.
      expect(sonuclar.contains('yorumSayisi == 0 ? null'), isTrue,
          reason: 'yorumu olmayan için "0.0" gösterilir');
    });

    test('⚠ null = yorum yok; tip bunu ZORUNLU kılar', () {
      expect(ozet.contains('double? puan'), isTrue,
          reason: 'puan null olamıyorsa "değerlendirilmemiş" durumu '
              'kaybolur');
    });
  });

  group('4 — SONUÇLAR EKRANI DÜĞMESİ MAVİ', () {
    test('yeşil dolgu kaldırıldı', () {
      expect(sonuclar.contains('color: RC.blue'), isTrue);
      expect(sonuclar.contains('color: HC.green'), isFalse,
          reason: 'düğme hâlâ yeşil');
    });
  });

  group('5 — ÇANTA İKONU BU EKRANDA DA', () {
    test('ortak satır çanta kullanır, kalkan kullanmaz', () {
      expect(satir.contains('assets/svg/ic_briefcase.svg'), isTrue);
      expect(satir.contains('assets/svg/ic_shieldok.svg'), isFalse);
    });
  });
}
