// YASAL ONAY DÜZENİ (22 Eki, KVKK): onay isteyen tek belge Kullanım
// Sözleşmesi; aydınlatma/gizlilik/çerez bilgilendirmedir ve her zaman
// okunabilir. İlk kez soruluyorsa "güncellendi" denmez. Oturumsuz
// ziyaretçinin tarayıcısına cihaz kimliği yazılmaz (çerez politikası).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  test('onay penceresi: ilk kez soruluyorsa "onayınız gerekiyor"', () {
    final k = _kodu('lib/ui/yasal_kabul_kapisi.dart');
    expect(k.contains("b['firstTime'] == true"), isTrue);
    expect(k.contains("'\$baslik onayınız gerekiyor'"), isTrue);
  });

  // 23 Eki (kullanıcı kararı): dört belge profilde TEK satır altında
  // ("Sözleşmeler ve Politikalar"); satır belge listesini açar. Aydınlatma
  // ve çerez politikası her zaman buradan okunabilir kalmalı.
  test('aydınlatma ve çerez politikası menüden okunabilir (tek satır → belge listesi)', () {
    final mobil = _kodu('lib/screens/profile_screen.dart');
    expect(mobil.contains("Navigator.pushNamed(c, '/profile/legal')"), isTrue);
    expect(mobil.contains("'slug': 'terms'"), isFalse, 'profilde belgeler ayrı ayrı durmaz');
    final menu = _kodu('lib/domain/profil_menusu.dart');
    expect(menu.contains("rota: '/profile/legal'"), isTrue);
    for (final slug in ['terms', 'privacy', 'kvkk', 'cookies']) {
      expect(menu.contains("slug: '$slug'"), isTrue, reason: slug);
    }
    expect(RegExp(r"slug: 'cookies',[\s\S]*?yalnizWeb: true").hasMatch(menu), isTrue,
        reason: 'Çerez Politikası yalnız web');
    final sayfa = _kodu('lib/screens/yasal_belgeler_screen.dart');
    expect(sayfa.contains('kYasalBelgeler'), isTrue);
    expect(sayfa.contains("Navigator.pushNamed(context, '/legal'"), isTrue);
    expect(_kodu('lib/main.dart').contains("ad == '/profile/legal'"), isTrue);
  });

  test('cihaz kimliği yalnız oturum varken ya da giriş/kayıtta üretilir', () {
    final k = _kodu('lib/data/remote/api_client.dart');
    expect(k.contains("olustur: token != null || path.startsWith('/auth/')"), isTrue);
    expect(k.contains('await CihazKimligi.i.mevcut()'), isTrue);
  });
}
