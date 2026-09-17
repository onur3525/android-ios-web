import '../../domain/failures.dart';
import '../models/notification.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Bildirimler — liste, okundu, tümünü okundu ve rozet sayısı.
class NotificationController extends BaseController {
  final NotificationPort _notifs;
  NotificationController(this._notifs) : super([_notifs]);

  List<AppNotification> forUser(String userId) => _notifs.forUser(userId);
  int unreadCount(String userId) => _notifs.unreadCount(userId);

  /// Liste yenileme (açılış ve aşağı çekerek yenileme).
  Future<DomainError?> load(String userId) => runLoad(() => _notifs.load(userId));

  /// Yalnız rozet sayısı (ana sayfada liste yüklemeden).
  Future<DomainError?> refreshBadge(String userId) => _notifs.loadUnreadCount(userId);

  Future<DomainError?> markRead(String id) =>
      runAction('notif:read:$id', () => _notifs.markRead(id));

  Future<DomainError?> markAllRead(String userId) =>
      runAction('notif:read-all', () => _notifs.markAllRead(userId));
}
