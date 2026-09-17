/// Mesaj durumları — backend sözleşmesiyle aynı sıra:
/// gönderiliyor → gönderildi → iletildi → okundu (veya gönderilemedi).
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String senderId; // hesap id — yön (in/out) görüntüleyen tarafa göre çözülür
  final String? text;
  final String? imagePath;
  MessageStatus status;
  final DateTime time;
  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imagePath,
    this.status = MessageStatus.sent,
  }) : time = DateTime.now();
}
