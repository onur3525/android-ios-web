import 'package:google_sign_in/google_sign_in.dart';

/// GOOGLE İLE GİRİŞ — istemci tarafı
///
/// ⚠ Bu sınıf YALNIZ `idToken` alır ve sunucuya iletir.
/// Kullanıcı adı, e-posta veya fotoğraf sunucuya GÖNDERİLMEZ:
/// bunlar `id_token` içinden Google'da doğrulanarak okunur.
///
/// `GOOGLE_CLIENT_ID` sunucuda tanımsızsa uç açık hata döner;
/// istemci sahte başarı ÜRETMEZ.
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? client})
      : _client = client ?? GoogleSignIn(scopes: const ['email', 'profile']);

  final GoogleSignIn _client;

  /// Google oturumu açar ve kimlik jetonunu döner.
  /// Kullanıcı vazgeçerse `null` döner — hata DEĞİLDİR.
  Future<String?> signInIdToken() async {
    final hesap = await _client.signIn();
    if (hesap == null) return null; // kullanıcı vazgeçti
    final auth = await hesap.authentication;
    return auth.idToken;
  }

  /// Oturumu kapatır (yerel Google oturumu).
  Future<void> signOut() => _client.signOut();
}
