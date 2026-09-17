/// ═══════════════════════════════════════════════════════════════
/// HTTP İSTEMCİSİ — PLATFORMA GÖRE
///
/// Tek işlev: `http.Client sabitlemeliIstemci()`.
///
/// ## ⚠ NİÇİN AYRILDI
///
/// `api_client.dart` doğrudan `IOClient(SertifikaSabitleme.istemci())`
/// kuruyordu. `IOClient` ve `HttpClient` `dart:io`'dadır ve `dart:io`
/// içe aktaran dosya Flutter Web'de DERLENMEZ.
///
/// ## ⚠ WEB'DE SERTİFİKA SABİTLEME YAPILMAZ — VE YAPILIYORMUŞ GİBİ
/// GÖSTERİLMEZ
///
/// Tarayıcıda TLS doğrulaması tamamen tarayıcının işidir; JavaScript
/// veya Dart tarafından sunucu sertifikasına erişilemez, dolayısıyla
/// pin karşılaştırması MÜMKÜN DEĞİLDİR. Web'e sahte bir pinning
/// katmanı eklemek, var olmayan bir korumayı varmış gibi gösterirdi.
///
/// Bu, raporlanması gereken gerçek bir güvenlik sınırıdır:
/// **web istemcisi MITM'e karşı yalnız tarayıcının kök deposu kadar
/// korunur.**
///
/// ## ⚠ MOBİL SABİTLEME AYNEN KORUNUR
///
/// `_io` uygulaması bugünkü satırın birebir aynısıdır: pin verilmişse
/// sabitlemeli istemci, verilmemişse düz istemci.
/// ═══════════════════════════════════════════════════════════════
library;

export 'sabitlemeli_istemci_io.dart'
    if (dart.library.html) 'sabitlemeli_istemci_web.dart';
