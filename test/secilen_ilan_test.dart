// TEKLİFİ SEÇİLEN İLAN (16 Eki, kullanıcı bulgusu): hizmet veren seçilen
// ilanı "İlan kaldırıldı" olarak görüyor ve açamıyordu. Teklif verdiğim
// ilanlar `/offers/my` ile gelir ve ilan deposunda ayrı tutulur.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/remote/api/listing_api.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';

void main() {
  test('teklif verdiğim ilan açık ilan listesinde olmasa da bulunur', () {
    final repo = ApiListingRepository(ListingApi(ApiClient()));
    expect(repo.byId('l1'), isNull);
    repo.teklifIlanlariniAl([
      Listing(id: 'l1', ilanNo: '1', ownerId: 'a', title: 'Boya', location: 'Konak', desc: 'x y z')
        ..selectedOfferId = 'o1',
    ]);
    expect(repo.byId('l1')?.selectedOfferId, 'o1');
    expect(repo.all, isEmpty, reason: '"Yeni işler" beslemesine girmez');
  });

  test('main bağlar; sunucu seçilen ilanın silinmesini reddeder', () {
    expect(File('lib/main.dart').readAsStringSync().contains('offerRepo.ilanlariAktar = listingRepo.teklifIlanlariniAl;'), isTrue);
    expect(File('backend/src/routes/ilan.js').readAsStringSync().contains("'Teklif seçilen ilan silinemez'"), isTrue);
  });
}
