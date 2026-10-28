import 'package:flutter/painting.dart';

// ⚠ WEB: DEĞİŞİKLİK YOK (28 Eki). Tarayıcı, sunucunun "değişmez, sakla"
// (Cache-Control: immutable) başlığına uyarak fotoğrafı kendi önbelleğinde
// tutar; ayrı bir kalıcı önbellek gerekmez. Bu, `Image.network`un
// kullandığı sağlayıcının AYNISIDIR.
ImageProvider kaliciAgGorseli(
  String url, {
  WebHtmlElementStrategy webHtmlElementStrategy = WebHtmlElementStrategy.never,
}) =>
    NetworkImage(url, webHtmlElementStrategy: webHtmlElementStrategy);
