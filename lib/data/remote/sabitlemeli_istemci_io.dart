import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'sertifika_sabitleme.dart';

// ⚠ MOBİL — ANDROID VE iOS. Bu dosya web derlemesine GİRMEZ.

/// Sabitlemeli istemci; pin yoksa düz istemci.
///
/// ⚠ DAVRANIŞ DEĞİŞMEDİ: `api_client.dart` içindeki satırın birebir
/// aynısı, yalnız buraya taşındı.
http.Client sabitlemeliIstemci() => SertifikaSabitleme.etkin
    ? IOClient(SertifikaSabitleme.istemci())
    : http.Client();

/// Release + gerçek API modunda pin zorunluluğunu denetler.
///
/// ⚠ SADECE DEVREDER: kural `SertifikaSabitleme.pinDenetimi` içinde;
/// burada ikinci bir kopya yok.
void pinDenetimi({required bool gercekApi}) =>
    SertifikaSabitleme.pinDenetimi(gercekApi: gercekApi);

/// ── ⚠ WEBSOCKET SABİTLEMESİ (güvenlik turu 2) ──
///
/// `socket_io_client` bağlantıyı kendi içinde `WebSocket.connect` ile
/// kurar ve dışarıdan `HttpClient` alan bir seçenek sunmaz; bu yüzden
/// WebSocket bugüne dek SABİTLEMESİZDİ.
///
/// `WebSocket.connect`, kendisine istemci verilmediğinde `HttpClient()`
/// üretir ve bu üretim `HttpOverrides.current`'a uyar. [f] burada
/// sabitlemeli istemci üreten bir `HttpOverrides` BÖLGESİNDE çalışır;
/// bölgede başlatılan bağlantı ve onun zamanlayıcıları (yeniden
/// bağlanma) aynı bölgede kalır. Sonuç: WebSocket el sıkışması REST ile
/// AYNI pin + ad + süre denetiminden geçer.
///
/// ⚠ YALNIZ BU BÖLGE: `HttpOverrides.global` KULLANILMAZ — o, dosya
/// yükleme (depolama sağlayıcısının farklı sertifikası) dahil
/// uygulamadaki BÜTÜN bağlantıları API pinlerine bağlar ve kırardı.
///
/// Pin verilmemişse (sabitleme kapalı) [f] olduğu gibi çalışır.
T sabitliBolgede<T>(T Function() f) {
  if (!SertifikaSabitleme.etkin) {
    return f();
  }
  return HttpOverrides.runZoned<T>(
    f,
    createHttpClient: (_) => SertifikaSabitleme.istemci(),
  );
}
