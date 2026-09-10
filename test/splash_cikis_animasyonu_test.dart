// SPLASH ÇIKIŞI — DEVRALINIR, TEMA ELLE UYGULANIR (KİLİT)
//
// ⚠ KULLANICI BULGUSU: "Splash kapanmasına yakın logoda anlık bir
// küçülme oluyor."
//
// SEBEP: `setOnExitAnimationListener` tanımsızdı. Android 12+ splash'ı
// bırakırken kimse devralmazsa SİSTEMİN varsayılan çıkış animasyonunu
// oynatır — ikonu küçültüp soldurur.
//
// ⚠ 1. DENEME UYGULAMAYI BOZDU: yalnız `remove()` çağıran hâli,
// uygulamanın altında ve üstünde SİYAH BANTLAR bıraktı ve tamamen
// geri alındı. O turda Android tarafında değişen tek dosya bu dosya,
// tek değişiklik de bu listener'dı (MD5'lerle doğrulandı).
//
// EN GÜÇLÜ AÇIKLAMA: çıkış devralınınca `postSplashScreenTheme`
// geçişi uygulanmıyor ve pencere `Theme.SplashScreen` üzerinde
// kalıyor; o temanın sistem çubuğu renkleri koyu.
//
// ⚠ 2. DENEME BU YÜZDEN TEMAYI ELLE UYGULUYOR: `remove()`tan ÖNCE
// `NormalTheme`e geçilir. `styles.xml`de `postSplashScreenTheme`
// zaten bu temayı gösterir; yeni tema TANIMLANMADI.
//
// ⚠ HİPOTEZ, ÖLÇÜM DEĞİL: siyah bantlar yine çıkarsa açıklama
// yanlıştır ve blok BÜTÜNÜYLE geri alınmalıdır. Küçülme kozmetiktir,
// bozuk pencere değildir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _yol = 'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt';

void main() {
  final ham = File(_yol).readAsStringSync();

  test('çıkış devralınır ve animasyonsuz kaldırılır', () {
    expect(ham.contains('setOnExitAnimationListener'), isTrue);
    expect(ham.contains('yuzey.remove()'), isTrue);
  });

  test('⚠ TEMA ELLE UYGULANIR — SİYAH BANT KORUMASI', () {
    // Bu satır olmadan 1. denemedeki bant sorunu geri gelir.
    expect(ham.contains('setTheme(R.style.NormalTheme)'), isTrue,
        reason: 'tema geçişi elle uygulanmıyor');
  });

  test('⚠ SIRA: ÖNCE TEMA, SONRA KALDIRMA', () {
    // Ters sırada pencere bir kare boyunca eski temada kalır.
    final iTema = ham.indexOf('setTheme(R.style.NormalTheme)');
    final iKaldir = ham.indexOf('yuzey.remove()');
    expect(iTema, greaterThan(-1));
    expect(iKaldir, greaterThan(iTema),
        reason: 'kaldırma temadan önce çağrılıyor');
  });

  test('splash süreleri ve tutma koşulu KORUNDU', () {
    // Bu tur YALNIZ çıkış anını değiştirir.
    expect(ham.contains('SPLASH_MIN_MS = 2000L'), isTrue);
    expect(ham.contains('SPLASH_MAX_MS = 9000L'), isTrue);
    expect(ham.contains('setKeepOnScreenCondition'), isTrue);
  });

  test('⚠ FLUTTER SPLASH ÖLÇÜSÜNE DOKUNULMADI', () {
    // Elenen ikinci aday (native ikon kutusu ile `SplashView`in
    // 240 dp'si arasındaki uyumsuzluk) hâlâ elenmiş durumda.
    final s = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(s.contains('const double _kMarkaKutusu = 240;'), isTrue);
  });
}
