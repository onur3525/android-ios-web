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
