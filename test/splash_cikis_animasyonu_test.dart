// SPLASH ÇIKIŞI · İKON KUTUSU · SİSTEM ÇUBUKLARI (KİLİT)
//
// ⚠ BU DOSYA İKİ AYRI ARIZAYI KİLİTLER. İkisi de aylarca "renk /
// tema" sanıldı ve her turda yanlış yere yazıldı.
//
// ── 1. LOGO KÜÇÜLMESİ ──
//
// Bulgu: "Splash kapanmasına yakın logoda anlık bir küçülme oluyor."
//
// İlk önlem doğruydu: `setOnExitAnimationListener` tanımsızken sistem
// kendi çıkış animasyonunu oynatıp ikonu küçültüyordu. Devralındı.
//
// ⚠ AMA KÜÇÜLME GEÇMEDİ ve o turda "tema geçişi çözdü" diye
// kaydedildi. O KAYIT YANLIŞTI: manifest'teki
// `io.flutter.embedding.android.NormalTheme` meta-data'sı yüzünden
// `FlutterActivity` temayı pencere oluşmadan önce zaten değiştiriyor;
// `setTheme(R.style.NormalTheme)` etkisiz bir satır.
//
// GERÇEK SEBEP (12 Eyl): `windowSplashScreenIconBackgroundColor`
// SAYDAM verilmişti. Saydam olduğunda Android "arka planı yok" dalını
// seçer ve ikon kutusu 288dp olur; `SplashView` ise 240dp çiziyordu.
// Native yüzey bırakılıp altındaki Flutter yüzeyi göründüğü anda
// marka bloğu %16,7 küçülüyordu.
//
// DÜZELTME: öznitelik splash zemininin rengine ayarlandı → kutu
// 240dp, iki taraf aynı ölçü. Renk zeminle aynı olduğu için görünür
// daire oluşmaz.
//
// ── 2. SİYAH BANTLAR ──
//
// Bulgu: "Ekranın altı ve üstü siyah, tam ekran değil."
//
// Renk atamak üç kez denendi (saydam, sonra beyaz, Dart tarafında
// `SystemChrome`) ve hiçbiri tutmadı. Sebep renk değildi:
// `NormalTheme` atası `@android:style/Theme.Light.NoTitleBar` olduğu
// için pencerede `windowDrawsSystemBarBackgrounds` bayrağı kapalıydı.
// O bayrak yokken `setStatusBarColor`/`setNavigationBarColor`
// ETKİSİZDİR ve sistem çubukları opak siyah çizilir.
//
// DÜZELTME: bayrak + renkler TEMAYA yazıldı; tema pencere
// oluşturulurken okunur, çalışma zamanı atamaları da artık etkilidir.
//
// ⚠ ÖLÇÜM SINIRI: cihazda ölçüm bu ortamda YAPILAMADI. Zincirin her
// halkası koddan okunabilir, ama "APK'da düzeldi" doğrulaması
// kullanıcının koşusuna bağlıdır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _yol = 'android/app/src/main/kotlin/com/hizmetcep/app/MainActivity.kt';

