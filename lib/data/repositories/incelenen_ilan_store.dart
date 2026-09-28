import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// İNCELENEN İLANLAR — KALICI SAKLAMA
///
/// Sağlayıcının açıp incelediği ilan kimlikleri. Liste ekranında
/// incelenmemiş ilanlar KOYU, incelenmişler normal gösterilir.
///
/// `flutter_secure_storage` PROJEDE ZATEN VARDIR (`TokenStore`,
/// `PendingListingStore` aynı altyapıyı kullanır); yeni bağımlılık
/// eklenmemiştir.
class IncelenenIlanStore {
  static const _key = 'hc.incelenenIlanlar';

  /// Sınır: yalnız son N kayıt tutulur (depo şişmesin).
  static const int _enFazla = 500;

  final FlutterSecureStorage _s;

  IncelenenIlanStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  List<String>? _cache;

  Future<List<String>> read() async {
    if (_cache != null) {
      return _cache!;
    }
    try {
      final raw = await _s.read(key: _key);
      if (raw == null || raw.trim().isEmpty) {
        _cache = <String>[];
      } else {
        final j = jsonDecode(raw);
        _cache = j is List ? j.whereType<String>().toList() : <String>[];
      }
    } catch (_) {
      // Bozuk kayıt kullanıcıyı kilitlemez.
      _cache = <String>[];
    }
    return _cache!;
  }

  Future<void> save(List<String> idler) async {
    // En yeni kayıtlar sonda; sınırı aşan en eskiler atılır.
    final kirpik =
        idler.length <= _enFazla ? idler : idler.sublist(idler.length - _enFazla);
    _cache = kirpik;
    try {
      await _s.write(key: _key, value: jsonEncode(kirpik));
    } catch (_) {
      // Disk yazımı başarısız olsa da bellek kopyası korunur.
    }
  }

  Future<void> clear() async {
    _cache = <String>[];
    try {
      await _s.delete(key: _key);
    } catch (_) {
      // Yoksay.
    }
  }
}
