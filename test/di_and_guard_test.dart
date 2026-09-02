import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/ports/api_ports.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/remote/api/listing_api.dart';
import 'package:hizmetcep/data/remote/api_config.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/main.dart';

import 'support/fake_backend.dart';

void main() {
  group('DI seçimi', () {
    test('DATA_SOURCE=mock → bellek içi portlar kurulur', () {
      final ports = buildPorts(mode: DataSourceMode.mock);
      expect(ports.freeRights, isA<MockFreeRightPort>(),
          reason: 'mock modda ücretsiz hak portu da mock olmalı');
      expect(ports.auth, isA<MockAuthPort>());
      expect(ports.listings, isA<MockListingPort>());
      expect(ports.offers, isA<MockOfferPort>());
      expect(ports.contact, isA<MockContactPort>());
      expect(ports.expiry, isNotNull); // süre kuralı mock modda istemcide
    });

    test('DATA_SOURCE=api → gerçek API portları kurulur', () {
      final ports = buildPorts(mode: DataSourceMode.api);
      expect(ports.freeRights, isA<ApiFreeRightPort>(),
          reason: 'api modda ücretsiz hak portu gerçek API olmalı');
      expect(ports.auth, isA<ApiAuthPort>());
      expect(ports.listings, isA<ApiListingPort>());
      expect(ports.offers, isA<ApiOfferPort>());
      expect(ports.contact, isA<ApiContactPort>());
      expect(ports.expiry, isNull); // süre kuralı sunucuda
    });

    test('Chat, Review ve Notification her iki modda da mock kalır', () {
      for (final m in DataSourceMode.values) {
        final p = buildPorts(mode: m);
        expect(p.chat, isNotNull);
        expect(p.reviews, isNotNull);
        expect(p.notifications, isNotNull);
      }
    });
  });

  group('Çift tıklama koruması', () {
    test('aynı işlem sürerken ikinci istek sunucuya GİTMEZ', () async {
      var inFlightSeen = false;
      final be = FakeBackend({
        'POST /listings': (_) => listingJson(ownerId: 'u1'),
        'GET /listings/my': (_) => <dynamic>[listingJson(ownerId: 'u1')],
      });
      final ctl = ListingController(
          ApiListingPort(ApiListingRepository(ListingApi(be.client()))));

      final first = ctl.publish(
          ownerId: 'u1', title: 'Musluk tamiri', location: 'Bornova',
          desc: 'Mutfak musluğu damlatıyor');
      // İlk istek sürerken ikinci çağrı domain katmanında reddedilir.
      final second = await ctl.publish(
          ownerId: 'u1', title: 'Musluk tamiri', location: 'Bornova',
          desc: 'Mutfak musluğu damlatıyor');
      inFlightSeen = second.error != null && second.listing == null;
      await first;

      expect(inFlightSeen, isTrue);
      expect(be.countOf('POST /listings'), 1); // sunucuya TEK istek gitti
    });
  });
}
