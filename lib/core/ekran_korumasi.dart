// EKRAN KORUMASI — FLAG_SECURE
//
// ⚠ NE ENGELLER: ekran görüntüsü, ekran kaydı ve son uygulamalar
// listesindeki ÖNİZLEME. Sonuncusu en sinsi olanıdır: kullanıcı
// cüzdandan çıkıp uygulamayı arka plana aldığında bakiye ve kart
// bilgisi görev listesinde asılı kalır; telefonu eline alan herkes
// görür.
//
// ⚠ NEREDE AÇILIR: kart numarası, bakiye ve iletişim bilgisi
// gösteren yüzeyler. Her ekranda açmak yanlış olur — kullanıcı
// ilanının ekran görüntüsünü alıp paylaşabilmeli.
//
// ⚠ iOS'ta FLAG_SECURE YOKTUR — ORADA BAŞKA BİR ŞEY YAPILIR.
//
// iOS'ta ekran görüntüsü ENGELLENEMEZ; işletim sistemi böyle bir
// anahtar sunmaz. Yapılabilen tek şey ÖNİZLEME KARARTMASIDIR:
// uygulama arka plana alınırken pencerenin üzerine örtü konur, öne
// gelince kaldırılır. Böylece görev değiştiricide bakiye ve kart
// bilgisi asılı kalmaz.
//
// ⚠ İKİ PLATFORM AYNI KANALI KULLANIR (`hizmetcep/ekran_korumasi`)
// ve aynı `ac`/`kapat` sözleşmesini konuşur. Fark yalnız yerel
// tarafın o çağrıya ne yaptığındadır:
//   • Android → `FLAG_SECURE` (MainActivity.kt)
//   • iOS     → arka plan örtüsü (AppDelegate.swift)
//
// ⚠ ANDROID DALI DEĞİŞMEDİ. Aşağıdaki koşula iOS EKLENDİ; Android'in
// davranışı, sayaç mantığı ve hata yutma kuralı aynen duruyor.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ⚠ `State` ve `StatefulWidget` buradan gelir; `foundation` yetmez.
import 'package:flutter/widgets.dart';

/// Hassas ekranlarda ekran korumasını yöneten köprü.
abstract final class EkranKorumasi {
  static const MethodChannel _kanal =
      MethodChannel('hizmetcep/ekran_korumasi');

  /// Kaç ekran korumayı istiyor.
  ///
  /// ⚠ SAYAÇ GEREKLİ: cüzdandan kart formuna geçildiğinde iki ekran
  /// üst üste biner. İkincisi kapanırken koruma kapatılırsa alttaki
  /// cüzdan korumasız kalırdı.
  static int _isteyen = 0;

  static bool get _desteklenir =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Korumayı açar. Her `ac` çağrısının bir `kapat` karşılığı olmalı.
  static Future<void> ac() async {
    if (!_desteklenir) {
      return;
    }
    _isteyen++;
    if (_isteyen == 1) {
      // ⚠ Hata YUTULUR: koruma açılamazsa ekran yine de çalışmalı.
      // Kullanıcıyı ekrandan mahrum bırakmak korumadan daha kötü.
      try {
        await _kanal.invokeMethod<void>('ac');
      } on PlatformException {
        // yerel taraf yanıt vermedi
      } on MissingPluginException {
        // köprü yok (eski sürüm / test ortamı)
      }
    }
  }

  /// Korumayı bırakır. Son isteyen çıkınca gerçekten kapanır.
  static Future<void> kapat() async {
    if (!_desteklenir) {
      return;
    }
    if (_isteyen > 0) {
      _isteyen--;
    }
    if (_isteyen == 0) {
      try {
        await _kanal.invokeMethod<void>('kapat');
      } on PlatformException {
        // yerel taraf yanıt vermedi
      } on MissingPluginException {
        // köprü yok
      }
    }
  }

  /// ⚠ YALNIZ TEST İÇİN: sayaç sıfırlanır.
  @visibleForTesting
  static void sayaciSifirla() => _isteyen = 0;

  @visibleForTesting
  static int get isteyenSayisi => _isteyen;
}

/// Ekran açıkken korumayı tutan karışım (mixin).
///
/// ⚠ `initState`/`dispose` çiftini elle yazmak yerine bu kullanılır;
/// unutulan bir `kapat` çağrısı korumayı sonsuza kadar açık bırakır.
mixin EkranKorumaliState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    EkranKorumasi.ac();
  }

  @override
  void dispose() {
    EkranKorumasi.kapat();
    super.dispose();
  }
}
