import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/api_error_mapper.dart';
import 'package:hizmetcep/data/remote/token_store.dart';
import 'package:hizmetcep/domain/failures.dart';

/// Bellek içi token deposu (gerçek Keychain testte kullanılmaz).
class FakeTokenStore implements TokenStore {
  String? access;
  String? refresh;
  FakeTokenStore({this.access, this.refresh});
  @override
  Future<String?> accessToken() async => access;
  @override
  Future<String?> refreshToken() async => refresh;
  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }
  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

void main() {
  test('Authorization başlığı eklenir', () async {
    late http.BaseRequest seen;
    final c = ApiClient(
        // Test: MethodChannel'a gitmeden DAİMA çevrimiçi.
        onlineChecker: () async => true,
      baseUrl: 'https://x/api/v1',
      tokenStore: FakeTokenStore(access: 'AT'),
      httpClient: MockClient.streaming((req, _) async {
        seen = req;
        return http.StreamedResponse(Stream.value(utf8.encode('{"ok":true}')), 200);
      }),
    );
    await c.get('/users/me');
    expect(seen.headers['Authorization'], 'Bearer AT');
  });

  test('finansal POST Idempotency-Key gönderir', () async {
    late http.BaseRequest seen;
    final c = ApiClient(
        // Test: MethodChannel'a gitmeden DAİMA çevrimiçi.
        onlineChecker: () async => true,
      baseUrl: 'https://x/api/v1',
      tokenStore: FakeTokenStore(access: 'AT'),
      httpClient: MockClient.streaming((req, _) async {
        seen = req;
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
      }),
    );
    await c.post('/wallet/topup', body: {'amountTl': 500}, idempotencyKey: 'idem-1');
    expect(seen.headers['Idempotency-Key'], 'idem-1');
  });

  test('401 sonrası refresh yapılır ve istek TEK KEZ tekrarlanır', () async {
    final store = FakeTokenStore(access: 'eski', refresh: 'RT');
    var calls = <String>[];
    final c = ApiClient(
        // Test: MethodChannel'a gitmeden DAİMA çevrimiçi.
        onlineChecker: () async => true,
      baseUrl: 'https://x/api/v1',
      tokenStore: store,
      httpClient: MockClient.streaming((req, _) async {
        calls.add(req.url.path);
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.StreamedResponse(
              Stream.value(utf8.encode('{"accessToken":"yeni","refreshToken":"RT2"}')), 200);
        }
        final auth = req.headers['Authorization'];
        if (auth == 'Bearer eski') {
          return http.StreamedResponse(
              Stream.value(utf8.encode('{"error":{"code":"UNAUTHORIZED","message":"süre doldu"}}')), 401);
        }
        return http.StreamedResponse(Stream.value(utf8.encode('{"id":"u1"}')), 200);
      }),
    );
    final res = await c.get('/users/me');
    expect(res['id'], 'u1');
    expect(store.access, 'yeni');
    expect(store.refresh, 'RT2');           // rotasyon: yeni refresh saklandı
    expect(calls.where((p) => p.endsWith('/auth/refresh')).length, 1);
  });

  test('refresh de geçersizse oturum kapanır', () async {
    final store = FakeTokenStore(access: 'eski', refresh: 'RT');
    var loggedOut = false;
    final c = ApiClient(
        // Test: MethodChannel'a gitmeden DAİMA çevrimiçi.
        onlineChecker: () async => true,
      baseUrl: 'https://x/api/v1',
      tokenStore: store,
      onSessionExpired: () => loggedOut = true,
      httpClient: MockClient.streaming((req, _) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 401);
        }
        return http.StreamedResponse(
            Stream.value(utf8.encode('{"error":{"code":"UNAUTHORIZED","message":"süre doldu"}}')), 401);
      }),
    );
    await expectLater(c.get('/users/me'), throwsA(isA<ApiFailure>()));
    expect(loggedOut, isTrue);
    expect(store.access, isNull);
  });

  test('sunucu hatası DomainError e çevrilir', () async {
    final c = ApiClient(
        // Test: MethodChannel'a gitmeden DAİMA çevrimiçi.
        onlineChecker: () async => true,
      baseUrl: 'https://x/api/v1',
      tokenStore: FakeTokenStore(access: 'AT'),
      httpClient: MockClient.streaming((req, _) async => http.StreamedResponse(
          Stream.value(utf8.encode(
              '{"error":{"code":"INSUFFICIENT_BALANCE","message":"Bakiyeniz yetersiz"}}')),
          402)),
    );
    try {
      await c.post('/offers', body: {}, idempotencyKey: 'k');
      fail('hata bekleniyordu');
    } on ApiFailure catch (e) {
      expect(e.error, isA<InsufficientBalanceError>());
    }
  });
}
