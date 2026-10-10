// Platform köprüsü: mobil (FlutterFire) / web (web/fcm_web.js).
// Ortak imza:
//   Future<bool> pushBaslat({onMesaj, onAcildi, onToken})
//   Future<String?> pushIzinIsteVeTokenAl()
//   Future<void> pushTokenSil()
export 'push_platform_mobil.dart'
    if (dart.library.js_interop) 'push_platform_web.dart';
