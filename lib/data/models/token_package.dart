/// JETON PAKETİ — satın alınabilir bakiye paketi.
///
/// TEK OTORİTE BACKEND'DİR. Bu model yalnız GÖSTERİM içindir; fiyat ve
/// jeton miktarı ödeme başlatılırken istemciden GÖNDERİLMEZ. Sunucu
/// `packageId`'den paketi yeniden okur ve kendi snapshot'ını üretir.
///
/// Not: `GET /wallet/token-packages` yalnız satın alınabilir paketleri
/// döner (aktif + görünür + tarih aralığı geçerli). `startsAt`/`endsAt`
/// sunucu tarafında FİLTRE ÖLÇÜTÜDÜR ve cevapta bulunmaz; alanlar
/// ileride eklenirse diye opsiyonel tutulur.
library;

class TokenPackage {
  final String id;
  final String name;
  final int tokenAmount;
  final int bonusTokenAmount;
  final int priceTl;
  final String currency;
  final int sortOrder;

  /// Sunucu şu an döndürmüyor; alan gelirse ayrıştırılır.
  final DateTime? startsAt;
  final DateTime? endsAt;

  const TokenPackage({
    required this.id,
    required this.name,
    required this.tokenAmount,
    required this.bonusTokenAmount,
    required this.priceTl,
    required this.currency,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
  });

  /// Kullanıcının alacağı toplam jeton.
  /// Sunucu `totalTokenAmount` göndermiyorsa jeton + bonus olarak hesaplanır.
  int get totalTokenAmount => tokenAmount + bonusTokenAmount;

  bool get hasBonus => bonusTokenAmount > 0;

  /// Eksik/bozuk alanlar uygulamayı ÇÖKERTMEZ; geçersiz kayıt için null
  /// döner ve çağıran onu listeden eler.
  static TokenPackage? tryFromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final name = j['name'];
    final token = _asInt(j['tokenAmount']);
    final price = _asInt(j['priceTl']);

    // Kimlik, ad, jeton ve fiyat ZORUNLUDUR; biri geçersizse kayıt atılır.
    if (id is! String || id.isEmpty) {
      return null;
    }
    if (name is! String || name.trim().isEmpty) {
      return null;
    }
    if (token == null || token <= 0) {
      return null;
    }
    if (price == null || price <= 0) {
      return null;
    }

    // Bonus opsiyoneldir; yoksa veya geçersizse 0 kabul edilir.
    final bonus = _asInt(j['bonusTokenAmount']) ?? 0;

    return TokenPackage(
      id: id,
      name: name.trim(),
      tokenAmount: token,
      bonusTokenAmount: bonus < 0 ? 0 : bonus,
      priceTl: price,
      // Şu an yalnız TRY gösterilir.
      currency: (j['currency'] as String?)?.trim().isNotEmpty == true
          ? j['currency'] as String
          : 'TRY',
      sortOrder: _asInt(j['sortOrder']) ?? 0,
      startsAt: _asDate(j['startsAt']),
      endsAt: _asDate(j['endsAt']),
    );
  }

  /// Liste ayrıştırma — geçersiz kayıtlar sessizce ELENİR, diğerleri kalır.
  static List<TokenPackage> listFrom(List<dynamic> raw) {
    final out = <TokenPackage>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) {
        continue;
      }
      final p = tryFromJson(e);
      if (p != null) {
        out.add(p);
      }
    }
    // Sunucu sırası korunur; sortOrder eşitse fiyata göre.
    out.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.priceTl.compareTo(b.priceTl);
    });
    return out;
  }

  static int? _asInt(Object? v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    if (v is String) {
      return int.tryParse(v);
    }
    return null;
  }

  static DateTime? _asDate(Object? v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }
}
