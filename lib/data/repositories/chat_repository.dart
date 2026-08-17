import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat.dart';

/// Teklif başına sohbet (offerId → mesajlar).
/// Kural: geçmiş yazışma yoktur; ilk mesaj YALNIZ teklif verenin notudur.
class ChatRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, List<ChatMessage>> _threads = {};

  List<ChatMessage> threadFor(String offerId,
      {required String firstNote, required String providerId}) {
    return _threads.putIfAbsent(offerId, () => [
          ChatMessage(id: _uuid.v4(), senderId: providerId, text: firstNote),
        ]);
  }

  List<ChatMessage>? existing(String offerId) => _threads[offerId];

  ChatMessage send(String offerId,
      {required String senderId,
      String? text,
      String? imagePath,
      MessageStatus status = MessageStatus.sent}) {
    final m = ChatMessage(
        id: _uuid.v4(), senderId: senderId, text: text,
        imagePath: imagePath, status: status);
    _threads.putIfAbsent(offerId, () => []).add(m);
    notifyListeners();
    return m;
  }

  void setStatus(String offerId, String messageId, MessageStatus s) {
    for (final m in _threads[offerId] ?? const <ChatMessage>[]) {
      if (m.id == messageId) {
        m.status = s;
      }
    }
    notifyListeners();
  }

  /// Okuyanın KARŞI tarafça gönderilmiş mesajlarını okundu yapar.
  void markRead(String offerId, {required String readerId}) {
    for (final m in _threads[offerId] ?? const <ChatMessage>[]) {
      if (m.senderId != readerId && m.status == MessageStatus.sent) {
        m.status = MessageStatus.read;
      }
    }
    notifyListeners();
  }

  void removeForOffers(Iterable<String> offerIds) {
    for (final id in offerIds) {
      _threads.remove(id);
    }
    notifyListeners();
  }
}
