import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/review.dart';

class ReviewRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, Review> _items = {}; // reviewId → Review

  Review? byOffer(String offerId) {
    for (final r in _items.values) {
      if (r.offerId == offerId) {
        return r;
      }
    }
    return null;
  }

  List<Review> byProvider(String providerId) =>
      _items.values.where((r) => r.providerId == providerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// MÜŞTERİNİN YAZDIĞI değerlendirmeler (yeniden eskiye).
  ///
  /// ⚠ `byProvider` ALINAN değerlendirmelerdir; bu ise VERİLEN.
  /// Hizmet alan kendi yazdıklarını görüntüler, düzenleyemez.
  List<Review> byAuthor(String authorId) =>
      _items.values.where((r) => r.authorId == authorId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Review create({
    required String listingId,
    required String offerId,
    required String providerId,
    required String authorId,
    required int stars,
    required String text,
  }) {
    final r = Review(
        id: _uuid.v4(), listingId: listingId, offerId: offerId,
        providerId: providerId, authorId: authorId, stars: stars, text: text);
    _items[r.id] = r;
    notifyListeners();
    return r;
  }
}
