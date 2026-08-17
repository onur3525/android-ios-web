// ANDROID BUILD TOOLCHAIN — SÖZLEŞME
//
// ⚠ Hedef kombinasyon (14 Ağu, ürün kararı):
//   Flutter 3.47.x · AGP 9.3.0 · Gradle 9.5.0 · Kotlin 2.4.10 · JDK 17
//
// ⚠ SÜRÜMLER BAĞIMSIZ DEĞİL. Birini yükseltip ötekini bırakmak
// derlemeyi kırar; bu test dördünü BİRLİKTE kilitler.
//
// ⚠ Bu test derlemeyi DOĞRULAMAZ — yalnız yapılandırmanın hedefte
// kaldığını söyler. Gerçek doğrulama Codemagic/GitHub Actions'ta
// `flutter build apk` ile yapılır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return f.readAsStringSync();
}

void main() {
  group('SÜRÜM KOMBİNASYONU', () {
    test('Gradle 9.5.0', () {
      final w = _oku('android/gradle/wrapper/gradle-wrapper.properties');
      expect(w.contains('gradle-9.5.0-all.zip'), isTrue);
      expect(w.contains('gradle-8.'), isFalse, reason: 'eski Gradle kalmış');
    });

    test('AGP 9.3.0', () {
      final s = _oku('android/settings.gradle');
      expect(s.contains('"com.android.application" version "9.3.0"'), isTrue);
      expect(s.contains('version "8.'), isFalse, reason: 'eski AGP kalmış');
    });

    test('Kotlin 2.4.10 AÇIKÇA bildirilir', () {
      // ⚠ AGP 9, KGP 2.2.10'a bağımlı ve daha düşüğü sessizce
      // yükseltir. Sürüm yazılmazsa hedef 2.2.10'da kalır.
      final s = _oku('android/settings.gradle');
      expect(s.contains('"org.jetbrains.kotlin.android" version "2.4.10"'),
          isTrue);
    });

    test('JDK 17 — Java ve Kotlin hedefi AYNI', () {
      final g = _oku('android/app/build.gradle');
      expect(g.contains('sourceCompatibility = JavaVersion.VERSION_17'), isTrue);
      expect(g.contains('targetCompatibility = JavaVersion.VERSION_17'), isTrue);
      expect(g.contains('JvmTarget.JVM_17'), isTrue);
    });
  });

  group('BUILT-IN KOTLIN GEÇİŞİ', () {
    test('KAPI ile EKLENTİ birlikte yaşar', () {
      // ⚠ GEÇİŞ MODU (14 Ağu): `share_plus` henüz built-in Kotlin'e
      // göç etmediği için kapı geçici olarak KAPALI. O durumda AGP
      // Kotlin kaynağını kendisi derlemez; `kotlin-android` ZORUNLU.
      //
      // ⚠ İKİSİ AYRI DÜŞEMEZ: kapı açıkken eklenti varsa derleme
      // "plugin is no longer required" ile düşer; kapı kapalıyken
      // eklenti yoksa MainActivity.kt derlenmez. Bu test o eşleşmeyi
      // korur.
      final p = _oku('android/gradle.properties');
      final g = _oku('android/app/build.gradle');
      final plugins = g.substring(
          g.indexOf('plugins {'), g.indexOf('}', g.indexOf('plugins {')));

      final kapiKapali = p.contains('android.builtInKotlin=false');
      final eklentiVar = plugins.contains('kotlin-android');
      expect(kapiKapali, eklentiVar,
          reason: kapiKapali
              ? 'kapı kapalı ama kotlin-android yok'
              : 'kapı açık ama kotlin-android duruyor');

      // Kapının kendisi bildirilmiş olmalı; varsayılana bırakılmaz.
      expect(p.contains('android.builtInKotlin='), isTrue);
      expect(plugins.contains('com.android.application'), isTrue);
      expect(plugins.contains('dev.flutter.flutter-gradle-plugin'), isTrue);
    });

    test('GEÇİCİ OLDUĞU koda yazılmış', () {
      // AGP 10'da bu kapı kalkacak; gerekçe ve son tarih kaynakta
      // dursun ki sonraki tur nedenini aramasın.
      final p = _oku('android/gradle.properties');
      expect(p.contains('share_plus'), isTrue);
      expect(p.contains('AGP 10'), isTrue);
    });

    test('kotlinOptions bloğu YOK — üst düzey kotlin{} kullanılır', () {
      // AGP 9 built-in Kotlin eski bloğu tanımaz:
      //   Unresolved reference 'kotlinOptions'
      final g = _oku('android/app/build.gradle');
      // ⚠ Yorumda geçen `kotlinOptions` metnini yakalamamak için
      // gerçek blok kalıbı aranır.
      expect(g.contains('android {\n    kotlinOptions'), isFalse,
          reason: 'eski blok geri gelmiş');
      expect(g.contains('    kotlinOptions {'), isFalse,
          reason: 'eski blok geri gelmiş');
      expect(g.contains('kotlin {'), isTrue);
      expect(g.contains('compilerOptions {'), isTrue);
    });
  });

  group('DOKUNULMAYANLAR', () {
    test('MainActivity.kt yerinde', () {
      // Kotlin kaynağımız tek dosya; built-in Kotlin ile derleniyor
      // ama DOSYA DEĞİŞMEDİ (açılış/splash kapsam dışı).
      expect(
          File('android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt')
              .existsSync(),
          isTrue);
    });

    test('TEK DSL — Groovy', () {
      // `.kts` dosyası eklenirse "Both build.gradle and
      // build.gradle.kts exist" uyarısı çıkar.
      expect(File('android/app/build.gradle.kts').existsSync(), isFalse);
      expect(File('android/settings.gradle.kts').existsSync(), isFalse);
    });

    test('compileSdk 36 korundu', () {
      expect(_oku('android/app/build.gradle').contains('compileSdk = 36'),
          isTrue);
    });

    test('release imza koruması korundu', () {
      final g = _oku('android/app/build.gradle');
      expect(g.contains('RELEASE İMZALAMA ANAHTARI BULUNAMADI'), isTrue);
      expect(g.contains('hasKeystore ? signingConfigs.release : null'), isTrue);
    });
  });
}
