import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 21 Eki (kullanıcı bulgusu): sistem bildirimi Samsung'da renkli logoyla,
/// Xiaomi'de tek renk küçük simgeyle görünüyordu. Android bildirimi artık
/// uygulamanın native alıcısı çizer (renkli logo = büyük simge); sunucu
/// Android'e yalnız veri gönderir (backend/test/fcm.test.js).
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final alici = File('android/app/src/main/kotlin/com/hizmetcep/app/BildirimAlici.kt')
      .readAsStringSync();
  final aktivite = File('android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt')
      .readAsStringSync();
  final dart = File('lib/core/push/push_platform_mobil.dart').readAsStringSync();

  test('alıcı FCM yayınına kayıtlı ve yalnız Google gönderebilir', () {
    expect(manifest.contains('android:name=".BildirimAlici"'), isTrue);
    expect(manifest.contains('com.google.android.c2dm.intent.RECEIVE'), isTrue);
    expect(manifest.contains('android:permission="com.google.android.c2dm.permission.SEND"'), isTrue);
  });

  test('bildirim: marka simgesi + renkli logo; Samsung\'da logo iki kez çizilmez', () {
    expect(alici.contains('setSmallIcon(R.drawable.ic_stat_hizmetcep)'), isTrue);
    expect(alici.contains('setLargeIcon'), isTrue);
    expect(alici.contains('Build.MANUFACTURER.equals("samsung", ignoreCase = true)'), isTrue);
    // Yalnız sunucunun işaretlediği mesajlar çizilir; önde çizilmez.
    expect(alici.contains('"hcYerel"'), isTrue);
    expect(alici.contains('MainActivity.onde'), isTrue);
  });

  test('dokunma köprüsü native ve Dart\'ta aynı ad ve alanlarla', () {
    expect(aktivite.contains('"hizmetcep/bildirim"'), isTrue);
    expect(dart.contains("MethodChannel('hizmetcep/bildirim')"), isTrue);
    for (final alan in const ['type', 'bildirimId', 'hedef', 'id']) {
      expect(alici.contains('"$alan"'), isTrue, reason: alan);
    }
    expect(dart.contains("invokeMapMethod<String, Object?>('ilk')"), isTrue);
    expect(dart.contains("c.method == 'acildi'"), isTrue);
  });
}
