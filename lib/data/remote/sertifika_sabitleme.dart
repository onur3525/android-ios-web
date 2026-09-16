// SERTİFİKA SABİTLEME (certificate pinning)
//
// ⚠ NEYE KARŞI: cihaza kök sertifika yükleyebilen bir saldırgan
// (kurumsal cihaz yönetimi, kötü amaçlı profil, sahte Wi-Fi portalı)
// TLS'i sonlandırıp trafiği okuyabilir. Token, telefon numarası ve
// kart oturumu bu trafikte taşınır.
//
// ⚠ NASIL: sunucunun açık anahtarının SHA-256 özeti derleme zamanında
// verilir; el sıkışmada sunucudan gelen zincirdeki özetlerden hiçbiri
// listede yoksa bağlantı REDDEDİLİR.
//
// ⚠ PIN VERİLMEZSE NE OLUR: sabitleme DEVRE DIŞI kalır ve normal
// sistem doğrulaması geçerlidir. Bilerek böyle: yanlış pin ile çıkılan
// bir sürüm uygulamayı TAMAMEN çalışmaz hâle getirir. Pin, alan adı
// ve sertifika kesinleştikten sonra verilir.
//
// ⚠ YEDEK PİN ZORUNLU: sertifika yenilenince tek pinli uygulama
// kırılır. En az iki pin verilmelidir (mevcut + sonraki).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

abstract final class SertifikaSabitleme {
  /// Virgülle ayrılmış SHA-256 özetleri (base64).
  ///
  /// Örnek:
  /// `--dart-define=CERT_PINS=abc...=,def...=`
  static const String _pinTanim =
      String.fromEnvironment('CERT_PINS', defaultValue: '');

  /// Ayrıştırılmış pin listesi.
  static List<String> get pinler => _pinTanim
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  /// Sabitleme etkin mi?
  static bool get etkin => pinler.isNotEmpty;

  /// Sertifikanın SHA-256 özeti (base64) — DER kodlu TAM SERTİFİKA.
  ///
  /// ── ⚠ NİÇİN SPKI DEĞİL TAM SERTİFİKA ──
  ///
  /// Yaygın pratik, açık anahtarı (SPKI) pinlemektir: sertifika aynı
  /// anahtarla yenilendiğinde pin kırılmaz. Ancak Dart'ın
  /// `X509Certificate` sınıfı YALNIZ `der` alanını verir; SPKI'yi
  /// çıkarmak için ASN.1 çözümleyicisi yazmak ya da yeni bir paket
  /// eklemek gerekir. Doğrulanamayan bir ASN.1 çözümleyicisini
  /// güvenlik yoluna koymak, kazandırdığından çok riski getirir.
  ///
  /// ⚠ BEDELİ: sertifika yenilendiğinde pin DEĞİŞİR. Bu yüzden
  /// yedek pin zorunlu tutulur (`pinDenetimi`).
  static String ozet(X509Certificate sertifika) =>
      base64.encode(sha256.convert(sertifika.der).bytes);

  /// Zincirdeki sertifika kabul edilir mi?
  static bool kabulEdilir(X509Certificate sertifika) =>
      pinler.contains(ozet(sertifika));

