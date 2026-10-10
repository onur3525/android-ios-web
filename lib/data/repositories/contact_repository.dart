import 'package:flutter/foundation.dart';

/// Ortak iletişim durumu — TEK doğruluk kaynağı (teklif id bazlı).
/// Taraflardan biri açınca iki taraf için de açıktır.
class ContactRepository extends ChangeNotifier {
  final Set<String> _openOfferIds = {};

  // ── Sekme anlığı (yalnız web + mock; bkz. sekme_anligi.dart) ──
  List<String> get sekmeKayitlari => List.unmodifiable(_openOfferIds);
  void sekmeKayitlariniYukle(Iterable<String> kayitlar) {
    _openOfferIds
      ..clear()
      ..addAll(kayitlar);
    notifyListeners();
  }

  bool isOpen(String offerId) => _openOfferIds.contains(offerId);

  /// true: ilk açılış (tüketim yapılmalı); false: zaten açıktı (no-op).
  bool open(String offerId) {
    if (_openOfferIds.contains(offerId)) {
      return false;
    }
    _openOfferIds.add(offerId);
    notifyListeners();
    return true;
  }

  void removeForOffers(Iterable<String> offerIds) {
    _openOfferIds.removeAll(offerIds);
    notifyListeners();
  }
}
