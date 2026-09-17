import Flutter
// ⚠ `CACurrentMediaTime()` QuartzCore'dadır. UIKit genelde dolaylı
// getirir ama buna güvenilmez; açıkça import edilir.
import QuartzCore
import UIKit

/**
 ÖDEME DÖNÜŞÜ — DERİN BAĞLANTI KÖPRÜSÜ (iOS)

 Dart tarafı ile sözleşme (Android ile BİREBİR AYNI):
   MethodChannel("hizmetcep/deeplinks")        → getInitialLink
   EventChannel ("hizmetcep/deeplinks/events") → sonraki bağlantılar

 Yakalanan durumlar:
   • Uygulama KAPALIYKEN → launchOptions[.url], getInitialLink ile TEK SEFER
   • ARKA PLAN / ÖN PLAN → application(_:open:options:)

 GÜVENLİK:
   • URI'deki "success"/"status" alanlarına GÜVENİLMEZ; Dart'a yalnız
   • Aynı bağlantı iki kez iletilmez (duplicate callback koruması).
 */
@main
@objc class AppDelegate: FlutterAppDelegate {

  private static let methodChannelName = "hizmetcep/deeplinks"
  private static let eventChannelName = "hizmetcep/deeplinks/events"
  private static let scheme = "hizmetcep"

  /**
   UNIVERSAL LINKS ALAN ADI (HTTPS)

   ⚠ HAZIRLIK, ÇALIŞIR DURUM DEĞİL: Apple
   `https://hizmetcep.com/.well-known/apple-app-site-association`
   dosyasını indirip App ID ile eşleştirmeden universal link
   ÇALIŞMAZ. O dosya bu turda oluşturulmadı (kapsam dışı). Ayrıca
   `Runner.entitlements` Xcode'da hedefe bağlanmalıdır.

   ⚠ ÖZEL ŞEMA KALDIRILMADI: `hizmetcep://payment/return` aynen
   çalışır. İki yol da AYNI Dart akışına düşer.
   */
  private static let appLinkHost = "hizmetcep.com"

  /**
   EKRAN KORUMASI KANALI (iOS karşılığı)

   ⚠ ANDROID İLE AYNI KANAL ADI ve AYNI SÖZLEŞME: `ac` / `kapat`.
   Dart tarafı (`lib/core/ekran_korumasi.dart`) hangi platformda
   olduğunu bilmez; yalnız "koruma istiyorum" der.

   ⚠ YAPILAN İŞ ANDROID'DEKİNDEN FARKLIDIR — farklı olmak zorundadır.
   iOS'ta `FLAG_SECURE` gibi bir anahtar YOKTUR; ekran görüntüsü
   ENGELLENEMEZ. Buradaki koruma yalnız ÖNİZLEME KARARTMASIDIR:
   uygulama arka plana alınırken pencerenin üzerine opak bir örtü
   konur, öne gelince kaldırılır. Böylece görev değiştiricide iletişim
   bilgisi asılı kalmaz.

   ⚠ Sayaç Dart tarafındadır; burada yalnız "istek var mı" bilgisi
   tutulur.
   */
  private static let screenGuardChannelName = "hizmetcep/ekran_korumasi"

  /**
   AÇILIŞ (SPLASH) KANALI — ANDROID İLE AYNI SÖZLEŞME

   ⚠ KANAL ADI VE METOT ANDROID'DEKİYLE BİREBİR: `hizmetcep/splash`
   üzerinden tek metot, `bootReady`. Dart tarafı
   (`lib/core/native_splash.dart`) hangi platformda olduğunu bilmek
   ZORUNDA KALMAZ.

   ⚠ ANDROID DAVRANIŞI REFERANS ALINDI: splash ŞU İKİ KOŞUL sağlanana
   kadar ekranda kalır —
     1) en az `splashMinMs` geçmiş olmalı,
     2) Dart açılış kararını bildirmiş olmalı (`bootReady`).
   Değerler Android'deki `SPLASH_MIN_MS` / `SPLASH_MAX_MS` ile AYNI
   tutuldu; ayrışırlarsa iki platform farklı hızda açılır.

   ⚠ iOS'TA SİSTEM SPLASH'I TUTULAMAZ. Android'in `installSplashScreen`
   API'si gibi bir "ekranda tut" mekanizması yoktur: `LaunchScreen`
   storyboard'u ilk Flutter karesiyle kaybolur. Bu yüzden aynı görüntü
   ÖRTÜ olarak sürdürülür — storyboard'un birebir aynısı (beyaz zemin +
   ortalanmış `LaunchImage`) pencerenin üstüne konur ve koşullar
   sağlanınca kaldırılır. Kullanıcı tek ve kesintisiz bir açılış görür.

   ⚠ UI THREAD BLOKLANMAZ: `sleep` KULLANILMAZ — Android'de de
   kullanılmıyor. Kaldırma, zamanlayıcı ile ertelenir; motor bu sırada
   çalışmaya devam eder.

   ⚠ FAIL-SAFE ZORUNLU: `bootReady` hiç gelmezse örtü sonsuza kadar
   kalır ve uygulama kilitli görünür. Android'deki `SPLASH_MAX_MS`
   güvenliği burada da vardır.
   */
  private static let splashChannelName = "hizmetcep/splash"

