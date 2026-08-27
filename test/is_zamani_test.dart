import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/pending_listing.dart';

/// İŞİN YAPILMA ZAMANI — İSTEĞE BAĞLI, TEK SEÇİMLİ
String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

Listing _ilan({IsZamani? z}) => Listing(
      id: 'i1',
      ilanNo: '10000001',
      ownerId: 'c1',
      title: 'Kombi Bakımı',
      location: 'Alsancak, Konak / İzmir',
      desc: 'Kombi bakımı gerekiyor.',
      isZamani: z,
    );

void main() {
  group('SEÇENEKLER', () {
    test('⚠ TAM ÜÇ SEÇENEK — fazlası eklenmez', () {
      // "Acil", "Bugün", "Yarın", "Planlı", "Tarih seç" YOKTUR.
      expect(IsZamani.values.length, 3);
      expect(IsZamani.values.map((e) => e.etiket).toList(),
          ['Hemen', 'Bu hafta', 'Esnek zaman']);
    });

    test('sunucu kodları', () {
      expect(IsZamani.hemen.kod, 'NOW');
      expect(IsZamani.buHafta.kod, 'THIS_WEEK');
      expect(IsZamani.esnek.kod, 'FLEXIBLE');
    });

    test('⚠ BİLİNMEYEN KOD null DÖNER — uygulama çökmez', () {
      expect(IsZamani.koddan('NOW'), IsZamani.hemen);
      expect(IsZamani.koddan(null), isNull);
      expect(IsZamani.koddan('BILINMEYEN'), isNull);
      expect(IsZamani.koddan(''), isNull);
    });
  });

  group('⚠ İSTEĞE BAĞLI', () {
    test('seçim yapılmadan ilan oluşturulabilir', () {
      final l = _ilan();
      expect(l.isZamani, isNull);
      // İlan geçerli: durum ve teklif kabulü etkilenmez.
      expect(l.status, ListingStatus.active);
      expect(l.acceptsOffers, isTrue);
    });

    test('seçim sonradan değiştirilebilir ve KALDIRILABİLİR', () {
      // Kullanıcı ilanını düzenlerken seçimini değiştirebilmeli.
      final l = _ilan(z: IsZamani.hemen);
      l.isZamani = IsZamani.esnek;
      expect(l.isZamani, IsZamani.esnek);
      l.isZamani = null;
      expect(l.isZamani, isNull, reason: 'seçim kaldırılamıyor');
    });

    test('⚠ ZORUNLU ALAN DEĞİL — doğrulamaya girmez', () {
      // ⚠ BAŞLIK DEĞİŞTİ: "İşin ne zaman yapılacağı" → "Hizmet Zamanı"
      // (ürün kararı). Eski metin form etiketi gibi soğuk duruyordu.
      final k = _kod('lib/screens/create_listing_screen.dart');
      final i = k.indexOf('Hizmet Zamanı');
      expect(i, greaterThan(0), reason: 'alan eklenmemiş');
      // ⚠ "(Zorunlu)" DEĞİL "(Opsiyonel)": kullanıcı bu alanın
      // isteğe bağlı olduğunu görmeli.
      final blok = k.substring(i, i + 320);
      expect(blok.contains('(Zorunlu)'), isFalse);
      expect(blok.contains('(Opsiyonel)'), isTrue);
    });
  });

  group('⚠ TEK SEÇİM GARANTİSİ', () {
    test('durum TEK değişkende tutulur — liste yok', () {
      // İki seçeneğin aynı anda seçili olması yapısal olarak imkânsız.
      final k = _kod('lib/screens/create_listing_screen.dart');
      expect(k.contains('IsZamani? _isZamani;'), isTrue);
      expect(k.contains('List<IsZamani>'), isFalse,
          reason: 'çoklu seçim yapısı var');
      expect(k.contains('Set<IsZamani>'), isFalse);
    });

    test('seçili düğmeye tekrar dokunmak seçimi kaldırır', () {
      final w = _kod('lib/screens/widgets/is_zamani_secici.dart');
      expect(w.contains('onDegisti(aktif ? null : z)'), isTrue);
    });

    test('seçenek listesi enum\'dan gelir', () {
      // Ekran kendi listesini yazmaz; oluşturma ve görüntüleme
      // ayrışmaz.
      final w = _kod('lib/screens/widgets/is_zamani_secici.dart');
      expect(w.contains('IsZamani.values'), isTrue);
      expect(w.contains("'Hemen'"), isFalse, reason: 'metin ekranda gömülü');
    });
  });

  group('VERİ TAŞINMASI', () {
    test('publish zinciri alanı taşır', () {
      for (final yol in const [
        'lib/data/ports/repository_ports.dart',
        'lib/data/ports/mock_ports.dart',
        'lib/data/ports/api_ports.dart',
        'lib/data/controllers/listing_controller.dart',
        'lib/data/repositories/listing_repository.dart',
        'lib/data/remote/repositories/api_repositories.dart',
        'lib/data/remote/api/listing_api.dart',
        'lib/data/remote/mappers.dart',
      ]) {
        expect(_kod(yol).contains('isZamani'), isTrue, reason: yol);
      }
    });

    test('⚠ SEÇİM YOKSA SUNUCUYA ALAN GÖNDERİLMEZ', () {
      final k = _kod('lib/data/remote/api/listing_api.dart');
      expect(k.contains("if (isZamani != null) 'workTiming'"), isTrue);
    });

    test('⚠ KAYITSIZ AKIŞTA SEÇİM KAYBOLMAZ', () {
      // Taslak JSON'a yazılır; kayıt sonrası ilana aktarılır.
      final p = PendingListing(
        category: 'Kombi Servis',
        subService: 'Kombi Bakımı',
        description: 'Bakım gerekiyor.',
        city: 'İzmir',
        district: 'Konak',
        neighborhood: 'Alsancak',
        localPhotoPaths: [],
        isZamani: IsZamani.buHafta,
        createdAt: DateTime.now(),
      );
      final geri = PendingListing.fromJson(p.toJson());
      expect(geri.isZamani, IsZamani.buHafta);
    });

    test('eski taslakta alan yoksa null', () {
      final geri = PendingListing.fromJson(const {
        'category': 'Kombi Servis',
        'description': 'x',
        'city': 'İzmir',
        'district': 'Konak',
        'neighborhood': 'Alsancak',
      });
      expect(geri.isZamani, isNull);
    });
  });

  group('HİZMET VERENİN GÖRDÜĞÜ', () {
    test('⚠ SEÇİM YOKSA ROZET ÇİZİLMEZ', () {
      final w = _kod('lib/screens/widgets/is_zamani_secici.dart');
      expect(w.contains('if (z == null)'), isTrue);
      expect(w.contains('SizedBox.shrink()'), isTrue);
      // Yer tutucu metin yok.
      expect(w.contains('Belirtilmemiş'), isFalse);
    });

    test('iş detayında koşullu gösterilir', () {
      final k = _kod('lib/screens/job_detail_screen.dart');
      expect(k.contains('if (l.isZamani != null)'), isTrue);
      expect(k.contains('IsZamaniRozeti(l.isZamani)'), isTrue);
    });
  });

  group('⚠ TASARIM SINIRLARI', () {
    final w = _kod('lib/screens/widgets/is_zamani_secici.dart');

    test('tarih seçici YOK', () {
      expect(w.contains('showDatePicker'), isFalse);
      expect(w.contains('DatePicker'), isFalse);
      expect(w.contains('Calendar'), isFalse);
    });

    test('anlam yükleyen renk YOK', () {
      // Kırmızı/yeşil kullanılmaz; mevcut birincil mavi.
      expect(w.contains('RC.danger'), isFalse);
      expect(w.contains('RC.success'), isFalse);
      expect(w.contains('Colors.red'), isFalse);
      expect(w.contains('Colors.green'), isFalse);
      expect(w.contains('RC.blue'), isTrue);
    });

    test('yardımcı metin / ikon YOK', () {
      expect(w.contains('Tooltip'), isFalse);
      expect(w.contains('RefSvg'), isFalse, reason: 'gereksiz ikon');
    });
  });
}
