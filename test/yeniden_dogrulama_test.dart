// YENİDEN KİMLİK DOĞRULAMA (15 Eki güvenlik denetimi, karar 2). Hesap
// silme şifre panelini kullanır.
//
// 6 Kas (kullanıcı kararı): telefon ve e-posta değişikliği ŞİFRE İSTEMEZ;
// numara yeni numaraya gelen SMS koduyla, e-posta bağlantıyla değişir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  test('6 Kas: telefon değişikliği şifre SORMAZ; satır içi SMS koduyla', () {
    final p = _oku('lib/screens/profile_info_screen.dart');
    expect(p.contains('sifreIleDogrula('), isFalse);
    expect(p.contains('mevcutSifre:'), isFalse);
    expect(p.contains('gonderici: _telefonOnayli ? auth.telefonDegisimiKodGonder : null'),
        isTrue);
    expect(p.contains('await auth.telefonDegisimiDogrula(challengeId, _telKod.text)'),
        isTrue);
  });

  test('şifre sunucuya ulaşır: currentPassword / password gövdede', () {
    expect(_oku('lib/data/remote/api/profile_api.dart').contains("'currentPassword'"),
        isTrue);
    expect(_oku('lib/data/remote/api/account_api.dart').contains("'password'"),
        isTrue);
    expect(
        _oku('lib/data/ports/api_ports.dart')
            .contains('mevcutSifre: mevcutSifre'),
        isTrue);
  });

  test('tek panel: şifre isteyen akış ortak paneli kullanır', () {
    for (final f in const [
      'lib/screens/account_settings_screen.dart',
    ]) {
      expect(_oku(f).contains("import '../ui/sifre_dogrulama_paneli.dart';"),
          isTrue,
          reason: f);
    }
  });
}
