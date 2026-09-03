import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MOCK MODDA AĞ ÇAĞRISI YAPILMAZ.
///
/// ⚠ NİÇİN KRİTİK: bazı ekranlar port sistemini atlayıp DOĞRUDAN
/// `ApiClient` çağırır. Mock modda backend yoktur; istek 20 saniye
/// timeout'a düşer ve `GET` olduğu için 2 kez daha denenir:
///
///   3 deneme × 20sn + geri çekilme ≈ 61 saniye
///
/// Bu sürede ekranda takılı bir yükleniyor çarkı döner. Kullanıcı
/// uygulamanın donduğunu sanır.
///
/// ⚠ Bu test SÖZLEŞME testidir: doğrudan HTTP çağıran HER ekran
/// `ApiConfig.useRealApi` ile erken çıkış yapmalıdır.
/// ⚠ YORUM SATIRLARI ELENİR — proje kuralı.
///
/// `my_categories_screen` içinde "CategoryRequestApi dosyası da
/// silinmiştir" diyen bir AÇIKLAMA satırı var; ham metin okunduğunda
/// test bunu kod sanıp başarısız oluyordu.
String _oku(String p) => File(p)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('Mock ağ koruması', () {
    test('DOĞRUDAN HTTP ÇAĞIRAN HER EKRAN mod kontrolü yapar', () {
      final korumasiz = <String>[];
      for (final f in Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final k = f.readAsStringSync();
        if (!k.contains('ApiClient>()')) {
          continue;
        }
        if (!k.contains('ApiConfig.useRealApi')) {
          korumasiz.add(f.path.split('/').last);
        }
      }
      expect(korumasiz, isEmpty,
          reason: 'mock modda takılı çark üretecek ekranlar: $korumasiz');
    });

    test('Hesap Ayarları mock modda BOŞ liste ile açılır', () {
      // ⚠ Ekranın geri kalanı (şifre · bildirim · dondurma · silme)
      // zaten çiziliyordu; yalnız alttaki çark takılı kalıyordu.
      final k = _oku('lib/screens/account_settings_screen.dart');
      expect(k.contains('if (!ApiConfig.useRealApi) {'), isTrue);
      expect(k.contains('_requests = const [];'), isTrue);
    });

    test('Kategorilerim HİÇ ağ çağrısı yapmaz', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ — TEST GEVŞETİLMEDİ, DARALTILDI.
      //
      // Eskiden bu ekran kategori taleplerini sunucudan çekiyordu ve
      // yalnız mock modda erken çıkması denetleniyordu. Kategori talep
      final k = _oku('lib/screens/my_categories_screen.dart');
      expect(k.contains('ApiClient>()'), isFalse,
          reason: 'ekran yeniden doğrudan HTTP çağırmaya başlamış');
      expect(k.contains('CategoryRequestApi'), isFalse);
      expect(File('lib/data/remote/api/category_request_api.dart').existsSync(),
          isFalse,
          reason: 'talep API dosyası geri gelmiş');
    });

    test('Sözleşmeler mock modda beklemez', () {
      final k = _oku('lib/screens/legal_screen.dart');
      expect(k.contains('if (!ApiConfig.useRealApi) {'), isTrue);
    });

    test('Kayıt sonrası fotoğraf yükleme mock modda ATLANIR', () {
      // Her fotoğraf için ayrı timeout → dakikalarca bekleme.
      final k = _oku('lib/screens/register_screen.dart');
      expect(k.contains('if (!ApiConfig.useRealApi) {\n      return true;\n    }'),
          isTrue);
    });
  });
}
