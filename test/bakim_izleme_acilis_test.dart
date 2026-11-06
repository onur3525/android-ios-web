// BAKIM İZLEMESİ AÇILIŞ SORGUSUNA BAĞLI DEĞİLDİR (22 Eki, hata düzeltmesi)
//
// Hata: izleme yalnız açılıştaki `/config/app` sorgusu kısa bütçede
// başarılı olursa kuruluyordu. Sunucu yavaş uyandığında izleme hiç
// kurulmuyor, bakım açılınca ne bakım ekranı çıkıyor ne de 503
// "MAINTENANCE" yanıtı ekranı açabiliyordu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final k = File('lib/screens/splash_screen.dart').readAsStringSync();

  // 6 Kas: izleme splash'ten ÇIKARILDI, `main.dart`ta her platform için tek
  // noktada kurulur (web splash'i atladığı için web'de hiç başlamıyordu).
  test('izleme main.dart\'ta, splash açılış sorgusundan BAĞIMSIZ kurulur', () {
    final m = File('lib/main.dart').readAsStringSync();
    final baslat = m.indexOf(
        'BakimDurumu.i.baslat(() => bakimApi.app(platform: currentPlatform()));');
    expect(baslat, greaterThan(-1), reason: 'izleme başlatılmıyor');
    // Web açılışındaki oturum isteklerinden ve runApp'ten ÖNCE.
    expect(m.indexOf('String? ilkRota;'), greaterThan(baslat));
    expect(m.indexOf("BootLog.olay('RUN_APP_CALL');"), greaterThan(baslat));
    // Web'de ilk soru hemen sorulur (splash yok).
    expect(m.substring(baslat, baslat + 200).contains(
        'if (kIsWeb) {\n      unawaited(BakimDurumu.i.kontrolEt());'), isTrue);
    // Splash ikinci bir izleme kurmaz; yalnız ilk değeri uygular.
    expect(k.contains('.baslat('), isFalse);
    expect(k.contains('BakimDurumu.i.uygula(m);'), isTrue);
  });

  test('açılış sorgusu başarısızsa bakım durumu arka planda yeniden sorulur', () {
    final hata = k.indexOf("BootLog.olay('CONFIG_CHECK_END', 'fail:");
    expect(hata, greaterThan(-1));
    final blokSonu = k.indexOf('\n      }', hata);
    expect(k.substring(hata, blokSonu).contains('unawaited(BakimDurumu.i.kontrolEt());'),
        isTrue);
  });
}
