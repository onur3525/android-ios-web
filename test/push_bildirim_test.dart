import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/push_kapisi.dart';

/// PUSH BİLDİRİM (FCM) — Flutter tarafı
///
/// ⚠ Gerçek Firebase bağlantısı testte çalışmaz (yerel eklenti yok;
/// `push_platform_mobil.dart` FLUTTER_TEST ortamında push'u kapatır).
String _oku(String y) => File(y).readAsStringSync();

void main() {
  group('BİLDİRİME DOKUNMA → GÜVENLİ ROTA', () {
    test('yalnız tablodaki hedefler, yalnız güvenli kimlik', () {
      expect(pushRotasi({'hedef': 'ilan', 'id': 'abc-123'}), '/ilan/abc-123');
      expect(pushRotasi({'hedef': 'mesaj', 'id': 'f00d'}), '/mesaj/f00d');
      expect(pushRotasi({'hedef': 'talep', 'id': 'x1'}), '/talep/x1');
      // Bilinmeyen hedef, yol enjeksiyonu, dış adres → Bildirimler
      expect(pushRotasi({'hedef': 'admin', 'id': '1'}), '/notifications');
      expect(pushRotasi({'hedef': 'ilan', 'id': '../profile'}), '/notifications');
      expect(pushRotasi({'hedef': 'ilan', 'id': 'https://kotu.com'}), '/notifications');
      expect(pushRotasi(const {}), '/notifications');
    });
  });

  group('GÜVENLİK', () {
    test('gizli anahtar depoda yok; jeton kalıcı depoya yazılmaz', () {
      for (final y in ['web/fcm_yapilandirma.js', 'web/fcm_web.js', 'web/firebase-messaging-sw.js',
          'lib/core/push/firebase_secenekleri.dart', 'lib/ui/push_kapisi.dart']) {
        final s = _oku(y);
        expect(s.contains('PRIVATE KEY'), isFalse, reason: y);
        expect(s.contains('private_key'), isFalse, reason: y);
        expect(s.contains('localStorage'), isFalse, reason: y);
      }
      final k = _oku('lib/ui/push_kapisi.dart');
      expect(k.contains('FlutterSecureStorage'), isFalse);
      expect(k.contains('SharedPreferences'), isFalse);
    });
  });

  group('WEB — base-href uyumu', () {
    test('servis çalışanı base-href\'e GÖRELİ; kök yol yok', () {
      final w = _oku('web/fcm_web.js');
      expect(w.contains("new URL('firebase-messaging-sw.js', taban)"), isTrue);
      expect(w.contains("'/firebase-messaging-sw.js'"), isFalse);
      final h = _oku('web/index.html');
      expect(h.contains('<script src="fcm_yapilandirma.js"></script>'), isTrue);
      expect(h.contains('<base href="\$FLUTTER_BASE_HREF">'), isTrue);
    });
  });

  group('PLATFORM AYARLARI', () {
    test('Android 13 bildirim izni, iOS arka plan modu ve hedef 13.0', () {
      expect(_oku('android/app/src/main/AndroidManifest.xml').contains('android.permission.POST_NOTIFICATIONS'), isTrue);
      final p = _oku('ios/Runner/Info.plist');
      expect(p.contains('<string>remote-notification</string>'), isTrue);
      expect(_oku('ios/Podfile').contains("platform :ios, '13.0'"), isTrue);
    });
    test('kökte bağlı; izin yalnız girişte istenir', () {
      expect(_oku('lib/main.dart').contains('builder: (context, child) => PushKapisi('), isTrue);
      final k = _oku('lib/ui/push_kapisi.dart');
      expect(k.contains('final t = await pushIzinIsteVeTokenAl();'), isTrue);
    });
  });
}
