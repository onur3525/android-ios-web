import '../../domain/config.dart';

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
  /// YORUMUN YAZILDIĞI AN.
  ///
  /// ⚠ DIŞARIDAN VERİLEBİLİR. Eskiden yapıcı her zaman
  /// `DateTime.now()` yazıyordu; sunucudan gelen yorumlar da
  /// OKUNDUKLARI ana damgalanıyordu — yani liste her açıldığında
  /// bütün yorumlar "az önce yazılmış" görünürdü ve 1 günlük yayın
  /// gecikmesi hiç dolmazdı.
  ///
  /// Verilmezse (yeni oluşturulan yorum) şimdiki zaman kullanılır.
  final DateTime createdAt;

  /// ── ⚠ YAYIN DURUMU (API sözleşmesi §14) ──
  ///
  /// Yorum gönderildiğinde `PENDING_PUBLICATION` olur; 1 GÜN sonra
  /// `PUBLISHED` olur ve ancak o zaman hizmet verenin ortalamasına
  /// girer. Admin silerse `ADMIN_DELETED` olur ve ortalama yeniden
  /// hesaplanır.
  ///
  /// ⚠ İSTEMCİ BU ALANI HESAPLAMAZ, SUNUCUDAN OKUR. Yerel depoda
  /// süzme `createdAt` üzerinden yapılıyordu; gerçek API'de karar
  /// sunucunundur — cihaz saati güvenilmezdir.
  ///
  /// Geçiş dönemi: sunucu göndermezse `createdAt` + gecikme ile
  /// türetilir (bkz. `yayinlandiMi`).
  final ReviewStatus? status;

  /// Yayına çıktığı an; `PENDING_PUBLICATION` iken `null`.
  final DateTime? publishedAt;
  Review({
    required this.id,
    required this.listingId,
    required this.offerId,
    required this.providerId,
    required this.authorId,
    required this.stars,
    this.status,
    this.publishedAt,
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Yayında mı?
  ///
  /// ⚠ SUNUCU BİLGİSİ ÖNCELİKLİDİR. Alan gelmediyse yerel gecikme
  /// kuralına düşülür — bu bir KÖPRÜDÜR, kalıcı kural değil.
  bool get yayinlandiMi {
    if (status != null) {
      return status == ReviewStatus.published;
    }
    return DateTime.now()
        .difference(createdAt)
        .compareTo(DomainConfig.yorumYayinGecikmesi) >=
        0;
  }
}

/// Değerlendirme yayın durumu (API sözleşmesi §24).
enum ReviewStatus {
  pendingPublication,
  published,
  adminDeleted;

  static ReviewStatus? fromJson(String? v) => switch (v) {
        'PENDING_PUBLICATION' => ReviewStatus.pendingPublication,
        'PUBLISHED' => ReviewStatus.published,
        'ADMIN_DELETED' => ReviewStatus.adminDeleted,
        _ => null,
      };
}
