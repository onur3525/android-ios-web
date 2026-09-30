import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WEB — KATEGORİ → HİZMET → İLAN OLUŞTURMA AKIŞI PANEL OLARAK
///
/// Kullanıcı kararı: ana sayfadaki kategori (çatı) kartlarından
/// başlayan akış ve ilan oluşturma ekranları web'de giriş ekranı gibi
/// panel olarak açılır, tam ekran değil. Geçişlerin TEK kaynağı
/// `akisRotasi` (lib/ui/panel_rotasi.dart).
///
/// ⚠ MOBİL KİLİTLİ: `akisRotasi` web değilse bugünkü
/// `MaterialPageRoute`un kendisini döndürür.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  test('akisRotasi: mobilde düz sayfa, web\'de panel', () {
    final k = oku('lib/ui/panel_rotasi.dart');
    final i = k.indexOf('Route<T> akisRotasi<T>(');
    expect(i, greaterThan(0));
    final govde = k.substring(i, k.indexOf('\n}\n', i));
    expect(
        govde.contains('if (!kIsWeb) {\n'
            '    return MaterialPageRoute<T>(settings: settings, builder: builder);'),
        isTrue,
        reason: 'mobil yol değişmiş');
    expect(govde.contains('return panelRotasi<T>('), isTrue);
  });

  test('akıştaki bütün geçişler akisRotasi kullanır', () {
    final beklenen = <String, int>{
      'lib/screens/home_screen.dart': 2, // çatı kartı + arama sonrası ilan
      'lib/screens/hizmet_alani_screen.dart': 2, // iki kategori girişi
      'lib/screens/category_screen.dart': 1, // oturumlu ilan
      'lib/screens/search_screen.dart': 1, // kategori satırı
      'lib/main.dart': 2, // /customer/new-listing + /listing/new (web)
    };
    beklenen.forEach((yol, adet) {
      expect('akisRotasi<void>('.allMatches(oku(yol)).length, adet,
          reason: yol);
    });
    expect(oku('lib/screens/hizmet_alani_screen.dart')
        .contains('MaterialPageRoute<void>('), isFalse);
  });

  test('/listing/new: mobilde haritada, web\'de panel rotası', () {
    final m = oku('lib/main.dart');
    expect(
        m.contains(
            'if (!kIsWeb) PreLoginListingRoute.name: preLoginListingBuilder,'),
        isTrue);
    expect(m.contains('if (kIsWeb && ad == PreLoginListingRoute.name) {'),
        isTrue);
  });

  test('panelde zemin saydam, geri oku yerine kartın X\'i', () {
    final c = oku('lib/screens/category_screen.dart');
    expect(c.contains('backgroundColor: panelde ? Colors.transparent : RC.pageBg'),
        isTrue);
    expect(c.contains('geriDugmesi: panelde ? false : null'), isTrue);
    expect(c.contains(': sayfa,'), isTrue,
        reason: 'mobilde gövde önceki SafeArea > ListView olmalı');

    final h = oku('lib/screens/hizmet_alani_screen.dart');
    expect(h.contains('if (!WebPanel.panelMi(context)) ...['), isTrue);

    final l = oku('lib/screens/create_listing_screen.dart');
    expect(
        'WebPanel.panelMi(context) ? Colors.transparent : RC.pageBg'
            .allMatches(l)
            .length,
        2,
        reason: 'ilan formu + tamamlandı adımı');
  });
}
