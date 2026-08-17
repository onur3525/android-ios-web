import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/failures.dart';
import '../../models/chat.dart';
import '../../models/notification.dart';
import '../../models/offer.dart';
import '../../models/review.dart';
import '../api/chat_api.dart';
import '../api/notification_api.dart';
import '../api/review_api.dart';
import '../api_error_mapper.dart';
import '../mappers.dart';
import '../ws_client.dart';

Future<(T?, DomainError?)> _guard<T>(Future<T> Function() fn) async {
  try {
    return (await fn(), null);
  } on ApiFailure catch (e) {
    return (null, e.error);
  } catch (_) {
    return (null, const ValidationError('İşlem tamamlanamadı. Lütfen tekrar deneyin.'));
  }
}

/// SOHBET — mesaj önce sunucuya yazılır, sonra yayınlanır.
/// Çevrimdışıyken gönderim engellenir (ApiClient offline hatası döner) ve
/// mesaj "gönderilemedi" olarak kalır; tekrar denemede AYNI idempotencyKey
/// kullanılır, böylece sunucuda ikinci kayıt oluşmaz.
class ApiChatRepository extends ChangeNotifier {
  final ChatApi _api;
  final WsClient? ws;
  ApiChatRepository(this._api, {this.ws}) {
    _bindRealtime();
  }

  static const _uuid = Uuid();
  final Map<String, List<ChatMessage>> _threads = {};
  final Map<String, String> _idemOf = {}; // messageId → idempotencyKey (tekrar için)
  List<Offer> _conversations = const [];
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _connected = false;

  bool get realtimeConnected => _connected;
  List<ChatMessage>? threadFor(String offerId) => _threads[offerId];
  List<Offer> get conversations => _conversations;

  void _bindRealtime() {
    final w = ws;
    if (w == null) {
      return;
    }
    _subs.add(w.onConnectionChange.listen((c) {
      _connected = c;
      notifyListeners();
    }));
    _subs.add(w.onMessageNew.listen((d) {
      final offerId = d['offerId'] as String?;
      if (offerId == null) {
        return;
      }
      final m = Mappers.message(d);
      final list = _threads.putIfAbsent(offerId, () => []);
      if (list.every((e) => e.id != m.id)) list.add(m); // çift ekleme yok
      notifyListeners();
    }));
    _subs.add(w.onMessageDelivered.listen((d) => _applyStatus(d, MessageStatus.delivered)));
    _subs.add(w.onMessageRead.listen((d) => _applyStatus(d, MessageStatus.read)));
  }

  void _applyStatus(Map<String, dynamic> d, MessageStatus s) {
    final offerId = d['offerId'] as String?;
    if (offerId == null) {
      return;
    }
    for (final m in _threads[offerId] ?? const <ChatMessage>[]) {
      if (m.status != MessageStatus.failed && m.status != MessageStatus.sending) {
        m.status = s;
      }
    }
    notifyListeners();
  }

  Future<void> connectRealtime() async {
    await ws?.connect();
  }

  Future<void> disconnectRealtime() async {
    await ws?.disconnect();
    _connected = false;
    notifyListeners();
  }

