// DEĞİŞMEDİYSE YENİDEN İNDİRME YOK (28 Eki, telefon performansı): istemci
// son GET yanıtının özetini (ETag) gönderir; sunucu 304 derse saklı gövde
// kullanılır. Oturum kapanınca saklananlar silinir.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/token_store.dart';

class _Jeton implements TokenStore {
  String? access = 'AT';
  @override
  Future<String?> accessToken() async => access;
  @override
  Future<String?> refreshToken() async => null;
  @override
  Future<void> save({required String access, required String refresh}) async => this.access = access;
  @override
  Future<void> clear() async => access = null;
}

void main() {
  late List<http.BaseRequest> giden;
  late List<http.StreamedResponse Function(http.BaseRequest)> yanitlar;

  ApiClient istemci() => ApiClient(
        onlineChecker: () async => true,
        baseUrl: 'https://x/api/v1',
        tokenStore: _Jeton(),
        httpClient: MockClient.streaming((req, _) async {
          giden.add(req);
          return yanitlar.removeAt(0)(req);
        }),
      );

  http.StreamedResponse tamam(String govde, {String? etiket}) => http.StreamedResponse(
      Stream.value(utf8.encode(govde)), 200,
      headers: {if (etiket != null) 'etag': etiket});
  http.StreamedResponse degismedi() => http.StreamedResponse(const Stream.empty(), 304);

  setUp(() {
    giden = [];
    yanitlar = [];
  });

  test('ilk istekte özet yok; sonraki istekte saklı özet gönderilir, 304 saklı veriyi döner', () async {
    final c = istemci();
    yanitlar
      ..add((_) => tamam('[{"id":"l1"}]', etiket: 'W/"a1"'))
      ..add((_) => degismedi());
    expect(await c.getList('/listings/my'), [{'id': 'l1'}]);
    expect(giden[0].headers.containsKey('If-None-Match'), isFalse);
    expect(await c.getList('/listings/my'), [{'id': 'l1'}]);
    expect(giden[1].headers['If-None-Match'], 'W/"a1"');
  });

  test('veri değişince yeni özet saklanır', () async {
    final c = istemci();
    yanitlar
      ..add((_) => tamam('{"n":1}', etiket: 'W/"a1"'))
      ..add((_) => tamam('{"n":2}', etiket: 'W/"a2"'))
      ..add((_) => degismedi());
    expect((await c.get('/x'))['n'], 1);
    expect((await c.get('/x'))['n'], 2);
    expect((await c.get('/x'))['n'], 2);
    expect(giden[2].headers['If-None-Match'], 'W/"a2"');
  });

  test('adres (sorgu dahil) ayrı tutulur; özetsiz yanıt saklanmaz; POST etkilenmez', () async {
    final c = istemci();
    yanitlar
      ..add((_) => tamam('[]', etiket: 'W/"k1"'))
      ..add((_) => tamam('[1]'))
      ..add((_) => tamam('[2]'))
      ..add((_) => tamam('{}'));
    await c.getList('/listings/available', query: {'category': 'Boya'});
    await c.getList('/listings/available');
    await c.getList('/listings/available');
    await c.post('/listings/available');
    expect(giden[1].headers.containsKey('If-None-Match'), isFalse, reason: 'farklı sorgu');
    expect(giden[2].headers.containsKey('If-None-Match'), isFalse, reason: 'özetsiz yanıt saklanmaz');
    expect(giden[3].headers.containsKey('If-None-Match'), isFalse, reason: 'yalnız GET');
  });

  test('oturum kapanınca saklananlar silinir', () async {
    final c = istemci();
    yanitlar
      ..add((_) => tamam('{"n":1}', etiket: 'W/"a1"'))
      ..add((_) => tamam('{"n":1}', etiket: 'W/"a1"'));
    await c.get('/x');
    await c.clearSession();
    await c.get('/x');
    expect(giden[1].headers.containsKey('If-None-Match'), isFalse);
  });

  test('saklanan adres sayısı sınırlıdır (en eskisi düşer)', () async {
    final c = istemci();
    for (var i = 0; i <= ApiClient.okumaOnbellegiSiniri; i++) {
      yanitlar.add((_) => tamam('{}', etiket: 'W/"e$i"'));
      await c.get('/x$i');
    }
    yanitlar
      ..add((_) => tamam('{}'))
      ..add((_) => degismedi());
    await c.get('/x0');
    await c.get('/x${ApiClient.okumaOnbellegiSiniri}');
    final son = giden.length;
    expect(giden[son - 2].headers.containsKey('If-None-Match'), isFalse, reason: 'en eski düşmeli');
    expect(giden[son - 1].headers['If-None-Match'], 'W/"e${ApiClient.okumaOnbellegiSiniri}"');
  });
}
