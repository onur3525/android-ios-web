import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/payment.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/controllers/wallet_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/contact_api.dart';
import 'package:hizmetcep/data/remote/api/listing_api.dart';
import 'package:hizmetcep/data/remote/api/offer_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/api/wallet_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/domain/failures.dart';

import 'support/fake_backend.dart';

ApiAuthPort authPort(ApiClient c) =>
    ApiAuthPort(ApiAuthRepository(c, AuthApi(c), ProfileApi(c)));
ApiListingPort listingPort(ApiClient c) => ApiListingPort(ApiListingRepository(ListingApi(c)));
ApiOfferPort offerPort(ApiClient c) => ApiOfferPort(ApiOfferRepository(OfferApi(c)));
ApiWalletPort walletPort(ApiClient c) => ApiWalletPort(ApiWalletRepository(WalletApi(c)));
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
    // ⚠ E-POSTA GİRİŞ UCU SUNUCUDA HENÜZ YOK.
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
      final msg = await ctl.girisEposta('test@hizmetcep.com', '123456');

      // Açık hata döner…
      expect(msg, isNotNull);
      expect(msg!.contains('sunucuda etkin değil'), isTrue);
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
        'GET /wallet/me': (_) => {'availTl': 450, 'blockedTl': 50},
        'GET /wallet/me/ledger': (_) => <dynamic>[],
      });
      final c = be.client();
      final ctl = OfferController(offerPort(c), listingPort(c), walletPort(c));
      final err = await ctl.placeOffer(
          listingId: 'l1', providerId: 'u1', amount: 750,
          note: 'Bugün akşam gelebilirim efendim');

      expect(err, isNull);
      expect(be.headers.any((h) => h.containsKey('Idempotency-Key')), isTrue);
    });

    test('yetersiz bakiyede teklif verilemez ve sahte başarı gösterilmez', () async {
      final be = FakeBackend({
        'POST /offers': (_) => apiError(402, 'INSUFFICIENT_BALANCE',
            'Bakiyeniz yetersiz — teklif vermek için 50 TL bloke edilir'),
      });
      final c = be.client();
      final ctl = OfferController(offerPort(c), listingPort(c), walletPort(c));
      final err = await ctl.placeOffer(
          listingId: 'l1', providerId: 'u1', amount: 750, note: 'Gelebilirim efendim');

      expect(err, isA<InsufficientBalanceError>());
      expect(ctl.offersForListing('l1'), isEmpty);
    });
  });

  group('İletişim', () {
    test('iletişim açma sunucu onayıyla açık işaretlenir', () async {
      final be = FakeBackend({
        'POST /contact/open': (_) => {'open': true, 'offerId': 'o1'},
        'GET /contact/o1': (_) => {'open': true, 'offerId': 'o1'},
        'GET /wallet/me': (_) => {'availTl': 400, 'blockedTl': 0},
        'GET /wallet/me/ledger': (_) => <dynamic>[],
      });
      final c = be.client();
      final ctl = ContactController(contactPort(c), offerPort(c), walletPort(c));
      final err = await ctl.openShared('o1', actorId: 'u1');

      expect(err, isNull);
      expect(ctl.isOpen('o1'), isTrue);
      expect(be.headers.any((h) => h.containsKey('Idempotency-Key')), isTrue);
    });

    test('sunucu reddederse iletişim AÇIK gösterilmez', () async {
      final be = FakeBackend({
        'POST /contact/open': (_) =>
            apiError(402, 'INSUFFICIENT_BALANCE', 'Bakiyeniz yetersiz'),
      });
      final c = be.client();
      final ctl = ContactController(contactPort(c), offerPort(c), walletPort(c));
      final err = await ctl.openShared('o1', actorId: 'u1');

      expect(err, isA<InsufficientBalanceError>());
      expect(ctl.isOpen('o1'), isFalse);
    });
  });

  group('Cüzdan', () {
    test('yükleme sonrası bakiye SUNUCUDAN yeniden okunur', () async {
      var loaded = 0;
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(),
        'GET /profiles/me/address': (_) => null,
        'POST /wallet/topup/session': (_) => {
              'sessionId': 's1', 'providerRef': 'r1',
              'amountTl': 500, 'status': 'PENDING',
            },
        'POST /wallet/topup/confirm': (_) => {'status': 'SUCCEEDED'},
        'GET /wallet/me': (_) {
          loaded++;
          return {'availTl': loaded == 1 ? 0 : 500, 'blockedTl': 0};
        },
        'GET /wallet/me/ledger': (_) => <dynamic>[],
      });
      final c = be.client();
      final auth = authPort(c);
      await auth.restoreSession();               // oturum sahibi yüklenir
      final ctl = WalletController(walletPort(c), auth);

      await ctl.load();
      expect(ctl.myWallet!.avail, 0);

      // ADIM 1 — oturum açılır, bakiye HENÜZ artmaz.
      final (session, err) = await ctl.startTopup(amount: 500);
      expect(err, isNull);
      expect(session!.status, PaymentStatus.pending);

      // ADIM 2 — sunucu doğrulaması sonrası bakiye SUNUCUDAN yeniden okunur.
      final (status, cerr) = await ctl.confirmTopup();
      expect(cerr, isNull);
      expect(status, PaymentStatus.succeeded);
      expect(ctl.myWallet!.avail, 500);          // sunucu cevabından SONRA güncellendi
    });

    test('yükleme reddedilirse bakiye DEĞİŞMEZ', () async {
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(),
        'GET /profiles/me/address': (_) => null,
        'GET /wallet/me': (_) => {'availTl': 0, 'blockedTl': 0},
        'GET /wallet/me/ledger': (_) => <dynamic>[],
        'POST /wallet/topup/session': (_) =>
            apiError(422, 'VALIDATION_ERROR', 'Minimum yükleme tutarı 500 TL dir'),
      });
      final c = be.client();
      final auth = authPort(c);
      await auth.restoreSession();
      final ctl = WalletController(walletPort(c), auth);
      await ctl.load();
      final (session, err) = await ctl.startTopup(amount: 600);   // sunucu reddeder

      expect(session, isNull);
      expect(err, isA<ValidationError>());
      expect(ctl.myWallet!.avail, 0);            // bakiye DEĞİŞMEDİ
    });
    test('backend FAILED derse ödeme BAŞARISIZDIR (redirect ne derse desin)',
        () async {
      final be = FakeBackend({
        'GET /users/me': (_) => userJson(),
        'GET /profiles/me/address': (_) => null,
        'GET /wallet/me': (_) => {'availTl': 0, 'blockedTl': 0},
        'GET /wallet/me/ledger': (_) => <dynamic>[],
        'POST /wallet/topup/session': (_) => {
              'sessionId': 's9', 'providerRef': 'r9',
              'amountTl': 500, 'status': 'PENDING',
            },
        // Sağlayıcı dönüşü "başarılı" gösterse bile sunucu FAILED diyor.
        'POST /wallet/topup/confirm': (_) => {'status': 'FAILED'},
      });
      final c = be.client();
      final auth = authPort(c);
      await auth.restoreSession();
      final ctl = WalletController(walletPort(c), auth);
      await ctl.load();

      await ctl.startTopup(amount: 500);
      final (status, err) = await ctl.confirmTopup();

      expect(err, isNull);
      expect(status, PaymentStatus.failed);
      expect(ctl.myWallet!.avail, 0, reason: 'başarısız ödemede bakiye artmaz');
    });
  });
}
