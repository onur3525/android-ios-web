import '../api_client.dart';

/// /notifications uçları.
class NotificationApi {
  final ApiClient c;
  NotificationApi(this.c);

  Future<List<dynamic>> list() => c.getList('/notifications');
  Future<Map<String, dynamic>> unreadCount() => c.get('/notifications/unread-count');
  Future<Map<String, dynamic>> markRead(String id) => c.post('/notifications/$id/read');
  Future<Map<String, dynamic>> markAllRead() => c.post('/notifications/read-all');
}
