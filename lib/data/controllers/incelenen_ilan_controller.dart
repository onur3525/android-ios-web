import 'package:flutter/foundation.dart';

import '../repositories/incelenen_ilan_store.dart';

/// İNCELENEN İLAN DURUMU
///
/// İlan detayına girildiğinde ilgili kimlik işaretlenir. Liste
/// ekranında incelenmemiş ilanlar KOYU, incelenmişler normal
/// ağırlıkta gösterilir.
class IncelenenIlanController extends ChangeNotifier {
  IncelenenIlanController(this._store);

  final IncelenenIlanStore _store;

  final Set<String> _idler = {};

  /// Kalıcı kaydı belleğe alır (uygulama açılışında).
  Future<void> load() async {
    _idler
      ..clear()
      ..addAll(await _store.read());
    notifyListeners();
  }

  bool incelendiMi(String listingId) => _idler.contains(listingId);

  /// İlan detayı açıldığında çağrılır.
  ///
  /// Zaten işaretliyse hiçbir şey yapmaz — gereksiz yazma ve
  /// yeniden çizim OLMAZ.
  Future<void> isaretle(String listingId) async {
    if (listingId.isEmpty || _idler.contains(listingId)) {
      return;
    }
    _idler.add(listingId);
    await _store.save(_idler.toList(growable: false));
    notifyListeners();
  }

  /// Oturum kapanışında temizlenir.
  Future<void> clear() async {
    _idler.clear();
    await _store.clear();
    notifyListeners();
  }
}
