import '../api_client.dart';

/// /messages uçları. Mesaj ÖNCE sunucuya yazılır, sonra yayınlanır;
/// idempotencyKey ile aynı mesaj iki kez oluşmaz.
class ChatApi {
  final ApiClient c;
  ChatApi(this.c);

  Future<List<dynamic>> conversations() => c.getList('/messages/conversations');

  Future<List<dynamic>> history(String offerId, {String? before}) =>
      c.getList('/messages/$offerId', query: {if (before != null) 'before': before});

  Future<Map<String, dynamic>> send({
    required String offerId,
    required String idempotencyKey,
    String? text,
    String? storageRef,
  }) =>
      c.post('/messages',
          body: {
            'offerId': offerId,
            'idempotencyKey': idempotencyKey,
            if (text != null) 'text': text,
            if (storageRef != null) 'storageRef': storageRef,
          },
          idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> markRead(String offerId) =>
      c.post('/messages/$offerId/read');
}
