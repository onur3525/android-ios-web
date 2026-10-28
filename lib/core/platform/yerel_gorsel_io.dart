import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'gorsel_cozumu.dart';
import 'gorsel_yedegi.dart';

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
  // ⚠ 28 Eki: tam ekran yakınlaştırmalı görüntüleyiciler `true` verir;
  // ağ görseli eskisi gibi TAM çözünürlükte çözülür.
  bool tamCozunurluk = false,
}) =>
    // ⚠ SUNUCU FOTOĞRAFI (imzalı https adresi): ağdan çizilir. Yerel
    // dosya yolları `https://` ile başlamaz; onların davranışı AYNEN.
    _uzakMi(yol)
        ? (tamCozunurluk
            ? Image.network(
                yol,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, _, __) =>
                    (hataYedegi ?? varsayilanGorselYedegi)(context),
              )
            // ⚠ 28 Eki: ekrandaki boyuta göre çözülür (bkz.
            // `gorsel_cozumu.dart`). Görünüm aynı, bellek çok daha az.
            : LayoutBuilder(
                builder: (context, kisit) => Image.network(
                  yol,
                  width: width,
                  height: height,
                  fit: fit,
                  cacheWidth: kisittanCozumGenisligi(context, kisit,
                      genislik: width, yukseklik: height),
                  // ⚠ YEDEK HER ZAMAN VAR (11 Eki): verilmezse nötr yer
                  // tutucu çizilir; ham hata kutusu kullanıcıya görünmez.
                  errorBuilder: (context, _, __) =>
                      (hataYedegi ?? varsayilanGorselYedegi)(context),
                ),
              ))
        : Image.file(
            File(yol),
            width: width,
            height: height,
            fit: fit,
            // ⚠ YEDEK HER ZAMAN VAR (11 Eki): verilmezse nötr yer
            // tutucu çizilir; ham hata kutusu kullanıcıya görünmez.
            errorBuilder: (context, _, __) =>
                (hataYedegi ?? varsayilanGorselYedegi)(context),
          );

bool _uzakMi(String yol) => yol.startsWith('https://');

/// Dosyanın baytları — yükleme akışı için.
Future<Uint8List> yerelBaytlar(String yol) => File(yol).readAsBytes();

/// Dosya hâlâ duruyor mu?
///
/// ⚠ EŞ ZAMANLI (`existsSync`): çağrıldığı yerler `build` içinde ve
/// bugünkü davranış budur.
bool yerelVarMi(String yol) => _uzakMi(yol) || File(yol).existsSync();

/// Dosyanın bayt boyutu — yükleme öncesi `sizeBytes` için.
Future<int> yerelBoyut(String yol) => File(yol).length();

/// Mobilde dosya yolu zaten kalıcıdır; olduğu gibi döner
/// (web karşılığı için bkz. `yerel_gorsel_web.dart`).
Future<String> kaliciYerelYol(String yol, {String? tur}) async => yol;

/// Mobilde seçici boyutu DEĞİŞMEZ (web karşılığı 1280).
const double? kaliciGorselEnFazlaGenislik = null;
