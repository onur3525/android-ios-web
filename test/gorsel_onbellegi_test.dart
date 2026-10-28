// KALICI FOTOĞRAF ÖNBELLEĞİ (28 Eki): bir kez indirilen fotoğraf telefonda
// saklanır; uygulama yeniden açılınca internetten değil önbellekten gelir.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/platform/kalici_gorsel_io.dart';
import 'package:http/http.dart' as http;

String _kod(String yol) => File(yol).readAsStringSync();

void main() {
  late Directory klasor;
  late List<Uri> indirilen;
  late int durum;
  late Uint8List icerik;

  setUp(() async {
    klasor = await Directory.systemTemp.createTemp('hc_onbellek_test');
    indirilen = [];
    durum = 200;
    icerik = Uint8List.fromList(List<int>.generate(64, (i) => i));
    GorselOnbellegi.testSifirla();
    GorselOnbellegi.testKlasoru = klasor;
    GorselOnbellegi.testIndir = (adres) async {
      indirilen.add(adres);
      return http.Response.bytes(icerik, durum);
    };
  });

  tearDown(() async {
    GorselOnbellegi.testKlasoru = null;
    GorselOnbellegi.testIndir = null;
    GorselOnbellegi.testSifirla();
    if (await klasor.exists()) {
      await klasor.delete(recursive: true);
    }
  });

  test('ilk istekte indirir, sonra önbellekten verir (yeniden açılış dahil)', () async {
    const url = 'https://api.ornek.com/api/v1/categories/photo/katalog/kategori/a.jpg';
    expect(await GorselOnbellegi.getir(url), icerik);
    expect(indirilen.length, 1);
    // "Uygulama yeniden açıldı": bellek sıfırlanır, dosya durur.
    GorselOnbellegi.testSifirla();
    GorselOnbellegi.testKlasoru = klasor;
    expect(await GorselOnbellegi.getir(url), icerik);
    expect(indirilen.length, 1, 'ikinci açılışta internetten indirilmemeli');
  });

  test('yeniden imzalanan adres (sorgu farklı) aynı fotoğraf sayılır', () async {
    const yol = 'https://hc.r2.ornek.com/u/kisi/foto.jpg';
    await GorselOnbellegi.getir('$yol?X-Amz-Signature=aaa&X-Amz-Date=1');
    await GorselOnbellegi.getir('$yol?X-Amz-Signature=bbb&X-Amz-Date=2');
    expect(indirilen.length, 1);
    expect(gorselOnbellekAnahtari('$yol?x=1'), yol);
    expect(
        const KaliciAgGorseli('$yol?a=1') == const KaliciAgGorseli('$yol?b=2'), isTrue,
        reason: 'bellekteki çözülmüş görsel de paylaşılır');
  });

  test('farklı fotoğraf (yeni yükleme = yeni ad) ayrı indirilir', () async {
    await GorselOnbellegi.getir('https://api.ornek.com/p/eski.jpg');
    await GorselOnbellegi.getir('https://api.ornek.com/p/yeni.jpg');
    expect(indirilen.length, 2);
  });

  test('aynı fotoğrafı aynı anda isteyenler TEK indirmeyi bekler', () async {
    const url = 'https://api.ornek.com/p/esz.jpg';
    final sonuclar = await Future.wait(List.generate(5, (_) => GorselOnbellegi.getir(url)));
    expect(indirilen.length, 1);
    for (final s in sonuclar) {
      expect(s, icerik);
    }
  });

  test('başarısız indirme önbelleğe yazılmaz; sonra yeniden denenir', () async {
    const url = 'https://api.ornek.com/p/hata.jpg';
    durum = 404;
    await expectLater(GorselOnbellegi.getir(url), throwsA(isA<HttpException>()));
    expect(klasor.listSync().whereType<File>().where((f) => !f.path.endsWith('.yaziliyor')), isEmpty);
    durum = 200;
    expect(await GorselOnbellegi.getir(url), icerik);
    expect(indirilen.length, 2);
  });

  test('süresi (30 gün) geçen dosya yeniden indirilir', () async {
    const url = 'https://api.ornek.com/p/eski_dosya.jpg';
    await GorselOnbellegi.getir(url);
    for (final f in klasor.listSync().whereType<File>()) {
      f.setLastModifiedSync(DateTime.now().subtract(kOnbellekSuresi + const Duration(hours: 1)));
    }
    GorselOnbellegi.testSifirla();
    GorselOnbellegi.testKlasoru = klasor;
    await GorselOnbellegi.getir(url);
    expect(indirilen.length, 2);
  });

  test('budama: süresi geçenler silinir; boyut sınırı aşılınca en eskiler gider', () async {
    final eski = File('${klasor.path}/eski')..writeAsBytesSync([1, 2, 3]);
    eski.setLastModifiedSync(DateTime.now().subtract(kOnbellekSuresi + const Duration(days: 1)));
    final yeni = File('${klasor.path}/yeni')..writeAsBytesSync([4, 5, 6]);
    await GorselOnbellegi.budaSimdi(klasor);
    expect(eski.existsSync(), isFalse);
    expect(yeni.existsSync(), isTrue);
    expect(kOnbellekAzamiBoyut, 200 * 1024 * 1024);
  });

  group('kod', () {
    test('ağ fotoğrafları tek ortak bileşenden (agGorseli) çizilir; web değişmez', () {
      for (final yol in [
        'lib/core/platform/yerel_gorsel_io.dart',
        'lib/screens/chat_screen.dart',
        'lib/screens/home_screen.dart',
      ]) {
        final k = _kod(yol);
        expect(k.contains('agGorseli('), isTrue, reason: yol);
        expect(k.contains('Image.network('), isFalse, reason: yol);
      }
      expect(_kod('lib/core/platform/kalici_gorsel_web.dart').contains('NetworkImage(url'), isTrue);
      expect(_kod('lib/core/platform/ag_gorseli.dart')
          .contains("import 'kalici_gorsel_io.dart' if (dart.library.html) 'kalici_gorsel_web.dart';"), isTrue);
    });
  });
}
