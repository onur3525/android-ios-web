import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/boot.dart';
import '../core/sys_state.dart';
import '../ui/ref_tokens.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/notification_controller.dart';
import '../data/models/account.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api/config_api.dart';
import '../data/category_tree.dart';
import '../data/remote/api/category_api.dart';
import '../data/remote/api_config.dart';
import '../data/store_links.dart';
import '../core/native_splash.dart';
import '../core/boot_log.dart';
import '../data/repositories/oturum_tercihi.dart';

// ═══════════════════════════════════════════════════════════════
// SPLASH — REFERANS DEĞERLERİ
//
// Kaynak: hizmetcep-uygulama-son-kod.html → vSplash() ve .splash CSS
//
//   .splash { flex:1; display:flex; align-items:center;
//             justify-content:center; background:#FEFEFE }
//   .splash .in { text-align:center;
//                 animation: logoIn .7s cubic-bezier(.2,.8,.2,1) both }
//   @keyframes logoIn { from { opacity:0; transform:scale(.88) }
//                       to   { opacity:1; transform:none } }
//
//   return `<div class="splash"><div class="in">
//     ${LOGO(118)}
//     <div style="margin-top:8px">${WORDMARK(43)}</div>
//   </div></div>`;
//
//   setTimeout(..., 1400)  → home
//
// LOGO(h)     → w = round(h * 148/182)
// WORDMARK(h) → w = round(h * 318/76)
//
// ⚠ Referansta spinner, metin, hata kutusu veya başka öğe YOKTUR.
//   Splash görünümü hiçbir koşulda değişmez.
// ═══════════════════════════════════════════════════════════════

/// `background:#FEFEFE` — tasarım sisteminden (`RC.splashBg`).
///
/// ⚠ Native `launch_background` ile BİREBİR AYNI (#FFFEFEFE).
const Color _kBg = RC.splashBg;

/// Marka bloğunun çizildiği kutu — Android 12+ splash ikon kutusuyla
/// aynı ölçü (240dp). `splash_brand.png` tuvalinin tamamı buraya
/// sığdırılır; görünen blok tuvalin 469/1024'ü kadardır (≈110dp).
const double _kMarkaKutusu = 240;









// ═══════════════════════════════════════════════════════════════
// GÖRÜNÜR UI — yalnız marka; iş mantığı içermez.
// ═══════════════════════════════════════════════════════════════

/// Referans `.splash` bloğunun birebir karşılığı.
///
/// Bu widget hiçbir duruma bakmaz: yükleniyor, hata, bakım, güncelleme
/// hâllerinde de aynı görünür. Karar sonuçları [SplashScreen] tarafından
/// başka bir ekrana yönlendirilerek gösterilir.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // ══════════════════════════════════════════════════════════════
    // ⚠ SÖZLEŞME DEĞİŞTİ — BU YÜZEY ARTIK BOŞ DEĞİL.
    //
    // ESKİ KURAL: "tek splash native'dir, bu yüzey hiçbir şey
    // çizmez". Gerekçe: native splash hedef ekran hazır olmadan
    // kaldırılmadığı için bu yüzey zaten görünmez.
    //
    // GERÇEK CİHAZDA BU VARSAYIM TUTMADI. Native splash'ın
    // `SPLASH_MAX_MS` fail-safe'i doluyor ve splash KOŞULSUZ
    // bırakılıyor; altında bu yüzey kalıyor. Yüzey bomboş olduğu
    // için kullanıcı TAMAMEN BEYAZ EKRAN görüyor — videoda ölçülen
    // ~1,7 saniyelik boşluk buydu.
    //
    // YENİ KURAL: yüzey, native splash ile AYNI marka bloğunu çizer.
    // Fail-safe erken tetiklense bile kullanıcı boşluk değil aynı
    // açılış görüntüsünü görür; geçiş fark edilmez.
    //
    // ⚠ SPINNER YOK — bu kural KORUNDU. Yükleniyor çemberi açılışı
    // "takılmış" gösterir; marka bloğu yeterlidir.
    //
    // ⚠ Zemin ve oranlar native `splash_brand` ile aynı kaynaktan:
    // logo üstte, wordmark altta, ortalanmış.
    // ══════════════════════════════════════════════════════════════
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        // ⚠ NATIVE İLE AYNI KAYNAK — SIÇRAMA OLMASIN DİYE.
        //
        // Önce `logo_mark.png` + `wordmark.png` ayrı ayrı çiziliyordu.
        // Ölçüm gösterdi ki bu iki dosyanın kenar boşlukları
        // `splash_brand.png` içindeki kompozisyondan FARKLI
        // (wordmark en/boy 4.18 ≠ 4.60), yani logo native'den Flutter'a
        // geçerken hafifçe kayardı.
        //
        // Artık native splash'ın TAM OLARAK AYNI dosyası çizilir.
        // Ölçü: sistem bu 1024×1024 tuvali 240dp'lik ikon kutusuna
        // sığdırır; aynı genişlik burada da verilir, böylece marka
        // bloğu (tuvalin 469/1024'ü ≈ 110dp) birebir aynı boyutta ve
        // aynı merkezde kalır.
        //
        // ⚠ ANİMASYON YOK: geçiş fark edilmemeli, hareket
        // eklenmemeli.
        child: Image.asset(
          'assets/logo/splash_brand.png',
          width: _kMarkaKutusu,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}



