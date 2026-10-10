import '../api_client.dart';

/// Destek talepleri (Destek Merkezi › Talep Gönder) — OTURUM GEREKİR.
///
/// Sunucu: `backend/src/routes/destek.js`. Kayıt Admin › Gelen Talepler ›
/// Destek Talepleri'ne düşer; hesap dondurma/silme talepleriyle KARIŞMAZ.
class DestekApi {
  final ApiClient c;
  DestekApi(this.c);

  /// Yeni talep → { id, ticketNo, subject, message, status, createdAt, … }
  ///
  /// [idempotencyKey]: aynı içerik yeniden denendiğinde (yanıt ağda
  /// kaybolduysa) sunucu İKİNCİ kayıt açmaz, ilkini döndürür.
  Future<Map<String, dynamic>> talepGonder({
    required String konu,
    required String mesaj,
    required String platform,
    required String surum,
    required String idempotencyKey,
  }) =>
      c.post('/support/tickets',
          body: {
            'subject': konu,
            'message': mesaj,
            'platform': platform,
            'appVersion': surum,
          },
          idempotencyKey: idempotencyKey);
}
