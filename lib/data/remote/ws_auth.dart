import 'api_config.dart';
import 'token_store.dart';

/// WebSocket KİMLİK altyapısı. Sunucu tarafı sözleşme:
/// socket.io namespace '/ws', kimlik `handshake.auth.token` ile taşınır.
/// Bağlantı kurma ve olay dinleme MESAJLAŞMA paketinde yapılacaktır;
/// burada yalnız kimlik/adres üretimi hazırlanır.
class WsAuth {
  final TokenStore tokens;
  const WsAuth(this.tokens);

  String get url => ApiConfig.wsUrl;

  /// socket.io istemcisine verilecek auth haritası.
  Future<Map<String, String>?> handshakeAuth() async {
    final t = await tokens.accessToken();
    if (t == null) return null; // oturum yoksa bağlanılmaz
    // ⚠ ÇEREZE GEÇİŞ NOKTASI (web · M-05): backend çerezli oturuma
    // geçtiğinde web el sıkışması token değil çerezle doğrulanır.
    return {'token': t};
  }

  /// Sunucudan gelen olaylar (mesajlaşma paketinde tüketilecek).
  static const String eventMessageNew = 'message.new';
  static const String eventMessageDelivered = 'message.delivered';
  static const String eventMessageRead = 'message.read';

  /// İstemciden gönderilen olaylar.
  static const String actionJoin = 'conversation.join';
  static const String actionLeave = 'conversation.leave';
}
