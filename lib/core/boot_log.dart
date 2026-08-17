import 'package:flutter/foundation.dart';

/// AÇILIŞ TELEMETRİSİ
///
/// Gerçek cihazda açılış zincirini izlemek için TEK etiket altında
/// zaman damgalı olay kaydı. `logcat | grep HC_BOOT` ile filtrelenir.
///
/// Biçim (tek satır, sabit):
///     HC_BOOT +0124ms MAIN_ENTRY
///     HC_BOOT +0357ms SEED_DEMO_END=331ms
///
/// ⚠ GİZLİLİK: kullanıcı verisi, token, telefon, e-posta veya sır
/// KAYDEDİLMEZ — yalnız olay adı, süre ve teknik sonuç.
///
/// ⚠ Yalnız debug derlemede yazar; release'de tamamen sessizdir ve
/// hiçbir iş mantığına dokunmaz.
///
/// ── TEK BAŞLANGIÇ (EPOCH) ──
///
/// ⚠ ÖNCEKİ HÂLDE KRONOMETRE `SplashScreen.initState` İÇİNDE
/// BAŞLIYORDU. Bu yüzden `main()` girişi, `buildPorts`, `_seedDemo`
/// ve `runApp` — yani açılışın EN ŞÜPHELİ penceresi — ölçümün
/// TAMAMEN DIŞINDA kalıyordu.
///
/// Artık kronometre İLK olay kaydında başlar (`MAIN_ENTRY`) ve bir
/// daha SIFIRLANMAZ. Tüm Dart olayları aynı sıfıra göre `+X ms`
/// verir.
///
/// ── NATIVE İLE KORELASYON ──
///
/// Native taraf (`MainActivity`) kendi kronometresini
/// `SystemClock.uptimeMillis()` ile `onCreate` anında başlatır; Dart
/// kronometresi `main()` girişinde başlar. İKİ FARKLI SIFIR NOKTASI
/// VARDIR.
///
/// Korelasyon şu çiftle kurulur — ikisi AYNI ANI gösterir:
///     NATIVE_BOOT_READY_RECEIVED  (native saat)
///     NATIVE_BOOT_READY_SENT      (Dart saat)
/// Aradaki fark = Dart sıfırının native sıfırına göre kayması.
/// Yani:  MAIN_ENTRY(native ölçeğinde) ≈ farkın kendisi.
class BootLog {
  const BootLog._();

  static const _etiket = 'HC_BOOT';
  static Stopwatch? _kronometre;

  /// Açılış ölçümünü başlatır (cold start başına BİR kez).
  ///
  /// ⚠ TEKRAR ÇAĞRILIRSA SIFIRLAMAZ: `main()` ve `SplashScreen`
  /// ikisi de çağırabilir; sıfır noktası ilk çağrıda sabitlenir.
  static void basla() {
    _kronometre ??= Stopwatch()..start();
  }

  /// Şu anki `+X ms` değeri (ölçüm başlamadıysa 0).
  static int get gecen => _kronometre?.elapsedMilliseconds ?? 0;

  /// Zaman damgalı olay — tek satır.
  static void olay(String ad, [String? deger]) {
    if (!kDebugMode) {
      return;
    }
    // İlk olay kronometreyi de başlatır: hiçbir olay sıfırsız kalmaz.
    basla();
    final ms = gecen.toString().padLeft(4, '0');
    final satir = deger == null ? ad : '$ad=$deger';
    debugPrint('$_etiket +${ms}ms $satir');
  }

  /// Bir işin SÜRESİNİ ölçer ve `<ad>_START` / `<ad>_END=<süre>ms`
  /// olarak kaydeder.
  ///
  /// ⚠ SENKRON: işin sırasını, dönüş değerini ve istisnasını
  /// DEĞİŞTİRMEZ. Hata atarsa `_END` yine yazılır (`finally`).
  static T olc<T>(String ad, T Function() is_) {
    if (!kDebugMode) {
      return is_();
    }
    olay('${ad}_START');
    final k = Stopwatch()..start();
    try {
      return is_();
    } finally {
      olay('${ad}_END', '${k.elapsedMilliseconds}ms');
    }
  }

  /// [olc]'nin asenkron karşılığı — `await` sırası DEĞİŞMEZ.
  static Future<T> olcAsync<T>(String ad, Future<T> Function() is_) async {
    if (!kDebugMode) {
      return is_();
    }
    olay('${ad}_START');
    final k = Stopwatch()..start();
    try {
      return await is_();
    } finally {
      olay('${ad}_END', '${k.elapsedMilliseconds}ms');
    }
  }
}
