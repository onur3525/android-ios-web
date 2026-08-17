import 'dart:convert';

/// KAYIT ÖNCESİ HAZIRLANAN İLAN (TASLAK)
///
/// Kayıtsız kullanıcı ana sayfadaki kategoriden veya "Hizmet Ara"
/// sonucundan ilan formunu doldurabilir. İlan, kayıt ve zorunlu
/// doğrulamalar tamamlanana kadar YAYINLANMAZ; bu model o ara
/// durumu taşır.
///
/// ⚠ FOTOĞRAFLAR BACKEND'E YÜKLENMEZ. Kayıtsız kullanıcının yükleme
/// yetkisi yoktur; yalnız cihazdaki dosya yolları tutulur ve yükleme
/// kayıt tamamlandıktan sonra yapılır (`storageRef` BURADA TUTULMAZ).
class PendingListing {
  /// Ana kategori (ör. "Tesisat").
  final String category;

  /// Seçilen alt hizmet (ör. "Kombi Bakımı"). Yoksa `null`.
  final String? subService;

  final String description;

  /// Bölge zinciri — Problem 1'deki il/ilçe/mahalle sözleşmesiyle aynı.
  final String city;
  final String district;
  final String neighborhood;

  /// Cihazdaki fotoğraf yolları. Yükleme kayıt SONRASINDA yapılır.
  final List<String> localPhotoPaths;

  final DateTime createdAt;

  const PendingListing({
    required this.category,
    this.subService,
    this.description = '',
    this.city = '',
    this.district = '',
    this.neighborhood = '',
    this.localPhotoPaths = const [],
    required this.createdAt,
  });

  /// Yayınlanabilmesi için gereken asgari alanlar dolu mu?
  bool get isComplete =>
      category.trim().isNotEmpty &&
      description.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      neighborhood.trim().isNotEmpty;

  /// İlan başlığı: alt hizmet seçildiyse o, yoksa kategori.
  String get title =>
      (subService?.trim().isNotEmpty ?? false) ? subService!.trim() : category;

  /// Ekranlarda tek satır konum: "Mahalle, İlçe / İl"
  String get location => '$neighborhood, $district / $city';

  PendingListing copyWith({
    String? category,
    String? subService,
    String? description,
    String? city,
    String? district,
    String? neighborhood,
    List<String>? localPhotoPaths,
  }) =>
      PendingListing(
        category: category ?? this.category,
        subService: subService ?? this.subService,
        description: description ?? this.description,
        city: city ?? this.city,
        district: district ?? this.district,
        neighborhood: neighborhood ?? this.neighborhood,
        localPhotoPaths: localPhotoPaths ?? this.localPhotoPaths,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'subService': subService,
        'description': description,
        'city': city,
        'district': district,
        'neighborhood': neighborhood,
        'localPhotoPaths': localPhotoPaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingListing.fromJson(Map<String, dynamic> j) => PendingListing(
        category: (j['category'] as String?) ?? '',
        subService: j['subService'] as String?,
        description: (j['description'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        district: (j['district'] as String?) ?? '',
        neighborhood: (j['neighborhood'] as String?) ?? '',
        localPhotoPaths: ((j['localPhotoPaths'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        createdAt:
            DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
                DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static PendingListing? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) {
        return null;
      }
      return PendingListing.fromJson(j);
    } catch (_) {
      // Bozuk kayıt kullanıcıyı kilitlemez; taslak yok sayılır.
      return null;
    }
  }
}
