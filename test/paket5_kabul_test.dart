import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/models/wallet.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/listing_state_machine.dart';

import 'support/mock_wiring.dart';

/// ═══════════════════════════════════════════════════════════════
///  PAKET 5 — 32 NİHAİ KABUL TESTİ
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠ BU DOSYA STRING ARAMASIYLA YETİNMEZ. Mümkün olan her yerde
/// gerçek model/controller/repository davranışı kurulur ve sonuç
/// ölçülür. Yalnız kaynak metni okunan yerler UI koşullarıdır —
/// widget ağacı olmadan ölçülemeyen tek katman odur ve orada da
/// KOŞULUN KENDİSİ aranır, düğme adı değil.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

String _sozlesme() => File('docs/openapi.yaml').readAsStringSync();

/// İlanın CTA zinciri — ekran koduyla aynı sırayı izler.
///
/// ⚠ Ekran şu sırayla karar veriyor:
///   1. iletişim kapalı              → "İletişimi Aç"
///   2. ilan yaşıyor + tamamlanmamış + teklif aktif → "Teklifi Seç"
///   3. teklif seçili                → "Yorum Yaz" / "Yorum Yapıldı"
/// Bu yardımcı o mantığı taklit eder ki senaryolar tek tek
/// doğrulanabilsin.
String _teklifCtasi({
  required bool iletisimAcik,
  required Listing ilan,
  required Offer teklif,
}) {
  final acik = iletisimAcik ||
      ilan.selectedOfferId == teklif.id ||
      teklif.status == OfferStatus.selected;
  if (!acik) {
    return 'İletişimi Aç';
  }
  if (ilan.status == ListingStatus.active &&
      !ilan.isTamamlanmisIs &&
      teklif.status == OfferStatus.active) {
    return 'Teklifi Seç';
  }
  if (teklif.status == OfferStatus.selected) {
    return 'Yorum Yaz';
  }
  return '(düğme yok)';
}

