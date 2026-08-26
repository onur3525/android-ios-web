import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/controllers/free_right_controller.dart';
import 'package:hizmetcep/data/models/free_right.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';

/// ÜCRETSİZ İLETİŞİM HAKKI — istemci davranış testleri.
///
/// ⚠ Bu testler yalnız İSTEMCİ mantığını doğrular.
/// Atomik tüketim, çift tüketim engeli ve iade kuralları SUNUCUDA
/// zorlanır ve gerçek veritabanıyla test edilmelidir.
void main() {
  group('FundingDecision', () {
    test('FREE_RIGHT çözümlemesi', () {
      final d = FundingDecision.fromJson(
          {'source': 'FREE_RIGHT', 'aciklama': 'Hakkınız kullanılacak'});
      expect(d.source, OfferFundingSource.freeRight);
      expect(d.isFree, isTrue);
    });

    test('bilinmeyen değer WALLET sayılır (güvenli taraf)', () {
      final d = FundingDecision.fromJson({'source': 'BILINMEYEN'});
      expect(d.source, OfferFundingSource.wallet);
      expect(d.isFree, isFalse);
    });
  });

  group('FreeRightSummary', () {
    test('boş yanıt sıfır hak', () {
      final s = FreeRightSummary.fromJson(const {});
      expect(s.remainingRights, 0);
      expect(s.hasUsableRight, isFalse);
    });

    test('dolu yanıt çözümlenir', () {
      final s = FreeRightSummary.fromJson({
        'remainingRights': 3,
        'hasUsableRight': true,
        'nextExpiryAt': '2026-12-31T00:00:00.000Z',
      });
      expect(s.remainingRights, 3);
      expect(s.hasUsableRight, isTrue);
      expect(s.nextExpiryAt, isNotNull);
    });
  });

  group('FreeRightController', () {
    test('hak yoksa cüzdan akışı seçilir', () async {
      final c = FreeRightController(MockFreeRightPort());
      await c.load();
      expect(c.remainingRights, 0);
      expect(c.willUseFreeRight, isFalse,
          reason: 'hak yokken parasal bloke akışı uygulanmalı');
    });

    test('hak varsa ücretsiz akış seçilir', () async {
      final c = FreeRightController(MockFreeRightPort(remainingRights: 2));
      await c.load();
      expect(c.remainingRights, 2);
      expect(c.willUseFreeRight, isTrue);
      expect(c.funding?.aciklama, contains('bloke edilmeyecek'));
    });

    test('yüklenmeden önce ücretsiz sayılmaz (güvenli varsayılan)', () {
      final c = FreeRightController(MockFreeRightPort(remainingRights: 5));
      expect(c.willUseFreeRight, isFalse,
          reason: 'karar alınmadan ücretsiz gösterilmemeli');
    });
  });
}
