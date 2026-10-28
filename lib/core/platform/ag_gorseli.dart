import 'package:flutter/widgets.dart';

import 'kalici_gorsel_io.dart' if (dart.library.html) 'kalici_gorsel_web.dart';

// ═══════════════════════════════════════════════════════════════
// AĞ GÖRSELİ — TEK KAYNAK (28 Eki)
// ═══════════════════════════════════════════════════════════════
//
// Uygulamadaki BÜTÜN ağ fotoğrafları (ana sayfa çatıları, ilan, teklif,
// sohbet, profil, tam ekran görüntüleyiciler) bu bileşenden çizilir.
//   · Mobil: kalıcı önbellek (bkz. `kalici_gorsel_io.dart`) — uygulama
//     yeniden açılınca fotoğraf internetten DEĞİL telefondan gelir.
//   · Web: `Image.network` ile birebir aynı (tarayıcı önbelleği).
// `cacheWidth` verilirse görsel o genişlikte çözülür (bkz. gorsel_cozumu.dart).
Widget agGorseli(
  String url, {
  double? width,
  double? height,
  BoxFit? fit,
  int? cacheWidth,
  ImageErrorWidgetBuilder? errorBuilder,
  ImageFrameBuilder? frameBuilder,
  WebHtmlElementStrategy webHtmlElementStrategy = WebHtmlElementStrategy.never,
}) =>
    Image(
      image: ResizeImage.resizeIfNeeded(
        cacheWidth,
        null,
        kaliciAgGorseli(url, webHtmlElementStrategy: webHtmlElementStrategy),
      ),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
      frameBuilder: frameBuilder,
    );
