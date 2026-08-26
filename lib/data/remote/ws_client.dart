import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'ws_auth.dart';

/// GERÇEK ZAMANLI MESAJLAŞMA bağlantısı (socket.io, namespace /ws).
/// Sunucu sözleşmesi WsAuth içindedir; burada yalnız bağlantı yönetimi,
/// YENİDEN BAĞLANMA ve olay dağıtımı vardır.
class WsClient {
  final WsAuth auth;
  io.Socket? _socket;
  final Set<String> _joined = {};

  WsClient(this.auth);

  bool get connected => _socket?.connected ?? false;

  final _messageNew = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDelivered = StreamController<Map<String, dynamic>>.broadcast();
  final _messageRead = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onMessageNew => _messageNew.stream;
  Stream<Map<String, dynamic>> get onMessageDelivered => _messageDelivered.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageRead.stream;
  Stream<bool> get onConnectionChange => _connection.stream;

  Future<void> connect() async {
    if (_socket != null) {
      return;
    }
    final handshake = await auth.handshakeAuth();
    if (handshake == null) return; // oturum yoksa bağlanılmaz

    final s = io.io(
      auth.url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth(handshake)
          .enableReconnection()          // kopmada otomatik yeniden bağlanma
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    s.onConnect((_) {
      _connection.add(true);
      for (final offerId in _joined) {
        s.emit(WsAuth.actionJoin, {'offerId': offerId}); // yeniden katıl
      }
    });
    s.onDisconnect((_) => _connection.add(false));
    s.on(WsAuth.eventMessageNew, (d) => _emit(_messageNew, d));
    s.on(WsAuth.eventMessageDelivered, (d) => _emit(_messageDelivered, d));
    s.on(WsAuth.eventMessageRead, (d) => _emit(_messageRead, d));

    _socket = s;
    s.connect();
  }

  void _emit(StreamController<Map<String, dynamic>> c, dynamic data) {
    if (data is Map) c.add(Map<String, dynamic>.from(data));
  }

  /// Konuşma odasına katıl — yetkiyi SUNUCU doğrular.
  void join(String offerId) {
    _joined.add(offerId);
    _socket?.emit(WsAuth.actionJoin, {'offerId': offerId});
  }

  void leave(String offerId) {
    _joined.remove(offerId);
    _socket?.emit(WsAuth.actionLeave, {'offerId': offerId});
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _joined.clear();
    _connection.add(false);
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageNew.close();
    await _messageDelivered.close();
    await _messageRead.close();
    await _connection.close();
  }
}
