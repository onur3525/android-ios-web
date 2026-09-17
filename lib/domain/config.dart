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
const int kMinAciklamaKelime = 3;

abstract final class DomainConfig {
  /// Bir ilana verilebilecek EN FAZLA teklif sayısı.
  ///
  /// ⚠ Bu bir ÜCRET ya da hizmet veren kotası DEĞİLDİR: ilan sahibi
  /// yönetilebilir sayıda teklif görsün diye konmuş ürün kuralıdır.
  /// Hizmet verenin kaç ilana teklif verebileceği SINIRSIZDIR.
  static const int ilanBasinaMaxTeklif = 3;


  // ── ⚠ YORUM KURALLARI ──
  //
  // ⚠ SINIR 300 (kullanıcı kararı, 16 Eyl): "yorum yapma karakter
  // sayısı şu an 1000 görünüyor, onu 300 yapalım; 300 karakterden
  // fazla yazı yazılamasın."
  //
  // TARİHÇE: prototipte `maxlength=500`, API sözleşmesi §14'te 1000
  // yazıyordu. Kullanıcı kararı ikisini de EZER.
  //
  // ⚠ SUNUCU DA AYNI SINIRI UYGULAMALIDIR: istemcideki `maxLength`
  // yalnız yazmayı engeller; paketi değiştiren biri daha uzun metin
  // gönderebilir.
  //
  // ⚠ TEK KAYNAK: iki yorum ekranı da (ilan akışı ve Bul akışı) bu
  // sabiti okur; sayı ekranlara elle yazılmaz.
  static const int kYorumMaxKarakter = 300;

  /// ⚠ DEĞERLENDİRME ANINDA YANSIR (kullanıcı kararı, 9 Eyl).
  ///
  /// "Bir hizmet verene yorum/puan yapıldığı anda hizmet veren
  /// profiline bunlar ANINDA yansısın ve o hizmet verenin TÜM
  /// kartlarında anında görünsün."
  ///
  /// ⚠ ÖNCEKİ KURAL EZİLDİ: §14 / kabul testi 15 uyarınca burada
  /// `Duration(days: 1)` yazıyordu — yorum anında kaydedilir ama
  /// hizmet verenin ortalamasına ve listesine bir gün sonra girerdi.
  /// Gerekçesi, sıcağı sıcağına yazılan yorumun düzeltilme/silinme
  /// baskısı olmadan yerleşmesiydi. Kullanıcı bu davranışı
  /// istemediğini açıkça bildirdi.
  ///
  /// ⚠ MEKANİZMA SİLİNMEDİ: süzgeç ve `yayinlandiMi` yerinde duruyor,
  /// yalnız süre sıfır. Karar değişirse tek satır yeter — kural
  /// yeniden ekranlara dağıtılmaz.
  ///
  /// ⚠ SUNUCU SON SÖZÜ SÖYLER: `Review.status` alanı geldiğinde o
  /// öncelikli kalır; buradaki süre yalnız yerel köprüdür.
  static const Duration yorumYayinGecikmesi = Duration.zero;

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
