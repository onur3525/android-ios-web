import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'baglanti_modu.dart';
import 'sys_state.dart';

/// ═══════════════════════════════════════════════════════════════
/// E-POSTA UYGULAMASINI AÇ — TEK KAYNAK (15 Eki)
///
/// `<a href="mailto:...">` karşılığı: cihazın e-posta uygulamasında alıcısı
/// dolu yeni ileti açılır; gönderimi kullanıcı yapar.
///
/// ⚠ WEB: AYNI SEKMEDE AÇILIR — `telefonuAra` ile aynı neden: varsayılan
/// YENİ PENCERE önce boş bir sekme açıyordu. `_self` ile bağlantı aynı
/// sekmede işlenir; sayfa değişmez, e-posta uygulaması doğrudan açılır.
/// Mobil davranış (`acilisModu()`) değişmez.
/// ═══════════════════════════════════════════════════════════════
Future<void> epostaUygulamasiniAc(BuildContext c, String adres) async {
  final uri = Uri(scheme: 'mailto', path: adres);
  try {
    final ok = await launchUrl(uri,
        mode: acilisModu(), webOnlyWindowName: kIsWeb ? '_self' : null);
    if (!ok && c.mounted) {
      sysToastErr(c, SysKind.genericError,
          extra: 'E-posta uygulaması bulunamadı: $adres');
    }
  } catch (_) {
    if (c.mounted) {
      sysToastErr(c, SysKind.genericError,
          extra: 'E-posta uygulaması açılamadı: $adres');
    }
  }
}
