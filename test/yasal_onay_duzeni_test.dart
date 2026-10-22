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

  test('aydınlatma ve çerez politikası menüden okunabilir', () {
    final mobil = _kodu('lib/screens/profile_screen.dart');
    expect(mobil.contains("arguments: {'slug': 'kvkk', 'title': 'Aydınlatma Metni'}"), isTrue);
    expect(mobil.contains("arguments: {'slug': 'cookies', 'title': 'Çerez Politikası'}"), isTrue);
    final web = _kodu('lib/domain/profil_menusu.dart');
    expect(web.contains("rotaArgumani: {'slug': 'kvkk', 'title': 'Aydınlatma Metni'}"), isTrue);
    expect(web.contains("rotaArgumani: {'slug': 'cookies', 'title': 'Çerez Politikası'}"), isTrue);
  });

  test('cihaz kimliği yalnız oturum varken ya da giriş/kayıtta üretilir', () {
    final k = _kodu('lib/data/remote/api_client.dart');
    expect(k.contains("olustur: token != null || path.startsWith('/auth/')"), isTrue);
    expect(k.contains('await CihazKimligi.i.mevcut()'), isTrue);
  });
}
