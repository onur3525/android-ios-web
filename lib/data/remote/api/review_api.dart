import '../api_client.dart';

/// /reviews uçları. Kural doğrulaması (ilan sahibi + tamamlanmış iş +
/// tek değerlendirme) SUNUCUDA yapılır; silinen yorumlar dönmez.
class ReviewApi {
  final ApiClient c;
  ReviewApi(this.c);

  Future<Map<String, dynamic>> create({
    required String listingId,
    required int stars,
    required String text,
  }) =>
      c.post('/reviews', body: {'listingId': listingId, 'stars': stars, 'text': text});

  /// { average, count, reviews[] } — average yalnız GÖRÜNÜR yorumlardan.
  Future<Map<String, dynamic>> ofProvider(String providerId) =>
      c.get('/reviews/provider/$providerId');

  /// DEĞERLENDİRMELERİM — hizmet verenin aldığı yorumlar (READ-ONLY).
  /// { average, count, distribution{5..1}, items[], page{} }
  Future<Map<String, dynamic>> mine({int skip = 0, int take = 20}) =>
      c.get('/reviews/me', query: {'skip': skip.toString(), 'take': take.toString()});
}
