import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/iletisim_maskesi.dart';

/// İLETİŞİM VE ADRES MASKELEME
///
/// ⚠ İki yönlü denetim: yakalanması gerekenler yakalanıyor mu, VE
/// normal açıklamalar gereksiz yere maskeleniyor mu.
void main() {
  bool yakalandi(String s) => iletisimIceriyor(s);

  group('A — TELEFON', () {
    const ornekler = [
      '5555631993',
      '555 563 19 93',
      '5 5 5 5 6 3 1 9 9 3',
      '0555 563 19 93',
      '05555631993',
      '+90 555 563 19 93',
      '+905555631993',
      '0555-563-19-93',
      '555-563-19-93',
      '(0555) 563 19 93',
      '0555.563.19.93',
    ];
    for (final t in ornekler) {
      test('yakalanır: $t', () => expect(yakalandi(t), isTrue));
    }

    test('⚠ KISA SAYILAR TELEFON DEĞİLDİR', () {
      // En az 10 rakam gerekir; fiyat ve ölçü sayıları etkilenmez.
      for (final t in ['500 TL', '3 metre kablo', '2025 yılı', '1500 lira']) {
        expect(yakalandi(t), isFalse, reason: t);
      }
    });
  });

  group('B — ADRES', () {
    const ornekler = [
      '3. Sok. Sk.', '3 sok.', '3 Sokak', '3065 sok. Sk',
      'Lale sok', 'Lale Sok.', 'Lale Sk.', 'Lale sok cad',
      'Lale Caddesi', 'Lale Cd.', 'Lale Mahallesi', 'Lale Mh.',
      'No:25', 'No 25', 'No.25', 'Numara 25', 'Kapı No 25', '25 numara',
      'D4', 'D:4', 'D.4', 'Daire 4', 'Dai 4', 'Dai4', 'DAİRE 4',
      '4. Daire', 'B Blok', 'X Apartmanı', 'X Sitesi',
    ];
    for (final t in ornekler) {
      test('yakalanır: $t', () => expect(yakalandi(t), isTrue));
    }
  });

  group('C — TARİFLİ KONUM', () {
    const ornekler = [
      'Karşıyaka Çiçek Pasajı içinde Ayşe Terzi',
      'AVM nin karşısında',
      'caminin yanında',
      'okulun karşısında',
      'marketin arkasında',
      'sitenin B bloğu',
      'Y binasının 3. katı',
    ];
    for (final t in ornekler) {
      test('yakalanır: $t', () => expect(yakalandi(t), isTrue));
    }
  });

  group('D/E/F — E-POSTA · URL · SOSYAL MEDYA', () {
    const ornekler = [
      'example@gmail.com',
      'www.example.com',
      'https://example.com',
      'instagram: kullaniciadi',
      '@kullaniciadi',
      'wp: 0555 563 19 93',
      'telegram - kullanici',
    ];
    for (final t in ornekler) {
      test('yakalanır: $t', () => expect(yakalandi(t), isTrue));
    }
  });

  group('G — ⚠ NORMAL AÇIKLAMA MASKELENMEZ', () {
    const ornekler = [
      'Doğalgaz tesisatı, kombi bağlantısı ve bakım hizmeti veriyorum.',
      '3 odalı ev',
      '4 saat içinde gelebilirim',
      '500 TL',
      '3 metre kablo',
      '4 kat boya yapılacak',
      'İki katlı evim var',
      'Boya 3 kat olacak',
      'Kombi bakımı gerekiyor',
      'Yarın sabah uygunum',
      'Petek temizliği yaptırmak istiyorum',
    ];
    for (final t in ornekler) {
      test('maskelenmez: $t', () {
        expect(yakalandi(t), isFalse);
        expect(maskele(t), t, reason: 'metin değişmemeli');
      });
    }
  });

  group('LOKAL MASKELEME', () {
    test('⚠ YALNIZ RİSKLİ PARÇA GİZLENİR', () {
      // Açıklamanın tamamı DEĞİL, yalnız adres öbeği maskelenir.
      const girdi = 'Evde boya işi yaptırmak istiyorum. No:25, D4. '
          'Yarın uygunum.';
      final cikti = maskele(girdi);
      expect(cikti.contains('Evde boya işi yaptırmak istiyorum'), isTrue);
      expect(cikti.contains('Yarın uygunum'), isTrue);
      expect(cikti.contains('No:25'), isFalse);
      expect(cikti.contains('D4'), isFalse);
      expect(cikti.contains(kMaskeEtiketi), isTrue);
    });

    test('telefon maskelenir, cümle kalır', () {
      const girdi = 'Kombi arızalı. 0555 563 19 93 numarasından arayın.';
      final cikti = maskele(girdi);
      expect(cikti.contains('Kombi arızalı'), isTrue);
      expect(cikti.contains('numarasından arayın'), isTrue);
      expect(cikti.contains('0555'), isFalse);
    });
  });

  group('H — İLETİŞİM AÇIK / KAPALI', () {
    const girdi = 'Kombi arızalı. 0555 563 19 93 numarasından arayın.';

    test('⚠ KAPALIYKEN MASKELİ', () {
      final c = gorunenMetin(girdi, iletisimAcik: false);
      expect(c.contains('0555'), isFalse);
      expect(c.contains(kMaskeEtiketi), isTrue);
    });

    test('⚠ AÇIKKEN METİN AYNEN', () {
      // Mevcut normal görünüm bozulmaz.
      expect(gorunenMetin(girdi, iletisimAcik: true), girdi);
    });
  });

  group('⚠ YAZAN KİŞİYE KISITLAMA YOK', () {
    String kod(String yol) => File(yol)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    test('ilan oluşturma ekranı maskelemeye DOKUNMAZ', () {
      // Kullanıcı yazarken uyarı görmez, metni değişmez.
      final k = kod('lib/screens/create_listing_screen.dart');
      expect(k.contains('iletisim_maskesi'), isFalse);
      expect(k.contains('maskele('), isFalse);
    });

    test('hizmet alanın KENDİ ilan ekranı maskelenmez', () {
      // Kendi yazdığını maskelemek anlamsız olurdu.
      final k = kod('lib/screens/my_listings_screen.dart');
      expect(k.contains('maskele('), isFalse);
    });

    test('⚠ 1) HİZMET ALAN KENDİ İLAN AÇIKLAMASINI HAM GÖRÜR', () {
      // ── NİÇİN AYRI TEST ──
      //
      // `listing_detail_screen` HEM hizmet alanın kendi ilanını
      // gösterir HEM de gelen teklif kartlarını. Maskeleme YALNIZ
      // teklif kartındaki nota uygulandı (`_TeklifKarti`); ilan
      // açıklaması (`l.desc`) HAM kalır.
      //
      // ⚠ Kendi yazdığını maskelemek anlamsız olurdu: kullanıcı
      // telefonunu yazdığını göremezdi.
      final ld = kod('lib/screens/listing_detail_screen.dart');
      expect(ld.contains('maskele(l.desc'), isFalse,
          reason: 'kendi ilan açıklaması maskelenmiş');
      expect(ld.contains('gorunenMetin(l.desc'), isFalse,
          reason: 'kendi ilan açıklaması koşullu maskelenmiş');
      // Ham gösterim yerinde.
      expect(ld.contains('l.desc,'), isTrue);

      final ml = kod('lib/screens/my_listings_screen.dart');
      expect(ml.contains('maskele('), isFalse);
      expect(ml.contains('listing.desc,'), isTrue);
    });

    test('⚠ 5) HİZMET VEREN KENDİ TEKLİF NOTUNU HAM GÖRÜR', () {
      // `job_detail_screen`'de hizmet veren kendi teklifini görür.
      // Kendi notu maskelenmez; maskelenen YALNIZ ilan açıklamasıdır.
      final jd = kod('lib/screens/job_detail_screen.dart');
      expect(jd.contains('Text(mine.note,'), isTrue,
          reason: 'kendi not gösterimi kalkmış');
      expect(jd.contains('maskele(mine.note'), isFalse);
      expect(jd.contains('gorunenMetin(mine.note'), isFalse);
    });

    test('karşı tarafın gördüğü dört nokta maskelenir', () {
      for (final yol in const [
        'lib/screens/job_detail_screen.dart',
        'lib/screens/jobs_screen.dart',
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/listing_detail_screen.dart',
      ]) {
        expect(kod(yol).contains('iletisim_maskesi'), isTrue, reason: yol);
      }
    });
  });
}
