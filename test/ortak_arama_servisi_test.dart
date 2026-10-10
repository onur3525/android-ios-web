// ORTAK ARAMA SERVİSİ — KESİN KURAL
//
// ⚠ TÜM hizmet/kategori aramaları `SearchService`'ten geçer.
// Ekranlar kendi süzgecini YAZMAZ.
//
// Somut kusur (14 Ağu): ilan oluşturma ekranı ve hizmet veren
// kategori paneli kendi `contains` süzgeçlerini kullanıyordu ve
// yalnız KATALOG ADLARINA bakıyordu. 1500 terimlik eş anlamlı
// sözlüğü ile alias katmanı o iki ekranda HİÇ çalışmıyordu:
// kullanıcı "ocak" yazınca "Sonuç bulunamadı" görüyordu.
//
// ⚠ İKİNCİ KURAL: hizmetin hangi kategoriye bağlı olduğu
// KULLANICIYA GÖSTERİLMEZ. "Ana > Alt" kırılımı çizilmez; kategori
// arka planda taşınmaya devam eder.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/services/search_service.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

/// Hizmet/kategori araması yapan TÜM ekranlar.
/// ⚠ `home_screen` LİSTEDE DEĞİL: kendi araması yok, aramayı
/// `InlineSearchBox` bileşenine devrediyor (o da listede).
const _aramaEkranlari = [
  'lib/screens/create_listing_screen.dart',
  'lib/screens/widgets/inline_search_box.dart',
  'lib/screens/widgets/kategori_secim_paneli.dart',
];

