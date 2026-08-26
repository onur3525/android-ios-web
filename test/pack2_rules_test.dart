import 'dart:io';

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

/// Yorumsuz kaynak metni.
///
/// ⚠ YOKLUK İDDİASI KURULACAĞI İÇİN YORUMLAR ELENİR: kaldırılan
/// davranışı ANLATAN yorum satırları ham metinde "withdraw" içerir ve
/// yanlış alarm verirdi.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

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

  group('⚠ TEKLİF GERİ ÇEKME KALDIRILDI', () {
    // API sözleşmesi §1 ve kabul testi 2: "Teklif geri çekilemez ve
    // değiştirilemez." Eskiden bu grupta dört test vardı ve geri
    // çekmenin ÇALIŞTIĞINI kilitliyordu; kural tersine döndüğü için
    // davranışın YOKLUĞU kilitlenir.
    //
    // ⚠ Aynı işi başka adla yapan bir uç da EKLENMEDİ: kural ad
    // değiştirerek dolaşılmaz.
    test('hiçbir katmanda geri çekme yok', () {
      final yollar = {
        'API': 'lib/data/remote/api/offer_api.dart',
        'API repository': 'lib/data/remote/repositories/api_repositories.dart',
        'port arayüzü': 'lib/data/ports/repository_ports.dart',
        'API port': 'lib/data/ports/api_ports.dart',
        'mock port': 'lib/data/ports/mock_ports.dart',
        'controller': 'lib/data/controllers/offer_controller.dart',
      };
      yollar.forEach((ad, yol) {
        final k = _kodu(yol);
        expect(k.contains('withdraw'), isFalse, reason: '$ad: withdraw kalmış');
      });
    });

    test('alternatif adla geri getirilmemiş', () {
      for (final yol in const [
        'lib/data/ports/repository_ports.dart',
        'lib/data/controllers/offer_controller.dart',
      ]) {
        final k = _kodu(yol);
        for (final ad in const [
          'cancelOffer', 'deleteOffer', 'removeOffer', 'revokeOffer', 'undoOffer'
        ]) {
          expect(k.contains(ad), isFalse, reason: '$yol: $ad eklenmiş');
        }
      }
    });

    test('teklif verme akışı BOZULMADI', () async {
      final l = await ilan();
      expect(
          await offerCtl.placeOffer(
              listingId: l.id, providerId: p1, amount: 900, note: 'n'),
          isNull);
      expect(offerCtl.myOfferFor(l.id, p1), isNotNull);
    });
  });

  group('Değerlendirme kuralları', () {
    Future<({Listing l, Offer o})> tamamlanmisIs() async {
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      // ⚠ ZİNCİR: iletişim → seçim → yorum.
      //
      // "Teklifi Seç" düğmesi yalnız iletişim AÇIKKEN çizilir; seçim
      // ilanı doğrudan "tamamlanan işler"e taşır; yorum sonra ve
      // dilendiği zaman yazılır.
      await contactCtl.openShared(o.id, actorId: cust);
      await offerCtl.selectOffer(listingId: l.id, offerId: o.id, actorId: cust);
      return (l: l, o: o);
    }

    test('SEÇİM YAPILMADAN değerlendirme yapılamaz', () async {
      // ⚠ ESKİ KURAL: "ilan completed olmadan değerlendirilemez".
      //
      // O kural uygulanamıyordu: ilanı tamamlayan hiçbir istemci
      // eylemi yoktu, dolayısıyla değerlendirmeye HİÇ ulaşılamıyordu.
      // Doğru kapı SEÇİMDİR; seçim de ancak iletişim açıkken
      // yapılabildiği için zincir tamdır.
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(await reviewCtl.submit(
              listingId: l.id, offerId: o.id, actorId: cust, stars: 5, text: 'x'),
          isA<InvalidStateError>());
    });

    test('SEÇİM İLANI TAMAMLAR ve rakip blokeleri iade eder', () async {
      final l = await ilan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'b');
      final o1 = offerCtl.myOfferFor(l.id, p1)!;
      final o2 = offerCtl.myOfferFor(l.id, p2)!;
      await contactCtl.openShared(o1.id, actorId: cust);

      expect(
          await offerCtl.selectOffer(
              listingId: l.id, offerId: o1.id, actorId: cust),
          isNull);

      // ⚠ İlan doğrudan "tamamlanan işler"e taşınır; ara durum yok.
      // ⚠ Tamamlanmışlık ilişkiden türetilir (§24).
      expect(l.isTamamlanmisIs, isTrue, reason: 'ilan tamamlanmadı');
      expect(l.status, ListingStatus.active);
      expect(l.selectedOfferId, o1.id);
      expect(o1.status, OfferStatus.selected);
      expect(o2.status, OfferStatus.closed, reason: 'rakip iptal edilmedi');
      expect(o2.escrowBlocked, isFalse, reason: 'rakip blokesi iade edilmedi');
      // ⚠ Seçilenin ücreti iletişim açılırken TÜKETİLMİŞTİ; iade yok.
      expect(o1.escrowConsumed, isTrue);
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
      await offerCtl.selectOffer(
          listingId: l2.id, offerId: o1.id, actorId: cust);
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
