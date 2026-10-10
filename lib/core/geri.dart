import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// GÜVENLİ GERİ
///
/// ⚠ `Navigator.maybePop` yığında geri dönülecek route yoksa SESSİZCE
/// HİÇBİR ŞEY YAPMAZ. `pushReplacement`/`pushNamedAndRemoveUntil` ile
/// açılan ekranlarda geri butonu ölü kalır.
///
/// Bu yardımcı geri dönülebiliyorsa döner, dönülemiyorsa uygulamanın
/// ana ekranına gider — buton hiçbir durumda işlevsiz kalmaz.
void geriGit(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    nav.pushNamedAndRemoveUntil('/home', (_) => false);
  }
}

/// ── KAYIT SONRASI GEZİNME — TEK KAYNAK ──
///
/// Kenar çubuğundan açılan form sayfalarında (Adreslerim, Profil
/// Bilgilerim, Hizmet Bölgelerim, Hizmet Kategorilerim) "Güncelle"ye
/// basılınca:
///   · WEB: AYNI SAYFADA KALINIR (kullanıcı kararı). Sayfa kenar
///     çubuğunun bir bölümüdür; geri gitmek kullanıcıyı alakasız bir
///     ekrana atıyordu. Başarı bildirimi zaten gösteriliyor.
///   · MOBİL: [mobilde] çağrılır — ekranın bugünkü davranışı AYNEN
///     (geri dönüş).
void kayittanSonra(BuildContext context, VoidCallback mobilde) {
  if (kIsWeb) {
    return;
  }
  mobilde();
}
