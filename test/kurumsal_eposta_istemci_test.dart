// KURUMSAL DOĞRULAMA E-POSTASI — İSTEMCİ (21 Eki, kullanıcı isteği)
//
// E-posta önce sunucudan HizmetCep tasarımıyla gider. Sunucu gönderdiyse
// (`sent: true`) Firebase'e HİÇ gidilmez; e-posta kanalı yoksa
// (`sent: false`) eski Firebase gönderimi kullanılır.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/domain/failures.dart';

import 'support/fake_backend.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

ApiAuthPort _port(ApiClient c) =>
    ApiAuthPort(ApiAuthRepository(c, AuthApi(c), ProfileApi(c)));

void main() {
  test('mevcut adres: sunucu gönderdiyse başarı, Firebase belgesi İSTENMEZ', () async {
    final be = FakeBackend({
      'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
      'GET /profiles/me/address': (_) => null,
      'POST /profiles/me/email/verification': (_) =>
          {'sent': true, 'email': 'a@ornek.com'},
    });
    final port = _port(be.client());
    await port.restoreSession();
    expect(await port.mevcutEpostaDogrulamaGonder('a@ornek.com'), isNull);
    expect(be.countOf('POST /profiles/me/email/verification'), 1);
    expect(be.countOf('POST /auth/firebase/baglanti'), 0);
  });

  test('yeni adres: gövdede yalnız newEmail gider', () async {
    Map<String, dynamic>? govde;
    final be = FakeBackend({
      'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
      'GET /profiles/me/address': (_) => null,
      'POST /profiles/me/email/change-request': (b) {
        govde = b;
        return {'sent': true, 'email': 'yeni@ornek.com'};
      },
    });
    final port = _port(be.client());
    await port.restoreSession();
    expect(await port.epostaDegisimiBaslat('yeni@ornek.com'), isNull);
    expect(govde, {'newEmail': 'yeni@ornek.com'});
    expect(be.countOf('POST /auth/firebase/baglanti'), 0);
  });

  test('sunucu hatası kullanıcıya döner; Firebase yoluna DÜŞÜLMEZ', () async {
    final be = FakeBackend({
      'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
      'GET /profiles/me/address': (_) => null,
      'POST /profiles/me/email/change-request': (_) =>
          apiError(409, 'CONFLICT', 'Bu e-posta adresi başka bir hesapta kayıtlı'),
    });
    final port = _port(be.client());
    await port.restoreSession();
    final h = await port.epostaDegisimiBaslat('baska@ornek.com');
    expect(h, isA<DomainError>());
    expect(h!.message, 'Bu e-posta adresi başka bir hesapta kayıtlı');
    expect(be.countOf('POST /auth/firebase/baglanti'), 0);
  });

  test('kanal yoksa (sent:false) Firebase gönderimine düşülür', () {
    final p = _kod('lib/data/ports/api_ports.dart');
    expect('await repo.kurumsalEpostaGonder('.allMatches(p).length, 2);
    expect('if (gonderildi) {'.allMatches(p).length, 2);
    expect(p.contains('await FirebaseKimlik.i.epostaDegistir(yeniEposta);'), isTrue);
    expect(p.contains('await FirebaseKimlik.i.mevcutEpostaDogrulamaGonder(mevcutEposta);'), isTrue);
  });
}
