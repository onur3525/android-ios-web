import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/core/geri.dart';

/// KAYIT SONRASI GEZİNME — her yerde aynı sayfada kalınır
///
/// Kullanıcı kararı: form sayfalarında kaydedince AYNI sayfada kalınır.
/// Önce yalnız web'de böyleydi; 28 Eki'den beri mobilde de ("Kaydedildi
/// yazısı kalmalı, kullanıcı kendi çıkmadan otomatik çıkmamalı").
/// Tek kaynak: `kayittanSonra` (lib/core/geri.dart).
void main() {
  String oku(String p) => File(p).readAsStringSync();

  testWidgets('mobil (VM): geri dönüş eylemi ÇAĞRILMAZ — ekranda kalınır',
      (t) async {
    var cagrildi = false;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => kayittanSonra(c, () => cagrildi = true),
          child: const Text('KAYDET'),
        ),
      ),
    ));
    await t.tap(find.text('KAYDET'));
    expect(cagrildi, isFalse);
    expect(find.text('KAYDET'), findsOneWidget);
  });

  test('kayittanSonra hiçbir platformda gezinmez', () {
    final k = oku('lib/core/geri.dart');
    expect(k.contains('void kayittanSonra(BuildContext context, VoidCallback mobilde) {}'), isTrue);
  });

  test('profilde telefon doğrulandıktan sonra profil ekranı kapanmaz', () {
    final k = oku('lib/screens/profile_info_screen.dart');
    final i = k.indexOf("sysToastOk(c, 'Telefon numaranız güncellendi');");
    final govde = k.substring(i, k.indexOf('},', i));
    expect(govde.contains('geriGit(c)'), isFalse);
    expect(govde.contains('_kaydedildi = true'), isTrue);
  });

  test('dört form sayfası kayıttan sonra kayittanSonra kullanır', () {
    const beklenen = <String, String>{
      'lib/screens/addresses_screen.dart':
          'kayittanSonra(context, () => Navigator.of(context).maybePop());',
      'lib/screens/profile_info_screen.dart':
          'kayittanSonra(context, () => geriGit(context));',
      'lib/screens/my_areas_screen.dart':
          'kayittanSonra(context, () => geriGit(context));',
      'lib/screens/my_categories_screen.dart':
          'kayittanSonra(context, () => geriGit(context));',
    };
    beklenen.forEach((yol, satir) {
      expect(oku(yol).contains(satir), isTrue, reason: yol);
    });
  });
}
