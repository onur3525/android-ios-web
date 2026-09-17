/// TEKLİF DURUMU — nihai dört değer (API sözleşmesi §24).
///
enum OfferStatus { active, selected, expired, closed }

/// Bir ilana verilen teklif. Bir ilan BİRDEN FAZLA hizmet verenden
/// teklif alabilir; her teklifin kendi bloke (escrow) muhasebesi vardır.
class Offer {
  final String id;         // değişmez UUID
  final String listingId;
  final String providerId;
  int amount;
  String note;             // teklif notu — sohbetin ilk mesajı
  OfferStatus status;
  final DateTime createdAt;

  /// İletişim açıldığında bloke YALNIZCA BİR KEZ tüketilir.


  Offer({
    required this.id,
    required this.listingId,
    required this.providerId,
    required this.amount,
    required this.note,
    this.status = OfferStatus.active,


    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
