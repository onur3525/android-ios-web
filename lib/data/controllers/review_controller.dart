import '../../domain/failures.dart';
import '../models/review.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Değerlendirmeler. Kurallar mock modda port'ta, API modunda sunucudadır.
/// Silinen (soft-deleted) yorumlar listelenmez ve ortalamaya girmez.
class ReviewController extends BaseController {
  final ReviewPort _reviews;
  ReviewController(this._reviews) : super([_reviews]);

  Review? byOffer(String offerId) => _reviews.byOffer(offerId);
  Review? byTalep(String talepId) => _reviews.byTalep(talepId);
  List<Review> byProvider(String providerId) => _reviews.byProvider(providerId);

  /// Müşterinin YAZDIĞI değerlendirmeler — bkz. depo notu.
  List<Review> byAuthor(String authorId) => _reviews.byAuthor(authorId);
  double? averageOf(String providerId) => _reviews.averageOf(providerId);

  Future<DomainError?> loadForProvider(String providerId) =>
      runLoad(() => _reviews.loadForProvider(providerId));

  /// ⚠ İKİ MOD: `listingId`+`offerId` (normal akış) YA DA `talepId`
  /// ("Bul" doğrudan teklif akışı) — bkz. `ReviewPort.submit` notu.
  Future<DomainError?> submit({
    String? listingId,
    String? offerId,
    String? talepId,
    required String actorId,
    required int stars,
    required String text,
  }) =>
      runAction(
        'review:${offerId ?? talepId}',
        () => _reviews.submit(
            listingId: listingId, offerId: offerId, talepId: talepId,
            actorId: actorId, stars: stars, text: text),
      );
}
