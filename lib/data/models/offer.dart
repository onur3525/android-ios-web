enum OfferStatus { active, selected, cancelled }

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

  /// Teklif ücretsizdir; verilirken iletişim ücreti kadar bakiye bloke edilir.
  bool escrowBlocked;
  /// İletişim açıldığında bloke YALNIZCA BİR KEZ tüketilir.
  bool escrowConsumed;

  Offer({
    required this.id,
    required this.listingId,
    required this.providerId,
    required this.amount,
    required this.note,
    this.status = OfferStatus.active,
    this.escrowBlocked = true,
    this.escrowConsumed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
