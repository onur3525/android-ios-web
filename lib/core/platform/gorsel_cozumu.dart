import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

// ═══════════════════════════════════════════════════════════════
// FOTOĞRAF BOYUTU — TEK KAYNAK (28 Eki, performans denetimi)
// ═══════════════════════════════════════════════════════════════
//
// Sorun 1: gerçek API modunda seçilen fotoğraf KÜÇÜLTÜLMEDEN
// yükleniyordu (telefon kamerası 12–50 MP). Yükleme yavaş, mobil veri
// yüksek; sunucudan geri gelen dosya da aynı büyüklükte.
//
// Sorun 2: ağdan gelen görseller ekrandaki boyuta bakılmadan TAM
// çözünürlükte çözülüyordu. 12 MP'lik bir fotoğraf küçük bir kartta
// görünse bile bellekte ≈ 48 MB (4000 × 3000 × 4 bayt) yer tutar;
// listelerde kaydırma takılır, eski telefonlarda uygulama kapanabilir.
//
// Çözüm: (1) seçimde en çok `kYuklemeGorselEnFazlaGenislik` piksel;
// (2) ağ görseli, kutunun BÜYÜK kenarı × ekran piksel oranı ×
// `kCozumPayi` genişliğinde çözülür (en çok `kAzamiCozumGenisligi`).
//
// ⚠ GÖRÜNÜM DEĞİŞMEZ: çözülen genişlik ekrandaki piksel sayısından
// büyüktür (pay 1,5; `BoxFit.cover` ile kırpılan dikey/yatay farkı için).
// ⚠ TAM EKRAN YAKINLAŞTIRMA (4×) bu sınırı KULLANMAZ: görüntüleyiciler
// `tamCozunurluk: true` ile eskisi gibi tam çözünürlükte çizer.
// ⚠ WEB'DE DEĞİŞMEZ: tarayıcı görseli kendi çözer; `null` döner.

/// Yüklenecek fotoğrafın en büyük genişliği (piksel).
const double kYuklemeGorselEnFazlaGenislik = 1600;

/// Çözüm genişliği için pay — `cover` kırpma farkını karşılar.
const double kCozumPayi = 1.5;

/// Kart/liste görselleri için en büyük çözüm genişliği (piksel).
const int kAzamiCozumGenisligi = 2048;

/// Ağ görselinin çözüleceği genişlik; bilinmiyorsa ya da web'de `null`
/// (tam çözünürlük — önceki davranış).
int? gorselCozumGenisligi(
  BuildContext context, {
  double? genislik,
  double? yukseklik,
}) {
  if (kIsWeb) {
    return null;
  }
  final kenarlar = [
    if (genislik != null && genislik.isFinite && genislik > 0) genislik,
    if (yukseklik != null && yukseklik.isFinite && yukseklik > 0) yukseklik,
  ];
  if (kenarlar.isEmpty) {
    return null;
  }
  final oran = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  final piksel = (kenarlar.reduce(math.max) * oran * kCozumPayi).ceil();
  return math.min(piksel, kAzamiCozumGenisligi);
}

/// Kutunun kısıtlarından (LayoutBuilder) çözüm genişliği.
int? kisittanCozumGenisligi(
  BuildContext context,
  BoxConstraints kisit, {
  double? genislik,
  double? yukseklik,
}) =>
    gorselCozumGenisligi(
      context,
      genislik: genislik ?? kisit.maxWidth,
      yukseklik: yukseklik ?? kisit.maxHeight,
    );
