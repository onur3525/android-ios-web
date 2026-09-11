// ⚠ CUPERTINO İÇE AKTARMASI ZORUNLUDUR — DERLEME KIRILIR.
//
// Flutter 3.47 ile `CupertinoPageTransitionsBuilder` Material
// kitaplığından Cupertino kitaplığına TAŞINDI. Yalnız `material.dart`
// içe aktarıldığında derleyici sınıfı bulamaz:
//
//   lib/core/theme.dart:42:33
//   Error: Method not found: 'CupertinoPageTransitionsBuilder'.
//
// ⚠ BU HATA PLATFORMA ÖZEL DEĞİLDİR: web, Android ve iOS
// derlemelerinin ÜÇÜNÜ birden kırar. Web teşhis koşusunda ortaya
// çıktı, ama Android release'i de aynı satırda kırılıyordu.
//
// ⚠ Bu satır kaldırılmamalıdır. Kullanım yeri aşağıda
// `pageTransitionsTheme` içindedir ve o satır DEĞİŞMEDİ.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'klavye.dart';

/// HizmetCep tasarım dili — HTML prototipiyle birebir.
/// YALNIZ görsel değerler içerir; iş kuralı sabitleri lib/domain/config.dart'tadır.
/// ── ⚠ SİSTEM ÇUBUKLARI — TEK KAYNAK ──
///
/// KULLANICI İSTEĞİ (9 Eyl): "Android ikonları gri/koyu ve belirgin
/// olmalı; zemin beyaz olacağı için kaybolmamalı."
///
/// ⚠ ÖNCEDEN HİÇ AYARLANMAMIŞTI: ne `SystemChrome` çağrısı ne de
/// temada `windowLightStatusBar` vardı; çubuklar cihaz varsayılanına
/// bırakılmıştı ve beyaz ikonlar beyaz zeminde kayboluyordu.
///
/// ⚠ İKİ YERDE UYGULANIR, TEK YERDE TANIMLIDIR: `main()` uygulama
/// açılışında bunu kurar, `AppBarTheme` de aynı değeri taşır —
/// çünkü `AppBar` kendi `systemOverlayStyle`ı ile açılıştaki ayarı
/// EZER. Uygulamada iki `AppBar` var (`route_guard`, `legal_screen`);
/// buraya bağlanmasaydı o iki ekranda ikonlar yine kaybolabilirdi.
///
/// ⚠ UYGULAMANIN KOYU TEMASI YOK: tüm ekranların zemini beyaz, bu
/// yüzden ikon parlaklığı cihazın açık/koyu temasına göre DEĞİŞMEZ.
const SystemUiOverlayStyle kSistemCubuklari = SystemUiOverlayStyle(
  // ⚠ SAYDAM DEĞİL BEYAZ (kullanıcı bulgusu, 10 Eyl): saydamlık
  // ancak uygulama sistem çubuklarının ALTINA çizdiğinde işe yarar;
  // bu pencere öyle çizmiyor ve saydamın arkasında kalan şey SİYAH
  // oluyordu. Native taraftaki `MainActivity` ile AYNI değer.
  statusBarColor: Colors.white,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Color(0xFFECEEF2),
);

class HC {
  // Renkler (hizmetcep.html ile aynı)
  static const blue = Color(0xFF1D6BE3);
  static const dark = Color(0xFF16233D);
  static const grey = Color(0xFF5B6472);
  static const lightGrey = Color(0xFF98A2B3);
  static const red = Color(0xFFE5452C);
  static const green = Color(0xFF16A34A);
  static const orange = Color(0xFFF5820C);
  static const amber = Color(0xFFF5A319);
  static const border = Color(0xFFECEEF1);
  static const bg = Color(0xFFFFFFFF);
  static const softBlue = Color(0xFFE7EFFD);


  static ThemeData theme() => ThemeData(
        // ⚠ VARSAYILAN ANDROID GEÇİŞİ (~300 ms zoom) AĞIR HİSSETTİRİR.
        // Android'de kısa ve keskin `HizliGecis` kullanılır — bu satır
        // DEĞİŞMEDİ ve değişmeyecek.
        //
        // ⚠ iOS'TA HizliGecis KULLANILMAZ — SERT BLOKERDİ.
        //
        // `HizliGecis` iOS'a atandığında `CupertinoPageTransitionsBuilder`
        // EZİLİYOR ve onunla birlikte gelen KENARDAN GERİ KAYDIRMA
        // (swipe-back) jesti ÇALIŞMIYORDU. iPhone kullanıcısının ilk
        // refleksi budur; geri oku her ekranda olduğu için kilitlenme
        // olmaz ama uygulama iOS gibi davranmaz.
        //
        // ⚠ Bu bir animasyon TERCİHİ değil, PLATFORM DAVRANIŞIDIR.
        // Flutter geçiş oluşturucuyu platforma göre seçer: Android
        // cihazda YALNIZ `TargetPlatform.android` anahtarı okunur,
        // iOS anahtarının değeri Android davranışını ETKİLEMEZ.
        // Kilit: test/klavye_standardi_test.dart
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: HizliGecis(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue),
        // Poppins artık YEREL asset'tir (pubspec `fonts:` bölümü).
        fontFamily: 'Poppins',
        textTheme: Typography.blackMountainView
            .apply(bodyColor: grey, displayColor: dark, fontFamily: 'Poppins'),
        appBarTheme: const AppBarTheme(
            backgroundColor: bg,
            foregroundColor: dark,
            elevation: 0,
            // ⚠ AppBar açılıştaki ayarı ezer — aynı değer buraya da.
            systemOverlayStyle: kSistemCubuklari),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: blue, width: 1.4)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: red)),
          errorStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: red),
          // ── ⚠ YER TUTUCU RENGİ — TEMADA TANIMLI DEĞİLDİ ──
          //
          // `hintStyle` verilmediğinde Flutter kendi varsayılanını
          // kullanır ve o renk KOYUDUR: yer tutucu, kullanıcının
          // yazdığı değerden ayırt edilemiyordu. Kart formunda
          // "Ad Soyad", "0000 0000 0000 0000", "AA/YY" ve "123"
          // metinleri DOLDURULMUŞ gibi görünüyordu.
          //
          // ⚠ RENK UYDURULMADI: uygulamanın kendi bileşenleri
          // (`RefTextField`, `RefFormField`, kayıt ekranı, arama
          // kutuları) yer tutucuda zaten #98A2B3 kullanıyor. Tema bu
          // değere hizalandı; kendi `hintStyle`'ını veren bileşenler
          // temayı ezmeye devam eder, yani onlar etkilenmez.
          //
          // ⚠ AĞIRLIK w500: varsayılan ağırlık "yazılmış metin"
          // hissini artırıyordu.
          hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: lightGrey),
        ),
      );
}
