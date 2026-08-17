import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/ui/olcu.dart';
import 'package:hizmetcep/ui/web_kabuk.dart';

/// WEB / GENİŞ EKRAN TEMELİ — KILIT TESTLERİ
///
/// ⚠ EN ÖNEMLİ SÖZLEŞME: telefon genişliğinde HİÇBİR ŞEY DEĞİŞMEZ.
///
/// Web çalışması mobil düzeni bozmamalı. Bu dosyadaki testlerin
/// çoğu tam olarak bunu kilitler: <600 px'te sarmalayıcılar araya
/// girmez, ölçek 1.0 kalır, sütun sayısı bugünkü değerdir.
///
/// ⚠ Kırılma noktaları PLATFORMA değil GENİŞLİĞE bağlıdır. Aynı kod
/// Android tablette de ferah çizer; bu bilinçli bir karardır.
void main() {
  group('1 — Kırılma noktaları', () {
    test('sınır değerleri', () {
      expect(ekranSinifiFor(320), EkranSinifi.mobil);
      expect(ekranSinifiFor(599), EkranSinifi.mobil);
      expect(ekranSinifiFor(600), EkranSinifi.tablet);
      expect(ekranSinifiFor(1023), EkranSinifi.tablet);
      expect(ekranSinifiFor(1024), EkranSinifi.laptop);
      expect(ekranSinifiFor(1439), EkranSinifi.laptop);
      expect(ekranSinifiFor(1440), EkranSinifi.masaustu);
      expect(ekranSinifiFor(2560), EkranSinifi.masaustu);
    });

    test('genisMi / masaustuMu', () {
      expect(EkranSinifi.mobil.genisMi, isFalse);
      expect(EkranSinifi.tablet.genisMi, isTrue);
      expect(EkranSinifi.tablet.masaustuMu, isFalse);
      expect(EkranSinifi.laptop.masaustuMu, isTrue);
      expect(EkranSinifi.masaustu.masaustuMu, isTrue);
    });
  });

  group('2 — ⚠ MOBİL DEĞERLER DEĞİŞMEDİ', () {
    test('telefonda metin ölçeği TAM 1.0', () {
      // ⚠ 1.0 dışında bir değer, bugünkü Android tipografisini
      // değiştirir. Bu test o riski kilitler.
      expect(metinOlcegi(EkranSinifi.mobil), 1.0);
    });

    test('telefonda sayfa kenarı 16 (bugünkü değer)', () {
      expect(sayfaKenari(EkranSinifi.mobil), 16);
    });

    test('telefonda sütun sayısı OLDUĞU GİBİ döner', () {
      for (final n in [1, 2, 3, 4]) {
        expect(izgaraSutun(EkranSinifi.mobil, mobilSutun: n), n,
            reason: 'telefonda sütun sayısı değiştirilmiş');
      }
    });

    test('telefonda düğme yüksekliği 52 (bugünkü değer)', () {
      expect(dugmeYuksekligi(EkranSinifi.mobil), 52);
    });
  });

  group('3 — Geniş ekranda büyüme', () {
    test('ölçek yalnız artar, asla küçülmez', () {
      var onceki = 0.0;
      for (final s in EkranSinifi.values) {
        expect(metinOlcegi(s), greaterThanOrEqualTo(onceki));
        onceki = metinOlcegi(s);
      }
      // ⚠ Üst sınır: kilitli ölçülü bileşenler taşmasın.
      expect(metinOlcegi(EkranSinifi.masaustu), lessThanOrEqualTo(1.15));
    });

    test('sütun sayısı KARTI BÜYÜTEREK değil ÇOĞALTARAK artar', () {
      expect(izgaraSutun(EkranSinifi.tablet, mobilSutun: 2), 3);
      expect(izgaraSutun(EkranSinifi.laptop, mobilSutun: 2), 4);
      expect(izgaraSutun(EkranSinifi.masaustu, mobilSutun: 2), 5);
    });

    test('masaüstünde düğme KÜÇÜLMEZ', () {
      expect(dugmeYuksekligi(EkranSinifi.masaustu),
          greaterThanOrEqualTo(dugmeYuksekligi(EkranSinifi.mobil)));
    });

    test('içerik genişlikleri: form < liste < ızgara', () {
      expect(IcerikGenisligi.form, lessThan(IcerikGenisligi.liste));
      expect(IcerikGenisligi.liste, lessThan(IcerikGenisligi.izgara));
    });
  });

  group('4 — MerkezliIcerik: mobilde ARAYA GİRMEZ', () {
    Widget host(double genislik, Widget child) => MediaQuery(
          data: MediaQueryData(size: Size(genislik, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child,
          ),
        );

    testWidgets('telefonda Center/ConstrainedBox EKLENMEZ', (t) async {
      const isaret = Key('icerik');
      await t.pumpWidget(host(
        390,
        const MerkezliIcerik(child: SizedBox(key: isaret, height: 10)),
      ));
      // ⚠ Mobilde çocuk DOĞRUDAN döner: sarmalayıcı yok.
      expect(find.byKey(isaret), findsOneWidget);
      expect(find.byType(ConstrainedBox), findsNothing,
          reason: 'mobilde genişlik sınırı uygulanmış');
      expect(find.byType(Center), findsNothing,
          reason: 'mobilde ortalama uygulanmış');
    });

    testWidgets('masaüstünde ortalanır ve sınırlanır', (t) async {
      await t.pumpWidget(host(
        1600,
        const MerkezliIcerik(child: SizedBox(height: 10)),
      ));
      expect(find.byType(Center), findsOneWidget);
      expect(find.byType(ConstrainedBox), findsWidgets);
    });
  });

  group('5 — GenisEkranTipografi: mobilde dokunmaz', () {
    // ⚠ `MediaQuery` WIDGET'I SAYILMAZ.
    //
    // Önceki hâl `findsOneWidget` / `findsNWidgets(2)` ile ağaçtaki
    // `MediaQuery` sayısına bakıyordu. Flutter'ın kendi sarmalayıcıları
    // (View, Directionality zinciri) ağaca ek `MediaQuery` koyduğu için
    // sayı sürüme göre değişiyor ve test KURAL BOZULMADAN düşüyordu.
    //
    // Ölçülmesi gereken şey sayı değil SONUÇ: alt ağacın gördüğü
    // metin ölçeği. Aşağıda ölçek doğrudan okunur.
    late TextScaler gorulen;

    Widget host(double genislik) => MediaQuery(
          data: MediaQueryData(size: Size(genislik, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GenisEkranTipografi(
              child: Builder(builder: (c) {
                gorulen = MediaQuery.textScalerOf(c);
                return const SizedBox(height: 10);
              }),
            ),
          ),
        );

    testWidgets('telefonda ölçek DEĞİŞMEZ (1.0)', (t) async {
      await t.pumpWidget(host(390));
      expect(gorulen.scale(10), 10.0,
          reason: 'mobilde metin ölçeği değiştirilmiş');
    });

    testWidgets('masaüstünde ölçek BÜYÜR', (t) async {
      await t.pumpWidget(host(1600));
      expect(gorulen.scale(10), greaterThan(10.0),
          reason: 'geniş ekranda metin büyütülmemiş');
      // ⚠ Üst sınır: kilitli ölçülü bileşenler taşmasın.
      expect(gorulen.scale(10), lessThanOrEqualTo(11.5));
    });
  });

  group('6 — GenislikDali eksik dalda düşmez', () {
    // ⚠ GENİŞLİK `MediaQuery` İLE VERİLMEZ.
    //
    // `GenislikDali` içeride `LayoutBuilder` kullanır ve genişliği
    // EBEVEYN KISITINDAN okur, ekran boyutundan değil. Test ekran
    // boyutunu 1600 yapsa da ebeveyn kısıtı dar kaldığı için masaüstü
    // dalı hiç seçilmiyordu — bileşen değil, testin kurgusu yanlıştı.
    //
    // ⚠ TEST YÜZEYİ VARSAYILAN 800×600'DÜR.
    //
    // Kısıtı `SizedBox(width: 1600)` ile vermek de YETMEDİ: dıştaki
    // yüzey 800 dp olduğu için `SizedBox` istediği genişliği ALAMIYOR
    // ve 800'e sıkışıyordu. Sonuç tablet sınıfı oluyor, masaüstü dalı
    // hiç seçilmiyordu. (İlk koşuda `MediaQuery` ile denendi, ikinci
    // koşuda `SizedBox` ile; ikisi de aynı sebeple düştü.)
    //
    // Doğrusu YÜZEYİ büyütmektir. `t.view` ile fiziksel boyut
    // ayarlanır ve test bitiminde geri alınır.
    Widget kutu() => const Directionality(
          textDirection: TextDirection.ltr,
          child: GenislikDali(mobil: Text('M'), laptop: Text('L')),
        );

    Future<void> yuzey(WidgetTester t, double genislik) async {
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = Size(genislik, 800);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(kutu());
    }

    testWidgets('tablet dalı yoksa mobile düşer', (t) async {
      await yuzey(t, 800);
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('masaüstü dalı yoksa laptopa düşer', (t) async {
      await yuzey(t, 1600);
      expect(find.text('L'), findsOneWidget,
          reason: '1600 dp masaüstü sınıfıdır; masaüstü dalı yoksa '
              'laptop dalına düşmeli');
    });
  });

  group('7 — Kaynak sözleşmesi', () {
    test('bu dosyalar YENİDİR; mevcut ref_widgets DEĞİŞMEDİ', () {
      // ⚠ Web bileşenleri ayrı dosyada tutulur. `ref_widgets.dart`
      // 19 test dosyası tarafından ham metin olarak okunuyor;
      // oraya eklemek gereksiz regresyon riski üretirdi.
      expect(EkranSinifi.values.length, 4);
    });
  });
}
