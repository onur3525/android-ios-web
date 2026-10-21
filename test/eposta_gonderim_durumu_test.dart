// E-POSTA DOĞRULAMA — GÖNDERİM SONUCU EKRANDA GÖRÜNÜR (21 Eki, kullanıcı bulgusu)
//
// Başarı uyarıları (`sysToastOk`) bilerek çizilmiyor; doğrulama bağlantısı
// gönderildiğinde ekranda hiçbir şey değişmiyordu. Sonuç artık e-posta
// alanının altında yeşil kutu olarak görünür (kullanıcının görseliyle
// birebir: "Doğrulama e-postası gönderildi." + iki satır açıklama).
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/screens/widgets/eposta_gonderildi_kutusu.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final p = _kod('lib/screens/profile_info_screen.dart');

  test('iki gönderim de kutuyu açar', () {
    expect('setState(() => _epostaGonderildi = true);'.allMatches(p).length, 2);
  });

  test('kutu düğmelerin ÜSTÜNDE, yalnız onaysızken çizilir', () {
    final kutu = p.indexOf('if (_epostaGonderildi && !onayli) ...[');
    expect(kutu, greaterThan(-1));
    expect(p.indexOf('const EpostaGonderildiKutusu()'), greaterThan(kutu));
    expect(kutu, lessThan(p.indexOf("label: const Text('E-posta Adresini Doğrula')")));
  });

  test('adres değişince kutu kalkar', () {
    expect(p.contains('onChanged: (_) => setState(() => _epostaGonderildi = false)'),
        isTrue);
  });

  testWidgets('kutu metni görseldeki gibi', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: EpostaGonderildiKutusu())));
    expect(find.text('Doğrulama e-postası gönderildi.'), findsOneWidget);
    expect(
        find.text('E-posta kutunuzu kontrol edin.\n'
            'Bulamazsanız spam klasörüne bakın.'),
        findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
  });
}
