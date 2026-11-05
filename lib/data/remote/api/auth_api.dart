import '../api_client.dart';

/// /auth uçları. ŞİFRE İSTEMCİDE HASH'LENMEZ ve SAKLANMAZ —
/// düz metin yalnız TLS üzerinden gönderilir, hash'i backend üretir.
class AuthApi {
  final ApiClient c;
  AuthApi(this.c);

  Future<void> requestOtp({required String phone, required String purpose}) =>
      c.post('/auth/otp/request', body: {'phone': phone, 'purpose': purpose});

  /// 4 Kas: SMS'i Firebase gönderdiğinde her koddan ÖNCE sunucu izni
  /// (60 sn / 3 kod / 15 dk kuralı sunucuda sayılır).
  Future<Map<String, dynamic>> otpPermit({required String phone, required String purpose}) =>
      c.post('/auth/otp/permit', body: {'phone': phone, 'purpose': purpose});

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    required String email,
    required String role,
    required String otpCode,
    String? firebaseIdToken,
    // 4 Kas: SMS'siz kayıtta Firebase e-posta/şifre kullanıcısının belgesi
    // (hesap ona bağlanır; e-posta ile giriş ve doğrulama korunur).
    String? firebaseEmailToken,
    // ⚠ 15 Eki: sunucu Kullanım Sözleşmesi onayını ZORUNLU tutar; yalnız
    // gerçek `true` kabul edilir. 16 Eki: ayrı 18 yaş beyanı kaldırıldı —
    // yaş koşulu sözleşmenin 4. maddesindedir.
    required bool termsAccepted,
    // 4 Kas: isteğe bağlı ticari elektronik ileti izni.
    bool marketingConsent = false,
    String? platform,
  }) =>
      c.post('/auth/register', body: {
        'phone': phone, 'password': password, 'name': name,
        'email': email, 'role': role, 'otpCode': otpCode,
        'termsAccepted': termsAccepted,
        // 16 Eki: kayıt ekranında iki zorunlu onay var; `termsAccepted` ancak
        // Kullanım Sözleşmesi VE Aydınlatma Metni işaretliyse true olur.
        // Sunucu onay kaydını bu iki belgeye yazar.
        'aydinlatmaAccepted': termsAccepted,
        'marketingConsent': marketingConsent,
        if (platform != null) 'platform': platform,
        // Firebase telefon doğrulamasının kanıtı (sunucu doğrular).
        if (firebaseIdToken != null) 'firebaseIdToken': firebaseIdToken,
        if (firebaseEmailToken != null) 'firebaseEmailToken': firebaseEmailToken,
      });

  /// Firebase ile doğrulanmış kimlikle HizmetCep oturumu (sunucu token'ı
  /// doğrular, UID'yi hesaba bağlar, kendi oturumunu verir).
  Future<Map<String, dynamic>> firebaseSession(String idToken) =>
      c.post('/auth/firebase/session', body: {'idToken': idToken});

  /// 4 Kas: Google/Apple ile KAYIT. Hesap şifresiz açılır; telefon ve
  /// adres profil tamamlamada alınır. Bu kimliğin hesabı varsa sunucu yeni
  /// hesap açmaz (rol yoksa ekler, oturum açar).
  Future<Map<String, dynamic>> firebaseRegister({
    required String idToken,
    required String role,
    String? name,
    required bool termsAccepted,
    bool marketingConsent = false,
    String? platform,
  }) =>
      c.post('/auth/firebase/register', body: {
        'idToken': idToken,
        'role': role,
        if (name != null) 'name': name,
        'termsAccepted': termsAccepted,
        // E-postalı kayıtla aynı: iki kutu da işaretliyse true.
        'aydinlatmaAccepted': termsAccepted,
        'marketingConsent': marketingConsent,
        if (platform != null) 'platform': platform,
      });

  Future<Map<String, dynamic>> login({required String phone, required String password}) =>
      c.post('/auth/login', body: {'phone': phone, 'password': password});

  Future<void> logout() => c.post('/auth/logout');

  Future<void> changePassword({required String current, required String next}) =>
      c.post('/auth/password/change', body: {'currentPassword': current, 'newPassword': next});

  Future<void> forgotComplete({
    required String phone,
    required String otpCode,
    required String newPassword,
    String? firebaseIdToken,
  }) =>
      c.post('/auth/forgot/complete', body: {
        'phone': phone, 'otpCode': otpCode, 'newPassword': newPassword,
        if (firebaseIdToken != null) 'firebaseIdToken': firebaseIdToken,
      });

  /// Rol ekleme: yalnız rol. 5 Kas (kullanıcı kararı): kimlik doğrulaması
  /// (şifre / Google-Apple yeniden girişi) İSTENMEZ; 21 Eki: telefon/SMS de
  /// istenmez.
  Future<void> addRole({required String role}) =>
      c.post('/auth/roles/add', body: {'role': role});

  /// Google/Apple hesabına şifre oluşturma (5 Kas). [firebaseIdToken]: bu
  /// hesabın son 10 dakikadaki girişinin Firebase belgesi.
  Future<void> setPassword(
          {required String newPassword, required String firebaseIdToken}) =>
      c.post('/auth/password/set', body: {
        'newPassword': newPassword,
        'firebaseIdToken': firebaseIdToken,
      });

  Future<List<dynamic>> sessions() => c.getList('/auth/sessions');
  Future<void> revokeSession(String jti) => c.post('/auth/sessions/$jti/revoke');

  /// Şifre doğrulama — kritik işlem kapısı (hesap silme).
  ///
  Future<void> verifyPassword({required String password}) =>
      c.post('/auth/verify-password', body: {'password': password});
}
