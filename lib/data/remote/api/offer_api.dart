import '../api_client.dart';

/// /offers uçları. Teklif verme FİNANSAL bir işlemdir (50 TL bloke) →
/// Idempotency-Key ZORUNLU.
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

  Future<Map<String, dynamic>> select(String offerId, {required String idempotencyKey}) =>
      c.post('/offers/$offerId/select', idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> withdraw(String offerId, {required String idempotencyKey}) =>
      c.post('/offers/$offerId/withdraw', idempotencyKey: idempotencyKey);
}
