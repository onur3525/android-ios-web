import 'package:flutter_test/flutter_test.dart';

import 'support/mock_wiring.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/repositories/listing_repository.dart';
import 'package:hizmetcep/data/repositories/wallet_repository.dart';
import 'package:hizmetcep/data/services/listing_expiry_service.dart';
import 'package:hizmetcep/domain/config.dart';
import 'package:hizmetcep/domain/failures.dart';

void main() {
  late WalletRepository wallets;
  late ListingRepository listings;
  late OfferController offerCtl;
  late ContactController contactCtl;
  late ListingController listingCtl;
  late ListingExpiryService expiry;
  const fee = DomainConfig.contactFee;
  const p1 = 'usta-1', p2 = 'usta-2', cust = 'musteri-1';

  late MockWiring w0;
  setUp(() {
    w0 = MockWiring();
    wallets = w0.wallets;
    listings = w0.listings;
    offerCtl = w0.offerCtl;
    contactCtl = w0.contactCtl;
    listingCtl = w0.listingCtl;
    // Süre kuralı servisi port üzerinden çalışır (mock modda istemcide).
    expiry = ListingExpiryService(listings, w0.offerPort);
  });

  // Yayın anı — GERÇEK ZAMANA GÖRE KAYAR.
  //
  // Sabit bir takvim tarihi (ör. 2026-01-01) kullanılamaz: `placeOffer`
  // teklif kabulünü duvar saatiyle denetler
  // (`!DateTime.now().isBefore(l.expiresAt)`). Sabit tarih geçmişte
  // kaldığında üretilen her ilan "süresi dolmuş" sayılır; teklif
  // oluşmaz, bloke edilmez ve `myOfferFor` null döner.
  //
  // 1 saat önce yayınlanmış varsayılır: ilan hâlâ açıktır (30 saatlik
  // ömrün 31 saati kalmıştır) ve süre dolumu testleri t0'a göre
  // hesaplandığı için deterministik kalır.
  final t0 = DateTime.now().subtract(const Duration(hours: 1)); // yayın anı
  Listing ilan() => listings.create(
      ownerId: cust, title: 'Kombi Bakımı', location: 'Konak, İzmir',
      desc: 'Kombi bakımı yapılacak beş kelime tamam', createdAt: t0);

  test('expiresAt = createdAt + 30 saat', () async {
    final l = ilan();
    expect(l.expiresAt, t0.add(const Duration(hours: 30)));
    expect(DomainConfig.listingLifetime, const Duration(hours: 30));
  });

  // ⚠ Yaşam süresi 30 SAAT: sınırın hemen altı 29:59'dur.
  test('29 saat 59 dakikada ilan OPEN kalır', () async {
    final l = ilan();
    final n = expiry.sweep(now: t0.add(const Duration(hours: 29, minutes: 59)));
    expect(n, 0);
    expect(l.status, ListingStatus.active);
  });

  test('30 saatte EXPIRED olur ve Açık listesinden çıkar / Süresi Dolan filtresine girer', () async {
    final l = ilan();
    final n = expiry.sweep(now: t0.add(const Duration(hours: 30)));
    expect(n, 1);
    expect(l.status, ListingStatus.expired);
    // ⚠ Açık sekmesi: YAŞAYAN ve teklif seçilmemiş ilanlar (§24).
    final openTab = listings.byOwner(cust).where(
        (x) => x.status == ListingStatus.active && !x.isTamamlanmisIs);
    expect(openTab, isEmpty);
    // Süresi Dolan sekmesi filtresi → yalnız burada görünür
    final expiredTab =
        listings.byOwner(cust).where((x) => x.status == ListingStatus.expired);
    expect(expiredTab.map((x) => x.id), [l.id]);
  });

  test('süre dolduğunda açılmamış blokeler otomatik İADE edilir', () async {
    final l = ilan();
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
    await offerCtl.placeOffer(listingId: l.id, providerId: p2, amount: 800, note: 'n');
    final a1 = wallets.walletOf(p1).avail;
    final a2 = wallets.walletOf(p2).avail;
    expiry.sweep(now: t0.add(const Duration(hours: 33)));
    expect(wallets.walletOf(p1).avail, a1 + fee);
    expect(wallets.walletOf(p2).avail, a2 + fee);
    expect(offerCtl.myOfferFor(l.id, p1)!.status, OfferStatus.closed);
  });

  test('iletişimi açılmış (tüketilmiş) teklif için KESİNLİKLE iade yapılmaz', () async {
    final l = ilan();
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
    final o = offerCtl.myOfferFor(l.id, p1)!;
    await contactCtl.openShared(o.id, actorId: cust); // bloke tüketildi
    final w = wallets.walletOf(p1);
    final a0 = w.avail, b0 = w.blocked;
    expiry.sweep(now: t0.add(const Duration(hours: 40)));
    expect(w.avail, a0);
    expect(w.blocked, b0);
  });

  test('aynı ilan için süre dolma işlemi bir kez çalışır; çift iade oluşmaz', () async {
    final l = ilan();
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 900, note: 'n');
    final w = wallets.walletOf(p1);
    expect(expiry.sweep(now: t0.add(const Duration(hours: 30))), 1);
    final afterFirst = w.avail;
    expect(expiry.sweep(now: t0.add(const Duration(hours: 50))), 0); // tekrar işlenmez
    expect(w.avail, afterFirst); // ikinci iade YOK
    expect(l.status, ListingStatus.expired);
  });

  test('süresi dolmuş ilana yeni teklif verilemez (sweep koşmamış olsa bile)', () async {
    final l = listings.create(
        ownerId: cust, title: 'Boya', location: 'Konak, İzmir',
        desc: 'Boya işi var evet beş kelime',
        createdAt: DateTime.now().subtract(const Duration(hours: 33)));
    // Durum hâlâ open (servis henüz koşmadı) — saat kuralı yine de engeller
    expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 1, note: 'n'),
        isA<ListingClosedError>());
    // Servis koştuktan sonra da (expired) engel sürer
    expiry.sweep();
    expect(l.status, ListingStatus.expired);
    expect(await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 1, note: 'n'),
        isA<ListingClosedError>());
  });

  test('COMPLETED, CANCELLED ve silinmiş ilanlar expire edilmez', () async {
    // completed
    final lc = ilan();
    await offerCtl.placeOffer(listingId: lc.id, providerId: p1, amount: 900, note: 'n');
    await offerCtl.selectOffer(
        listingId: lc.id, offerId: offerCtl.myOfferFor(lc.id, p1)!.id, actorId: cust);
    // ⚠ `startWork`/`completeWork` KALDIRILDI (API sözleşmesi §11).
    // Seçim ilanı zaten tamamlanmış duruma getirir.
    // cancelled
    final lx = ilan();
    await listingCtl.delete(lx.id, actorId: cust);
    // silinmiş
    final ld = ilan();
    await listingCtl.delete(ld.id, actorId: cust);
    final w = wallets.walletOf(p1);
    final a0 = w.avail, b0 = w.blocked;

    expect(expiry.sweep(now: t0.add(const Duration(hours: 100))), 0);
    // ⚠ Tamamlanmış işe süre dolumu DOKUNMAZ; ilan ACTIVE kalır ama
    // tamamlanmışlık ilişkisi korunur (§24).
    expect(lc.isTamamlanmisIs, isTrue);
    expect(lx.status, ListingStatus.userDeleted);
    expect(listings.byId(ld.id), isNull);
    expect(w.avail, a0); // hiçbir yeni iade oluşmadı
    expect(w.blocked, b0);
  });
}
