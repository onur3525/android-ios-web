// ⚠ KOŞULLU EXPORT: derleyici platforma göre BİRİNİ alır.
//   • `dart.library.io` varsa (Android, iOS) → `_io` uygulaması
//   • yoksa (Web)                            → `_web` uygulaması
//
// Çağıran dosyalar YALNIZ bu dosyayı import eder; `dart:io` adı
// hiçbir ekranda geçmez. Web derlemesini kıran şey buydu: `dart:io`
// içe aktaran bir dosya Flutter Web'de DERLENMEZ — çalışma anı hatası
// değil, derleme hatası. Tek dosya bile kalsa web hiç derlenmez.

/// ═══════════════════════════════════════════════════════════════
/// YEREL DOSYA / GÖRSEL KÖPRÜSÜ — ORTAK SÖZLEŞME
///
/// Bu dosya yalnız SÖZLEŞMEYİ belgeler; gövdeler `_io` ve `_web`
/// dosyalarındadır.
///
/// ## SAĞLANAN ÜÇ İŞLEV
///
///   `yerelGorsel(yol, ...)`  — cihazdaki/seçilen dosyayı çizer
///   `yerelBaytlar(yol)`      — dosyanın baytlarını okur (yükleme)
///   `yerelVarMi(yol)`        — dosya hâlâ duruyor mu
///
/// ## ⚠ MOBİL DAVRANIŞI DEĞİŞMEZ
///
/// `_io` uygulaması bugünkü kodun BİREBİR aynısıdır:
/// `Image.file(File(yol))`, `File(yol).readAsBytes()`,
/// `File(yol).existsSync()`. Android ve iOS için değişen tek şey,
/// çağrının bir fonksiyon üzerinden geçmesidir.
///
/// ## ⚠ WEB'DE YOL BİR BLOB ADRESİDİR
///
/// `image_picker` web'de `XFile.path` olarak `blob:https://...`
/// döndürür. Tarayıcıda dosya sistemi YOKTUR; bu adres yalnız o
/// sekme yaşadığı sürece geçerlidir. Bu yüzden web tarafında:
///   • çizim `Image.network` ile yapılır (blob adresi ağ adresi gibi
///     çözülür),
///   • baytlar `XFile(yol).readAsBytes()` ile okunur,
///   • "dosya var mı" sorusunun karşılığı yoktur — adres boş değilse
///     var sayılır.
///
/// ⚠ SUNUCUDAN GELEN ADRESLER BURAYA GELMEZ: bu köprü yalnız YEREL
/// (henüz yüklenmemiş) dosyalar içindir. Yüklenmiş görseller
/// `storageRef` ile sunucudan çözülür.
/// ═══════════════════════════════════════════════════════════════
///
/// Aşağıdaki imzalar, iki uygulamanın da uymak zorunda olduğu
/// sözleşmedir (belge amaçlıdır, burada tanımlı değildir):
///
/// ```dart
/// Widget yerelGorsel(
///   String yol, {
///   double? width,
///   double? height,
///   BoxFit? fit,
///   WidgetBuilder? hataYedegi,
/// });
///
/// Future<Uint8List> yerelBaytlar(String yol);
///
/// bool yerelVarMi(String yol);
///
/// Future<int> yerelBoyut(String yol);
/// ```
library;

export 'yerel_gorsel_io.dart' if (dart.library.html) 'yerel_gorsel_web.dart';
