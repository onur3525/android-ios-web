/// Tip güvenli domain hataları. Mutasyonlar başarıda `null`,
/// hatada bu hiyerarşiden bir örnek döndürür; UI `message` alanını gösterir,
/// testler `isA<...>()` ile türü doğrular.
sealed class DomainError {
  const DomainError();
  String get message;
}

class NotFoundError extends DomainError {
  @override
  final String message;
  const NotFoundError(this.message);
}

class UnauthorizedError extends DomainError {
  @override
  final String message;
  const UnauthorizedError([this.message = 'Bu işlem için yetkiniz yok']);
}

class InvalidStateError extends DomainError {
  @override
  final String message;
  const InvalidStateError(this.message);
}

class InsufficientBalanceError extends DomainError {
  @override
  final String message;
  const InsufficientBalanceError(this.message);
}

class DuplicateOfferError extends DomainError {
  @override
  String get message => 'Bu ilana zaten teklif verdiniz';
  const DuplicateOfferError();
}

class OwnListingOfferError extends DomainError {
  @override
  String get message => 'Kendi ilanınıza teklif veremezsiniz';
  const OwnListingOfferError();
}

/// İLETİŞİM ZATEN AÇIK — ⚠ BAŞARISIZLIK DEĞİL.
///
/// API sözleşmesi §10: iletişim açma İDEMPOTENTTİR. İkinci istek
/// ikinci tahsilat yapmaz ve sunucu "zaten açık" der. İstenen durum
/// zaten sağlandığı için çağıran taraf bunu BAŞARI gibi ele almalı,
/// kullanıcıya kırmızı hata göstermemelidir.
///
/// ⚠ Ayrı bir tip olması şart: `InvalidStateError` ile karışırsa
/// ekranlar bunu gerçek bir engel sanıp kullanıcıyı durdurur.
class IletisimZatenAcikError extends DomainError {
  @override
  String get message => 'İletişim zaten açık';
  const IletisimZatenAcikError();
}

class ListingClosedError extends DomainError {
  @override
  String get message => 'Bu ilan artık teklif kabul etmiyor';
  const ListingClosedError();
}

class OtpRequiredError extends DomainError {
  @override
  String get message => 'Devam etmek için telefon doğrulaması (SMS) gerekli';
  const OtpRequiredError();
}

class WrongPasswordError extends DomainError {
  @override
  final String message;
  const WrongPasswordError([this.message = 'Şifre hatalı']);
}

class AuthFailedError extends DomainError {
  @override
  String get message => 'Telefon numarası veya şifre hatalı';
  const AuthFailedError();
}

/// ── ⚠ TAŞIMA KATMANI HATALARI ──
///
/// Bunlar KULLANICININ YAPTIĞI bir şeyden kaynaklanmaz; ağ, sunucu ya
/// da zamanlama sorunudur. Eskiden hepsi `ValidationError` olarak
/// dönüyordu ve ekran "form hatası" ile "internet yok"u AYIRT
/// EDEMİYORDU — ikisi de aynı kırmızı satır oluyordu.
///
/// ⚠ Ayrı tür olmalarının tek amacı budur: ekran doğru GÖSTERİM
/// biçimini seçebilsin (şerit mi, tam ekran mı, bildirim mi).

/// Kartın bakiyesi/limiti işlem için yetmedi.
///
/// ⚠ `InsufficientBalanceError` ile KARIŞTIRILMAZ: o bizim CÜZDAN
/// bakiyemiz içindir, bu KARTIN bakiyesidir.
class KartBakiyesiYetersizError extends DomainError {
  @override
  final String message;
  const KartBakiyesiYetersizError(this.message);
}

/// İnternet yok ya da sunucuya hiç ulaşılamadı.
class NetworkError extends DomainError {
  @override
  final String message;
  const NetworkError(this.message);
}

/// İstek gönderildi ama süresinde yanıt gelmedi.
class TimeoutError extends DomainError {
  @override
  final String message;
  const TimeoutError(this.message);
}

/// Sunucu hata verdi (5xx). Kullanıcının yapabileceği bir şey yok.
class ServerError extends DomainError {
  @override
  final String message;
  const ServerError(this.message);
}

/// Planlı bakım (503).
class MaintenanceError extends DomainError {
  @override
  final String message;
  const MaintenanceError(this.message);
}

class ValidationError extends DomainError {
  @override
  final String message;
  const ValidationError(this.message);
}
