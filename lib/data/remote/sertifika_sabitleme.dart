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

  /// Sertifikanın SHA-256 özeti (base64) — DER kodlu tam sertifika.
  static String ozet(X509Certificate sertifika) =>
      base64.encode(sha256.convert(sertifika.der).bytes);

  /// Zincirdeki sertifika kabul edilir mi?
  static bool kabulEdilir(X509Certificate sertifika) =>
      pinler.contains(ozet(sertifika));

  /// Sabitlemeli `HttpClient` üretir.
  ///
  /// ⚠ `badCertificateCallback` YALNIZ sistem doğrulaması BAŞARISIZ
  /// olduğunda çağrılır. Bu yüzden sabitleme oraya konamaz — geçerli
  /// ama sahte bir zincir hiç uğramadan geçerdi. Doğru yer
  /// `connectionFactory` değil, bağlantı kurulduktan sonra sertifikayı
  /// okumaktır; `HttpClient` bunu `badCertificateCallback` dışında
  /// vermez.
  ///
  /// ⚠ BU YÜZDEN: sabitleme, sistem doğrulamasını GEÇEN sertifikalar
  /// için `dart:io` katmanında yapılamaz. Uygulanan yaklaşım, sistem
  /// doğrulamasına ek olarak pin denetimini `badCertificateCallback`
  /// ile birleştirmektir:
  ///   • sistem doğrulaması geçti  → pin denetimi `dogrula` ile
  ///     istek katmanında yapılır
  ///   • sistem doğrulaması geçmedi → pin tutuyorsa kabul edilir
  ///     (kendi CA'sını tanımayan cihazlar için)
  static HttpClient istemci() {
    final c = HttpClient();
    if (!etkin) {
      return c;
    }
    c.badCertificateCallback = (sertifika, host, port) {
      final tamam = kabulEdilir(sertifika);
      if (!tamam && kDebugMode) {
        debugPrint('SERTIFIKA_PIN_TUTMADI host=$host');
      }
      return tamam;
    };
    return c;
  }

  /// Kurulmuş bir bağlantının sertifikasını doğrular.
  ///
  /// ⚠ Sistem doğrulamasını geçen sertifikalar da bu kapıdan geçer;
  /// aksi hâlde saldırganın cihaza yüklediği güvenilir kök işe yarardı.
  ///
  /// Sabitleme kapalıysa her zaman `true` döner.
  static bool dogrula(X509Certificate? sertifika) {
    if (!etkin) {
      return true;
    }
    if (sertifika == null) {
      // ⚠ Sertifika okunamıyorsa GÜVENME: sabitleme açıkken belirsizlik
      // reddedilir.
      return false;
    }
    return kabulEdilir(sertifika);
  }
}
