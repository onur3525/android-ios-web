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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';

abstract final class SertifikaSabitleme {
  /// Virgülle ayrılmış pin listesi.
  ///
  /// ── İKİ BİÇİM (güvenlik turu 2) ──
  ///
  ///   · `sha256/<base64>` — AÇIK ANAHTAR (SPKI) pini. ÖNERİLEN biçim:
  ///     sertifika aynı anahtarla yenilendiğinde pin KIRILMAZ. Değer,
  ///     `openssl x509 -in sertifika.pem -pubkey -noout | openssl pkey
  ///     -pubin -outform der | openssl dgst -sha256 -binary | base64`
  ///     çıktısıdır (OkHttp/HPKP ile aynı biçim).
  ///   · `<base64>` (öneksiz) — ESKİ biçim: sertifikanın TAMAMININ
  ///     özeti. Önceden verilmiş yapılandırmalar kırılmasın diye hâlâ
  ///     kabul edilir; her yenilemede değişir, yeni sürümlerde
  ///     kullanılmamalıdır.
  ///
  /// Örnek:
  /// `--dart-define=CERT_PINS=sha256/abc...=,sha256/def...=`
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

  static const String _spkiOnek = 'sha256/';

  /// SPKI pinleri (öneki atılmış base64 değerler).
  static Set<String> get _spkiPinleri => pinler
      .where((p) => p.startsWith(_spkiOnek))
      .map((p) => p.substring(_spkiOnek.length))
      .toSet();

  /// Eski biçim (tam sertifika) pinleri.
  static Set<String> get _tamPinler =>
      pinler.where((p) => !p.startsWith(_spkiOnek)).toSet();

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

  // ═══════════════════════════════════════════════════════════════
  // SPKI ÇIKARMA — en küçük DER okuyucusu (güvenlik turu 2)
  //
  // Önceki not, doğrulanamayan bir ASN.1 çözümleyicisini güvenlik
  // yoluna koymamak için SPKI'den kaçınıyordu. Bu okuyucu YALNIZ X.509
  // iskeletini yürür (RFC 5280):
  //
  //   Certificate  ::= SEQUENCE { tbsCertificate, ... }
  //   TBSCertificate ::= SEQUENCE {
  //     [0] version OPTIONAL, serialNumber, signature, issuer,
  //     validity, subject, subjectPublicKeyInfo, ... }
  //
  // ve `subjectPublicKeyInfo` öğesinin HAM DER baytlarını döndürür.
  // Her uzunluk sınır denetiminden geçer; biçim beklenenden farklıysa
  // `null` döner ve sertifika REDDEDİLİR (güvenli taraf).
  //
  // ⚠ DOĞRULAMA: aynı algoritmanın Python karşılığı 150 sistem kök
  // sertifikası ve üretilmiş RSA/EC sertifikalarla `cryptography`
  // kütüphanesinin SPKI çıktısına karşı denendi; hepsi birebir tuttu.
  // Dart tarafı `test/sertifika_spki_test.dart` ile kilitli.
  // ═══════════════════════════════════════════════════════════════

  /// DER TLV: (etiket, içerik başı, öğe sonu) ya da biçim hatasında null.
  static (int, int, int)? _tlv(Uint8List d, int i) {
    if (i + 2 > d.length) {
      return null;
    }
    final etiket = d[i];
    final b = d[i + 1];
    var bas = i + 2;
    var uzunluk = b;
    if (b >= 0x80) {
      final k = b & 0x7f;
      if (k == 0 || k > 4 || i + 2 + k > d.length) {
        return null;
      }
      uzunluk = 0;
      for (var j = 0; j < k; j++) {
        uzunluk = (uzunluk << 8) | d[i + 2 + j];
      }
      bas = i + 2 + k;
    }
    final son = bas + uzunluk;
    if (son > d.length) {
      return null;
    }
    return (etiket, bas, son);
  }

