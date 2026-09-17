import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api_error_mapper.dart';
import 'package:hizmetcep/domain/failures.dart';

void main() {
  group('backend hata modeli → DomainError', () {
    test('bilinen kodlar doğru tipe çevrilir', () {
      expect(
        mapErrorBody(409, {'error': {'code': 'DUPLICATE_OFFER', 'message': 'x'}}),
        isA<DuplicateOfferError>(),
      );
      expect(
        mapErrorBody(409, {'error': {'code': 'LISTING_CLOSED', 'message': 'x'}}),
        isA<ListingClosedError>(),
      );
      expect(
        mapErrorBody(403, {'error': {'code': 'FORBIDDEN', 'message': 'Yetkiniz yok'}}),
        isA<UnauthorizedError>(),
      );
    });

    test('kullanıcıya teknik kod değil sunucu mesajı gider', () {
      final e = mapErrorBody(422, {
        'error': {'code': 'VALIDATION_ERROR', 'message': 'Açıklama en az 5 kelime olmalı'}
      }) as ValidationError;
      expect(e.message, 'Açıklama en az 5 kelime olmalı');
      expect(e.message.contains('VALIDATION_ERROR'), isFalse);
    });

    test('5xx SUNUCU HATASI olarak sınıflanır', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ (15 Ağu): sunucu hatası artık
      // `ValidationError` değil. Form hatasıyla karıştırılırsa
      // kullanıcıya "alanı düzeltin" denmiş olurdu.
      expect(mapErrorBody(500, null), isA<ServerError>());
      expect(mapErrorBody(503, null), isA<MaintenanceError>());
    });

    test('tanınmayan 4xx gövdede güvenli varsayılan metin', () {
      final e = mapErrorBody(400, null);
      expect(e, isA<ValidationError>());
      expect((e as ValidationError).message.contains('tekrar deneyin'), isTrue);
    });

    test('bağlantı hataları KENDİ TÜRÜNDE ve kullanıcı dilinde', () {
      // ⚠ Metinler kısaldı; uzun cümle yerine tek başlık kullanılıyor
      // ve ayrıntı `hata_mesajlari.dart` merkezinden geliyor.
      expect(offlineError(), isA<NetworkError>());
      expect(offlineError().message.contains('İnternet'), isTrue);
      expect(timeoutError(), isA<TimeoutError>());
      expect(timeoutError().message.contains('zaman aşımı'), isTrue);
    });
  });
}
