import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/widgets.dart';

import 'gorsel_yedegi.dart';

// ⚠ WEB UYGULAMASI — TARAYICI.
//
// Tarayıcıda dosya sistemi YOKTUR. `image_picker` web'de `XFile.path`
// olarak `blob:https://...` biçiminde bir adres döndürür; bu adres
// yalnız sekme yaşadığı sürece geçerlidir ve `dart:io` ile
// okunamaz.
//
// ⚠ `XFile` doğrudan `cross_file`tan DEĞİL, bağımlılığımız olan
// `image_picker`ın yeniden dışa aktarımından alınır (analyze:
// depend_on_referenced_packages). pubspec'e paket eklenmedi; kilit
// dosyası değişmez.

/// `data:` adresi mi? (bkz. [kaliciYerelYol])
bool _veriAdresiMi(String yol) => yol.startsWith('data:');

/// Çözülmüş baytlar önbelleği: her yeniden çizimde aynı baytlar
/// döner — `Image.memory` görseli yeniden çözmez, titreme olmaz.
final Map<String, Uint8List> _veriOnbellegi = {};

Uint8List? _veriBaytlari(String yol) {
  final hazir = _veriOnbellegi[yol];
  if (hazir != null) return hazir;
  try {
    final b = UriData.parse(yol).contentAsBytes();
    if (_veriOnbellegi.length >= 40) {
      _veriOnbellegi.remove(_veriOnbellegi.keys.first);
    }
    return _veriOnbellegi[yol] = b;
  } catch (_) {
    return null;
  }
}

/// Blob adresini çizer.
///
/// ⚠ `Image.network` KULLANILIR: tarayıcı `blob:` adresini normal bir
/// kaynak gibi çözer. `Image.file` web'de yoktur.
Widget yerelGorsel(
  String yol, {
  double? width,
  double? height,
  BoxFit? fit,
  WidgetBuilder? hataYedegi,
}) {
  // ⚠ KALICI YEREL GÖRSEL (`data:`): sayfa yenilense de çizilir.
  if (_veriAdresiMi(yol)) {
    final b = _veriBaytlari(yol);
    if (b == null) {
      return SizedBox(
          width: width,
          height: height,
          child: Builder(builder: hataYedegi ?? varsayilanGorselYedegi));
    }
    return Image.memory(
      b,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, _, __) =>
          (hataYedegi ?? varsayilanGorselYedegi)(context),
    );
  }
  return Image.network(
      yol,
      width: width,
      height: height,
      fit: fit,
      // ⚠ YEDEK HER ZAMAN VAR (11 Eki): verilmezse nötr yer
      // tutucu çizilir; ham hata kutusu kullanıcıya görünmez.
      errorBuilder: (context, _, __) =>
          (hataYedegi ?? varsayilanGorselYedegi)(context),
    );
}

/// Baytlar — `XFile` blob adresinden (ya da `data:` adresinden) okur.
Future<Uint8List> yerelBaytlar(String yol) async {
  if (_veriAdresiMi(yol)) {
    final b = _veriBaytlari(yol);
    if (b == null) throw const FormatException('Geçersiz görsel verisi');
    return b;
  }
  return XFile(yol).readAsBytes();
}

/// ⚠ WEB'DE KARŞILIĞI YOK: tarayıcıda "dosya duruyor mu" sorusu
/// sorulamaz. Adres boş değilse var sayılır; gerçekten geçersizse
/// çizim aşamasındaki `hataYedegi` devreye girer.
bool yerelVarMi(String yol) => yol.trim().isNotEmpty;

/// ⚠ WEB'DE BOYUT BLOB'DAN OKUNUR: `XFile.length()` blob'un
/// uzunluğunu verir; dosya sistemine erişmez.
Future<int> yerelBoyut(String yol) async => _veriAdresiMi(yol)
    ? (_veriBaytlari(yol)?.length ?? 0)
    : XFile(yol).length();

/// ── ⚠ SAYFA YENİLENİNCE KAYBOLMAYAN YEREL GÖRSEL (14 Eki) ──
///
/// KULLANICI BULGUSU: telefonun tarayıcısında "Masaüstü sitesi" seçilince
/// sayfa baştan yükleniyor; talep fotoğrafı `blob:` adresiyle saklandığı
/// için yeniden açılmıyor ve "HTTP request failed, statusCode: 0, blob:…"
/// görünüyordu. `blob:` adresi YALNIZ o sayfa yaşadığı sürece geçerlidir.
///
/// Deneme (mock) modunda sunucu olmadığı için fotoğraf yerelde kalır;
/// web'de bu yüzden baytlar `data:` adresine çevrilir ve kayda o yazılır.
/// Gerçek API modunda çağrılmaz — orada fotoğraf sunucuya yüklenir.
Future<String> kaliciYerelYol(String yol, {String? tur}) async {
  if (!yol.startsWith('blob:')) {
    return yol;
  }
  final x = XFile(yol);
  final b = await x.readAsBytes();
  final mime = (tur != null && tur.startsWith('image/'))
      ? tur
      : (x.mimeType != null && x.mimeType!.startsWith('image/'))
          ? x.mimeType!
          : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(b)}';
}

/// Web deneme modunda seçici görseli küçültsün mü? (yerel depo sınırlı)
const double? kaliciGorselEnFazlaGenislik = 1280;