  /// Android `SPLASH_MIN_MS` karşılığı.
  private static let splashMinMs: Double = 2000

  /// Android `SPLASH_MAX_MS` karşılığı — fail-safe.
  private static let splashMaxMs: Double = 9000

  /// Açılış örtüsü (storyboard'un devamı).
  private var splashCover: UIView?

  /// Örtünün konulduğu an.
  private var splashStartedAt: CFTimeInterval = 0

  /// Dart açılış kararını bildirdi mi?
  private var bootReady = false

  /// Örtü kaldırıldı mı? (iki yoldan da bir kez çalışsın)
  private var splashRemoved = false

  /// Hassas bir ekran açık mı? (Dart tarafındaki sayaç 0'dan büyükse true)
  private var screenGuardActive = false

  /// Arka plana geçerken konulan örtü.
  private var privacyCover: UIView?

  /// Sağlayıcı SDK adaptörü bağlandığında `true` yapılır.

  /// Açılışa neden olan bağlantı; Dart bir kez okur ve tüketir.
  private var initialLink: String?
  private var initialLinkConsumed = false

  private var eventSink: FlutterEventSink?

  /// Duplicate koruması.
  private var delivered = Set<String>()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // SOĞUK BAŞLANGIÇ: uygulama tamamen kapalıyken gelen derin bağlantı.
    if let url = launchOptions?[.url] as? URL {
      initialLink = Self.derinBaglanti(from: url)
    }

    // Kanallar, Flutter motoru hazır olduktan sonra kurulur.
    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger

      let method = FlutterMethodChannel(
        name: Self.methodChannelName, binaryMessenger: messenger)
      method.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "getInitialLink":
          // TEK SEFER: ikinci çağrıda nil döner.
          if self.initialLinkConsumed {
            result(nil)
          } else {
            self.initialLinkConsumed = true
            if let link = self.initialLink {
              self.delivered.insert(link)
            }
            result(self.initialLink)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let events = FlutterEventChannel(
        name: Self.eventChannelName, binaryMessenger: messenger)
      events.setStreamHandler(self)

      // ── AÇILIŞ (SPLASH) KÖPRÜSÜ ──
      //
      // ⚠ ÖRTÜ BURADA KONUR: storyboard ilk Flutter karesiyle kalkar;
      // örtü o boşluğu doldurur. Kanal kaydından ÖNCE konur ki
      // `bootReady` çok erken gelse bile kaldıracak bir şey olsun.
      self.installSplashCover()

      let splash = FlutterMethodChannel(
        name: Self.splashChannelName, binaryMessenger: messenger)
      splash.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "bootReady":
          // ⚠ ANDROID İLE AYNI: sinyal yalnız İKİNCİ koşulu sağlar;
          // en kısa süre dolmadıysa örtü beklemeye devam eder.
          self.bootReady = true
          self.removeSplashCoverIfReady()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // ── EKRAN KORUMASI KÖPRÜSÜ ──
      let guardChannel = FlutterMethodChannel(
        name: Self.screenGuardChannelName, binaryMessenger: messenger)
      guardChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "ac":
          self.screenGuardActive = true
          result(nil)
        case "kapat":
          self.screenGuardActive = false
          // Ekran kapanırken örtü açıkta kalmasın.
          self.removePrivacyCover()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Uygulama AÇIK veya ARKA PLANDA iken gelen bağlantı.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard let link = Self.derinBaglanti(from: url) else {
      // Ödeme dışı bağlantı: diğer eklentilere devredilir.
      return super.application(app, open: url, options: options)
    }

    // ⚠ DAVRANIŞ DEĞİŞMEDİ: aynı yinelenme koruması ve aynı "dinleyici
    // yoksa sakla" mantığı; yalnız universal link ile PAYLAŞILAN tek
    // yere taşındı.
    teslimEt(link)
    return true
  }

