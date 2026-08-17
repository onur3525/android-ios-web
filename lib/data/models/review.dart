/// Değerlendirme — HTML kuralı: yalnız hizmeti alan müşteri,
/// yalnız TAMAMLANMIŞ işte, teklif başına BİR KEZ; değiştirilemez.
class Review {
  final String id;
  final String listingId;
  final String offerId;
  final String providerId; // değerlendirilen hizmet veren
  final String authorId;   // ilan sahibi müşteri
  final int stars;         // 1..5
  final String text;
  final DateTime createdAt;
  Review({
    required this.id,
    required this.listingId,
    required this.offerId,
    required this.providerId,
    required this.authorId,
    required this.stars,
    required this.text,
  }) : createdAt = DateTime.now();
}
