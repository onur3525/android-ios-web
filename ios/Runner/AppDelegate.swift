import Flutter
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
   • Yalnız `hizmetcep://payment...` kabul edilir.
   • URI'deki "success"/"status" alanlarına GÜVENİLMEZ; Dart'a yalnız
     bağlantı iletilir, sonucu backend `confirmTopup` belirler.
   • Aynı bağlantı iki kez iletilmez (duplicate callback koruması).
 */
@main
@objc class AppDelegate: FlutterAppDelegate {

  private static let methodChannelName = "hizmetcep/deeplinks"
  private static let eventChannelName = "hizmetcep/deeplinks/events"
  private static let scheme = "hizmetcep"
  private static let paymentHost = "payment"

  /**
   KART TOKENİZASYON KANALI

   Dart tarafı (`card_tokenization_bridge.dart`) bu kanala `ping` ve
   `tokenize` çağrıları yapar.

   ⚠ ŞU AN ADAPTÖR BAĞLI DEĞİL: ödeme sağlayıcısı seçilmediği için
   `ping` false döner ve Dart tarafı `UnconfiguredCardTokenizer`
   kullanır.

   Sağlayıcı seçildiğinde yapılacak: `tokenize` içinde sağlayıcının iOS
   SDK'sı çağrılır ve tek kullanımlık `paymentToken` döndürülür.
   Dart tarafında HİÇBİR dosya değişmez.
   */
  private static let cardTokenizerChannelName = "hizmetcep/card_tokenizer"

  /**
   EKRAN KORUMASI KANALI (iOS karşılığı)

   ⚠ ANDROID İLE AYNI KANAL ADI ve AYNI SÖZLEŞME: `ac` / `kapat`.
   Dart tarafı (`lib/core/ekran_korumasi.dart`) hangi platformda
   olduğunu bilmez; yalnız "koruma istiyorum" der.

   ⚠ YAPILAN İŞ ANDROID'DEKİNDEN FARKLIDIR — farklı olmak zorundadır.
   iOS'ta `FLAG_SECURE` gibi bir anahtar YOKTUR; ekran görüntüsü
   ENGELLENEMEZ. Buradaki koruma yalnız ÖNİZLEME KARARTMASIDIR:
   uygulama arka plana alınırken pencerenin üzerine opak bir örtü
   konur, öne gelince kaldırılır. Böylece görev değiştiricide bakiye,
   kart ve iletişim bilgisi asılı kalmaz.

   ⚠ Sayaç Dart tarafındadır; burada yalnız "istek var mı" bilgisi
   tutulur.
   */
  private static let screenGuardChannelName = "hizmetcep/ekran_korumasi"

  /// Hassas bir ekran açık mı? (Dart tarafındaki sayaç 0'dan büyükse true)
  private var screenGuardActive = false

  /// Arka plana geçerken konulan örtü.
  private var privacyCover: UIView?

  /// Sağlayıcı SDK adaptörü bağlandığında `true` yapılır.
  private static let cardTokenizerReady = false

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

    // ── KART TOKENİZASYON KÖPRÜSÜ ──
    if let controller = window?.rootViewController as? FlutterViewController {
      let cardChannel = FlutterMethodChannel(
        name: AppDelegate.cardTokenizerChannelName,
        binaryMessenger: controller.binaryMessenger)

      cardChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "ping":
          // Dart açılışta sorar: adaptör hazır mı?
          result(AppDelegate.cardTokenizerReady)

        case "tokenize":
          guard AppDelegate.cardTokenizerReady else {
            // Sahte token ÜRETİLMEZ; açık hata döner.
            result(FlutterError(
              code: "PROVIDER_NOT_CONFIGURED",
              message: "Ödeme sağlayıcısı SDK adaptörü bağlanmadı.",
              details: nil))
            return
          }
          // DIŞ SERVİS ENTEGRASYONU BEKLİYOR:
          // sağlayıcının iOS SDK çağrısı buraya gelir.
          // Beklenen dönüş: ["paymentToken": ..., "masked": ..., "brand": ...]
          result(FlutterError(
            code: "NOT_IMPLEMENTED",
            message: "Sağlayıcı SDK adaptörü henüz uygulanmadı.",
            details: nil))

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // SOĞUK BAŞLANGIÇ: uygulama tamamen kapalıyken gelen ödeme dönüşü.
    if let url = launchOptions?[.url] as? URL {
      initialLink = Self.paymentLink(from: url)
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
    guard let link = Self.paymentLink(from: url) else {
      // Ödeme dışı bağlantı: diğer eklentilere devredilir.
      return super.application(app, open: url, options: options)
    }

    guard !delivered.contains(link) else {
      NSLog("[HizmetCepDeepLink] Yinelenen ödeme dönüşü yok sayıldı")
      return true
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
    return true
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
  private static func paymentLink(from url: URL) -> String? {
    guard url.scheme?.lowercased() == scheme else {
      NSLog("[HizmetCepDeepLink] Beklenmeyen şema yok sayıldı: \(url.scheme ?? "-")")
      return nil
    }
    let host = url.host?.lowercased()
    let isPayment = host == paymentHost || url.pathComponents.contains(paymentHost)
    guard isPayment else {
      NSLog("[HizmetCepDeepLink] Ödeme dışı derin bağlantı yok sayıldı")
      return nil
    }

    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
    let session = items?.first(where: { $0.name == "session" })?.value
      ?? items?.first(where: { $0.name == "sessionId" })?.value
    guard let s = session, !s.trimmingCharacters(in: .whitespaces).isEmpty else {
      NSLog("[HizmetCepDeepLink] Ödeme dönüşünde session kimliği YOK — yok sayıldı")
      return nil
    }
    // NOT: success/status gibi alanlar bilinçli olarak OKUNMAZ.
    return url.absoluteString
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
