import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'baglanti_modu.dart';
import 'sys_state.dart';
import 'validators.dart';

/// ═══════════════════════════════════════════════════════════════
/// TELEFONLA ARA — TEK KAYNAK (15 Eki)
///
/// `<a href="tel:...">` karşılığı: telefon uygulamasını numara yazılı
/// açar; aramayı kullanıcı "Ara" ile başlatır (web sitesi aramayı kendi
/// başlatamaz).
///
/// ## ⚠ NİÇİN TAŞINDI
///
/// Aynı işlev dört ekranda ayrı kopya olarak duruyordu (teklif talebi,
/// ilan, teklif detayı, sohbet).
///
/// ## ⚠ WEB: AYNI SEKMEDE AÇILIR
///
/// `url_launcher` web'de varsayılan olarak YENİ PENCERE açar. Telefonda
/// Chrome boş (siyah) bir sekme açıp `tel:` bağlantısını işletim
/// sistemine devrediyor, sonra sekmeyi kapatıyordu (kullanıcı bulgusu:
/// "siyah ekran gelip kayboluyor"). `_self` ile bağlantı aynı sekmede
/// işlenir; sayfa değişmez, arama ekranı doğrudan açılır.
///
/// ⚠ MOBİL DEĞİŞMEZ: `webOnlyWindowName` yalnız web'de okunur; mod
/// `acilisModu()` ile aynı kalır.
/// ═══════════════════════════════════════════════════════════════
Future<void> telefonuAra(BuildContext context, String? ham) async {
  final d = Validators.phoneLocal(ham ?? '');
  if (d.isEmpty) {
    return;
  }
  final acildi = await launchUrl(
    Uri.parse('tel:$d'),
    mode: acilisModu(),
    webOnlyWindowName: kIsWeb ? '_self' : null,
  );
  // ⚠ Sahte başarı YOK: arama uygulaması açılamazsa kullanıcı uyarılır.
  if (!acildi && context.mounted) {
    sysToastErr(context, SysKind.genericError,
        extra: 'Arama uygulaması açılamadı');
  }
}
