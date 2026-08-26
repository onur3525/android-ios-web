import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'sertifika_sabitleme.dart';
import 'package:uuid/uuid.dart';

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

  /// Oturum düştüğünde (refresh de geçersiz) tetiklenir → uygulama çıkış yapar.
  final void Function()? onSessionExpired;

  ApiClient({
    http.Client? httpClient,
    TokenStore? tokenStore,
    /// Ağ durumu sorgusu. Verilmezse `connectivity_plus` kullanılır.
    /// Testler MethodChannel'a ihtiyaç duymamak için kendi işlevini verir.
    OnlineChecker? onlineChecker,
    String? baseUrl,
    this.onSessionExpired,
  })  : // ── ⚠ SERTİFİKA SABİTLEME ──
        //
        // Pin verilmişse istekler sabitlemeli istemciden geçer; pin
        // yoksa davranış DEĞİŞMEZ (normal sistem doğrulaması).
        // Testler kendi istemcisini verdiği için sabitleme onları
        // etkilemez.
        _http = httpClient ??
            (SertifikaSabitleme.etkin
                ? IOClient(SertifikaSabitleme.istemci())
                : http.Client()),
        tokens = tokenStore ?? TokenStore(),
        _isOnline = onlineChecker ?? defaultOnlineChecker,
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Boş/null gövdeyi işaretleyen dahili anahtar (dışarı sızmaz).
  static const String _kNullBody = '__hc_null_body__';

  static const _uuid = Uuid();
  Future<bool>? _refreshing; // eşzamanlı 401'lerde TEK yenileme

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
  /// yalnız POST'a özgü değildir; durum değiştiren her istek
  /// tekrarlanabilir olmalıdır.
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
    };
    final token = await tokens.accessToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
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
    } on SocketException {
      if (_retryable(method, attempt)) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        return _send(method, path,
            body: body, query: query, idempotencyKey: idempotencyKey,
            expectList: expectList, attempt: attempt + 1);
      }
      throw ApiFailure(networkError(), 0, 'NETWORK', null);
    } on http.ClientException {
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
      await _forceLogout();
    }

    // GÖVDE DAİMA UTF-8 ÇÖZÜLÜR.
    //
    // `res.body` Content-Type başlığındaki charset'e bakar; sunucu
    // `charset=utf-8` göndermezse http paketi LATIN-1 varsayar ve Türkçe
    // karakterler bozulur ("Kazımdirik" → "KazÄ±mdirik").
    // JSON, RFC 8259 gereği UTF-8'dir; bu yüzden ham baytlar doğrudan
    // utf8 ile çözülür.
    final govde = res.bodyBytes.isEmpty
        ? ''
        : utf8.decode(res.bodyBytes, allowMalformed: true);
    final decoded = govde.isEmpty ? null : _decode(govde);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is List) {
        return {'_list': decoded};
      }
      // BOŞ CEVAP SÖZLEŞMESİ (kayıt yok):
      //   • 204 No Content            → gövde yok
      //   • 200 + gövde "null"        → decoded == null
      //   • 200 + tamamen boş gövde   → decoded == null
      // Üçü de AYNI şekilde işaretlenir; getOrNull bunu null'a çevirir.
      // Not: gerçek boş nesne `{}` bundan AYRIDIR ve null sayılmaz.
      if (res.statusCode == 204 || decoded == null) {
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

  Future<bool> _doRefresh() async {
    final rt = await tokens.refreshToken();
    if (rt == null) {
      return false;
    }
    try {
      final res = await _http
          .post(Uri.parse('$baseUrl/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': rt}))
          .timeout(ApiConfig.receiveTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
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
    await tokens.clear();
    onSessionExpired?.call();
  }

  /// Oturumu kapat (yerel): tokenlar silinir.
  Future<void> clearSession() => tokens.clear();
}
