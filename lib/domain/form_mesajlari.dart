import 'config.dart';
// ⚠ Şifre uzunluk sabitleri buradan gelir; sayı iki yerde
// yazılmasın diye. Dart döngüsel içe aktarmaya izin verir ve
// `validators.dart` de bu dosyadaki mesajları kullanır — ikisi de
// yalnız sabit/statik üye okuduğu için sorun çıkmaz.
import '../core/validators.dart';

/// ═══════════════════════════════════════════════════════════════
/// FORM MESAJLARI — TEK KAYNAK
///
/// ## NİÇİN VAR
///
/// Aynı anlam uygulamada üç ayrı biçimde yazılıyordu:
///     "En az 1 hizmet kategorisi seçmelisiniz."
///     "En az bir hizmet kategorisi seçiniz"
///     "En az 1 kategori seçmeniz gerekmektedir."
/// Kullanıcı aynı kuralı her ekranda başka bir dille duyuyordu.
///
/// ⚠ EKRANLAR ARTIK METİN YAZMAZ, BURADAN ÇAĞIRIR. Yeni bir metin
/// gerekiyorsa önce buraya eklenir.
///
/// ## DİL KURALLARI
///
/// · Emir kipi: "…giriniz", "…seçiniz" — "Lütfen" ile başlanmaz.
/// · Suçlayıcı değil, ne yapılacağını söyler.
/// · Nokta KULLANILMAZ (tek cümlelik alan uyarısı).
/// · Sayı gerektiren metinler kuralın kendisinden beslenir
///   (`kMinAciklamaKelime` gibi) — elle yazılmaz, kural değişince
///   metin de değişir.
///
/// ## SINIFLANDIRMA
///
/// Bu dosya YALNIZ METİN tutar. Hatanın hangi sınıfa girdiği
/// (alan / alanlar arası / iş kuralı / sistem) ekranın state
/// yapısında ayrılır; metin ile sınıf karıştırılmaz.
/// ═══════════════════════════════════════════════════════════════
class FormMesaj {
  const FormMesaj._();

  // ── ALAN HATALARI (FIELD ERROR) ──

  static const zorunlu = 'Bu alan zorunludur';
  static const telefon = 'Geçerli bir telefon numarası giriniz';
  static const eposta = 'Geçerli bir e-posta adresi giriniz';

  // ── ŞİFRE KURALI MESAJLARI — TEK KAYNAK ──
  //
  // ⚠ SAYI ARTIK GÖMÜLÜ DEĞİL: `kPasswordMinLength` ve
  // `kPasswordMaxLength` sabitlerinden okunur. Eskiden "6" beş ayrı
  // yerde düz metin olarak yazılıydı (iki doğrulayıcı satırı, bu
  // sabit ve iki ekranın politika kutusu); sayı değişince biri
  // unutulursa ekranda eski değer kalıyordu.
  //
  // ⚠ METİNLER KISA TUTULUR. Uzun cümleler alanın içindeki hata
  // satırına sığmıyor ve üç noktayla KESİLİYORDU: 360 dp'lik
  // telefonda o satıra ~212 dp yer kalıyor.
  // ⚠ "Şifreniz" ÖNEKİ KALDIRILDI: metin 320 dp'lik telefonda hata
  // satırına sığmıyordu (191 dp / 172 dp yer). Alanın hangi alan
  // olduğu zaten belli; özne tekrar edilmiyor.
  static final sifreKisa =
      'En az $kPasswordMinLength karakter olmalıdır';
  static final sifreUzun =
      'En fazla $kPasswordMaxLength karakter olabilir';
  static const sifreArdisik = 'Ardışık karakter kullanılamaz';
  static const sifreTekrar = 'Aynı karakteri tekrar etmeyin';
  static const sifreYaygin = 'Bu şifre çok yaygın';

  /// ⚠ YALNIZ ŞİFRE DEĞİŞTİR EKRANINDA GEÇERLİDİR.
  ///
  /// Kurtarma akışında (Yeni Şifre Belirle) kullanıcı eski şifresini
  /// GİRMEZ; istemci karşılaştırma yapamaz, denetim SUNUCUYA aittir.
  /// Kayıt ekranında ise mevcut şifre kavramı yoktur.
  // ⚠ Kısaltıldı: uzun hâli (267 dp) hiçbir ekranda sığmıyordu.
  static const sifreEskisiyleAyni = 'Eski şifrenizle aynı olamaz';

  /// Ekranlardaki bilgi kutusunda gösterilen POLİTİKA ÖZETİ.
  ///
  /// ⚠ Ekranlara elle yazılmaz; sayı buradan gelir.
  static final sifrePolitikasi =
      'Şifreniz en az $kPasswordMinLength karakter olmalıdır. '
      'Ardışık, tekrar eden ve yaygın şifreler kabul edilmez.';

  // ── ALANLAR ARASI (CROSS-FIELD) ──

  static const sifrelerFarkli = 'Şifreler aynı olmalıdır';

  // ── İŞ KURALI / SUNUCU (BUSINESS) ──

