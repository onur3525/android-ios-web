import '../api_client.dart';

/// /contact uçları — iletişim açma TEK TÜKETİMDİR, iki taraf için ortaktır.
class ContactApi {
  final ApiClient c;
  ContactApi(this.c);

  Future<Map<String, dynamic>> status(String offerId) => c.get('/contact/$offerId');

  /// İLETİŞİM AÇMA — nihai uç (OpenAPI: `POST /offers/{offerId}/communication`).
  ///
  /// ⚠ ESKİ UÇ `POST /contact/open` İDİ ve `offerId`yi GÖVDEDE
  /// taşıyordu. Nihai sözleşmede kimlik YOLDA taşınır; gövde boştur.
  ///
  /// ⚠ Idempotency-Key ZORUNLU (§25): çift tıklamada ikinci tahsilat
  /// yapılmaz, ikinci ücretsiz hak tüketilmez, ikinci iletişim kaydı
  /// oluşmaz. İletişim zaten açıksa sunucu ilk sonucu döndürür — bu
  /// bir HATA DEĞİLDİR ve kullanıcıya hata gösterilmez.
  Future<Map<String, dynamic>> open(String offerId,
          {required String idempotencyKey}) =>
      c.post('/offers/$offerId/communication',
          idempotencyKey: idempotencyKey);
}
