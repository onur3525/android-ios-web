import 'package:flutter_test/flutter_test.dart';

import 'support/mock_wiring.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/controllers/review_controller.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';

void main() {
  late WalletRepository wallets;
  late OfferController offerCtl;
  late ContactController contactCtl;
  late ListingController listingCtl;
  late ReviewController reviewCtl;
  const fee = DomainConfig.contactFee;
  const p1 = 'usta-1', p2 = 'usta-2', cust = 'musteri-1', stranger = 'yabanci-9';

  late MockWiring w0;
  setUp(() {
    w0 = MockWiring();
    wallets = w0.wallets;
    offerCtl = w0.offerCtl;
    contactCtl = w0.contactCtl;
    listingCtl = w0.listingCtl;
    reviewCtl = w0.reviewCtl;
  });

  Future<Listing> ilan() async {
    final r = (await listingCtl.publish(
        ownerId: cust, title: 'Kombi Bakımı', location: 'Konak, İzmir',
        desc: 'Kombi bakımı yapılacak beş kelime tamam')).listing!;
    return r;
  }

  group('Teklif geri çekme', () {
    test('açılmamış bloke İADE edilir; teklif cancelled olur', () async {
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      final w = wallets.walletOf(p1);
      final a0 = w.avail;
      expect(await offerCtl.withdrawOffer(offerId: o.id, actorId: p1), isNull);
      expect(o.status, OfferStatus.cancelled);
      expect(w.avail, a0 + fee);
      expect(w.blocked, WalletRepository.demoBlocked);
    });

    test('iletişimi AÇILMIŞ ücret geri çekmede iade edilmez', () async {
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      await contactCtl.openShared(o.id, actorId: cust);
      final w = wallets.walletOf(p1);
      final a0 = w.avail, b0 = w.blocked;
      expect(await offerCtl.withdrawOffer(offerId: o.id, actorId: p1), isNull);
      expect(w.avail, a0); // iade YOK
      expect(w.blocked, b0);
    });

    test('yabancı geri çekemez; seçilmiş teklif geri çekilemez', () async {
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(await offerCtl.withdrawOffer(offerId: o.id, actorId: p2),
          isA<UnauthorizedError>());
      await offerCtl.selectOffer(listingId: l.id, offerId: o.id, actorId: cust);
      expect(await offerCtl.withdrawOffer(offerId: o.id, actorId: p1),
          isA<InvalidStateError>());
      expect(o.status, OfferStatus.selected);
    });

    test('geçersiz offerId hiçbir state değiştirmez', () async {
      expect(await offerCtl.withdrawOffer(offerId: 'yok', actorId: p1),
          isA<NotFoundError>());
    });
  });

  group('Değerlendirme kuralları', () {
    Future<({Listing l, Offer o})> tamamlanmisIs() async {
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      // ⚠ REFERANS SIRASI (HTML `vOffer` → `submitReviewDo`):
      // önce İLETİŞİM açılır, sonra "Teklifi Seç" düğmesi çıkar ve o
      // düğme değerlendirme panelini açar. Seçim, değerlendirme
      // gönderilirken yazılır.
      await contactCtl.openShared(o.id, actorId: cust);
      return (l: l, o: o);
    }

    test('İLETİŞİM AÇILMADAN değerlendirme yapılamaz', () async {
      // ⚠ ESKİ KURAL: "ilan completed olmadan değerlendirilemez".
      //
      // O kural uygulanamıyordu: ilanı tamamlayan hiçbir istemci
      // eylemi yoktu, dolayısıyla değerlendirmeye HİÇ ulaşılamıyordu.
      // Referansta önkoşul farklı: `.pr-cta` iletişim açılmadan
      // "Teklifi Seç" düğmesini ÇİZMEZ. Kapı artık iletişimdir.
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(await reviewCtl.submit(
              listingId: l.id, offerId: o.id, actorId: cust, stars: 5, text: 'x'),
          isA<InvalidStateError>());
    });

    test('DEĞERLENDİRME SEÇİMİ DE YAZAR (referans submitReviewDo)', () async {
      // Referans: değerlendirme gönderilince ilan `done` olur, seçilen
      // teklif işaretlenir ve seçilmeyenlerin açılmamış blokesi iade
      // edilir. Üçü de TEK adımda.
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'b');
      final o1 = offerCtl.myOfferFor(l.id, p1)!;
      final o2 = offerCtl.myOfferFor(l.id, p2)!;
      await contactCtl.openShared(o1.id, actorId: cust);

      expect(await reviewCtl.submit(
              listingId: l.id, offerId: o1.id, actorId: cust,
              stars: 5, text: 'iyi iş'),
          isNull);

      expect(l.status, ListingStatus.completed, reason: 'ilan tamamlanmadı');
      expect(l.selectedOfferId, o1.id, reason: 'seçim yazılmadı');
      expect(o1.status, OfferStatus.selected);
      expect(o2.status, OfferStatus.cancelled, reason: 'rakip iptal edilmedi');
      expect(o2.escrowBlocked, isFalse, reason: 'rakip blokesi iade edilmedi');
    });

    test('yalnız ilan sahibi ve yalnız seçilmiş teklif değerlendirilir', () async {
      final t = await tamamlanmisIs();
      expect(await reviewCtl.submit(
              listingId: t.l.id, offerId: t.o.id, actorId: stranger,
              stars: 5, text: 'x'),
          isA<UnauthorizedError>());
      // aynı ilana ikinci (seçilmemiş) teklif senaryosu
      final l2 = await ilan();
      await offerCtl.placeOffer(listingId: l2.id, providerId: p1, amount: 1, note: 'a');
      await offerCtl.placeOffer(listingId: l2.id, providerId: p2, amount: 2, note: 'b');
      final o1 = offerCtl.myOfferFor(l2.id, p1)!;
      final o2 = offerCtl.myOfferFor(l2.id, p2)!;
      await contactCtl.openShared(o1.id, actorId: cust);
      await reviewCtl.submit(
          listingId: l2.id, offerId: o1.id, actorId: cust,
          stars: 5, text: 'seçildi');
      expect(await reviewCtl.submit(
              listingId: l2.id, offerId: o2.id, actorId: cust, stars: 4, text: 'y'),
          isA<InvalidStateError>()); // seçilmemiş teklif
    });

    test('tek sefer: ikinci değerlendirme tip güvenli reddedilir', () async {
      final t = await tamamlanmisIs();
      expect(await reviewCtl.submit(
              listingId: t.l.id, offerId: t.o.id, actorId: cust,
              stars: 5, text: 'Harika iş'),
          isNull);
      expect(reviewCtl.byOffer(t.o.id)!.stars, 5);
      expect(await reviewCtl.submit(
              listingId: t.l.id, offerId: t.o.id, actorId: cust,
              stars: 1, text: 'tekrar'),
          isA<InvalidStateError>());
      expect(reviewCtl.byOffer(t.o.id)!.stars, 5); // ilk kayıt değişmedi
      expect(reviewCtl.byProvider(p1).length, 1);
    });

    test('geçersiz puan reddedilir', () async {
      final t = await tamamlanmisIs();
      expect(await reviewCtl.submit(
              listingId: t.l.id, offerId: t.o.id, actorId: cust, stars: 0, text: ''),
          isA<ValidationError>());
    });
  });
}
