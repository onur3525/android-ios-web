// MASAÜSTÜ WEB GENİŞLİĞİ (28 Eki, kullanıcı kararı): kenar çubuklu masaüstü
// web'de iki rolün bütün ekranları menünün yanından başlayan, en çok 1228 px
// genişlikte tek sütunda çizilir; listeler ızgara, detaylar okunur sütun.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/olcu.dart';

String _kod(String p) => File(p).readAsStringSync();

void main() {
  test('içerik sütunu tek kaynak: ızgara + iki yanda 14 px', () {
    expect(IcerikGenisligi.masaustuSutun, IcerikGenisligi.izgara + 28);
  });

  test('kabuk içerik sütununu menünün yanına (sola) yaslar ve sınırlar', () {
    final k = _kod('lib/ui/global_web_kabugu.dart');
    expect(k.contains('alignment: Alignment.topLeft'), isTrue);
    expect(k.contains('IcerikGenisligi.masaustuSutun'), isTrue);
    expect(k.contains('color: RC.pageBg'), isTrue);
  });

  test('hizmet alan listesi masaüstünde ızgara (hizmet verenle aynı diziliş)', () {
    final k = _kod('lib/screens/my_listings_screen.dart');
    expect(k.contains('if (masaustuNav(context))\n              MasaustuIzgara('), isTrue);
    expect(k.contains('children: [for (final oge in ogeler) ilanOgesi(oge)]'), isTrue);
  });

  test('iki rolün detayı aynı okunur sütun kuralını kullanır', () {
    expect(_kod('lib/screens/listing_detail_screen.dart').contains('MasaustuOkunurSutun(child: Column('), isTrue);
    expect(_kod('lib/ui/masaustu_detay.dart').contains('return MasaustuOkunurSutun(child: sutun);'), isTrue);
  });

  test('hizmet veren İşlerim masaüstü kenarları hizmet alanla aynı', () {
    final k = _kod('lib/screens/jobs_screen.dart');
    expect(k.contains('SizedBox(height: ustMenu ? 12 : 8)'), isTrue);
    expect(k.contains('padding: EdgeInsets.symmetric(horizontal: ustMenu ? 14 : 0)'), isTrue);
    expect('EdgeInsets.fromLTRB(ustMenu ? 14 : 20, 4, ustMenu ? 14 : 20, 24)'.allMatches(k).length, 2);
  });
}