  /// Sabitlemeli `HttpClient` üretir.
  ///
  /// ── ⚠ ÖNCEKİ UYGULAMA GERÇEK SABİTLEME YAPMIYORDU ──
  ///
  /// `badCertificateCallback` YALNIZ sistem doğrulaması BAŞARISIZ
  /// olduğunda çağrılır. Pin denetimi oraya konduğunda, cihaza kök
  /// sertifika yükleyebilen saldırganın ürettiği zincir sistem
  /// doğrulamasını GEÇİYOR, geri çağrı hiç tetiklenmiyor ve pin
  /// listesine BAKILMADAN bağlantı kuruluyordu. Yani sabitleme, tam
  /// da korumak için var olduğu tehdide karşı etkisizdi.
  ///
  /// ── ⚠ ÇÖZÜM: SİSTEM KÖK DEPOSU DEVRE DIŞI ──
  ///
  /// `SecurityContext(withTrustedRoots: false)` ile hiçbir kök
  /// sertifika güvenilmez sayılır. Sonuç:
  ///   • Her zincir doğrulamayı başarısız sayar,
  ///   • `badCertificateCallback` HER BAĞLANTIDA çağrılır,
  ///   • karar TEK BAŞINA pin listesine kalır.
  ///
  /// Cihaza yüklenen kök sertifika artık işe yaramaz: güven deposu
  /// hiç okunmuyor. Bu, `dart:io` ile connection-level sabitlemenin
  /// bilinen ve belgelenmiş yoludur.
  ///
  /// ⚠ BEDELİ BİLİNÇLİ: pin verilmiş bir sürümde SADECE pinlenen
  /// sertifika çalışır. Sertifika yenilenmeden önce yeni pin
  /// dağıtılmazsa uygulama tamamen bağlanamaz hâle gelir — bu yüzden
  /// en az iki pin zorunludur (bkz. `pinDenetimi`).
  ///
  /// ⚠ HOSTNAME DOĞRULAMASI: pin TAM SERTİFİKANIN özetidir; belirli
  /// bir sertifikayı kabul etmek, o sertifikanın ait olduğu alan adına
  /// bağlanmak demektir. Ayrıca `host` denetlenmez çünkü sertifikanın
  /// kendisi zaten tek ve sabittir.
  ///
  /// ⚠ PIN YOKSA DAVRANIŞ DEĞİŞMEZ: normal sistem doğrulaması
  /// geçerlidir. Release'te bunun sessizce olmaması için
  /// `pinDenetimi` ayrıca çağrılır.
  static HttpClient istemci() {
    final c = HttpClient();
    if (!etkin) {
      return c;
    }
    // ⚠ GÜVEN DEPOSU BOŞ: sistem CA'ları devre dışı.
    final sabitli = HttpClient(context: SecurityContext(withTrustedRoots: false));
    sabitli.badCertificateCallback = (sertifika, host, port) {
      final tamam = kabulEdilir(sertifika);
      if (!tamam && kDebugMode) {
        debugPrint('SERTIFIKA_PIN_TUTMADI host=$host');
      }
      return tamam;
    };
    return sabitli;
  }

  /// ── ⚠ RELEASE'TE SESSİZ FAIL-OPEN YASAK ──
  ///
  /// Pin verilmeden çıkılan bir sürümde sabitleme kapalıdır ve bunu
  /// hiçbir şey haber vermez. `API_BASE_URL` için zaten bir zorunluluk
  /// var (`ApiConfig.baseUrl`); aynı katılık pin için de gerekir.
  ///
  /// ⚠ YALNIZ GERÇEK API MODUNDA: mock derlemede sunucuya hiç
  /// bağlanılmaz, pin istemek anlamsız olur.
  ///
  /// ⚠ EN AZ İKİ PIN: tek pinli sürüm, sertifika yenilendiği an
  /// uygulamayı tamamen çalışmaz hâle getirir. Yedek pin (sonraki
  /// sertifikanın anahtarı) zorunludur.
  static void pinDenetimi({required bool gercekApi}) {
    if (!kReleaseMode || !gercekApi) {
      return;
    }
    if (pinler.isEmpty) {
      throw StateError(
        'RELEASE derlemede CERT_PINS zorunludur: '
        '--dart-define=CERT_PINS=<mevcut>,<yedek>',
      );
    }
    if (pinler.length < 2) {
      throw StateError(
        'CERT_PINS en az İKİ pin içermelidir (mevcut + yedek). '
        'Tek pinli sürüm, sertifika yenilendiğinde uygulamayı '
        'tamamen çalışmaz hâle getirir.',
      );
    }
  }

  // ── ⚠ `dogrula()` KALDIRILDI ──
  //
  // Sistem doğrulamasını geçen sertifikalar için istek katmanında pin
  // denetimi yapması amaçlanmıştı ama HİÇBİR YERDEN ÇAĞRILMIYORDU;
  // ölü koddu ve "pinning var" izlenimi veriyordu. Denetim artık
  // bağlantı kurulurken, `badCertificateCallback` üzerinden ve boş
  // güven deposuyla yapılıyor — istek katmanında ek bir kapıya gerek
  // kalmadı.
}
