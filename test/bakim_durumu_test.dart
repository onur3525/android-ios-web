// BAKIM DURUMU (22 Eki): uygulama açıkken bakım izlenir; bakım ekranı
// bütün ekranları örter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/bakim_durumu.dart';
import 'package:hizmetcep/core/cihaz_kimligi.dart';
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

  test('032: cihaz kimliği rastgele, kalıba uygun; kişisel bilgi içermez', () {
    final a = CihazKimligi.uret();
    final b = CihazKimligi.uret();
    expect(a.length, 43);
    expect(CihazKimligi.gecerliMi(a), isTrue);
    expect(a, isNot(b));
    expect(CihazKimligi.gecerliMi('kisa'), isFalse);
    expect(CihazKimligi.gecerliMi(null), isFalse);
  });

  test('032: listedeki hesap (bypass) için bakım ekranı yok', () {
    expect(bakimEtkinMi({'active': true}), isTrue);
    expect(bakimEtkinMi({'active': true, 'bypass': true}), isFalse);
    expect(bakimEtkinMi({'active': false}), isFalse);
    expect(bakimEtkinMi(null), isFalse);
    final d = BakimDurumu.i;
    d.uygula({'active': true, 'message': 'x', 'bypass': true});
    expect(d.aktif, isFalse);
    d.uygula({'active': true, 'message': 'x'});
    expect(d.aktif, isTrue);
  });

  testWidgets('032: gizli giriş kapısı logoya 2 sn basılı tutunca açılır', (t) async {
    var acildi = 0;
    await t.pumpWidget(MaterialApp(
      home: BakimEkrani(onYenile: () {}, onGiris: () => acildi++),
    ));
    final kapi = find.byKey(const ValueKey('bakim-giris-kapisi'));
    expect(kapi, findsOneWidget);
    var g = await t.startGesture(t.getCenter(kapi));
    await t.pump(const Duration(seconds: 1));
    await g.up();
    await t.pump();
    expect(acildi, 0, reason: 'kısa basış kapıyı açmaz');
    g = await t.startGesture(t.getCenter(kapi));
    await t.pump(kBakimGirisSuresi + const Duration(milliseconds: 100));
    await g.up();
    await t.pump();
    expect(acildi, 1);
  });

  testWidgets('032: kapı YALNIZ tanınmış test cihazında; giriş açıkken örtü kalkar', (t) async {
    final kapi = find.byKey(const ValueKey('bakim-giris-kapisi'));
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => BakimKapisi(child: child!),
      home: const Scaffold(body: Text('ana ekran')),
    ));
    BakimDurumu.i.uygula({'active': true, 'message': 'Bakım'});
    await t.pump();
    expect(find.text('Bakımdayız'), findsOneWidget);
    expect(kapi, findsNothing, reason: 'tanınmamış cihazda kapı yok');
    expect(BakimDurumu.i.testCihazi, isFalse);
    BakimDurumu.i.uygula({'active': true, 'message': 'Bakım', 'testerDevice': true});
    await t.pump();
    expect(BakimDurumu.i.testCihazi, isTrue);
    expect(kapi, findsOneWidget);
    BakimDurumu.i.girisAc();
    await t.pump();
    expect(find.text('Bakımdayız'), findsNothing);
    await t.pumpWidget(MaterialApp(home: BakimEkrani(onYenile: () {})));
    expect(find.byKey(const ValueKey('bakim-giris-kapisi')), findsNothing);
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
