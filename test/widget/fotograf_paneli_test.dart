// FOTOĞRAF KAYNAĞI PANELİ — TEK KAYNAK VE TEK GÖRÜNÜM
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "Tüm ilan oluşturma ekranlarında
// fotoğraf yükleme kartları bu şekilde olmalı; ikonlar, yazılar,
// renkler, boyutlar hepsi aynı olmalı. Mesaj gönderirken fotoğraf
// yükleme ikonuna basınca da bu şekilde görünmeli."
//
// ⚠ ÖLÇÜLEN SAPMA: iki ayrı panel vardı. İlan akışınınki renkli 38 px
// rozet + açıklama + chevron taşıyordu; mesajlaşmanınki rozetsiz,
// açıklamasız, chevronsuz, iki ikonu da mavi ve sırası TERSTİ.
//
// Bu dosya iki şeyi kilitler:
//   1. GÖRÜNÜM — panel gerçekten pump edilir, metinler/ölçüler/
//      renkler RenderBox ve widget ağacından OKUNUR.
//   2. TEK KAYNAK — iki çağıran da kendi panelini ÇİZMEZ, ortak
//      fonksiyonu çağırır (kaynak metni).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/screens/widgets/fotograf_kaynak_paneli.dart';
import 'package:hizmetcep/ui/ref_tokens.dart';
import 'package:image_picker/image_picker.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  /// Paneli açan basit bir ekran kurar; seçilen kaynağı [secilen]e
  /// yazar.
  Future<void> panelAc(WidgetTester t, List<ImageSource?> secilen) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => Center(
            child: ElevatedButton(
              onPressed: () async =>
                  secilen.add(await fotografKaynagiSec(c)),
              child: const Text('AÇ'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('AÇ'));
    await t.pumpAndSettle();
  }

  /// Metni verilen satırın rozet dairesini bulur.
  ///
  /// ⚠ ANAHTAR YOK, METİNDEN GİDİLİR: satırın kendisi `Row`, rozet o
  /// satırdaki İLK `Container`dır.
  Container _rozet(WidgetTester t, String baslik) {
    final satir = find.ancestor(of: find.text(baslik), matching: find.byType(Row));
    return t.widget<Container>(
        find.descendant(of: satir.first, matching: find.byType(Container)).first);
  }

  group('1 — GÖRÜNÜM', () {
    testWidgets('başlık ve iki seçenek — metinler birebir', (t) async {
      await panelAc(t, <ImageSource?>[]);

      expect(find.text('Fotoğraf ekle'), findsOneWidget,
          reason: 'başlık küçük "e" ile tek biçim olmalı');
      expect(find.text('Fotoğraf Çek'), findsOneWidget);
      expect(find.text('Kamerayı açar'), findsOneWidget);
      expect(find.text('Galeriden Seç'), findsOneWidget);
      expect(find.text('Kayıtlı fotoğraflarınız'), findsOneWidget);

      // ⚠ ESKİ MESAJLAŞMA METNİ ARTIK YOK.
      expect(find.text('Kamera ile Çek'), findsNothing);
    });

    testWidgets('SIRA: önce Fotoğraf Çek, sonra Galeriden Seç', (t) async {
      await panelAc(t, <ImageSource?>[]);
      final kamera = t.getCenter(find.text('Fotoğraf Çek')).dy;
      final galeri = t.getCenter(find.text('Galeriden Seç')).dy;
      expect(kamera, lessThan(galeri),
          reason: 'mesajlaşmadaki ters sıra geri gelmiş');
    });

    testWidgets('rozet renkleri: kamera MAVİ, galeri YEŞİL', (t) async {
      await panelAc(t, <ImageSource?>[]);
      expect((_rozet(t, 'Fotoğraf Çek').decoration as BoxDecoration).color,
          RC.blue);
      expect((_rozet(t, 'Galeriden Seç').decoration as BoxDecoration).color,
          RC.success);
    });

    testWidgets('rozet ölçüsü 38 ve daire', (t) async {
      await panelAc(t, <ImageSource?>[]);
      for (final baslik in const ['Fotoğraf Çek', 'Galeriden Seç']) {
        final c = _rozet(t, baslik);
        expect(c.constraints?.maxWidth, 38, reason: '$baslik rozeti dar/geniş');
        expect((c.decoration as BoxDecoration).shape, BoxShape.circle);
      }
    });

    testWidgets('seçim DEĞER olarak döner, panel kapanır', (t) async {
      final secilen = <ImageSource?>[];
      await panelAc(t, secilen);
      await t.tap(find.text('Galeriden Seç'));
      await t.pumpAndSettle();
      expect(secilen.single, ImageSource.gallery);
      expect(find.text('Fotoğraf ekle'), findsNothing,
          reason: 'panel kapanmadı');
    });
  });

  group('2 — TEK KAYNAK', () {
    test('ilan/teklif akışı ortak paneli çağırır, kopya çizmez', () {
      final k = _kodu('lib/screens/widgets/photo_picker.dart');
      expect(k.contains('fotografKaynagiSec(context)'), isTrue);
      // ⚠ Kopya panel işareti: kendi başlığını yazıyorsa iki panel
      // yeniden ayrışabilir.
      expect(k.contains("title: 'Fotoğraf ekle'"), isFalse,
          reason: 'panel kopyası geri gelmiş');
    });

    test('mesajlaşma akışı ortak paneli çağırır, kopya çizmez', () {
      final k = _kodu('lib/screens/widgets/sohbet_fotograf_akisi.dart');
      expect(k.contains('fotografKaynagiSec(context)'), isTrue);
      expect(k.contains('RefBottomSheet.goster'), isFalse,
          reason: 'mesajlaşma kendi panelini çiziyor');
    });

    test('⚠ İLAN OLUŞTURMA EKRANLARI AYNI SEÇİCİYİ KULLANIR', () {
      // Panel `ListingPhotoPicker` içinden açılır; iki ilan akışı da
      // bu bileşeni kullandığı sürece panel de aynıdır.
      for (final yol in const [
        'lib/screens/create_listing_screen.dart',
        'lib/screens/teklif_iste_screen.dart',
      ]) {
        expect(_kodu(yol).contains('ListingPhotoPicker('), isTrue,
            reason: '$yol ortak fotoğraf seçicisini kullanmıyor');
      }
    });
  });
}
