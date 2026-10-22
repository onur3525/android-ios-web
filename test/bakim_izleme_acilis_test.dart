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

  test('izleme açılış sorgusundan ÖNCE ve try dışında başlatılır', () {
    final baslat = k.indexOf('BakimDurumu.i\n          .baslat(');
    final sorgu = k.indexOf("BootLog.olay('CONFIG_CHECK_START')");
    expect(baslat, greaterThan(-1), reason: 'izleme başlatılmıyor');
    expect(sorgu, greaterThan(baslat), reason: 'izleme sorgudan sonra');
    final tryBas = k.lastIndexOf('try {', sorgu);
    expect(tryBas, greaterThan(baslat), reason: 'izleme try içinde kalmış');
  });

  test('açılış sorgusu başarısızsa bakım durumu arka planda yeniden sorulur', () {
    final hata = k.indexOf("BootLog.olay('CONFIG_CHECK_END', 'fail:");
    expect(hata, greaterThan(-1));
    final blokSonu = k.indexOf('\n      }', hata);
    expect(k.substring(hata, blokSonu).contains('unawaited(BakimDurumu.i.kontrolEt());'),
        isTrue);
  });
}
