// Masaüstü web düzeni (15 Eki, kullanıcı bulgusu): "Masaüstü sitesi"ne
// geçince Profil menüsü kenar çubuğuyla İKİ KEZ görünüyordu; çubuktaki
// kart fotoğrafsız ve telefon ham ("5555631993") yazılıydı; yenilemede rol
// hizmet verene zorlanıyordu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/telefon_bicimi.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  group('telefon gösterimi tek kaynak', () {
    test('ham numara 0 ile ve gruplu gösterilir', () {
      expect(telefonGoster('5555631993'), '0555 563 19 93');
      expect(telefonGoster('05555631993'), '0555 563 19 93');
      expect(telefonGoster(''), 'Telefon eklenmedi');
      expect(telefonGoster(null), 'Telefon eklenmedi');
    });

    test('Profil ve kenar çubuğu aynı işlevi kullanır; kopya yok', () {
      expect(_oku('lib/screens/profile_screen.dart').contains('_telefonGoster'),
          isFalse);
      final cubuk = _oku('lib/ui/web_kenar_cubugu.dart');
      expect(cubuk.contains('metin: telefonGoster(acc.phone)'), isTrue);
      expect(cubuk.contains('fotoYolu: acc.photoPath'), isTrue,
          reason: 'kenar çubuğu kartı profil fotoğrafını göstermeli');
    });
  });

  test('masaüstü düzeninde /profile menüsüz Profil Bilgilerim açar', () {
    final m = _oku('lib/main.dart');
    expect(m.contains('''masaustuNav(c)
                  ? const ProfileInfoScreen()
                  : const ProfileScreen()'''), isTrue);
  });

  test('yenilemede rol korunur; yeni açılışta hizmet veren önceliği sürer', () {
    final m = _oku('lib/main.dart');
    expect(m.contains('final yenileme = sekmeOku(kSekmeRota) != null'), isTrue);
    expect(m.contains('? acc.activeRole'), isTrue);
    expect(m.contains('acc.roles.contains(Role.provider)'), isTrue);
  });
}
