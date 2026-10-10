import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat.dart';

/// Teklif başına sohbet (offerId → mesajlar).
///
/// ── ⚠ SOHBET BOŞ BAŞLAR (12 Eyl, kullanıcı isteği) ──
///
/// "Not kısmına yazılan yazı not kısmında kalsın, aynı zamanda mesaj
/// olarak gönderilmesin."
///
/// ESKİ KURAL: sohbet ilk açıldığında teklif notu, hizmet verenin ilk
/// MESAJI olarak eklenirdi. İki sorunu vardı:
///
///   1. AYNI METİN İKİ YERDE. Not zaten teklif kartında "Hizmet
///      Verenin Notu" başlığıyla duruyor. Sohbette tekrar çıkması,
///      hizmet verenin hiç yazmadığı bir mesajı göndermiş gibi
///      göstermekti.
///   2. YANILTICI OKUNMAMIŞ SAYISI. Kart üzerindeki "Yeni mesaj"
///      balonu bu sahte mesajı sayıyordu; kimse yazmamışken hizmet
///      alana mesaj gelmiş gibi görünüyordu.
///
/// ⚠ NOT SİLİNMEDİ, YERİ DEĞİŞMEDİ: `Offer.note` alanı ve onu
/// gösteren kart aynen duruyor. Kalkan yalnız notun MESAJA
/// kopyalanması.
class ChatRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, List<ChatMessage>> _threads = {};

  // ── Sekme anlığı (yalnız web + mock; bkz. sekme_anligi.dart) ──
  Map<String, List<ChatMessage>> get sekmeKayitlari => Map.unmodifiable(_threads);
  void sekmeKayitlariniYukle(Map<String, List<ChatMessage>> kayitlar) {
    _threads
      ..clear()
      ..addAll(kayitlar);
    notifyListeners();
  }

  /// ⚠ BOŞ LİSTE DÖNER, `null` DEĞİL: çağıranlar "sohbet var ama
  /// henüz mesaj yok" ile "böyle bir teklif yok" arasındaki farkı
  /// `null` üzerinden ayırıyor.
  List<ChatMessage> threadFor(String offerId) =>
      _threads.putIfAbsent(offerId, () => []);

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
