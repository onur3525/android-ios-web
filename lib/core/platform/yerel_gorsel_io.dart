import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

// ⚠ MOBİL UYGULAMA — ANDROID VE iOS.
//
// Gövdeler bugüne kadar ekranların içinde yazılı olan kodun BİREBİR
// aynısıdır. Android/iOS davranışı değişmez; değişen tek şey çağrının
// bir fonksiyon üzerinden geçmesidir.
//
// ⚠ BU DOSYA WEB DERLEMESİNE GİRMEZ: `yerel_gorsel.dart` içindeki
// koşullu export, web'de `_web` dosyasını seçer.

/// Cihazdaki dosyayı çizer.
///
/// ⚠ `errorBuilder` KORUNDU: kullanıcı fotoğrafı galeriden silmiş
/// olabilir; çökmek yerine yedek gösterilir.
Widget yerelGorsel(
  String yol, {
  double? width,
  double? height,
  BoxFit? fit,
  WidgetBuilder? hataYedegi,
}) =>
    Image.file(
      File(yol),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: hataYedegi == null
          ? null
          : (context, _, __) => hataYedegi(context),
    );

/// Dosyanın baytları — yükleme akışı için.
Future<Uint8List> yerelBaytlar(String yol) => File(yol).readAsBytes();

/// Dosya hâlâ duruyor mu?
///
/// ⚠ EŞ ZAMANLI (`existsSync`): çağrıldığı yerler `build` içinde ve
/// bugünkü davranış budur.
bool yerelVarMi(String yol) => File(yol).existsSync();

/// Dosyanın bayt boyutu — yükleme öncesi `sizeBytes` için.
Future<int> yerelBoyut(String yol) => File(yol).length();
