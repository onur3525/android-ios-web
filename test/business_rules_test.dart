import 'package:flutter_test/flutter_test.dart';

import 'support/mock_wiring.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/repositories/offer_repository.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/listing_state_machine.dart';

void main() {
  late MockWiring w0;
  late OfferRepository offers;
  late OfferController offerCtl;
  late ContactController contactCtl;
  late ListingController listingCtl;
  const p1 = 'usta-1', p2 = 'usta-2', cust = 'musteri-1', stranger = 'yabanci-9';

  setUp(() {
    // Uygulamadaki DI ile aynı bileşim: controller'lar port üzerinden bağlanır.
    w0 = MockWiring();
    offers = w0.offers;
    offerCtl = w0.offerCtl;
    contactCtl = w0.contactCtl;
    listingCtl = w0.listingCtl;
  });

  Future<Listing> yeniIlan({String owner = cust}) async {
    final r = (await listingCtl.publish(
        ownerId: owner, title: 'Kombi Bakımı', location: 'Konak, İzmir',
        desc: 'Kombi bakımı yapılacak beş kelime tamam')).listing!;
    return r;
  }

  group('Teklif verme', () {
    // ── ⚠ YENİ İŞ MODELİ: ÜCRETSİZ VE SINIRSIZ ──
    //
    // HizmetCep hem hizmet alan hem hizmet veren için TAMAMEN
    // ÜCRETSİZDİR. Bakiye, bloke, kredi ve kota kavramları ürün
    // kapsamından çıktı.
    test('⚠ TEKLİF VERME ÜCRETSİZ — bakiye koşulu yok', () async {
      final l = await yeniIlan();
      expect(
          await offerCtl.placeOffer(
              listingId: l.id, providerId: p1, amount: 900, note: 'Notum'),
          isNull);
      expect(offerCtl.myOfferFor(l.id, p1), isNotNull);
    });

    test('⚠ TEKLİF SAYISINDA KOTA YOK — 25 ilana teklif verilir', () async {
      for (var i = 0; i < 25; i++) {
        final l = await yeniIlan();
        expect(
            await offerCtl.placeOffer(
                listingId: l.id, providerId: p1, amount: 500, note: 'n'),
            isNull,
            reason: '${i + 1}. teklif reddedildi — kota olmamalı');
      }
    });

    test('⚠ İLETİŞİM AÇMA ÜCRETSİZ VE KOŞULSUZ', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      // Hiçbir ön koşul yok: doğrudan açılır.
      expect(await contactCtl.openShared(o.id, actorId: p1), isNull);
      expect(contactCtl.isOpen(o.id), isTrue);
    });

    test('KENDİ ilanına teklif verilemez (Y2)', () async {
      final l = await yeniIlan(owner: p1); // ilan sahibi = usta-1
      expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 500, note: 'n'),
          isA<OwnListingOfferError>());
      expect(offerCtl.offersForListing(l.id), isEmpty);
    });

    test('çoklu usta teklif verebilir; aynı usta ikinciyi veremez; sıralama createdAt', () async {
      final l = await yeniIlan();
      expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a'), isNull);
      expect(await offerCtl.placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'b'), isNull);
      final list = offerCtl.offersForListing(l.id);
      expect(list.length, 2);
      expect(list.first.providerId, p1); // önce gelen üstte (createdAt)
      expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 700, note: 'c'),
          isA<DuplicateOfferError>());
    });

    test('kapalı ilana teklif verilemez (cancelled/expired)', () async {
      final l1 = await yeniIlan();
      await listingCtl.delete(l1.id, actorId: cust);
      expect(await offerCtl.placeOffer(listingId: l1.id, providerId: p1, amount: 500, note: 'n'),
          isA<ListingClosedError>());
      final l2 = await yeniIlan();
      await listingCtl.expire(l2.id, actorId: cust);
      expect(await offerCtl.placeOffer(listingId: l2.id, providerId: p2, amount: 500, note: 'n'),
          isA<ListingClosedError>());
    });
  });

  group('Ortak iletişim (tek tüketim)', () {
    test('taraflardan biri açınca iki taraf için açılır; bloke BİR KEZ tüketilir', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(await contactCtl.openShared(o.id, actorId: p1), isNull); // usta açtı
      expect(contactCtl.isOpen(o.id), isTrue);

      expect(await contactCtl.openShared(o.id, actorId: cust), isNull); // müşteri tekrar → no-op
      expect(contactCtl.isOpen(o.id), isTrue); // ikinci çağrı no-op
    });

    test('müşteri (ilan sahibi) de açabilir; ücret ustanın blokesinden', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(await contactCtl.openShared(o.id, actorId: cust), isNull);
      expect(contactCtl.isOpen(o.id), isTrue);
      expect(w.avail, a1);
    });

    test('YETKİSİZ aktör açamaz; başka usta başkasının teklifini açamaz (Y3)', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(await contactCtl.openShared(o.id, actorId: stranger), isA<UnauthorizedError>());
      expect(await contactCtl.openShared(o.id, actorId: p2), isA<UnauthorizedError>());
      expect(contactCtl.isOpen(o.id), isFalse);          // state DEĞİŞMEDİ
    });

    test('geçersiz offerId HİÇBİR state değişikliği oluşturmaz (O3)', () async {
      expect(await contactCtl.openShared('olmayan-id', actorId: p1), isA<NotFoundError>());
      expect(contactCtl.isOpen('olmayan-id'), isFalse);
    });
  });

  group('Seçim + iade', () {
    test('yalnız İLAN SAHİBİ seçebilir (Y3)', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o1 = offerCtl.myOfferFor(l.id, p1)!;
      expect(await offerCtl.selectOffer(listingId: l.id, offerId: o1.id, actorId: p1),
          isA<UnauthorizedError>());
      expect(l.status, ListingStatus.active); // değişmedi
    });

    test('seçim: ilan TAMAMLANIR, diğerleri iptal + açılmamış bloke İADE',
        () async {
      // ⚠ ÜRÜN KARARI (18 Ağu): seçim ilanı doğrudan "tamamlanan
      // işler"e taşır. Ara durum `providerSelected` durum makinesinde
      // GEÇERLİLİĞİNİ KORUR (backend gönderebilir, eski kayıtlar
      // taşır) ama istemci artık onu ÜRETMEZ.
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'b');
      final o1 = offerCtl.myOfferFor(l.id, p1)!;
      final o2 = offerCtl.myOfferFor(l.id, p2)!;
      expect(await offerCtl.selectOffer(listingId: l.id, offerId: o2.id, actorId: cust), isNull);
      // ⚠ Tamamlanmışlık ilişkiden türetilir (§24); ilan ACTIVE kalır.
      expect(l.isTamamlanmisIs, isTrue);
      expect(l.status, ListingStatus.active);
      expect(l.selectedOfferId, o2.id);
      expect(o2.status, OfferStatus.selected);
      expect(o1.status, OfferStatus.closed);
    });

  });

  group('Durum makinesi (Y1)', () {
    test('⚠ NİHAİ GEÇİŞ TABLOSU — dört yaşam durumu (§24)', () async {
      // `completed` / `providerSelected` / `inProgress` ARTIK YOK.
      // Tablo yalnız ilanın YAŞAMINI tanımlar; tamamlanmışlık
      // `selectedOfferId` ilişkisinden türetilir.
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.active, ListingStatus.expired),
          isTrue);
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.active, ListingStatus.userDeleted),
          isTrue);
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.active, ListingStatus.adminRemoved),
          isTrue);
      // Kapanmış durumlardan GERİ DÖNÜŞ yok.
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.userDeleted, ListingStatus.active),
          isFalse);
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.adminRemoved, ListingStatus.active),
          isFalse);
      // ⚠ Süresi dolmuş ilan silinebilir/kaldırılabilir (§12).
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.expired, ListingStatus.userDeleted),
          isTrue);
    });


    test('akış: open→completed (seçim doğrudan tamamlar)', () async {
      // ⚠ ÜRÜN KARARI: ayrı "İşi Başlat" adımı KALDIRILDI.
      //
      // Teklif seçildikten sonra iş fiilen başlamıştır; ayrıca
      // "başlat" demek fazladan bir adımdı ve unutulduğunda ilan
      // tamamlanamaz duruma düşüyordu.
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.selectOffer(
          listingId: l.id, offerId: offerCtl.myOfferFor(l.id, p1)!.id, actorId: cust);
      // ⚠ SEÇİM İLANI DOĞRUDAN TAMAMLAR (18 Ağu): ayrı bir
      // "tamamla" adımı yok, ilan seçimle birlikte "tamamlanan
      // işler"e taşınır.
      // ⚠ Tamamlanmışlık ilişkiden türetilir (§24); ilan ACTIVE kalır.
      expect(l.isTamamlanmisIs, isTrue);
      expect(l.status, ListingStatus.active);
      // ⚠ İkinci seçim reddedilir; ilan bir kez tamamlanır.
      expect(
          await offerCtl.selectOffer(
              listingId: l.id,
              offerId: offerCtl.myOfferFor(l.id, p1)!.id,
              actorId: cust),
          isA<InvalidStateError>());
    });

    test('AYNI İLANDA İKİNCİ SEÇİM YAPILAMAZ', () async {
      // İki teklif; biri seçilince ilan `completed` olur ve o durumdan
      // yeni bir seçim geçişi YOKTUR (durum makinesi kapatır).
      final l = await yeniIlan();
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p2, amount: 800, note: 'b');
      final o1 = offerCtl.myOfferFor(l.id, p1)!;
      final o2 = offerCtl.myOfferFor(l.id, p2)!;

      expect(
          await offerCtl.selectOffer(
              listingId: l.id, offerId: o1.id, actorId: cust),
          isNull);
      expect(l.selectedOfferId, o1.id);
      expect(o2.status, OfferStatus.closed, reason: 'rakip kapanmalı');

      // İkinci seçim reddedilir; ilk seçim BOZULMAZ.
      final err = await offerCtl.selectOffer(
          listingId: l.id, offerId: o2.id, actorId: cust);
      expect(err, isA<InvalidStateError>());
      expect(l.selectedOfferId, o1.id, reason: 'ilk seçim korunmalı');
      expect(o1.status, OfferStatus.selected);
      expect(o2.status, OfferStatus.closed);
    });

    test('SEÇİLİ TEKLİF YOKSA tamamlanamaz — durum DEĞİŞMEZ', () async {
      // ⚠ `providerSelected` ve `completed` anlamlarını seçili
      // teklifden alır. `selectedOfferId` boşken bu durumlara geçmek
      // ilanı tutarsız hâle sokar: kim seçildi, kim tamamladı belli
      // olmaz; değerlendirme de hedefsiz kalır.
      final l = await yeniIlan();
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      await offerCtl.selectOffer(
          listingId: l.id, offerId: o.id, actorId: cust);
      // ⚠ Tamamlanmışlık ilişkiden türetilir (§24); ilan ACTIVE kalır.
      expect(l.isTamamlanmisIs, isTrue);
      expect(l.status, ListingStatus.active);
      expect(l.selectedOfferId, isNotNull);

      // Veri tutarsızlığı simüle edilir: seçim kaydı kaybolmuş.
      l.selectedOfferId = null;

      // ⚠ `completeWork` KALDIRILDI (§11); tutarsız veri artık BAŞKA
      // bir geçiş denemesiyle sınanır: tamamlanmış ilan iptal
      // EDİLEMEZ ve durum bozulmaz.
      final err = await listingCtl.delete(l.id, actorId: cust);
      expect(err, isA<InvalidStateError>(),
          reason: 'sessizce geçilmemeli, AÇIK hata dönmeli');
      // ⚠ EN ÖNEMLİSİ: ilan TUTARSIZ duruma DÜŞMEDİ.
      expect(l.status, ListingStatus.active,
          reason: 'denetim geçişten ÖNCE yapılır — durum bozulmadı');
    });

    test('⚠ TAMAMLANMIŞ İŞ SİLİNEMEZ — denetim ilişkiden yapılır', () async {
      // `canDelete` artık DURUMU değil İLANI alır: tamamlanmışlık
      // `selectedOfferId` ile belirlendiği için durum tek başına
      // yetmez.
      final l = await yeniIlan();
      expect(ListingStateMachine.canDelete(l), isTrue,
          reason: 'yaşayan, seçimsiz ilan silinebilir');

      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      await contactCtl.openShared(o.id, actorId: cust);
      await offerCtl.selectOffer(
          listingId: l.id, offerId: o.id, actorId: cust);

      expect(l.isTamamlanmisIs, isTrue, reason: 'seçim tamamlanmışlık üretir');
      expect(l.status, ListingStatus.active,
          reason: 'seçim ilanın YAŞAM durumunu değiştirmez');
      expect(ListingStateMachine.canDelete(l), isFalse,
          reason: 'tamamlanmış iş silinemez');
    });


    test('İLETİŞİM: iki taraftan biri açar, ücret YALNIZ sağlayıcıdan', () async {
      // ⚠ NİHAİ İŞ KURALI.
      //
      // İletişimi hizmet alan da hizmet veren de açabilir. İlk açan
      // kim olursa olsun iletişim İKİ TARAF için birden açılır ve
      // bedel YALNIZ hizmet verenin blokesinden düşer. Hizmet alandan
      // hiçbir ücret alınmaz; ikinci kez de ücret alınmaz.
      final l = await yeniIlan();
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      await offerCtl.selectOffer(
          listingId: l.id, offerId: o.id, actorId: cust);

      // HİZMET ALAN açıyor.
      expect(await contactCtl.openShared(o.id, actorId: cust), isNull);
      expect(contactCtl.isOpen(o.id), isTrue);

      // Bedel sağlayıcının BLOKESİNDEN tüketildi.
      // Hizmet alandan HİÇBİR ücret alınmadı.

      // İkinci açma ücretsizdir (idempotent).
      expect(await contactCtl.openShared(o.id, actorId: p1), isNull);
    });

    test('expire yalnız open durumda; inProgress süresi dolamaz', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.selectOffer(
          listingId: l.id, offerId: offerCtl.myOfferFor(l.id, p1)!.id, actorId: cust);
      expect(await listingCtl.expire(l.id, actorId: cust), isA<InvalidStateError>());
    });
  });

  group('İptal / süre dolumu / silme', () {
    test('yetkisiz aktör ilan yönetemez (Y3)', () async {
      final l = await yeniIlan();
      expect(await listingCtl.delete(l.id, actorId: stranger), isA<UnauthorizedError>());
      expect(await listingCtl.delete(l.id, actorId: p1), isA<UnauthorizedError>());
      expect(l.status, ListingStatus.active);
      expect(listingCtl.byId(l.id), isNotNull);
    });

    test('UUID kimlikler: bir ilan silinince diğerinin kayıtları bozulmaz', () async {
      final la = await yeniIlan();
      final lb = await yeniIlan();
      await offerCtl.placeOffer(listingId: la.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(listingId: lb.id, providerId: p1, amount: 700, note: 'b');
      final ob = offerCtl.myOfferFor(lb.id, p1)!;
      await contactCtl.openShared(ob.id, actorId: p1);
      await listingCtl.delete(la.id, actorId: cust);
      expect(offerCtl.myOfferFor(lb.id, p1)!.id, ob.id);
      expect(contactCtl.isOpen(ob.id), isTrue);
    });

    test('müşteri ücretsiz + sınırsız ilan verebilir (cüzdan etkilenmez)', () async {
      for (var i = 0; i < 25; i++) {
        await yeniIlan();
      }
      expect(listingCtl.byOwner(cust).length, 25);
    });
  });
}
