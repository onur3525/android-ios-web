import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/review.dart';

/// PAKET 4 — PATCH KURALI VE MODEL ALANLARI
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

String _sozlesme() => File('docs/openapi.yaml').readAsStringSync();

void main() {
  group('1 — PATCH /listings/{id} KURALI', () {
    test('⚠ GENEL YASAK YOK — izin verilen alan tanımlı', () {
      final y = _sozlesme();
      expect(y.contains('İlan güncelle — YALNIZ İZİN VERİLEN ALANLAR'), isTrue);
      expect(y.contains('ALLOWED_AFTER_PUBLISH'), isTrue);
      expect(y.contains('FORBIDDEN_AFTER_PUBLISH'), isTrue);
    });

    test('request schema YALNIZ description kabul eder', () {
      // ⚠ `additionalProperties: false` şart: aksi hâlde istemci
      // `title` gönderir ve sunucu sessizce kabul edebilir.
      final y = _sozlesme();
      final i = y.indexOf('summary: İlan güncelle — YALNIZ İZİN VERİLEN ALANLAR');
      expect(i, greaterThan(0));
      final blok = y.substring(i, i + 4000);
      expect(blok.contains('additionalProperties: false'), isTrue);
      expect(blok.contains('minProperties: 1'), isTrue);
    });

    test('⚠ title YASAK — işin kimliğidir', () {
      // Uygulamada başlık serbest metin değil, SEÇİLEN HİZMETİN
      // adıdır. Değişmesi, hizmet verenlerin başka bir işe teklif
      // vermiş duruma düşmesi demektir.
      final y = _sozlesme();
      expect(y.contains('BU ALAN İŞİN KİMLİĞİDİR'), isTrue);
    });

    test('⚠ SEÇİLMİŞ TEKLİFLİ İLANDA PATCH TAMAMEN REDDEDİLİR', () {
      // Ürün kararı: `description` DAHİL hiçbir alan değişmez.
      // Gerekçe: hizmet veren teklifini O AÇIKLAMAYA bakarak verdi.
      final y = _sozlesme();
      expect(y.contains('PATCH TAMAMEN\n          REDDEDİLİR'), isTrue);
      expect(
          y.contains('`description` YALNIZ `selectedOfferId == null` iken'),
          isTrue);
    });

    test('sunucu zorunlu kontrolleri yazılı', () {
      // ⚠ İstemcide düğmenin gizlenmesi güvenlik DEĞİLDİR.
      final y = _sozlesme();
      expect(y.contains('SUNUCU ZORUNLU KONTROLLERİ'), isTrue);
      expect(y.contains('STATE_CONFLICT'), isTrue,
          reason: 'ret için yeni hata kodu icat edilmemeli');
    });

    test('⚠ UI: düzenleme aksiyonu hiçbir ekranda YOK', () {
      // Uygulamada ilan düzenleme yüzeyi bulunmuyor; PATCH'i çağıran
      // bir controller/ekran da yok. Kural kendiliğinden sağlanıyor.
      for (final yol in const [
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/my_listings_screen.dart',
      ]) {
        final k = _kodu(yol);
        expect(k.contains('İlanı Düzenle'), isFalse, reason: yol);
        expect(k.contains('.update('), isFalse, reason: '$yol: PATCH çağrısı');
      }
    });

    test('kapanmış durumlarda PATCH reddedilir', () {
      final y = _sozlesme();
      for (final d in const ['EXPIRED', 'USER_DELETED', 'ADMIN_REMOVED']) {
        expect(y.contains('`$d` → PATCH REDDEDİLİR'), isTrue, reason: d);
      }
    });
  });

  group('1b — SİLME: TEK KANONİK UÇ', () {
    test('DELETE /listings/{id} kanoniktir', () {
      final k = _kodu('lib/data/remote/api/listing_api.dart');
      expect(k.contains("c.delete(\n      '/listings/\$id'"), isTrue);
    });

    test('⚠ POST /listings/{id}/cancel KALDIRILDI', () {
      // Aynı iş için iki uç bırakılmaz.
      expect(_sozlesme().contains('/listings/{listingId}/cancel:'), isFalse,
          reason: 'sözleşmede kalmış');
      for (final yol in const [
        'lib/data/remote/api/listing_api.dart',
        'lib/data/remote/repositories/api_repositories.dart',
        'lib/data/ports/api_ports.dart',
        'lib/data/ports/repository_ports.dart',
        'lib/data/ports/mock_ports.dart',
        'lib/data/controllers/listing_controller.dart',
        'lib/screens/listing_detail_screen.dart',
      ]) {
        expect(_kodu(yol).contains("/listings/\$id/cancel"), isFalse,
            reason: '$yol: uç kalmış');
      }
    });

    test('⚠ cancel adında YENİ DURUM ÜRETİLMEDİ', () {
      // Eski `cancelled` durumu geri getirilmedi; kullanıcı silmesi
      // `USER_DELETED`tır ve `ADMIN_REMOVED` ile karıştırılmaz.
      expect(ListingStatus.values.map((e) => e.name).contains('cancelled'),
          isFalse);
      expect(_kodu('lib/data/ports/mock_ports.dart')
          .contains('ListingStatus.userDeleted'), isTrue);
    });
  });

  group('3 — REVIEW MODELİ', () {
    test('status ve publishedAt eklendi', () {
      expect(ReviewStatus.values.map((e) => e.name).toSet(),
          {'pendingPublication', 'published', 'adminDeleted'});
      expect(ReviewStatus.fromJson('PUBLISHED'), ReviewStatus.published);
      expect(ReviewStatus.fromJson('ZZZ'), isNull,
          reason: 'tanınmayan değer varsayılana ZORLANMAZ');
    });

    test('⚠ YAYIN KARARI SUNUCUNUNDUR', () {
      final r = Review(
          id: 'r1',
          listingId: 'l1',
          offerId: 'o1',
          providerId: 'p1',
          authorId: 'a1',
          stars: 5,
          text: 'çok iyi iş çıkardı',
          status: ReviewStatus.pendingPublication,
          createdAt: DateTime(2020));
      // ⚠ Tarih ÇOK ESKİ olsa bile sunucu "beklemede" dediyse
      // yayınlanmış sayılmaz. Cihaz saati kararı ezmez.
      expect(r.yayinlandiMi, isFalse);
    });

    test('sunucu alanı yoksa yerel gecikme köprüsü çalışır', () {
      final eski = Review(
          id: 'r2',
          listingId: 'l1',
          offerId: 'o1',
          providerId: 'p1',
          authorId: 'a1',
          stars: 4,
          text: 'işini düzgün yaptı',
          createdAt: DateTime.now().subtract(const Duration(days: 2)));
      final yeni = Review(
          id: 'r3',
          listingId: 'l1',
          offerId: 'o2',
          providerId: 'p1',
          authorId: 'a1',
          stars: 4,
          text: 'işini düzgün yaptı',
          createdAt: DateTime.now());
      expect(eski.yayinlandiMi, isTrue);
      expect(yeni.yayinlandiMi, isFalse);
    });

    test('mapper alanları okur, varsayım yapmaz', () {
      final k = _kodu('lib/data/remote/mappers.dart');
      expect(k.contains("ReviewStatus.fromJson(j['status'] as String?)"), isTrue);
      expect(k.contains("j['publishedAt']"), isTrue);
    });
  });

  group('5 — REGRESYON: önceki paketler bozulmadı', () {
    test('eski durumlar aktif kodda yok', () {
      for (final yol in const [
        'lib/data/ports/mock_ports.dart',
        'lib/screens/my_listings_screen.dart',
        'lib/screens/offer_detail_screen.dart',
      ]) {
        final k = _kodu(yol);
        for (final d in const [
          'ListingStatus.completed',
          'ListingStatus.inProgress',
          'ListingStatus.providerSelected',
          'OfferStatus.cancelled',
        ]) {
          expect(k.contains(d), isFalse, reason: '$yol: $d');
        }
      }
    });

    test('tamamlanmışlık hâlâ ilişkiden türetiliyor', () {
      final l = Listing(
          id: 'l1',
          ilanNo: '10458231',
          ownerId: 'u1',
          title: 'Kombi Bakımı',
          location: 'Alsancak, Konak / İzmir',
          desc: 'test');
      expect(l.isTamamlanmisIs, isFalse);
      l.selectedOfferId = 'o1';
      expect(l.isTamamlanmisIs, isTrue);
      expect(l.status, ListingStatus.active,
          reason: 'seçim ilanın YAŞAM durumunu değiştirmez');
    });
  });
}
