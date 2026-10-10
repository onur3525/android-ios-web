import 'dart:convert';
import 'dart:js_interop';

/// ═══════════════════════════════════════════════════════════════
/// WEB PUSH — `web/fcm_web.js` köprüsü
///
/// FlutterFire'ın web getToken'ı servis çalışanını SİTE KÖKÜNE
/// (`/firebase-messaging-sw.js`) kaydetmeye çalışır; GitHub Pages'te
/// uygulama `/android-ios-web/` alt yolunda olduğu için bu 404 verir.
/// Bu yüzden web'de kendi küçük köprümüz kullanılır: servis çalışanı
/// base-href'e GÖRELİ kaydedilir, VAPID genel anahtarıyla jeton alınır.
///
/// Web yapılandırması (web uygulaması appId'si) `web/fcm_yapilandirma.js`
/// içinde boşsa köprü KAPALI kalır; uygulama etkilenmez.
/// ═══════════════════════════════════════════════════════════════
@JS('hcFcm')
external _HcFcm? get _hcFcm;

extension type _HcFcm(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> baslat(JSFunction olay);
  external JSPromise<JSString?> izinVeToken();
  external JSPromise<JSAny?> tokenSil();
}

bool _basladi = false;

Map<String, dynamic> _coz(String s) {
  try {
    final v = jsonDecode(s);
    return v is Map<String, dynamic> ? v : const {};
  } catch (_) {
    return const {};
  }
}

Future<bool> pushBaslat({
  required void Function(Map<String, dynamic> veri) onMesaj,
  required void Function(Map<String, dynamic> veri) onAcildi,
  required void Function(String token) onToken,
}) async {
  if (_basladi) {
    return true;
  }
  // `fcm_web.js` bir ES modülüdür (ertelenmiş yüklenir); en fazla 5 sn beklenir.
  var k = _hcFcm;
  for (var i = 0; k == null && i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    k = _hcFcm;
  }
  if (k == null) {
    return false;
  }
  try {
    final ok = await k
        .baslat(((JSString tur, JSString veri) {
          final m = _coz(veri.toDart);
          if (tur.toDart == 'mesaj') {
            onMesaj(m);
          } else if (tur.toDart == 'acildi') {
            onAcildi(m);
          }
        }).toJS)
        .toDart;
    _basladi = ok.toDart;
    // Bildirime tıklanıp YENİ sekmede açıldıysa veri adreste gelir.
    final ilk = Uri.base.queryParameters['hc_push'];
    if (_basladi && ilk != null) {
      onAcildi(_coz(ilk));
    }
    return _basladi;
  } catch (_) {
    return false;
  }
}

Future<String?> pushIzinIsteVeTokenAl() async {
  final k = _hcFcm;
  if (!_basladi || k == null) {
    return null;
  }
  try {
    return (await k.izinVeToken().toDart)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<void> pushTokenSil() async {
  final k = _hcFcm;
  if (!_basladi || k == null) {
    return;
  }
  try {
    await k.tokenSil().toDart;
  } catch (_) {}
}
