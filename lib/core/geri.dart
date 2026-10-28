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
/// Form sayfalarında (Adreslerim, Profil Bilgilerim, Hizmet Bölgelerim,
/// Hizmet Kategorilerim) kaydedince AYNI SAYFADA KALINIR — web'de de
/// mobilde de.
///
/// ⚠ 28 Eki (kullanıcı kararı): "Kaydedildi yazısı kalmalı ve ekranda
/// kalmalı; kullanıcı kendi çıkmadan otomatik çıkmamalı." Önceden mobilde
/// [mobilde] çağrılıp ekran hemen kapanıyordu; kullanıcı düğmedeki
/// "✓ Kaydedildi" onayını göremeden profil ekranına atılıyordu. Onay
/// düğmede kalır (bkz. core/kaydedildi.dart); kullanıcı geri okuyla çıkar.
///
/// [mobilde] artık ÇAĞRILMAZ; çağrı yerleri değişmesin diye imza korundu.
void kayittanSonra(BuildContext context, VoidCallback mobilde) {}
