import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token deposu — Keychain (iOS) / EncryptedSharedPreferences (Android).
/// Tokenlar DÜZ METİN veya SharedPreferences içinde TUTULMAZ.
///
/// ═══════════════════════════════════════════════════════════════
/// ⚠ WEB: TOKEN WEB DEPOSUNA YAZILMAZ (güvenlik turu 2 · M-05)
///
/// `flutter_secure_storage`'ın web uygulaması veriyi `localStorage`'a
/// yazar; şifreleme anahtarı da aynı kaynakta durduğu için aynı
/// kaynaktaki HER betik (ve GitHub Pages'te aynı hesabın BAŞKA proje
/// sayfaları) token'ı okuyabilir. Bu, üretim mimarisi için kabul
/// edilemez.
///
/// Bu yüzden web'de erişim ve yenileme token'ları YALNIZ BELLEKTE
/// tutulur: sekme kapanınca ya da sayfa yenilenince oturum düşer.
/// Mobilde davranış AYNEN (Keychain / EncryptedSharedPreferences).
///
/// ── ⚠ BACKEND GELDİĞİNDE: HttpOnly ÇEREZE GEÇİŞ NOKTASI ──
///
/// Hedef mimari (web): token'ları JavaScript HİÇ görmez. Sunucu,
/// giriş/yenileme yanıtında `Set-Cookie: <ad>=...; HttpOnly; Secure;
/// SameSite=Strict; Path=/` koyar; tarayıcı çerezi her istekte kendisi
/// gönderir. O zaman bu sınıfın web dalı token SAKLAMAZ, yalnız
/// "oturum var mı" bilgisini tutar. Değişecek yerler (hepsinde
/// `ÇEREZE GEÇİŞ NOKTASI` notu var):
///   · bu dosya — web dalı,
///   · `api_client.dart` — `Authorization` başlığının web'de
///     eklenmemesi, isteklerin kimlik bilgisiyle (credentials)
///     gönderilmesi, yenileme akışının çerezle yapılması,
///   · `ws_auth.dart` — WebSocket el sıkışmasında token yerine çerez.
/// Backend bu çerezleri üretmeden istemci tarafında "HttpOnly çerez"
/// UYDURULAMAZ — HttpOnly çerezi yalnız sunucu koyabilir.
/// ═══════════════════════════════════════════════════════════════
class TokenStore {
  static const _access = 'hc.accessToken';
  static const _refresh = 'hc.refreshToken';

  final FlutterSecureStorage _s;

  /// Token'lar kalıcı depoya yazılır mı? Web'de HAYIR (yukarıdaki not).
  final bool _kalici;

  TokenStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _kalici = !kIsWeb;

  String? _cachedAccess; // bellek içi kopya — her istekte disk okuması yapılmaz
  String? _bellekRefresh; // yalnız web: kalıcı depo yerine

  // ⚠ ÇEREZE GEÇİŞ NOKTASI (web): backend HttpOnly çerez koyduğunda
  // web dalı token döndürmez; istekler çerezle kimlik doğrular.
  Future<String?> accessToken() async {
    if (!_kalici) {
      return _cachedAccess;
    }
    return _cachedAccess ??= await _s.read(key: _access);
  }

  Future<String?> refreshToken() async {
    if (!_kalici) {
      return _bellekRefresh;
    }
    return _s.read(key: _refresh);
  }

  Future<void> save({required String access, required String refresh}) async {
    _cachedAccess = access;
    if (!_kalici) {
      _bellekRefresh = refresh;
      return;
    }
    await _s.write(key: _access, value: access);
    await _s.write(key: _refresh, value: refresh);
  }

  Future<void> clear() async {
    _cachedAccess = null;
    _bellekRefresh = null;
    if (!_kalici) {
      // Eski sürümlerden kalmış olabilecek web kayıtlarını da temizle.
      try {
        await _s.delete(key: _access);
        await _s.delete(key: _refresh);
      } catch (_) {
        // Web deposu erişilemezse bellek zaten temiz.
      }
      return;
    }
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
  }
}
