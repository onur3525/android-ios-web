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

  /// Bu platformda push destekleniyor mu (mobil)? Web ayrı köprüdedir.
  static FirebaseOptions? get mobil => switch (defaultTargetPlatform) {
        _ when kIsWeb => null,
        TargetPlatform.android => android,
        TargetPlatform.iOS => ios,
        _ => null,
      };
}
