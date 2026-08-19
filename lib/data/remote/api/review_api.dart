import '../api_client.dart';

/// /reviews uçları. Kural doğrulaması (ilan sahibi + tamamlanmış iş +
/// tek değerlendirme) SUNUCUDA yapılır; silinen yorumlar dönmez.
class ReviewApi {
  final ApiClient c;
  ReviewApi(this.c);

  /// YORUM OLUŞTURMA — nihai uç
  /// (OpenAPI: `POST /listings/{listingId}/review`).
  ///
  /// ⚠ ESKİ UÇ `POST /reviews` İDİ ve `listingId`yi gövdede taşıyordu.
  /// Nihai sözleşmede yorum İLANIN alt kaynağıdır: bir ilan için tek
  /// değerlendirme yapılır (§14) ve bu kısıt yolda görünür.
  ///
  /// ⚠ Idempotency-Key ZORUNLU (§25): kullanıcı "Gönder"e iki kez
  /// basarsa ikinci yorum OLUŞMAZ.
  Future<Map<String, dynamic>> create({
    required String listingId,
    required int stars,
    required String text,
    required String idempotencyKey,
  }) =>
      c.post('/listings/$listingId/review',
          body: {'stars': stars, 'text': text},
          idempotencyKey: idempotencyKey);

  /// Bir hizmet verenin YAYINLANMIŞ değerlendirmeleri.
  ///
  /// ⚠ ESKİ YOL `/reviews/provider/{id}` İDİ ve OpenAPI'de yoktu.
  /// Nihai sözleşmede yorum listesi hizmet verenin alt kaynağıdır:
  /// `GET /providers/{providerId}/reviews`.
  ///
  /// ⚠ `mine()` ile AYNI UÇTUR — tek fark hangi kimliğin verildiği.
  /// Ayrı uç açmak aynı veriyi iki adla sunmak olurdu (§27).
  ///
  /// Ortalama yalnız YAYINLANMIŞ yorumlardan hesaplanır (§14):
  /// gönderimden 1 gün geçmeyenler listeye ve ortalamaya girmez.
  Future<Map<String, dynamic>> ofProvider(String providerId) =>
      c.get('/providers/$providerId/reviews');

  /// DEĞERLENDİRMELERİM — hizmet verenin aldığı yorumlar (READ-ONLY).
  /// { average, count, distribution{5..1}, items[], page{} }
  /// DEĞERLENDİRMELERİM — hizmet verenin ALDIĞI yorumlar.
  ///
  /// ── ⚠ AYRI UÇ AÇILMADI, KANONİK UÇ KULLANILDI ──
  ///
  /// Eskiden `GET /reviews/me` çağrılıyordu ve bu uç OpenAPI'de YOKTU.
  /// Ekranın istediği veri — bir hizmet verenin aldığı yorumlar,
  /// ortalaması, sayısı ve yıldız dağılımı — sözleşmedeki
  /// `GET /providers/{providerId}/reviews` ucunun tam olarak
  /// döndürdüğü şeydir.
  ///
  /// "Kendi yorumlarım" ayrı bir VERİ DEĞİL, aynı verinin
  /// `providerId = kendi kimliğim` hâlidir. Sözleşme aynı anlam için
  /// alternatif uç açılmasını YASAKLIYOR (§27); bu yüzden yeni uç
  /// tanımlamak yerine kanonik uç kullanıldı.
  ///
  /// ⚠ CURSOR PAGINATION KORUNDU (§16): sayfa numarası ya da
  /// `skip`/`take` KULLANILMAZ. Araya yeni kayıt girdiğinde offset
  /// kayar ve kullanıcı aynı yorumu iki kez görürdü.
  Future<Map<String, dynamic>> mine(
    String providerId, {
    String? cursor,
    int limit = 20,
  }) =>
      c.get('/providers/$providerId/reviews', query: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit.toString(),
      });
}
