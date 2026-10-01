import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../push/firebase_secenekleri.dart';

/// ═══════════════════════════════════════════════════════════════
/// FIREBASE BAŞLATICI — TEK KAYNAK (push + kimlik doğrulama)
///
/// Önceden Firebase yalnız push katmanında başlatılıyordu; şimdi kimlik
/// doğrulama da aynı varsayılan uygulamayı kullanır. Başlatma TEMBELDİR
/// (ilk ihtiyaçta) ve tek seferliktir: açılışı geciktirmez, iki katman
/// aynı anda istese de bir kez çalışır.
///
/// Web: Flutter tarafındaki Firebase (Auth) burada başlatılır. Web push'un
/// JS köprüsü (`web/fcm_web.js`) kendi adlı uygulamasını kullanır; ikisi
/// çakışmaz.
/// ═══════════════════════════════════════════════════════════════
Future<FirebaseApp?>? _bekleyen;

Future<FirebaseApp?> firebaseHazirla() => _bekleyen ??= _baslat();

Future<FirebaseApp?> _baslat() async {
  final secenek = FirebaseSecenekleri.aktif;
  if (secenek == null) {
    return null;
  }
  try {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }
    return await Firebase.initializeApp(options: secenek);
  } catch (e) {
    debugPrint('FIREBASE_BASLATILAMADI ${e.runtimeType}');
    _bekleyen = null; // sonraki istekte yeniden denenir
    return null;
  }
}
