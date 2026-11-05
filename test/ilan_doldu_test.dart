// İLAN 3 TEKLİFLE DOLDU (5 Kas, kullanıcı kararı)
//
// · 3. teklif verildiği an kart, teklif vermemiş hizmet verenin listesinden
//   kalkar (sunucu `LISTING_FULL` anlık haberi → "Yeni işler" yenilenir).
// · İlanın içindeki ya da karta son anda basan hizmet veren ilan
//   bilgilerini görmez; yalnız "Bu ilana ulaşılamıyor" yazısı.
// · "Teklif Ver" anında ilan dolduysa UYARI GÖSTERİLMEZ; aynı ekran.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart' show Role;
import 'package:hizmetcep/data/remote/api/listing_api.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/screens/job_detail_screen.dart' show kIlanaUlasilamiyor;
import 'package:hizmetcep/ui/anlik_tazeleme.dart';

import 'support/fake_backend.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Anlık haber', () {
    test('LISTING_FULL: hizmet verende yalnız "Yeni işler" yenilenir', () {
      expect(AnlikTazeleme.isler('LISTING_FULL', Role.provider),
          {TazelemeIsi.yeniIsler});
    });

    test('LISTING_FULL bildirim listesini ve hizmet alanı etkilemez', () {
      expect(AnlikTazeleme.isler('LISTING_FULL', Role.customer), isEmpty);
    });
  });

  group('İlan deposu', () {
    test('liste yenilenince dolan ilan kartı kalkar', () async {
      var dolu = false;
      final be = FakeBackend({
        'GET /listings/available': (_) =>
            dolu ? <dynamic>[] : <dynamic>[listingJson(id: 'l1')],
      });
      final repo = ApiListingRepository(ListingApi(be.client()));
      await repo.loadAvailable();
      expect(repo.byId('l1'), isNotNull);
      dolu = true;
      await repo.loadAvailable();
      expect(repo.byId('l1'), isNull);
    });

    test('ilana erişim yoksa (404) yerel kopya bırakılır', () async {
      var dolu = false;
      final be = FakeBackend({
        'GET /listings/available': (_) => <dynamic>[listingJson(id: 'l1')],
        'GET /listings/l1': (_) => dolu
            ? apiError(404, 'NOT_FOUND', 'İlan bulunamadı')
            : listingJson(id: 'l1'),
      });
      final repo = ApiListingRepository(ListingApi(be.client()));
      await repo.loadAvailable();
      expect(await repo.loadOne('l1'), isNull);
      expect(repo.byId('l1'), isNotNull);
      dolu = true;
      expect(await repo.loadOne('l1'), isA<NotFoundError>());
      expect(repo.byId('l1'), isNull);
    });
  });

  group('İş detayı ekranı', () {
    final s = _kod('lib/screens/job_detail_screen.dart');

    test('metin tek kaynakta ve kullanıcının istediği gibi', () {
      expect(kIlanaUlasilamiyor, 'Bu ilana ulaşılamıyor');
      expect(s.contains("SysEmpty(title: kIlanaUlasilamiyor, desc: '')"), isTrue);
      expect(s.contains("'İlan bulunamadı'"), isFalse);
    });

    test('teklif anında ilan dolduysa uyarı yok; ilan yeniden sorulur', () {
      final i = s.indexOf('if (err is OfferLimitReachedError) {');
      expect(i, greaterThan(0));
      final g = s.substring(i, s.indexOf('if (err != null) {', i));
      expect(g.contains('loadOne(widget.listingId, sessiz: true)'), isTrue);
      expect(g.contains('return;'), isTrue);
      expect(g.contains('_formError'), isFalse);
    });

    test('açılışta ilan sunucuya yeniden sorulur (karta son anda basılırsa)',
        () {
      expect(s.contains('unawaited(lc.loadOne(widget.listingId, sessiz: true));'),
          isTrue);
    });
  });
}
