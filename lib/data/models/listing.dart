import '../../domain/config.dart';

/// İlan yaşam döngüsü.
enum ListingStatus {
  open,             // teklif kabul ediyor
  providerSelected, // müşteri bir teklifi seçti
  inProgress,       // iş başladı
  completed,        // iş tamamlandı
  cancelled,        // müşteri iptal etti / ilan silindi
  expired,          // süre doldu
}


class Listing {
  final String id;       // değişmez UUID

  /// ── KULLANICIYA GÖSTERİLEN İLAN NUMARASI ──
  ///
  /// ⚠ `id` İLE KARIŞTIRILMAZ. `id` sistemin teknik kimliğidir
  /// (UUID) ve teklif, mesaj, ödeme, şikâyet ilişkileri DAİMA onun
  /// üzerinden kurulur. `ilanNo` yalnız KULLANICI, hizmet veren,
  /// admin ve destek süreçlerinde kullanılan okunabilir referanstır.
  ///
  /// ⚠ FOREIGN KEY DEĞİLDİR. Hiçbir ilişki bu alan üzerinden
  /// kurulmaz.
  ///
  /// ⚠ DEĞİŞMEZ: `final`. İlan düzenlense, teklif alsa, kapatılsa,
  /// geçmişe taşınsa da aynı kalır. Silinen/kapanan bir ilanın
  /// numarası BAŞKA bir ilana yeniden verilmez.
  ///
  /// ⚠ ÜRETİM OTORİTESİ İSTEMCİ DEĞİLDİR. Mock ortamda
  /// `ListingRepository` artan bir sayaçla üretir; gerçek backend
  /// geldiğinde numarayı üreten ve benzersizliğini garanti eden
  /// taraf veritabanıdır (UNIQUE kısıt).
  final String ilanNo;
  final String ownerId;  // müşteri hesabı
  String title;
  String location;
  String desc;
  ListingStatus status;
  List<String> photoPaths;
  String? selectedOfferId;
  final DateTime createdAt;
  final DateTime expiresAt;   // createdAt + DomainConfig.listingLifetime

  Listing({
    required this.id,
    required this.ilanNo,
    required this.ownerId,
    required this.title,
    required this.location,
    required this.desc,
    this.status = ListingStatus.open,
    List<String>? photoPaths,
    DateTime? createdAt,
  })  : photoPaths = photoPaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        expiresAt =
            (createdAt ?? DateTime.now()).add(DomainConfig.listingLifetime);

  bool get acceptsOffers => status == ListingStatus.open;

  /// Ekranlarda gösterilecek biçim — TEK KAYNAK.
  ///
  /// ⚠ Ekranlar "İlan No: " önekini elle yazmaz; biçim değişirse
  /// tek yerden değişsin.
  String get ilanNoEtiketi => 'İlan No: $ilanNo';
}