void main() {
  final ham = File(_yol).readAsStringSync();

  test('çıkış devralınır ve animasyonsuz kaldırılır', () {
    expect(ham.contains('setOnExitAnimationListener'), isTrue);
    expect(ham.contains('yuzey.remove()'), isTrue);
  });

  test('tema elle uygulanır', () {
    expect(ham.contains('setTheme(R.style.NormalTheme)'), isTrue,
        reason: 'tema geçişi elle uygulanmıyor');
  });

  test('⚠ SİYAH BANT KORUMASI — PENCERE RENKLERİ ELLE', () {
    // 2. DENEME BULGUSU (10 Eyl): tema geçişi logonun küçülmesini
    // çözdü ama bantları ÇÖZMEDİ. Sebep: `setTheme` PENCERE
    // ÖZNİTELİKLERİNİ geri almaz — pencere zaten oluşturulmuştur ve
    // çubuk renkleri `Theme.SplashScreen`den çözülmüş hâlde kalır.
    //
    // İki sorun FARKLI şeylerden geliyordu; ikisi ayrı ayrı
    // çözülmek zorundaydı.
    // ⚠ SAYDAM DEĞİL BEYAZ (10 Eyl): saydam atanan ilk deneme
    // bantları çözmedi. Saydamlık ancak pencere sistem çubuklarının
    // ALTINA çizdiğinde işe yarar; bu pencere öyle çizmiyor ve
    // saydamın arkasında kalan şey siyah oluyordu.
    expect(ham.contains('window.statusBarColor = Color.WHITE'), isTrue);
    expect(ham.contains('window.navigationBarColor = Color.WHITE'), isTrue);
    expect(ham.contains('Color.TRANSPARENT'), isFalse,
        reason: 'saydam geri gelmiş — bantlar yine siyah olur');
  });

  test('⚠ İKON PARLAKLIĞI DA AYARLANIR', () {
    // Zemin beyaz; ikonlar koyu olmazsa beyaz üstünde beyaz kalır.
    expect(ham.contains('isAppearanceLightStatusBars = true'), isTrue);
    expect(ham.contains('isAppearanceLightNavigationBars = true'), isTrue);
  });

  test('⚠ RENKLER DART SABİTİYLE AYNI', () {
    // `core/theme.dart` içindeki `kSistemCubuklari`: saydam durum
    // çubuğu + beyaz gezinme çubuğu + koyu ikon. İki taraf ayrışırsa
    // açılışta renk zıplar.
    final dart = File('lib/core/theme.dart').readAsStringSync();
    expect(dart.contains('statusBarColor: Colors.white'), isTrue);
    expect(dart.contains('Colors.transparent'), isFalse,
        reason: 'Dart tarafı native ile ayrışmış');
    expect(dart.contains('systemNavigationBarColor: Colors.white'), isTrue);
    expect(dart.contains('statusBarIconBrightness: Brightness.dark'), isTrue);
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
    // 240 dp KORUNUR; artık Android tarafı da 240 dp kutuyu seçiyor.
    final s = File('lib/screens/splash_screen.dart').readAsStringSync();
    expect(s.contains('const double _kMarkaKutusu = 240;'), isTrue);
  });

  group('⚠ İKON KUTUSU 240dp — DÖRT VARYANTTA', () {
    const res = 'android/app/src/main/res';
    const varyantlar = [
      'values',
      'values-night',
      'values-v31',
      'values-night-v31',
    ];

    test('ikon arka planı SAYDAM DEĞİL (288dp dalına düşülmez)', () {
      for (final d in varyantlar) {
        final s = File('$res/$d/styles.xml').readAsStringSync();
        expect(
          s.contains('windowSplashScreenIconBackgroundColor">'
              '@color/launch_background'),
          isTrue,
          reason: '$d: saydam ikon arka planı 288dp kutuya geçirir ve '
              'SplashView ile 240dp uyuşmazlığı geri gelir',
        );
        expect(
          s.contains('windowSplashScreenIconBackgroundColor">'
              '@android:color/transparent'),
          isFalse,
          reason: '$d: saydam değer geri gelmiş',
        );
      }
    });

    test('ikon arka planı splash zemini ile AYNI resource', () {
      // Farklı renk verilirse ikonun arkasında görünür bir daire oluşur.
      for (final d in varyantlar) {
        final s = File('$res/$d/styles.xml').readAsStringSync();
        expect(s.contains('windowSplashScreenBackground">'
            '@color/launch_background'), isTrue, reason: d);
      }
    });
  });

  group('⚠ SİYAH BANT — RENK DEĞİL, ÖNCE BAYRAK', () {
    const res = 'android/app/src/main/res';
    const varyantlar = [
      'values',
      'values-night',
      'values-v31',
      'values-night-v31',
    ];

    test('NormalTheme sistem çubuğu zeminlerini ÇİZER', () {
      // Bu bayrak olmadan aşağıdaki renkler de, MainActivity ve
      // SystemChrome atamaları da etkisiz kalır.
      for (final d in varyantlar) {
        final s = File('$res/$d/styles.xml').readAsStringSync();
        expect(
          s.contains('android:windowDrawsSystemBarBackgrounds">true'),
          isTrue,
          reason: '$d: bayrak kapalıyken çubuklar opak siyah çizilir',
        );
      }
    });

    test('çubuk renkleri temada tanımlı ve beyaz', () {
      for (final d in varyantlar) {
        final s = File('$res/$d/styles.xml').readAsStringSync();
        expect(s.contains('android:statusBarColor">@android:color/white'),
            isTrue, reason: d);
        expect(s.contains('android:navigationBarColor">@android:color/white'),
            isTrue, reason: d);
      }
    });

    test('üç taraf AYNI rengi söyler', () {
      // Tema · MainActivity · core/theme.dart ayrışırsa açılışta renk
      // zıplar.
      final tema = File('$res/values/styles.xml').readAsStringSync();
      final native = File(_yol).readAsStringSync();
      final dart = File('lib/core/theme.dart').readAsStringSync();
      expect(tema.contains('@android:color/white'), isTrue);
      expect(native.contains('window.statusBarColor = Color.WHITE'), isTrue);
      expect(dart.contains('statusBarColor: Colors.white'), isTrue);
    });
  });
}
