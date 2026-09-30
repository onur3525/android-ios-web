import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/ui/panel_rotasi.dart';
import 'package:hizmetcep/ui/web_panel.dart';

/// WEB — KATEGORİ → İLAN AKIŞINDA X AKIŞIN TAMAMINI KAPATIR
///
/// Kullanıcı kararı: kategori kartıyla başlayan akışta hangi adımda
/// olursa olsun X bütün panelleri kapatır ve ana sayfaya döner. Bir
/// önceki ekrana dönmek kartın geri okuyla yapılır.
///
/// `kIsWeb` derleme sabiti olduğu için VM'de `akisRotasi` panel
/// üretmez; akış rotaları `akisRotasiIsaretle` ile elle işaretlenir.
/// ⚠ MOBİL: işaretsiz rotalarda `webKapat` bir seviye kapatır (değişmedi).
void main() {
  Route<void> akisSayfasi(String ad, {bool isaretli = true}) {
    final r = MaterialPageRoute<void>(
      builder: (c) => Scaffold(
        body: Column(children: [
          Text(ad),
          TextButton(
              onPressed: () => webKapat(c), child: Text('X-$ad')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(), child: Text('GERI-$ad')),
        ]),
      ),
    );
    if (isaretli) {
      akisRotasiIsaretle(r);
    }
    return r;
  }

  Future<NavigatorState> kur(WidgetTester t) async {
    final anahtar = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: anahtar,
      routes: {'/home': (_) => const Scaffold(body: Text('ANA'))},
      home: const Scaffold(body: Text('ANA')),
    ));
    final nav = anahtar.currentState!;
    nav.push(akisSayfasi('ALAN'));
    nav.push(akisSayfasi('KATEGORI'));
    nav.push(akisSayfasi('ILAN'));
    await t.pumpAndSettle();
    return nav;
  }

  testWidgets('X: son adımdan akışın tamamı kapanır, ana sayfa görünür',
      (t) async {
    await kur(t);
    expect(find.text('ILAN'), findsOneWidget);
    await t.tap(find.text('X-ILAN'));
    await t.pumpAndSettle();
    expect(find.text('ANA'), findsOneWidget);
    expect(find.text('KATEGORI'), findsNothing);
    expect(find.text('ALAN'), findsNothing);
  });

  testWidgets('X: ara adımdan da akışın tamamı kapanır', (t) async {
    final nav = await kur(t);
    nav.pop();
    await t.pumpAndSettle();
    await t.tap(find.text('X-KATEGORI'));
    await t.pumpAndSettle();
    expect(find.text('ANA'), findsOneWidget);
    expect(find.text('ALAN'), findsNothing);
  });

  testWidgets('geri oku yalnız bir önceki ekrana döner', (t) async {
    await kur(t);
    await t.tap(find.text('GERI-ILAN'));
    await t.pumpAndSettle();
    expect(find.text('KATEGORI'), findsOneWidget);
  });

  testWidgets('akış dışı rotada X bir seviye kapatır (değişmedi)',
      (t) async {
    final anahtar = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: anahtar,
      home: const Scaffold(body: Text('ANA')),
    ));
    anahtar.currentState!.push(akisSayfasi('BIR', isaretli: false));
    anahtar.currentState!.push(akisSayfasi('IKI', isaretli: false));
    await t.pumpAndSettle();
    await t.tap(find.text('X-IKI'));
    await t.pumpAndSettle();
    expect(find.text('BIR'), findsOneWidget);
  });

  testWidgets('yığının dibi de akışsa ana sayfaya gidilir (boş ekran yok)',
      (t) async {
    final anahtar = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: anahtar,
      routes: {'/home': (_) => const Scaffold(body: Text('ANA'))},
      onGenerateInitialRoutes: (_) => [akisSayfasi('DERIN')],
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('X-DERIN'));
    await t.pumpAndSettle();
    expect(find.text('ANA'), findsOneWidget);
  });
}
