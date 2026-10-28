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
        '--dart-define=API_BASE_URL=https://hizmetcep-backend.onrender.com/api/v1',
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
    return DataSourceMode.mock;
  }

  static bool get useRealApi => mode == DataSourceMode.api;

  /// WebSocket kökü — mesajlaşma bağlantısı bu adresi kullanır.
  ///
  /// ── ⚠ RELEASE'TE `wss://` ZORUNLU ──
  ///
  /// Adres `baseUrl`den türetilir ve `baseUrl` release'te zaten
  /// `https://` şartına bağlıdır. Ama türetme bir dize değiştirmesidir:
  /// ileride `baseUrl` kuralı gevşerse ya da adres beklenmedik bir
  /// biçimde gelirse sonuç sessizce `ws://` olabilirdi. Sohbet
  /// trafiğinde access token ve kişisel veri taşınır; şifresiz
  /// bağlantı kabul edilemez.
  ///
  /// ⚠ DEBUG'TA `ws://` SERBEST: geliştirme sunucusu (10.0.2.2) TLS
  /// sunmaz.
  static String get wsUrl {
    final u = wsAdresi(baseUrl);
    if (kReleaseMode && !u.startsWith('wss://')) {
      throw StateError(
        'RELEASE derlemede WebSocket adresi wss:// ile başlamalıdır. '
        'Üretilen: $u',
      );
    }
    return u;
  }

  /// API adresinden WebSocket adresi — TEK KAYNAK.
  ///
  /// ── ⚠ KAPI NUMARASI AÇIK YAZILIR (29 Eki, canlı denetim bulgusu) ──
  ///
  /// `https://alan/api/v1` → `wss://alan/ws` üretiliyordu. Dart'ın `Uri`
  /// sınıfı ws/wss şemasının varsayılan kapısını bilmez (0 döner); bu
  /// yüzden socket.io istemcisi bağlantıyı `wss://alan:0/socket.io/`
  /// adresine kurmaya çalışıyor, bağlantı HİÇ kurulamıyordu (anlık
  /// sohbet ve anlık yenileme çalışmıyordu). Artık kapı her zaman açık:
  /// adreste yazılıysa o, yoksa güvenli bağlantıda 443, düzde 80.
  static String wsAdresi(String apiAdresi) {
    final a = Uri.parse(apiAdresi.replaceFirst(RegExp(r'/api/v1/?$'), ''));
    final guvenli = a.scheme == 'https';
    final kapi = a.hasPort ? a.port : (guvenli ? 443 : 80);
    final yol = a.path.endsWith('/') ? a.path.substring(0, a.path.length - 1) : a.path;
    return '${guvenli ? 'wss' : 'ws'}://${a.host}:$kapi$yol/ws';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Yalnız GET ve ağ/5xx hatalarında; POST'lar idempotency-key olmadan tekrarlanmaz.
  static const int maxRetries = 2;

  /// Uygulama sürümü — `pubspec.yaml` `version:` alanının sürüm adı
  /// (`+` öncesi) ile AYNI olmalıdır; `test/surum_tutarliligi_test.dart`
  /// ikisini karşılaştırır. Zorunlu güncelleme kontrolü bu değeri kullanır.
  /// Release derlemesi isterse `--dart-define=APP_VERSION=` ile verir.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
}
