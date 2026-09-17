import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api_config.dart';
import 'package:hizmetcep/data/remote/ws_auth.dart';

import 'support/fake_backend.dart';

void main() {
  group('WebSocket kimlik altyapısı', () {
    test('adres /ws namespace ine çözülür ve ws şemasını kullanır', () {
      final url = ApiConfig.wsUrl;
      expect(url.startsWith('ws'), isTrue);
      expect(url.endsWith('/ws'), isTrue);
      expect(url.contains('/api/v1'), isFalse);
    });

    test('oturum varken handshake token taşır', () async {
      final auth = WsAuth(FakeTokenStore(access: 'AT', refresh: 'RT'));
      expect(await auth.handshakeAuth(), {'token': 'AT'});
    });

    test('oturum yoksa bağlanılmaz (handshake null)', () async {
      final auth = WsAuth(FakeTokenStore());
      expect(await auth.handshakeAuth(), isNull);
    });

    test('olay adları sunucu sözleşmesiyle birebir', () {
      expect(WsAuth.eventMessageNew, 'message.new');
      expect(WsAuth.eventMessageDelivered, 'message.delivered');
      expect(WsAuth.eventMessageRead, 'message.read');
      expect(WsAuth.actionJoin, 'conversation.join');
      expect(WsAuth.actionLeave, 'conversation.leave');
    });
  });
}
