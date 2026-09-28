import '../api_client.dart';
import '../../models/listing.dart';

/// /listings uçları — 30 saat kuralı ve durum makinesi SUNUCUDA işler.
class ListingApi {
  final ApiClient c;
  ListingApi(this.c);

  Future<List<dynamic>> my() => c.getList('/listings/my');
  Future<List<dynamic>> available({String? category, String? district}) =>
      c.getList('/listings/available', query: {
        if (category != null) 'category': category,
        if (district != null) 'district': district,
      });
  Future<Map<String, dynamic>> byId(String id) => c.get('/listings/$id');

  Future<Map<String, dynamic>> create({
    required String title,
    required String location,
    required String description,
    List<String> photoRefs = const [],
    IsZamani? isZamani,
  }) =>
      c.post('/listings', body: {
        'title': title, 'location': location,
        'description': description, 'photoRefs': photoRefs,
        // ⚠ SEÇİM YOKSA ALAN HİÇ GÖNDERİLMEZ.
        //
        // `null` göndermek yerine alanı atlamak, sunucunun "seçim
        // yapılmadı" ile "boş gönderildi" arasında ayrım yapmasını
        // gerektirmez.
        if (isZamani != null) 'workTiming': isZamani.kod,
      });

  Future<Map<String, dynamic>> update(String id, {String? title, String? description}) =>
      c.patch('/listings/$id', body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      });

  /// ⚠ Gerekçe SUNUCUYA GÖNDERİLİR (yönetim denetimi için).
  Future<void> remove(String id, {String? reason}) => c.delete(
      '/listings/$id',
      body: reason == null || reason.isEmpty ? null : {'reason': reason});
}
