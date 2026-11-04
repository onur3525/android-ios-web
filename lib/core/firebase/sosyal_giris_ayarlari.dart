import 'package:flutter/foundation.dart';

import '../../domain/sosyal_saglayici.dart';

/// ═══════════════════════════════════════════════════════════════
/// GOOGLE / APPLE İLE GİRİŞ — AYARLAR (TEK KAYNAK, 4 Kas)
///
/// Kod hazırdır; düğmeler YALNIZ ilgili platform yapılandırıldığında
/// görünür (yapılandırılmamış düğme ya hiçbir şey yapmaz ya da iOS'ta
/// uygulamayı kapatır). Değerler gizli DEĞİLDİR (istemci kimlikleri her
/// uygulamada açıkça bulunur); Firebase konsolundan alınır:
///
///   GOOGLE (Firebase Console → Authentication → Sign-in method → Google
///   etkinleştirilir; Android için SHA-1/SHA-256 parmak izleri eklenir;
///   ardından google-services.json ve GoogleService-Info.plist YENİDEN
///   indirilir):
///     · [googleWebIstemciKimligi] — google-services.json içindeki
///       `client_type: 3` olan oauth_client'ın `client_id`'si (Android
///       Google girişi bunu "serverClientId" olarak ister).
///     · [googleIosIstemciKimligi] — GoogleService-Info.plist `CLIENT_ID`.
///       ⚠ iOS'ta ayrıca Info.plist'e `REVERSED_CLIENT_ID` URL şeması
///       eklenmelidir; eksikse Google girişi uygulamayı KAPATIR. Bu yüzden
///       iOS düğmesi bu değer boşken görünmez.
///   APPLE (Apple Developer'da App ID'ye "Sign in with Apple" eklenir;
///   web ve Android için bir Services ID + anahtar oluşturulup Firebase
///   Console → Authentication → Apple'a girilir):
///     · [appleAcik] — yapılandırma bitince `true`.
///   WEB: Firebase Console → Authentication → Settings → Authorized
///   domains listesinde hizmetcep.com ve test alanı bulunmalıdır.
///
/// Derleme anında da verilebilir (değiştirmeden):
///   --dart-define=GOOGLE_WEB_CLIENT_ID=...  --dart-define=GOOGLE_IOS_CLIENT_ID=...
///   --dart-define=APPLE_GIRIS=1
/// ═══════════════════════════════════════════════════════════════
class SosyalGirisAyarlari {
  SosyalGirisAyarlari._();

  // 4 Kas: Firebase'de Google girişi açıldı; kimlikler google-services.json
  // (client_type 3 = web, client_type 2 = iOS) ile aynıdır.
  static const String googleWebIstemciKimligi = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '262578778971-vbgddv6hp0qceebgd2vpllba76qmaf4u.apps.googleusercontent.com');
  static const String googleIosIstemciKimligi = String.fromEnvironment(
      'GOOGLE_IOS_CLIENT_ID',
      defaultValue:
          '262578778971-vralmbcac95ndp4jl78ofq8tgstgc6sk.apps.googleusercontent.com');

  /// ⚠ ANDROID: mağaza uygulamasının (com.hizmetcep.app) SHA-1 parmak izi
  /// Firebase'e eklenmeden Google girişi Android'de "yapılandırma hatası"
  /// verir. Parmak izi eklenip google-services.json yenilenince `true`.
  static const bool googleAndroidAcik =
      String.fromEnvironment('GOOGLE_ANDROID') == '1';
  static const bool appleAcik =
      String.fromEnvironment('APPLE_GIRIS') == '1';

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Bu platformda Google ile giriş kullanılabilir mi.
  ///
  /// ⚠ Platform `dart:io` ile DEĞİL `kIsWeb` + `defaultTargetPlatform` ile
  /// anlaşılır (web'de `Platform.isIOS` çalışmaz).
  static bool get googleHazir {
    if (googleWebIstemciKimligi.isEmpty) {
      return false; // Google sağlayıcısı Firebase'de etkin değil
    }
    if (_ios) {
      return googleIosIstemciKimligi.isNotEmpty;
    }
    if (_android) {
      return googleAndroidAcik;
    }
    return kIsWeb;
  }

  /// Bu platformda Apple ile giriş kullanılabilir mi (iOS yerel; web ve
  /// Android Firebase'in Apple web akışıyla).
  static bool get appleHazir => appleAcik && (kIsWeb || _ios || _android);

  /// Bu platformda gösterilecek sağlayıcılar (sıra: Apple, Google — Apple
  /// kuralı gereği Apple düğmesi diğerlerinden geride değildir).
  static List<SosyalSaglayici> get saglayicilar => [
        if (appleHazir) SosyalSaglayici.apple,
        if (googleHazir) SosyalSaglayici.google,
      ];

  /// ⚠ APPLE KURALI (App Review 4.8): iOS'ta Google girişi varsa Apple
  /// girişi de sunulmalıdır. Apple hazır değilken iOS'ta Google gösterilmez.
  static List<SosyalSaglayici> get gorunenler {
    final s = saglayicilar;
    if (_ios && !s.contains(SosyalSaglayici.apple)) {
      return const [];
    }
    return s;
  }
}
