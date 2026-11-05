// KOD TEKRAR GÖNDERME BAĞLANTISI — YUVARLAK OK İKONU (5 Kas, kullanıcı kararı)
//
// İkon SOLDA, yazının renginde; üç SMS kod yüzeyi tek bileşeni kullanır.
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

void main() {
  testWidgets('ikon solda, yazıyla aynı renkte; dokununca çalışır',
      (tester) async {
    var n = 0;
    await tester.pumpWidget(MaterialApp(
        home: Material(
            child: Center(
                child: RefTekrarGonder(
                    metin: 'Kodu tekrar gönder', onTap: () => n++)))));
    final ikon = find.byIcon(Icons.refresh);
    final yazi = find.text('Kodu tekrar gönder');
    expect(ikon, findsOneWidget);
    expect(yazi, findsOneWidget);
    expect(tester.getCenter(ikon).dx, lessThan(tester.getCenter(yazi).dx));
    expect(tester.widget<Icon>(ikon).color, RC.blue);
    expect(tester.widget<Text>(yazi).style!.color, RC.blue);
    await tester.tap(yazi);
    expect(n, 1);
  });

  test('üç SMS kod yüzeyi ortak bileşeni kullanır', () {
    expect(_kod('lib/ui/ref_widgets.dart').contains("RefTekrarGonder(\n              metin: 'Tekrar Gönder',"), isTrue);
    expect(_kod('lib/screens/profil_tamamlama_screen.dart').contains("RefTekrarGonder(\n        metin: 'Kodu tekrar gönder',"), isTrue);
    expect(_kod('lib/screens/widgets/ilan_otp_adimi.dart').contains("RefTekrarGonder(\n                    metin: 'Kodu Tekrar Gönder',"), isTrue);
  });
}
