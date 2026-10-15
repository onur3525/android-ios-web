import '../api_client.dart';

/// /users ve /profiles uçları.
class ProfileApi {
  final ApiClient c;
  ProfileApi(this.c);

  Future<Map<String, dynamic>> me() => c.get('/users/me');

  /// KARŞI TARAF ÖZETİ — yalnız ilişkisi olan kullanıcı için döner (404).
  /// Telefon ve tam ad sunucunun kurallarına göre gelir.
  Future<Map<String, dynamic>> kisiOzeti(String id) =>
      c.get('/users/${Uri.encodeComponent(id)}/summary');

  Future<Map<String, dynamic>> setActiveRole(String role) =>
      c.post('/users/me/active-role', body: {'role': role});

  /// Ad güncellemesi. Fotoğraf AYRI ucu kullanır ([updatePhoto]): yerel
  /// dosya yolu sunucuya referans diye GÖNDERİLMEZ.
  Future<Map<String, dynamic>> updateProfile({String? name, String? email}) =>
      c.patch('/profiles/me', body: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      });

  /// PROFİL FOTOĞRAFI (rol bazlı). [ref]: `profile-photo` türünde
  /// YÜKLENMİŞ depo referansı; `null` fotoğrafı kaldırır. Sunucu dosyayı
  /// doğrular, eskisini silme kuyruğuna alır ve `photos` alanında imzalı
  /// adresleri döndürür.
  Future<Map<String, dynamic>> updatePhoto(String? ref, String role) =>
      c.patch('/profiles/me', body: {'photoRef': ref, 'photoRole': role});

  /// Bildirim tercihleri (Hesap Ayarları). Yalnız verilen alanlar değişir;
  /// sunucu güncel dört değeri döndürür. Push gönderimi bunlara uyar.
  Future<Map<String, dynamic>> updateNotificationPrefs(
          Map<String, bool> degisenler) =>
      c.patch('/profiles/me/notifications', body: degisenler);

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
