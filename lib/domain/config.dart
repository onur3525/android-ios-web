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
  /// Bir ilana verilebilecek EN FAZLA teklif sayısı.
  ///
  /// ⚠ Bu bir ÜCRET ya da hizmet veren kotası DEĞİLDİR: ilan sahibi
  /// yönetilebilir sayıda teklif görsün diye konmuş ürün kuralıdır.
  /// Hizmet verenin kaç ilana teklif verebileceği SINIRSIZDIR.
  static const int ilanBasinaMaxTeklif = 3;


  // ── ⚠ YORUM KURALLARI (API sözleşmesi §14) ──
  //
  // Belge HTML prototipine ÜSTÜNDÜR (§31). Prototipte `maxlength=500`
  // yazıyordu; sözleşme 1000 diyor. Asgari kelime kuralı prototipte
  // HİÇ YOKTU.
  static const int kYorumMaxKarakter = 1000;

  /// ⚠ DEĞERLENDİRME 1 GÜN SONRA YANSIR (§14, kabul testi 15).
  ///
  /// Yorum anında kaydedilir ama hizmet verenin ortalamasına ve
  /// yorum listesine bu süre dolmadan GİRMEZ. Amaç, sıcağı sıcağına
  /// yazılan yorumun düzeltilme/silinme baskısı olmadan yerleşmesi.
  static const Duration yorumYayinGecikmesi = Duration(days: 1);

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
