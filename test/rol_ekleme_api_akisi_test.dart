// ROL EKLEME — API MODU İSTEMCİ AKIŞI
//
// ⚠ 21 Eki (kullanıcı kararı): telefon ve SMS kodu İSTENMEZ.
// ⚠ 5 Kas (kullanıcı kararı): kimlik doğrulaması da (şifre / Google-Apple
// yeniden girişi) İSTENMEZ. Sunucu sözleşmesi
// (backend/test/rol_ekleme.test.js): POST /auth/roles/add { role }.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';

import 'support/fake_backend.dart';
import 'support/test_config.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

ApiAuthPort _port(ApiClient c) =>
    ApiAuthPort(ApiAuthRepository(c, AuthApi(c), ProfileApi(c)));

void main() {
  group('API portu', () {
    test('doğrulama istemez; şifresiz istek sunucuya gider ve rol eklenir', () async {
      var rol = 'CUSTOMER';
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(role: rol),
        'GET /profiles/me/address': (_) => null,
        'POST /auth/roles/add': (_) {
          rol = 'PROVIDER';
          return null;
        },
      });
      final port = _port(be.client());
      await port.restoreSession();
      expect(port.rolEklemeDogrulamaIster, isFalse);

      expect(await port.addRole(Role.provider), isNull);
      expect(be.countOf('POST /auth/roles/add'), 1);
    });

    test('yalnız rol sunucuya gider (şifre gönderilmez); ardından hizmet veren profili yazılır',
        () async {
      Map<String, dynamic>? gonderilen;
      Map<String, dynamic>? profil;
      var rol = 'CUSTOMER';
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(role: rol),
        'GET /profiles/me/address': (_) => null,
        'POST /auth/roles/add': (b) {
          gonderilen = b;
          rol = 'PROVIDER';
          return null;
        },
        'PUT /profiles/me/provider': (b) {
          profil = b;
          return {'categories': b['categories'], 'districts': b['districts']};
        },
      });
      final port = _port(be.client());
      await port.restoreSession();

      final hata = await port.addRole(Role.provider,
          categories: {'Tesisat'},
          serviceDistricts: {'Bornova'},
          sifre: kTestPass);
      expect(hata, isNull);
      expect(gonderilen, {'role': 'PROVIDER'});
      expect(gonderilen!.containsKey('otpCode'), isFalse);
      expect(profil, {
        'categories': ['Tesisat'],
        'districts': ['Bornova'],
      });
      // Profil yazımı rol eklendikten SONRA.
      expect(be.calls.indexOf('POST /auth/roles/add'),
          lessThan(be.calls.indexOf('PUT /profiles/me/provider')));
    });

    test('sunucu reddederse hata döner ve profil YAZILMAZ', () async {
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
        'GET /profiles/me/address': (_) => null,
        'POST /auth/roles/add': (_) => apiError(400, 'WRONG_PASSWORD', 'Şifre hatalı'),
      });
      final port = _port(be.client());
      await port.restoreSession();
      final hata = await port.addRole(Role.provider,
          categories: {'Tesisat'},
          serviceDistricts: {'Bornova'},
          sifre: kTestPass);
      expect(hata, isNotNull);
      expect(be.countOf('PUT /profiles/me/provider'), 0);
    });
  });

  group('Mock port (değişmedi)', () {
    test('doğrulama istemez; rol doğrudan eklenir', () async {
      final port = MockAuthPort(AuthRepository());
      expect(port.rolEklemeDogrulamaIster, isFalse);
      expect(await port.girisEposta(kTestEmail, kTestPass), isNull);
      expect(
          await port.addRole(Role.provider,
              categories: {'Tesisat'}, serviceDistricts: {'Bornova'}),
          isNull);
      expect(port.currentAccount!.roles, contains(Role.provider));
    });
  });

  group('Rol Değiştir ekranı', () {
    final r = _kod('lib/screens/role_switch_screen.dart');

    test('kimlik doğrulama adımı YOK (şifre, Google/Apple, telefon/SMS)', () {
      expect(r.contains('final ekleErr = await auth.addRole(hedef);'), isTrue);
      expect(r.contains('_sifreAl('), isFalse);
      expect(r.contains('verifyPassword('), isFalse);
      expect(r.contains('sosyalIleDogrula('), isFalse);
      expect(r.contains('rolEklemeKodGonder'), isFalse);
      expect(r.contains('OtpScreen('), isFalse);
      expect(r.contains('kayıtlı telefonunuza doğrulama kodu'), isFalse);
    });

    test('ekranda sabit kod ya da test ipucu yok', () {
      expect(r.contains('123456'), isFalse);
      expect(r.contains('test kodu'), isFalse);
    });
  });

  test('istemci roles/add gövdesinde yalnız rolü gönderir', () {
    final a = _kod('lib/data/remote/api/auth_api.dart');
    expect(a.contains("c.post('/auth/roles/add', body: {'role': role});"),
        isTrue);
    expect(a.contains("c.post('/auth/roles/add', body: {'role': role, 'password'"),
        isFalse);
  });
}
