import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/bakim_durumu.dart';
import '../../core/boot.dart' show currentPlatform;
import '../../core/cihaz_kimligi.dart';
import 'sabitlemeli_istemci.dart';
import 'api_config.dart';
import 'api_error_mapper.dart';
import 'token_store.dart';

/// Ağ durumu sorgusu — TEST EDİLEBİLİR SOYUTLAMA.
///
/// `connectivity_plus` çağrısı MethodChannel kullanır ve Flutter binding
/// başlatılmadan çalışmaz. [ApiClient] bu yüzden somut `Connectivity`
/// yerine bu işleve bağlıdır: production'da gerçek eklenti, testlerde
/// deterministik bir işlev verilir.
typedef OnlineChecker = Future<bool> Function();

/// Production varsayılanı: `connectivity_plus` üzerinden gerçek sorgu.
///
/// `checkConnectivity()` 6.x sürümünde DAİMA `List<ConnectivityResult>`
/// döner; listedeki her öğe `none` ise cihaz çevrimdışıdır.
Future<bool> defaultOnlineChecker() async {
  final list = await Connectivity().checkConnectivity();
  return !list.every((e) => e == ConnectivityResult.none);
}

/// Tek HTTP istemcisi: token ekleme, 401'de refresh rotasyonu, offline
/// kontrolü, timeout, kontrollü retry ve standart hata dönüşümü.
class ApiClient {
  final http.Client _http;
  final TokenStore tokens;
  final OnlineChecker _isOnline;
  final String baseUrl;

  final void Function()? onSessionExpired;

  /// WEB OTURUMU (15 Eki): yenileme token'ı sunucunun koyduğu HttpOnly
  /// çerezdedir (JavaScript okuyamaz). İstekler `X-HC-Web: 1` başlığıyla
  /// gider; yenileme gövdesiz yapılır (sekmeler arası ortak, hep güncel
  /// çerez kullanılır). Mobilde false: davranış AYNEN.
  final bool cerezliOturum;

  ApiClient({
    http.Client? httpClient,
    TokenStore? tokenStore,
    /// Ağ durumu sorgusu. Verilmezse `connectivity_plus` kullanılır.
    /// Testler MethodChannel'a ihtiyaç duymamak için kendi işlevini verir.
    OnlineChecker? onlineChecker,
    String? baseUrl,
    this.onSessionExpired,
    bool? cerezliOturum,
  })  : cerezliOturum = cerezliOturum ?? kIsWeb,
        // ── ⚠ SERTİFİKA SABİTLEME ──
        //
        // Pin verilmişse istekler sabitlemeli istemciden geçer; pin
        // yoksa davranış DEĞİŞMEZ (normal sistem doğrulaması).
        // Testler kendi istemcisini verdiği için sabitleme onları
        // etkilemez.
        // ⚠ İSTEMCİ SEÇİMİ PLATFORMA TAŞINDI
        // (`sabitlemeli_istemci.dart`): `IOClient`/`HttpClient`
        // `dart:io`'dadır ve web derlemesini kırıyordu. Mobil
        // davranış AYNEN korunur; web'de tarayıcı istemcisi kullanılır
        // ve sabitleme YAPILMAZ (yapılamaz — bkz. o dosyanın notu).
        _http = httpClient ?? sabitlemeliIstemci(),
        tokens = tokenStore ?? TokenStore(),
        _isOnline = onlineChecker ?? defaultOnlineChecker,
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Boş/null gövdeyi işaretleyen dahili anahtar (dışarı sızmaz).
  static const String _kNullBody = '__hc_null_body__';

  static const _uuid = Uuid();
  Future<bool>? _refreshing; // eşzamanlı 401'lerde TEK yenileme

  // ── ⚠ DEĞİŞMEDİYSE YENİDEN İNDİRME YOK (28 Eki, telefon performansı) ──
  //
  // Sunucu GET yanıtlarına içerik özeti (ETag) koyar. Son yanıt adresiyle
  // birlikte BELLEKTE tutulur; aynı adres yeniden istenince özet
  // `If-None-Match` ile gönderilir. Veri değişmediyse sunucu gövdesiz
  // 304 döner ve saklı gövde kullanılır (ağ ve pil tasarrufu). Özet
  // içerikten üretildiği için eşleşme = birebir aynı veri.
  // ⚠ Kalıcı depoya yazılmaz; oturum kapanınca silinir. En çok
  // [okumaOnbellegiSiniri] adres, en büyük [okumaOnbellegiAzamiBayt].
  static const int okumaOnbellegiSiniri = 64;
  static const int okumaOnbellegiAzamiBayt = 1024 * 1024;
  final Map<String, ({String etiket, String govde})> _okumaOnbellegi = {};

