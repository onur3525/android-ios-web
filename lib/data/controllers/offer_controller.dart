import '../../domain/failures.dart';
import '../models/offer.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Teklifler. Finansal sonuç (bloke/iade/tüketim) SUNUCUNUN ya da mock
/// port'un kesin cevabına bağlıdır; istemci sahte başarı göstermez.
class OfferController extends BaseController {
  final OfferPort _offers;
  final ListingPort _listings;
  final WalletPort _wallets;
  OfferController(this._offers, this._listings, this._wallets)
      : super([_offers, _listings, _wallets]);

  List<Offer> offersForListing(String listingId) => _offers.offersForListing(listingId);
  List<Offer> offersByProvider(String providerId) => _offers.offersByProvider(providerId);
  Offer? myOfferFor(String listingId, String providerId) =>
      _offers.myOfferFor(listingId, providerId);
  Offer? byId(String id) => _offers.byId(id);

  Future<DomainError?> loadMine() => runLoad(() => _offers.loadMine());
  Future<DomainError?> loadForListing(String listingId) =>
      runLoad(() => _offers.loadForListing(listingId));

  /// KURAL: Teklif ücretsizdir; iletişim ücreti kadar bakiye bloke edilir.
  /// Yetersiz bakiyede teklif verilemez (hata sunucudan/porttan gelir).
  Future<DomainError?> placeOffer({
    required String listingId,
    required String providerId,
    required int amount,
    required String note,
  }) =>
      runAction(
        'offer:place:$listingId',
        () => _offers.placeOffer(
            listingId: listingId, providerId: providerId, amount: amount, note: note),
        onSuccess: () async {
          await _offers.loadForListing(listingId);
          await _wallets.load(providerId); // bakiye ancak onaydan SONRA tazelenir
        },
      );

  /// KURAL: Teklifi yalnız ilan sahibi seçebilir; seçilmeyenlerin
  /// açılmamış blokeleri iade edilir.
  Future<DomainError?> selectOffer({
    required String listingId,
    required String offerId,
    required String actorId,
  }) =>
      runAction(
        'offer:select:$offerId',
        () => _offers.selectOffer(listingId: listingId, offerId: offerId, actorId: actorId),
        onSuccess: () async {
          await _offers.loadForListing(listingId);
          await _listings.loadOne(listingId);
        },
      );

  /// KURAL: Yalnız kendi aktif teklifi geri çekilebilir; açılmış ücret
  /// iade edilmez.
  Future<DomainError?> withdrawOffer({
    required String offerId,
    required String actorId,
  }) =>
      runAction(
        'offer:withdraw:$offerId',
        () => _offers.withdrawOffer(offerId: offerId, actorId: actorId),
        onSuccess: () async {
          await _offers.loadMine();
          await _wallets.load(actorId); // iade sunucudan okunur
        },
      );
}
