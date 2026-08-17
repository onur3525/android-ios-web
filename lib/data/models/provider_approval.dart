/// HİZMET VEREN PLATFORM ONAY DURUMU
///
/// ÜRÜN KURALI: hizmet veren kayıt olup profilini tamamlayabilir
/// (kimlik doğrulaması YOK), ancak ADMIN ONAYI olmadan teklif veremez.
///
/// Durum kullanıcıya teklif ekranına girmeden ÖNCE gösterilir; 403
/// beklenmez.
library;

enum ProviderApproval {
  /// İnceleme bekliyor — teklif veremez.
  pending,

  /// Onaylı — teklif verebilir.
  approved,

  /// Reddedildi — bilgilerini güncelleyip yeniden başvurabilir.
  rejected,

  /// Askıya alındı — teklif veremez.
  suspended;

  static ProviderApproval parse(String? raw) =>
      switch ((raw ?? '').toUpperCase()) {
        'APPROVED' => ProviderApproval.approved,
        'REJECTED' => ProviderApproval.rejected,
        'SUSPENDED' => ProviderApproval.suspended,
        // Bilinmeyen/boş değer ONAYLI SAYILMAZ (güvenli varsayılan).
        _ => ProviderApproval.pending,
      };

  /// Yalnız onaylı hesap teklif verebilir.
  bool get canPlaceOffer => this == ProviderApproval.approved;

  String get label => switch (this) {
        ProviderApproval.pending => 'İnceleniyor',
        ProviderApproval.approved => 'Onaylı',
        ProviderApproval.rejected => 'Onaylanmadı',
        ProviderApproval.suspended => 'Askıya alındı',
      };
}

class ProviderApprovalState {
  final ProviderApproval status;
  final String message;

  /// Red veya askıya alma gerekçesi (varsa).
  final String? reason;

  const ProviderApprovalState({
    required this.status,
    required this.message,
    this.reason,
  });

  bool get canPlaceOffer => status.canPlaceOffer;

  factory ProviderApprovalState.fromJson(Map<String, dynamic> j) =>
      ProviderApprovalState(
        status: ProviderApproval.parse(j['status'] as String?),
        message: j['message'] as String? ?? '',
        reason: j['reason'] as String?,
      );

  /// Sunucuya ulaşılamadığında kullanılan güvenli varsayılan:
  /// onaylı SAYILMAZ, ancak kullanıcıya hata değil bilgi gösterilir.
  static const unknown = ProviderApprovalState(
    status: ProviderApproval.pending,
    message: 'Hesap durumunuz alınamadı. Lütfen bağlantınızı kontrol edin.',
  );
}
