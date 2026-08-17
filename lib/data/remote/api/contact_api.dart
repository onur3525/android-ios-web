import '../api_client.dart';

/// /contact uçları — iletişim açma TEK TÜKETİMDİR, iki taraf için ortaktır.
class ContactApi {
  final ApiClient c;
  ContactApi(this.c);

  Future<Map<String, dynamic>> status(String offerId) => c.get('/contact/$offerId');

  /// Idempotency-Key ZORUNLU: çift tıklamada ikinci ücret alınmaz.
  Future<Map<String, dynamic>> open(String offerId, {required String idempotencyKey}) =>
      c.post('/contact/open',
          body: {'offerId': offerId}, idempotencyKey: idempotencyKey);
}