// ═══════════════════════════════════════════════════════════════
// AÇILIŞ MANTIĞI — görünümü etkilemez.
// ═══════════════════════════════════════════════════════════════

/// Açılış kontrolünü yürütür; ekranda yalnız [SplashView] gösterilir.
///
/// Sıra:
///   1) Bakım modu           → engel ekranı
///   2) Zorunlu güncelleme   → engel ekranı
///   3) Ağ yok + oturum yok  → engel ekranı
///   4) Oturum yok/süresi dolmuş → giriş
///   5) Oturum var           → son aktif role göre ana ekran
///
/// EN KISA SPLASH SÜRESİ NATIVE TARAFTADIR
/// (`MainActivity.SPLASH_MIN_MS` = 2000 ms). Dart yalnız kararı
/// hazırlar ve `NativeSplash.bootReady()` ile haber verir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// AÇILIŞ BÜTÇESİ
///
/// ⚠ Native splash fail-safe'i 4000 ms'de splash'ı KOŞULSUZ bırakır.
/// Sunucu meta çağrısı `ApiConfig.receiveTimeout` (20 sn) beklerse
/// arada ~16 saniyelik BOŞ BEYAZ pencere oluşur — gerçek cihazda
/// görülen beyaz ekran buydu.
///
/// Bu yüzden açılış çağrıları fail-safe'ten ÖNCE bitecek şekilde
/// ayrı ve KISA bir bütçeyle sınırlanır.
///
/// TOPLAM = 2000 + 1200 = 3200 ms < 4000 ms (fail-safe).
/// Ağ kontrolü yeniden doğrulaması (600 ms) yalnız sunucuya
/// ulaşılamadığında ve config bütçesi dolmadan biterse eklenir.
const Duration _kConfigButce = Duration(milliseconds: 2000);
const Duration _kOturumButce = Duration(milliseconds: 1200);

/// Tek `false` sonucu kalıcı çevrimdışı kararı yapmaz: platform
/// kanalı açılışta henüz hazır olmayabilir. Kısa, SINIRLI (tek)
/// yeniden doğrulama yapılır — sonsuz döngü YOKTUR.
const Duration _kAgTekrarGecikme = Duration(milliseconds: 600);

/// Tek ağ sorgusunun üst sınırı — platform kanalı yanıt vermezse
/// açılış bütçesi aşılmasın diye zaman aşımına uğrar ve `bilinmiyor`
/// olarak değerlendirilir.
const Duration _kAgSorguButce = Duration(milliseconds: 500);

class _SplashScreenState extends State<SplashScreen> {
  /// Navigasyon TEK kez yapılır (çift push koruması).
  bool _yonlendirildi = false;

  /// `await`'ten ÖNCE alınan bildirim denetleyicisi.
  late final NotificationController _bildirimler;

