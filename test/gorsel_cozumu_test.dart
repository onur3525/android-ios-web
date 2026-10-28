// FOTOĞRAF BOYUTU (28 Eki, performans denetimi): yüklenen fotoğraf
// küçültülür; ağ görseli ekrandaki boyutuna göre çözülür; tam ekran
// yakınlaştırma tam çözünürlükte kalır.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/platform/gorsel_cozumu.dart';

String _kod(String yol) => File(yol).readAsStringSync();

Future<int?> _cozum(WidgetTester t,
    {double oran = 3, double? genislik, double? yukseklik}) async {
  int? sonuc;
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(devicePixelRatio: oran),
      child: Builder(builder: (context) {
        sonuc = gorselCozumGenisligi(context,
            genislik: genislik, yukseklik: yukseklik);
        return const SizedBox.shrink();
      }),
    ),
  );
  return sonuc;
}

void main() {
  group('çözüm genişliği', () {
    testWidgets('büyük kenar × piksel oranı × 1,5', (t) async {
      // 120 × 3 × 1,5 = 540
      expect(await _cozum(t, genislik: 120, yukseklik: 90), 540);
      // dikey kutuda büyük kenar yükseklik: 200 × 3 × 1,5 = 900
      expect(await _cozum(t, genislik: 100, yukseklik: 200), 900);
    });

    testWidgets('üst sınır 2048', (t) async {
      expect(await _cozum(t, genislik: 1000, yukseklik: 800),
          kAzamiCozumGenisligi);
    });

    testWidgets('boyut bilinmiyorsa null (tam çözünürlük)', (t) async {
      expect(await _cozum(t), isNull);
      expect(await _cozum(t, genislik: double.infinity), isNull);
      expect(await _cozum(t, genislik: 0, yukseklik: 0), isNull);
    });

    testWidgets('sonsuz kenar yok sayılır, sonlu olan kullanılır', (t) async {
      expect(await _cozum(t, genislik: 100, yukseklik: double.infinity), 450);
    });
  });

  group('kod', () {
    test('yükleme 1600 px ile sınırlı (gerçek API modu)', () {
      expect(kYuklemeGorselEnFazlaGenislik, 1600);
      final k = _kod('lib/screens/widgets/photo_picker.dart');
      expect(
          RegExp(r': kYuklemeGorselEnFazlaGenislik\)').allMatches(k).length, 2,
          reason: 'kamera ve galeri seçimi');
      expect(k.contains('kaliciGorselEnFazlaGenislik : null'), isFalse);
    });

    test('ağ görselleri ekrandaki boyutuna göre çözülür', () {
      for (final yol in [
        'lib/core/platform/yerel_gorsel_io.dart',
        'lib/screens/chat_screen.dart',
        'lib/screens/home_screen.dart',
      ]) {
        expect(_kod(yol).contains('cacheWidth: kisittanCozumGenisligi('), isTrue,
            reason: yol);
      }
    });

    test('tam ekran yakınlaştırmalı görüntüleyiciler TAM çözünürlükte', () {
      expect(
          _kod('lib/screens/chat_screen.dart')
              .contains('yerelGorsel(yol, tamCozunurluk: true)'),
          isTrue);
      expect(
          _kod('lib/screens/teklif_talebi_sohbet_screen.dart')
              .contains('yerelGorsel(yol, tamCozunurluk: true)'),
          isTrue);
      expect(
          _kod('lib/screens/widgets/foto_goruntuleyici.dart')
              .contains('tamCozunurluk: true,'),
          isTrue);
    });

    test('web ve mobil köprü imzası aynı', () {
      for (final yol in [
        'lib/core/platform/yerel_gorsel_io.dart',
        'lib/core/platform/yerel_gorsel_web.dart',
      ]) {
        expect(_kod(yol).contains('bool tamCozunurluk = false,'), isTrue,
            reason: yol);
      }
    });
  });
}
