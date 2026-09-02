// HATA DİLİ — TEK MERKEZ
//
// ⚠ NEDEN VAR: aynı hata iki ekranda farklı cümleyle çıkıyordu ve
// hepsi tek bir kırmızı satıra düşüyordu. Kullanıcı ne yapacağını
// bilemiyordu: bekleyecek mi, tekrar mı denesin, giriş mi yapsın?
//
// ⚠ HER DURUMDA \"KULLANICI NE YAPABİLİR\" YAZAR. Yapabileceği bir şey
// yoksa bu AÇIKÇA söylenir; belirsiz bırakılmaz.
//
// ⚠ BU DOSYA METNİ VERİR, GÖSTERİMİ DEĞİL. Nerede ve nasıl çizileceği
// `HataBicimi` ile önerilir; son kararı ekran verir (liste ekranı tam
// ekran gösterir, form alan altında gösterir).
//
// ⚠ TEKNİK KOD KULLANICIYA GÖSTERİLMEZ.

import 'failures.dart';

/// Hatanın nasıl gösterileceği.
enum HataBicimi {
  /// Ekran kullanılabilir, iş arka planda — üstte ince şerit.
  serit,

  /// Gösterilecek veri yok — ortada başlık, açıklama ve eylem.
  tamEkran,

  /// Tek bir alana ait — alan altında kırmızı satır.
  alanAlti,

  /// İşlem başarısız ama ekran değişmiyor — alttan bildirim.
  bildirim,
}

/// Kullanıcıya gösterilecek hata bilgisi.
class HataBilgisi {
  const HataBilgisi({
    required this.baslik,
    required this.aciklama,
    required this.bicim,
    this.eylem,
  });

  /// Kısa ve net: ne oldu.
  final String baslik;

  /// Bir cümle: neden oldu ya da ne anlama geliyor.
  final String aciklama;

  /// Önerilen gösterim biçimi.
  final HataBicimi bicim;

  /// Kullanıcının atabileceği adımın etiketi.
  ///
  /// ⚠ `null` ise kullanıcının yapabileceği bir şey YOKTUR ve bu
  /// açıklamada söylenir — ekran düğme çizmez.
  final String? eylem;

  /// Yeniden denenebilir mi? (düğme çizilecek mi)
  bool get denenebilir => eylem != null;
}

/// ── ⚠ TEK ÇEVİRİ NOKTASI ──
///
/// Ekranlar `DomainError`'ı kendi cümlesine çevirmez; buradan sorar.
/// Yeni bir hata türü eklendiğinde derleyici burada uyarır.
HataBilgisi hataBilgisi(DomainError hata) {
  switch (hata) {
      return const HataBilgisi(
        baslik: 'Kart bakiyeniz yetersiz',
        aciklama: 'Bakiyeniz değişmedi. Farklı bir kartla deneyebilirsiniz.',
        eylem: 'Tekrar dene',
        bicim: HataBicimi.tamEkran,
      );
    case NetworkError():
      return const HataBilgisi(
        baslik: 'Sunucuya ulaşılamıyor',
        aciklama: 'İnternet bağlantınızı kontrol edip tekrar deneyin.',
        eylem: 'Tekrar dene',
        bicim: HataBicimi.tamEkran,
      );
    case TimeoutError():
      return const HataBilgisi(
        baslik: 'İşlem zaman aşımına uğradı',
        aciklama: 'Sunucu süresinde yanıt vermedi.',
        eylem: 'Tekrar dene',
        bicim: HataBicimi.bildirim,
      );
    case ServerError():
      // ⚠ Kullanıcının yapabileceği bir şey YOK; \"tekrar dene\" demek
      // onu boşuna uğraştırır.
      return const HataBilgisi(
        baslik: 'Şu an işlem yapılamıyor',
        aciklama: 'Sorun bizim tarafımızda. Kısa süre sonra tekrar bakın.',
        bicim: HataBicimi.tamEkran,
      );
    case MaintenanceError():
      return const HataBilgisi(
        baslik: 'Bakım çalışması sürüyor',
        aciklama: 'İşlemler geçici olarak durduruldu.',
        bicim: HataBicimi.tamEkran,
      );
    case UnauthorizedError():
      // ⚠ Oturum düşmesi bir HATA EKRANI değil, yönlendirmedir;
      // `SysState.sessionExpired` zaten giriş ekranına götürür.
      return const HataBilgisi(
        baslik: 'Oturumunuzun süresi doldu',
        aciklama: 'Devam etmek için tekrar giriş yapın.',
        eylem: 'Giriş yap',
        bicim: HataBicimi.tamEkran,
      );
    case NotFoundError():
      return const HataBilgisi(
        baslik: 'Bu kayıt artık yok',
        aciklama: 'Silinmiş ya da yayından kaldırılmış olabilir.',
        eylem: 'Listeye dön',
        bicim: HataBicimi.tamEkran,
      );
    // ── Aşağıdakiler KULLANICI GİRDİSİNE ait: alan altında gösterilir,
    // metin domain katmanından gelir (backend'in Türkçe mesajı).
    case ValidationError():
    case InvalidStateError():
    case DuplicateOfferError():
    case OwnListingOfferError():
    // ── ⚠ İLETİŞİM ZATEN AÇIK — BAŞARISIZLIK DEĞİL ──
    //
    // İletişim açma idempotenttir (§10): ikinci istek ikinci tahsilat
    // yapmaz ve sunucu "zaten açık" der. İstenen durum ZATEN
    // sağlandığı için `ContactController` bunu başarı gibi ele alır
    // ve buraya normalde HİÇ GELMEZ.
    //
    // ⚠ Yine de sessiz bırakılmaz: başka bir yol bu hatayı ekrana
    // taşırsa kullanıcı kırmızı bir uyarı değil, durumu anlatan nötr
    // bir bilgi görmeli.
    case IletisimZatenAcikError():
      return const HataBilgisi(
        baslik: 'İletişim zaten açık',
        aciklama: 'Karşı tarafın bilgilerine erişebilirsiniz.',
        bicim: HataBicimi.bildirim,
      );
    case ListingClosedError():
    case OtpRequiredError():
    case WrongPasswordError():
    case AuthFailedError():
      return HataBilgisi(
        baslik: hata.message,
        aciklama: '',
        bicim: HataBicimi.alanAlti,
      );
  }
}

/// ── ⚠ GEREKSİZ UYARI GÖSTERİLMEZ ──
///
/// Hata ekranı YALNIZ gerçekten başarısız olmuş bir istekten sonra
/// çizilir. Bu üç durumda ÇİZİLMEZ:
///   • istek hâlâ sürüyorsa (yükleniyor)
///   • hata yoksa
///   • hata var ama ekranda gösterilecek veri VARSA — kullanıcı
///     eskisini görmeye devam eder, üstüne hata basılmaz
///
/// ⚠ Boş liste HATA DEĞİLDİR: veri gerçekten yoksa \"kayıt yok\"
/// mesajı gösterilir, hata ekranı değil.
bool hataGosterilsinMi({
  required bool yukleniyor,
  required DomainError? hata,
  required bool veriVar,
}) =>
    !yukleniyor && hata != null && !veriVar;
