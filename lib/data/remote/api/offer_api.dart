import '../api_client.dart';

/// /offers uçları.
///
/// ⚠ "FİNANSAL bir işlemdir (50 TL bloke)" KALDIRILDI (16 Eyl):
/// teklif vermek ücretsizdir.
///
/// ⚠ `Idempotency-Key` YİNE ZORUNLU — gerekçesi ücret değil,
/// YİNELENME: yeniden denenen POST aynı ilana ikinci teklif
/// oluşturmamalıdır.
class OfferApi {
  final ApiClient c;
  OfferApi(this.c);

  Future<List<dynamic>> my() => c.getList('/offers/my');

  Future<Map<String, dynamic>> create({
    required String listingId,
    required int amountTl,
    required String note,
    required String idempotencyKey,
  }) =>
      c.post('/offers',
          body: {'listingId': listingId, 'amountTl': amountTl, 'note': note},
          idempotencyKey: idempotencyKey);

  /// TEKLİF SEÇME — nihai uç
  /// (OpenAPI: `PUT /listings/{listingId}/selected-offer`).
  ///
  /// ⚠ ESKİ UÇ `POST /offers/{offerId}/select` İDİ. Nihai sözleşmede
  /// işlem TEKLİFİN değil İLANIN bir özelliğini yazar: ilanın seçilmiş
  /// teklifi. Bu yüzden yol ilana aittir, yöntem PUT'tur (aynı sonucu
  /// yazan tekrar istekler aynı durumu üretir) ve seçilen teklif
  /// GÖVDEDE gider.
  ///
  /// ⚠ Idempotency-Key ZORUNLU (§25): ikinci istek ikinci tamamlanan
  /// iş, ikinci tahsilat ya da ikinci bildirim ÜRETMEZ.
  Future<Map<String, dynamic>> select(
    String listingId, {
    required String offerId,
    required String idempotencyKey,
  }) =>
      c.put('/listings/$listingId/selected-offer',
          body: {'offerId': offerId}, idempotencyKey: idempotencyKey);

}
