// KARTLARDA "YENİ MESAJ" İŞARETİ (29 Eki, kullanıcı isteği): mesaj gelince
// hangi ilana / hangi teklife geldiği kartın üzerinde görünür; sohbet
// okununca kaybolur. Sayı tek kaynaktan: sunucunun sohbet listesindeki
// okunmamış sayısı + anlık gelen mesaj (açılmamış sohbet de sayılır).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/chat_api.dart';
import 'package:hizmetcep/data/remote/repositories/api_chat_repositories.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> _sohbet(String id, String ilan, int okunmamis) => {
      'offer': offerJson(id: id, listingId: ilan, providerId: 'p-$id'),
      'listingTitle': 'Boya', 'counterpart': {'id': 'p-$id', 'name': 'Usta', 'phone': null},
      'lastMessage': null, 'unread': okunmamis,
    };

String _kod(String yol) => File(yol).readAsStringSync();

void main() {
  ChatController kur(FakeBackend be) => ChatController(ApiChatPort(ApiChatRepository(ChatApi(be.client()))));

  test('açılmamış sohbetteki mesaj sunucu sayısından gelir; ilan kartı tekliflerin toplamını gösterir', () async {
    final be = FakeBackend({
      'GET /messages/conversations': (_) => <dynamic>[_sohbet('o1', 'l1', 2), _sohbet('o2', 'l1', 1), _sohbet('o3', 'l2', 0)],
    });
    final ctl = kur(be);
    expect(ctl.okunmamisMesaj('o1', 'ben'), 0, reason: 'liste yüklenmeden işaret yok');
    await ctl.okunmamislariTazele('ben');
    expect(ctl.okunmamisMesaj('o1', 'ben'), 2);
    expect(ctl.okunmamisMesaj('o2', 'ben'), 1);
    expect(ctl.okunmamisMesaj('o3', 'ben'), 0);
    expect(ctl.ilanOkunmamisMesaj('l1', 'ben'), 3);
    expect(ctl.ilanOkunmamisMesaj('l2', 'ben'), 0);
  });

  test('sohbet açılıp okununca işaret kalkar; diğer teklifinki kalır', () async {
    final be = FakeBackend({
      'GET /messages/conversations': (_) => <dynamic>[_sohbet('o1', 'l1', 2), _sohbet('o2', 'l1', 1)],
      'GET /messages/o1': (_) => <dynamic>[
            {'id': 'm1', 'offerId': 'o1', 'senderId': 'p-o1', 'text': 'merhaba', 'status': 'DELIVERED', 'createdAt': '2026-10-29T12:00:00.000Z'},
            {'id': 'm2', 'offerId': 'o1', 'senderId': 'p-o1', 'text': 'orada mısınız', 'status': 'DELIVERED', 'createdAt': '2026-10-29T12:01:00.000Z'},
          ],
      'POST /messages/o1/read': (_) => {'ok': true},
    });
    final ctl = kur(be);
    await ctl.okunmamislariTazele('ben');
    final r = await ctl.openThread('o1', actorId: 'ben');
    expect(r.error, isNull);
    expect(ctl.okunmamisMesaj('o1', 'ben'), 0);
    expect(ctl.okunmamisMesaj('o2', 'ben'), 1);
    expect(ctl.ilanOkunmamisMesaj('l1', 'ben'), 1);
  });

  test('kendi gönderdiğim mesaj sayılmaz', () async {
    final be = FakeBackend({
      'GET /messages/o1': (_) => <dynamic>[
            {'id': 'm1', 'offerId': 'o1', 'senderId': 'ben', 'text': 'merhaba', 'status': 'SENT', 'createdAt': '2026-10-29T12:00:00.000Z'},
          ],
    });
    final ctl = kur(be);
    await ctl.openThread('o1', actorId: 'ben');
    expect(ctl.okunmamisMesaj('o1', 'ben'), 0);
  });

  group('kartlar tek bileşeni kullanır', () {
    test('hizmet alanın ilan kartı, ilan detayındaki teklif kartı, hizmet verenin teklif kartı', () {
      expect(_kod('lib/screens/my_listings_screen.dart').contains('IlanYeniMesaj(listingId: listing.id)'), isTrue);
      expect(_kod('lib/screens/listing_detail_screen.dart').contains('TeklifYeniMesaj(offerId: offer.id'), isTrue);
      expect(_kod('lib/screens/jobs_screen.dart').contains('TeklifYeniMesaj(offerId: mine.id)'), isTrue);
    });

    test('mesajlar listesi aynı sayıyı kullanır (açılmamış sohbet de sayılır)', () {
      expect(_kod('lib/screens/chat_screen.dart').contains('chatCtl.okunmamisMesaj(o.id, me.id)'), isTrue);
    });

    test('kabul edilen teklif talebi kartı da işaret taşır', () {
      expect(_kod('lib/screens/my_listings_screen.dart')
          .contains('YeniMesajSeridi(okunmamisMesajSayisi(talep, talep.hizmetAlanId))'), isTrue);
    });
  });
}
