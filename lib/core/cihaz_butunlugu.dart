// CİHAZ BÜTÜNLÜĞÜ
//
// ⚠ BU BİR GÜVENLİK DUVARI DEĞİLDİR.
//
// Root'lu bir cihazda bu denetimlerin HEPSİ atlatılabilir; kararlı bir
// saldırganı durdurmaz. Amaç farklıdır:
//   • riskli ortamı fark edip kullanıcıyı UYARMAK
//   • gerekirse hassas işlemi (para yükleme) kısıtlamak
//   • yeniden paketlenmiş (repackaged) kopyayı tespit etmek
//
// ⚠ TEK BAŞINA ENGELLEME YAPILMAZ. Yanlış pozitif dürüst kullanıcıyı
// uygulamadan tamamen dışlar; geliştirici telefonu, özel ROM veya
// kurumsal cihaz root'lu görünebilir.
//
// ⚠ SUNUCU BU BİLGİYE GÜVENEMEZ: değer istemciden gelir ve
// değiştirilebilir. Sunucu kendi kurallarını ayrıca uygulamalıdır.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cihazdan okunan bütünlük göstergeleri.
@immutable
class CihazDurumu {
  const CihazDurumu({
    this.root = false,
    this.hataAyiklanabilir = false,
    this.hataAyiklayiciBagli = false,
    this.oykunucu = false,
    this.imzaOzeti,
  });

  /// Root izleri bulundu (su ikilisi, Magisk, test-keys).
  final bool root;

  /// Paket hata ayıklanabilir işaretiyle derlenmiş.
  ///
  /// ⚠ Sürüm paketinde FALSE olmalı; TRUE ise paket ya geliştirme
  /// derlemesidir ya da yeniden imzalanmıştır.
  final bool hataAyiklanabilir;

  /// Şu anda bir hata ayıklayıcı bağlı.
  final bool hataAyiklayiciBagli;

  /// Öykünücü belirtileri.
  final bool oykunucu;

  /// Paketin imza özeti (SHA-256, base64).
  final String? imzaOzeti;

  /// Para işlemleri için riskli sayılan ortam.
  ///
  /// ⚠ Öykünücü BURAYA GİRMEZ: test ve geliştirme öykünücüde yapılır,
  /// riskli saymak günlük çalışmayı bozar.
  bool get paraIcinRiskli =>
      root || hataAyiklayiciBagli || !imzaBekleneneUyuyor;

  /// Beklenen imza verilmişse tutuyor mu?
  ///
  /// ⚠ Beklenen özet VERİLMEMİŞSE denetim yapılmaz ve `true` döner.
  /// Bilerek böyle: yanlış özetle çıkılan sürüm uygulamayı tamamen
  /// kullanılamaz hâle getirir.
  bool get imzaBekleneneUyuyor {
    if (CihazButunlugu.beklenenImza.isEmpty) {
      return true;
    }
    if (imzaOzeti == null) {
      // ⚠ Denetim açıkken belirsizlik RİSKLİ sayılır.
      return false;
    }
    return imzaOzeti == CihazButunlugu.beklenenImza;
  }
}

abstract final class CihazButunlugu {
  static const MethodChannel _kanal =
      MethodChannel('hizmetcep/cihaz_butunlugu');

  /// Beklenen imza özeti — derleme zamanında verilir.
  ///
  ///     --dart-define=APK_SIGNATURE_SHA256=<base64>
  static const String beklenenImza =
      String.fromEnvironment('APK_SIGNATURE_SHA256', defaultValue: '');

  /// Son okunan durum (bir kez okunur, önbelleklenir).
  static CihazDurumu? _durum;

  static bool get _desteklenir =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Cihaz durumunu okur.
  ///
  /// ⚠ Hata durumunda GÜVENLİ TARAF: okunamadıysa temiz kabul edilir
  /// ve kullanıcı engellenmez. Aksi hâlde köprünün çalışmadığı her
  /// cihazda uygulama kilitlenirdi.
  static Future<CihazDurumu> durum() async {
    if (_durum != null) {
      return _durum!;
    }
    if (!_desteklenir) {
      return _durum = const CihazDurumu();
    }
    try {
      final m = await _kanal.invokeMapMethod<String, Object?>('durum');
      if (m == null) {
        return _durum = const CihazDurumu();
      }
      return _durum = CihazDurumu(
        root: m['root'] == true,
        hataAyiklanabilir: m['hataAyiklanabilir'] == true,
        hataAyiklayiciBagli: m['hataAyiklayiciBagli'] == true,
        oykunucu: m['oykunucu'] == true,
        imzaOzeti: m['imzaOzeti'] as String?,
      );
    } on PlatformException {
      return _durum = const CihazDurumu();
    } on MissingPluginException {
      return _durum = const CihazDurumu();
    }
  }

  /// ⚠ YALNIZ TEST İÇİN.
  @visibleForTesting
  static void durumuAta(CihazDurumu? d) => _durum = d;
}
