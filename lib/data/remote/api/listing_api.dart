import '../api_client.dart';

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
  }) =>
      c.post('/listings', body: {
        'title': title, 'location': location,
        'description': description, 'photoRefs': photoRefs,
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
  Future<Map<String, dynamic>> cancel(String id, {String? reason}) =>
      c.post('/listings/$id/cancel',
          body: reason == null || reason.isEmpty ? null : {'reason': reason});
  Future<Map<String, dynamic>> start(String id) => c.post('/listings/$id/start');
  Future<Map<String, dynamic>> complete(String id) => c.post('/listings/$id/complete');
}
