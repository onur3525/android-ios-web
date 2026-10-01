import 'package:flutter_test/flutter_test.dart';
import 'support/test_config.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/contact_api.dart';
import 'package:hizmetcep/data/remote/api/listing_api.dart';
import 'package:hizmetcep/data/remote/api/offer_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/domain/failures.dart';

import 'support/fake_backend.dart';

ApiAuthPort authPort(ApiClient c) =>
    ApiAuthPort(ApiAuthRepository(c, AuthApi(c), ProfileApi(c)));
ApiListingPort listingPort(ApiClient c) => ApiListingPort(ApiListingRepository(ListingApi(c)));
ApiOfferPort offerPort(ApiClient c) => ApiOfferPort(ApiOfferRepository(OfferApi(c)));
ApiContactPort contactPort(ApiClient c) => ApiContactPort(ApiContactRepository(ContactApi(c)));

void main() {
  group('Oturum', () {
    test('saklı token varsa açılışta profil ve aktif rol backend den gelir', () async {
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(role: 'PROVIDER'),
        // TEK ADRES sözleşmesi: tek nesne döner (liste değil).
        'GET /profiles/me/address': (_) => {
              'id': 'a1', 'city': 'İzmir',
              'district': 'Bornova', 'neighborhood': 'Kazımdirik',
            },
      });
      final port = authPort(be.client(store: FakeTokenStore(access: 'AT', refresh: 'RT')));
      await port.restoreSession();

      expect(port.loggedIn, isTrue);
      expect(port.activeRole, Role.provider);
      // TEK adres yüklendi (liste değil).
      final addr = port.currentAccount!.address;
      expect(addr, isNotNull);
      expect(addr!.district, 'Bornova');
      expect(addr.neighborhood, 'Kazımdirik');
    });

    test('token yoksa profil isteği YAPILMAZ', () async {
      final be = FakeBackend({'GET /users/me': (_) => userJson()});
      final port = authPort(be.client(store: FakeTokenStore()));
      await port.restoreSession();

      expect(be.calls, isEmpty);
      expect(port.loggedIn, isFalse);
    });

    test('refresh de geçersizse oturum düşer ve tokenlar temizlenir', () async {
      final store = FakeTokenStore(access: 'eski', refresh: 'RT');
      var kicked = false;
      final be = FakeBackend({
        'GET /users/me': (_) => apiError(401, 'UNAUTHORIZED', 'Oturum süresi doldu'),
        'POST /auth/refresh': (_) => apiError(401, 'UNAUTHORIZED', 'Yenileme geçersiz'),
      });
      final port = authPort(be.client(store: store, onSessionExpired: () => kicked = true));
      await port.restoreSession();

      expect(kicked, isTrue);       // giriş ekranına dönüş tetiklendi
      expect(store.access, isNull); // tokenlar temizlendi
      expect(port.loggedIn, isFalse);
      expect(be.countOf('POST /auth/refresh'), 1); // refresh TEK KEZ denendi
    });
  });

  group('Giriş', () {
    // ⚠ (Güncel) E-posta girişi Firebase Authentication ile yapılır;
    // aşağıdaki testler Firebase'e ULAŞILAMADIĞINDA da sahte başarı
    // üretilmediğini kilitler.
    //
    // Hesap modeli kararıyla şifreli giriş e-postaya geçti; sunucu
    // sözleşmesi (`POST /auth/login/email`) yazıldı ama uç
    // gerçeklenmedi. `ApiAuthPort` bu durumda SAHTE BAŞARI ÜRETMEZ,
    // açık hata döndürür.
    //
    // ⚠ Bu testler ŞU ANKİ doğru davranışı kilitler. Gerçek uç
    // geldiğinde başarı sözleşmesi ayrıca test edilecek ve bu grup
    // o zaman genişletilecek.

    test('API modunda e-posta girişi SAHTE BAŞARI üretmez', () async {
      final store = FakeTokenStore();
      final be = FakeBackend({
        'POST /auth/login': (_) => {'accessToken': 'AT', 'refreshToken': 'RT'},
        'GET /users/me': (_) => userJson(role: 'CUSTOMER'),
        'GET /profiles/me/address': (_) => null,
      });
      final ctl = AuthController(authPort(be.client(store: store)));
      final msg = await ctl.girisEposta(kTestEmail, kTestPass);

      // Açık hata döner… (Firebase Auth eklendi: e-posta girişi Firebase'de
      // doğrulanır; test ortamında Firebase yoktur → hizmete ulaşılamaz.
      // Kilitlenen DEĞİŞMEZ: sahte başarı ve sahte oturum YOK.)
      expect(msg, isNotNull);
      // …ve HİÇBİR oturum/jeton oluşmaz.
      expect(ctl.loggedIn, isFalse);
      expect(store.access, isNull);
      expect(store.refresh, isNull);
    });

    test('telefon OTP giriş uçları da sahte başarı üretmez', () async {
      final store = FakeTokenStore();
      final be = FakeBackend({});
      final ctl = AuthController(authPort(be.client(store: store)));

      final k = await ctl.girisTelefonKodGonder('05321112233');
      expect(k.hata, isNotNull);
      expect(k.challengeId, isNull);

      final d = await ctl.girisTelefonDogrula('uydurma', '123456');
      expect(d, isNotNull);
      expect(ctl.loggedIn, isFalse);
      expect(store.access, isNull);
    });
  });

  group('İlan', () {
    test('ilan oluşturma sonrası listem yeniden yüklenir', () async {
      final be = FakeBackend({
        'POST /listings': (_) => listingJson(id: 'l1', ownerId: 'u1'),
        'GET /listings/my': (_) => <dynamic>[listingJson(id: 'l1', ownerId: 'u1')],
      });
      final ctl = ListingController(listingPort(be.client()));
      final r = await ctl.publish(
          ownerId: 'u1', title: 'Musluk tamiri', location: 'Bornova',
          desc: 'Mutfak musluğu damlatıyor');

      expect(r.error, isNull);
      expect(r.listing!.id, 'l1');
      expect(be.countOf('GET /listings/my'), 1); // işlem sonrası yenileme
    });

    test('sunucu reddederse ilan önbelleğe EKLENMEZ', () async {
      final be = FakeBackend({
        'POST /listings': (_) =>
            apiError(422, 'VALIDATION_ERROR', 'Açıklama en az 5 kelime olmalı'),
      });
      final ctl = ListingController(listingPort(be.client()));
      final r = await ctl.publish(
          ownerId: 'u1', title: 'x', location: 'Bornova', desc: 'kısa');

      expect(r.listing, isNull);
      expect((r.error as ValidationError).message, contains('5 kelime'));
      expect(ctl.all, isEmpty);
    });
  });

  group('Teklif', () {
    test('teklif verilir ve Idempotency-Key gönderilir', () async {
      final be = FakeBackend({
        'POST /offers': (_) => offerJson(),
        'GET /offers/my': (_) => <dynamic>[offerJson()],      // işlem sonrası yenileme
      });
      final c = be.client();
      final ctl = OfferController(offerPort(c), listingPort(c));
      final err = await ctl.placeOffer(
          listingId: 'l1', providerId: 'u1', amount: 750,
          note: 'Bugün akşam gelebilirim efendim');

      expect(err, isNull);
      expect(be.headers.any((h) => h.containsKey('Idempotency-Key')), isTrue);
    });

  });

  group('İletişim', () {
    test('iletişim açma sunucu onayıyla açık işaretlenir', () async {
      final be = FakeBackend({
        'POST /contact/open': (_) => {'open': true, 'offerId': 'o1'},
        'GET /contact/o1': (_) => {'open': true, 'offerId': 'o1'},
      });
      final c = be.client();
      final ctl = ContactController(contactPort(c), offerPort(c));
      final err = await ctl.openShared('o1', actorId: 'u1');

      expect(err, isNull);
      expect(ctl.isOpen('o1'), isTrue);
      expect(be.headers.any((h) => h.containsKey('Idempotency-Key')), isTrue);
    });

    test('sunucu reddederse iletişim AÇIK gösterilmez', () async {
      final be = FakeBackend({
        'POST /contact/open': (_) =>
            apiError(422, 'BUSINESS_RULE', 'İşlem reddedildi'),
      });
      final c = be.client();
      final ctl = ContactController(contactPort(c), offerPort(c));
      final err = await ctl.openShared('o1', actorId: 'u1');

      expect(err, isNotNull);
      expect(ctl.isOpen('o1'), isFalse);
    });
  });

}
