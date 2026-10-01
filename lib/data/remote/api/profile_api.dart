import '../api_client.dart';

/// /users ve /profiles uçları.
class ProfileApi {
  final ApiClient c;
  ProfileApi(this.c);

  Future<Map<String, dynamic>> me() => c.get('/users/me');

  Future<Map<String, dynamic>> setActiveRole(String role) =>
      c.post('/users/me/active-role', body: {'role': role});

  Future<Map<String, dynamic>> updateProfile({String? name, String? email, String? photoRef}) =>
      c.patch('/profiles/me', body: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (photoRef != null) 'photoRef': photoRef,
      });

  /// E-POSTA DEĞİŞİMİ — doğrulama bağlantısı ister.
  ///
  /// ⚠ BU ÇAĞRI E-POSTAYI DEĞİŞTİRMEZ. Sunucu yeni adrese bağlantı
  /// yollar; hesabın e-postası bağlantı tıklanana kadar ESKİ kalır
  /// (iş kuralları §4).
  ///
  /// ⚠ `updateProfile` ile e-posta GÖNDERİLMEZ — doğrulamayı
  /// atlatmak olurdu.
  Future<Map<String, dynamic>> changeEmail({required String newEmail}) =>
      c.post('/profiles/me/email/change',
          body: {'newEmail': newEmail},
          idempotencyKey: ApiClient.newIdempotencyKey());

  Future<Map<String, dynamic>> changePhone(
          {required String newPhone, required String otpCode, String? firebaseIdToken}) =>
      c.post('/profiles/me/phone/change', body: {
        'newPhone': newPhone, 'otpCode': otpCode,
        if (firebaseIdToken != null) 'firebaseIdToken': firebaseIdToken,
      });

  /// TEK adres: kayıt yoksa sunucu null döner.
  Future<Map<String, dynamic>?> address() => c.getOrNull('/profiles/me/address');

  /// Tek adres kaydını oluşturur veya günceller (upsert).
  Future<Map<String, dynamic>> saveAddress({
    required String city,
    required String district,
    required String neighborhood,
  }) =>
      c.put('/profiles/me/address', body: {
        'city': city,
        'district': district,
        'neighborhood': neighborhood,
      });
  Future<Map<String, dynamic>> providerProfile() => c.get('/profiles/me/provider');
  Future<Map<String, dynamic>> saveProviderProfile({
    required List<String> categories,
    required List<String> districts,
  }) =>
      c.put('/profiles/me/provider', body: {'categories': categories, 'districts': districts});

  /// Hizmet veren platform onay durumu.
  Future<Map<String, dynamic>> providerApproval() =>
      c.get('/profiles/me/provider/approval');
}
