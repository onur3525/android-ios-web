import 'dart:js_interop';

/// ═══════════════════════════════════════════════════════════════
/// SEKME DURUMU — `window.sessionStorage`
///
/// Neden: mobil tarayıcıda "Masaüstü sitesi" açılıp kapatılınca (ya da
/// sayfa yenilenince) tarayıcı sayfayı BAŞTAN yükler; Flutter'ın
/// bellekteki durumu (oturum, açık ekran) sıfırlanırdı. sessionStorage
/// yenilemede KORUNUR, sekme kapanınca SİLİNİR — kalıcı depo değildir.
///
/// ⚠ API modunda erişim/yenileme JETONU buraya YAZILMAZ (M-05 kararı;
/// canlıda oturum HttpOnly çerezle yenilemeyi zaten atlatır).
/// ═══════════════════════════════════════════════════════════════
@JS('sessionStorage')
external _Depo? get _depo;

extension type _Depo(JSObject _) implements JSObject {
  external JSString? getItem(JSString anahtar);
  external void setItem(JSString anahtar, JSString deger);
  external void removeItem(JSString anahtar);
}

String? sekmeOku(String anahtar) {
  try {
    return _depo?.getItem(anahtar.toJS)?.toDart;
  } catch (_) {
    return null; // gizli mod / depo kapalı: yenilemede sıfırdan açılır
  }
}

void sekmeYaz(String anahtar, String deger) {
  try {
    _depo?.setItem(anahtar.toJS, deger.toJS);
  } catch (_) {}
}

void sekmeSil(String anahtar) {
  try {
    _depo?.removeItem(anahtar.toJS);
  } catch (_) {}
}

/// ── KALICI DEPO (localStorage) — YALNIZ WEB DEMO (mock) VERİSİ ──
///
/// Kullanıcı kararı (1 Eki): web demosu MOBİLDEKİ GİBİ davranır — demo
/// hesaplar ve demo veri (ilan, teklif, mesaj…) sekme/tarayıcı kapansa
/// da korunur; iki rol rahatça test edilir. Oturum yine sekmeye özeldir;
/// tarayıcı kapanınca oturumu "Beni hatırla" geri getirir (mobildeki gibi).
/// ⚠ API modunda KULLANILMAZ; jeton buraya yazılmaz.
@JS('localStorage')
external _Depo? get _kalici;

String? kaliciOku(String anahtar) {
  try {
    return _kalici?.getItem(anahtar.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void kaliciYaz(String anahtar, String deger) {
  try {
    _kalici?.setItem(anahtar.toJS, deger.toJS);
  } catch (_) {}
}

@JS('addEventListener')
external void _olayDinle(JSString tur, JSFunction f);

extension type _DepoOlayi(JSObject _) implements JSObject {
  external JSString? get key;
}

/// BAŞKA SEKME kalıcı depoyu değiştirince çağrılır (tarayıcı `storage`
/// olayı; aynı sekmenin kendi yazımında tetiklenmez). İki sekmede iki
/// rol aynı anda test edilirken veriler birbirini EZMEZ, eşitlenir.
void kaliciDegisince(void Function(String anahtar) f) {
  try {
    _olayDinle('storage'.toJS, ((_DepoOlayi e) {
      final k = e.key?.toDart;
      if (k != null) {
        f(k);
      }
    }).toJS);
  } catch (_) {}
}
