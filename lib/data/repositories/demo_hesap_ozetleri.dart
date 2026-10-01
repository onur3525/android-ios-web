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
///     550 765 43 21) aittir. Demo şifre (`kDemoSifre`) kişisel/gerçek
///     bir şifre DEĞİLDİR (30 Eyl güvenlik turu: eski demo şifre kişisel
///     görünümlü olduğu için DEĞİŞTİRİLDİ) ve yalnız test modunda
///     giriş ekranında gösterilir.
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

/// ── DEMO GİRİŞ BİLGİSİ (yalnız TEST MODUNDA gösterilir) ──
///
/// Giriş ekranındaki "Demo hesap" kutusu bu değerleri gösterir. Kutu ve
/// demo hesabın kendisi YALNIZ `TestModu.etkin` + mock modda vardır:
/// release derlemede hiçbir koşulda yoktur (`kReleaseMode` derleme
/// sabiti; dal derleyicide atılır), web'de yalnız
/// `--dart-define=HC_TEST_MODU=true` ile açılır.
/// ⚠ Kişisel/gerçek bir şifre DEĞİLDİR; yalnız yerel demo hesabı açar
/// (sunucu yok, veri cihazda). Testlerdeki `kTestPass` ile AYNI.
const String kDemoEposta = 'test@hizmetcep.com';
const String kDemoSifre = 'hc-Demo-7Kq2xVw9';

/// Test MÜŞTERİSİ — 532 111 22 33 (şifre: `kDemoSifre`)
const String kDemoMusteriTuz = 'hc-demo-musteri-v1';
const String kDemoMusteriOzet =
    'pbkdf2\$20000\$fd814658c855411900c2ba7e6b0188235faa0123e38ceb45dc462e018610fbe0';

/// Test HİZMET VERENİ — 550 765 43 21 (şifre: `kTestPass`, yalnız testlerde)
const String kDemoUstaTuz = 'hc-demo-usta-v1';
const String kDemoUstaOzet =
    'pbkdf2\$20000\$ce76b65253fd0cac83a3bbdfb7cbe9162801a6205f40d691c419b959fef3d6b7';
