import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token deposu — Keychain (iOS) / EncryptedSharedPreferences (Android).
/// Tokenlar DÜZ METİN veya SharedPreferences içinde TUTULMAZ.
class TokenStore {
  static const _access = 'hc.accessToken';
  static const _refresh = 'hc.refreshToken';

  final FlutterSecureStorage _s;
  TokenStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  String? _cachedAccess; // bellek içi kopya — her istekte disk okuması yapılmaz

  Future<String?> accessToken() async => _cachedAccess ??= await _s.read(key: _access);
  Future<String?> refreshToken() => _s.read(key: _refresh);

  Future<void> save({required String access, required String refresh}) async {
    _cachedAccess = access;
    await _s.write(key: _access, value: access);
    await _s.write(key: _refresh, value: refresh);
  }

  Future<void> clear() async {
    _cachedAccess = null;
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
  }
}
