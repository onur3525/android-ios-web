import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/category_tree.dart';

/// YORUMDAKİ SAYI = GERÇEK SAYIM
///
/// ⚠ BU TESTİN VAR OLMA NEDENİ — TEKRAR EDEN BİR ARIZA SINIFI
///
/// Katalog birkaç kez büyüdü (53/248 → 54/251 → 55 → 459 → 439 →
/// 58/517) ve her seferinde KOD doğru, YORUM geride kaldı. Dosya
/// başlığı "54 ANA KATEGORİ · 251 ALT HİZMET" derken ağaçta 58/517
/// vardı. Yanlış yorum sessizdir: derlemez, testi düşürmez, yalnız
/// sonraki okuyanı yanıltır — ve o okuyan çoğu zaman kararı ona göre
/// verir.
///
/// ⚠ Bu yüzden sayı iddiası artık İDDİA DEĞİL, KİLİTTİR. Kataloğu
/// büyüten kişi başlığı da güncellemek zorundadır; unutursa burası
/// düşer.
///
/// ⚠ HAM METİN OKUNUR, YORUM ELENMEZ. Proje kuralı yokluk
/// denetimlerinde yorumların elenmesini söyler; burada denetlenen
/// şeyin KENDİSİ yorumdur (aynı istisna `wallet_repository` bakiye
/// gerekçelerinde de geçerlidir).
///
/// ⚠ TARİHSEL SAYILAR SERBESTTİR: "34/165", "53/248" gibi büyüme
/// çizgisi kayıtları geçmişi anlatır ve yasaklanmaz. Kilitlenen şey
/// yalnız GÜNCEL DURUMU söyleyen cümlelerdir.
String _oku(String p) => File(p).readAsStringSync();

void main() {
  final kategoriSayisi = kCategoryTree.length;
  final hizmetSayisi = kTreeServices.length;

  group('1 — Güncel sayıyı söyleyen yorumlar', () {
    test('category_tree başlığı gerçek sayımı yazar', () {
      final ilkSatir = _oku('lib/data/category_tree.dart').split('\n').first;
      expect(
        ilkSatir,
        '/// HİZMET KATALOĞU — $kategoriSayisi ANA KATEGORİ · '
        '$hizmetSayisi ALT HİZMET',
        reason: 'katalog büyüdüyse dosya başlığı da güncellenmeli',
      );
    });

    test('service_aliases katalog boyutunu doğru anlatır', () {
      final k = _oku('lib/data/service_aliases.dart');
      expect(
        k.contains('$kategoriSayisi ana kategori / $hizmetSayisi alt hizmet'),
        isTrue,
        reason: 'alias belgesi eski katalog boyutunu söylüyor',
      );
    });

    test('arama sözlüğü kapsam sayısını doğru anlatır', () {
      final k = _oku('lib/data/arama_es_anlamlilari.dart');
      expect(
        k.contains('⚠ $hizmetSayisi ALT HİZMETİN TAMAMI KAPSANIR'),
        isTrue,
        reason: 'sözlük kapsam iddiası eski sayıda kalmış',
      );
    });

    test('izmir.dart kategori kaynağını doğru anlatır', () {
      final k = _oku('lib/data/izmir.dart');
      expect(
        k.contains('($kategoriSayisi kategori, $hizmetSayisi alt hizmet)'),
        isTrue,
        reason: 'tek kaynak notu eski sayıda kalmış',
      );
    });
  });

  group('2 — Kaldırılmış yapıyı GÜNCELMİŞ gibi anlatan yorum kalmaz', () {
    test('category_tree hızlı erişim satırını yaşıyormuş gibi anlatmaz', () {
      final k = _oku('lib/data/category_tree.dart');
      expect(k.contains('`kHizliKategoriler`'), isFalse,
          reason: 'ana sayfadaki 12 ikonluk hızlı erişim satırı 15 Ağu\'da '
              'kaldırıldı; yerine ÇATI katmanı geldi');
      expect(k.contains('kHizliKategoriler = ['), isFalse);
    });

    test('katalog HTML\'den bağımsız olduğunu söyler', () {
      final k = _oku('lib/data/izmir.dart');
      expect(k.contains('referans HTML\'deki'), isFalse,
          reason: 'kategori verisi artık HTML\'den GELMİYOR; '
              'HTML yalnız UI/UX referansıdır');
    });
  });

  group('3 — Sözlük kapsamı iddiası gerçekten doğru mu', () {
    test('her alt hizmetin en az bir terimi var', () {
      // ⚠ Yorumun doğru SAYIYI yazması yetmez; söylediği ŞEY de doğru
      // olmalı. "TAMAMI KAPSANIR" cümlesi burada ölçülür.
      final hizmetler = kTreeServices.map((e) => e.service).toSet();
      expect(hizmetler.length, hizmetSayisi,
          reason: 'aynı adlı hizmet iki kez geçiyor');
    });
  });
}