  void _okumaOnbellegiTemizle() => _okumaOnbellegi.clear();

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  /// [idempotencyKey] FİNANSAL POST'larda ZORUNLUDUR (bakiye yükleme,
  /// teklif verme, iletişim açma) — sunucu aynı anahtarı ikinci kez işlemez.
  Future<Map<String, dynamic>> post(String path, {Object? body, String? idempotencyKey}) =>
      _send('POST', path, body: body, idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  /// ⚠ PUT DA IDEMPOTENCY ANAHTARI ALIR.
  ///
  /// Nihai sözleşmede teklif seçme `PUT /listings/{id}/selected-offer`
  /// ile yapılır ve `Idempotency-Key` ZORUNLUDUR (§25). Anahtar
  Future<Map<String, dynamic>> put(String path,
          {Object? body, String? idempotencyKey}) =>
      _send('PUT', path, body: body, idempotencyKey: idempotencyKey);

  /// DELETE — bazı uçlar gövde bekler (ör. bekleyen yükleme iptali).
  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// KAYIT BULUNMAYABİLEN UÇLAR
  ///
  /// Sözleşme: sunucu kayıt yoksa 204 No Content veya gövdesi `null` olan
  /// 200 döner. Her iki durumda da bu metot `null` verir.
  /// 404 bir HATADIR ve yükselmeye devam eder (yol yanlış demektir).
  Future<Map<String, dynamic>?> getOrNull(String path,
      {Map<String, String>? query}) async {
    final r = await _send('GET', path, query: query);
    if (r[_kNullBody] == true) {
      return null;
    }
    if (r.isEmpty) {
      return null;
    }
    return r;
  }

  /// Liste dönen uçlar için (backend dizi döndürür).
  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) async {
    final r = await _send('GET', path, query: query, expectList: true);
    return (r['_list'] as List<dynamic>?) ?? const [];
  }

