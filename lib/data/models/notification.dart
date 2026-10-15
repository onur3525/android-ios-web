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
  newListing,      // Yeni iş ilanı — eşleşen hizmet verene (15 Eki)
  // ── ⚠ "DOĞRUDAN TEKLİF İSTE" — YENİ TÜRLER ──
  //
  // Mevcut türlerle KARIŞTIRILMADI: bu akış `Offer`/`Listing`den
  // AYRI bir modele (`TeklifTalebi`) dayanır; `newOffer` vb. genel
  // ilan sistemine aittir.
  teklifTalebiGeldi,     // Yeni doğrudan talep (hizmet verene)
  teklifVerildi,         // Teklif geldi (hizmet alana)
  teklifSecildi,         // Teklif kabul edildi, iş aktif (hizmet verene)
  teklifReddedildi,      // Teklif reddedildi (hizmet verene)
  teklifSuresiDoldu,     // 30 saat doldu (hizmet verene)
  teklifIsiTamamlandi,   // İş tamamlandı işaretlendi (hizmet alana)
  teklifYeniMesaj,       // Teklif talebi sohbetinde yeni mesaj (karşı tarafa)
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

  /// Bildirimin GERÇEK oluşturulma zamanı.
  ///
  /// ⚠ DÜZELTİLDİ (11 Eki, kullanıcı bulgusu): alan her zaman
  /// `DateTime.now()` ile dolduruluyordu; sunucunun gönderdiği
  /// `createdAt` okunmuyor, web deneme deposu da zamanı saklamıyordu.
  /// Sonuç: her bildirim, liste yüklendiği an gelmiş gibi "x dk"
  /// görünüyordu (30 saati geçmiş bir teklif "7 dk önce" çıkıyordu).
  /// Verilmezse yeni oluşturulan bildirim için "şimdi" kullanılır.
  final DateTime createdAt;
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.refId,
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
