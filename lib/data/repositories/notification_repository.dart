import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/notification.dart';

class NotificationRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<AppNotification> _items = [];

  List<AppNotification> forUser(String userId) =>
      _items.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadCount(String userId) =>
      _items.where((n) => n.userId == userId && !n.read).length;

  AppNotification push({
    required String userId,
    required NotifType type,
    required String title,
    required String body,
    String? refId,
  }) {
    final n = AppNotification(
        id: _uuid.v4(), userId: userId, type: type,
        title: title, body: body, refId: refId);
    _items.insert(0, n);
    notifyListeners();
    return n;
  }

  void markRead(String id) {
    for (final n in _items) {
      if (n.id == id) {
        n.read = true;
      }
    }
    notifyListeners();
  }

  void markAllRead(String userId) {
    for (final n in _items) {
      if (n.userId == userId) {
        n.read = true;
      }
    }
    notifyListeners();
  }
}