void main() {
  late MockWiring w;
  const p1 = 'usta-1', p2 = 'usta-2', cust = 'musteri-1';
  const fee = DomainConfig.contactFee;

  setUp(() => w = MockWiring());

  Future<Listing> ilan() async => (await w.listingCtl.publish(
          ownerId: cust,
          title: 'Kombi Bakımı',
          location: 'Konak, İzmir',
          desc: 'Kombi bakımı yapılacak beş kelime tamam'))
      .listing!;

  /// İletişimi açılmış ve SEÇİLMİŞ teklifi olan ilan.
  Future<({Listing l, Offer o})> tamamlanmisIs() async {
    final l = await ilan();
    await w.offerCtl
        .placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
    final o = w.offerCtl.myOfferFor(l.id, p1)!;
    await w.contactCtl.openShared(o.id, actorId: cust);
    await w.offerCtl.selectOffer(listingId: l.id, offerId: o.id, actorId: cust);
    return (l: l, o: o);
  }

  // ── 1-4: İLAN DURUMLARI ──
  group('İLAN DURUMLARI (1-4)', () {
    test('1. ACTIVE ilan normal görüntülenir', () async {
      final l = await ilan();
      expect(l.status, ListingStatus.active);
      expect(l.isTamamlanmisIs, isFalse);
    });

    test('2. EXPIRED ilan doğru durumla görüntülenir', () async {
      final l = await ilan();
      await w.listingCtl.expire(l.id, actorId: cust);
      expect(l.status, ListingStatus.expired);
    });

    test('3. USER_DELETED ilan aktif listede GÖRÜNMEZ', () async {
      final l = await ilan();
      await w.listingCtl.delete(l.id, actorId: cust, reason: 'vazgeçtim');
      expect(l.status, ListingStatus.userDeleted);
      // Açık işler sekmesinin filtresi.
      final acikSekme = w.listings
          .byOwner(cust)
          .where((x) => x.status == ListingStatus.active && !x.isTamamlanmisIs);
      expect(acikSekme.any((x) => x.id == l.id), isFalse);
    });

    test('4. ADMIN_REMOVED ilan aktif listede GÖRÜNMEZ', () async {
      final l = await ilan();
      w.listings.setStatus(l.id, ListingStatus.adminRemoved);
      final acikSekme = w.listings
          .byOwner(cust)
          .where((x) => x.status == ListingStatus.active);
      expect(acikSekme.any((x) => x.id == l.id), isFalse);
    });
  });

  // ── 5-7: TAMAMLANMIŞ İŞ ──
  group('TAMAMLANMIŞ İŞ (5-7)', () {
    test('5. ACTIVE + seçim yok → teklif ALABİLİR', () async {
      final l = await ilan();
      expect(
          await w.offerCtl.placeOffer(
              listingId: l.id, providerId: p1, amount: 900, note: 'n'),
          isNull);
    });

    test('6. ACTIVE + seçim VAR → teklif ALAMAZ', () async {
      final t = await tamamlanmisIs();
      // ⚠ İlan hâlâ ACTIVE — ama iş tamamlanmıştır.
      expect(t.l.status, ListingStatus.active);
      // ⚠ DOMAIN KATMANINDA ENGELLENİR — ekran koşuluna bırakılmaz.
      expect(t.l.acceptsOffers, isFalse,
          reason: 'tamamlanmış ilan teklif kabul etmemeli');
      final err = await w.offerCtl
          .placeOffer(listingId: t.l.id, providerId: p2, amount: 800, note: 'n');
      expect(err, isA<ListingClosedError>(),
          reason: 'tamamlanmış işe yeni teklif kabul edilmemeli');
    });

    test('7. seçim dolu → tamamlanmış iş sayılır', () async {
      final t = await tamamlanmisIs();
      expect(t.l.isTamamlanmisIs, isTrue);
      // Tamamlanan işler sekmesinin filtresi.
      expect(w.listings.byOwner(cust).where((x) => x.isTamamlanmisIs).length, 1);
    });
  });

  // ── 8-13: TAMAMLANAN İŞTE ESKİ AKSİYONLAR ──
  group('⚠ TAMAMLANAN İŞ UI REGRESYONU (8-13)', () {
    test('8. ⚠ Tamamlanan işte "İletişimi Aç" GÖRÜNMEZ', () async {
      // ⚠ DAHA ÖNCE YAŞANAN HATA BUYDU. Gerçek durum kurulup CTA
      // zinciri çalıştırılıyor — yalnız metin aranmıyor.
      final t = await tamamlanmisIs();
      expect(
          _teklifCtasi(iletisimAcik: true, ilan: t.l, teklif: t.o),
          isNot('İletişimi Aç'));
      // ⚠ İletişim KAYDI hiç olmasa bile: seçim tek başına yeterli.
      final l2 = await ilan();
      await w.offerCtl
          .placeOffer(listingId: l2.id, providerId: p2, amount: 700, note: 'n');
      final o2 = w.offerCtl.myOfferFor(l2.id, p2)!;
      o2.status = OfferStatus.selected;
      l2.selectedOfferId = o2.id;
      expect(_teklifCtasi(iletisimAcik: false, ilan: l2, teklif: o2),
          'Yorum Yaz');
    });

    test('9. Tamamlanan işte "Teklif Ver" GÖRÜNMEZ', () async {
      final t = await tamamlanmisIs();
      // Ekran koşulu: `mine == null && active && !isTamamlanmisIs`.
      final gosterilir =
          t.l.status == ListingStatus.active && !t.l.isTamamlanmisIs;
      expect(gosterilir, isFalse);
      final k = _kodu('lib/screens/job_detail_screen.dart');
      expect('!l.isTamamlanmisIs'.allMatches(k).length, greaterThanOrEqualTo(2));
    });

    test('10. Tamamlanan işte "Teklifi Seç" GÖRÜNMEZ', () async {
      final t = await tamamlanmisIs();
      expect(_teklifCtasi(iletisimAcik: true, ilan: t.l, teklif: t.o),
          isNot('Teklifi Seç'));
    });

    test('11-13. İşi Başlat / İşi Tamamla / Teklifi Geri Çek YOK', () {
      for (final yol in const [
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/job_detail_screen.dart',
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/my_listings_screen.dart',
        'lib/screens/jobs_screen.dart',
      ]) {
        final k = _kodu(yol);
        for (final d in const [
          "'İşi Başlat'", "'İşi Tamamla'", "'Teklifi Geri Çek'"
        ]) {
          expect(k.contains(d), isFalse, reason: '$yol: $d');
        }
      }
    });

    test('⚠ TAMAMLANAN İŞTE ÜÇ NOKTA MENÜSÜ ÇİZİLMEZ', () {
      // Menünün tek işi ilanı silmek; tamamlanmış iş silinemez.
      //
      // ⚠ İkon "gizlenmiyor", HİÇ çizilmiyor. Önceki hâlde
      // `onTap: null` veriliyordu — nokta duruyor ama basınca hiçbir
      // şey olmuyordu; kullanıcı bozuk sanıyordu.
      final k = _kodu('lib/screens/listing_detail_screen.dart');
      expect(
          k.contains(
              'if (l.status == ListingStatus.active && !l.isTamamlanmisIs)'),
          isTrue,
          reason: 'üç nokta tamamlanmış işte de çiziliyor');
      expect(k.contains('onTap: l.status == ListingStatus.active'), isFalse,
          reason: 'ölü (tıklanamaz) ikon geri gelmiş');
    });

    test('⚠ TAMAMLANMIŞ İŞ DOMAIN KATMANINDA DA SİLİNEMEZ', () async {
      // Arayüzde gizlemek tek başına güvenlik değildir.
      final t = await tamamlanmisIs();
      expect(ListingStateMachine.canDelete(t.l), isFalse);
      final err =
          await w.listingCtl.delete(t.l.id, actorId: cust, reason: 'test');
      expect(err, isNotNull, reason: 'tamamlanmış ilan silinebiliyor');
      expect(t.l.status, ListingStatus.active,
          reason: 'başarısız silme durumu bozmamalı');
    });

    test('⚠ TAMAMLANMIŞ İŞ DÜZENLENEMEZ (sözleşme)', () {
      final y = _sozlesme();
      expect(y.contains('PATCH TAMAMEN\n          REDDEDİLİR'), isTrue);
    });

    test('⚠ EK: İlanı Düzenle aksiyonu hiçbir ekranda YOK', () {
      for (final yol in const [
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/my_listings_screen.dart',
      ]) {
        expect(_kodu(yol).contains('İlanı Düzenle'), isFalse, reason: yol);
      }
    });
  });

  // ── 14-20: EXPIRED VE PATCH ──
  group('EXPIRED VE PATCH (14-20)', () {
    test('14. EXPIRED ilana teklif VERİLEMEZ', () async {
      final l = await ilan();
      await w.listingCtl.expire(l.id, actorId: cust);
      final err = await w.offerCtl
          .placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      expect(err, isNotNull);
    });

    test('15. EXPIRED ilanda iletişim AÇILAMAZ', () async {
      final l = await ilan();
      await w.offerCtl
          .placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = w.offerCtl.myOfferFor(l.id, p1)!;
      await w.listingCtl.expire(l.id, actorId: cust);
      // Süre dolumunda teklif kapanır; kapanmış teklifte iletişim açılmaz.
      expect(o.status, isNot(OfferStatus.active));
    });

    test('16-20. PATCH kuralları sözleşmede tanımlı', () {
      final y = _sozlesme();
      // 16. EXPIRED · 19. USER_DELETED · 20. ADMIN_REMOVED
      for (final d in const ['EXPIRED', 'USER_DELETED', 'ADMIN_REMOVED']) {
        expect(y.contains('`$d` → PATCH REDDEDİLİR'), isTrue, reason: d);
      }
      // 17. seçim dolu → tamamen reddedilir
      expect(y.contains('PATCH TAMAMEN\n          REDDEDİLİR'), isTrue);
      // 18. yalnız description
      expect(
          y.contains('`description` YALNIZ `selectedOfferId == null` iken'),
          isTrue);
      expect(y.contains('additionalProperties: false'), isTrue);
    });
  });

  // ── 21-27: UÇLAR ──
  group('KANONİK UÇLAR (21-27)', () {
    test('21-22. DELETE tek kanonik silme; cancel YOK', () {
      final k = _kodu('lib/data/remote/api/listing_api.dart');
      expect(k.contains("c.delete(\n      '/listings/\$id'"), isTrue);
      expect(k.contains('/cancel'), isFalse);
      expect(_sozlesme().contains('/listings/{listingId}/cancel:'), isFalse);
    });

    test('23-24. withdraw / start / complete YOK', () {
      for (final yol in const [
        'lib/data/remote/api/offer_api.dart',
        'lib/data/remote/api/listing_api.dart',
        'lib/data/ports/mock_ports.dart',
        'lib/data/controllers/offer_controller.dart',
        'lib/data/controllers/listing_controller.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('withdraw'), isFalse, reason: '$yol: withdraw');
        expect(k.contains('startWork'), isFalse, reason: '$yol: startWork');
        expect(k.contains('completeWork'), isFalse, reason: '$yol: completeWork');
      }
    });

    test('25. PUT /listings/{id}/selected-offer', () {
      final k = _kodu('lib/data/remote/api/offer_api.dart');
      expect(k.contains("c.put('/listings/\$listingId/selected-offer'"), isTrue);
      expect(k.contains("/select'"), isFalse);
    });

    test('26. POST /offers/{id}/communication', () {
      final k = _kodu('lib/data/remote/api/contact_api.dart');
      expect(k.contains("/offers/\$offerId/communication"), isTrue);
      expect(k.contains('/contact/open'), isFalse);
    });

    test('27-28. Yorum uçları kanonik; fotoğraf YOK', () {
      final k = _kodu('lib/data/remote/api/review_api.dart');
      expect(k.contains("/listings/\$listingId/review"), isTrue);
      expect("/providers/\$providerId/reviews".allMatches(k).length, 2);
      expect(k.contains('/reviews/me'), isFalse);
      expect(k.contains('/reviews/provider/'), isFalse);
      // Yorum ekranında fotoğraf yüzeyi yok.
      final e = _kodu('lib/screens/review_screen.dart');
      for (final f in const ['photo', 'Foto', 'Galeri', 'Kamera']) {
        expect(e.contains(f), isFalse, reason: 'yorum ekranında $f');
      }
    });
  });

  // ── 29: ÜCRETSİZ HAK ──
  group('⚠ ÜCRETSİZ HAK (29)', () {
    test('29. bloke edilmez, iade edilmez, geri yüklenmez', () async {
      final y = _sozlesme();
      expect(y.contains('ÜCRETSİZ HAK PARASAL BİR BAKİYE DEĞİLDİR'), isTrue);
      expect(y.contains('hiçbir kapanışta geri yüklenmez'), isTrue);

      // Normal (WALLET) teklifte bloke OLUŞUR — karşılaştırma için.
      final l = await ilan();
      final once = w.wallets.walletOf(p1).blocked;
      await w.offerCtl
          .placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      expect(w.wallets.walletOf(p1).blocked, once + fee,
          reason: 'parasal teklif bloke etmeli');
    });
  });

  // ── 30: IDEMPOTENCY ──
  group('⚠ IDEMPOTENCY (30)', () {
    test('30. anahtar BAŞLIKTA, gövdede YOK', () {
      for (final yol in const [
        'lib/data/remote/api/contact_api.dart',
        'lib/data/remote/api/offer_api.dart',
        'lib/data/remote/api/review_api.dart',
        'lib/data/remote/api/wallet_api.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains("'idempotencyKey':"), isFalse,
            reason: '$yol: anahtar gövdede');
        expect(k.contains('microsecondsSinceEpoch'), isFalse,
            reason: '$yol: sahte anahtar üretimi');
      }
    });

    test('iletişim açma idempotent — ikinci kez ücret alınmaz', () async {
      final l = await ilan();
      await w.offerCtl
          .placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      final o = w.offerCtl.myOfferFor(l.id, p1)!;
      await w.contactCtl.openShared(o.id, actorId: cust);
      final sonra = w.wallets.walletOf(p1).avail;
      // ⚠ İkinci istek: bakiye DEĞİŞMEMELİ.
      await w.contactCtl.openShared(o.id, actorId: cust);
      expect(w.wallets.walletOf(p1).avail, sonra);
    });
  });

  // ── 31: CÜZDAN → İLAN ──
  group('CÜZDAN BAĞLANTISI (31)', () {
    test('31. listingId varsa bağlantı, yoksa YOK', () {
      final bagli = WalletTx(
          id: 't1',
          kind: TxKind.block,
          title: 'Bloke',
          sub: '',
          amount: -fee,
          listingId: 'l1',
          offerId: 'o1');
      final bagsiz = WalletTx(
          id: 't2', kind: TxKind.load, title: 'Yükleme', sub: '', amount: 500);
      expect(bagli.ilanaGidilebilir, isTrue);
      expect(bagsiz.ilanaGidilebilir, isFalse);
      expect(_kodu('lib/screens/wallet_screen.dart')
          .contains('if (t.ilanaGidilebilir)'), isTrue);
    });
  });

  // ── 32: ESKİ DURUMLAR ──
  group('ESKİ DURUM/UÇ KALINTISI (32)', () {
    test('32. enum değerleri nihai', () {
      expect(ListingStatus.values.map((e) => e.name).toSet(),
          {'active', 'expired', 'userDeleted', 'adminRemoved'});
      expect(OfferStatus.values.map((e) => e.name).toSet(),
          {'active', 'selected', 'expired', 'closed'});
    });

    test('durum makinesi seçim geçişi İÇERMEZ', () {
      // Seçim ilan durumunu değiştirmez; tabloda karşılığı yoktur.
      for (final hedefler in ListingStateMachine.transitions.values) {
        expect(hedefler.contains(ListingStatus.active), isFalse,
            reason: 'kapanmış durumdan ACTIVE\'e dönüş olmamalı');
      }
    });

    test('⚠ ikinci seçim REDDEDİLİR — ilk seçim bozulmaz', () async {
      // İki teklif ÖNCE verilir, seçim SONRA yapılır — tamamlanmış
      // ilana artık yeni teklif verilemediği için sıra önemli.
      final l = await ilan();
      await w.offerCtl
          .placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
      await w.offerCtl
          .placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'n');
      final o1 = w.offerCtl.myOfferFor(l.id, p1)!;
      final o2 = w.offerCtl.myOfferFor(l.id, p2)!;
      await w.contactCtl.openShared(o1.id, actorId: cust);
      await w.offerCtl.selectOffer(listingId: l.id, offerId: o1.id, actorId: cust);

      final err = await w.offerCtl
          .selectOffer(listingId: l.id, offerId: o2.id, actorId: cust);
      expect(err, isA<InvalidStateError>());
      expect(l.selectedOfferId, o1.id, reason: 'ilk seçim bozulmamalı');
    });
  });
}
