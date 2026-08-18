import 'package:flutter_test/flutter_test.dart';

import 'support/mock_wiring.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/repositories/offer_repository.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/listing_state_machine.dart';

void main() {
  late MockWiring w0;
  late WalletRepository wallets;
  late OfferRepository offers;
  late OfferController offerCtl;
  late ContactController contactCtl;
  late ListingController listingCtl;
  const fee = DomainConfig.contactFee;
  const p1 = 'usta-1', p2 = 'usta-2', cust = 'musteri-1', stranger = 'yabanci-9';

  setUp(() {
    // Uygulamadaki DI ile aynı bileşim: controller'lar port üzerinden bağlanır.
    w0 = MockWiring();
    wallets = w0.wallets;
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

  group('Teklif + bloke', () {
    test('teklif ücretsiz + bloke: avail-50, blocked+50; kayıt oluşur', () async {
      final l = await yeniIlan();
      final w = wallets.walletOf(p1);
      final a0 = w.avail, b0 = w.blocked;
      expect(await offerCtl.placeOffer(
              listingId: l.id, providerId: p1, amount: 900, note: 'Notum'),
          isNull);
      expect(w.avail, a0 - fee);
      expect(w.blocked, b0 + fee);
      final o = offerCtl.myOfferFor(l.id, p1)!;
      expect(o.escrowBlocked, isTrue);
      expect(o.escrowConsumed, isFalse);
    });

    test('yetersiz kullanılabilir bakiye → teklif verilemez (tip güvenli)', () async {
      final l = await yeniIlan();
      wallets.walletOf(p1).avail = fee - 1;
      expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 500, note: 'n'),
          isA<InsufficientBalanceError>());
      expect(offerCtl.myOfferFor(l.id, p1), isNull);
    });

    test('KENDİ ilanına teklif verilemez (Y2)', () async {
      final l = await yeniIlan(owner: p1); // ilan sahibi = usta-1
      expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 500, note: 'n'),
          isA<OwnListingOfferError>());
      expect(offerCtl.offersForListing(l.id), isEmpty);
      // cüzdan da etkilenmedi
      expect(wallets.walletOf(p1).avail, WalletRepository.demoAvail);
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
      await listingCtl.cancel(l1.id, actorId: cust);
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
      final w = wallets.walletOf(p1);
      final a1 = w.avail, b1 = w.blocked;

      expect(await contactCtl.openShared(o.id, actorId: p1), isNull); // usta açtı
      expect(contactCtl.isOpen(o.id), isTrue);
      expect(w.avail, a1);         // kullanılabilir SABİT (müşteri de ödemedi)
      expect(w.blocked, b1 - fee); // blokeden tüketildi

      expect(await contactCtl.openShared(o.id, actorId: cust), isNull); // müşteri tekrar → no-op
      expect(w.avail, a1);
      expect(w.blocked, b1 - fee); // ikinci tüketim YOK
    });

    test('müşteri (ilan sahibi) de açabilir; ücret ustanın blokesinden', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      final w = wallets.walletOf(p1);
      final a1 = w.avail;
      expect(await contactCtl.openShared(o.id, actorId: cust), isNull);
      expect(contactCtl.isOpen(o.id), isTrue);
      expect(w.avail, a1);
    });

    test('YETKİSİZ aktör açamaz; başka usta başkasının teklifini açamaz (Y3)', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      final b0 = wallets.walletOf(p1).blocked;
      expect(await contactCtl.openShared(o.id, actorId: stranger), isA<UnauthorizedError>());
      expect(await contactCtl.openShared(o.id, actorId: p2), isA<UnauthorizedError>());
      expect(contactCtl.isOpen(o.id), isFalse);          // state DEĞİŞMEDİ
      expect(wallets.walletOf(p1).blocked, b0);           // tüketim YOK
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
      expect(l.status, ListingStatus.open); // değişmedi
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
      final w1 = wallets.walletOf(p1);
      final a1 = w1.avail;

      expect(await offerCtl.selectOffer(listingId: l.id, offerId: o2.id, actorId: cust), isNull);
      expect(l.status, ListingStatus.completed);
      expect(l.selectedOfferId, o2.id);
      expect(o2.status, OfferStatus.selected);
      expect(o1.status, OfferStatus.cancelled);
      expect(w1.avail, a1 + fee); // p1'in açılmamış blokesi kendi cüzdanına iade
      expect(wallets.walletOf(p2).blocked, greaterThanOrEqualTo(fee));
    });

    test('tüketilmiş iletişim ücreti seçimde İADE EDİLMEZ', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'b');
      final o1 = offerCtl.myOfferFor(l.id, p1)!;
      await contactCtl.openShared(o1.id, actorId: p1);
      final w1 = wallets.walletOf(p1);
      final a1 = w1.avail, b1 = w1.blocked;
      await offerCtl.selectOffer(
          listingId: l.id,
          offerId: offerCtl.myOfferFor(l.id, p2)!.id,
          actorId: cust);
      expect(w1.avail, a1);
      expect(w1.blocked, b1);
    });
  });

  group('Durum makinesi (Y1)', () {
    test('merkezi tanım: completed uç durumdur', () async {
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.completed, ListingStatus.cancelled),
          isFalse);
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.completed, ListingStatus.expired),
          isFalse);
      expect(ListingStateMachine.canDelete(ListingStatus.completed), isFalse);
    });

    test('akış: open→completed (seçim doğrudan tamamlar)', () async {
      // ⚠ ÜRÜN KARARI: ayrı "İşi Başlat" adımı KALDIRILDI.
      //
      // Teklif seçildikten sonra iş fiilen başlamıştır; ayrıca
      // "başlat" demek fazladan bir adımdı ve unutulduğunda ilan
      // tamamlanamaz duruma düşüyordu.
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      // Teklif seçilmeden tamamlanamaz.
      expect(await listingCtl.completeWork(l.id, actorId: cust),
          isA<InvalidStateError>());
      await offerCtl.selectOffer(
          listingId: l.id, offerId: offerCtl.myOfferFor(l.id, p1)!.id, actorId: cust);
      // ⚠ SEÇİM İLANI DOĞRUDAN TAMAMLAR (18 Ağu): ayrı bir
      // "tamamla" adımı yok, ilan seçimle birlikte "tamamlanan
      // işler"e taşınır.
      expect(l.status, ListingStatus.completed);
      // İkinci kez tamamlanamaz (uç durum).
      expect(await listingCtl.completeWork(l.id, actorId: cust),
          isA<InvalidStateError>());
    });

    test('ATOMİKLİK: consume başarısızsa İLETİŞİM AÇILMAZ', () async {
      // ⚠ PARTIAL-STATE AÇIĞIYDI.
      //
      // Eski sırada `contacts.open()` ÖNCE çağrılıyordu; `consume`
      // sonra `StateError` atınca iletişim AÇIK kalıyor, para
      // alınmıyordu → ücretsiz iletişim.
      //
      // Yeni sırada para ÖNCE tahsil edilir; atarsa hiçbir durum
      // yazılmamış olur.
      final l = await yeniIlan();
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      final w = wallets.walletOf(p1);
      // ⚠ MUTLAK DEĞER DEĞİL FARK ÖLÇÜLÜR.
      //
      // `setUp` cüzdanı sıfırlamıyor; aynı gruptaki önceki testlerden
      // bloke birikmiş olabilir. Mutlak `fee` beklentisi test SIRASINA
      // bağımlı olur ve tek başına geçip toplu koşuda düşer.
      expect(w.blocked, greaterThanOrEqualTo(fee),
          reason: 'teklif blokeyi almalı');

      // Bloke ELLE boşaltılır: `consume` artık StateError atacak.
      // (Gerçekte veri tutarsızlığı veya eşzamanlı iade ile oluşur.)
      w.blocked = 0;

      expect(
        () => contactCtl.openShared(o.id, actorId: p1),
        throwsA(isA<StateError>()),
        reason: 'yetersiz bloke StateError atmalı',
      );

      // ⚠ EN ÖNEMLİSİ: hiçbir durum DEĞİŞMEMİŞ olmalı.
      expect(contactCtl.isOpen(o.id), isFalse,
          reason: 'ücret alınmadan iletişim AÇILMAMALI');
      expect(o.escrowBlocked, isTrue, reason: 'bayrak bozulmamalı');
      expect(o.escrowConsumed, isFalse, reason: 'tüketildi sayılmamalı');
    });

    test('GERİ ÇEKİLMİŞ TEKLİF SEÇİLEMEZ — bedava iletişim engeli', () async {
      // ⚠ GERÇEK AÇIKTI (SM-1), davranış testiyle kilitlenir.
      //
      // 1. Hizmet veren teklif verir  → active, bloke alınır
      // 2. Teklifini GERİ ÇEKER       → cancelled, bloke İADE EDİLİR
      // 3. İlan hâlâ `open` (geri çekme ilan durumuna dokunmaz)
      // 4. İlan sahibi o teklifi seçerse → blokesi yok, iletişim
      //    açılınca ücret TÜKETİLEMEZ → BEDAVA İLETİŞİM
      final l = await yeniIlan();
      await offerCtl.placeOffer(
          listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o = offerCtl.myOfferFor(l.id, p1)!;

      final w = wallets.walletOf(p1);
      final blok0 = w.blocked;
      // ⚠ FARK ÖLÇÜLÜR — bkz. yukarıdaki not.
      expect(blok0, greaterThanOrEqualTo(fee),
          reason: 'teklif blokeyi almalı');

      // Hizmet veren teklifini geri çeker — bloke iade edilir.
      expect(await offerCtl.withdrawOffer(offerId: o.id, actorId: p1), isNull);
      expect(o.status, OfferStatus.cancelled);
      expect(w.blocked, blok0 - fee, reason: 'bloke iade edilmeli');
      expect(l.status, ListingStatus.open, reason: 'ilan açık kalır');

      // ⚠ İlan sahibi geri çekilmiş teklifi SEÇEMEZ.
      final err = await offerCtl.selectOffer(
          listingId: l.id, offerId: o.id, actorId: cust);
      expect(err, isA<InvalidStateError>());
      expect(o.status, OfferStatus.cancelled,
          reason: 'teklif durumu değişmemeli');
      expect(l.status, ListingStatus.open,
          reason: 'ilan providerSelected olmamalı');
      expect(l.selectedOfferId, isNull);
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
      expect(o2.status, OfferStatus.cancelled, reason: 'rakip kapanmalı');

      // İkinci seçim reddedilir; ilk seçim BOZULMAZ.
      final err = await offerCtl.selectOffer(
          listingId: l.id, offerId: o2.id, actorId: cust);
      expect(err, isA<InvalidStateError>());
      expect(l.selectedOfferId, o1.id, reason: 'ilk seçim korunmalı');
      expect(o1.status, OfferStatus.selected);
      expect(o2.status, OfferStatus.cancelled);
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
      expect(l.status, ListingStatus.completed);
      expect(l.selectedOfferId, isNotNull);

      // Veri tutarsızlığı simüle edilir: seçim kaydı kaybolmuş.
      l.selectedOfferId = null;

      final err = await listingCtl.completeWork(l.id, actorId: cust);
      expect(err, isA<InvalidStateError>(),
          reason: 'sessizce geçilmemeli, AÇIK hata dönmeli');
      expect(err!.message.contains('seçilmiş teklif'), isTrue,
          reason: 'hata sebebi anlaşılır olmalı');
      // ⚠ EN ÖNEMLİSİ: ilan TUTARSIZ duruma DÜŞMEDİ.
      expect(l.status, ListingStatus.completed,
          reason: 'denetim geçişten ÖNCE yapılır — durum bozulmadı');
    });

    test('inProgress geçişi KORUNUR (eski kayıt / backend uyumu)', () async {
      // ⚠ Ara durum kaldırılmadı, yalnız KULLANICI ADIMI kaldırıldı.
      // Backend `IN_PROGRESS` göndermeye devam edebilir; o durumdan
      // tamamlamaya geçiş çalışmaya devam etmelidir.
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.providerSelected, ListingStatus.inProgress),
          isTrue);
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.inProgress, ListingStatus.completed),
          isTrue);
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.providerSelected, ListingStatus.completed),
          isTrue,
          reason: 'ara adım olmadan tamamlanabilmeli');
      // ⚠ YENİ (18 Ağu): seçim ilanı DOĞRUDAN tamamladığı için
      // `open → completed` geçişi de açıktır.
      expect(
          ListingStateMachine.canTransition(
              ListingStatus.open, ListingStatus.completed),
          isTrue,
          reason: 'seçim ilanı doğrudan tamamlar');
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

      final wp = wallets.walletOf(p1);
      final wc = wallets.walletOf(cust);
      final pAvail0 = wp.avail, pBlok0 = wp.blocked;
      final cAvail0 = wc.avail, cBlok0 = wc.blocked;

      // HİZMET ALAN açıyor.
      expect(await contactCtl.openShared(o.id, actorId: cust), isNull);
      expect(contactCtl.isOpen(o.id), isTrue);

      // Bedel sağlayıcının BLOKESİNDEN tüketildi.
      expect(wp.blocked, pBlok0 - DomainConfig.contactFee);
      expect(wp.avail, pAvail0, reason: 'kullanılabilir bakiye değişmez');
      // Hizmet alandan HİÇBİR ücret alınmadı.
      expect(wc.avail, cAvail0);
      expect(wc.blocked, cBlok0);

      // İkinci açma ücretsizdir (idempotent).
      expect(await contactCtl.openShared(o.id, actorId: p1), isNull);
      expect(wp.blocked, pBlok0 - DomainConfig.contactFee);
      expect(wc.avail, cAvail0);
    });

    test('COMPLETED ilan iptal/expire/silme YAPILAMAZ; bloke iade edilmez', () async {
      final l = await yeniIlan();
      await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'a');
      final o = offerCtl.myOfferFor(l.id, p1)!;
      await offerCtl.selectOffer(listingId: l.id, offerId: o.id, actorId: cust);
      await listingCtl.startWork(l.id, actorId: cust);
      await listingCtl.completeWork(l.id, actorId: cust);
      final w = wallets.walletOf(p1);
      final a0 = w.avail, b0 = w.blocked;

      expect(await listingCtl.cancel(l.id, actorId: cust), isA<InvalidStateError>());
      expect(await listingCtl.expire(l.id, actorId: cust), isA<InvalidStateError>());
      expect(await listingCtl.delete(l.id, actorId: cust), isA<InvalidStateError>());
      expect(l.status, ListingStatus.completed);
      expect(listingCtl.byId(l.id), isNotNull);
      expect(w.avail, a0);   // tamamlanmış işin blokesi İADE EDİLMEDİ
      expect(w.blocked, b0); // bloke aynen duruyor (iletişim açılınca tüketilecek)
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
      expect(await listingCtl.cancel(l.id, actorId: stranger), isA<UnauthorizedError>());
      expect(await listingCtl.delete(l.id, actorId: p1), isA<UnauthorizedError>());
      expect(l.status, ListingStatus.open);
      expect(listingCtl.byId(l.id), isNotNull);
    });

    test('iptal ve süre dolumu: açılmamış blokeler iade', () async {
      final l1 = await yeniIlan();
      await offerCtl.placeOffer(listingId: l1.id, providerId: p1, amount: 900, note: 'a');
      final a0 = wallets.walletOf(p1).avail;
      expect(await listingCtl.cancel(l1.id, actorId: cust), isNull);
      expect(l1.status, ListingStatus.cancelled);
      expect(wallets.walletOf(p1).avail, a0 + fee);

      final l2 = await yeniIlan();
      await offerCtl.placeOffer(listingId: l2.id, providerId: p2, amount: 700, note: 'b');
      final a2 = wallets.walletOf(p2).avail;
      expect(await listingCtl.expire(l2.id, actorId: cust), isNull);
      expect(l2.status, ListingStatus.expired);
      expect(wallets.walletOf(p2).avail, a2 + fee);
    });

    test('silme: açılmamış bloke iade; tüketilmiş iade edilmez; kayıtlar temizlenir', () async {
      final la = await yeniIlan();
      final lb = await yeniIlan();
      await offerCtl.placeOffer(listingId: la.id, providerId: p1, amount: 900, note: 'a');
      await offerCtl.placeOffer(listingId: lb.id, providerId: p1, amount: 700, note: 'b');
      final oa = offerCtl.myOfferFor(la.id, p1)!;
      await contactCtl.openShared(oa.id, actorId: p1);
      final w = wallets.walletOf(p1);

      final a0 = w.avail, b0 = w.blocked;
      expect(await listingCtl.delete(la.id, actorId: cust), isNull); // tüketilmiş → iade YOK
      expect(w.avail, a0);
      expect(w.blocked, b0);
      expect(offers.forListing(la.id), isEmpty);

      final a1 = w.avail;
      expect(await listingCtl.delete(lb.id, actorId: cust), isNull); // açılmamış → iade VAR
      expect(w.avail, a1 + fee);
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
      final w1 = wallets.walletOf(p1);
      final snapshot = (w1.avail, w1.blocked);
      for (var i = 0; i < 25; i++) {
        await yeniIlan();
      }
      expect(listingCtl.byOwner(cust).length, 25);
      expect((w1.avail, w1.blocked), snapshot);
    });
  });
}
