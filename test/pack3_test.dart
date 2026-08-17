import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/models/payment.dart';

import 'support/mock_wiring.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/controllers/wallet_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/models/chat.dart';
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/repositories/listing_repository.dart';
import 'package:hizmetcep/data/repositories/notification_repository.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';
import 'package:hizmetcep/data/services/listing_expiry_service.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'support/test_config.dart';

void main() {
  late ListingRepository listings;
  late NotificationRepository notifs;
  late OfferController offerCtl;
  late ContactController contactCtl;
  late ListingController listingCtl;
  const p1 = 'usta-1', cust = 'musteri-1', stranger = 'yabanci-9';

  late MockWiring w0;
  setUp(() {
    w0 = MockWiring();
    listings = w0.listings;
    notifs = w0.notifs;
    offerCtl = w0.offerCtl;
    contactCtl = w0.contactCtl;
    listingCtl = w0.listingCtl;
  });

  ChatController chatCtl() => w0.chatCtl;

  Future<({String listingId, String offerId})> teklifliIlan() async {
    // publish → ({Listing? listing, DomainError? error})
    // `.listing!` bir kez alındığında nesne zaten Listing'dir.
    final l = (await listingCtl.publish(
        ownerId: cust, title: 'Kombi Bakımı', location: 'Konak, İzmir',
        desc: 'Kombi bakımı yapılacak beş kelime tamam')).listing!;
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900,
        note: 'Aynı gün bakımı titizlikle yaparım söz.');
    return (listingId: l.id, offerId: offerCtl.myOfferFor(l.id, p1)!.id);
  }

  group('Sohbet erişim kuralları', () {
    test('İLETİŞİM AÇILMADAN mesajlaşma kapalıdır (send + openThread)', () async {
      final t = await teklifliIlan();
      final ctl = chatCtl();
      expect((await ctl.sendDelivered(t.offerId, senderId: cust, text: 'selam')).error,
          isA<InvalidStateError>());
      expect((await ctl.openThread(t.offerId, actorId: p1)).error,
          isA<InvalidStateError>());
      await contactCtl.openShared(t.offerId, actorId: cust);
      expect((await ctl.sendDelivered(t.offerId, senderId: cust, text: 'selam')).error, isNull);
      expect((await ctl.openThread(t.offerId, actorId: p1)).error, isNull);
    });

    test('yalnız taraflar erişebilir; yabancı offerId+taraf doğrulamasına takılır', () async {
      final t = await teklifliIlan();
      await contactCtl.openShared(t.offerId, actorId: p1);
      final ctl = chatCtl();
      expect((await ctl.sendDelivered(t.offerId, senderId: stranger, text: 'x')).error,
          isA<UnauthorizedError>());
      expect((await ctl.openThread(t.offerId, actorId: stranger)).error,
          isA<UnauthorizedError>());
      expect((await ctl.sendDelivered('olmayan-teklif', senderId: cust, text: 'x')).error,
          isA<NotFoundError>());
    });

    test('konuşma listesinde YALNIZ iletişimi açık teklifler yer alır', () async {
      final t1 = await teklifliIlan();
      final t2 = await teklifliIlan(); // iletişim açılmadı
      await contactCtl.openShared(t1.offerId, actorId: cust);
      final ctl = chatCtl();
      expect(ctl.conversationsFor(cust).map((o) => o.id), [t1.offerId]);
      expect(ctl.conversationsFor(p1).map((o) => o.id), [t1.offerId]);
      expect(ctl.conversationsFor(p1).map((o) => o.id),
          isNot(contains(t2.offerId)));
    });
  });

  group('Mesaj durumları', () {
    test('sendDelivered: gönderim sonucu kesinleşince sent olur; retry yalnız failed için çalışır',
        () async {
      final t = await teklifliIlan();
      await contactCtl.openShared(t.offerId, actorId: cust);
      final ctl = chatCtl();
      final r = await ctl.sendDelivered(t.offerId,
          senderId: cust, text: 'Yarın uygun musunuz?');
      expect(r.error, isNull);
      expect(r.message!.status, MessageStatus.sent);
      // Gönderilmiş mesaj tekrar gönderilmez (yalnız 'gönderilemedi' tekrarlanır).
      expect(await ctl.retry(t.offerId, r.message!), isFalse);
    });

    test('karşı taraf sohbeti açınca mesajlar OKUNDU olur', () async {
      final t = await teklifliIlan();
      await contactCtl.openShared(t.offerId, actorId: cust);
      final ctl = chatCtl();
      final r =
          await ctl.sendDelivered(t.offerId, senderId: cust, text: 'Merhaba');
      expect(r.message!.status, MessageStatus.sent);
      await ctl.openThread(t.offerId, actorId: p1); // usta sohbeti açtı
      expect(r.message!.status, MessageStatus.read);
    });
  });

  group('Bildirimler', () {
    test('teklif → ilan sahibine; seçim → seçilen ustaya; iade → kaybedene', () async {
      final l = (await listingCtl.publish(
          ownerId: cust, title: 'Boya', location: 'Konak, İzmir',
          desc: 'Boya işi var evet beş kelime')).listing!;
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 1, note: 'a');
      await offerCtl.placeOffer(
          listingId: l.id, providerId: 'usta-2', amount: 2, note: 'b');
      expect(notifs.forUser(cust).map((n) => n.type),
          containsAll([NotifType.newOffer]));
      final o2 = offerCtl.myOfferFor(l.id, 'usta-2')!;
      await offerCtl.selectOffer(listingId: l.id, offerId: o2.id, actorId: cust);
      expect(notifs.forUser('usta-2').map((n) => n.type),
          contains(NotifType.offerSelected));
      expect(notifs.forUser(p1).map((n) => n.type), contains(NotifType.refund));
    });

    test('iletişim açılınca KARŞI tarafa; süre dolunca ilan sahibine', () async {
      final t = await teklifliIlan();
      await contactCtl.openShared(t.offerId, actorId: p1); // usta açtı
      expect(notifs.forUser(cust).map((n) => n.type),
          contains(NotifType.contactOpened));
      expect(
          notifs.forUser(p1).where((n) => n.type == NotifType.contactOpened),
          isEmpty); // açan tarafa gitmez

      // ListingExpiryService bir PORT bekler (MockOfferPort), controller değil.
      final expiry = ListingExpiryService(listings, w0.offerPort,
          notifications: notifs);
      final l2 = listings.create(
          ownerId: cust, title: 'Klima', location: 'Konak, İzmir',
          desc: 'Klima montajı lazım beş kelime',
          createdAt: DateTime.now().subtract(const Duration(hours: 40)));
      expiry.sweep();
      expect(
          notifs
              .forUser(cust)
              .where((n) => n.type == NotifType.listingExpired && n.refId == l2.id),
          isNotEmpty);
    });

    test('yeni mesaj karşı tarafa bildirilir; okunmadı sayacı ve tümünü okundu',
        () async {
      final t = await teklifliIlan();
      await contactCtl.openShared(t.offerId, actorId: cust);
      final ctl = chatCtl();
      await ctl.sendDelivered(t.offerId, senderId: cust, text: 'Merhaba');
      expect(notifs.forUser(p1).map((n) => n.type),
          contains(NotifType.newMessage));
      expect(notifs.unreadCount(p1), greaterThan(0));
      notifs.markAllRead(p1);
      expect(notifs.unreadCount(p1), 0);
    });
  });

  group('Cüzdan (Paket 3)', () {
    test('ÇİFT YÜKLEME YOK: eşzamanlı ikinci oturum açılamaz, tek artış olur',
        () async {
      final auth = AuthRepository();
      auth.girisEposta(kTestEmail, kTestPass);
      final w = WalletRepository();
      final ctl = WalletController(MockWalletPort(w), MockAuthPort(auth));
      final me = auth.currentAccount!.id;

      // ADIM 1 — eşzamanlı iki oturum isteği: ikincisi meşguliyet kilidine takılır.
      final f1 = ctl.startTopup(amount: DomainConfig.minTopup);
      final f2 = ctl.startTopup(amount: DomainConfig.minTopup);
      final (s1, e1) = await f1;
      await f2;
      expect(e1, isNull);
      expect(s1, isNotNull);

      // Onay gelmeden bakiye ARTMAZ.
      expect(w.walletOf(me).avail, 0);

      // ADIM 2 — tek doğrulama, tek artış.
      final (status, cerr) = await ctl.confirmTopup();
      expect(cerr, isNull);
      expect(status, PaymentStatus.succeeded);
      expect(w.walletOf(me).avail, DomainConfig.minTopup);
      expect(w.walletOf(me).txs.length, 1);

      // Aynı oturum ikinci kez doğrulanamaz (idempotent sonuç).
      final (again, _) = await ctl.confirmTopup();
      expect(again, isNull, reason: 'oturum tüketildi');
      expect(w.walletOf(me).avail, DomainConfig.minTopup);
    });
  });

  group('Profil', () {
    test('profil güncelleme, TEK adres güncelleme ve usta tercihleri', () async {
      final auth = AuthRepository();
      auth.register(
          phone: '5507654321', pass: 'p1p1p1', role: Role.provider,
          otpVerified: true, termsAccepted: true, name: 'Ali Usta', email: 'ali@usta.com',
          categories: {'Tesisat'}, serviceDistricts: {'Konak'});
      final me = auth.currentAccount!;
      expect(me.email, 'ali@usta.com');
      expect(me.categories, {'Tesisat'});
      auth.updateProfile(name: 'Ali Veli Usta', email: 'ali2@usta.com');
      expect(me.name, 'Ali Veli Usta');
      // TEK ADRES: ekleme/silme YOKTUR; yalnız güncelleme vardır.
      auth.setAddress(district: 'Konak', neighborhood: 'Alsancak');
      expect(me.address, isNotNull);
      expect(me.address!.district, 'Konak');
      expect(me.address!.neighborhood, 'Alsancak');
      expect(me.address!.display, 'Alsancak, Konak / İzmir');

      // İkinci çağrı YENİ kayıt açmaz, mevcut kaydı GÜNCELLER.
      auth.setAddress(district: 'Bornova', neighborhood: 'Kazımdirik');
      expect(me.address!.district, 'Bornova');
      expect(me.address!.neighborhood, 'Kazımdirik');
      auth.setProviderPrefs(
          categories: {'Boya', 'Tadilat'}, districts: {'Bornova'});
      expect(me.categories, {'Boya', 'Tadilat'});
      expect(me.serviceDistricts, {'Bornova'});
    });
  });
}
