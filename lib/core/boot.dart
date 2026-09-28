/// AÇILIŞ KARARI (splash)
///
/// Splash ekranı bu modeli kullanarak nereye yönlendireceğine karar verir.
/// Sıra ÖNEMLİDİR: bakım ve zorunlu güncelleme, oturumdan ÖNCE gelir —
/// aksi hâlde bakımdayken oturum açmış kullanıcı uygulamayı kullanmaya
/// devam ederdi.
library;

import 'package:flutter/foundation.dart';


enum BootDecision {
  /// Bakım modu aktif — kullanıcı içeri alınmaz.
  maintenance,

  /// Sürüm minimum desteklenenin altında — zorunlu güncelleme.
  forceUpdate,

  /// Sunucuya ulaşılamadı ve yerel oturum da yok.
  offline,

  /// Ana karşılama ekranı.
  ///
  /// Oturum VARSA aktif role göre panel, YOKSA HTML'deki karşılama
  /// ekranı. Referans `vSplash()` her iki durumda da home'a gider;
  /// bu yüzden ayrı bir `login` kararı YOKTUR.
  home,
}

class BootResult {
  final BootDecision decision;

  /// Bakım mesajı (varsa).
  final String? maintenanceMessage;
  final String? maintenanceEndAt;

  /// Zorunlu güncelleme için mağazaya yönlendirme bilgisi.
  final String? latestVersion;
  final String? minSupportedVersion;

  /// Oturum bulunduysa kullanıcının son aktif rolü.
  final bool isProvider;

  const BootResult(
    this.decision, {
    this.maintenanceMessage,
    this.maintenanceEndAt,
    this.latestVersion,
    this.minSupportedVersion,
    this.isProvider = false,
  });
}

/// Platform adı — backend sözlüğüyle aynı: android | ios | web.
String currentPlatform() {
  if (kIsWeb) {
    return 'web';
  }
  // ⚠ `Platform` (dart:io) YERİNE `defaultTargetPlatform`:
  // `dart:io` içe aktaran dosya Flutter Web'de DERLENMEZ. Bu alan
  // yalnız platform ADINI üretiyordu; `foundation` karşılığı her
  // platformda çalışır ve mobilde AYNI değeri döndürür.
  //
  // ⚠ `try/catch` KORUNDU: test ortamı davranışı değişmesin.
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
  } catch (_) {
    // Test ortamında platform okunamayabilir.
  }
  return 'android';
}

/// "1.2.3" biçimli sürümleri karşılaştırır. a<b → -1, a==b → 0, a>b → 1.
/// Biçimsiz/eksik girdide 0 döner (karşılaştırma yapılmaz — kullanıcı
/// yanlışlıkla güncellemeye zorlanmaz).
int compareVersions(String? a, String? b) {
  if (a == null || b == null) {
    return 0;
  }
  final ap = a.trim().split('-').first.split('.');
  final bp = b.trim().split('-').first.split('.');
  if (ap.isEmpty || bp.isEmpty) {
    return 0;
  }
  for (var i = 0; i < 3; i++) {
    final x = int.tryParse(i < ap.length ? ap[i] : '0');
    final y = int.tryParse(i < bp.length ? bp[i] : '0');
    if (x == null || y == null) {
      return 0;
    }
    if (x != y) {
      return x < y ? -1 : 1;
    }
  }
  return 0;
}

/// Saf karar fonksiyonu — test edilebilir olması için ağ/IO içermez.
///
/// [configOk] false ise sunucuya ulaşılamamıştır: oturum varsa kullanıcı
/// çevrimdışı olarak içeri alınır (uygulama tamamen kilitlenmez),
/// yoksa çevrimdışı ekranı gösterilir.
/// AĞ DURUMU — ÜÇ DURUMLU
///
/// ⚠ `bool` YETERSİZDİR: kontrol hatası (platform kanalı hazır değil,
/// DNS/izin sorunu) "internet var" DEMEK DEĞİLDİR. `true` dönmek
/// kullanıcıyı SAHTE ONLINE'a, `false` dönmek YANLIŞ OFFLINE'a
/// kilitler. Bu yüzden bilinmeyen durum ayrı taşınır.
enum AgDurumu {
  /// Bağlantı DOĞRULANDI.
  online,

  /// Bağlantı YOK — art arda iki olumsuz sorgu.
  offline,

  /// Kontrol edilemedi (hata/zaman aşımı). Kesin bilgi YOKTUR.
  bilinmiyor;

  /// Çevrimdışı ekranı YALNIZ kesin `offline` durumunda gösterilir.
  ///
  /// `bilinmiyor` durumunda kullanıcı çevrimdışına HAPSEDİLMEZ:
  /// akışa devam eder ve ağ gerektiren işlemde gerçek hatayı görür.
  bool get kesinCevrimdisi => this == AgDurumu.offline;
}

BootResult decideBoot({
  required bool configOk,
  required bool maintenanceActive,
  String? maintenanceMessage,
  String? maintenanceEndAt,
  required String appVersion,
  String? minSupportedVersion,
  String? latestVersion,
  required bool hasSession,
  required bool isProvider,

  /// CİHAZIN GERÇEK İNTERNET DURUMU.
  ///
  /// ⚠ `configOk` ile KARIŞTIRILMAZ: `configOk=false` yalnız
  /// "HizmetCep sunucusundan meta bilgisi ALINAMADI" demektir —
  /// sunucu bakımda, yavaş veya erişilemez olabilir. İnternet varken
  /// kullanıcıya "İnternet bağlantısı yok" göstermek YANLIŞTIR.
  ///
  /// Varsayılan `bilinmiyor`: bilgi yoksa kullanıcı ne çevrimdışına
  /// hapsedilir ne de sahte çevrimiçi sayılır.
  AgDurumu ag = AgDurumu.bilinmiyor,
}) {
  if (configOk) {
    if (maintenanceActive) {
      return BootResult(
        BootDecision.maintenance,
        maintenanceMessage: maintenanceMessage,
        maintenanceEndAt: maintenanceEndAt,
      );
    }
    // Sürüm minimumun ALTINDAYSA zorunlu güncelleme.
    if (compareVersions(appVersion, minSupportedVersion) < 0) {
      return BootResult(
        BootDecision.forceUpdate,
        latestVersion: latestVersion,
        minSupportedVersion: minSupportedVersion,
      );
    }
  } else if (!hasSession && ag.kesinCevrimdisi) {
    // Sunucu meta bilgisi YOK **ve** bağlantı KESİN olarak yok.
    // `bilinmiyor` durumunda bu dal ÇALIŞMAZ — yanlış offline yok.
    return const BootResult(BootDecision.offline);
  }

  // ── OTURUMSUZ KULLANICI DA HOME'A GİDER ──
  //
  // Referans `vSplash()` 1400 ms sonra yığını temizleyip KOŞULSUZ
  // olarak home'a gider:
  //   setTimeout(() => { STACK.length = 0;
  //                      navigate('home', {enter:'enter-fade'}); }, 1400)
  //
  // Oturumsuz kullanıcı ana karşılama ekranını görür; giriş ekranı
  // ancak profil ikonuna dokununca açılır. Otomatik `/login`
  // yönlendirmesi HTML sözleşmesiyle ÇELİŞİR.
  //
  // `isProvider` yalnız oturum varken anlamlıdır; oturumsuzda panel
  // seçimi yapılmaz, Home rol kartlarını gösterir.
  return BootResult(
    BootDecision.home,
    isProvider: hasSession && isProvider,
  );
}