void main() {
  group('1 — ORTAK SERVİS ZORUNLU', () {
    test('arama yapan her ekran SearchService kullanır', () {
      final eksik = <String>[];
      for (final f in _aramaEkranlari) {
        if (!_kod(f).contains('SearchService')) {
          eksik.add(f);
        }
      }
      expect(eksik, isEmpty, reason: 'kendi süzgecini yazan ekran: $eksik');
    });

    test('hiçbir arama ekranı KENDİ süzgecini yazmaz', () {
      // Katalog üzerinde elle dolaşıp `contains` ile süzmek yasak.
      final suclu = <String>[];
      for (final f in _aramaEkranlari) {
        final k = _kod(f);
        if (k.contains('turkceNormalize') && k.contains('kCategoryTree')) {
          suclu.add(f);
        }
      }
      expect(suclu, isEmpty, reason: 'yerel süzgeç geri gelmiş: $suclu');
    });

    test('panel kendi Türkçe normalleştirmesini taşımaz', () {
      final p = _kod('lib/screens/widgets/kategori_secim_paneli.dart');
      expect(p.contains('String _norm(String s)'), isFalse);
      expect(p.contains('SearchService.services('), isTrue);
    });
  });

  group('2 — KATEGORİ KIRILIMI GÖSTERİLMEZ', () {
    test('ilan formunda "Ana > Alt" satırı YOK', () {
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect(c.contains(r"'${liste[i].kategori} > ${liste[i].alt}'"), isFalse,
          reason: 'kırılım geri gelmiş');
      // ⚠ Kod içinde kırılım ÜRETEN bir ifade kalmamalı.
      expect(c.contains('kategori} > '), isFalse,
          reason: 'kırılım biçimi kalmış');
    });

    test('öneri satırı label gösterir', () {
      // `label` alias adını gösterir; seçime giden değer yine katalog
      // kimliğidir.
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect(c.contains('Text(liste[i].label,'), isTrue);
      expect(c.contains('onSecim(liste[i].category, liste[i].subService)'),
          isTrue);
    });
  });

  group('3 — SÖZLÜK ARTIK İLAN EKRANINDA ÇALIŞIYOR', () {
    test('"ocak" sonuç döndürür', () {
      // Katalogda "ocak" geçen bir ad YOK; sonuç yalnız eş anlamlı
      // sözlüğünden gelebilir. Eski yerel süzgeç bunu bulamıyordu.
      final r = SearchService.services('ocak');
      expect(r, isNotEmpty);
      expect(r.any((h) => h.subService == 'Doğalgaz Tesisatı'), isTrue);
    });

    test('"ocak dönüşümü" ve "ocak bağlama" doğru hizmete gider', () {
      for (final q in const ['ocak dönüşümü', 'ocak bağlama']) {
        final r = SearchService.services(q);
        expect(r.any((h) => h.subService == 'Doğalgaz Tesisatı'), isTrue,
            reason: q);
      }
    });

    test('"kolon hattı" sonuç döndürür', () {
      // Sözlükte yalnız "kolon tesisatı" biçimi vardı; "hat" sözcüğüyle
      // arayan SIFIR sonuç alıyordu.
      final r = SearchService.services('kolon hattı');
      expect(r, isNotEmpty);
      expect(r.any((h) => h.subService == 'Doğalgaz Boru Hattı Tadilatı'),
          isTrue);
    });
  });

  group('4 — SIRALAMA: DAR EŞLEŞME ÖNCE', () {
    test('adı birebir eşleşen en üstte', () {
      // ⚠ "Halı Yıkama" hem KATEGORİ hem ALT HİZMET adı; ikisi de tam
      // eşleşme (skor 0). Etiketin doğru olması yeter.
      final r = SearchService.services('halı yıkama');
      expect(r.first.label, 'Halı Yıkama');
    });

    test('baştan eşleşme, ad içinde geçmeden ÖNCE gelir', () {
      // "kombi" → kategori adları önce, eş anlamlıdan gelenler sonra.
      final r = SearchService.services('kombi montajı');
      expect(r.first.subService, 'Kombi Montajı');
    });

    test('eş anlamlıdan gelen sonuç, ad eşleşmesinin ARDINDA', () {
      // "doğalgaz" kategori adının BAŞINDA geçer (skor 2); eş
      // anlamlıdan gelen sonuçlar (skor 6) onun arkasında sıralanır.
      final r = SearchService.services('doğalgaz');
      expect(r.first.category, 'Doğalgaz');
      expect(r.first.subService, isNull, reason: 'kategori satırı önce');
    });
  });

  group('5 — HİZMET VEREN TEK TEK SEÇER', () {
    test('panel yalnız ALT HİZMET satırı listeler', () {
      final p = _kod('lib/screens/widgets/kategori_secim_paneli.dart');
      // Ana kategori satırı (subService == null) atlanır.
      expect(p.contains('final alt = h.subService;'), isTrue);
      expect(p.contains('if (alt == null || _secili.contains(alt))'), isTrue);
    });

    test('seçili hizmet tekrar listelenmez', () {
      final p = _kod('lib/screens/widgets/kategori_secim_paneli.dart');
      expect(p.contains('_secili.contains(alt)'), isTrue);
    });
  });


  group('ÖNERİ PANELİ — SAYFAYI İTMEZ, HEPSİNİ GÖSTERİR', () {
    final k = _kod('lib/screens/widgets/inline_search_box.dart');

    test('panel OVERLAY katmanında çizilir', () {
      // ⚠ Panel eskiden kutunun altındaki `Column` çocuğuydu:
      // açıldıkça altındaki kartlar aşağı kayıyor, kapanınca geri
      // zıplıyordu. Artık overlay'de ve kutuya `LayerLink` ile bağlı.
      //
      // ⚠ AYRI PENCERE DEĞİL: yeni route/diyalog açılmaz.
      expect(k.contains('LayerLink'), isTrue);
      expect(k.contains('CompositedTransformTarget'), isTrue);
      expect(k.contains('CompositedTransformFollower'), isTrue);
      expect(k.contains('Overlay.of(context).insert'), isTrue);
    });

    test('panel kutunun ALT KÖŞESİNE yapışır', () {
      expect(k.contains('targetAnchor: Alignment.bottomLeft'), isTrue);
      expect(k.contains('followerAnchor: Alignment.topLeft'), isTrue);
    });

    test('overlay girdisi TEMİZLENİR', () {
      // Kaldırılmazsa ekran değişince panel asılı kalır.
      expect(k.contains('void _paneliKaldir()'), isTrue);
      final d = k.indexOf('void dispose()');
      expect(k.substring(d, k.indexOf('\n  }', d)).contains('_paneliKaldir()'),
          isTrue,
          reason: 'dispose panelini kaldırmıyor');
      // Seçim ve odak kaybında da kaldırılır.
      expect('_paneliKaldir();'.allMatches(k).length,
          greaterThanOrEqualTo(3));
    });

    test('SONUÇ SINIRI genişletildi', () {
      // Katalog 517 hizmete çıkınca 40'lık varsayılan yetmiyordu.
      expect(k.contains('enFazla: 200'), isTrue);
    });

    test('panel yüksekliği EKRANA göre, sabit 320 DEĞİL', () {
      expect(k.contains('ekran * 0.55'), isTrue);
      expect(k.contains('maxHeight: 320'), isFalse,
          reason: 'sabit yükseklik geri gelmiş');
    });
  });


  group('PERFORMANS — TUŞ BAŞINA MALİYET', () {
    test('NORMALLEŞTİRME ÖNBELLEĞİ sonucu değiştirmez', () {
      // ⚠ Önbellek yalnız tekrarı önler; aynı sorgu iki kez
      // çalıştığında sonuç birebir aynı olmalı.
      final ilk = SearchService.services('kombi bakım', enFazla: 200);
      final ikinci = SearchService.services('kombi bakım', enFazla: 200);
      expect(ikinci.length, ilk.length);
      for (var i = 0; i < ilk.length; i++) {
        expect(ikinci[i].category, ilk[i].category, reason: 'sıra $i');
        expect(ikinci[i].subService, ilk[i].subService, reason: 'sıra $i');
      }
    });

    test('BÜYÜK/KÜÇÜK harf ve Türkçe harf davranışı korundu', () {
      final a = SearchService.services('KOMBİ', enFazla: 200);
      final b = SearchService.services('kombi', enFazla: 200);
      expect(a.length, b.length);
      expect(SearchService.services('IŞIK', enFazla: 5).length,
          SearchService.services('ışık', enFazla: 5).length);
    });

    test('ARDIŞIK FARKLI sorgular birbirini kirletmez', () {
      // ⚠ Sorgu parçaları önbelleğe alınıyor; önceki sorgunun
      // parçaları yenisine sızarsa yanlış sonuç döner.
      final kombi = SearchService.services('kombi', enFazla: 200);
      SearchService.services('boya', enFazla: 200);
      final kombi2 = SearchService.services('kombi', enFazla: 200);
      expect(kombi2.length, kombi.length);
    });

    test('BOŞ SORGU davranışı değişmedi', () {
      expect(SearchService.services('', enFazla: 200), isEmpty);
      expect(SearchService.services('   ', enFazla: 200), isEmpty);
    });
  });

  group('ARAMA KUTUSU — TUŞ BAŞINA YENİDEN ÇİZİM YOK', () {
    final k = File('lib/screens/widgets/inline_search_box.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('_ara içinde setState YOK', () {
      // Öneriler `Overlay`de çizilir; kutunun ağacını yeniden çizmek
      // kare süresini boşuna uzatıyordu.
      final i = k.indexOf('void _ara(String q)');
      expect(i, greaterThan(-1));
      final govde = k.substring(i, k.indexOf('}', k.indexOf('_paneliTazele();', i)));
      expect(govde.contains('setState'), isFalse,
          reason: 'tuş başına tam ekran yeniden çizim geri gelmiş');
    });

    test('kare sonuna ERTELEME kaldırıldı', () {
      final i = k.indexOf('void _ara(String q)');
      final govde = k.substring(i, k.indexOf('}', k.indexOf('_paneliTazele();', i)));
      expect(govde.contains('addPostFrameCallback'), isFalse,
          reason: 'her tuşta bir kare gecikme geri gelmiş');
    });

    test('sonuç yok satırı KENDİ bildirimini kullanır', () {
      expect(k.contains('ValueNotifier<bool> _sonucYok'), isTrue);
      expect(k.contains('ValueListenableBuilder<bool>'), isTrue);
      expect(k.contains('_sonucYok.dispose();'), isTrue,
          reason: 'bildirim temizlenmiyor — sızıntı');
    });
  });
}
