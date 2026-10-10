import 'package:http/http.dart' as http;

// ⚠ WEB — TARAYICI.

/// Tarayıcının kendi HTTP yığını.
///
/// ⚠ SABİTLEME YOK VE OLAMAZ: tarayıcı TLS el sıkışmasını kendi
/// yapar; sunucu sertifikasına erişilemediği için pin
/// karşılaştırılamaz. Buraya sahte bir kontrol koymak, olmayan bir
/// korumayı varmış gibi gösterirdi.
///
/// ⚠ GÜVENLİK SINIRI: web istemcisi MITM'e karşı yalnız tarayıcının
/// kök sertifika deposu kadar korunur.
http.Client sabitlemeliIstemci() => http.Client();

/// ⚠ WEB'DE DENETLENECEK BİR ŞEY YOK: sabitleme yapılamadığı için
/// pin zorunluluğu da anlamsızdır. Boş gövde BİLİNÇLİDİR — burada
/// hata fırlatmak, web sürümünü hiç açılmaz hâle getirirdi.
void pinDenetimi({required bool gercekApi}) {}

/// ⚠ WEB: tarayıcı WebSocket'i kendi TLS modeliyle kurar; sabitleme
/// yapılamaz ve yapılıyormuş gibi gösterilmez. [f] olduğu gibi çalışır.
T sabitliBolgede<T>(T Function() f) => f();