  static const kimlikHatali = 'Telefon numarası veya şifre hatalı';
  static const mevcutSifreHatali = 'Mevcut şifreniz hatalı';
  static const telefonKullanimda =
      'Bu telefon numarası başka bir hesapta kullanılıyor';
  static const epostaKullanimda =
      'Bu e-posta adresi başka bir hesapta kullanılıyor';

  // ── TELEFON OTP ──
  //
  // ⚠ OTP YALNIZ TELEFON DOĞRULAMA İÇİNDİR.

  static const otpEksik = '6 haneli doğrulama kodunu eksiksiz giriniz';
  static const otpHatali = 'Doğrulama kodu hatalı';
  static const otpSuresiDoldu =
      'Doğrulama kodunun süresi doldu. Yeni kod isteyiniz.';
  static const otpCokDeneme =
      'Çok fazla doğrulama denemesi yaptınız. Bir süre sonra tekrar deneyin.';
  static const otpGonderilemedi =
      'Doğrulama kodu gönderilemedi. Lütfen tekrar deneyin.';

  // ⚠ `kodGonderildiNotr` KALDIRILDI (16 Ağu).
  //
  // Telefon yolunda nötr kutu artık gösterilmiyor: kod istendiğinde
  // doğrulama ekranı açılıyor ve yönlendirme orada yapılıyor.
  // Kayıtsızlık uyarısı ise daha önce enumeration gerekçesiyle
  // kaldırılmıştı; ikisi de geri getirilmemelidir.

  // ── SEÇİM HATALARI ──

  static const kategoriSec = 'En az bir hizmet kategorisi seçiniz';
  static const bolgeSec = 'En az bir hizmet ilçesi seçiniz';
  static const ilSec = 'İl seçiniz';
  static const ilceSec = 'İlçe seçiniz';
  static const mahalleSec = 'Mahalle seçiniz';
  static const puanSec = 'Puan seçiniz';

  /// ⚠ API sözleşmesi §14: yorum en az `kYorumMinKelime` kelimedir.
  static final yorumKisa =
      'Yorumunuz en az ${DomainConfig.kYorumMinKelime} kelime olmalıdır';

  /// İlan oluşturmada kategori adımı.
  ///
  /// ⚠ "Lütfen bir kategori seçin" DEĞİL — öteki seçim metinleriyle
  /// aynı kalıp.
  static const ilanKategoriSec = 'Kategori seçiniz';

  // ── TEKLİF / İLAN ──

  static const teklifTutari = 'Geçerli bir teklif tutarı giriniz';

  /// ⚠ SAYI KURALDAN GELİR: `kMinAciklamaKelime` değişirse metin de
  /// değişir, iki yerde ayrı sayı tutulmaz.
  static const teklifAciklama =
      'Açıklamanız en az $kMinAciklamaKelime kelime olmalıdır';

  /// İlan açıklaması — teklif açıklamasıyla AYNI kuralı kullanır.
  static const ilanAciklama =
      'Açıklamanız en az $kMinAciklamaKelime kelime olmalıdır';

  // ── KART ──

  static const kartSahibi = 'Kart sahibi adı ve soyadı geçerli olmalıdır';
  static const kartNumarasi = 'Geçerli bir kart numarası giriniz';
  static const kartSonKullanma = 'Son kullanma tarihi geçerli olmalıdır';
  static const kartCvv = 'Güvenlik kodu geçerli olmalıdır';

  // ── SİSTEM (SYSTEM ERROR) ──
  //
  // ⚠ BUNLAR ALAN ALTINDA GÖSTERİLMEZ. Belirli bir değerden
  // kaynaklanmazlar; form genelinde sunulurlar.

  static const baglantiYok =
      'Bağlantı kurulamadı. İnternetinizi kontrol edip tekrar deneyin.';
  static const zamanAsimi = 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.';

  // ── ŞİFRE SIFIRLAMA (E-POSTA) ──
  //
  // ⚠ HESAP VAR/YOK BİLGİSİ SIZDIRILMAZ: başarı metni hesap bulunsa
  // da bulunmasa da AYNIDIR.

  static const sifirlamaGonderildi =
      'Eğer bu e-posta adresiyle kayıtlı bir hesabınız varsa, şifre '
      'yenileme bağlantısı gönderildi. Lütfen e-posta kutunuzu kontrol edin.';
  static const sifirlamaGecersiz = 'Şifre yenileme bağlantısı geçersiz.';
  static const sifirlamaSuresiDoldu =
      'Şifre yenileme bağlantısının süresi dolmuş. Yeni bir bağlantı isteyin.';
  static const sifirlamaKullanilmis =
      'Bu şifre yenileme bağlantısı daha önce kullanılmış. Yeni bir bağlantı '
      'isteyin.';
  static const sifirlamaBasarili = 'Şifreniz başarıyla yenilendi.';
  static const sifirlamaCokIstek =
      'Çok fazla şifre yenileme isteği gönderdiniz. Bir süre sonra tekrar '
      'deneyin.';
}
