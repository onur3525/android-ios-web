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
///   • Buradaki tuzlar ve özetler test hesaplarına (532 111 22 33 /
///     550 765 43 21) aittir. ⚠ DÜZ ŞİFRE KAYNAKTA TUTULMAZ; yalnız
///     `test/support/test_config.dart` (`kTestPass`) içindedir ve
///     kişisel/gerçek bir şifre DEĞİLDİR (30 Eyl güvenlik turu:
///     eski demo şifre kişisel görünümlü olduğu için DEĞİŞTİRİLDİ).
///   • Release derlemede tohumlama çalışmaz; web'de de varsayılan
///     kapalıdır (`AuthRepository(seedTestAccount: TestModu.etkin)`).
///
/// ## DOĞRULAMA
///
/// Değerler `PasswordHasher` ile birebir aynı algoritmadan üretildi:
/// PBKDF2-HMAC-SHA256, 20.000 tur, 32 bayt, tek blok; biçim
/// `pbkdf2$<tur>$<hex>`. `PasswordHasher.verify` bu özetleri normal
/// yoldan doğrular — giriş denemesi gerçek hesabı bulur.
///
/// ⚠ Tur sayısı (`PasswordHasher._turSayisi`) değişirse bu özetler
library;

/// Test MÜŞTERİSİ — 532 111 22 33 (şifre: `kTestPass`, yalnız testlerde)
const String kDemoMusteriTuz = 'hc-demo-musteri-v1';
const String kDemoMusteriOzet =
    'pbkdf2\$20000\$fd814658c855411900c2ba7e6b0188235faa0123e38ceb45dc462e018610fbe0';

/// Test HİZMET VERENİ — 550 765 43 21 (şifre: `kTestPass`, yalnız testlerde)
const String kDemoUstaTuz = 'hc-demo-usta-v1';
const String kDemoUstaOzet =
    'pbkdf2\$20000\$ce76b65253fd0cac83a3bbdfb7cbe9162801a6205f40d691c419b959fef3d6b7';
