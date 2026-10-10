// ÜÇ NOKTA MENÜSÜ — YALNIZ AÇIK İŞLERDE (KİLİT)
//
// ⚠ KULLANICI KARARI (12 Eyl): "Hizmet alan tamamlanan işler kart
// detay ekranına girince sağ üst köşedeki üç noktalar kaldırılmalı.
// Doğrudan teklif ve ilan oluşturma ile gelen teklifler — sadece bu
// özellik açık işlerde olacak, tamamlanan işlerde buna gerek yok."
//
// ⚠ MENÜ TEK BİR ŞEY YAPAR: kaydı siler. İş bir kez karara
// bağlandıysa silmek bir kaydı yok etmektir — tamamlanmış işin
// yorumu, puanı ve karşı tarafın geçmişi ona bağlıdır.
//
// ⚠ KOŞUL EKRANDA DEĞİL MODELDE. İki akışın iki ayrı ekranı var; her
// biri kendi koşulunu yazsaydı biri güncellenip öteki eskide kalırdı
// — bu depoda tam olarak böyle onlarca ayrışma yaşandı.
//   · İlan akışı  → `Listing.acceptsOffers` (aktif VE tamamlanmamış)
//   · Bul akışı   → `TeklifTalebi.silinebilir`

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

TeklifTalebi _talep(TeklifTalebiDurumu d) => TeklifTalebi(
      id: 't1',
      talepNo: '10458231',
      hizmetAlanId: 'a1',
      saglayiciId: 'v1',
      saglayiciAdi: 'Usta',
      kategori: 'Doğalgaz',
      hizmet: 'Doğalgaz Kaçak Kontrolü',
      aciklama: 'acil',
      iletisimTercihi: IletisimTercihi.telefonGoster,
      durum: d,
      createdAt: DateTime(2026, 9, 12),
    );

void main() {
  group('1 — ⚠ AÇIK TALEP: SİLİNEBİLİR', () {
    test('yanıt beklenirken ve teklif geldiğinde', () {
      // Bu iki durumda ortada henüz bir İŞ yok; hizmet alan isteğini
      // geri çekebilmeli.
      expect(_talep(TeklifTalebiDurumu.beklemede).silinebilir, isTrue);
      expect(_talep(TeklifTalebiDurumu.teklifGeldi).silinebilir, isTrue);
    });
  });

  group('2 — ⚠ KARARA BAĞLANMIŞ TALEP: SİLİNEMEZ', () {
    test('seçildi ve tamamlandı', () {
      // Seçildikten sonra ortada bir iş vardır; tamamlandıktan sonra
      // ise yorum ve puan bu kayda bağlıdır.
      expect(_talep(TeklifTalebiDurumu.secildi).silinebilir, isFalse);
      expect(_talep(TeklifTalebiDurumu.tamamlandi).silinebilir, isFalse);
    });

    test('⚠ REDDEDİLDİ VE SÜRESİ DOLDU DA KAPSAM DIŞI', () {
      // İkisi de sonuçlanmış kayıttır. "Açık" olan yalnız yukarıdaki
      // iki durumdur.
      expect(_talep(TeklifTalebiDurumu.reddedildi).silinebilir, isFalse);
      expect(_talep(TeklifTalebiDurumu.suresiDoldu).silinebilir, isFalse);
    });
  });

  group('3 — ⚠ EKRANLAR KENDİ KOŞULUNU YAZMAZ', () {
    test('Bul akışı modeldeki kuralı okur', () {
      final k = _kod('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('t.silinebilir'), isTrue,
          reason: 'menü koşulsuz ya da elle yazılmış bir koşulla çiziliyor');
      expect(k.contains('ic_dots.svg'), isTrue,
          reason: 'menü tümden kaldırılmış — açık taleplerde kalmalı');
    });

    test('İlan akışı zaten tamamlanmışta menü çizmez', () {
      final k = _kod('lib/screens/listing_detail_screen.dart');
      expect(
          k.contains(
              'l.status == ListingStatus.active && !l.isTamamlanmisIs'),
          isTrue,
          reason: 'tamamlanmış ilanda üç nokta geri gelmiş');
    });

    test('⚠ HİZMET VERENDE HİÇ ÇİZİLMEZ', () {
      // Menü silme içindir; hizmet verenin böyle bir yetkisi yok.
      final k = _kod('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('if (!benSaglayiciMi && t.silinebilir)'), isTrue);
    });
  });
}
