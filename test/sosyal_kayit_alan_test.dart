// GOOGLE / APPLE KAYIT EKRANI — AD/SOYAD ALANLARI (5 Kas, kullanıcı talebi)
//
// · Ad ve Soyad, kayıt ekranıyla AYNI ortak alan görünümünü kullanır
//   (`refIkonluAlanDekoru`): kırmızı yıldız, kişi simgesi.
// · Sağlayıcının vermediği (boş) alanın çerçevesi KIRMIZIDIR; bilgi
//   girilince normal rengine döner (`eksik`).
// · Varsayılan `eksik: false` — ortak görünümü kullanan diğer ekranlar
//   değişmez.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/ref_tokens.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

Color _renk(InputBorder? b) => (b! as OutlineInputBorder).borderSide.color;

void main() {
  group('Ortak alan görünümü — eksik alan', () {
    test('eksik: çerçeve kırmızı (odakta da), hata mesajı yok', () {
      final d = refIkonluAlanDekoru('Soyad', 'assets/svg/ic_person.svg',
          zorunlu: true, eksik: true);
      expect(_renk(d.enabledBorder), RC.danger);
      expect(_renk(d.border), RC.danger);
      expect(_renk(d.focusedBorder), RC.danger);
      expect(d.errorText, isNull);
    });

    test('bilgi girilince (eksik değil) normal renk', () {
      final d = refIkonluAlanDekoru('Soyad', 'assets/svg/ic_person.svg',
          zorunlu: true);
      expect(_renk(d.enabledBorder), RC.borderLight);
      expect(_renk(d.border), RC.borderLight);
      expect(_renk(d.focusedBorder), RC.blue);
    });

    test('geçersiz değerde hata çerçevesi ve mesajı sürer', () {
      final d = refIkonluAlanDekoru('Soyad', 'assets/svg/ic_person.svg',
          zorunlu: true, hata: 'Soyad en az 2 harf olmalıdır.');
      expect(d.errorText, isNotNull);
      expect(_renk(d.errorBorder), RC.danger);
    });

    testWidgets('zorunlu alanda yıldız kırmızı', (tester) async {
      final d = refIkonluAlanDekoru('Ad', 'assets/svg/ic_person.svg',
          zorunlu: true);
      await tester.pumpWidget(MaterialApp(home: Material(child: d.hint!)));
      final rt = tester.widget<RichText>(find.byType(RichText).first);
      final yildiz = (rt.text as TextSpan)
          .children!
          .whereType<TextSpan>()
          .firstWhere((s) => (s.text ?? '').contains('*'));
      expect(yildiz.style!.color, RC.requiredStar);
    });
  });

  group('Google/Apple kayıt ekranı', () {
    final s = _kod('lib/screens/sosyal_kayit_screen.dart');

    test('ad ve soyad ortak görünümle; boşken eksik', () {
      expect(s.contains("refIkonluAlanDekoru(\n                      'Ad',"),
          isTrue);
      expect(s.contains("refIkonluAlanDekoru(\n                      'Soyad',"),
          isTrue);
      expect(s.contains('eksik: _ad.text.trim().isEmpty,'), isTrue);
      expect(s.contains('eksik: _soyad.text.trim().isEmpty,'), isTrue);
    });

    test('ekrana özel tek renkli etiket kalmadı', () {
      expect(s.contains("_alan('Ad *')"), isFalse);
      expect(s.contains("_alan('Soyad *')"), isFalse);
      expect(s.contains('labelText:'), isFalse);
    });
  });
}
