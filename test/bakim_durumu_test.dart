// BAKIM DURUMU (22 Eki): uygulama açıkken bakım izlenir; bakım ekranı
// bütün ekranları örter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/bakim_durumu.dart';
import 'package:hizmetcep/ui/bakim_ekrani.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => BakimDurumu.i.sifirla());

  test('maintenance nesnesi uygulanır; bitince bekleyen iş bir kez çalışır', () {
    final d = BakimDurumu.i;
    var bitti = 0;
    d.uygula({'active': true, 'message': 'Planlı bakım', 'endAt': '2026-10-23T03:00:00.000Z'});
    expect(d.aktif, isTrue);
    expect(d.mesaj, 'Planlı bakım');
    d.bitinceCalistir(() => bitti++);
    d.uygula({'active': false});
    expect(d.aktif, isFalse);
    expect(bitti, 1);
    d.uygula({'active': true, 'message': 'x'});
    d.uygula({'active': false});
    expect(bitti, 1, reason: 'iş yalnız bir kez');
  });

  test('sorgu hatası bakım durumunu değiştirmez', () async {
    final d = BakimDurumu.i;
    d.uygula({'active': true, 'message': 'Bakım'});
    d.baslat(() async => throw Exception('ağ yok'));
    await d.kontrolEt();
    expect(d.aktif, isTrue);
    d.baslat(() async => {'maintenance': {'active': false}});
    await d.kontrolEt();
    expect(d.aktif, isFalse);
  });

  test('bitiş metni yerel saatle gg.aa.yyyy ss:dd; bozuk değer null', () {
    expect(bakimBitisMetni(null), isNull);
    expect(bakimBitisMetni('bozuk'), isNull);
    final t = DateTime.utc(2026, 10, 23, 3).toLocal();
    String iki(int n) => n.toString().padLeft(2, '0');
    expect(bakimBitisMetni('2026-10-23T03:00:00.000Z'),
        '${iki(t.day)}.${iki(t.month)}.${t.year} ${iki(t.hour)}:${iki(t.minute)}');
  });

  testWidgets('BakimKapisi: bakım açıkken ekran örtülür, kapanınca kalkar', (t) async {
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => BakimKapisi(child: child!),
      home: const Scaffold(body: Text('ana ekran')),
    ));
    expect(find.text('Bakımdayız'), findsNothing);
    BakimDurumu.i.uygula({'active': true, 'message': 'Planlı bakım çalışması'});
    await t.pump();
    expect(find.text('Bakımdayız'), findsOneWidget);
    expect(find.text('Planlı bakım çalışması'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    BakimDurumu.i.uygula({'active': false});
    await t.pump();
    expect(find.text('Bakımdayız'), findsNothing);
    expect(find.text('ana ekran'), findsOneWidget);
  });
}
