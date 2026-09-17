import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/controllers/notification_controller.dart';
import 'package:hizmetcep/data/controllers/review_controller.dart';
import 'package:hizmetcep/data/models/chat.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/remote/api/chat_api.dart';
import 'package:hizmetcep/data/remote/api/notification_api.dart';
import 'package:hizmetcep/data/remote/api/offer_api.dart';
import 'package:hizmetcep/data/remote/api/review_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_chat_repositories.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/domain/failures.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> messageJson({
  String id = 'm1', String senderId = 'u1', String status = 'SENT', String text = 'merhaba',
}) =>
    {
      'id': id, 'offerId': 'o1', 'senderId': senderId, 'text': text,
      'status': status, 'createdAt': '2026-01-01T12:00:00.000Z',
    };

ApiChatPort chatPort(ApiClient c) => ApiChatPort(ApiChatRepository(ChatApi(c)));
ApiReviewPort reviewPort(ApiClient c) =>
    ApiReviewPort(ApiReviewRepository(ReviewApi(c)), ApiOfferPort(ApiOfferRepository(OfferApi(c))));
ApiNotificationPort notifPort(ApiClient c) =>
    ApiNotificationPort(ApiNotificationRepository(NotificationApi(c)));

void main() {
  group('Sohbet', () {
    test('konuşma listesi sunucudan gelir', () async {
      final be = FakeBackend({
        'GET /messages/conversations': (_) => <dynamic>[
              {'offer': offerJson(id: 'o1')},
            ],
      });
      final ctl = ChatController(chatPort(be.client()));
      final err = await ctl.loadConversations('u1');

      expect(err, isNull);
      expect(ctl.conversationsFor('u1').single.id, 'o1');
    });

    test('sohbet açılışında geçmiş yüklenir ve okundu işaretlenir', () async {
      final be = FakeBackend({
        'GET /messages/o1': (_) => <dynamic>[
              messageJson(id: 'm1', senderId: 'u2', status: 'DELIVERED'),
            ],
        'POST /messages/o1/read': (_) => {'ok': true},
      });
      final ctl = ChatController(chatPort(be.client()));
      final r = await ctl.openThread('o1', actorId: 'u1');

      expect(r.error, isNull);
      expect(r.thread!.single.status, MessageStatus.read);
      expect(be.countOf('POST /messages/o1/read'), 1);
    });

    test('iletişim açılmamışsa sunucu reddeder, geçmiş açılmaz', () async {
      final be = FakeBackend({
        'GET /messages/o1': (_) => apiError(409, 'INVALID_STATE',
            'Mesajlaşma, iletişim bilgileri açıldıktan sonra kullanılabilir'),
      });
      final ctl = ChatController(chatPort(be.client()));
      final r = await ctl.openThread('o1', actorId: 'u1');

      expect(r.error, isA<InvalidStateError>());
      expect(r.thread, isNull);
    });

    test('gönderim: idempotencyKey ile gider, sunucu kaydı yerel satırın yerine geçer', () async {
      final be = FakeBackend({'POST /messages': (b) => messageJson(id: 'srv-1')});
      final port = chatPort(be.client());
      final ctl = ChatController(port);
      final r = await ctl.sendDelivered('o1', senderId: 'u1', text: 'merhaba');

      expect(r.error, isNull);
      expect(r.message!.id, 'srv-1');
      // ⚠ BU TEST API PORTUNU KULLANIR (`chatPort`), mock portu
      // değil: teklif notunun sohbete eklenmesi MOCK tarafındaydı ve
      // 12 Eyl'de kaldırıldı. Buradaki 1, az önce GÖNDERİLEN mesajın
      // kendisidir; "çift satır yok" onun iki kez eklenmediğini
      // söyler.
      expect(port.threadFor('o1')!.length, 1);          // çift satır yok
      expect(be.headers.last['Idempotency-Key'], isNotNull);
    });

    test('gönderim başarısızsa mesaj gönderilemedi kalır, sahte başarı yok', () async {
      final be = FakeBackend({
        'POST /messages': (_) => apiError(500, 'INTERNAL_ERROR', 'Sunucu hatası'),
      });
      final port = chatPort(be.client());
      final ctl = ChatController(port);
      final r = await ctl.sendDelivered('o1', senderId: 'u1', text: 'merhaba');

      expect(r.error, isNotNull);
      expect(port.threadFor('o1')!.single.status, MessageStatus.failed);
    });

    test('tekrar gönderim AYNI anahtarı kullanır — sunucuda ikinci kayıt oluşmaz', () async {
      var fail = true;
      final keys = <String>[];
      final be = FakeBackend({
        'POST /messages': (b) {
          keys.add(b['idempotencyKey'] as String);
          if (fail) {
            return apiError(503, 'INTERNAL_ERROR', 'Servis kapalı');
          }
          return messageJson(id: 'srv-1');
        },
      });
      final port = chatPort(be.client());
      final ctl = ChatController(port);
      await ctl.sendDelivered('o1', senderId: 'u1', text: 'merhaba');

      fail = false;
      final ok = await ctl.retry('o1', port.threadFor('o1')!.single);

      expect(ok, isTrue);
      expect(keys.length, 2);
      expect(keys[0], keys[1]);                          // aynı idempotency anahtarı
      expect(port.threadFor('o1')!.single.id, 'srv-1');
    });

    test('çift tıklamada ikinci gönderim engellenir', () async {
      final be = FakeBackend({'POST /messages': (_) => messageJson()});
      final ctl = ChatController(chatPort(be.client()));
      final first = ctl.sendDelivered('o1', senderId: 'u1', text: 'merhaba');
      final second = await ctl.sendDelivered('o1', senderId: 'u1', text: 'merhaba');
      await first;

      expect(second.error, isNotNull);
      expect(be.countOf('POST /messages'), 1);
    });
  });

  group('Değerlendirme', () {
    test('gönderim sonrası ortalama sunucudan tazelenir', () async {
      var created = false;
      final be = FakeBackend({
        'GET /offers/my': (_) => <dynamic>[offerJson(id: 'o1', providerId: 'p1')],
        'POST /reviews': (_) { created = true; return {'id': 'r1'}; },
        'GET /reviews/provider/p1': (_) => {
              'average': created ? 4.5 : null,
              'count': created ? 2 : 0,
              'reviews': created
                  ? <dynamic>[
                      {'id': 'r1', 'listingId': 'l1', 'offerId': 'o1', 'authorId': 'u1',
                       'stars': 5, 'text': 'teşekkürler'},
                      {'id': 'r0', 'listingId': 'l0', 'offerId': 'o0', 'authorId': 'u2',
                       'stars': 4, 'text': 'iyi'},
                    ]
                  : <dynamic>[],
            },
      });
      final c = be.client();
      final port = reviewPort(c);
      await port.offers.loadMine();               // teklif önbelleğe alınır
      final ctl = ReviewController(port);

      final err = await ctl.submit(
          listingId: 'l1', offerId: 'o1', actorId: 'u1', stars: 5, text: 'teşekkürler');

      expect(err, isNull);
      expect(ctl.averageOf('p1'), 4.5);
      expect(ctl.byProvider('p1').length, 2);
    });

    test('silinen yorumlar listede ve ortalamada YOKTUR (sunucu göndermez)', () async {
      final be = FakeBackend({
        'GET /reviews/provider/p1': (_) => {
              'average': 5.0, 'count': 1,
              'reviews': <dynamic>[
                {'id': 'r1', 'listingId': 'l1', 'offerId': 'o1', 'authorId': 'u1',
                 'stars': 5, 'text': 'harika'},
              ],
            },
      });
      final ctl = ReviewController(reviewPort(be.client()));
      await ctl.loadForProvider('p1');

      expect(ctl.byProvider('p1').length, 1);
      expect(ctl.averageOf('p1'), 5.0);
    });

    test('kural ihlalinde sunucu mesajı döner', () async {
      final be = FakeBackend({
        'GET /offers/my': (_) => <dynamic>[offerJson(id: 'o1', providerId: 'p1')],
        'POST /reviews': (_) => apiError(409, 'INVALID_STATE',
            'Bu iş için zaten bir değerlendirme yaptınız'),
      });
      final c = be.client();
      final port = reviewPort(c);
      await port.offers.loadMine();
      final err = await ReviewController(port).submit(
          listingId: 'l1', offerId: 'o1', actorId: 'u1', stars: 5, text: 'tekrar');

      expect(err, isA<InvalidStateError>());
    });
  });

  group('Bildirimler', () {
    Map<String, dynamic> notif(String id, {String? readAt}) => {
          'id': id, 'userId': 'u1', 'type': 'NEW_OFFER', 'title': 'Yeni teklif',
          'body': 'İlanınıza teklif geldi', 'refId': 'l1', 'readAt': readAt,
          'createdAt': '2026-01-01T09:00:00.000Z',
        };

    test('liste ve rozet sayısı sunucudan gelir', () async {
      final be = FakeBackend({
        'GET /notifications': (_) => <dynamic>[notif('n1'), notif('n2', readAt: '2026-01-01T10:00:00.000Z')],
      });
      final ctl = NotificationController(notifPort(be.client()));
      await ctl.load('u1');

      expect(ctl.forUser('u1').length, 2);
      expect(ctl.unreadCount('u1'), 1);
    });

    test('rozet sayısı listeden bağımsız tazelenebilir', () async {
      final be = FakeBackend({'GET /notifications/unread-count': (_) => {'count': 7}});
      final ctl = NotificationController(notifPort(be.client()));
      await ctl.refreshBadge('u1');

      expect(ctl.unreadCount('u1'), 7);
      expect(be.countOf('GET /notifications'), 0);
    });

    test('okundu ve tümünü okundu sonrası liste yeniden yüklenir', () async {
      var allRead = false;
      final be = FakeBackend({
        'GET /notifications': (_) => <dynamic>[
              notif('n1', readAt: allRead ? '2026-01-01T10:00:00.000Z' : null),
            ],
        'POST /notifications/n1/read': (_) { allRead = true; return {'ok': true}; },
        'POST /notifications/read-all': (_) { allRead = true; return {'ok': true}; },
      });
      final ctl = NotificationController(notifPort(be.client()));
      await ctl.load('u1');
      expect(ctl.unreadCount('u1'), 1);

      await ctl.markRead('n1');
      expect(ctl.unreadCount('u1'), 0);
      expect(be.countOf('GET /notifications'), 2); // işlem sonrası yenileme

      await ctl.markAllRead('u1');
      expect(be.countOf('GET /notifications'), 3);
    });
  });
}
