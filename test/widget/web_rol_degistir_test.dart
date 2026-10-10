import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/domain/profil_menusu.dart';

/// WEB — ROL DEĞİŞTİR SAĞ ALANDA, ANDROID'İN AYNI EKRANI
///
/// Web kenar çubuğundaki "Rol Değiştir" eskiden `/role` panelini
/// (kayıt akışının rol SEÇİM ekranı) ortada saydam panel olarak
/// açıyordu. Artık Android'in açtığı `RoleSwitchScreen`in KENDİSİ,
/// diğer menü sayfaları gibi düz sayfa rotasıyla sağ alanda açılır.
///
/// ⚠ MOBİL KİLİTLİ: Android profil ekranı `RoleSwitchScreen`'i
/// bugünkü gibi doğrudan açar; yeni rota yalnız `kIsWeb` iken eşleşir.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  test('kenar çubuğu menüsünde Rol Değiştir ROTA ile açılır', () {
    final t = oku('lib/domain/profil_menusu.dart');
    expect("rota: '/profile/role'".allMatches(t).length, 2,
        reason: 'iki rolde de (hizmet alan + hizmet veren) aynı rota');
    expect(t.contains('eylem: ProfilEylemi.rolDegistir'), isFalse,
        reason: 'eski /role paneline giden eylem geri gelmiş');
  });

  test('menü öğesi eylemsiz ve rotalı (çubukta seçili görünebilir)', () {
    for (final rol in [Role.customer, Role.provider]) {
      final oge = profilMenusu(rol)
          .expand((b) => b.ogeler)
          .firstWhere((o) => o.baslik == 'Rol Değiştir');
      expect(oge.rota, '/profile/role');
      expect(oge.eylem, isNull);
    }
  });

  test('rota YALNIZ web\'de eşleşir ve RoleSwitchScreen açar', () {
    final m = oku('lib/main.dart');
    final i = m.indexOf("if (kIsWeb && ad == '/profile/role') {");
    expect(i, greaterThan(0), reason: 'web koşullu rota bulunamadı');
    final son = m.indexOf('\n          }', i);
    final govde = m.substring(i, son);
    expect(govde.contains('const RoleSwitchScreen()'), isTrue);
    expect(govde.contains('MaterialPageRoute'), isTrue,
        reason: 'panel değil düz sayfa rotası olmalı');
    expect(govde.contains('panelRotasi'), isFalse);
  });

  test('Android profil ekranı AYNEN: RoleSwitchScreen doğrudan açılır', () {
    final p = oku('lib/screens/profile_screen.dart');
    expect(p.contains('MaterialPageRoute<void>(builder: (_) => const RoleSwitchScreen())'),
        isTrue);
    expect(p.contains('/profile/role'), isFalse);
  });

  test('kabuk: form genişliği ve sekme başlığı tanımlı', () {
    final k = oku('lib/ui/global_web_kabugu.dart');
    expect(k.contains("'/profile/role'"), isTrue);
    expect(k.contains("'/profile/role': 'Rol Değiştir'"), isTrue);
  });
}
