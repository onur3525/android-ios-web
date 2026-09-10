// SPLASH ÇIKIŞI — GERİ ALINDI (KİLİT)
//
// ⚠ NE OLDU: kullanıcı "splash kapanmasına yakın logoda anlık bir
// küçülme" bildirdi. Sebep olarak `MainActivity`de
// `setOnExitAnimationListener`ın hiç tanımlı olmaması gösterildi ve
// listener eklendi (`remove()` ile animasyonsuz kaldırma).
//
// ⚠ SONUÇ KÖTÜ OLDU: o derlemede uygulamanın ALTINDA VE ÜSTÜNDE siyah
// bantlar çıktı; ekrana tam sığmayı bıraktı. Android tarafında o
// turda DEĞİŞEN TEK DOSYA `MainActivity.kt` idi ve tek değişiklik bu
// listener'dı (tema, manifest, gradle dosyalarına dokunulmadı —
// MD5'lerle doğrulandı).
//
// ⚠ DEĞİŞİKLİK GERİ ALINDI: dosya referans sürümüyle BİREBİR aynı.
// Logodaki anlık küçülme geri geldi; bozuk pencereye tercih edildi.
//
// ⚠ KÖK NEDEN KESİN İLAN EDİLMEDİ: siyah bantların listener yüzünden
// çıktığı ÖLÇÜLMEDİ, yalnız "tek değişen dosya" kanıtına dayanıyor.
// En güçlü aday, `postSplashScreenTheme` geçişinin çıkış devralınınca
// uygulanmaması ve pencerenin `Theme.SplashScreen`de kalması —
// doğrulanması cihaz gerektirir.
//
// Bu test, düzeltme denenmeden dosyanın sessizce değişmemesini
// sağlar.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _yol = 'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt';

void main() {
  final ham = File(_yol).readAsStringSync();

  test('⚠ ÇIKIŞ ANİMASYONU DEVRALINMIYOR', () {
    // Yeniden denenecekse, aynı turda `postSplashScreenTheme`
    // geçişinin de elle uygulanması gerekir; yoksa siyah bantlar
    // geri gelir.
    expect(ham.contains('setOnExitAnimationListener'), isFalse,
        reason: 'çıkış devralınmış — siyah bant sorunu geri gelebilir');
  });

  test('splash süreleri ve tutma koşulu KORUNDU', () {
    expect(ham.contains('SPLASH_MIN_MS = 2000L'), isTrue);
    expect(ham.contains('SPLASH_MAX_MS = 9000L'), isTrue);
    expect(ham.contains('setKeepOnScreenCondition'), isTrue);
  });

  test('⚠ FLUTTER SPLASH ÖLÇÜSÜNE HİÇ DOKUNULMADI', () {
    final s = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(s.contains('const double _kMarkaKutusu = 240;'), isTrue);
  });
}
