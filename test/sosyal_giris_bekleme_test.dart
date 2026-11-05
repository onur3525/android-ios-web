// GOOGLE / APPLE İLE DEVAM — BEKLEME EKRANI (5 Kas, kullanıcı kararı)
//
// E-posta seçildikten sonra giriş/kayıt formu görünmeden rol ekranına
// (ya da Üyelik Koşulları'na) geçilir; arada tam ekran bekleme görünümü.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/sosyal_giris_dugmeleri.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  testWidgets('bekleme görünümü: logo + dönen işaret, form yok', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SosyalGirisBekleme()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byType(TextField), findsNothing);
  });

  group('akış', () {
    final k = _kod('lib/ui/sosyal_giris_dugmeleri.dart');
    final i = k.indexOf('Future<void> _devam(SosyalSaglayici s) async {');
    final g = k.substring(i, k.indexOf('Route<void> _beklemeRotasi()'));

    test('bekleme ekranı Google/Apple isteğinden ÖNCE açılır', () {
      expect(g.indexOf('unawaited(nav.push(bekleme));'), greaterThan(0));
      expect(g.indexOf('unawaited(nav.push(bekleme));'),
          lessThan(g.indexOf('auth.sosyalGiris(s, rol: widget.rol)')));
    });

    test('hesap yoksa bekleme ekranı yerini Üyelik Koşulları\'na bırakır', () {
      expect(g.contains('nav.replace(oldRoute: bekleme, newRoute: kayit);'), isTrue);
      expect(g.contains('await kayit.popped;'), isTrue);
    });

    test('vazgeçme/hata: bekleme kalkar (yalnız hâlâ en üstteyse)', () {
      expect(g.contains('if (bekleme.isCurrent) {\n        nav.removeRoute(bekleme);'), isTrue);
      final iptal = g.indexOf('if (sonuc.iptal) {');
      expect(g.substring(iptal, iptal + 80).contains('beklemeyiKaldir();'), isTrue);
    });

    test('bekleme ekranı geçişsiz ve geri tuşuyla kapanmaz', () {
      expect(k.contains('transitionDuration: Duration.zero,'), isTrue);
      expect(k.contains('canPop: false,'), isTrue);
    });
  });
}
