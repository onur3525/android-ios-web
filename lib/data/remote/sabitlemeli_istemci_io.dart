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
///
/// ── ⚠ SONSUZ DÖNGÜ DÜZELTİLDİ (29 Eki, güvenlik incelemesi) ──
/// Önceden `HttpOverrides.runZoned(createHttpClient: (_) =>
/// SertifikaSabitleme.istemci())` kullanılıyordu. `istemci()` içindeki
/// `HttpClient(...)` çağrısı AYNI bölgede çalıştığı için yine bu geri
/// çağrıya düşüyordu (Dart SDK `_HttpOverridesScope.createHttpClient`):
/// pin verilmiş HER sürümde WebSocket bağlantısı yığın taşmasıyla
/// kurulamazdı (pin verilmiş sürüm henüz çıkmadığı için görülmedi).
/// Artık istemci, bölgeyi YENİDEN ÇAĞIRMAYAN temel üretimle
/// (`HttpOverrides.createHttpClient` = SDK'nın kendi istemcisi) kurulur;
/// pin + ad + süre denetimi aynen `SertifikaSabitleme.istemci` içinde.
T sabitliBolgede<T>(T Function() f) {
  if (!SertifikaSabitleme.etkin) {
    return f();
  }
  return HttpOverrides.runWithHttpOverrides<T>(f, SabitliHttpOverrides());
}

/// WebSocket bölgesinin `HttpClient` üretimi: SDK'nın temel üretimi +
/// sabitleme kuralları (tek kaynak: `SertifikaSabitleme.istemci`).
class SabitliHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      SertifikaSabitleme.istemci(super.createHttpClient);
}
