import '../api_client.dart';

/// KATALOG — kanonik uç `GET /categories`.
///
/// ⚠ KATALOG OTORİTESİ BACKEND'DİR. Admin panelinden kategori/hizmet
/// eklenip pasifleştirilebildiği için liste sunucudan gelir; uygulama
/// içindeki gömülü katalog yalnızca yedektir.
///
/// ⚠ ALTERNATİF UÇ AÇILMAZ: `/categories/me`, `/my/categories`,
/// `/mobile/categories` gibi karşılıklar üretilmez. Android, iOS ve
/// Web AYNI ucu kullanır.
class CategoryApi {
  final ApiClient c;
  CategoryApi(this.c);

  /// Kategori ağacını getirir.
  ///
  /// ⚠ Kimlik doğrulaması istemez: katalog, giriş yapmamış kullanıcı
  /// için de gereklidir (kayıtsız ilan akışı kategori seçtiriyor).
  Future<Map<String, dynamic>> tree() => c.get('/categories');

  /// Sunucu yanıtını `kategori → hizmetler` biçimine çevirir.
  ///
  /// ── ⚠ PASİF KAYITLAR BURADA SÜZÜLÜR ──
  ///
  /// `active: false` gelen kategori yeni ilanda SEÇİLEMEZ (§32), bu
  /// yüzden aktif kataloğa hiç alınmaz. Süzmeyi tek yerde yapmak
  /// önemli: ekranlar tek tek `active` kontrolü yazsaydı biri
  /// unutulurdu.
  ///
  /// ⚠ BOZUK KAYIT SESSİZCE ATLANIR, TAHMİN EDİLMEZ. Adı olmayan ya
  /// da hizmet listesi boş olan kayıt kullanılamaz; uydurma bir ad
  /// üretmek yerine o kayıt alınmaz.
  ///
  /// ⚠ İSTEMCİ KİMLİK ÜRETMEZ: kategori ve hizmet, sunucunun verdiği
  /// ADLARIYLA taşınır. Addan kimlik türetme, index'i kimlik sayma
  /// ya da rastgele kimlik üretme YAPILMAZ.
  /// Kategori → ikon dosyası (sunucu `icon` alanı; yoksa boş).
  static Map<String, String> ikonlar(Map<String, dynamic> j) {
    final ham = j['items'];
    if (ham is! List) {
      return const {};
    }
    return {
      for (final e in ham.whereType<Map<String, dynamic>>())
        if (e['category'] is String && e['icon'] is String) e['category'] as String: e['icon'] as String,
    };
  }

  static Map<String, List<String>> parse(Map<String, dynamic> j) {
    final ham = j['items'];
    if (ham is! List) {
      return const {};
    }
    final out = <String, List<String>>{};
    for (final e in ham) {
      if (e is! Map) {
        continue;
      }
      final ad = e['category'];
      if (ad is! String || ad.trim().isEmpty) {
        continue;
      }
      // ⚠ `active` alanı GELMEYEBİLİR. Yokluğunu "pasif" saymak tüm
      // katalogu boşaltırdı; varsayılan AKTİF'tir.
      if (e['active'] == false) {
        continue;
      }
      final hizmetler = <String>[];
      final liste = e['services'];
      if (liste is List) {
        for (final h in liste) {
          if (h is String && h.trim().isNotEmpty) {
            hizmetler.add(h);
          }
        }
      }
      if (hizmetler.isEmpty) {
        continue;
      }
      out[ad] = hizmetler;
    }
    return out;
  }
}
