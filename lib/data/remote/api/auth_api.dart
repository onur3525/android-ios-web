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
  }) =>
      c.post('/auth/register', body: {
        'phone': phone, 'password': password, 'name': name,
        'email': email, 'role': role, 'otpCode': otpCode,
      });

  Future<Map<String, dynamic>> login({required String phone, required String password}) =>
      c.post('/auth/login', body: {'phone': phone, 'password': password});

  // ⚠ `POST /auth/google` KALDIRILDI — üçüncü taraf girişi yok.
  //
  // ⚠ SÖZLEŞMEDEN DE ÇIKARILDI: istemcinin çağırmadığı bir ucu
  // sözleşmede bırakmak, backend'in gereksiz yere uygulamasına yol
  // açardı.

  Future<void> logout() => c.post('/auth/logout');

  Future<void> changePassword({required String current, required String next}) =>
      c.post('/auth/password/change', body: {'currentPassword': current, 'newPassword': next});

  Future<void> forgotComplete({
    required String phone,
    required String otpCode,
    required String newPassword,
  }) =>
      c.post('/auth/forgot/complete',
          body: {'phone': phone, 'otpCode': otpCode, 'newPassword': newPassword});

  Future<void> addRole({required String role, required String password, required String otpCode}) =>
      c.post('/auth/roles/add', body: {'role': role, 'password': password, 'otpCode': otpCode});

  Future<List<dynamic>> sessions() => c.getList('/auth/sessions');
  Future<void> revokeSession(String jti) => c.post('/auth/sessions/$jti/revoke');

  /// Şifre doğrulama — kritik işlem kapısı (hesap silme).
  ///
  /// ⚠ Şifreyi DEĞİŞTİRMEZ. Backend bu ucu açmalıdır.
  Future<void> verifyPassword({required String password}) =>
      c.post('/auth/verify-password', body: {'password': password});
}
