import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/domain/listing_state_machine.dart';

/// PAKET 2 — DURUM GÖÇÜ VE TAMAMLANMIŞ İŞ MANTIĞI
///
/// ⚠ İKİ KAVRAM AYRIDIR (API sözleşmesi §24):
///   · `ListingStatus`   → ilanın YAŞAMI
///   · `selectedOfferId` → İŞİN tamamlanmışlığı
///
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

Listing _ilan({String? secili}) {
  final l = Listing(
      id: 'l1',
      ilanNo: '10458231',
      ownerId: 'u1',
      title: 'Kombi Bakımı',
      location: 'Alsancak, Konak / İzmir',
      desc: 'test');
  l.selectedOfferId = secili;
  return l;
}

void main() {
  group('1 — NİHAİ ENUM DEĞERLERİ', () {
    test('ListingStatus TAM DÖRT değer', () {
      expect(ListingStatus.values, hasLength(4));
      expect(ListingStatus.values.map((e) => e.name).toSet(),
          {'active', 'expired', 'userDeleted', 'adminRemoved'});
    });

    test('OfferStatus TAM DÖRT değer', () {
      expect(OfferStatus.values, hasLength(4));
      expect(OfferStatus.values.map((e) => e.name).toSet(),
          {'active', 'selected', 'expired', 'closed'});
    });

    test('⚠ eski değerler YENİ ADLA geri getirilmemiş', () {
      // `finished`, `done`, `working`, `removed` gibi karşılıklar
      final adlar = <String>{
        ...ListingStatus.values.map((e) => e.name),
        ...OfferStatus.values.map((e) => e.name),
      };
      for (final yasak in const [
        'completed', 'inProgress', 'providerSelected', 'cancelled', 'open',
        'withdrawn', 'finished', 'done', 'working', 'removed'
      ]) {
        expect(adlar.contains(yasak), isFalse, reason: 'yasak değer: $yasak');
      }
    });
  });

  group('2 — TAMAMLANMIŞ İŞ = SEÇİLMİŞ TEKLİF', () {
    test('ACTIVE + seçim YOK → tamamlanmış değil', () {
      final l = _ilan();
      expect(l.status, ListingStatus.active);
      expect(l.isTamamlanmisIs, isFalse);
    });

    test('ACTIVE + seçim VAR → tamamlanmış', () {
      expect(_ilan(secili: 'o1').isTamamlanmisIs, isTrue);
    });

    test('EXPIRED + seçim YOK → tamamlanmış değil', () {
      final l = _ilan()..status = ListingStatus.expired;
      expect(l.isTamamlanmisIs, isFalse);
    });

    test('EXPIRED + seçim VAR → tamamlanmışlık KORUNUR', () {
      final l = _ilan(secili: 'o1')..status = ListingStatus.expired;
      expect(l.isTamamlanmisIs, isTrue);
    });

    test('USER_DELETED + seçim VAR → ilişki YOK SAYILMAZ', () {
      // ⚠ Silinmiş olması işin yapılmadığı anlamına gelmez.
      final l = _ilan(secili: 'o1')..status = ListingStatus.userDeleted;
      expect(l.isTamamlanmisIs, isTrue);
    });

    test('ADMIN_REMOVED + seçim VAR → ilişki YOK SAYILMAZ', () {
      final l = _ilan(secili: 'o1')..status = ListingStatus.adminRemoved;
      expect(l.isTamamlanmisIs, isTrue);
    });
  });

  group('3 — DURUM MAKİNESİ', () {
    test('yalnız yaşam geçişleri tanımlı', () {
      expect(ListingStateMachine.transitions.keys.toSet(),
          ListingStatus.values.toSet());
      // Kapanmış üç durumdan çıkış yok (expired hariç: silinebilir).
      expect(ListingStateMachine.transitions[ListingStatus.userDeleted], isEmpty);
      expect(ListingStateMachine.transitions[ListingStatus.adminRemoved], isEmpty);
    });

    test('canDelete İLANI alır — tamamlanmış iş silinemez', () {
      expect(ListingStateMachine.canDelete(_ilan()), isTrue);
      expect(ListingStateMachine.canDelete(_ilan(secili: 'o1')), isFalse);
      final kaldirilmis = _ilan()..status = ListingStatus.adminRemoved;
      expect(ListingStateMachine.canDelete(kaldirilmis), isFalse);
    });
  });

  group('4 — MAPPER', () {
    test('nihai değerler doğru eşlenir', () {
      expect(Mappers.listingStatus('ACTIVE'), ListingStatus.active);
      expect(Mappers.listingStatus('EXPIRED'), ListingStatus.expired);
      expect(Mappers.listingStatus('USER_DELETED'), ListingStatus.userDeleted);
      expect(Mappers.listingStatus('ADMIN_REMOVED'), ListingStatus.adminRemoved);
      expect(Mappers.offerStatus('ACTIVE'), OfferStatus.active);
      expect(Mappers.offerStatus('SELECTED'), OfferStatus.selected);
      expect(Mappers.offerStatus('EXPIRED'), OfferStatus.expired);
      expect(Mappers.offerStatus('CLOSED'), OfferStatus.closed);
    });

    test('⚠ ESKİ DEĞERLER sessizce yanlış duruma çevrilmez', () {
      // Backend geçiş döneminde eski değer gönderebilir. Kural:
      // yaşam durumu `active` olur, ama tamamlanmışlık BURADAN
      // türetilmez — o `selectedOfferId` alanından gelir.
      expect(Mappers.listingStatus('COMPLETED'), ListingStatus.active);
      expect(Mappers.listingStatus('IN_PROGRESS'), ListingStatus.active);
      expect(Mappers.listingStatus('PROVIDER_SELECTED'), ListingStatus.active);
      // Kullanıcı kapatması `userDeleted`tır.
      expect(Mappers.listingStatus('CANCELLED'), ListingStatus.userDeleted);
      // Teklif tarafında eski iki değer sistemsel kapanıştır.
      expect(Mappers.offerStatus('CANCELLED'), OfferStatus.closed);
      expect(Mappers.offerStatus('WITHDRAWN'), OfferStatus.closed);
    });

    test('tanınmayan değer güvenli tarafa düşer', () {
      expect(Mappers.listingStatus('ZZZ'), ListingStatus.active);
      expect(Mappers.offerStatus('ZZZ'), OfferStatus.active);
    });
  });

  group('5 — EKRANLAR TEK KAYNAĞI KULLANIR', () {
    test('sekme filtresi ilişkiden okur', () {
      final k = _kodu('lib/screens/my_listings_screen.dart');
      expect(k.contains('l.isTamamlanmisIs'), isTrue);
      expect(k.contains('ListingStatus.completed'), isFalse);
    });

    test('rozet tek kaynaktan gelir', () {
      final k = _kodu('lib/screens/status_ui.dart');
      expect(k.contains('listingRozetiUi'), isTrue,
          reason: 'ortak rozet yardımcısı yok');
      expect(k.contains('isTamamlanmisIs'), isTrue);
    });

    test('⚠ ekranlar kendi tamamlanmışlık koşulunu YAZMAZ', () {
      // `selectedOfferId != null` onlarca yerde tekrarlanırsa biri
      // güncellenip öteki unutulur.
      for (final yol in const [
        'lib/screens/my_listings_screen.dart',
        'lib/screens/jobs_screen.dart',
        'lib/screens/status_ui.dart',
      ]) {
        expect(_kodu(yol).contains('selectedOfferId != null'), isFalse,
            reason: '$yol: koşul elle yazılmış');
      }
    });
  });
}
