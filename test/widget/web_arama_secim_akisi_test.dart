import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/data/services/search_service.dart';
import 'package:hizmetcep/screens/widgets/inline_search_box.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';
import 'package:hizmetcep/ui/web_oneri_dokunusu.dart';

/// WEB ARAMA → HİZMET SEÇİMİ AKIŞI (ana sayfa kutusu)
///
/// `kIsWeb` derleme sabiti olduğu için web dalı `webDavranisi: true`
/// ile açılır. Uygulamadaki çağrı bu parametreyi VERMEZ (varsayılan
/// `kIsWeb`); mobil dal ayrıca `webDavranisi: false` ile denetlenir.
///
/// Kilitlenen sözleşme:
///   1. normal dokunuş → seçim TEK KEZ, panel kapanır
///   2. sürükleme → seçim YOK, panel açık
///   3. panel içinde satır dışı yere dokunma → panel açık
///   4. panel dışına dokunma → panel kapanır, seçim YOK
///   5. X → panel kapanır
///   6. web'de ODAK KAYBI paneli kapatmaz; ardından dokunuş seçer
///   7. web'de iç liste kaydırmaz (tek kaydırıcı sayfa)
///   8. mobil dal: overlay + ilk temasta seçim AYNEN
void main() {
  const sorgu = 'kombi';

  Future<List<String>> kur(WidgetTester t, {bool web = true}) async {
    final secimler = <String>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ⚠ "Dışarı" alanı kutunun ÜSTÜNDE: sonuç sayısı ne olursa
              // olsun panel onu ekrandan itemez.
              const SizedBox(
                key: Key('disari'),
                height: 60,
                child: ColoredBox(color: Color(0xFFEEEEEE)),
              ),
              InlineSearchBox(
                title: 'Hangi hizmete ihtiyacınız var?',
                subtitle: 'Örnek',
                webDavranisi: web,
                onSecim: (k, a) => secimler.add('$k|$a'),
              ),
            ],
          ),
        ),
      ),
    ));
    await t.tap(find.byType(RefSearchBox));
    await t.pump();
    await t.pump();
    await t.enterText(find.byType(TextField), sorgu);
    await t.pump();
    return secimler;
  }

  Finder satirlar() => find.byType(WebOneriDokunusu);

  setUpAll(() {
    if (SearchService.services(sorgu).isEmpty) {
      throw StateError('"$sorgu" için arama sonucu yok — test verisi geçersiz');
    }
  });

  testWidgets('web: sonuçlar sayfa içinde görünür', (t) async {
    await kur(t);
    expect(satirlar(), findsWidgets);
  });

  testWidgets('web: normal dokunuş seçer ve paneli kapatır', (t) async {
    final secimler = await kur(t);
    await t.tap(satirlar().first);
    await t.pump();
    expect(secimler.length, 1);
    expect(satirlar(), findsNothing);
    expect(find.byType(RefSearchBox), findsOneWidget);
  });

  testWidgets('web: odak düşse de panel açık kalır, dokunuş seçer',
      (t) async {
    final secimler = await kur(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    expect(satirlar(), findsWidgets,
        reason: 'web: panel odak kaybıyla kapanmamalı');
    await t.tap(satirlar().first);
    await t.pump();
    expect(secimler.length, 1);
  });

  testWidgets('web: sürükleme seçim yapmaz, panel açık kalır', (t) async {
    final secimler = await kur(t);
    await t.drag(satirlar().first, const Offset(0, -120));
    await t.pump();
    expect(secimler, isEmpty);
    expect(satirlar(), findsWidgets);
  });

  testWidgets('web: panel içinde satır dışına dokunma paneli kapatmaz',
      (t) async {
    final secimler = await kur(t);
    final liste = find.descendant(
        of: find.byType(InlineSearchBox), matching: find.byType(ListView));
    // ListView'in üst dolgusu (4 px) — hiçbir satıra ait değil.
    await t.tapAt(t.getTopLeft(liste) + const Offset(20, 1));
    await t.pump();
    expect(secimler, isEmpty);
    expect(satirlar(), findsWidgets);
  });

  testWidgets('web: panel dışına dokunma paneli kapatır, seçmez', (t) async {
    final secimler = await kur(t);
    await t.tap(find.byKey(const Key('disari')));
    await t.pump();
    expect(secimler, isEmpty);
    expect(satirlar(), findsNothing);
    expect(find.byType(RefSearchBox), findsOneWidget);
  });

  testWidgets('web: X paneli kapatır', (t) async {
    final secimler = await kur(t);
    final x = find.byWidgetPredicate(
        (w) => w is RefSvg && w.asset == 'assets/svg/ic_x.svg');
    expect(x, findsOneWidget);
    await t.tap(x);
    await t.pump();
    expect(secimler, isEmpty);
    expect(satirlar(), findsNothing);
  });

  testWidgets('web: iç liste kaydırmaz (tek kaydırıcı sayfa)', (t) async {
    await kur(t);
    final liste = t.widget<ListView>(find.descendant(
        of: find.byType(InlineSearchBox), matching: find.byType(ListView)));
    expect(liste.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('mobil: overlay + ilk temasta seçim aynen', (t) async {
    final secimler = await kur(t, web: false);
    expect(satirlar(), findsNothing,
        reason: 'mobil satırlar web dokunuş bileşenine bağlanmaz');
    final liste = find.byType(ListView);
    expect(liste, findsOneWidget);
    expect(t.widget<ListView>(liste).physics, isNull,
        reason: 'mobilde varsayılan kaydırma fiziği');
    final g = await t.startGesture(t.getCenter(
        find.descendant(of: liste, matching: find.byType(InkWell)).first));
    await t.pump();
    expect(secimler.length, 1, reason: 'mobil: seçim ilk temasta');
    await g.up();
    await t.pump();
    expect(secimler.length, 1);
  });
}
