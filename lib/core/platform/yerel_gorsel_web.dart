import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';

// ⚠ WEB UYGULAMASI — TARAYICI.
//
// Tarayıcıda dosya sistemi YOKTUR. `image_picker` web'de `XFile.path`
// olarak `blob:https://...` biçiminde bir adres döndürür; bu adres
// yalnız sekme yaşadığı sürece geçerlidir ve `dart:io` ile
// okunamaz.
//
// ⚠ `cross_file` YENİ BİR BAĞIMLILIK DEĞİLDİR: `image_picker` zaten
// onu getirir (`XFile` o pakettedir). pubspec'e paket eklenmedi.

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
}) =>
    Image.network(
      yol,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: hataYedegi == null
          ? null
          : (context, _, __) => hataYedegi(context),
    );

/// Baytlar — `XFile` blob adresinden okur.
Future<Uint8List> yerelBaytlar(String yol) => XFile(yol).readAsBytes();

/// ⚠ WEB'DE KARŞILIĞI YOK: tarayıcıda "dosya duruyor mu" sorusu
/// sorulamaz. Adres boş değilse var sayılır; gerçekten geçersizse
/// çizim aşamasındaki `hataYedegi` devreye girer.
bool yerelVarMi(String yol) => yol.trim().isNotEmpty;

/// ⚠ WEB'DE BOYUT BLOB'DAN OKUNUR: `XFile.length()` blob'un
/// uzunluğunu verir; dosya sistemine erişmez.
Future<int> yerelBoyut(String yol) => XFile(yol).length();
