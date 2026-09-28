// TEKLİF ROZETİ — TEK KAYNAK VE TEK METİN (KİLİT)
//
// ⚠ KULLANICI KURALI (9 Eyl, kesin kural): "Sana tek tek ekran
// düzelttirmek istemiyorum. Mantık her yerde birbirine bağlı olmalı.
// Burada teklif gelmedi yazısı nasılsa diğer yerlerde de aynı olmalı."
//
// ⚠ BU KURALIN GEREKÇESİ ÖLÇÜLDÜ: aynı rozet iki dosyada AYRI AYRI
// yazılmıştı (`my_listings_screen` ve `jobs_screen`, ikisinde de
// `_TeklifRozeti`). "Henüz" sözcüğünün kaldırılması istendiğinde
// yalnız biri düzeltilmiş, öteki eski metinle kalmıştı.
//
// Bu test iki şeyi kilitler:
//   1. METİN — 0 iken "Teklif verilmedi" ("Henüz" YOK), 1+ iken
//      "N teklif verildi"; ve rozetin yanında İKON YOK.
//   2. TEK KAYNAK — hiçbir ekran kendi rozetini yeniden yazmaz.
//
// ⚠ 1. bölüm gerçek widget'ı pump eder (kaynak metni değil): "dosyada
// doğru yazıyor" demek ekranda doğru çizildiğini kanıtlamaz.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/screens/widgets/teklif_rozeti.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  Future<void> ciz(WidgetTester t, int sayi) => t.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: TeklifRozeti(sayi: sayi))),
      ));

  group('1 — METİN', () {
    test('0 iken "Henüz" YOK', () {
      expect(teklifEtiketi(0), 'Teklif verilmedi');
    });

    test('1+ iken sayı ve "teklif verildi"', () {
      expect(teklifEtiketi(1), '1 teklif verildi');
      expect(teklifEtiketi(7), '7 teklif verildi');
    });

    testWidgets('rozet ekranda aynı metni çizer', (t) async {
      await ciz(t, 0);
      expect(find.text('Teklif verilmedi'), findsOneWidget);
      expect(find.textContaining('Henüz'), findsNothing);

      await ciz(t, 3);
      await t.pump();
      expect(find.text('3 teklif verildi'), findsOneWidget);
    });

    testWidgets('⚠ YANINDA İKON YOK', (t) async {
      // Konuşma balonu ikonu kaldırıldı: rozet metni zaten durumu
      // söylüyordu, ikon "mesaj var" gibi yanlış anlam taşıyordu.
      await ciz(t, 0);
      final ikon = find.descendant(
          of: find.byType(TeklifRozeti), matching: find.byType(Image));
      expect(ikon, findsNothing);
      expect(_kodu('lib/screens/widgets/teklif_rozeti.dart').contains('ic_chat'),
          isFalse,
          reason: 'ikon geri gelmiş');
    });
  });

  group('2 — TEK KAYNAK', () {
    const ekranlar = <String>[
      'lib/screens/my_listings_screen.dart',
      'lib/screens/jobs_screen.dart',
    ];

    test('iki ekran da ortak rozeti kullanır', () {
      for (final yol in ekranlar) {
        expect(_kodu(yol).contains('TeklifRozeti(sayi:'), isTrue,
            reason: '$yol ortak rozeti kullanmıyor');
      }
    });

    test('⚠ KOPYA ROZET GERİ GELMEDİ', () {
      for (final yol in ekranlar) {
        final k = _kodu(yol);
        expect(k.contains('class _TeklifRozeti'), isFalse,
            reason: '$yol kendi rozetini yeniden yazmış');
        expect(k.contains('teklif verildi'), isFalse,
            reason: '$yol metni kendi üretiyor');
      }
    });

    test('boş durum cümlesi de aynı dilde', () {
      // Aynı durumu iki farklı cümleyle anlatmak, kullanıcının
      // şikâyet ettiği tutarsızlığın kendisi.
      final k = _kodu('lib/screens/listing_detail_screen.dart');
      expect(k.contains('Bu ilana teklif verilmedi.'), isTrue);
      expect(k.contains('Bu ilana henüz teklif verilmedi.'), isFalse);
    });
  });
}
