// EKRAN YÖNLENDİRMESİ — TELEFON DİKEY, TABLET SERBEST
//
// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): telefonda yönlendirme DİKEY
// kilitlenir; tablette yatay kullanıma izin verilir.
//
// ── ⚠ NEDEN MANIFEST DEĞİL, ÇALIŞMA ZAMANI ──
//
// `AndroidManifest.xml` içindeki `android:screenOrientation` STATİKTİR:
// tek bir değer yazılır ve cihaz ayrımı yapılamaz. `portrait` yazmak
// tableti de kilitler, boş bırakmak telefonu serbest bırakır. İkisi de
// karara aykırıdır. Bu yüzden manifest'e yönlendirme yazılmaz ve kural
// burada, cihaz ölçüsüne bakarak uygulanır.
//
// ⚠ MANIFEST'E `screenOrientation` EKLENMEMELİDİR: eklenirse sistem
// kısıtı buradaki karardan önce gelir ve tablet de kilitlenir. Kilit:
// `test/yonlendirme_test.dart`.
//
// ── ⚠ NEDEN `MediaQuery` GENİŞLİĞİ DEĞİL, EN KISA KENAR ──
//
// `ui/olcu.dart` içindeki `ekranSinifi(context)` YERLEŞİM içindir ve
// o anki GENİŞLİĞE bakar — doğru olan da budur, çünkü kullanıcının
// gördüğü şey o anki genişliktir.
//
// Ama yönlendirme kararı YERLEŞİM değil CİHAZ SINIFI sorusudur ve
// genişlikle verilemez: uygulama telefonda yatay açılırsa genişlik
// 800'ü aşar, kural onu tablet sanır ve telefonu HİÇ kilitlemez.
// Kilitlemediği için de ekran dönük kalır — hata kendi kendini
// besler.
//
// En kısa kenar YÖNDEN BAĞIMSIZDIR: aynı cihaz dikeyde de yatayda da
// aynı değeri verir. Bu yüzden cihaz sınıfı ondan okunur.
//
// ⚠ EŞİK ÇOĞALTILMADI: sınır yine `Kirilma.tablet` (600). İkinci bir
// 600 yazılsaydı biri değişip öteki kalabilirdi.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../ui/olcu.dart';

/// Verilen en kısa kenar (dp) telefon sınıfına mı giriyor?
///
/// ⚠ Saf fonksiyon — testten doğrudan çağrılır.
bool telefonMu(double enKisaKenarDp) => enKisaKenarDp < Kirilma.tablet;

/// Telefonda izin verilen yönler.
///
/// ⚠ `portraitDown` YOK: telefonlar baş aşağı dikeyi zaten pratikte
/// kullanmaz ve listede bırakmak kilidi gevşetirdi.
const List<DeviceOrientation> kTelefonYonleri = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
];

/// Tablette izin verilen yönler.
///
/// ⚠ BOŞ LİSTE = SİSTEM VARSAYILANI (tüm yönler serbest). Dört yönü
/// tek tek saymak yerine kısıtı kaldırmak doğrudur: cihazın kendi
/// desteklemediği bir yönü listeye yazmak sessiz bir tutarsızlık
/// üretir.
const List<DeviceOrientation> kTabletYonleri = <DeviceOrientation>[];

/// Cihaz ölçüsüne göre yönlendirme kısıtını uygular.
///
/// ⚠ TEK ÇAĞRI YERİ `main()`. Ekranlar kendi yönlendirmesini
/// AYARLAMAZ; bir ekranın kısıtı değiştirmesi, geri dönüşte eski
/// hâli geri getirmeyi de gerektirir ve o adım unutulur.
///
/// ⚠ ÖLÇÜ HENÜZ HAZIR OLMAYABİLİR: motor açılışında görünüm
/// ölçüleri sıfır gelebilir. Sıfır değere göre karar vermek telefonu
/// tablet sayardı; bu yüzden ölçü geçersizse karar İLK KAREYE
/// ertelenir. Tek seferliktir, döngü kurmaz.
void yonlendirmeyiUygula() {
  // ⚠ WEB'DE ANLAMSIZ: tarayıcı penceresinin yönü uygulamaya ait
  // değildir ve çağrı sessizce yok sayılır.
  if (kIsWeb) {
    return;
  }

  final binding = WidgetsBinding.instance;
  final view = binding.platformDispatcher.implicitView;
  if (view == null) {
    return;
  }

  final oran = view.devicePixelRatio;
  final fiziksel = view.physicalSize;
  if (oran <= 0 || fiziksel.isEmpty) {
    // Ölçü hazır değil — ilk karede tekrar denenir.
    binding.addPostFrameCallback((_) => yonlendirmeyiUygula());
    return;
  }

  final enKisaKenar = fiziksel.shortestSide / oran;
  SystemChrome.setPreferredOrientations(
    telefonMu(enKisaKenar) ? kTelefonYonleri : kTabletYonleri,
  );
}