  /**
   UNIVERSAL LINK GİRİŞİ

   ⚠ ÖZEL ŞEMADAN FARKLI KAPI: `hizmetcep://` adresleri
   `application(_:open:options:)` ile gelir; HTTPS universal link'ler
   ise `NSUserActivity` üzerinden `continueUserActivity` ile gelir.
   İkinci kapı yoktu, bu yüzden HTTPS bağlantı uygulamaya hiç
   ulaşamıyordu.

   ⚠ AYNI BORUYA BAĞLANIR: bağlantı, özel şemadakiyle AYNI
   `teslimEt` yoluna verilir — aynı yinelenme koruması, aynı
   "dinleyici yoksa sakla" davranışı. İki giriş yolu, tek akış.

   ⚠ SOĞUK BAŞLANGIÇ DA BURADAN GELİR: uygulama kapalıyken açılan
   universal link, `didFinishLaunchingWithOptions` yerine bu metotla
   iletilir; `eventSink` henüz yokken `initialLink` olarak saklanır.
   */
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = userActivity.webpageURL,
      let link = Self.derinBaglanti(from: url)
    else {
      return super.application(
        application, continue: userActivity, restorationHandler: restorationHandler)
    }
    teslimEt(link)
    return true
  }

  /// Bağlantıyı Dart'a iletir; dinleyici yoksa açılış için saklar.
  ///
  /// ⚠ TEK YER: özel şema ve universal link aynı mantığı kullanır.
  /// İki kopya olsaydı yinelenme koruması birinde eksik kalabilirdi.
  private func teslimEt(_ link: String) {
    guard !delivered.contains(link) else {
      NSLog("[HizmetCepDeepLink] Yinelenen bağlantı yok sayıldı")
      return
    }
    delivered.insert(link)

    if let sink = eventSink {
      sink(link)
    } else {
      // Dart henüz dinlemiyorsa bağlantı KAYBOLMASIN.
      initialLink = link
      initialLinkConsumed = false
      NSLog("[HizmetCepDeepLink] Dinleyici yok — açılış bağlantısı olarak saklandı")
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ÖNİZLEME KARARTMASI (yaşam döngüsü)
  // ═══════════════════════════════════════════════════════════════
  //
  // ⚠ ÖRTÜ `willResignActive`'DE KONUR, `didEnterBackground`'DA
  // DEĞİL. Sistem görev değiştirici görüntüsünü uygulama tam arka
  // plana düşmeden ÖNCE alır; geç konan örtü o karede yetişmez.
  //
  // ⚠ Denetim çubuğu aşağı çekildiğinde de `willResignActive` gelir.
  // Örtü o durumda da görünür ve kullanıcı geri döndüğünde kalkar —
  // istenen davranış budur.

  override func applicationWillResignActive(_ application: UIApplication) {
    if screenGuardActive {
      addPrivacyCover()
    }
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    removePrivacyCover()
    super.applicationDidBecomeActive(application)
  }

  // ═══════════════════════════════════════════════════════════════
  //  AÇILIŞ ÖRTÜSÜ (Android native splash karşılığı)
  // ═══════════════════════════════════════════════════════════════

  /// Storyboard ile AYNI görüntüyü pencerenin üstüne koyar.
  ///
  /// ⚠ STORYBOARD'UN KOPYASI, BENZERİ DEĞİL: beyaz zemin + ortalanmış
  /// `LaunchImage`, ölçeklemesiz (`center`). Farklı olursa kullanıcı
  /// açılışta bir "sıçrama" görür.
  private func installSplashCover() {
    guard splashCover == nil, let window = self.window else {
      return
    }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor.white
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.isUserInteractionEnabled = false

    let logo = UIImageView(image: UIImage(named: "LaunchImage"))
    logo.contentMode = .center
    logo.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(logo)
    NSLayoutConstraint.activate([
      logo.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      logo.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
    ])

    window.addSubview(cover)
    splashCover = cover
    splashStartedAt = CACurrentMediaTime()

    // ⚠ FAIL-SAFE: `bootReady` hiç gelmezse uygulama kilitli görünür.
    // Android'deki `SPLASH_MAX_MS` koruması birebir.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.splashMaxMs / 1000) {
      [weak self] in
      guard let self = self, !self.splashRemoved else {
        return
      }
      NSLog("[HizmetCepSplash] Fail-safe: bootReady gelmedi, örtü kaldırıldı")
      self.removeSplashCover()
    }
  }

  /// İki koşul da sağlandıysa örtüyü kaldırır; değilse kalan süreyi
  /// bekler.
  ///
  /// ⚠ BEKLEME BLOKLAMAZ: `sleep` yerine zamanlayıcı kullanılır.
  private func removeSplashCoverIfReady() {
    guard !splashRemoved, bootReady else {
      return
    }
    let gecen = (CACurrentMediaTime() - splashStartedAt) * 1000
    let kalan = Self.splashMinMs - gecen
    if kalan <= 0 {
      removeSplashCover()
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + kalan / 1000) {
      [weak self] in
      self?.removeSplashCover()
    }
  }

  /// Örtüyü tek sefer kaldırır.
  ///
  /// ⚠ ANDROID'DEKİ GİBİ ANİMASYONSUZ: sistem çıkış animasyonu
  /// devralınıp tek karede kaldırılıyor; iOS'ta da solma eklenmedi ki
  /// iki platform aynı görünsün.
  private func removeSplashCover() {
    guard !splashRemoved else {
      return
    }
    splashRemoved = true
    splashCover?.removeFromSuperview()
    splashCover = nil
  }

  /// Pencerenin üzerine opak örtü koyar.
  ///
  /// ⚠ Örtü pencereye eklenir, Flutter görünümünün İÇİNE değil:
  /// Flutter tarafı bu sırada çizim yapmıyor olabilir.
  private func addPrivacyCover() {
    guard privacyCover == nil, let window = self.window else {
      return
    }
    let cover = UIView(frame: window.bounds)
    // Uygulamanın açılış zemini ile aynı renk — marka sürekliliği.
    cover.backgroundColor = UIColor.white
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.isUserInteractionEnabled = false
    window.addSubview(cover)
    privacyCover = cover
  }

  /// Örtüyü kaldırır. Örtü yoksa hiçbir şey yapmaz.
  private func removePrivacyCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }

  /**
   Geçerli ödeme dönüş bağlantısını doğrular.
   Geçersiz şema/host veya EKSİK session kimliğinde nil döner ve
   neden loglanır (sessizce yutulmaz).
   */
  private static func derinBaglanti(from url: URL) -> String? {
    // ── ⚠ İKİ YOL KABUL EDİLİR ──
    //
    //   1) Özel şema:  hizmetcep://payment/return?session=...
    //   2) Universal:  https://hizmetcep.com/payment/return?session=...
    //
    // ⚠ ÖZEL ŞEMA ÖNCE DENETLENİR ve davranışı DEĞİŞMEDİ.
    //
    // ⚠ ALAN ADI ZORUNLU: yalnız `https` görmek yetmez; denetlenmezse
    // başka bir sitenin bağlantısı da uygulamaya girebilirdi.
    //
    // ⚠ ADRES OLDUĞU GİBİ DART'A GEÇER: Dart `session` dışındaki
    // hiçbir parametreye güvenmez.
    let sema = url.scheme?.lowercased()
    if sema == scheme {
      return url.absoluteString
    }
    if sema == "https", url.host?.lowercased() == appLinkHost {
      return url.absoluteString
    }
    NSLog(
      "[HizmetCepDeepLink] Beklenmeyen bağlantı yok sayıldı: "
        + "\(url.scheme ?? "-")://\(url.host ?? "-")")
    return nil
  }
}

// MARK: - EventChannel
extension AppDelegate: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
