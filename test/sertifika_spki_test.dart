import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/sertifika_sabitleme.dart';

/// SERTİFİKA SABİTLEME — SPKI + AD + SÜRE (güvenlik turu 2 · M-03)
///
/// Örnek sertifika: `api.hizmetcep.com` adına üretilmiş, kendinden
/// imzalı P-256 (EC) test sertifikası. Beklenen SPKI özeti Python
/// `cryptography` kütüphanesiyle BAĞIMSIZ olarak hesaplandı:
///   sha256(SubjectPublicKeyInfo DER) → base64
/// Aynı algoritma 150 sistem kök sertifikasında da denendi.
const String _ornekDer = 'MIIBSDCB76ADAgECAgMS1ocwCgYIKoZIzj0EAwIwHDEaMBgGA1UEAwwRYXBpLmhpem1ldGNlcC5jb20wHhcNMjYwMTAxMDAwMDAwWhcNMzYwMTAxMDAwMDAwWjAcMRowGAYDVQQDDBFhcGkuaGl6bWV0Y2VwLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABIgNXf+Wq4k/GvkFNHfZP2CW52jSkeqx0BCMyRt3krPxaQnibIKDwsN1gBxmp/mw8eU38LCoKX93sLzdKpohhzejIDAeMBwGA1UdEQQVMBOCEWFwaS5oaXptZXRjZXAuY29tMAoGCCqGSM49BAMCA0gAMEUCIQCn/6daZWUPH+OZ1JEfzwJbXqvY/UWkefH9zYZtH/Kw9AIgaaRqP15YJkKRUMGiolUs6mcvN48YJGCwemFhnYXXeSY=';
const String _beklenenSpki = 'uoJrG8a01ZPTi2ASFrNhPOdj09VRXQLrNFBryCPHKz8=';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final der = Uint8List.fromList(base64.decode(_ornekDer));

  test('SPKI özeti bağımsız hesapla birebir aynı', () {
    expect(SertifikaSabitleme.spkiOzetDer(der), _beklenenSpki);
  });

  test('bozuk / kesik DER reddedilir (null)', () {
    expect(SertifikaSabitleme.spkiDer(Uint8List(0)), isNull);
    expect(SertifikaSabitleme.spkiDer(Uint8List.fromList([0x30, 0x82])), isNull);
    expect(SertifikaSabitleme.spkiDer(Uint8List.sublistView(der, 0, 40)),
        isNull);
    final bozuk = Uint8List.fromList(der)..[0] = 0x31;
    expect(SertifikaSabitleme.spkiDer(bozuk), isNull);
  });

  test('izinli olmayan ad reddedilir', () {
    expect(SertifikaSabitleme.hostIzinli('kotu.example.com'), isFalse);
  });

  test('geri çağrı: ad VE pin + süre birlikte', () {
    final k = _kod('lib/data/remote/sertifika_sabitleme.dart');
    expect(k.contains('final tamam = hostIzinli(host) && kabulEdilir(sertifika);'),
        isTrue);
    expect(k.contains('sertifika.endValidity'), isTrue);
    expect(k.contains('sertifika.startValidity'), isTrue);
    // Eski biçim pinler geriye dönük uyumluluk için hâlâ kabul edilir.
    expect(k.contains('return _tamPinler.contains(ozet(sertifika));'), isTrue);
  });

  test('WebSocket sabitlemeli bölgede kurulur', () {
    final w = _kod('lib/data/remote/ws_client.dart');
    expect(w.contains('sabitliBolgede(() {'), isTrue);
    final web = _kod('lib/data/remote/sabitlemeli_istemci_web.dart');
    expect(web.contains('T sabitliBolgede<T>(T Function() f) => f();'), isTrue,
        reason: 'web tarayıcı TLS modelini kullanır');
  });
}
