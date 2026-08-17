/// İş kuralı sabitleri — UI'dan bağımsız domain konfigürasyonu.
/// (Görsel değerler lib/core/theme.dart içindedir; burada yalnız iş kuralı yaşar.)
/// İlan açıklaması için karakter sınırı (referans `.rv-cnt` sayacı).
const int kAciklamaMaxLength = 1000;

/// SOHBET MESAJI — en fazla karakter.
///
/// ⚠ SINIR YOKTU. Kullanıcı sınırsız uzunlukta metin gönderebiliyordu:
/// yapıştırılan devasa metin hem sohbet listesini kilitler hem de
/// backend'e taşındığında istek gövdesini şişirir. Sunucu tarafında
/// da AYNI sınır uygulanmalıdır — istemci sınırı kullanıcı kolaylığı
/// içindir, güvenlik denetimi değildir.
const int kMesajMaxLength = 1000;

/// İlan açıklamasında istenen en az kelime sayısı.
const int kMinAciklamaKelime = 5;

abstract final class DomainConfig {
  /// İletişim açma ücreti; teklif verilirken bu tutar bloke edilir.
  static const int contactFee = 50;

  /// Minimum bakiye yükleme tutarı.
  static const int minTopup = 500;

  /// ── ⚠ TEK İŞLEMDE ÜST SINIR ──
  ///
  /// Hatalı basımda (fazladan sıfır) beklenmeyen tutarda para çekilmesini
  /// önler: 5000 yerine 50000 yazan kullanıcı sınırı aşamaz.
  ///
  /// ⚠ Toplam bakiye sınırı DEĞİLDİR; kullanıcı birden çok işlemle
  /// daha fazla yükleyebilir. Amaç tek seferlik kazayı engellemek.
  static const int maxTopup = 10000;

  /// Uygulamayı Paylaş metni (tek merkez).
  static const String shareText =
      'HizmetCep ile İzmir\'de güvenilir ustalara ücretsiz ilan verin, '
      'dakikalar içinde teklif alın! İndirmek için: https://hizmetcep.app';

  // Mağaza bağlantıları buradan KALDIRILDI.
  // Gerçek platform kimlikleri data/store_links.dart içindedir ve
  // --dart-define ile geçilebilir (ANDROID_PACKAGE / IOS_APP_STORE_ID).

  /// İlan yayın süresi: her ilan yayınlandığı andan itibaren 30 SAAT aktiftir
  /// (expiresAt = createdAt + listingLifetime).
  static const Duration listingLifetime = Duration(hours: 30);

  /// HİZMET BÖLGESİ OTOMATİK GENİŞLEME EŞİĞİ
  ///
  /// Sağlayıcının seçtiği ilçelerde, seçtiği kategoride bu süreden
  /// uzun zamandır YENİ ilan düşmediyse kapsam İL GENELİNE genişler.
  /// Amaç: sağlayıcının boş ekranla beklememesi.
  static const Duration areaExpandAfter = Duration(hours: 1);
}
