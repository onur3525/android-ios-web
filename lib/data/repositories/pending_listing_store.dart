import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/pending_listing.dart';

/// TASLAK İLAN KALICI SAKLAMA
///
/// `flutter_secure_storage` PROJEDE ZATEN VARDIR (`TokenStore` aynı
/// altyapıyı kullanır); yeni bağımlılık eklenmemiştir.
///
/// Taslak route değişimlerinde ve uygulama yeniden açıldığında
/// kaybolmaz. Yayın başarıyla tamamlandığında SİLİNİR.
class PendingListingStore {
  static const _key = 'hc.pendingListing';

  final FlutterSecureStorage _s;

  PendingListingStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Bellek içi kopya — her okumada disk erişimi yapılmaz.
  PendingListing? _cache;
  bool _okundu = false;

  Future<PendingListing?> read() async {
    if (_okundu) {
      return _cache;
    }
    try {
      _cache = PendingListing.decode(await _s.read(key: _key));
    } catch (_) {
      _cache = null;
    }
    _okundu = true;
    return _cache;
  }

  Future<void> save(PendingListing p) async {
    _cache = p;
    _okundu = true;
    try {
      await _s.write(key: _key, value: p.encode());
    } catch (_) {
      // Disk yazımı başarısız olsa da bellek kopyası korunur;
      // aynı oturumda akış devam eder.
    }
  }

  Future<void> clear() async {
    _cache = null;
    _okundu = true;
    try {
      await _s.delete(key: _key);
    } catch (_) {
      // Yoksay: bellek kopyası zaten temizlendi.
    }
  }
}
