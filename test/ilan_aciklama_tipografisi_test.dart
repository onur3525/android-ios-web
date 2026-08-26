import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// İLAN AÇIKLAMASI TİPOGRAFİSİ — TEK STANDART
///
/// ⚠ SORUN: aynı içerik (ilanın açıklaması) dört ekranda üç farklı
/// ölçüde ve hepsinde Poppins Regular ile çiziliyordu:
///   • ilan detayı  11,5px w400 #5B6472
///   • iş detayı    12,8px w400 #3A4658
///   • İlanlarım    12,0px w400 #5B6472
///   • Uygun İşler  12,0px w400 (ham `TextStyle`, tasarım sistemi dışı)
/// Küçük punto + en ince ağırlık + gri renk üst üste gelince metin
/// cihazda okunmuyordu.
///
/// ⚠ STANDART:
///   • DETAY ekranları → 13,5 / w500 / RC.text     / 1,55
///   • KART  ekranları → 12,5 / w500 / RC.textSoft / 1,45
///
/// ⚠ AĞIRLIK NEDEN w500: `pubspec.yaml` yalnız Poppins 400/500/700
/// taşır. w600 istenirse Flutter gerçek dosya bulamaz ve sentezler;
/// Poppins'te sentez bulanık basar. w700 ise açıklamayı başlıkla
/// yarıştırır. Bu yüzden w600 BU DÖRT YERDE YASAKTIR.
///
/// ⚠ BU DEĞERLER HTML SÖZLEŞMESİNDEN BİLİNÇLİ SAPMADIR
/// (`.ld-desc` 11,5px · `.pl-desc` 12,8px · `.cc-desc` 12px). Ürün
/// kararıdır; referans HTML diğer her şey için geçerli olmaya devam
/// eder. Bu test sapmanın kaza değil karar olduğunu kayda geçirir.
String _oku(String p) => File(p).readAsStringSync();

/// Açıklamanın çizildiği yerden itibaren stil bloğunu verir.
///
/// ⚠ Pencere BENZERSİZ bir işaretle açılır: dört dosyanın her birinde
/// açıklama alanı yalnız BİR kez geçer (test aşağıda bunu da
/// doğrular). Sabit uzunluk yerine dosya sonuna kırpılan pencere
/// kullanılır ki dosya kısalınca test kendi kendine patlamasın.
String _stilBlogu(String kaynak, String isaret) {
  final i = kaynak.indexOf(isaret);
  if (i < 0) {
    throw StateError('açıklama alanı bulunamadı: $isaret');
  }
  final son = (i + 420) > kaynak.length ? kaynak.length : i + 420;
  return kaynak.substring(i, son);
}

void main() {
  final detaylar = <String, String>{
    'lib/screens/listing_detail_screen.dart': 'l.desc',
    'lib/screens/job_detail_screen.dart': 'l.desc',
    // ⚠ ÖNİZLEME DE İLAN SAYFASIDIR — ilk turda ATLANMIŞTI.
    // Kullanıcı "ilanlar sayfalarının TÜMÜ" demişti; Önizle & Yayınla
    // adımı 13/w400/soluk gri kalmıştı ve yayınlanan ilandan farklı
    // görünüyordu.
    'lib/screens/create_listing_screen.dart': 'Text(_desc.text.trim()',
  };
  final kartlar = <String, String>{
    'lib/screens/my_listings_screen.dart': 'listing.desc',
    'lib/screens/jobs_screen.dart': 'l.desc',
  };

  group('0 — Pencere güvenliği', () {
    test('açıklama alanı her dosyada TEK kez geçer', () {
      for (final e in {...detaylar, ...kartlar}.entries) {
        final adet = RegExp(RegExp.escape(e.value))
            .allMatches(_oku(e.key))
            .length;
        expect(adet, 1,
            reason: '${e.key}: "${e.value}" birden fazla yerde geçiyor, '
                'pencere yanlış bloğa kayabilir');
      }
    });
  });

  group('1 — Detay ekranları: 13,5 / w500 / koyu', () {
    for (final e in detaylar.entries) {
      test(e.key, () {
        final blok = _stilBlogu(_oku(e.key), e.value);
        expect(blok.contains('RF.s135'), isTrue,
            reason: 'detay açıklaması 13,5px olmalı');
        expect(blok.contains('RF.w500'), isTrue,
            reason: 'Poppins Medium — Regular okunmuyordu');
        expect(blok.contains('color: RC.text,'), isTrue,
            reason: 'açıklama ilanın asıl içeriği, soluk gri değil '
                '(RC.textSoft ile karışmasın diye tam eşleşme aranır)');
        expect(blok.contains('RF.lh155'), isTrue);
      });
    }
  });

  group('2 — Kart ekranları: 12,5 / w500', () {
    for (final e in kartlar.entries) {
      test(e.key, () {
        final blok = _stilBlogu(_oku(e.key), e.value);
        expect(blok.contains('RF.s125'), isTrue,
            reason: 'kart açıklaması 12,5px olmalı');
        expect(blok.contains('RF.w500'), isTrue);
        expect(blok.contains('maxLines: 2'), isTrue,
            reason: 'kartta iki satır sınırı KORUNUR');
        expect(blok.contains('RC.textSoft'), isTrue,
            reason: 'kartta açıklama gri kalır — başlık önde olmalı');
      });
    }
  });

  group('3 — Yasaklar', () {
    test('açıklamada w400 ve w600 KULLANILMAZ', () {
      for (final e in {...detaylar, ...kartlar}.entries) {
        final blok = _stilBlogu(_oku(e.key), e.value);
        expect(blok.contains('RF.w400'), isFalse,
            reason: '${e.key}: en ince ağırlık okunmuyordu');
        expect(blok.contains('RF.w600'), isFalse,
            reason: '${e.key}: pubspec\'te 600 yok, Flutter sentezler '
                've bulanık basar');
      }
    });

    test('Uygun İşler kartı ham TextStyle kullanmaz', () {
      final blok = _stilBlogu(_oku('lib/screens/jobs_screen.dart'), 'l.desc');
      expect(blok.contains('refText('), isTrue,
          reason: 'tasarım sistemi tek yerde atlanıyordu');
      expect(blok.contains('fontSize:'), isFalse);
    });
  });

  group('4 — Korunan davranış', () {
    test('okunmuş/okunmamış ayrımı sürüyor', () {
      final blok = _stilBlogu(_oku('lib/screens/jobs_screen.dart'), 'l.desc');
      expect(blok.contains('incelendi ?'), isTrue,
          reason: 'okunmuş ilanın açıklaması solgunlaşmaya devam eder');
    });
  });

  group('5 — Font dosyası gerçekten var mı', () {
    test('Poppins Medium pubspec\'te tanımlı', () {
      final p = _oku('pubspec.yaml');
      expect(p.contains('Poppins-Medium.ttf'), isTrue,
          reason: 'w500 gerçek bir dosyaya karşılık gelmeli; '
              'yoksa standart sentezlenmiş yazıya döner');
      expect(File('assets/fonts/Poppins-Medium.ttf').existsSync(), isTrue,
          reason: 'font dosyası diskte yok');
    });
  });
}
