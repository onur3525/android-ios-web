import Flutter
// ⚠ `CACurrentMediaTime()` QuartzCore'dadır. UIKit genelde dolaylı
// getirir ama buna güvenilmez; açıkça import edilir.
import QuartzCore
import UIKit

/**
 HizmetCep uygulama temsilcisi — native köprüler (Android ile aynı sözleşme):
   hizmetcep/splash          → bootReady
   hizmetcep/ekran_korumasi  → ac / kapat (önizleme karartması)

 ⚠ Eski ödeme dönüşü derin bağlantı köprüsü ("hizmetcep/deeplinks")
 KALDIRILDI: ödeme ürünü kaldırıldı, Dart dinleyicisi yoktu ve Info.plist'te
 `hizmetcep://` şeması tanımlı değildi. URL ve universal link istekleri
 artık doğrudan FlutterAppDelegate'e (eklentilere, ör. Firebase Auth) gider.
 */
@main
@objc class AppDelegate: FlutterAppDelegate {

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


  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Kanallar, Flutter motoru hazır olduktan sonra kurulur.
    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger

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

}
