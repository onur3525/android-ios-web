import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/repositories/oturum_tercihi.dart';

/// BENİ HATIRLA — cihaz oturum tercihi.
///
/// ⚠ İŞ KURALI: kutucuğu işaretleyen kullanıcı, uygulamayı bir daha
/// açtığında hiçbir bilgi girmeden ve hiçbir düğmeye basmadan kendi
/// rol paneline gider. Profilden ÇIKIŞ yapana kadar sürer.
String _oku(String p) => File(p).readAsStringSync();

/// Bellek içi sahte depo — gerçek Keychain/EncryptedSharedPreferences
/// test ortamında yoktur.
class _SahteDepo extends FlutterSecureStorage {
  // ⚠ `const` OLAMAZ: alan sabit olmayan bir değerle ilklenir.
  // Üst sınıfın `const` kurucusu var ama bu alt sınıfın durumu vardır.
  final Map<String, String> kutu;

  _SahteDepo() : kutu = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      kutu.remove(key);
    } else {
      kutu[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      kutu[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    kutu.remove(key);
  }
}

void main() {
  group('OturumTercihi', () {
    test('varsayılan: cihaz HATIRLAMAZ', () async {
      final t = OturumTercihi(_SahteDepo());
      expect(await t.hatirlaniyor, isFalse);
      expect(await t.telefon, isNull);
    });

    test('kaydet → hatırlanır ve telefon döner', () async {
      final t = OturumTercihi(_SahteDepo());
      await t.kaydet('05321112233');
      expect(await t.hatirlaniyor, isTrue);
      expect(await t.telefon, '05321112233');
    });

    test('ÇIKIŞ TEMİZLER — bir daha otomatik giriş yok', () async {
      // ⚠ Çıkış düğmesi hiçbir işe yaramazsa kullanıcı hesabından
      // çıkamaz; bu güvenlik sorunudur (ortak cihaz).
      final t = OturumTercihi(_SahteDepo());
      await t.kaydet('05321112233');
      await t.temizle();
      expect(await t.hatirlaniyor, isFalse);
      expect(await t.telefon, isNull);
    });

    test('yeniden kaydet ÜZERİNE YAZAR', () async {
      final t = OturumTercihi(_SahteDepo());
      await t.kaydet('05321112233');
      await t.kaydet('05507654321');
      expect(await t.telefon, '05507654321');
    });
  });

  group('Kaynak sözleşmesi', () {
    test('LOGIN kutucuğu VAR ve tercihi kaydeder', () {
      final k = _oku('lib/screens/login_screen.dart');
      expect(k.contains("'Beni Hatırla'"), isTrue);
      expect(k.contains('_beniHatirla'), isTrue);
      expect(k.contains('OturumTercihi().kaydet'), isTrue);
      // Kutucuk kapalıysa ÖNCEKİ tercih silinmeli.
      expect(k.contains('OturumTercihi().temizle()'), isTrue);
    });

    test('ÇIKIŞ noktalarının HEPSİ temizler', () {
      // ⚠ İki ayrı çıkış yolu var: Profil ve Hesap Ayarları.
      // Biri unutulursa kullanıcı o yoldan çıkınca cihaz hâlâ
      // hatırlar ve bir sonraki açılışta otomatik girer.
      for (final f in [
        'lib/screens/profile_screen.dart',
        'lib/screens/account_settings_screen.dart',
      ]) {
        expect(_oku(f).contains('OturumTercihi().temizle()'), isTrue,
            reason: '$f çıkışta tercihi temizlemiyor');
      }
    });

    test('AÇILIŞ hatırlanan kullanıcıyı ROL PANELİNE yönlendirir', () {
      final k = _oku('lib/screens/splash_screen.dart');
      expect(k.contains('_hatirlananHedef'), isTrue);
      expect(k.contains("'/provider/jobs'"), isTrue);
      expect(k.contains("'/customer/listings'"), isTrue);
    });

    test('ÇİFT ROLDE HİZMET VEREN önceliklidir', () {
      // ⚠ İŞ KURALI: iki rolü olan kullanıcı hizmet veren panelinde
      // açılır — gelen ilanlar 30 saatte kapanır, teklif yarışı var.
      final k = _oku('lib/screens/splash_screen.dart');
      expect(
          k.contains(
              "roles.contains(Role.provider)\n        ? '/provider/jobs'"),
          isTrue,
          reason: 'çift rolde sağlayıcı önceliği kaybolmuş');
    });

    test('OTURUM YOKSA yönlendirme YAPILMAZ', () {
      // Tercih diskte kalıcıdır ama oturum kalıcı değildir; kontrol
      // olmazsa kullanıcı BOŞ panele düşerdi.
      final k = _oku('lib/screens/splash_screen.dart');
      expect(k.contains('if (acc == null) {'), isTrue);
    });

    test('ŞİFRE SAKLANMAZ', () {
      // ⚠ Yalnız telefon ve bayrak tutulur.
      final k = _oku('lib/data/repositories/oturum_tercihi.dart');
      expect(k.contains('pass'), isFalse, reason: 'şifre alanı olmamalı');
      expect(k.contains('encryptedSharedPreferences: true'), isTrue,
          reason: 'düz SharedPreferences kullanılmamalı');
    });
  });
}
