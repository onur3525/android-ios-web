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

  test('6 Kas: Profil Bilgilerim kayıttan / telefon onayından sonra ekranda kalır', () {
    // Telefon satır içinde onaylanır, ayrı kod ekranı açılıp kapanmaz;
    // Kaydet ekrandan çıkmaz, altında 5 sn "Kaydedildi" görünür.
    final k = oku('lib/screens/profile_info_screen.dart');
    expect(k.contains('geriGit('), isFalse);
    expect(k.contains('Navigator.pop('), isFalse);
    expect(k.contains('Navigator.push('), isFalse);
    expect(k.contains('_kaydedildiGoster();'), isTrue);
  });

  test('üç form sayfası kayıttan sonra kayittanSonra kullanır', () {
    const beklenen = <String, String>{
      'lib/screens/addresses_screen.dart':
          'kayittanSonra(context, () => Navigator.of(context).maybePop());',
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
