// YENİDEN KİMLİK DOĞRULAMA (15 Eki güvenlik denetimi, karar 2): telefon
// değiştirme kod gönderilmeden ÖNCE mevcut şifreyi sorar ve şifre sunucuya
// iletilir (sunucu yeniden doğrular). Hesap silme aynı paneli kullanır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  test('telefon değişikliği: şifre paneli kod gönderiminden önce', () {
    final p = _oku('lib/screens/profile_info_screen.dart');
    final iSifre = p.indexOf('await sifreIleDogrula(context,');
    final iKod = p.indexOf('.telefonDegisimiKodGonder(newPhone);');
    expect(iSifre, greaterThan(0));
    expect(iSifre, lessThan(iKod), reason: 'şifre kod gönderiminden önce sorulur');
    expect(p.contains('if (sifre == null || !mounted) {'), isTrue,
        reason: 'vazgeçilirse kod gönderilmez');
    expect(p.contains('mevcutSifre: sifre'), isTrue);
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

  test('tek panel: iki akış aynı işlevi kullanır', () {
    for (final f in const [
      'lib/screens/profile_info_screen.dart',
      'lib/screens/account_settings_screen.dart',
    ]) {
      expect(_oku(f).contains("import '../ui/sifre_dogrulama_paneli.dart';"),
          isTrue,
          reason: f);
    }
  });
}
