import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// FIREBASE SEÇENEKLERİ — proje `hizmetcep-fe036`
///
/// Değerler `android/app/google-services.json` ve
/// `ios/Runner/GoogleService-Info.plist` dosyalarından alınmıştır.
/// Bunlar GİZLİ DEĞİLDİR (istemciye gömülmek üzere tasarlanmış genel
/// tanımlayıcılardır); erişim Firebase Console'daki API anahtarı
/// kısıtlamaları ve güvenlik kurallarıyla sınırlanır.
///
/// ⚠ Neden Gradle `google-services` eklentisi / Xcode plist bağlantısı
/// yerine Dart seçenekleri: Android Gradle Plugin 9 ile eklenti
/// uyumluluğu bu ortamda doğrulanamıyor ve `project.pbxproj` elle
/// düzenlenmiyor. `Firebase.initializeApp(options: ...)` FlutterFire'ın
/// resmî ve platformdan bağımsız yoludur (`flutterfire configure`
/// çıktısıyla aynı yapı). Dosyalar yine de depoda durur (Crashlytics vb.
/// ileride eklenirse diye).
///
/// ⚠ GİZLİ ANAHTAR YOK: VAPID özel anahtarı ve servis hesabı anahtarı
/// ASLA istemciye/depoya girmez; push GÖNDERİMİ sunucunun işidir.
/// ═══════════════════════════════════════════════════════════════
abstract final class FirebaseSecenekleri {
  static const String _projectId = 'hizmetcep-fe036';
  static const String _senderId = '262578778971';
  static const String _storageBucket = 'hizmetcep-fe036.firebasestorage.app';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJw5diwZbumEpM7SOFexa9ysFl6_oBbXo',
    appId: '1:262578778971:android:bba810a8706baec30b207e',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCRBvZVYpo7s5lAZjOmKSaNAlPlgyYeHtw',
    appId: '1:262578778971:ios:c86fad4c01cbcf890b207e',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: 'com.hizmetcep.app',
  );

  /// ── ANDROID DEBUG UYGULAMASI (`com.hizmetcep.app.debug`) ──
  ///
  /// Debug derlemenin paket adı farklıdır (`applicationIdSuffix ".debug"`,
  /// android/app/build.gradle) ve Firebase'de AYRI bir Android uygulaması
  /// olarak kendi SHA kayıtlarıyla tanımlıdır. Telefon doğrulaması paket
  /// adı + imza eşleşmesi istediği için debug derlemesi bu uygulamanın
  /// kimliğini kullanır. Seçim OTOMATİKTİR (bkz. [aktif]): debug derleme
  /// türü ⇔ `.debug` paketi; ek derleme bayrağı gerekmez.
  static const FirebaseOptions androidDebug = FirebaseOptions(
    apiKey: 'AIzaSyAJw5diwZbumEpM7SOFexa9ysFl6_oBbXo',
    appId: '1:262578778971:android:21cd554a3ae33c500b207e',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  /// Web uygulaması ("HizmetCep Web") — `web/fcm_yapilandirma.js` ile AYNI
  /// genel değerler. Web push ayrı JS köprüsündedir; bu seçenekler Flutter
  /// tarafındaki Firebase Authentication içindir.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCr9t1Ywo6G5Dep944wEvs_QVeUlu2pG8g',
    appId: '1:262578778971:web:9e7e25bb909ab7720b207e',
    messagingSenderId: _senderId,
    projectId: _projectId,
    authDomain: 'hizmetcep-fe036.firebaseapp.com',
    storageBucket: _storageBucket,
  );

  /// Bu derlemenin Firebase seçenekleri (Auth + push için TEK KAYNAK).
  static FirebaseOptions? get aktif {
    if (kIsWeb) {
      return web;
    }
    return switch (defaultTargetPlatform) {
      // Debug derleme türü `.debug` paketidir (applicationIdSuffix);
      // profile ve release `com.hizmetcep.app`.
      TargetPlatform.android => kDebugMode ? androidDebug : android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  /// Mobil push (FCM) seçenekleri. Web push ayrı JS köprüsündedir.
  static FirebaseOptions? get mobil => kIsWeb ? null : aktif;
}
