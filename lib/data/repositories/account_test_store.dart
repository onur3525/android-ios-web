import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account.dart';

/// ── ⚠ YALNIZ APK TEST KALICILIĞI İÇİN — GEÇİCİ ──
///
/// Mock modda `AuthRepository.accounts` yalnız BELLEKTE tutulur;
/// uygulama kapatılıp açıldığında (APK testinde olduğu gibi) liste
/// SIFIRLANIR ve daha önce kaydolan test hesapları kaybolur —
/// kullanıcı her seferinde yeniden kayıt olmak zorunda kalır.
///
/// Bu depo, `IncelenenIlanStore`/`PendingListingStore` ile AYNI
/// altyapıyı (`flutter_secure_storage`, proje zaten kullanıyor —
/// yeni bağımlılık YOK) kullanarak kayıtlı hesap listesini CİHAZDA
/// saklar; bir sonraki açılışta geri yüklenir.
///
/// ⚠ KULLANICI "SİL" DEDİĞİNDE: bu dosya ve `main.dart`'taki
/// bağlantı noktası (bkz. oradaki "APK TEST KALICILIĞI" bloğu)
/// birlikte kaldırılacak — bu, mock backend'in KALICI bir parçası
/// değil, yalnız test kolaylığıdır.
///
/// ⚠ `Mappers.account` (gerçek API sözleşmesi) İLE KARIŞTIRILMAZ:
/// o, sunucu YANITINI okur ve şifre alanlarını hiç taşımaz; bu depo
/// CİHAZDA saklar ve `Account.toJson`/`fromJson` üzerinden şifre
/// hash'i DAHİL tüm alanları korur — aksi hâlde geri yüklenen
/// hesaplarla giriş yapılamazdı.
class AccountTestStore {
  static const _key = 'hc.testHesaplari';

  final FlutterSecureStorage _s;

  AccountTestStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<List<Account>> read() async {
    try {
      final raw = await _s.read(key: _key);
      if (raw == null || raw.trim().isEmpty) {
        return const [];
      }
      final j = jsonDecode(raw);
      if (j is! List) {
        return const [];
      }
      return j
          .whereType<Map<String, dynamic>>()
          .map(Account.fromJson)
          .toList();
    } catch (_) {
      // ⚠ Bozuk/eski biçim kayıt kullanıcıyı KİLİTLEMEZ — boş
      // listeyle devam edilir, en kötü ihtimalle yeniden kayıt
      // gerekir (bugünkü davranışla AYNI).
      return const [];
    }
  }

  Future<void> save(List<Account> hesaplar) async {
    try {
      final j = hesaplar.map((a) => a.toJson()).toList();
      await _s.write(key: _key, value: jsonEncode(j));
    } catch (_) {
      // Disk yazımı başarısız olursa bellekteki oturum ETKİLENMEZ;
      // yalnız bir sonraki açılışta bu değişiklik kaybolur.
    }
  }

  Future<void> clear() async {
    try {
      await _s.delete(key: _key);
    } catch (_) {
      // Yoksay.
    }
  }
}
