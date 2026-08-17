/// ═══════════════════════════════════════════════════════════════
/// DEMO HESAPLARIN ÖNCEDEN HESAPLANMIŞ ŞİFRE ÖZETLERİ
///
/// ## NİÇİN VAR
///
/// `PasswordHasher.hash` PBKDF2-HMAC-SHA256 ile 20.000 tur döner ve
/// SAF DART'tır — yani MAIN ISOLATE üzerinde, senkron çalışır.
/// Debug derlemede (JIT) bu iş yüzlerce milisaniye sürer.
///
/// Açılışta bu hesap İKİ KEZ yapılıyordu:
///   1. `AuthRepository` KURUCUSUNDA (test müşterisi) — `buildPorts`
///      içinde, yani `runApp`'ten ÖNCE,
///   2. `main._seedDemo` içinde (demo usta) — `auth.register` yoluyla.
///
/// İkisi de açılışın kritik zincirindeydi: ilk Flutter karesi ve boot
/// kararı bu hesapların bitmesini bekliyordu. Native splash'ın
/// `SPLASH_MAX_MS` fail-safe'ine çarpmasının nedenlerinden biri buydu.
///
/// ⚠ İŞİ ERTELEMEK ÇÖZMEZ: `Future.microtask`, `Future.delayed(0)` ya
/// da post-frame geri çağrısı işi yalnız BAŞKA BİR ANA taşır; hesap
/// yine AYNI isolate'ta ve senkron koştuğu için UI'yı o kadar süre
/// yine bloke eder.
///
/// ## ÇÖZÜM
///
/// Demo hesapların tuzu SABİTLENDİ ve özet DERLEME ÖNCESİ hesaplandı.
/// Böylece açılışta hiç PBKDF2 çalışmaz; değerler doğrudan yazılır.
///
/// ## GÜVENLİK
///
/// ⚠ BU DOSYA YALNIZ DEBUG/GELİŞTİRME HESAPLARI İÇİNDİR.
///   • Gerçek kullanıcı kaydı bu yoldan GEÇMEZ; `register` normal
///     akışta yine rastgele tuz üretip PBKDF2 hesaplar.
///   • Buradaki tuzlar ve özetler herkese açık test hesaplarına
///     (532 111 22 33 / 550 765 43 21, şifre `123456`) aittir;
///     gizli bir bilgi taşımazlar.
///   • Release derlemede tohumlama zaten çalışmaz
///     (`AuthRepository(seedTestAccount: kDebugMode)` ve
///     `if (kDebugMode)` koşulları).
///
/// ## DOĞRULAMA
///
/// Değerler `PasswordHasher` ile birebir aynı algoritmadan üretildi:
/// PBKDF2-HMAC-SHA256, 20.000 tur, 32 bayt, tek blok; biçim
/// `pbkdf2$<tur>$<hex>`. `PasswordHasher.verify` bu özetleri normal
/// yoldan doğrular — giriş denemesi gerçek hesabı bulur.
///
/// ⚠ Tur sayısı (`PasswordHasher._turSayisi`) değişirse bu özetler
/// GEÇERSİZ kalır; `test/demo_hesap_ozeti_test.dart` bunu yakalar.
/// ═══════════════════════════════════════════════════════════════
library;

/// Test MÜŞTERİSİ — 532 111 22 33 / `123456`
const String kDemoMusteriTuz = 'hc-demo-musteri-v1';
const String kDemoMusteriOzet =
    'pbkdf2\$20000\$01a5a1e48a169adab83494fa8c2f49f588c0e6ec854df733d22b5ca95355e59a';

/// Test HİZMET VERENİ — 550 765 43 21 / `123456`
const String kDemoUstaTuz = 'hc-demo-usta-v1';
const String kDemoUstaOzet =
    'pbkdf2\$20000\$2b736dc218f159c6a9be4977154dbc3cdd3e3d71bae0570e20bee39ee0872745';