  @override
  void initState() {
    super.initState();

    // ⚠ `basla()` ARTIK SIFIRLAMAZ — sıfır noktası `main()` girişidir.
    BootLog.basla();
    BootLog.olay('SPLASH_INIT_STATE');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BootLog.olay('FLUTTER_FIRST_FRAME');
      _bootGuvenli();
    });
  }

  /// `_boot()` her ne olursa olsun native splash'ı BIRAKIR.
  ///
  /// ⚠ GERÇEK CİHAZ HATASI: `_boot()` içinde beklenmeyen bir hata
  /// oluştuğunda veya `mounted` kontrolünden erken dönüldüğünde
  /// `NativeSplash.bootReady()` satırına HİÇ ULAŞILMIYORDU. Native
  /// koşul `!bootReady` olduğu için splash sonsuza dek ekranda
  /// kalıyordu.
  ///
  /// Burada `finally` ile sinyal GARANTİ altına alınır; hata durumunda
  /// kullanıcı kontrollü çevrimdışı/hata akışına yönlendirilir.
  Future<void> _bootGuvenli() async {
    try {
      await _boot();
    } catch (e, iz) {
      BootLog.olay('BOOT_EXCEPTION', e.runtimeType.toString());
      // ⚠ GÜVENLİK: `debugPrint` RELEASE derlemede DE çalışır ve
      // logcat'e yazar. Hata metni ile yığın izi; API adresi, sorgu
      // parametresi, dosya yolu ve iç sınıf adlarını sızdırabilir —
      // cihaza erişebilen herkes okuyabilir. Ayrıntı YALNIZ debug'da
      // basılır; release'te tür adı zaten `BootLog` ile kayıtlıdır
      // (o da kDebugMode korumalıdır).
      if (kDebugMode) {
        debugPrint('Açılış hatası: $e\n$iz');
      }
      // Kontrollü hata ekranı — boş beyaz ekran ASLA kabul edilmez.
      unawaited(_yonlendir(const BootResult(BootDecision.offline)));
    } finally {
      // ⚠ SON GÜVENCE: bir şekilde hiç yönlendirme yapılmadıysa
      // (beklenmeyen erken dönüş) kullanıcı ekranda BIRAKILMAZ.
      if (!_yonlendirildi) {
        BootLog.olay('BOOT_FALLBACK', 'yonlendirme_yapilmadi');
        unawaited(_yonlendir(const BootResult(BootDecision.offline)));
      }

      // ── ⚠ ROTASIZ SPLASH KORUMASI ──
      //
      // Buraya kadar gelindi ama HÂLÂ yönlendirme yapılamadıysa tek
      // sebep kalır: widget ağaçtan kalkmış (`!mounted`).
      //
      // O durumda native splash'ı bırakmak YANLIŞ olurdu: ekranda
      // bizim marka yüzeyimiz kalır, hiçbir rota kurulmamıştır ve
      // kendiliğinden de değişmez — kullanıcı logoda TAKILIR.
      //
      // ⚠ Splash'ı sonsuza dek tutmak da çözüm değildir; native
      // `SPLASH_MAX_MS` fail-safe'i zaten devreye girer. Ama sinyali
      // BİZ göndermeyiz: "hazırım" demek yanlış bilgi olurdu.
      //
      // Widget kalkmışsa yerine BAŞKA bir rota gelmiş demektir
      // (uygulama başka bir yere gitmiştir); o rota kendi karesini
      // çizer ve fail-safe splash'ı bırakır.
      if (!_yonlendirildi && !mounted) {
        BootLog.olay('BOOT_UNMOUNTED', 'rota_kurulamadi');
        return;
      }
      // ── ⚠ FALLBACK — NORMAL YOL BURAYA BAĞLI DEĞİLDİR ──
      //
      // NORMAL YOL: `_yonlendir` navigasyonu yapar ve hemen ardından
      // `_navSonrasiKareyiBekle` post-frame geri çağrısını kaydeder;
      // sinyal ORADAN gider. Bu blok ona hiç dokunmaz.
      //
      // BURASI yalnız şu hâl içindir: navigasyon HİÇ yapılamadı ama
      // widget ağaçta. O durumda üstteki son güvence bloke/çevrimdışı
      // ekranını kurmuştur; splash yine de bırakılmalıdır.
      //
      // Sinyal zaten gittiyse `_splashBirak` sessizce döner
      // (`_splashBirakildi`).
      //
      // ⚠ Bir tur bu blok NORMAL YOLU da taşıyordu — hem de farkında
      // olmadan: kök sarmalayıcı hiç çalışmadığı için tek çalışan yol
      // burasıydı. Artık iki yol açıkça ayrıdır.
      if (!_yonlendirildi) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_splashBirak());
        });
      }
    }
  }

  Future<AgDurumu> _agDurumu() async {
    BootLog.olay('CONNECTIVITY_CHECK_START');
    try {
      if (await defaultOnlineChecker().timeout(_kAgSorguButce)) {
        BootLog.olay('CONNECTIVITY_RESULT', 'online');
        return AgDurumu.online;
      }
      // Tek olumsuz sonuç yeterli değil — kısa yeniden doğrulama.
      await Future<void>.delayed(_kAgTekrarGecikme);
      final ikinci = await defaultOnlineChecker().timeout(_kAgSorguButce);
      BootLog.olay(
          'CONNECTIVITY_RESULT', ikinci ? 'online(retry)' : 'offline');
      return ikinci ? AgDurumu.online : AgDurumu.offline;
    } catch (e) {
      // ⚠ HATA "internet var" DEMEK DEĞİLDİR.
      //
      // Platform kanalı hazır olmayabilir, izin/DNS sorunu olabilir.
      // `online` dönmek SAHTE ONLINE, `offline` dönmek YANLIŞ OFFLINE
      // olurdu. Kesin bilgi yoksa `bilinmiyor` taşınır ve boot kararı
      // bu belirsizliği güvenli değerlendirir: çevrimdışı ekranı
      // gösterilmez, kullanıcı akışa devam eder.
      BootLog.olay('CONNECTIVITY_RESULT', 'unknown:${e.runtimeType}');
      return AgDurumu.bilinmiyor;
    }
  }

  /// TEK SEFERLİK YÖNLENDİRME
  ///
  /// Boot kararı kesinleştiğinde çağrılır; çift push oluşmaz.
  /// Her `BootDecision` için GEÇERLİ bir görünür route üretir —
  /// hiçbir dal "route yok / boş ekran" ile sonuçlanamaz.
  /// ⚠ ASENKRON: "beni hatırla" tercihi DİSKTEN okunur.
  ///
  /// Çağıranlar sonucu beklemez (`unawaited` davranışı) — yönlendirme
  /// zaten ekranı değiştirir ve dönüş değeri kullanılmaz.
  Future<void> _yonlendir(BootResult karar) async {
    if (_yonlendirildi || !mounted) {
      return;
    }
    _yonlendirildi = true;

    // ⚠ Bekletme YOK: hedef route hemen kurulur. Marka süresini
    // NATIVE splash yönetir (`SPLASH_MIN_MS`), bu katman değil.
    //
    // ⚠ `unawaited` DEĞİL: "beni hatırla" tercihi diskten okunduğu
    // için yönlendirme artık asenkrondur. Sonucu beklemek gerekir,
    // aksi hâlde çağıran taraf yönlendirme bitmeden ilerler.
    await _gercekYonlendir(karar);
  }

  Future<void> _gercekYonlendir(BootResult karar) async {
    if (!mounted) {
      return;
    }

    if (karar.decision == BootDecision.home) {
      // ── CİHAZ HATIRLIYOR MU? ──
      //
      // ⚠ "Beni Hatırla" işaretlenmişse karşılama ekranı ATLANIR ve
      // kullanıcı doğrudan kendi rol paneline gider — hiçbir düğmeye
      // basmadan, hiçbir bilgi girmeden.
      //
      // ⚠ ÇİFT ROLLÜ HESAPTA HİZMET VEREN ÖNCELİKLİ: gelen iş
      // ilanları 30 saat içinde kapanır ve teklif yarışı vardır;
      // hizmet alan tarafı bekleyebilir.
      //
      // Oturum yoksa kural işlemez ve normal karşılama açılır —
      // kullanıcı boş panelde kalmaz.
      final hedef = await _hatirlananHedef();
      if (!mounted) {
        return;
      }
      if (hedef != null) {
        BootLog.olay('NAVIGATION_START', hedef);
        Navigator.of(context).pushNamedAndRemoveUntil(hedef, (r) => false);
        BootLog.olay('NAVIGATION_CALL_RETURNED', hedef);
        _navSonrasiKareyiBekle(hedef);
        return;
      }
      BootLog.olay('NAVIGATION_START', '/home');
      Navigator.of(context).pushReplacementNamed('/home');
      BootLog.olay('NAVIGATION_CALL_RETURNED', '/home');
      _navSonrasiKareyiBekle('/home');
      return;
    }

    _bloke(karar);
  }

  /// NAVİGASYONDAN SONRAKİ KARENİN SONU — NORMAL YOL.
  ///
  /// ⚠ BU METOT NAVİGASYON ÇAĞRISINDAN **SONRA** ÇAĞRILIR.
  /// Öncesinde çağrılırsa geri çağrı, hedef rotayı içermeyen bir
  /// karenin sonunda tetiklenir ve splash erken kalkar.
  ///
  /// ## NİÇİN BU AN DOĞRU
  ///
  /// Geri çağrı KARELER ARASINDA kaydedilir (boot zincirinin async
  /// devamındayız, kare işleme içinde değiliz). Flutter bu durumda
  /// geri çağrıyı BİR SONRAKİ karenin sonunda çalıştırır. O kare,
  /// `Navigator` çağrısıyla kirlenen alt ağacın build + layout +
  /// paint edildiği karedir — yani hedef rota o karede boyanır.
  ///
  /// ## AD DÜRÜSTLÜĞÜ
  ///
  /// Olay adı `POST_NAV_FRAME_END`'dir, `TARGET_ROUTE_FIRST_FRAME`
  /// değil: burada ölçülen şey "navigasyondan sonraki karenin sonu"
  /// dur. Hedef rotanın kendi widget'ından gelen bir sinyal DEĞİLDİR
  /// ve öyleymiş gibi adlandırılmaz.
  ///
  /// ⚠ Bir tur `IlkKareBildirimi` adlı bir kök sarmalayıcı denendi ve
  /// KALDIRILDI: sinyali `static bool` değişikliğine bağlıyordu, oysa
  /// static alan değişimi hiçbir Element'i kirletmez. `Navigator`
  /// yalnız KENDİ alt ağacını yeniden inşa eder; kökteki sarmalayıcı
  /// yeniden build EDİLMEZ, dolayısıyla sinyal oradan hiç gitmezdi.
  void _navSonrasiKareyiBekle(String hedef) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BootLog.olay('POST_NAV_FRAME_END', hedef);
      unawaited(_splashBirak());
    });
  }

  /// Native splash sinyali — TEK KEZ.
  ///
  /// İki yoldan çağrılabilir:
  ///   • NORMAL: `_navSonrasiKareyiBekle` (navigasyon yapıldı),
  ///   • FALLBACK: `_bootGuvenli.finally` (navigasyon HİÇ yapılamadı).
  /// İlk çağrı kazanır; ikincisi sessizce döner.
  bool _splashBirakildi = false;

  Future<void> _splashBirak() async {
    if (_splashBirakildi) {
      return;
    }
    _splashBirakildi = true;
    await NativeSplash.bootReady();
    BootLog.olay('NATIVE_BOOT_READY_SENT');
  }

  /// Cihaz hatırlıyorsa gidilecek rol paneli, yoksa `null`.
  ///
  /// ⚠ İKİ KOŞUL BİRLİKTE ARANIR:
  ///   1. Cihazda "Beni Hatırla" tercihi var mı?
  ///   2. Gerçekten AÇIK BİR OTURUM var mı?
  ///
  /// İkincisi olmadan yönlendirmek kullanıcıyı BOŞ panele düşürürdü:
  /// tercih diskte kalıcıdır ama oturum kalıcı değildir (mock'ta
  /// uygulama kapanınca silinir, API'de jeton süresi dolabilir).
  Future<String?> _hatirlananHedef() async {
    if (!await OturumTercihi().hatirlaniyor) {
      return null;
    }
    if (!mounted) {
      return null;
    }
    final acc = context.read<AuthController>().currentAccount;
    if (acc == null) {
      return null;
    }
    // ⚠ ÇİFT ROL → HİZMET VEREN.
    return acc.roles.contains(Role.provider)
        ? '/provider/jobs'
        : '/customer/listings';
  }

  /// Bloke kararı (bakım · zorunlu güncelleme · çevrimdışı) ekranı.
  ///
  /// ⚠ AYRI METODA ALINDI: `_yonlendir` içinde "beni hatırla" dalı
  /// eklenince gövde uzadı; bloke akışı okunurluk için ayrıldı.
  /// Davranış DEĞİŞMEDİ.
  void _bloke(BootResult karar) {
    BootLog.olay('NAVIGATION_START', 'blocked:${karar.decision.name}');
    // Engel ekranı da bir HEDEF ROTADIR: splash onun ilk karesinden
    // sonra bırakılır, arada boş yüzey kalmaz.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BootBlockedScreen(
          result: karar,
          // ⚠ GERÇEK yeniden deneme: bağlantı ve boot kararı baştan
          // çalışır — yalnız mevcut ekran yeniden çizilmez.
          onRetry: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
          ),
        ),
      ),
    );
    BootLog.olay('NAVIGATION_CALL_RETURNED', 'blocked:${karar.decision.name}');
    _navSonrasiKareyiBekle('blocked:${karar.decision.name}');
  }

  Future<void> _boot() async {
    BootLog.olay('SPLASH_BOOT_START');

    // Controller'lar HERHANGİ BİR `await`'ten ÖNCE alınır.
    //
    // `context.read` async boşluktan sonra çağrılırsa widget o sırada
    // ağaçtan kalkmış olabilir (`use_build_context_synchronously`).
    // Davranış aynıdır: aynı örnekler, aynı sırayla kullanılır.
    final auth = context.read<AuthController>();
    _bildirimler = context.read<NotificationController>();
    final ApiClient? client =
        ApiConfig.useRealApi ? context.read<ApiClient>() : null;

    // ── Sunucu meta bilgisi (bakım + minimum sürüm) ──
    bool configOk = false;
    bool maintenanceActive = false;
    String? message, endAt, minVer, latestVer;

    if (ApiConfig.useRealApi) {
      try {
        BootLog.olay('CONFIG_CHECK_START');
        final api = ConfigApi(client!);
        // ⚠ KISA BÜTÇE: fail-safe'ten önce bitmeli (beyaz ekran yok).
        final j = await api
            .app(platform: currentPlatform())
            .timeout(_kConfigButce);
        configOk = true;
        BootLog.olay('CONFIG_CHECK_END', 'ok');
        final m = j['maintenance'] as Map<String, dynamic>?;
        final r = j['release'] as Map<String, dynamic>?;
        maintenanceActive = m?['active'] as bool? ?? false;
        message = m?['message'] as String?;
        endAt = m?['endAt'] as String?;
        minVer = r?['minSupportedVersion'] as String?;
        latestVer = r?['latestVersion'] as String?;
      } catch (e) {
        // Sunucuya ulaşılamadı. Bu, "internet yok" DEMEK DEĞİLDİR.
        configOk = false;
        BootLog.olay('CONFIG_CHECK_END', 'fail:${e.runtimeType}');
      }
    } else {
      configOk = true; // mock modda meta ucu yoktur
      BootLog.olay('CONFIG_CHECK_END', 'mock');
    }

    // ── ⚠ KATALOG — OTORİTE BACKEND'DİR ──
    //
    // Kategori ve hizmetler admin panelinden yönetiliyor; uygulamaya
    // gömülü liste yalnızca YEDEKTİR. Sunucudan gelen katalog
    // yerleşince arama, kategori seçimi, ilan verme ve çatı ekranları
    // hepsi yeni veriyi görür — çünkü hepsi `kCategoryTree`
    // getter'ından okuyor.
    //
    // ⚠ AÇILIŞI BLOKLAMAZ. Katalog alınamazsa uygulama gömülü
    // listeyle çalışmaya devam eder; kullanıcı beyaz ekranda
    // bırakılmaz. Bu yüzden hata yutulur ve yalnız log'a yazılır.
    //
    // ⚠ MOCK MODDA ÇAĞRILMAZ: sunucu yok, gömülü katalog zaten
    // kullanılıyor.
    if (ApiConfig.useRealApi) {
      try {
        BootLog.olay('CATALOG_FETCH_START');
        final j = await CategoryApi(client!).tree().timeout(_kConfigButce);
        final agac = CategoryApi.parse(j);
        KatalogKaynagi.i.guncelle(agac);
        BootLog.olay('CATALOG_FETCH_END', 'ok:${agac.length}');
      } catch (e) {
        // ⚠ Gömülü katalog devrede kalır — kategorisiz uygulama olmaz.
        BootLog.olay('CATALOG_FETCH_END', 'fail:${e.runtimeType}');
      }
    }

    // ── CİHAZIN GERÇEK İNTERNET DURUMU ──
    //
    // Yalnız sunucu meta bilgisi alınamadığında sorulur; internet
    // VARSA kullanıcı çevrimdışı ekranına DÜŞÜRÜLMEZ.
    var ag = AgDurumu.bilinmiyor;
    if (!configOk) {
      ag = await _agDurumu();
    }

    // ── Oturum geri yükleme ──
    // ⚠ İKİNCİ ÇAĞRI: `main()` de `restoreSession` çağırıyor
    // (RESTORE_SESSION_MAIN_*). İkisi log'da yan yana görülür.
    BootLog.olay('SESSION_RESTORE_SPLASH_START');
    final kOturum = Stopwatch()..start();
    try {
      await auth.restoreSession().timeout(_kOturumButce);
      BootLog.olay(
          'SESSION_RESTORE_SPLASH_END', 'ok:${kOturum.elapsedMilliseconds}ms');
      // ⚠ Bildirim rozeti tazeleme `main()`'den BURAYA taşındı:
      // oturumun geri yüklendiği tek yer artık burasıdır.
      //
      // ⚠ AÇILIŞI BEKLETMEZ: `unawaited` — sonucu beklenmez, hatası
      // açılışı düşürmez. Rozet sayısı açılış için KRİTİK DEĞİL;
      // geldiğinde kendiliğinden çizilir.
      //
      // ⚠ Controller `await`'ten ÖNCE alındı (`_bildirimler`):
      // async boşluktan sonra `context.read` çağrılmaz.
      final me = auth.currentAccount;
      if (me != null) {
        unawaited(_bildirimler.refreshBadge(me.id));
      }
    } catch (_) {
      BootLog.olay('SESSION_RESTORE_SPLASH_END',
          'fail:${kOturum.elapsedMilliseconds}ms');
      // Token geçersiz/süresi dolmuş — oturumsuz devam edilir.
    }

    // ⚠ BURADAKİ `if (!mounted) return;` KALDIRILDI.
    //
    // Bu erken dönüş gerçek bir arızaya yol açıyordu: widget async
    // boşlukta ağaçtan kalkarsa boot karar bile ÜRETMEDEN çıkıyor,
    // `finally` içindeki son güvence de `!mounted` yüzünden
    // yönlendirme yapamıyor, ama native splash YİNE bırakılıyordu.
    // Sonuç: rotasız, kendiliğinden değişmeyen bir marka ekranı.
    //
    // Aşağısı `context` KULLANMAZ — `decideBoot` saf bir fonksiyondur
    // ve `auth` zaten `await`'ten önce alındı. Karar her hâlükârda
    // üretilir; `mounted` denetimi yönlendirmenin KENDİSİNDE yapılır.
    final acc = auth.currentAccount;
    final karar = decideBoot(
      configOk: configOk,
      maintenanceActive: maintenanceActive,
      maintenanceMessage: message,
      maintenanceEndAt: endAt,
      appVersion: ApiConfig.appVersion,
      minSupportedVersion: minVer,
      latestVersion: latestVer,
      hasSession: acc != null,
      isProvider: acc?.activeRole == Role.provider,
      ag: ag,
    );
    BootLog.olay('BOOT_DECISION', karar.decision.name);

    // ⚠ EN KISA SPLASH SÜRESİ ARTIK NATIVE TARAFTADIR
    // (`MainActivity.SPLASH_MIN_MS` = 2000 ms). Burada ayrıca
    // beklenirse açılış İKİ KEZ uzardı. Dart yalnız kararı hazırlar
    // ve native'e "hazır" der; native splash o ana kadar ekranda
    // kalmış olur.
    // ── YÖNLENDİRME ÖNCE, NATIVE SPLASH SONRA ──
    //
    // ⚠ YARIŞ DURUMU: `bootReady()` navigasyondan ÖNCE çağrılırsa
    // native splash kalkarken Flutter tarafında hâlâ boş `SplashView`
    // çizilidir; kullanıcı bir an BEYAZ EKRAN görür. Ayrıca araya
    // `!mounted` kontrolü girerse navigasyon HİÇ yapılmadan splash
    // bırakılır ve beyaz ekran KALICI olur.
    //
    // Doğru sıra: önce hedef route kurulur, sonra native splash
    // bırakılır. Böylece splash kalktığında ekranda geçerli bir kare
    // hazırdır.
    await _yonlendir(karar);
    // ⚠ `bootReady` ARTIK BURADA GÖNDERİLMEZ.
    //
    // Eskiden `Navigator` çağrısının hemen ardından gönderiliyordu.
    // Çağrının dönmesi hedef ekranın ÇİZİLDİĞİ anlamına GELMEZ:
    // splash o anda kalkarsa kullanıcı hedef ekranı değil bu yüzeyi
    // görür.
    //
    // Sinyali `_hedefRotaKareleriniOlc` gönderir — hedef rotanın
    // İLK GERÇEK KARESİ çizildikten sonra. Yönlendirme hiç
    // yapılamadıysa `_bootGuvenli.finally` yine gönderir; sonsuz
    // bekleme oluşmaz.
  }

  // Splash görünümü karardan bağımsızdır.
  @override
  Widget build(BuildContext context) => const SplashView();
}

