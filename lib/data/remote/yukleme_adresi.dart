import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// DOSYA YÜKLEME ADRESİ DOĞRULAMASI (güvenlik turu 2 · M-03)
///
/// Fotoğraflar API sunucusuna değil, sunucunun verdiği İMZALI adrese
/// (`uploadUrl`, S3/R2 türü depolama) doğrudan `PUT` edilir. Bu adres
/// istemcinin kendi seçtiği bir yer değildir; sunucudan gelir. Adres
/// herhangi bir yere işaret edebilseydi (ele geçirilmiş yanıt, hatalı
/// yapılandırma), kullanıcının fotoğrafları oraya giderdi.
///
/// Yüklemeden ÖNCE üç kural denetlenir; biri tutmazsa HİÇBİR bayt
/// gönderilmez:
///   1. YALNIZ HTTPS — düz http, kullanıcı bilgisi (`user@`) ve parça
///      (`#`) içeren adres reddedilir.
///   2. İZİNLİ ALAN ADI — `--dart-define=STORAGE_HOSTS=...` (virgülle
///      ayrılmış). Tam ad (`hizmetcep-media.s3.eu-central-1.amazonaws.com`)
///      ya da nokta ile başlayan sonek (`.r2.cloudflarestorage.com`).
///      Liste boşsa: RELEASE'te yükleme REDDEDİLİR (sessiz fail-open
///      yok); debug'da yalnız 1. ve 3. kural uygulanır.
///   3. İMZALI ADRES — AWS SigV4 (S3/R2) sorgu parametreleri
///      zorunludur: `X-Amz-Algorithm`, `X-Amz-Credential`,
///      `X-Amz-Date`, `X-Amz-Expires`, `X-Amz-Signature`. Süresi
///      geçmiş ya da 7 günden uzun (SigV4 üst sınırı) imza reddedilir.
///
/// ⚠ İMZANIN KENDİSİ istemcide DOĞRULANAMAZ (gizli anahtar sunucuda);
/// burada yalnız adresin imzalı biçimde olduğu ve süresinin geçerli
/// olduğu denetlenir. Asıl yetki kontrolünü depolama sağlayıcısı yapar.
///
/// ⚠ SABİTLEME: yükleme API pinleriyle YAPILMAZ — depolama
/// sağlayıcısının sertifikası farklıdır. Güvence: sistem TLS
/// doğrulaması + yukarıdaki üç kural.
/// ═══════════════════════════════════════════════════════════════
abstract final class YuklemeAdresi {
  static const String _hostTanim =
      String.fromEnvironment('STORAGE_HOSTS', defaultValue: '');

  /// İzinli adlar / sonekler (küçük harf).
  static List<String> get izinliHostlar => _hostTanim
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static const List<String> _zorunluParametreler = [
    'X-Amz-Algorithm',
    'X-Amz-Credential',
    'X-Amz-Date',
    'X-Amz-Expires',
    'X-Amz-Signature',
  ];

  /// SigV4 imzasının izin verilen en uzun süresi (7 gün).
  static const int _enUzunSureSaniye = 7 * 24 * 60 * 60;

  /// [adres] yüklemeye uygunsa `null`, değilse ret gerekçesi.
  ///
  /// [simdi] ve [izinli] yalnız testlerde verilir.
  static String? denetle(
    String adres, {
    DateTime? simdi,
    List<String>? izinli,
    bool? release,
  }) {
    final Uri u;
    try {
      u = Uri.parse(adres);
    } catch (_) {
      return 'geçersiz adres';
    }
    // 1. YALNIZ HTTPS
    if (u.scheme != 'https') {
      return 'yalnız https kabul edilir';
    }
    if (u.userInfo.isNotEmpty || u.hasFragment || u.host.isEmpty) {
      return 'adres biçimi kabul edilmez';
    }
    // 2. İZİNLİ ALAN ADI
    final liste = izinli ?? izinliHostlar;
    final host = u.host.toLowerCase();
    if (liste.isEmpty) {
      if (release ?? kReleaseMode) {
        return 'depolama alan adı yapılandırılmamış (STORAGE_HOSTS)';
      }
    } else {
      final uygun = liste.any((h) =>
          h.startsWith('.') ? host.endsWith(h) && host.length > h.length : host == h);
      if (!uygun) {
        return 'izinli olmayan depolama alan adı';
      }
    }
    // 3. İMZALI ADRES (SigV4)
    final q = u.queryParameters;
    for (final p in _zorunluParametreler) {
      if ((q[p] ?? '').isEmpty) {
        return 'imzalı adres değil ($p yok)';
      }
    }
    final tarih = _amzTarihi(q['X-Amz-Date']!);
    final sure = int.tryParse(q['X-Amz-Expires']!);
    if (tarih == null || sure == null || sure <= 0 || sure > _enUzunSureSaniye) {
      return 'imza süresi geçersiz';
    }
    final an = (simdi ?? DateTime.now()).toUtc();
    if (an.isAfter(tarih.add(Duration(seconds: sure)))) {
      return 'imzanın süresi dolmuş';
    }
    return null;
  }

  /// `yyyyMMddTHHmmssZ` → UTC tarih; biçim bozuksa null.
  static DateTime? _amzTarihi(String s) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$')
        .firstMatch(s);
    if (m == null) {
      return null;
    }
    int g(int i) => int.parse(m.group(i)!);
    return DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6));
  }
}
