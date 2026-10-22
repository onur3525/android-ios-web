// YASAL BELGE PDF'İNİ AÇMA — TEK YER (22 Eki)
//
// Sunucu PDF adresini göreli verir (`/api/v1/legal/<slug>/pdf/<sürüm>`);
// YALNIZ bu kalıp kabul edilir ve API sunucusunun kendi kökenine çözülür.
// Mobilde cihazın PDF görüntüleyicisinde/tarayıcısında, web'de yeni
// sekmede açılır (`acilisModu`).
import 'package:url_launcher/url_launcher.dart';

import '../data/remote/api_config.dart';
import 'baglanti_modu.dart';

final RegExp _pdfKalibi = RegExp(r'^/api/v1/legal/[a-z][a-z0-9-]{1,40}/pdf/\d{1,6}$');

/// Göreli PDF yolunun tam adresi; kalıba uymuyorsa null.
Uri? yasalPdfAdresi(Object? goreli) {
  if (goreli is! String || !_pdfKalibi.hasMatch(goreli)) {
    return null;
  }
  return Uri.parse('${Uri.parse(ApiConfig.baseUrl).origin}$goreli');
}

/// PDF'i açar; açılamazsa false.
Future<bool> yasalPdfAc(Object? goreli) async {
  final u = yasalPdfAdresi(goreli);
  if (u == null) {
    return false;
  }
  try {
    return await launchUrl(u, mode: acilisModu());
  } catch (_) {
    return false;
  }
}