  /// Sertifikanın `subjectPublicKeyInfo` DER baytları; biçim
  /// beklenmedikse null.
  @visibleForTesting
  static Uint8List? spkiDer(Uint8List der) {
    final sertifika = _tlv(der, 0);
    if (sertifika == null || sertifika.$1 != 0x30) {
      return null;
    }
    final tbs = _tlv(der, sertifika.$2);
    if (tbs == null || tbs.$1 != 0x30) {
      return null;
    }
    var i = tbs.$2;
    final ilk = _tlv(der, i);
    if (ilk == null) {
      return null;
    }
    if (ilk.$1 == 0xA0) {
      i = ilk.$3; // [0] version
    }
    // serialNumber, signature, issuer, validity, subject
    for (var n = 0; n < 5; n++) {
      final e = _tlv(der, i);
      if (e == null || e.$3 > tbs.$3) {
        return null;
      }
      i = e.$3;
    }
    final spki = _tlv(der, i);
    if (spki == null || spki.$1 != 0x30 || spki.$3 > tbs.$3) {
      return null;
    }
    return Uint8List.sublistView(der, i, spki.$3);
  }

  /// DER sertifikanın SPKI özeti (base64) — `sha256/` öneki OLMADAN.
  @visibleForTesting
  static String? spkiOzetDer(Uint8List der) {
    final spki = spkiDer(der);
    return spki == null ? null : base64.encode(sha256.convert(spki).bytes);
  }

  /// Zincirdeki sertifika kabul edilir mi?
  ///
  /// Önce SPKI pinleri, sonra (geriye dönük uyumluluk için) eski tam
  /// sertifika pinleri denenir. Ayrıca sertifika GEÇERLİLİK SÜRESİ
  /// içinde olmalıdır: süresi dolmuş ya da henüz başlamamış sertifika,
  /// pini tutsa bile REDDEDİLİR (sistem doğrulaması devre dışı olduğu
  /// için bu denetimi artık kendimiz yapıyoruz).
  static bool kabulEdilir(X509Certificate sertifika) {
    final simdi = DateTime.now().toUtc();
    if (simdi.isBefore(sertifika.startValidity.toUtc()) ||
        simdi.isAfter(sertifika.endValidity.toUtc())) {
      return false;
    }
    final spki = spkiOzetDer(sertifika.der);
    if (spki != null && _spkiPinleri.contains(spki)) {
      return true;
    }
    return _tamPinler.contains(ozet(sertifika));
  }

  // ═══════════════════════════════════════════════════════════════
  // ANA BİLGİSAYAR ADI DENETİMİ (güvenlik turu 2)
  //
  // Sistem güven deposu kapalı olduğu için Dart'ın kendi ad
  // doğrulaması da devrede değil; `badCertificateCallback` yalnız pine
  // bakıyordu. Sabitlemeli istemci YALNIZ API sunucusuna gider: izinli
  // ad, `API_BASE_URL`'in ana bilgisayar adıdır (REST ve WebSocket aynı
  // adresten türer). Başka bir ada yapılan bağlantı, pin tutsa bile
  // REDDEDİLİR.
  // ═══════════════════════════════════════════════════════════════

  /// İzinli ana bilgisayar adları (küçük harf).
  static Set<String> get izinliHostlar {
    try {
      final h = Uri.parse(ApiConfig.baseUrl).host.toLowerCase();
      return h.isEmpty ? const <String>{} : {h};
    } catch (_) {
      // Adres yapılandırılmamışsa hiçbir ada izin verilmez (güvenli taraf).
      return const <String>{};
    }
  }

  /// Bağlanılan ad izinli mi?
  static bool hostIzinli(String host) =>
      izinliHostlar.contains(host.toLowerCase());

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
  /// ⚠ HOSTNAME DOĞRULAMASI (güvenlik turu 2): SPKI pini bir ANAHTARA
  /// bağlıdır, sertifikaya değil; aynı anahtarı taşıyan başka bir ad
  /// için düzenlenmiş sertifika da pini tutar. Bu yüzden `host` artık
  /// ayrıca `API_BASE_URL`'in adıyla karşılaştırılır (`hostIzinli`).
  ///
  /// ⚠ GERİ ÇAĞRIYA GELEN SERTİFİKA: Dart, doğrulamanın başarısız
  /// olduğu zincir halkasını verir; sistem kökleri kapalıyken bu
  /// cihazdan cihaza yaprak ya da ara sertifika olabilir. CERT_PINS
  /// bu yüzden hem yaprak hem ara sertifikanın SPKI pinini içermelidir
  /// (bkz. docs/guvenlik_sertlestirme.md).
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
      // ⚠ İKİ KOŞUL BİRLİKTE: izinli ad VE pin + geçerlilik süresi.
      final tamam = hostIzinli(host) && kabulEdilir(sertifika);
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
