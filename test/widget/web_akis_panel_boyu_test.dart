import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WEB — KATEGORİ → HİZMET → İLAN AKIŞINDA PANEL BOYU SABİT
///
/// Kullanıcı kararı: kategori kartına basınca açılan panel ne
/// boyuttaysa, akışın sonraki panelleri de AYNI boyda kalır; hizmet
/// çoksa kart büyümez, içerik kayar.
///
/// `WebPanel.panelMi` yalnız web'de true olduğu için panel dalı VM
/// testinde çizilemez; kural kaynak metniyle kilitlenir.
void main() {
  final k = File('lib/ui/web_panel.dart').readAsStringSync();

  test('akış paneli ilk panelin boyunu kullanır (min = max = boy)', () {
    expect(k.contains('final akisRota = akisRotasiMi(rota) ? rota : null;'),
        isTrue);
    expect(k.contains('_AkisBoyu.sabit(akisRota)'), isTrue);
    expect(
        k.contains('minHeight: akisBoyu == null\n'
            '                ? 0\n'
            '                : (akisBoyu < ustSinir ? akisBoyu : ustSinir),'),
        isTrue);
    expect(
        k.contains('maxHeight: akisBoyu == null\n'
            '                ? ustSinir\n'
            '                : (akisBoyu < ustSinir ? akisBoyu : ustSinir),'),
        isTrue);
  });

  test('ilk panel doğal boyunu bir kez bildirir; sahip kapanınca unutulur',
      () {
    final i = k.indexOf('class _AkisBoyu {');
    expect(i, greaterThan(0));
    final govde = k.substring(i, k.indexOf('\n}\n', i));
    expect(govde.contains('!sahip.isActive'), isTrue);
    expect(govde.contains('_boy == null && boy > 0'), isTrue);
    expect(k.contains('? (h) => _AkisBoyu.olc(akisRota, h)'), isTrue);
  });

  test('akış dışı paneller eski kurala bağlı (içerik kadar, en çok %85)',
      () {
    expect(k.contains('final ustSinir = MediaQuery.sizeOf(context).height * 0.85;'),
        isTrue);
    // Akış yoksa `akisBoyu` null → min 0 / max üst sınır (yukarıdaki
    // ifadeler); ölçüm de yapılmaz.
    expect(k.contains('onBoy: akisRota != null && akisBoyu == null'), isTrue);
  });
}