// ═══════════════════════════════════════════════════════════════
// ENGEL EKRANI — splash'tan AYRI.
//
// Bakım, zorunlu güncelleme ve çevrimdışı durumları burada gösterilir.
// Böylece splash görünümü referanstan sapmaz.
// ═══════════════════════════════════════════════════════════════

class BootBlockedScreen extends StatelessWidget {
  const BootBlockedScreen({
    super.key,
    required this.result,
    required this.onRetry,
  });

  final BootResult result;
  final VoidCallback onRetry;

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(storeUrlForPlatform());
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        sysToastErr(context, SysKind.genericError,
            extra: 'Mağaza açılamadı. Lütfen elle güncelleyin.');
      }
    } catch (_) {
      if (context.mounted) {
        sysToastErr(context, SysKind.genericError,
            extra: 'Mağaza açılamadı. Lütfen elle güncelleyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: switch (result.decision) {
              BootDecision.maintenance => SysState(
                  SysKind.serverUnreachable,
                  title: 'Bakımdayız',
                  desc: result.maintenanceMessage?.isNotEmpty == true
                      ? result.maintenanceMessage
                      : 'HizmetCep kısa süreli bakımda. '
                          'Lütfen daha sonra tekrar deneyin.',
                  action: 'Tekrar Dene',
                  onAction: onRetry,
                ),
              BootDecision.forceUpdate => SysState(
                  SysKind.genericError,
                  title: 'Güncelleme gerekli',
                  desc: 'Devam edebilmek için uygulamayı güncellemeniz gerekiyor'
                      '${result.latestVersion != null ? ' (sürüm ${result.latestVersion})' : ''}.',
                  action: 'Güncelle',
                  onAction: () => _openStore(context),
                ),
              BootDecision.offline => SysState(
                  SysKind.noInternet,
                  action: 'Tekrar Dene',
                  onAction: onRetry,
                ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}
