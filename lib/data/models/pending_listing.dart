import 'dart:convert';

import 'listing.dart';

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

  /// Fotoğrafların MIME türleri — `localPhotoPaths` ile AYNI SIRADA.
  ///
  /// ── ⚠ NİÇİN AYRI BİR LİSTE ──
  ///
  /// Web'de `image_picker`, yol olarak `blob:https://…/uuid` döndürür
  /// ve bu adreste UZANTI YOKTUR. Tür yalnız yoldan türetildiği için
  /// kayıt öncesi ilan akışında fotoğraflar "desteklenmeyen tür"
  /// sayılıp SESSİZCE ATLANIYORDU.
  ///
  /// Tür, seçim anında `XFile.mimeType`ten okunuyor (bkz.
  /// `photo_picker.fotografTuru`); burada saklanarak yükleme
  /// aşamasına taşınır.
  ///
  /// ⚠ ESKİ KAYITLARLA UYUMLU: liste boş olabilir ya da yollardan kısa
  /// olabilir. Okuyan taraf eksik indekste yola geri düşer — mobilde
  /// bugünkü davranış budur ve bozulmaz.
  ///
  /// ⚠ TÜR UYDURULMAZ: ne burada ne okuyan tarafta varsayılan bir
  /// MIME atanır. Çözülemeyen fotoğraf atlanır.
  final List<String> localPhotoTypes;

  /// İŞİN YAPILMASI İSTENEN ZAMAN — İSTEĞE BAĞLI.
  ///
  /// ⚠ Kayıtsız akışta da taşınır: kullanıcı ilanı doldurup kayıt
  /// olduğunda seçimi KAYBOLMAZ.
  final IsZamani? isZamani;

  final DateTime createdAt;

  const PendingListing({
    required this.category,
    this.subService,
    this.description = '',
    this.city = '',
    this.district = '',
    this.neighborhood = '',
    this.localPhotoPaths = const [],
    this.localPhotoTypes = const [],
    this.isZamani,
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
    List<String>? localPhotoTypes,
  }) =>
      PendingListing(
        category: category ?? this.category,
        subService: subService ?? this.subService,
        description: description ?? this.description,
        city: city ?? this.city,
        district: district ?? this.district,
        neighborhood: neighborhood ?? this.neighborhood,
        localPhotoPaths: localPhotoPaths ?? this.localPhotoPaths,
        localPhotoTypes: localPhotoTypes ?? this.localPhotoTypes,
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
        'localPhotoTypes': localPhotoTypes,
        // ⚠ SEÇİM YOKSA ANAHTAR YAZILMAZ: eski taslaklar okunurken
        // `null` döner ve sorun çıkmaz.
        if (isZamani != null) 'isZamani': isZamani!.kod,
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
        localPhotoTypes: ((j['localPhotoTypes'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        // ⚠ Alan yoksa ya da bilinmeyense `null` — eski taslaklarla
        // geriye dönük uyumlu.
        isZamani: IsZamani.koddan(j['isZamani'] as String?),
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
