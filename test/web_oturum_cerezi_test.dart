// WEB OTURUMU — HttpOnly yenileme çerezi (15 Eki).
//
// Web'de token'lar yalnız bellekte durur (güvenlik turu M-05); sayfa
// yenilenince/sekme yeniden açılınca oturum, sunucunun koyduğu HttpOnly
// çerezle sürdürülür. Tarayıcı çerezi kendisi gönderir; istemci yalnız
// `X-HC-Web: 1` başlığını ekler ve yenilemeyi GÖVDESİZ yapar.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';

import 'support/fake_backend.dart';

ApiAuthPort _port(ApiClient c) =>
    ApiAuthPort(ApiAuthRepository(c, AuthApi(c), ProfileApi(c)));

void main() {
  test('sayfa yenilendi: token yok → çerezle yenileme (gövdesiz) → oturum geri gelir', () async {
    Map<String, dynamic>? yenilemeGovdesi;
    final be = FakeBackend({
      'POST /auth/refresh': (b) {
        yenilemeGovdesi = b;
        return {'accessToken': 'AT2', 'refreshToken': 'RT2'};
      },
      'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
      'GET /profiles/me/address': (_) => null,
    });
    final port = _port(be.client(store: FakeTokenStore(), cerezliOturum: true));
    await port.restoreSession();

    expect(port.loggedIn, isTrue);
    expect(be.calls.first, 'POST /auth/refresh');
    expect(yenilemeGovdesi, isEmpty, reason: 'web token gövdede GÖNDERMEZ');
    expect(be.headers.first['x-hc-web'], '1');
    // Sonraki istekler yeni erişim token'ı ve web başlığıyla gider.
    expect(be.headers[1]['authorization'], 'Bearer AT2');
    expect(be.headers[1]['x-hc-web'], '1');
  });

  test('çerez yok/geçersiz: profil istenmez, oturum açılmaz', () async {
    final be = FakeBackend({
      'POST /auth/refresh': (_) => apiError(401, 'UNAUTHENTICATED', 'Oturum gerekli'),
    });
    final port = _port(be.client(store: FakeTokenStore(), cerezliOturum: true));
    await port.restoreSession();
    expect(port.loggedIn, isFalse);
    expect(be.calls, ['POST /auth/refresh']);
  });

  test('mobil (çerezsiz) davranış AYNEN: token yoksa hiç istek yok, başlık yok', () async {
    final be = FakeBackend({'GET /users/me': (_) => userJson()});
    final port = _port(be.client(store: FakeTokenStore()));
    await port.restoreSession();
    expect(be.calls, isEmpty);
    final dolu = FakeBackend({
      'GET /users/me': (_) => userJson(),
      'GET /profiles/me/address': (_) => null,
    });
    await _port(dolu.client()).restoreSession();
    expect(dolu.headers.first.containsKey('x-hc-web'), isFalse);
  });

  test('web istemcisi kimlik bilgisiyle (withCredentials) kurulur', () {
    final k = File('lib/data/remote/sabitlemeli_istemci_web.dart').readAsStringSync();
    expect(k.contains('BrowserClient()..withCredentials = true'), isTrue);
  });
}
