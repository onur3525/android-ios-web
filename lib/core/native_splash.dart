import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// NATIVE SPLASH KÖPRÜSÜ
///
/// Kullanıcıya gösterilen TEK marka splash'ı Android native
/// splash'tır. Native taraf splash'ı şu iki koşul sağlanana kadar
/// ekranda tutar:
///   1) en kısa süre (2000 ms) dolmuş olmalı,
///   2) Dart açılış kararını bildirmiş olmalı.
///
/// Bu sınıf ikinci koşulu bildirir. Böylece Flutter'ın ilk GÖRÜNÜR
/// karesi doğrudan hedef ekran olur; ikinci bir splash çizilmez.
class NativeSplash {
  const NativeSplash._();

  static const _kanal = MethodChannel('hizmetcep/splash');

  /// Açılış kararı hazır — native splash kaldırılabilir.
  ///
  /// Hata yutulur: köprü yoksa (iOS, test, eski sürüm) açılış
  /// engellenmemelidir.
  static Future<void> bootReady() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _kanal.invokeMethod<void>('bootReady');
    } catch (_) {
      // Köprü yok — native splash ilk kareyle zaten kalkar.
    }
  }
}
