/// MAĞAZA BAĞLANTILARI
///
/// Bu değerler ZORUNLU GÜNCELLEME yönlendirmesi için kullanılır.
/// Uygulama içi puanlama ayrı bir akıştır (bkz. app_rate_screen.dart) ve
/// mağazaya yönlendirme YAPMAZ — HTML referansındaki davranış budur.
///
/// Gerçek kimlikler:
///   Android paket adı : android/app/build.gradle → applicationId
///   iOS App Store ID  : App Store Connect'te uygulamaya atanan sayısal ID
///
/// Değerler derleme zamanında --dart-define ile geçilebilir; böylece
library;

import 'package:flutter/foundation.dart';


const String kAndroidPackage = String.fromEnvironment(
  'ANDROID_PACKAGE',
  defaultValue: 'com.hizmetcep.app',
);

const String kIosAppStoreId = String.fromEnvironment(
  'IOS_APP_STORE_ID',
  defaultValue: '6503417792',
);

/// Cihaz platformuna göre mağaza adresi.
/// Android'de önce `market://` denenir; mağaza uygulaması yoksa
/// [storeFallbackUrl] web adresine düşülür.
String storeUrlForPlatform() {
  if (kIsWeb) {
    return storeFallbackUrl();
  }
  // ⚠ `Platform` (dart:io) YERİNE `defaultTargetPlatform` — `dart:io`
  // web derlemesini kırıyordu. Mobilde AYNI değer döner.
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'https://apps.apple.com/app/id$kIosAppStoreId';
    }
  } catch (_) {
    // Test ortamı
  }
  return 'https://play.google.com/store/apps/details?id=$kAndroidPackage';
}

/// Mağaza uygulaması açılamazsa kullanılacak web adresi.
String storeFallbackUrl() {
  if (!kIsWeb) {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'https://apps.apple.com/app/id$kIosAppStoreId';
      }
    } catch (_) {
      // Test ortamı
    }
  }
  return 'https://play.google.com/store/apps/details?id=$kAndroidPackage';
}
