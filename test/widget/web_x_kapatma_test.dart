import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/ui/ref_widgets.dart';
import 'package:hizmetcep/ui/web_panel.dart';

/// WEB — X İLE KAPATMA TEK KAYNAKTA (`webKapat`)
///
/// Web'deki panel X'i, Esc ve alt panel X'i `webKapat`tan geçer:
/// geri dönülecek rota varsa EŞZAMANLI `pop`, yoksa ana sayfa. Eski
/// `maybePop`, rota yığındaki tek rotaysa sessizce hiçbir şey
/// yapmıyordu (web'de doğrudan açılan panel).
///
/// ⚠ MOBİL KİLİTLİ: alt panelin X'i Android/iOS'ta `maybePop`
/// çağırmaya devam eder.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  Widget uygulama(Widget ana) => MaterialApp(
        routes: {
          '/home': (_) => const Scaffold(body: Text('ANA')),
        },
        home: ana,
      );

  testWidgets('webKapat: üstte rota varsa onu kapatır', (t) async {
    await t.pumpWidget(uygulama(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
            builder: (c2) => Scaffold(
              body: TextButton(
                onPressed: () => webKapat(c2),
                child: const Text('KAPAT'),
              ),
            ),
          )),
          child: const Text('AC'),
        ),
      ),
    )));
    await t.tap(find.text('AC'));
    await t.pumpAndSettle();
    expect(find.text('KAPAT'), findsOneWidget);
    await t.tap(find.text('KAPAT'));
    await t.pumpAndSettle();
    expect(find.text('KAPAT'), findsNothing);
    expect(find.text('AC'), findsOneWidget);
  });

  testWidgets('webKapat: yığında tek rota varsa ana sayfaya gider (ölü X yok)',
      (t) async {
    await t.pumpWidget(uygulama(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => webKapat(c),
          child: const Text('KAPAT'),
        ),
      ),
    )));
    await t.tap(find.text('KAPAT'));
    await t.pumpAndSettle();
    expect(find.text('ANA'), findsOneWidget);
  });

  testWidgets('alt panelin X\'i paneli kapatır', (t) async {
    await t.pumpWidget(uygulama(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => RefBottomSheet.goster<void>(c,
              title: 'Destek Merkezi', child: const Text('ICERIK')),
          child: const Text('AC'),
        ),
      ),
    )));
    await t.tap(find.text('AC'));
    await t.pumpAndSettle();
    expect(find.text('ICERIK'), findsOneWidget);
    await t.tap(find.byWidgetPredicate(
        (w) => w is RefSvg && w.asset == 'assets/svg/ic_x.svg'));
    await t.pumpAndSettle();
    expect(find.text('ICERIK'), findsNothing);
  });

  test('web panelinde maybePop kalmadı; X ve Esc webKapat kullanır', () {
    final p = oku('lib/ui/web_panel.dart');
    final kod = p
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(kod.contains('maybePop('), isFalse);
    expect('webKapat(context)'.allMatches(kod).length, 3,
        reason: 'başlık X + başlıksız X + Esc');
  });

  test('alt panel X: web webKapat, mobil maybePop (aynen)', () {
    final w = oku('lib/ui/ref_widgets.dart');
    final i = w.indexOf("RefSvg('assets/svg/ic_x.svg', size: 18)");
    final once = w.substring(i - 700, i);
    expect(once.contains('if (kIsWeb) {\n                        webKapat(context);'),
        isTrue);
    expect(once.contains('Navigator.of(context).maybePop();'), isTrue);
  });
}
