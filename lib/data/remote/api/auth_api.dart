import '../api_client.dart';

/// /auth uçları. ŞİFRE İSTEMCİDE HASH'LENMEZ ve SAKLANMAZ —
/// düz metin yalnız TLS üzerinden gönderilir, hash'i backend üretir.
class AuthApi {
  final ApiClient c;
  AuthApi(this.c);

  Future<void> requestOtp({required String phone, required String purpose}) =>
      c.post('/auth/otp/request', body: {'phone': phone, 'purpose': purpose});

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    required String email,
    required String role,
    required String otpCode,
    String? firebaseIdToken,
    // ⚠ 15 Eki: sunucu Kullanım Sözleşmesi onayını ZORUNLU tutar; yalnız
    // gerçek `true` kabul edilir. 16 Eki: ayrı 18 yaş beyanı kaldırıldı —
    // yaş koşulu sözleşmenin 4. maddesindedir.
    required bool termsAccepted,
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
        if (platform != null) 'platform': platform,
        // Firebase telefon doğrulamasının kanıtı (sunucu doğrular).
        if (firebaseIdToken != null) 'firebaseIdToken': firebaseIdToken,
      });

  /// Firebase ile doğrulanmış kimlikle HizmetCep oturumu (sunucu token'ı
  /// doğrular, UID'yi hesaba bağlar, kendi oturumunu verir).
  Future<Map<String, dynamic>> firebaseSession(String idToken) =>
      c.post('/auth/firebase/session', body: {'idToken': idToken});

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

  /// Rol ekleme: yalnız şifre. 21 Eki (kullanıcı kararı): telefon/SMS
  /// doğrulaması İSTENMEZ.
  Future<void> addRole({required String role, required String password}) =>
      c.post('/auth/roles/add', body: {'role': role, 'password': password});

  Future<List<dynamic>> sessions() => c.getList('/auth/sessions');
  Future<void> revokeSession(String jti) => c.post('/auth/sessions/$jti/revoke');

  /// Şifre doğrulama — kritik işlem kapısı (hesap silme).
  ///
  Future<void> verifyPassword({required String password}) =>
      c.post('/auth/verify-password', body: {'password': password});
}