  Future<DomainError?> loadConversations() async {
    final (rows, err) = await _guard(() => _api.conversations());
    if (err != null) {
      return err;
    }
    _conversations = rows!
        .map((e) => Mappers.conversationOffer(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
    return null;
  }

  Future<DomainError?> loadThread(String offerId) async {
    final (rows, err) = await _guard(() => _api.history(offerId));
    if (err != null) {
      return err;
    }
    _threads[offerId] = rows!
        .map((e) => Mappers.message(e as Map<String, dynamic>))
        .toList();
    ws?.join(offerId); // gerçek zamanlı güncellemeler için odaya katıl
    notifyListeners();
    return null;
  }

  void leaveThread(String offerId) => ws?.leave(offerId);

  /// Gönderim: iyimser "gönderiliyor" satırı eklenir, sunucu onayında
  /// gerçek kimlikle değiştirilir. Başarısızlıkta satır "gönderilemedi"
  /// kalır ve idempotencyKey saklanır.
  Future<({ChatMessage? message, DomainError? error})> send(
    String offerId, {
    required String senderId,
    String? text,
    String? storageRef,
  }) async {
    final key = _uuid.v4();
    return _sendWithKey(offerId, senderId: senderId, text: text, storageRef: storageRef, key: key);
  }

  Future<({ChatMessage? message, DomainError? error})> _sendWithKey(
    String offerId, {
    required String senderId,
    required String key,
    String? text,
    String? storageRef,
    ChatMessage? existing,
  }) async {
    final local = existing ??
        ChatMessage(
          id: 'local-$key', senderId: senderId, text: text,
          imagePath: storageRef, status: MessageStatus.sending,
        );
    if (existing == null) {
      _threads.putIfAbsent(offerId, () => []).add(local);
      _idemOf[local.id] = key;
    } else {
      local.status = MessageStatus.sending;
    }
    notifyListeners();

    final (res, err) = await _guard(() => _api.send(
        offerId: offerId, idempotencyKey: key, text: text, storageRef: storageRef));
    if (err != null) {
      local.status = MessageStatus.failed; // sahte başarı YOK
      notifyListeners();
      return (message: local, error: err);
    }

    final saved = Mappers.message(res!);
    final list = _threads.putIfAbsent(offerId, () => []);
    final i = list.indexWhere((m) => m.id == local.id);
    if (list.any((m) => m.id == saved.id)) {
      // sunucu kaydı WS ile gelmiş olabilir → yerel satırı kaldır
      if (i >= 0) {
        list.removeAt(i);
      }
    } else if (i >= 0) {
      list[i] = saved;
    } else {
      list.add(saved);
    }
    _idemOf.remove(local.id);
    _idemOf[saved.id] = key;
    notifyListeners();
    return (message: saved, error: null);
  }

  /// Tekrar gönderim — AYNI idempotencyKey ile; sunucuda ikinci kayıt oluşmaz.
  Future<bool> retry(String offerId, ChatMessage m) async {
    if (m.status != MessageStatus.failed) {
      return false;
    }
    final key = _idemOf[m.id] ?? _uuid.v4();
    _idemOf[m.id] = key;
    final r = await _sendWithKey(offerId,
        senderId: m.senderId, key: key, text: m.text,
        storageRef: m.imagePath, existing: m);
    return r.error == null;
  }

  Future<DomainError?> markRead(String offerId) async {
    final err = (await _guard(() => _api.markRead(offerId))).$2;
    if (err != null) {
      return err;
    }
    for (final m in _threads[offerId] ?? const <ChatMessage>[]) {
      if (m.status == MessageStatus.sent || m.status == MessageStatus.delivered) {
        m.status = MessageStatus.read;
      }
    }
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// DEĞERLENDİRME — kurallar sunucuda; silinen yorumlar sunucudan HİÇ gelmez,
/// ortalama da yalnız görünür yorumlardan hesaplanır.
class ApiReviewRepository extends ChangeNotifier {
  final ReviewApi _api;
  ApiReviewRepository(this._api);

  final Map<String, List<Review>> _byProvider = {};
  final Map<String, double?> _average = {};

  List<Review> byProvider(String providerId) => _byProvider[providerId] ?? const [];

  /// Müşterinin YAZDIĞI değerlendirmeler.
  ///
  /// ⚠ API modunda liste sunucudan `/reviews/mine` ucuyla gelir; bu
  /// yerel önbellek yalnız çekilmiş kayıtları tarar. Ekran veriyi
  /// doğrudan uçtan aldığı için burada eksik sonuç KULLANILMAZ.
  List<Review> byAuthor(String authorId) {
    final out = <Review>[];
    for (final list in _byProvider.values) {
      out.addAll(list.where((r) => r.authorId == authorId));
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }
  double? averageOf(String providerId) => _average[providerId];
  Review? byOffer(String offerId) {
    for (final list in _byProvider.values) {
      for (final r in list) {
        if (r.offerId == offerId) {
          return r;
        }
      }
    }
    return null;
  }

  Future<DomainError?> loadForProvider(String providerId) async {
    final (res, err) = await _guard(() => _api.ofProvider(providerId));
    if (err != null) {
      return err;
    }
    _average[providerId] = (res!['average'] as num?)?.toDouble();
    _byProvider[providerId] = ((res['reviews'] ?? const []) as List)
        .map((e) => Mappers.review(e as Map<String, dynamic>, providerId: providerId))
        .toList();
    notifyListeners();
    return null;
  }

  Future<DomainError?> submit({
    required String listingId,
    required String providerId,
    required int stars,
    required String text,
  }) async {
    final err =
        (await _guard(() => _api.create(listingId: listingId, stars: stars, text: text))).$2;
    if (err != null) {
      return err;
    }
    return loadForProvider(providerId); // ortalama sunucudan tazelenir
  }
}

/// BİLDİRİMLER.
class ApiNotificationRepository extends ChangeNotifier {
  final NotificationApi _api;
  ApiNotificationRepository(this._api);

  List<AppNotification> _items = const [];
  int _unread = 0;

  List<AppNotification> get items => _items;
  int get unread => _unread;

  Future<DomainError?> load() async {
    final (rows, err) = await _guard(() => _api.list());
    if (err != null) {
      return err;
    }
    _items = rows!.map((e) => Mappers.notification(e as Map<String, dynamic>)).toList();
    _unread = _items.where((n) => !n.read).length;
    notifyListeners();
    return null;
  }

  Future<DomainError?> loadUnreadCount() async {
    final (res, err) = await _guard(() => _api.unreadCount());
    if (err != null) {
      return err;
    }
    _unread = (res!['count'] as num?)?.toInt() ?? 0;
    notifyListeners();
    return null;
  }

  Future<DomainError?> markRead(String id) async {
    final err = (await _guard(() => _api.markRead(id))).$2;
    if (err != null) {
      return err;
    }
    return load();
  }

  Future<DomainError?> markAllRead() async {
    final err = (await _guard(() => _api.markAllRead())).$2;
    if (err != null) {
      return err;
    }
    return load();
  }
}
