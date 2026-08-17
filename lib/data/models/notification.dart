enum NotifType {
  newOffer,        // Yeni teklif (ilan sahibine)
  offerSelected,   // Teklifiniz seçildi (ustaya)
  refund,          // Bloke iade edildi (ustaya)
  contactOpened,   // İletişim açıldı (karşı tarafa)
  newMessage,      // Yeni mesaj (karşı tarafa)
  listingExpired,  // İlan süresi doldu (ilan sahibine)
  accountStatus,   // Hesap onay durumu değişti (hizmet verene)
  categoryRequest, // Kategori talebi karara bağlandı (hizmet verene)
  announcement,    // Yönetici duyurusu (toplu bildirim)
  /// Sunucu yeni bir tip eklediyse uygulama ÇÖKMEZ: bilinmeyen tip
  /// nötr ikon ve başlıkla gösterilir.
  unknown,
}

class AppNotification {
  final String id;
  final String userId; // alıcı hesap id
  final NotifType type;
  final String title;
  final String body;
  final String? refId; // ilgili ilan/teklif id
  bool read;
  final DateTime createdAt;
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.refId,
    this.read = false,
  }) : createdAt = DateTime.now();
}
