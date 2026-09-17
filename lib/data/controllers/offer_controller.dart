import '../../domain/failures.dart';
import '../models/offer.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Teklifler. Finansal sonuç (bloke/iade/tüketim) SUNUCUNUN ya da mock
/// port'un kesin cevabına bağlıdır; istemci sahte başarı göstermez.
class OfferController extends BaseController {
  final OfferPort _offers;
  final ListingPort _listings;
  OfferController(this._offers, this._listings)
      : super([_offers, _listings]);

  List<Offer> offersForListing(String listingId) => _offers.offersForListing(listingId);
  List<Offer> offersByProvider(String providerId) => _offers.offersByProvider(providerId);
  Offer? myOfferFor(String listingId, String providerId) =>
      _offers.myOfferFor(listingId, providerId);
  Offer? byId(String id) => _offers.byId(id);

  Future<DomainError?> loadMine() => runLoad(() => _offers.loadMine());
  Future<DomainError?> loadForListing(String listingId) =>
      runLoad(() => _offers.loadForListing(listingId));

  /// KURAL: Teklif vermek ÜCRETSİZDİR.
  ///
  /// ⚠ ESKİ KURAL KALDIRILDI (16 Eyl): burada "iletişim ücreti kadar
  /// bakiye bloke edilir, yetersiz bakiyede teklif verilemez" yazıyordu.
  /// Uygulama 29 Ağu'dan beri iki taraf için de tamamen ücretsiz; bakiye
  /// ve bloke diye bir şey yok. Kod zaten öyle çalışıyordu, yorum
  /// eskideydi.
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
        },
      );

  /// KURAL: Teklifi yalnız ilan sahibi seçebilir.
  ///
  /// ⚠ "seçilmeyenlerin açılmamış blokeleri iade edilir" KALDIRILDI
  /// (16 Eyl): ücretsiz modelde iade edilecek bir bloke yok.
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

}
