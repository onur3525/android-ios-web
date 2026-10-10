import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/ui/web_oneri_dokunusu.dart';

/// WEB ARAMA ÖNERİSİ — DOKUNUŞ DAVRANIŞI
///
/// ⚠ `kIsWeb` derleme sabiti olduğu için web dalı VM testinde
/// koşturulamaz. Bu yüzden web satırlarının seçim kararını veren
/// ortak bileşen (`WebOneriDokunusu`) doğrudan pump edilir:
///
///   · kısa dokunuş / tıklama → seçim TEK KEZ
///   · parmakla kaydırma      → seçim YOK
///   · farenin sağ düğmesi    → seçim YOK
///   · iptal edilen işaretçi  → seçim YOK
///   · satır ağaçtan kalksa bile kalkış olayı seçimi tamamlar
void main() {
  Widget sar(Widget w) => MaterialApp(
        home: Scaffold(body: Center(child: w)),
      );

  Widget satir(VoidCallback onSec) => WebOneriDokunusu(
        onSec: onSec,
        child: const SizedBox(
          key: Key('satir'),
          width: 300,
          height: 48,
          child: ColoredBox(color: Color(0xFFFFFFFF)),
        ),
      );

  testWidgets('kısa dokunuş seçimi TEK KEZ yapar', (t) async {
    var sayac = 0;
    await t.pumpWidget(sar(satir(() => sayac++)));
    await t.tap(find.byKey(const Key('satir')));
    await t.pump();
    expect(sayac, 1);
  });

  testWidgets('fareyle sol tık seçer', (t) async {
    var sayac = 0;
    await t.pumpWidget(sar(satir(() => sayac++)));
    final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('satir'))),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton);
    await g.up();
    await t.pump();
    expect(sayac, 1);
  });

  testWidgets('kaydırma hareketi seçim SAYILMAZ', (t) async {
    var sayac = 0;
    await t.pumpWidget(sar(satir(() => sayac++)));
    final g = await t.startGesture(t.getCenter(find.byKey(const Key('satir'))));
    await g.moveBy(const Offset(0, kTouchSlop * 3));
    await g.moveBy(const Offset(0, -kTouchSlop * 3));
    await g.up();
    await t.pump();
    expect(sayac, 0,
        reason: 'parmak eşik ötesine kaydıysa geri dönse bile seçilmez');
  });

  testWidgets('farenin sağ düğmesi seçmez', (t) async {
    var sayac = 0;
    await t.pumpWidget(sar(satir(() => sayac++)));
    final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('satir'))),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton);
    await g.up();
    await t.pump();
    expect(sayac, 0);
  });

  testWidgets('iptal edilen işaretçi seçmez', (t) async {
    var sayac = 0;
    await t.pumpWidget(sar(satir(() => sayac++)));
    final g = await t.startGesture(t.getCenter(find.byKey(const Key('satir'))));
    await g.cancel();
    await t.pump();
    expect(sayac, 0);
  });

  testWidgets('satır basılıyken ağaçtan kalksa da seçim tamamlanır',
      (t) async {
    // Web'de odak kaybı ya da tarayıcı klavyesinin kapanması paneli
    // parmak kalkmadan önce kaldırabiliyor. Kalkış olayı basıldığı
    // andaki isabet yoluna teslim edildiği için seçim kaybolmamalı.
    var sayac = 0;
    final goster = ValueNotifier<bool>(true);
    addTearDown(goster.dispose);
    await t.pumpWidget(sar(ValueListenableBuilder<bool>(
      valueListenable: goster,
      builder: (_, g, __) =>
          g ? satir(() => sayac++) : const SizedBox.shrink(),
    )));
    final g = await t.startGesture(t.getCenter(find.byKey(const Key('satir'))));
    goster.value = false;
    await t.pump();
    expect(find.byKey(const Key('satir')), findsNothing);
    await g.up();
    await t.pump();
    expect(sayac, 1);
  });
}
