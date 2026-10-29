// WEBSOCKET SABİTLEME BÖLGESİ (29 Eki, güvenlik incelemesi): bölge içinde
// `HttpClient()` üretimi kendini yeniden çağırmamalı. Eski kurulum
// (`runZoned(createHttpClient: (_) => SertifikaSabitleme.istemci())`)
// pin verilmiş sürümde WebSocket'i yığın taşmasıyla düşürürdü.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/sabitlemeli_istemci_io.dart';
import 'package:hizmetcep/data/remote/sertifika_sabitleme.dart';

void main() {
  test('eski kurulum kendini yeniden çağırır (hatanın kanıtı)', () {
    expect(
      () => HttpOverrides.runZoned(
        () => HttpClient(),
        createHttpClient: (_) => SertifikaSabitleme.istemci(),
      ),
      throwsA(isA<StackOverflowError>()),
    );
  });

  test('yeni bölge istemciyi döngüsüz üretir (WebSocket.connect yolu)', () {
    final c = HttpOverrides.runWithHttpOverrides(() => HttpClient(), SabitliHttpOverrides());
    expect(c, isA<HttpClient>());
    c.close(force: true);
  });

  test('istemci üretimi verilen üreticiyi kullanır', () {
    var cagri = 0;
    final c = SertifikaSabitleme.istemci((ctx) {
      cagri++;
      return HttpClient(context: ctx);
    });
    expect(cagri, 1, reason: 'tek istemci üretilmeli (boşa nesne yok)');
    c.close(force: true);
  });
}
