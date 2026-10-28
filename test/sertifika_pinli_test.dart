// SERTİFİKA SABİTLEME — PİNLİ YOL (29 Eki, güvenlik düzeltme planı)
//
// Pin listesi derleme zamanında sabitlenir (`CERT_PINS`); normal
// `flutter test` koşusunda pin YOKTUR ve bu dosyadaki testler ATLANIR.
// CI'da ayrı bir adım geçici test sertifikaları üretip (anahtar depoya
// işlenmez) bu dosyayı şu tanımlarla çalıştırır:
//   CERT_PINS        = dogru + suresi_dolmus sertifikalarının SPKI pinleri
//   API_BASE_URL     = https://localhost/api/v1   (izinli ad: localhost)
//   PIN_TEST_DIZINI  = sertifikaların bulunduğu geçici dizin
// Bkz. .github/scripts/pin_test_sertifikalari.py ve flutter-ci.yml.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/sabitlemeli_istemci_io.dart';
import 'package:hizmetcep/data/remote/sertifika_sabitleme.dart';

const String _dizin = String.fromEnvironment('PIN_TEST_DIZINI');

/// `ad` sertifikasıyla yerel HTTPS + WebSocket sunucusu.
Future<HttpServer> _sunucu(String ad) async {
  final baglam = SecurityContext()
    ..useCertificateChain('$_dizin/$ad.pem')
    ..usePrivateKey('$_dizin/$ad.key');
  final s = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, baglam);
  s.listen((istek) async {
    if (WebSocketTransformer.isUpgradeRequest(istek)) {
      final ws = await WebSocketTransformer.upgrade(istek);
      ws.add('merhaba');
      await ws.close();
      return;
    }
    istek.response.write('tamam');
    await istek.response.close();
  });
  return s;
}

Future<String> _getir(HttpClient c, String adres) async {
  final yanit = await (await c.getUrl(Uri.parse(adres))).close();
  return utf8.decodeStream(yanit);
}

void main() {
  final atla = !SertifikaSabitleme.etkin || _dizin.isEmpty
      ? 'CERT_PINS / PIN_TEST_DIZINI verilmedi (yalnız CI pin adımında koşar)'
      : null;

  late HttpServer dogru;
  late HttpServer yabanci;
  late HttpServer dolmus;

  setUpAll(() async {
    if (atla != null) {
      return;
    }
    dogru = await _sunucu('dogru');
    yabanci = await _sunucu('yabanci');
    dolmus = await _sunucu('suresi_dolmus');
  });

  tearDownAll(() async {
    if (atla != null) {
      return;
    }
    await dogru.close(force: true);
    await yabanci.close(force: true);
    await dolmus.close(force: true);
  });

  test('doğru pin + izinli ad: bağlantı kurulur', () async {
    final c = SertifikaSabitleme.istemci();
    expect(await _getir(c, 'https://localhost:${dogru.port}/'), 'tamam');
    c.close(force: true);
  }, skip: atla);

  test('yanlış pin (pinlenmemiş anahtar): bağlantı reddedilir', () async {
    final c = SertifikaSabitleme.istemci();
    await expectLater(_getir(c, 'https://localhost:${yabanci.port}/'),
        throwsA(isA<TlsException>()));
    c.close(force: true);
  }, skip: atla);

  test('yanlış alan adı: pinli sertifika olsa da izinli olmayan ad reddedilir', () async {
    final c = SertifikaSabitleme.istemci();
    await expectLater(_getir(c, 'https://127.0.0.1:${dogru.port}/'),
        throwsA(isA<TlsException>()));
    c.close(force: true);
  }, skip: atla);

  test('süresi dolmuş sertifika: pini tutsa da reddedilir', () async {
    final c = SertifikaSabitleme.istemci();
    await expectLater(_getir(c, 'https://localhost:${dolmus.port}/'),
        throwsA(isA<TlsException>()));
    c.close(force: true);
  }, skip: atla);

  test('WebSocket: sabitleme bölgesinde doğru pinle bağlanır, döngü yok', () async {
    final ws = await sabitliBolgede(
        () => WebSocket.connect('wss://localhost:${dogru.port}/'));
    expect(await ws.first, 'merhaba');
    await ws.close();
  }, skip: atla);

  test('WebSocket: pinlenmemiş sunucuya bağlanamaz', () async {
    await expectLater(
        sabitliBolgede(() => WebSocket.connect('wss://localhost:${yabanci.port}/')),
        throwsA(isA<Exception>()));
  }, skip: atla);

  test('pinli istemci üretimi: üretici bir kez, boş güven deposuyla çağrılır', () {
    final baglamlar = <SecurityContext?>[];
    final c = SertifikaSabitleme.istemci((ctx) {
      baglamlar.add(ctx);
      return HttpClient(context: ctx);
    });
    expect(baglamlar.length, 1);
    expect(baglamlar.single, isNotNull,
        reason: 'pinli yolda sistem kökleri kapalı özel bağlam verilmeli');
    c.close(force: true);
  }, skip: atla);
}
