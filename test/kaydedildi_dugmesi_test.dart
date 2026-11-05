// "KAYDEDİLDİ" DÜĞME DURUMU (28 Eki): web'de form sayfası kaydedince aynı
// sayfada kalır; onay alt bildirim değil düğmenin kendisinde görünür.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/kaydedildi.dart';
import 'package:hizmetcep/core/sys_state.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';

Widget _sar(Widget w) => MaterialApp(home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('SysButton: kaydedildi → "Kaydedildi", basılamaz; değilse "Kaydet"', (t) async {
    var basildi = 0;
    await t.pumpWidget(_sar(SysButton('Kaydet', kaydedildi: true, onPressed: () => basildi++)));
    expect(find.text(kKaydedildiEtiketi), findsOneWidget);
    expect(find.text('Kaydet'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await t.tap(find.byType(ElevatedButton));
    expect(basildi, 0);

    await t.pumpWidget(_sar(SysButton('Kaydet', onPressed: () => basildi++)));
    expect(find.text('Kaydet'), findsOneWidget);
    await t.tap(find.byType(ElevatedButton));
    expect(basildi, 1);
  });

  testWidgets('RefNextButton: kaydedildi → "Kaydedildi", basılamaz', (t) async {
    var basildi = 0;
    await t.pumpWidget(_sar(SizedBox(width: 300, child: RefNextButton('Adresi Güncelle', kaydedildi: true, onPressed: () => basildi++))));
    expect(find.text(kKaydedildiEtiketi), findsOneWidget);
    expect(find.text('Adresi Güncelle'), findsNothing);
    await t.tap(find.text(kKaydedildiEtiketi));
    expect(basildi, 0);
  });

  test('dört form sayfası düğmeye "kaydedildi" durumunu verir', () {
    String k(String d) => File('lib/screens/$d').readAsStringSync();
    for (final d in ['my_areas_screen.dart', 'my_categories_screen.dart']) {
      expect(k(d).contains('setEquals(_selected, _sonKaydedilen)'), isTrue, reason: d);
      expect(k(d).contains('_sonKaydedilen = {..._selected}'), isTrue, reason: d);
    }
    expect(k('addresses_screen.dart').contains('_sonKaydedilen == (_district, _neighborhood)'), isTrue);
    expect(k('addresses_screen.dart').contains('SnackBar('), isFalse, reason: 'alt bildirim yok');
    // 6 Kas (kullanıcı kararı): Profil Bilgilerim'de düğme sade "Kaydet";
    // başarı düğmenin ALTINDA 5 sn yeşil "Kaydedildi" yazısıyla gösterilir.
    expect(k('profile_info_screen.dart').contains("child: Text('Kaydedildi',"), isTrue);
    expect(k('profile_info_screen.dart').contains('Timer(const Duration(seconds: 5), () {'), isTrue);
  });
}
