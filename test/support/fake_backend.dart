import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/token_store.dart';

/// Bellek içi token deposu — testte gerçek Keychain kullanılmaz.
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

/// Yol → cevap eşlemesiyle sahte backend. Çağrı sayısı tutulur, böylece
/// "işlem sonrası liste yeniden yüklendi mi" doğrulanabilir.
class FakeBackend {
  /// Yol → cevap üreteci.
  ///
  /// Handler `null` döndürebilir: bazı uçlar "kayıt yok" durumunda
  /// gövdesiz 200 döner (örn. `GET /profiles/me/address` adres
  /// tanımlanmamışken). Bu yüzden dönüş tipi `Object?`.
  final Map<String, Object? Function(Map<String, dynamic> body)> routes;
  final List<String> calls = [];
  final List<Map<String, String>> headers = [];
  FakeBackend(this.routes);

  ApiClient client({FakeTokenStore? store, void Function()? onSessionExpired}) => ApiClient(
        // Test: MethodChannel'a gitmeden DAİMA çevrimiçi.
        onlineChecker: () async => true,
        baseUrl: 'https://test.local/api/v1',
        tokenStore: store ?? FakeTokenStore(access: 'AT', refresh: 'RT'),
        onSessionExpired: onSessionExpired,
        httpClient: MockClient.streaming((req, bodyStream) async {
          final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
          calls.add(key);
          headers.add(req.headers);
          final raw = await bodyStream.bytesToString();
          final parsed = raw.isEmpty
              ? <String, dynamic>{}
              : (jsonDecode(raw) as Map<String, dynamic>);
          final handler = routes[key];
          if (handler == null) {
            return http.StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({
                  'error': {'code': 'NOT_FOUND', 'message': 'Kayıt bulunamadı'}
                }))),
                404);
          }
          final out = handler(parsed);
          if (out is _Err) {
            return http.StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({
                  'error': {'code': out.code, 'message': out.message}
                }))),
                out.status);
          }
          // `null` → gövdesiz 200. Sunucu "kayıt yok" derken JSON null
          // döndürür; istemci bunu boş değer olarak yorumlar.
          return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(out))), 200);
        }),
      );

  int countOf(String key) => calls.where((c) => c == key).length;
}

class _Err {
  final int status;
  final String code;
  final String message;
  const _Err(this.status, this.code, this.message);
}

Object apiError(int status, String code, String message) => _Err(status, code, message);

/// Testlerde kullanılan örnek sunucu cevapları.
Map<String, dynamic> userJson({String id = 'u1', String role = 'PROVIDER'}) => {
      'id': id, 'name': 'Test Kullanıcı', 'email': 'test@hizmetcep.local',
      'phone': '5321112233', 'roles': [role], 'activeRole': role,
    };

Map<String, dynamic> listingJson({
  String id = 'l1', String ownerId = 'u9', String status = 'OPEN',
}) =>
    {
      'id': id, 'ownerId': ownerId, 'title': 'Musluk tamiri',
      'location': 'Bornova', 'description': 'Mutfak musluğu damlatıyor',
      'status': status, 'photoPaths': <String>[],
      'createdAt': '2026-01-01T10:00:00.000Z', 'expiresAt': '2026-01-02T18:00:00.000Z',
    };

Map<String, dynamic> offerJson({
  String id = 'o1', String listingId = 'l1', String providerId = 'u1',
  String status = 'ACTIVE', bool escrowConsumed = false,
}) =>
    {
      'id': id, 'listingId': listingId, 'providerId': providerId,
      'amountTl': 750, 'note': 'Bugün akşam gelebilirim efendim',
      'status': status, 'escrowBlocked': true, 'escrowConsumed': escrowConsumed,
      'createdAt': '2026-01-01T11:00:00.000Z',
    };
