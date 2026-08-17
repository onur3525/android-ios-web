import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/remote/mappers.dart';

void main() {
  test('ilan JSON u modele çevrilir', () {
    final l = Mappers.listing({
      'id': 'l1', 'ownerId': 'u1', 'title': 'Musluk tamiri',
      'location': 'Bornova', 'description': 'Mutfak musluğu damlatıyor',
      'status': 'IN_PROGRESS', 'photoPaths': <String>[],
      'createdAt': '2026-01-01T10:00:00.000Z', 'selectedOfferId': 'o9',
    });
    expect(l.status, ListingStatus.inProgress);
    expect(l.selectedOfferId, 'o9');
    expect(l.desc, 'Mutfak musluğu damlatıyor');
  });

  test('teklif JSON u bloke alanlarını korur', () {
    final o = Mappers.offer({
      'id': 'o1', 'listingId': 'l1', 'providerId': 'p1', 'amountTl': 750,
      'note': 'Bugün gelebilirim', 'status': 'SELECTED',
      'escrowBlocked': false, 'escrowConsumed': true,
      'createdAt': '2026-01-01T10:00:00.000Z',
    });
    expect(o.status, OfferStatus.selected);
    expect(o.escrowConsumed, isTrue);
    expect(o.amount, 750);
  });

  test('hesap eşlemesi istemcide şifre hash i TUTMAZ', () {
    final a = Mappers.account({
      'id': 'u1', 'name': 'Test', 'email': 'a@b.c', 'phone': '5321112233',
      'roles': ['CUSTOMER', 'PROVIDER'], 'activeRole': 'PROVIDER',
    });
    expect(a.passwordHash, isEmpty);
    expect(a.salt, isEmpty);
    expect(a.roles.length, 2);
  });
}
