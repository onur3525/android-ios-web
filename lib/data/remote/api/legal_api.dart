import '../api_client.dart';

/// Yasal metinler ve destek içeriği (PUBLIC, sürümlü).
class LegalApi {
  final ApiClient c;
  LegalApi(this.c);

  /// Başlık + sürüm listesi.
  Future<List<dynamic>> index() => c.getList('/legal');

  /// Tek belge: { slug, title, version, effectiveDate, body }
  Future<Map<String, dynamic>> one(String slug) => c.get('/legal/$slug');
}