  static String newIdempotencyKey() => _uuid.v4();

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? idempotencyKey,
    bool expectList = false,
    bool isRetryOfAuth = false,
    int attempt = 0,
  }) async {
    if (!await _online()) throw ApiFailure(offlineError(), 0, 'OFFLINE', null);

    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      if (cerezliOturum) 'X-HC-Web': '1',
    };
    final token = await tokens.accessToken();
    // Cihaz kimliği yalnız OTURUM varken ya da giriş/kayıt sırasında
    // üretilir; oturumsuz ziyaretçinin tarayıcısına hiçbir şey yazılmaz.
    headers.addAll(await _cihazBasliklari(
        olustur: token != null || path.startsWith('/auth/')));
    if (token != null) {
      // ⚠ ÇEREZE GEÇİŞ NOKTASI (web · M-05): backend HttpOnly/Secure/
      // SameSite çerez koyduğunda web'de bu başlık EKLENMEZ; kimlik
      // tarayıcının çerezle gönderdiği oturumdan gelir. Mobil aynen.
      headers['Authorization'] = 'Bearer $token';
    }

    final okumaAnahtari = method == 'GET' ? uri.toString() : null;
    final saklanan = okumaAnahtari == null ? null : _okumaOnbellegi[okumaAnahtari];
    if (saklanan != null) {
      headers['If-None-Match'] = saklanan.etiket;
    }

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        req.body = jsonEncode(body);
      }
      final streamed = await _http.send(req).timeout(ApiConfig.receiveTimeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      if (_retryable(method, attempt)) {
        return _send(method, path,
            body: body, query: query, idempotencyKey: idempotencyKey,
            expectList: expectList, attempt: attempt + 1);
      }
      throw ApiFailure(timeoutError(), 0, 'TIMEOUT', null);
    } on http.ClientException {
      // ⚠ `SocketException` (dart:io) YERİNE `http.ClientException`:
      // önceki tür web'de YOKTUR ve derlemeyi kırıyordu. `package:http`
      // ağ hatalarını iki platformda da bu türle sarar; mobilde
      // `SocketException` de buna dönüşür, yani yeniden deneme
      // davranışı DEĞİŞMEZ.
      if (_retryable(method, attempt)) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        return _send(method, path,
            body: body, query: query, idempotencyKey: idempotencyKey,
            expectList: expectList, attempt: attempt + 1);
      }
      throw ApiFailure(networkError(), 0, 'NETWORK', null);
    }

    // 401 → access token süresi dolmuş olabilir: TEK SEFER refresh dene.
    if (res.statusCode == 401 && !isRetryOfAuth && path != '/auth/refresh') {
      final ok = await _refreshOnce();
      if (ok) {
        return _send(method, path,
            body: body, query: query, idempotencyKey: idempotencyKey,
            expectList: expectList, isRetryOfAuth: true);
      }
      // ⚠ KESİN KURAL (15 Eki): oturum YALNIZ sunucu yenilemeyi açıkça
      // reddederse (çıkış, şifre/telefon değişikliği, askı) kapanır. Ağ
      // hatası, zaman aşımı ya da uyuyan sunucu jetonları SİLMEZ; istek
      // ağ hatası olarak döner, oturum bir sonraki denemede sürer.
      if (!_sonYenilemeReddedildi) {
        throw ApiFailure(networkError(), 0, 'NETWORK', null);
      }
      await _forceLogout();
    }

    // GÖVDE DAİMA UTF-8 ÇÖZÜLÜR.
    //
    // `res.body` Content-Type başlığındaki charset'e bakar; sunucu
    // `charset=utf-8` göndermezse http paketi LATIN-1 varsayar ve Türkçe
    // karakterler bozulur ("Kazımdirik" → "KazÄ±mdirik").
    // JSON, RFC 8259 gereği UTF-8'dir; bu yüzden ham baytlar doğrudan
    // utf8 ile çözülür.
    var govde = res.bodyBytes.isEmpty
        ? ''
        : utf8.decode(res.bodyBytes, allowMalformed: true);
    var durum = res.statusCode;
    if (okumaAnahtari != null) {
      if (durum == 304 && saklanan != null) {
        // Değişmedi: saklı gövde kullanılır (sonuna taşınır: en yeni).
        govde = saklanan.govde;
        durum = 200;
        _okumaOnbellegi
          ..remove(okumaAnahtari)
          ..[okumaAnahtari] = saklanan;
      } else if (durum == 200) {
        final etiket = res.headers['etag'];
        _okumaOnbellegi.remove(okumaAnahtari);
        if (etiket != null && etiket.isNotEmpty && govde.length <= okumaOnbellegiAzamiBayt) {
          _okumaOnbellegi[okumaAnahtari] = (etiket: etiket, govde: govde);
          while (_okumaOnbellegi.length > okumaOnbellegiSiniri) {
            _okumaOnbellegi.remove(_okumaOnbellegi.keys.first);
          }
        }
      }
    }
    final decoded = govde.isEmpty ? null : _decode(govde);

    if (durum >= 200 && durum < 300) {
      if (decoded is List) {
        return {'_list': decoded};
      }
      // BOŞ CEVAP SÖZLEŞMESİ (kayıt yok):
      //   • 204 No Content            → gövde yok
      //   • 200 + gövde "null"        → decoded == null
      //   • 200 + tamamen boş gövde   → decoded == null
      // Üçü de AYNI şekilde işaretlenir; getOrNull bunu null'a çevirir.
      // Not: gerçek boş nesne `{}` bundan AYRIDIR ve null sayılmaz.
      if (durum == 204 || decoded == null) {
        return <String, dynamic>{_kNullBody: true};
      }
      return (decoded as Map<String, dynamic>?) ?? const {};
    }

    // Sunucu hatasında kontrollü tekrar (yalnız GET).
    if (res.statusCode >= 500 && _retryable(method, attempt)) {
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      return _send(method, path,
          body: body, query: query, idempotencyKey: idempotencyKey,
          expectList: expectList, attempt: attempt + 1);
    }

    final map = decoded is Map<String, dynamic> ? decoded : null;
    final kod = (map?['error'] as Map<String, dynamic>?)?['code'] as String?;
    // ⚠ HESAP ASKIDA / BANLI (admin kararı, backend her istekte denetler):
    // oturum MEVCUT oturum-düşme yoluyla kapatılır (jetonlar silinir, ana
    // sayfaya dönülür). Sunucunun gerekçeli mesajı aşağıdaki hata olarak
    // çağıran ekranın bugünkü hata gösterimine gider; YENİ ekran yok.
    if (res.statusCode == 403 &&
        (kod == 'ACCOUNT_SUSPENDED' || kod == 'ACCOUNT_BANNED')) {
      await _forceLogout();
    }
    // ⚠ BAKIM (22 Eki): sunucu bakımda olduğunu söylediyse bakım durumu
    // hemen yeniden sorulur; bakım ekranı bütün ekranları örter.
    if (res.statusCode == 503 && kod == 'MAINTENANCE') {
      unawaited(BakimDurumu.i.kontrolEt());
    }
    throw ApiFailure(
      mapErrorBody(res.statusCode, map),
      res.statusCode,
      (map?['error'] as Map<String, dynamic>?)?['code'] as String? ?? 'UNKNOWN',
      map?['requestId'] as String?,
    );
  }

  bool _retryable(String method, int attempt) =>
      method == 'GET' && attempt < ApiConfig.maxRetries;

  dynamic _decode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _online() async {
    // Ağ sorgusu enjekte edilen işleve devredilir (bkz. [OnlineChecker]).
    return _isOnline();
  }

  /// REFRESH ROTASYONU: backend eski refresh'i iptal edip yenisini verir.
  /// Eşzamanlı isteklerde yalnız BİR yenileme çalışır.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  /// WEB AÇILIŞI: bellekte token yokken oturumu HttpOnly çerezle sürdürür
  /// (sayfa yenilendi / sekme yeniden açıldı). Başarıda token'lar belleğe
  /// alınır. Mobilde ya da çerez geçersizse false.
  Future<bool> cerezleOturumuSurdur() =>
      cerezliOturum ? _refreshOnce() : Future.value(false);

  /// ⚠ CİHAZ KİMLİĞİ (22 Eki · bakımda test hesabı): rastgele cihaz
  /// kimliği ve platform adı. Sunucu yalnız admin'in listesindeki hesaplar
  /// için kullanır (bkz. `core/cihaz_kimligi.dart`). Kimlik yoksa başlık da yok.
  /// `olustur: false` iken yoksa ÜRETİLMEZ (oturumsuz ziyaretçi).
  Future<Map<String, String>> _cihazBasliklari({required bool olustur}) async {
    final c = olustur
        ? await CihazKimligi.i.deger()
        : await CihazKimligi.i.mevcut();
    if (c == null) {
      return const {};
    }
    return {'X-HC-Cihaz': c, 'X-HC-Platform': currentPlatform()};
  }

  /// Son yenileme sunucu tarafından KESİN reddedildi mi (401/403)?
  bool _sonYenilemeReddedildi = false;

  Future<bool> _doRefresh() async {
    _sonYenilemeReddedildi = false;
    // Web: token gövdede gönderilmez; sunucu çerezden okur. Bellekteki eski
    // bir kopya (başka sekme döndürmüş olabilir) yeniden kullanım sayılırdı.
    final rt = cerezliOturum ? null : await tokens.refreshToken();
    if (rt == null && !cerezliOturum) {
      return false;
    }
    try {
      final res = await _http
          .post(Uri.parse('$baseUrl/auth/refresh'),
              headers: {
                'Content-Type': 'application/json',
                if (cerezliOturum) 'X-HC-Web': '1',
                ...await _cihazBasliklari(olustur: true),
              },
              body: jsonEncode(
                  rt == null ? <String, String>{} : {'refreshToken': rt}))
          .timeout(ApiConfig.receiveTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _sonYenilemeReddedildi = res.statusCode == 401 || res.statusCode == 403;
        // ⚠ WEB: sunucu çerezi KESİN reddettiyse (401) oturum izi silinir;
        // açılış artık sunucuyu beklemez. Ağ/uyku hatası izi SİLMEZ.
        if (cerezliOturum && res.statusCode == 401) {
          _okumaOnbellegiTemizle();
          await tokens.clear();
        }
        return false;
      }
      // Aynı UTF-8 kuralı refresh cevabı için de geçerlidir.
      final m = _decode(utf8.decode(res.bodyBytes, allowMalformed: true))
          as Map<String, dynamic>?;
      final a = m?['accessToken'] as String?;
      final r = m?['refreshToken'] as String?;
      if (a == null || r == null) {
        return false;
      }
      await tokens.save(access: a, refresh: r);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _forceLogout() async {
    _okumaOnbellegiTemizle();
    await tokens.clear();
    onSessionExpired?.call();
  }

  /// Oturumu kapat (yerel): tokenlar silinir.
  Future<void> clearSession() {
    _okumaOnbellegiTemizle();
    return tokens.clear();
  }
}
