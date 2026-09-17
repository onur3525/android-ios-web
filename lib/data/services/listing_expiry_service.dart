import '../../domain/listing_state_machine.dart';
import '../models/offer.dart';
import '../models/listing.dart';
import '../ports/mock_ports.dart';
import '../models/notification.dart';
import '../repositories/listing_repository.dart';
import '../repositories/notification_repository.dart';

/// İLAN SÜRESİ KURALI — sistem servisi (UI geri sayımından bağımsız).
///
/// 30 saati dolan ve hâlâ OPEN olan ilanları EXPIRED durumuna taşır;
/// iletişimi açılmamış tüm teklif blokelerini sahiplerine iade eder
/// (tüketilmiş ücretler ASLA iade edilmez — teklif kuralı).
///
/// Tek sefer garantisi: yalnız OPEN ilanlar taranır (EXPIRED tekrar
/// işlenmez) ve iade, teklif başına escrowBlocked bayrağıyla idempotenttir;
/// bu nedenle çift iade oluşamaz. Durum geçişi ListingStateMachine'e uyar
/// (open → expired izinli tek kaynaktır).
class ListingExpiryService {
  final ListingRepository _listings;
  final MockOfferPort _offerPort;
  final NotificationRepository? _notifs;

  /// YALNIZ MOCK MOD: API modunda 30 saat kuralını sunucudaki zamanlayıcı
  /// işler; bu servis kurulmaz.
  ListingExpiryService(this._listings, this._offerPort,
      {NotificationRepository? notifications})
      : _notifs = notifications;

  /// Süresi geçmiş açık ilanları işler; işlenen ilan sayısını döndürür.
  /// Uygulama açılışında (geçmişte dolmuşlar dahil) ve periyodik çağrılır.
  int sweep({DateTime? now}) {
    final t = now ?? DateTime.now();
    var n = 0;
    for (final l in _listings.all) {
      if (l.status != ListingStatus.active) continue; // completed/cancelled/expired dokunulmaz
      if (t.isBefore(l.expiresAt)) continue;        // 31s59dk → hâlâ açık
      if (!ListingStateMachine.canTransition(
          l.status, ListingStatus.expired)) continue;
      _offerPort.cancelAllForListing(l.id,
          reason: 'İlan süresi doldu', yeniDurum: OfferStatus.expired);
      _listings.setStatus(l.id, ListingStatus.expired);
      _notifs?.push(
          userId: l.ownerId, type: NotifType.listingExpired, refId: l.id,
          title: 'İlan süreniz doldu',
          body: '"${l.title}" ilanı 30 saatlik süre sonunda otomatik kapandı.');
      n++;
    }
    return n;
  }
}
