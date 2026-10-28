// MASAÜSTÜ WEB GENİŞLİĞİ (28 Eki, kullanıcı kararı — 2.): kenar çubuklu
// masaüstü web'de iki rolün bütün ekranları menünün yanından SAĞ KENARA
// kadar çizilir ("yarım kalmamalı, tüm ekranlara sığmalı"); listeler
// genişledikçe sütun ekler, detaylar da tam genişlik.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String p) => File(p).readAsStringSync();

void main() {
  test('kabuk içeriği menünün yanından sağ kenara kadar çizer (sınır yok)', () {
    final k = _kod('lib/ui/global_web_kabugu.dart');
    expect(k.contains('child: ColoredBox(color: RC.pageBg, child: child),'), isTrue);
    expect(k.contains('masaustuSutun'), isFalse);
    // Sayfa iskeleti de masaüstünde genişliği sınırlamaz.
    final r = _kod('lib/ui/ref_widgets.dart');
    expect(r.contains('const BoxConstraints(maxWidth: IcerikGenisligi.izgara)'), isFalse);
  });

  test('ızgarada sütun sınırı yok; detay sütunu tam genişlik', () {
    expect(_kod('lib/ui/masaustu_izgara.dart').contains('_enFazlaKolon'), isFalse);
    final d = _kod('lib/ui/masaustu_detay.dart');
    expect(d.contains('maxWidth: IcerikGenisligi.liste'), isFalse);
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
