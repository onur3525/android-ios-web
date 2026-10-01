import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/offer.dart';

class OfferRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, Offer> _items = {};

  // ── Sekme anlığı (yalnız web + mock; bkz. sekme_anligi.dart) ──
  List<Offer> get sekmeKayitlari => List.unmodifiable(_items.values);
  void sekmeKayitlariniYukle(Iterable<Offer> kayitlar) {
    _items
      ..clear()
      ..addEntries(kayitlar.map((o) => MapEntry(o.id, o)));
    notifyListeners();
  }

  Offer? byId(String id) => _items[id];

  /// Bir ilana verilmiş TÜM teklifler (çoklu hizmet veren desteği).
  List<Offer> forListing(String listingId) =>
      _items.values.where((o) => o.listingId == listingId).toList()
        ..sort((a, b) {
          final c = a.createdAt.compareTo(b.createdAt); // önce gelen üstte
          return c != 0 ? c : a.id.compareTo(b.id);
        });

  Offer? byProviderForListing(String listingId, String providerId) {
    for (final o in _items.values) {
      if (o.listingId == listingId && o.providerId == providerId) {
        return o;
      }
    }
    return null;
  }

  List<Offer> byProvider(String providerId) =>
      _items.values.where((o) => o.providerId == providerId).toList();

  Offer create({
    required String listingId,
    required String providerId,
    required int amount,
    required String note,
  }) {
    final o = Offer(
        id: _uuid.v4(), listingId: listingId,
        providerId: providerId, amount: amount, note: note);
    _items[o.id] = o;
    notifyListeners();
    return o;
  }

  void removeForListing(String listingId) {
    _items.removeWhere((_, o) => o.listingId == listingId);
    notifyListeners();
  }

  void touch() => notifyListeners();
}
