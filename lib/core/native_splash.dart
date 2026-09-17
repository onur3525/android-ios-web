import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// NATIVE SPLASH KÖPRÜSÜ
///
/// Kullanıcıya gösterilen TEK marka splash'ı native splash'tır.
/// Native taraf splash'ı şu iki koşul sağlanana kadar ekranda
/// tutar:
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
  /// ── ⚠ iOS DA KAPSAMA ALINDI (16 Eyl) ──
  ///
  /// Koşul `!= TargetPlatform.android` idi: iOS'ta kanal HİÇ
  /// çağrılmıyordu. `AppDelegate` tarafına aynı kanal eklenince bu
  /// erken dönüş, yeni köprüyü ölü kod hâline getirirdi.
  ///
  /// ⚠ SÖZLEŞME DEĞİŞMEDİ: kanal adı ve metot adı iki platformda da
  /// aynı; burada değişen yalnız HANGİ platformların köprüyü
  /// çağırdığı.
  ///
  /// ⚠ WEB VE ÖTEKİ PLATFORMLAR DIŞARIDA: orada native splash yok.
  ///
  /// Hata yutulur: köprü yoksa (test, eski sürüm) açılış
  /// engellenmemelidir.
  static Future<void> bootReady() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _kanal.invokeMethod<void>('bootReady');
    } catch (_) {
      // Köprü yok — native splash ilk kareyle zaten kalkar.
    }
  }
}
