// SPLASH ÇIKIŞI — ANİMASYONSUZ (KİLİT)
//
// ⚠ KULLANICI BULGUSU (9 Eyl, gerçek cihazda APK ile): "splash
// ekranın kapanmasına yakın anlık bir küçülme oldu logoda."
//
// SEBEP: `MainActivity`de `setOnExitAnimationListener` HİÇ TANIMLI
// DEĞİLDİ. Android 12+ splash'ı bırakırken, kimse devralmazsa
// sistemin VARSAYILAN çıkış animasyonunu oynatır — ikonu küçültüp
// soldurur.
//
// ⚠ İKİNCİ ADAY ELENDİ: küçülme ANLIK ve yalnız kapanış anındaydı.
// Native ikon kutusu ile `SplashView`in 240 dp'si uyuşmasaydı logo
// küçülüp ÖYLE KALIRDI. Bu yüzden `_kMarkaKutusu`ya dokunulmadı;
// iki şeyi birden değiştirmek hangisinin çözdüğünü ölçülemez yapardı.
//
// ⚠ NEDEN KOTLIN METNİ OKUNUYOR: `flutter test` Android kaynağını
// derlemez. Bu test kuralın kodda DURDUĞUNU kilitler — "cihazda
// düzeldi" iddiası ETMEZ, onu APK doğrular.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _yol = 'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt';

/// Kotlin kaynağından satır ve blok yorumlarını eler.
///
/// ⚠ GEREKLİ: bu dosyadaki açıklamalar hem eski davranışı hem yeni
/// kuralı ANLATIYOR; ham metinde arama yapmak yanlış alarm verirdi.
String _kodu() {
  final ham = File(_yol).readAsStringSync();
  final sb = StringBuffer();
  var i = 0;
  while (i < ham.length) {
    if (i + 1 < ham.length && ham[i] == '/' && ham[i + 1] == '/') {
      while (i < ham.length && ham[i] != '\n') {
        i++;
      }
      continue;
    }
    if (i + 1 < ham.length && ham[i] == '/' && ham[i + 1] == '*') {
      i += 2;
      while (i + 1 < ham.length && !(ham[i] == '*' && ham[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    sb.write(ham[i]);
    i++;
  }
  return sb.toString();
}

void main() {
  test('splash bırakılırken sistem animasyonu OYNATILMAZ', () {
    final k = _kodu();
    expect(k.contains('setOnExitAnimationListener'), isTrue,
        reason: 'listener kaldırılmış — sistemin varsayılan küçülme '
            'animasyonu geri gelir');
    expect(k.contains('.remove()'), isTrue,
        reason: 'splash yüzeyi animasyonsuz kaldırılmıyor');
  });

  test('⚠ SÜRELER VE TUTMA KOŞULU DEĞİŞMEDİ', () {
    // Değişen tek şey bırakma ANINDAKİ animasyondu. Süreler ya da
    // tutma koşulu da değişseydi, düzelmenin hangisinden geldiği
    // ölçülemezdi.
    final k = _kodu();
    expect(k.contains('SPLASH_MIN_MS = 2000L'), isTrue);
    expect(k.contains('SPLASH_MAX_MS = 9000L'), isTrue);
    expect(k.contains('setKeepOnScreenCondition'), isTrue);
  });

  test('⚠ FLUTTER SPLASH ÖLÇÜSÜNE DOKUNULMADI', () {
    // Elenen ikinci adayın kilidi: ölçü değiştirilirse bu test düşer
    // ve değişikliğin bilinçli olduğu yeniden kanıtlanması gerekir.
    final s = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(s.contains('const double _kMarkaKutusu = 240;'), isTrue,
        reason: 'marka kutusu değişmiş — küçülme sorunu bununla '
            'düzeltilmedi, sebep çıkış animasyonuydu');
  });
}
