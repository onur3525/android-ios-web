// MASAÜSTÜ IZGARA — TEMBEL ÇİZİM (28 Eki): masaüstü web'de de yalnız
// görünen satırlar çizilir; kolon kuralı tek kaynaktan.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/masaustu_izgara.dart';

void main() {
  test('kolon sayısı: en az 360 px kart, en çok 3 kolon', () {
    expect(masaustuKolonSayisi(300, 10), 1);
    expect(masaustuKolonSayisi(729, 10), 1);
    expect(masaustuKolonSayisi(730, 10), 2);
    expect(masaustuKolonSayisi(1100, 10), 3);
    expect(masaustuKolonSayisi(2560, 10), 3);
  });

  testWidgets('mobilde liste tembel: 500 kartın yalnız görünenleri çizilir', (t) async {
    var cizilen = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MasaustuListe(
          adet: 500,
          itemBuilder: (_, i) {
            cizilen++;
            return SizedBox(height: 100, child: Text('kart $i'));
          },
        ),
      ),
    ));
    expect(find.text('kart 0'), findsOneWidget);
    expect(find.text('kart 499'), findsNothing);
    expect(cizilen, lessThan(20));
  });

  test('kod: masaüstü dalı ListView ile satır satır kurulur (hepsini birden çizmez)', () {
    final k = File('lib/ui/masaustu_izgara.dart').readAsStringSync();
    final liste = k.substring(k.indexOf('class MasaustuListe'));
    expect(liste.contains('SingleChildScrollView'), isFalse);
    expect(liste.contains('for (var i = 0; i < adet; i++)'), isFalse);
    expect(liste.contains('itemCount: satirSayisi'), isTrue);
    expect(liste.contains('CrossAxisAlignment.start'), isTrue);
    expect(k.contains('final kolon = masaustuKolonSayisi(genislik, aralik);'), isTrue);
  });
}
