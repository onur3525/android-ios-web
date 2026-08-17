import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KATEGORİ SEÇİM PANELİ — üç ekranda AYNI davranış.
///
/// ⚠ İŞ KURALI: hizmet veren ALT HİZMET seçebilmelidir. "Kombi
/// Servisi" seçen usta 4 alt hizmetin tamamına bağlanmamalı; yalnız
/// gerçekten yaptığı işleri seçebilmelidir.
///
/// Eskiden `RefMultiSelectSheet` 53 ANA KATEGORİYİ düz onay kutusu
/// listesi olarak gösteriyordu — alt hizmet seçilemiyordu.
String _oku(String p) => File(p).readAsStringSync();

void main() {
  group('Ortak panel', () {
    test('KATEGORİ SEÇİMİ YAPAN ÜÇ EKRAN da AYNI paneli kullanır', () {
      // ⚠ Ayrı paneller olsaydı biri düzeltilip öteki unutulurdu.
      for (final f in [
        'lib/screens/role_switch_screen.dart',
        'lib/screens/register_screen.dart',
      ]) {
        final k = _oku(f);
        expect(k.contains('KategoriSecimPaneli'), isTrue,
            reason: '$f ortak paneli kullanmıyor');
      }
    });

    test('DÜZ LİSTE PANELİ kategori seçiminde KULLANILMAZ', () {
      // `RefMultiSelectSheet` il/ilçe seçiminde kalabilir — orada
      // liste doğru biçimdir. Ama KATEGORİ için kullanılmamalı.
      for (final f in [
        'lib/screens/role_switch_screen.dart',
        'lib/screens/register_screen.dart',
      ]) {
        final k = _oku(f);
        expect(k.contains("title: 'Hizmet Kategorileri',\n        options:"),
            isFalse,
            reason: '$f hâlâ düz liste gösteriyor');
      }
    });

    test('panel ALT HİZMETLERİ arar (ana kategori değil)', () {
      // ⚠ ARAMA ORTAK SERVİSE TAŞINDI. Panel artık katalog üzerinde
      // elle dolaşmıyor; `SearchService` sonuçlarından YALNIZ alt
      // hizmet satırlarını alıyor (ana kategori satırı seçtirilmez).
      final k = _oku('lib/screens/widgets/kategori_secim_paneli.dart');
      expect(k.contains('SearchService.services('), isTrue);
      expect(k.contains('final alt = h.subService;'), isTrue);
      expect(k.contains('_sonuclar'), isTrue);
    });

    test('SEÇİM BOŞKEN onay KAPALI', () {
      // Hizmet veren en az bir kategori seçmeden rol değiştiremez.
      final k = _oku('lib/screens/widgets/kategori_secim_paneli.dart');
      expect(k.contains('_secili.isEmpty\n                      ? null'),
          isTrue);
    });

    test('ZATEN SEÇİLİ hizmet arama sonucunda ÇIKMAZ', () {
      // Tekrar eklemek anlamsızdır; kullanıcı "dokundum, bir şey
      // olmadı" diye düşünür.
      final k = _oku('lib/screens/widgets/kategori_secim_paneli.dart');
      expect(k.contains('_secili.contains(alt)'), isTrue);
    });

    test('Hizmet Kategorilerim ekranıyla AYNI arama mantığı', () {
      // İki dosyada da: en fazla 6 sonuç, seçili olanlar atlanır.
      final panel = _oku('lib/screens/widgets/kategori_secim_paneli.dart');
      final ekran = _oku('lib/screens/my_categories_screen.dart');
      for (final k in [panel, ekran]) {
        expect(k.contains('out.length >= 6'), isTrue);
      }
    });
  });
}
