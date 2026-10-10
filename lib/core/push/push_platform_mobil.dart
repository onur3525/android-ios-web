import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_baslatici.dart';
import 'firebase_secenekleri.dart';

/// ── ARKA PLAN / UYGULAMA KAPALI ──
///
/// Uygulama arka plandayken ya da tamamen kapalıyken gelen mesaj için
/// ayrı bir izolat çalışır. `notification` içeren mesajı İŞLETİM SİSTEMİ
/// kendisi gösterir; burada yalnız Firebase başlatılır. Kullanıcı
/// bildirime dokununca uygulama `onMessageOpenedApp` /
/// `getInitialMessage` ile yönlendirir.
@pragma('vm:entry-point')
Future<void> pushArkaPlanMesaji(RemoteMessage mesaj) async {
  final secenek = FirebaseSecenekleri.mobil;
  if (secenek != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: secenek);
  }
}

bool _basladi = false;

Map<String, dynamic> _veri(RemoteMessage m) => {
      ...m.data,
      if (m.notification?.title != null) '_baslik': m.notification!.title,
      if (m.notification?.body != null) '_govde': m.notification!.body,
    };

Future<bool> pushBaslat({
  required void Function(Map<String, dynamic> veri) onMesaj,
  required void Function(Map<String, dynamic> veri) onAcildi,
  required void Function(String token) onToken,
}) async {
  // `flutter test` ortamında yerel eklenti yok: push devre dışı.
  if (_basladi || Platform.environment.containsKey('FLUTTER_TEST')) {
    return _basladi;
  }
  final secenek = FirebaseSecenekleri.mobil;
  if (secenek == null) {
    return false;
  }
  try {
    // ⚠ Ortak başlatıcı (kimlik doğrulamayla AYNI uygulama).
    if (await firebaseHazirla() == null) {
      return false;
    }
    FirebaseMessaging.onBackgroundMessage(pushArkaPlanMesaji);
    final fm = FirebaseMessaging.instance;
    // iOS: uygulama ÖNDEYKEN de sistem bildirimi gösterilsin.
    await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen((m) => onMesaj(_veri(m)));
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onAcildi(_veri(m)));
    fm.onTokenRefresh.listen(onToken);
    // Uygulama bir bildirime dokunularak KAPALIYKEN açıldıysa.
    final ilk = await fm.getInitialMessage();
    if (ilk != null) {
      onAcildi(_veri(ilk));
    }
    _basladi = true;
    return true;
  } catch (e) {
    debugPrint('PUSH_BASLATILAMADI ${e.runtimeType}');
    return false;
  }
}

/// İzin ister (iOS ve Android 13+ sistem penceresi) ve token döndürür.
/// İzin verilmezse null.
Future<String?> pushIzinIsteVeTokenAl() async {
  if (!_basladi) {
    return null;
  }
  try {
    final fm = FirebaseMessaging.instance;
    final izin = await fm.requestPermission(alert: true, badge: true, sound: true);
    if (izin.authorizationStatus != AuthorizationStatus.authorized &&
        izin.authorizationStatus != AuthorizationStatus.provisional) {
      return null;
    }
    // iOS: APNs jetonu hazır olmadan FCM jetonu alınamaz; kısa bekleme.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var i = 0; i < 5 && await fm.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return await fm.getToken();
  } catch (e) {
    debugPrint('PUSH_TOKEN_ALINAMADI ${e.runtimeType}');
    return null;
  }
}

Future<void> pushTokenSil() async {
  if (!_basladi) {
    return;
  }
  try {
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {
    // Ağ yoksa bir sonraki çıkışta/girişte yeniden denenir.
  }
}
