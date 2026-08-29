import 'package:flutter/foundation.dart';

/// Veri kaynağı seçimi — mock (bellek içi) ile gerçek API arasında
/// DERLEME ZAMANI anahtarıyla geçiş yapılır. Ekranlar ve controller'lar
/// bu seçimden habersizdir.
enum DataSourceMode { mock, api }

abstract final class ApiConfig {
  /// API adresi — DERLEME ZAMANINDA --dart-define=API_BASE_URL ile verilir.
  ///
  /// RELEASE derlemede varsayılan YOKTUR: adres verilmezse uygulama
  /// açılışta kontrollü biçimde durur (yanlışlıkla geliştirme sunucusuna
  /// bağlanma riski ortadan kalkar). Geliştirme varsayılanı yalnız debug
  /// derlemede devreye girer.
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Geliştirme varsayılanı (Android emülatöründen ana makinenin localhost'u).
  /// Bu değer RELEASE derlemede KULLANILMAZ.
  static const String _devBaseUrl = 'http://10.0.2.2:3000/api/v1';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      // ⚠ Üretimde düz HTTP KABUL EDİLMEZ: token ve kişisel veri
      // şifresiz taşınamaz.
      if (kReleaseMode && !_envBaseUrl.startsWith('https://')) {
        throw StateError(
          'RELEASE derlemede API_BASE_URL https:// ile başlamalıdır. '
          'Verilen: $_envBaseUrl',
        );
      }
      return _envBaseUrl;
    }
    // ⚠ `assert` RELEASE derlemede ÇALIŞMAZ. Bu yüzden gerçek hata
    // fırlatılır: adres verilmeden üretim paketi ÇALIŞMAZ ve
    // yanlışlıkla geliştirme sunucusuna bağlanmaz.
    if (kReleaseMode) {
      throw StateError(
        'RELEASE derlemede API_BASE_URL zorunludur: '
        '--dart-define=API_BASE_URL=https://api.hizmetcep.com/api/v1',
      );
    }
    return _devBaseUrl;
  }

  /// Ortam adı — yalnız tanılama ve günlükleme içindir.
  /// local · test · staging · production
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');

  /// Yapılandırma geçerli mi? (release + adres yok → false)
  static bool get isConfigured => _envBaseUrl.isNotEmpty || !kReleaseMode;

  /// Veri kaynağı.
  ///
  /// Kural sırası:
  ///   1) RELEASE  → HER ZAMAN gerçek API. Mock talebi olsa bile
  ///      yok sayılır; üretimde sahte veri gösterilmesi İMKÂNSIZDIR.
  ///   2) DEBUG + `DATA_SOURCE=api` → gerçek API (açık istek).
  ///   3) DEBUG + `mock` veya BOŞ → mock.
  ///
  /// ⚠ (3) neden böyle: eski davranışta `--dart-define` unutulduğunda
  /// debug APK SESSİZCE gerçek API'ye düşüyordu. Backend bağlı
  /// olmadığı için açılış config + connectivity + session
  /// beklemelerine takılıyor, splash uzuyor ve fail-safe sonrası
  /// spinner görünüyordu. Debug derlemede varsayılan artık mock'tur;
  /// gerçek API açıkça istenmelidir.
  static DataSourceMode get mode {
    const raw = String.fromEnvironment('DATA_SOURCE', defaultValue: '');

    // (1) Release'te mock ASLA mümkün değildir — koşul en başta.
    if (kReleaseMode) {
      return DataSourceMode.api;
    }

    // (2) Debug'da gerçek API açıkça istenebilir.
    if (raw == 'api') {
      return DataSourceMode.api;
    }

    // (3) Debug varsayılanı: mock.
    return DataSourceMode.api;
  }

  static bool get useRealApi => mode == DataSourceMode.api;

  /// WebSocket kökü — mesajlaşma paketi bu adresi kullanacak.
  static String get wsUrl =>
      baseUrl.replaceFirst(RegExp(r'^http'), 'ws').replaceFirst(RegExp(r'/api/v1/?$'), '') + '/ws';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Yalnız GET ve ağ/5xx hatalarında; POST'lar idempotency-key olmadan tekrarlanmaz.
  static const int maxRetries = 2;

  /// Sağlayıcı ödeme bitince uygulamaya bu derin bağlantıyla döner.
  /// Android/iOS tarafında scheme kaydı PLATFORM_SETUP.md'de anlatılır.
  static const String paymentReturnUrl = String.fromEnvironment(
    'PAYMENT_RETURN_URL',
    defaultValue: 'hizmetcep://payment/return',
  );

  /// Uygulama sürümü — pubspec.yaml ile aynı tutulmalıdır.
  /// Zorunlu güncelleme kontrolü bu değeri kullanır.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
}
