import '../../domain/failures.dart';
import '../models/listing.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// İlanlar. İş kuralları mock modda MockListingPort'ta, API modunda
/// sunucudadır; controller yalnız akışı ve durumu yönetir.
class ListingController extends BaseController {
  final ListingPort _listings;
  ListingController(this._listings) : super([_listings]);

  List<Listing> byOwner(String ownerId) => _listings.byOwner(ownerId);
  List<Listing> get all => _listings.all;
  Listing? byId(String id) => _listings.byId(id);

  /// İLAN NUMARASIYLA ARAMA — kullanıcı/admin referansı.
  ///
  /// ⚠ İlişki anahtarı DEĞİL, yalnız arama. Teklif, mesaj, ödeme ve
  /// şikâyet bağları `id` (UUID) üzerinden kalır.
  Listing? byIlanNo(String ilanNo) => _listings.byIlanNo(ilanNo);

  // ── yükleme (pull-to-refresh ve açılış) ──
  Future<DomainError?> loadMine(String ownerId) =>
      runLoad(() => _listings.loadMine(ownerId));
  Future<DomainError?> loadAvailable({String? category, String? district}) =>
      runLoad(() => _listings.loadAvailable(category: category, district: district));
  Future<DomainError?> loadOne(String id) => runLoad(() => _listings.loadOne(id));

  /// KURAL: Müşteri ücretsiz ve sınırsız ilan verebilir.
  Future<({Listing? listing, DomainError? error})> publish({
    required String ownerId,
    required String title,
    required String location,
    required String desc,
    List<String>? photoPaths,
    // ⚠ İsteğe bağlı işin yapılma zamanı; `null` = seçim yok.
    IsZamani? isZamani,
  }) async {
    if (isBusy('publish')) {
      return (listing: null, error: const ValidationError('İlan yayınlanıyor — lütfen bekleyin'));
    }
    ({Listing? listing, DomainError? error}) result =
        (listing: null, error: const ValidationError('İlan oluşturulamadı'));
    await runAction('publish', () async {
      result = await _listings.publish(
          ownerId: ownerId, title: title, location: location,
          desc: desc, photoPaths: photoPaths, isZamani: isZamani);
      return result.error;
    }, onSuccess: () => _listings.loadMine(ownerId));
    return result;
  }

  /// ⚠ [reason] silme/iptal GEREKÇESİDİR ve yönetime iletilir.

  Future<DomainError?> expire(String listingId, {required String actorId}) =>
      runAction('listing:expire:$listingId',
          () => _listings.expire(listingId, actorId: actorId));

  Future<DomainError?> delete(String listingId,
          {required String actorId, String? reason}) =>
      runAction('listing:delete:$listingId',
          () => _listings.delete(listingId, actorId: actorId, reason: reason),
          onSuccess: () => _listings.loadMine(actorId));
}
