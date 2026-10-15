// KARŞI TARAF ÖZETİ — API MODU (15 Eki)
//
// Ekranlar karşı tarafın bilgisini `accountById` ile EŞZAMANLI okur.
// API modunda ilk okuma özeti arka planda ister (GET /users/{id}/summary);
// yanıt gelince dinleyiciler uyarılır ve aynı çağrı dolu hesabı döner.
// Telefon/tam ad kararı sunucudadır; istemci gelen değeri gösterir.
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';

import 'support/fake_backend.dart';

ApiAuthPort _port(ApiClient c) =>
    ApiAuthPort(ApiAuthRepository(c, AuthApi(c), ProfileApi(c)));

/// Arka plan isteğinin bitmesini bekler (gerçek ağ yok, sahte istemci).
Future<void> _bekle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

const _karsiId = '11111111-2222-3333-4444-555555555555';

Map<String, dynamic> _ozetJson({String? phone}) => {
      'id': _karsiId,
      'name': 'Gönül Bütün',
      'nameMasked': false,
      'createdAt': '2026-10-01T10:00:00.000Z',
      'address': {'city': 'İzmir', 'district': 'Karşıyaka', 'neighborhood': 'İmbatlı'},
      'photos': {'customer': 'https://depo.ornek/u/m.jpg', 'provider': null},
      'completedJobsAsProvider': 2,
      'completedJobsAsCustomer': 3,
      'phone': phone,
    };

void main() {
  test('mapper: özet → gösterim hesabı (e-posta yok, telefon koşullu)', () {
    final a = Mappers.kisiOzeti(_ozetJson(phone: '5551112233'));
    expect(a.id, _karsiId);
    expect(a.name, 'Gönül Bütün');
    expect(a.email, '');
    expect(a.phone, '5551112233');
    expect(a.address!.neighborhood, 'İmbatlı');
    expect(a.address!.district, 'Karşıyaka');
    expect(a.tamamlananIs, 2);
    expect(a.tamamlananIsHizmetAlan, 3);
    expect(a.kayitTarihi.toUtc().year, 2026);
    expect(a.fotografi(Role.customer), 'https://depo.ornek/u/m.jpg');
    expect(a.fotografi(Role.provider), '');
    expect(Mappers.kisiOzeti(_ozetJson()).phone, '');
  });

  test('ilk okuma boş döner, arka planda ister; yanıt gelince dolar ve dinleyici uyarılır', () async {
    final be = FakeBackend({
      'GET /users/me': (_) => userJson(role: 'PROVIDER'),
      'GET /profiles/me/address': (_) => null,
      'GET /users/$_karsiId/summary': (_) => _ozetJson(phone: '5551112233'),
    });
    final port = _port(be.client());
    await port.restoreSession();
    var uyari = 0;
    port.addListener(() => uyari++);

    expect(port.accountById(_karsiId), isNull);
    // Aynı çizimde ikinci okuma YENİ istek başlatmaz.
    expect(port.accountById(_karsiId), isNull);
    await _bekle();

    expect(be.countOf('GET /users/$_karsiId/summary'), 1);
    expect(uyari, greaterThan(0));
    final a = port.accountById(_karsiId)!;
    expect(a.name, 'Gönül Bütün');
    expect(a.phone, '5551112233');
    // Taze kayıt yeniden istenmez.
    await _bekle();
    expect(be.countOf('GET /users/$_karsiId/summary'), 1);
  });

  test('kendi hesabı ve boş kimlik istek üretmez', () async {
    final be = FakeBackend({
      'GET /users/me': (_) => userJson(id: 'u1'),
      'GET /profiles/me/address': (_) => null,
    });
    final port = _port(be.client());
    await port.restoreSession();
    expect(port.accountById('u1')!.id, 'u1');
    expect(port.accountById(''), isNull);
    await _bekle();
    expect(be.calls.where((c) => c.endsWith('/summary')), isEmpty);
  });

  test('ilişki yok (404): boş kalır ve bekleme süresince yeniden istenmez', () async {
    final be = FakeBackend({
      'GET /users/me': (_) => userJson(),
      'GET /profiles/me/address': (_) => null,
      'GET /users/$_karsiId/summary': (_) => apiError(404, 'NOT_FOUND', 'Kullanıcı bulunamadı'),
    });
    final port = _port(be.client());
    await port.restoreSession();
    expect(port.accountById(_karsiId), isNull);
    await _bekle();
    expect(port.accountById(_karsiId), isNull);
    await _bekle();
    expect(be.countOf('GET /users/$_karsiId/summary'), 1);
  });

  test('oturum yokken istek yapılmaz', () async {
    final be = FakeBackend({});
    final port = _port(be.client(store: FakeTokenStore()));
    await port.restoreSession();
    expect(port.accountById(_karsiId), isNull);
    await _bekle();
    expect(be.calls, isEmpty);
  });
}
