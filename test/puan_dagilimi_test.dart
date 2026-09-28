// PUAN DAĞILIMI VE YORUM KARTI TEKLİĞİ — KİLİT
//
// ⚠ KULLANICI BULGUSU (9 Eyl): "Puan grafiğinde kaç yıldız
// verildiyse hesaplanarak içi dolmalı, azalmalı."
//
// KÖK NEDEN: `FractionallySizedBox`a `heightFactor` VERİLMEMİŞTİ.
// Yalnız `widthFactor` verildiğinde çocuğa gevşek yükseklik geçer;
// `ColoredBox`un kendi ölçüsü olmadığı için yüksekliği SIFIR oluyor
// ve dolgu hiçbir oranda görünmüyordu. Genişlik hep doğru
// hesaplanıyordu — görünmeyen şey yükseklikti.
//
// ⚠ İKİNCİ BULGU (aynı ekran): "Genel Puanım" ekranı yorum kartını
// KENDİ çiziyordu ve yeni kuralların hiçbirini almamıştı — profil
// fotoğrafı duruyordu, ad TAM SOYADIYLA yazıyordu, uzun yorumda
// aç/kapa yoktu. Ayrıca hizmet adı "X · X" diye tekrar ediyordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final my = _kodu('lib/screens/my_reviews_screen.dart');
  final pr = _kodu('lib/screens/provider_reviews_screen.dart');

  group('1 — DAĞILIM ÇUBUĞU DOLAR', () {
    test('⚠ heightFactor VERİLİR', () {
      expect(my.contains('heightFactor: 1'), isTrue,
          reason: 'dolgunun yüksekliği sıfır kalır, çubuk boş görünür');
    });

    test('oran gerçek sayıdan hesaplanır', () {
      expect(my.contains('n / _count'), isTrue,
          reason: 'dolgu oranı yıldız sayısından gelmiyor');
    });

    test('⚠ SIFIRDA ÇUBUK TAMAMEN BOŞ (kullanıcı kararı, 9 Eyl)', () {
      // ÖNCEDEN taban %3 vardı (`Math.max(3, ...)` referansı): hiç oy
      // almamış yıldız da bir miktar dolu görünüyor, "az da olsa puan
      // var" izlenimi veriyordu. Kullanıcı bunu istemedi.
      //
      // Oran artık DOĞRUDAN uygulanır; gri raylar zaten görünür
      // olduğu için satırın ölçek olduğu yine anlaşılıyor.
      expect(my.contains('widthFactor: oran,'), isTrue);
      expect(my.contains('oran < 0.03 ? 0.03 : oran'), isFalse,
          reason: 'taban dolgu geri gelmiş — 0 oy dolu görünür');
    });

    test('⚠ SIFIRA BÖLME KORUNDU', () {
      // Hiç değerlendirme yokken `n / _count` NaN üretirdi.
      expect(my.contains('_count == 0 ? 0.0 : n / _count'), isTrue);
    });
  });

  group('2 — YORUM KARTI TEK ÇİZİM', () {
    test('"Genel Puanım" ekranı ortak gövdeyi kullanır', () {
      expect(my.contains('YorumKartiGovde('), isTrue);
    });

    test('⚠ KOPYA KART GERİ GELMEDİ', () {
      // Profil fotoğrafı ve kendi metin çizimi bu ekranda olmamalı.
      expect(my.contains('RefBasHarfAvatar'), isFalse,
          reason: 'yorum kartında avatar geri gelmiş');
    });

    test('⚠ TAM AD GEÇİRİLİR, KISALTMA BİLEŞENDE YAPILIR', () {
      // Çağıran kendi kısaltmasını yazarsa iki ekran ayrışır ve
      // soyad sızıntısı tam böyle olur.
      expect(my.contains('adTam: author'), isTrue);
      expect(my.contains('kisaYazarAdi('), isFalse,
          reason: 'kısaltma çağıranda yapılıyor');
      expect(pr.contains('kisaYazarAdi('), isTrue,
          reason: 'kısaltma bileşenin içinde olmalı');
    });

    test('⚠ HİZMET ADI TEKRARI GİDERİLDİ', () {
      // Veri `title` ve `category` alanlarını aynı değerle
      // döndürebiliyordu: "Doğalgaz Tesisatı · Doğalgaz Tesisatı".
      expect(my.contains('category == title'), isTrue,
          reason: 'aynı ad iki kez yazılır');
    });

    test('iki giriş, tek gövde', () {
      // `Review` tutan ekranlar sarmalayıcıyı, ham veri tutan ekran
      // doğrudan gövdeyi kullanır.
      expect(pr.contains('class YorumKarti extends StatelessWidget'), isTrue);
      expect(pr.contains('class YorumKartiGovde extends StatefulWidget'),
          isTrue);
    });
  });
}
