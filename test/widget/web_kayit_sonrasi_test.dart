import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/core/geri.dart';

/// KAYIT SONRASI GEZİNME — web'de aynı sayfada kalınır
///
/// Kullanıcı kararı: kenar çubuğundan açılan form sayfalarında
/// "Güncelle"ye basılınca web'de AYNI sayfada kalınır (geri dönmek
/// alakasız bir ekrana atıyordu). Mobilde bugünkü geri dönüş aynen.
/// Tek kaynak: `kayittanSonra` (lib/core/geri.dart).
void main() {
  String oku(String p) => File(p).readAsStringSync();

  testWidgets('mobil (VM): mobil eylemi çağrılır — davranış aynen',
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
    expect(cagrildi, isTrue);
  });

  test('web dalı hiçbir şey yapmaz (aynı sayfada kalınır)', () {
    final k = oku('lib/core/geri.dart');
    final i = k.indexOf('void kayittanSonra(');
    expect(i, greaterThan(0));
    final govde = k.substring(i, k.indexOf('\n}', i));
    expect(govde.contains('if (kIsWeb) {\n    return;\n  }'), isTrue);
    expect(govde.contains('mobilde();'), isTrue);
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
