import '../../domain/failures.dart';
import '../models/chat.dart';
import '../models/offer.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Sohbet. Somut repository OLUŞTURMAZ; mock modda bellek içi port,
/// API modunda sunucu + WebSocket portu kullanılır.
class ChatController extends BaseController {
  final ChatPort _chats;
  ChatController(this._chats) : super([_chats]);

  bool get realtimeConnected => _chats.realtimeConnected;

  List<ChatMessage>? threadFor(String offerId) => _chats.threadFor(offerId);
  List<Offer> conversationsFor(String actorId) => _chats.conversationsFor(actorId);

  Future<DomainError?> loadConversations(String actorId) =>
      runLoad(() => _chats.loadConversations(actorId));

  /// Sohbeti açar: geçmiş yüklenir, okundu işaretlenir, gerçek zamanlı
  /// bağlantı kurulur (mock modda no-op).
  Future<({List<ChatMessage>? thread, DomainError? error})> openThread(
      String offerId, {required String actorId}) async {
    final err = await runLoad(() async {
      await _chats.connectRealtime();
      final e = await _chats.loadThread(offerId, actorId: actorId);
      if (e != null) {
        return e;
      }
      return _chats.markRead(offerId, readerId: actorId);
    });
    return (thread: err == null ? _chats.threadFor(offerId) : null, error: err);
  }

  /// Gönderim: çift tıklamada ikinci istek engellenir; sunucu onaylamadan
  /// mesaj "gönderildi" gösterilmez, çevrimdışıyken gönderim yapılmaz.
  Future<({ChatMessage? message, DomainError? error})> sendDelivered(
    String offerId, {
    required String senderId,
    String? text,
    String? imagePath,
  }) async {
    if (isBusy('chat:send:$offerId')) {
      return (message: null, error: const ValidationError('Mesaj gönderiliyor — lütfen bekleyin'));
    }
    ({ChatMessage? message, DomainError? error}) result = (message: null, error: null);
    await runAction('chat:send:$offerId', () async {
      result = await _chats.send(offerId,
          senderId: senderId, text: text, storageRef: imagePath);
      return result.error;
    });
    return result;
  }

  /// Gönderilemeyen mesajı AYNI idempotency anahtarıyla tekrar dener.
  Future<bool> retry(String offerId, ChatMessage m) => _chats.retry(offerId, m);

  Future<DomainError?> markRead(String offerId, {required String readerId}) =>
      _chats.markRead(offerId, readerId: readerId);

  Future<void> leave(String offerId) async {
    // Oda üyeliği port düzeyinde yönetilir; bağlantı açık kalır.
  }
}
