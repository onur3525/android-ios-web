// ROL EKLEME — API MODU İSTEMCİ AKIŞI (15 Eki)
//
// Sunucu sözleşmesi (backend/test/rol_ekleme.test.js): POST
// /auth/roles/add { role, password, firebaseIdToken }. Kanıt yeni bir
// telefon doğrulamasıdır; şifre yanlışsa SMS harcanmaz diye istemci
// önce şifreyi doğrular.
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
import 'package:hizmetcep/domain/failures.dart';

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
    test('doğrulama ister; kanıtsız istek SUNUCUYA HİÇ GİTMEZ', () async {
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
        'GET /profiles/me/address': (_) => null,
      });
      final port = _port(be.client());
      await port.restoreSession();
      expect(port.rolEklemeDogrulamaIster, isTrue);

      expect(await port.addRole(Role.provider), isA<ValidationError>());
      expect(await port.addRole(Role.provider, sifre: kTestPass),
          isA<ValidationError>());
      expect(await port.addRole(Role.provider, telefonKaniti: 'kanit'),
          isA<ValidationError>());
      expect(be.countOf('POST /auth/roles/add'), 0);
    });

    test('şifre + kanıt sunucuya gider; ardından hizmet veren profili yazılır',
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
          sifre: kTestPass,
          telefonKaniti: 'firebase-id-token');
      expect(hata, isNull);
      expect(gonderilen, {
        'role': 'PROVIDER',
        'password': kTestPass,
        'firebaseIdToken': 'firebase-id-token',
      });
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
        'POST /auth/roles/add': (_) => apiError(400, 'PHONE_PROOF_INVALID',
            'Telefon doğrulaması geçersiz ya da süresi dolmuş. Yeni kod isteyin.'),
      });
      final port = _port(be.client());
      await port.restoreSession();
      final hata = await port.addRole(Role.provider,
          categories: {'Tesisat'},
          serviceDistricts: {'Bornova'},
          sifre: kTestPass,
          telefonKaniti: 'eski');
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

    test('API modunda şifre ÖNCE, SMS SONRA; kanıt addRole\'a gider', () {
      expect(r.contains('if (auth.rolEklemeDogrulamaIster) {'), isTrue);
      final iSifre = r.indexOf('final sifre = await _sifreAl(auth);');
      final iKod = r.indexOf('await auth.rolEklemeKodGonder();', iSifre);
      expect(iSifre, greaterThan(0));
      expect(iKod, greaterThan(iSifre),
          reason: 'şifre doğrulanmadan SMS gönderiliyor');
      expect(r.contains('.verifyPassword(ctl.text)'), isTrue);
      expect(r.contains('purpose: OtpPurpose.rolEkleme'), isTrue);
      expect(r.contains('telefonKaniti: kanit,'), isTrue);
    });

    test('ekranda sabit kod ya da test ipucu yok', () {
      expect(r.contains('123456'), isFalse);
      expect(r.contains('test kodu'), isFalse);
    });
  });

  test('istemci roles/add gövdesinde otpCode GÖNDERMEZ', () {
    final a = _kod('lib/data/remote/api/auth_api.dart');
    expect(
        a.contains(
            "c.post('/auth/roles/add', body: {'role': role, 'password': password, 'firebaseIdToken': firebaseIdToken});"),
        isTrue);
  });
}
