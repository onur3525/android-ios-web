import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WEB — SAĞ ALANDAKİ BÜTÜN SAYFALARDA STANDART BAŞLIK
///
/// Kullanıcı kararı: hizmet alanın kenar çubuğundan açılan her sayfada
/// başlık OLMALI ve hepsi AYNI ölçüde olmalı. Tek kaynak `RefPageTitle`
/// (25 / w700 / ortalı); `RefDetailHeader` aynı ölçüyü kullanır.
///
/// ⚠ MOBİL KİLİTLİ: aşağıdaki başlıklar yalnız `kIsWeb` dalında
/// eklenir; Android/iOS ağaçları değişmez.
void main() {
  String oku(String p) => File(p).readAsStringSync();

  // Ekran → web dalında beklenen standart başlık satırı.
  const webBasliklari = <String, String>{
    'lib/screens/find_provider_screen.dart':
        "const RefPageTitle('Hizmet Veren Bul')",
    'lib/screens/my_listings_screen.dart':
        "RefPageTitle(saglayici ? 'İşlerim' : 'İlanlarım',",
    'lib/screens/notifications_screen.dart':
        "const RefPageTitle('Bildirimler', geriDugmesi: false)",
    'lib/screens/profile_screen.dart':
        "const RefPageTitle('Profil', geriDugmesi: false)",
    'lib/screens/account_settings_screen.dart':
        "const RefPageTitle('Hesap Ayarları')",
    'lib/screens/legal_screen.dart':
        'RefPageTitle(d?.title ?? widget.title)',
  };

  test('web dalında her sayfa başlığı RefPageTitle ile çizer', () {
    webBasliklari.forEach((yol, satir) {
      final k = oku(yol);
      final i = k.indexOf(satir);
      expect(i, greaterThan(0), reason: '$yol: web başlığı yok');
      // Başlık bir `kIsWeb` koşulunun hemen ardında olmalı.
      final once = k.substring(i - 400 < 0 ? 0 : i - 400, i);
      expect(once.contains('kIsWeb'), isTrue,
          reason: '$yol: başlık web koşuluna bağlı değil (mobil etkilenir)');
    });
  });

  test('zaten standart olanlar yerinde', () {
    for (final e in {
      'lib/screens/profile_info_screen.dart': "RefPageTitle('Profil Bilgilerim')",
      'lib/screens/addresses_screen.dart': "RefPageTitle('Adreslerim')",
      'lib/screens/app_rate_screen.dart': "RefPageTitle('Uygulamayı Puanla')",
      'lib/screens/change_password_screen.dart': "RefPageTitle('Şifre Değiştir')",
      'lib/screens/role_switch_screen.dart': "RefDetailHeader(title: 'Rol Değiştir')",
    }.entries) {
      expect(oku(e.key).contains(e.value), isTrue, reason: e.key);
    }
  });

  test('tek ölçü: RefPageTitle ve RefDetailHeader 25 / w700', () {
    final w = oku('lib/ui/ref_widgets.dart');
    for (final sinif in ['class RefPageTitle', 'class RefDetailHeader']) {
      final i = w.indexOf(sinif);
      expect(i, greaterThan(0));
      final govde = w.substring(i, w.indexOf('\n}\n', i));
      expect(govde.contains('size: RF.s25'), isTrue, reason: sinif);
      expect(govde.contains('weight: RF.w700'), isTrue, reason: sinif);
    }
  });

  test('web: hukuki metinde AppBar çizilmez, Bul vitrini çizilmez', () {
    final l = oku('lib/screens/legal_screen.dart');
    expect(l.contains('appBar: kIsWeb\n          ? null'), isTrue);
    final b = oku('lib/screens/find_provider_screen.dart');
    final i = b.indexOf("const RefPageTitle('Hizmet Veren Bul')");
    final e = b.indexOf('else ...[', i);
    final vitrin = b.indexOf("'assets/art/bul_character.png'", i);
    expect(e, greaterThan(i));
    expect(vitrin, greaterThan(e),
        reason: 'vitrin görseli yalnız mobil (else) dalında kalmalı');
  });

  test('Bildirimler: "Tümünü Okundu Yap" TEK tanım', () {
    final k = oku('lib/screens/notifications_screen.dart');
    expect("'Tümünü Okundu Yap'".allMatches(k).length, 1);
    expect(k.contains('final Widget? tumunuOkundu'), isTrue);
  });
}
