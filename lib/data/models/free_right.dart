/// ÜCRETSİZ İLETİŞİM AÇMA HAKKI — istemci modeli
///
/// ⚠ Bu hak PARA DEĞİLDİR.
/// Cüzdan bakiyesi, jeton veya promosyon bakiyesi değildir.
/// Nakde çevrilemez, devredilemez, cüzdana aktarılamaz.
///
/// Hizmet Alan tarafında ASLA gösterilmez.
library;

/// Teklif bedelinin hangi kaynaktan karşılanacağı.
enum OfferFundingSource {
  /// Cüzdandan parasal bloke.
  wallet,

  /// Ücretsiz iletişim hakkı — parasal bloke YOK.
  freeRight;

  static OfferFundingSource fromJson(String? v) =>
      v == 'FREE_RIGHT' ? OfferFundingSource.freeRight : OfferFundingSource.wallet;

  String get apiValue =>
      this == OfferFundingSource.freeRight ? 'FREE_RIGHT' : 'WALLET';
}

/// Hizmet verenin kullanılabilir ücretsiz hak özeti.
class FreeRightSummary {
  const FreeRightSummary({
    required this.remainingRights,
    required this.hasUsableRight,
    this.nextExpiryAt,
  });

  /// Kullanılabilir hak adedi. **Adet cinsindendir — TL değildir.**
  final int remainingRights;

  /// Şu an kullanılabilir hak var mı?
  final bool hasUsableRight;

  /// En yakın sona erme tarihi.
  final DateTime? nextExpiryAt;

  static const empty = FreeRightSummary(remainingRights: 0, hasUsableRight: false);

  factory FreeRightSummary.fromJson(Map<String, dynamic> j) => FreeRightSummary(
        remainingRights: (j['remainingRights'] as num?)?.toInt() ?? 0,
        hasUsableRight: j['hasUsableRight'] as bool? ?? false,
        nextExpiryAt: j['nextExpiryAt'] == null
            ? null
            : DateTime.tryParse(j['nextExpiryAt'] as String),
      );
}

/// Teklif öncesi kaynak kararı — sunucu belirler, istemci SEÇMEZ.
class FundingDecision {
  const FundingDecision({required this.source, required this.aciklama});

  final OfferFundingSource source;

  /// Kullanıcıya gösterilecek metin. Sunucudan gelir; istemci uydurmaz.
  final String aciklama;

  bool get isFree => source == OfferFundingSource.freeRight;

  factory FundingDecision.fromJson(Map<String, dynamic> j) => FundingDecision(
        source: OfferFundingSource.fromJson(j['source'] as String?),
        aciklama: j['aciklama'] as String? ?? '',
      );
}
