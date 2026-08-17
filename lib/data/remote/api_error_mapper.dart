import '../../domain/failures.dart';

/// Backend STANDART hata gövdesi:
/// { error: { code, message, details? }, requestId, timestamp, path }
/// Bu gövde Flutter'ın sealed DomainError hiyerarşisine çevrilir.
/// TEKNİK KOD KULLANICIYA GÖSTERİLMEZ — yalnız backend'in Türkçe mesajı
/// veya güvenli bir varsayılan metin kullanılır.
class ApiFailure implements Exception {
  final DomainError error;
  final int statusCode;
  final String? requestId;
  final String code;
  const ApiFailure(this.error, this.statusCode, this.code, this.requestId);
  @override
  String toString() => 'ApiFailure($code/$statusCode)';
}

const _fallback = 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';

DomainError mapErrorBody(int status, Map<String, dynamic>? body) {
  final err = body?['error'] as Map<String, dynamic>?;
  final code = (err?['code'] as String?) ?? '';
  final msg = (err?['message'] as String?)?.trim();
  final text = (msg == null || msg.isEmpty) ? _fallback : msg;

  switch (code) {
    case 'NOT_FOUND':
      return NotFoundError(text);
    case 'UNAUTHORIZED':
    case 'FORBIDDEN':
      return UnauthorizedError(text);
    case 'INVALID_STATE':
      return InvalidStateError(text);
    // ⚠ KARTIN bakiyesi — cüzdan bakiyesi değil.
    case 'INSUFFICIENT_FUNDS':
    case 'CARD_INSUFFICIENT_FUNDS':
      return const KartBakiyesiYetersizError('Kart bakiyeniz yetersiz');
    case 'INSUFFICIENT_BALANCE':
      return InsufficientBalanceError(text);
    case 'DUPLICATE_OFFER':
      return const DuplicateOfferError();
    case 'OWN_LISTING_OFFER':
      return const OwnListingOfferError();
    case 'LISTING_CLOSED':
      return const ListingClosedError();
    case 'OTP_REQUIRED':
      return const OtpRequiredError();
    case 'WRONG_PASSWORD':
      return WrongPasswordError(text);
    case 'AUTH_FAILED':
      return const AuthFailedError();
    case 'VALIDATION_ERROR':
      return ValidationError(text);
    case 'RATE_LIMITED':
      return ValidationError(text);
    default:
      if (status == 401 || status == 403) {
        return UnauthorizedError(text);
      }
      if (status == 404) {
        return NotFoundError(text);
      }
      // ⚠ SUNUCU HATASI FORM HATASI DEĞİLDİR.
      //
      // 5xx kullanıcının girdisinden kaynaklanmaz; "alanı düzeltin"
      // demek yanlış olur. 503 planlı bakımdır, ayrı ele alınır.
      if (status == 503) {
        return maintenanceError();
      }
      if (status >= 500) {
        return serverError();
      }
      return ValidationError(text);
  }
}

// ── ⚠ TAŞIMA HATALARI KENDİ TÜRÜNE DÖNER ──
//
// Eskiden üçü de `ValidationError` idi; ekran bunları form
// hatasından ayıramıyordu. Metinler `hata_mesajlari.dart` ile
// aynı cümleleri kullanır.
NetworkError networkError() =>
    const NetworkError('Sunucuya ulaşılamıyor');
TimeoutError timeoutError() =>
    const TimeoutError('İşlem zaman aşımına uğradı');
NetworkError offlineError() =>
    const NetworkError('İnternet bağlantısı yok');
ServerError serverError() =>
    const ServerError('Şu an işlem yapılamıyor');
MaintenanceError maintenanceError() =>
    const MaintenanceError('Bakım çalışması sürüyor');
