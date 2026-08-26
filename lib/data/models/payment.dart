/// ÖDEME OTURUMU — SAĞLAYICIDAN BAĞIMSIZ MODEL
///
/// GÜVENLİK KURALI: Uygulama kart numarası, CVV veya son kullanma tarihi
/// TOPLAMAZ, TAŞIMAZ ve HizmetCep backend'ine GÖNDERMEZ. Kullanıcı kart
/// bilgisini yalnız ödeme sağlayıcısının kendi sayfasında girer.
///
/// Akış:
///   1) backend oturum açar        → PaymentSession(status: pending, redirectUrl)
///   2) kullanıcı sağlayıcı sayfasını tamamlar (harici tarayıcı)
///   3) uygulama backend'e sorar   → backend sağlayıcıdan DOĞRULAR
///   4) yalnız succeeded ise bakiye artar
library;

enum PaymentStatus {
  /// Kullanıcı sağlayıcı ekranını henüz tamamlamadı — sorgulamaya devam.
  pending,

  /// Sağlayıcı ödemeyi onayladı, bakiye yüklendi.
  succeeded,

  /// Sağlayıcı reddetti.
  failed,

  /// Kullanıcı vazgeçti.
  cancelled,

  /// Oturum zaman aşımına uğradı.
  expired;

  static PaymentStatus parse(String? raw) => switch ((raw ?? '').toUpperCase()) {
        'SUCCEEDED' => PaymentStatus.succeeded,
        'FAILED' => PaymentStatus.failed,
        'CANCELLED' => PaymentStatus.cancelled,
        'EXPIRED' => PaymentStatus.expired,
        _ => PaymentStatus.pending,
      };

  bool get isFinal => this != PaymentStatus.pending;

  /// Kullanıcıya gösterilecek metin.
  String get label => switch (this) {
        PaymentStatus.pending => 'Ödeme bekleniyor',
        PaymentStatus.succeeded => 'Ödeme başarılı',
        PaymentStatus.failed => 'Ödeme alınamadı',
        PaymentStatus.cancelled => 'Ödeme iptal edildi',
        PaymentStatus.expired => 'Ödeme süresi doldu',
      };
}

class PaymentSession {
  final String sessionId;
  final String providerRef;
  final int amountTl;
  final PaymentStatus status;

  /// Sağlayıcının ödeme sayfası. Kart bilgisi BURADA girilir.
  final String? redirectUrl;

  /// Sağlayıcı SDK'sı kullanılacaksa istemci anahtarı.
  final String? clientSecret;

  const PaymentSession({
    required this.sessionId,
    required this.providerRef,
    required this.amountTl,
    required this.status,
    this.redirectUrl,
    this.clientSecret,
  });

  /// Sağlayıcı ekranı açılabilir mi?
  bool get canOpenProvider =>
      (redirectUrl != null && redirectUrl!.isNotEmpty) ||
      (clientSecret != null && clientSecret!.isNotEmpty);

  factory PaymentSession.fromJson(Map<String, dynamic> j) => PaymentSession(
        sessionId: j['sessionId'] as String? ?? '',
        providerRef: j['providerRef'] as String? ?? '',
        amountTl: (j['amountTl'] as num?)?.toInt() ?? 0,
        status: PaymentStatus.parse(j['status'] as String?),
        redirectUrl: j['redirectUrl'] as String?,
        clientSecret: j['clientSecret'] as String?,
      );
}
