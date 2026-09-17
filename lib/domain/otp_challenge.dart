/// ═══════════════════════════════════════════════════════════════
/// TELEFON OTP CHALLENGE — TEK KULLANIMLIK, SÜRELİ, DENEME SINIRLI
///
/// ## NİÇİN VAR
///
/// Doğrulamanın AUTHORITATIVE noktası ekran OLAMAZ. Ekran yalnız kod
/// toplar; "bu kod doğru mu" sorusuna cevap veren tek yer bu
/// challenge'ı tutan katmandır.
///
/// ⚠ Bir tur `girisTelefonDogrula` kodu HİÇ okumuyordu; sonra yalnız
/// "6 hane mi" diye bakıyordu. İkisi de güvenlik denetimi DEĞİLDİR:
/// depoyu doğrudan çağıran herhangi bir kod `123456` yerine `000000`
/// yazıp oturum açabilirdi.
///
/// ## KURALLAR
///
/// · Challenge TELEFONA ve AMACA bağlıdır — giriş için üretilen bir
///   challenge telefon değiştirme akışında kullanılamaz.
/// · SÜRELİDİR: `expiresAt` geçtiyse reddedilir.
/// · DENEME SINIRLIDIR: `maxDeneme` aşılırsa challenge yakılır.
/// · TEK KULLANIMLIKTIR: başarılı doğrulamadan sonra `consumed`
///   işaretlenir ve bir daha kullanılamaz.
///
/// ⚠ Bunlar backend'in de uygulaması gereken kurallardır; buradaki
/// uygulama mock/istemci içindir. Gerçek güvenlik sunucudadır.
/// ═══════════════════════════════════════════════════════════════
library;

/// Challenge'ın hangi akış için üretildiği.
///
enum OtpAmac { giris, kayit, telefonDegisimi, hesapKurtarma }

class OtpChallenge {
  OtpChallenge({
    required this.id,
    required this.phone,
    required this.amac,
    required this.expiresAt,
    this.maxDeneme = 5,
  });

  final String id;

  /// Normalize edilmiş numara (0'sız 10 hane).
  final String phone;

  final OtpAmac amac;
  final DateTime expiresAt;
  final int maxDeneme;

  int deneme = 0;
  bool consumed = false;

  /// ── ⚠ SAAT DIŞARIDAN VERİLİR (Y7) ──
  ///
  /// Eskiden burada `DateTime.now()` okunuyordu. `expiresAt` ise
  /// deponun ENJEKTE EDİLEN saatiyle hesaplanıyordu. İki saat
  /// ayrışınca testler DUVAR SAATİNE bağlı hâle geliyordu: sahte
  /// saati geçmişe kuran testler, gerçek saat o ana yetişene kadar
  /// geçiyor, sonra kendiliğinden düşüyordu.
  ///
  /// ⚠ Aynı ayrışma üretimde de risk: sunucu saatiyle cihaz saati
  /// farklıysa challenge beklenmedik anda ölür. Karar tek yerde
  /// verilir; çağıran hangi saatle çalıştığını söyler.
  bool suresiDolduMu(DateTime simdi) => simdi.isAfter(expiresAt);

  /// Denemeler tükendi mi?
  bool get denemeBitti => deneme >= maxDeneme;

  /// Bu challenge hâlâ kullanılabilir mi?
  bool kullanilabilirMi(DateTime simdi) =>
      !consumed && !suresiDolduMu(simdi) && !denemeBitti;
}

/// Doğrulama sonucu — makine tarafından ayırt edilebilir.
///
/// ⚠ Kullanıcıya gösterilen metin ile bu sonuç AYRI şeylerdir;
/// çağıran katman metni kendi seçer (hesap enumerasyonu yapmadan).
enum OtpSonuc {
  basarili,

  /// Challenge yok ya da bu telefona/amaca ait değil.
  gecersizChallenge,

  /// Süre doldu.
  suresiDoldu,

  /// Daha önce kullanılmış.
  kullanilmis,

  /// Deneme hakkı bitti.
  denemeBitti,

  /// Kod yanlış.
  kodHatali,
}
