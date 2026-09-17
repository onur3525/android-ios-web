// ÇIKAR ÇATIŞMASI — HİZMET VEREN KENDİ ALANINDA İLAN AÇAMAZ
//
// İŞ KURALI: kullanıcı hizmet veren rolünde bir kategoride
// çalışıyorsa, hizmet alan rolünde AYNI kategoride ilan açamaz.
// Aksi hâlde rakiplerinden teklif toplayıp fiyat öğrenebilir.
//
// ⚠ KAPSAM DARALDI (kullanıcı kararı, 9 Eyl): denetim artık SEÇİLEN
// HİZMET düzeyindedir. "Doğalgaz Kaçağı" sunan biri "Doğalgaz
// Tesisatı" ilanı AÇABİLİR. Yalnız ANA KATEGORİYİ bütün olarak
// seçmişse o kategorinin tamamı kapanır — kategoriyi bütün olarak
// seçmek, o alandaki her işi yaptığını beyan etmektir.
//
// ⚠ ESKİ GEREKÇE GEÇERSİZ KALDI: "alt hizmetler aynı ustanın işidir"
// varsayımı katalog büyüdükçe tutmuyor.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/cikar_catismasi.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  group('KURAL', () {
    test('ana kategoride hizmet veren o kategoride ilan AÇAMAZ', () {
      const secim = {'Su Tesisatı'};
      expect(catisanKategori(
              saglayiciSecimleri: secim, ilanBasligi: 'Su Tesisatı'),
          'Su Tesisatı');
      expect(
          ilanAcilabilir(saglayiciSecimleri: secim, ilanBasligi: 'Su Tesisatı'),
          isFalse);
    });

    test('⚠ ALT HİZMET SEÇİMİ YALNIZ O HİZMETİ KAPATIR', () {
      // KULLANICI BULGUSU (9 Eyl): "Doğalgaz kaçağı ve tespiti
      // hizmeti veren biri, doğalgazın DİĞER hizmetleri için hizmet
      // alabilmeli."
      const secim = {'Kombi Bakımı'};
      expect(
          catisanKategori(
              saglayiciSecimleri: secim, ilanBasligi: 'Kombi Bakımı'),
          'Kombi Bakımı',
          reason: 'kendi sunduğu hizmette hâlâ ilan açamaz');
      expect(
          ilanAcilabilir(
              saglayiciSecimleri: secim, ilanBasligi: 'Kombi Tamiri'),
          isTrue,
          reason: 'aynı kategorideki BAŞKA hizmet için ilan açabilmeli');
    });

    test('⚠ ANA KATEGORİYİ SEÇEN TÜM KATEGORİYİ KAPATIR', () {
      // Kategoriyi bütün olarak seçmek, o alandaki her işi yaptığını
      // beyan etmektir.
      const secim = {'Kombi Servis'};
      expect(
          catisanKategori(
              saglayiciSecimleri: secim, ilanBasligi: 'Kombi Tamiri'),
          'Kombi Servis');
    });

    test('⚠ KURAL TEK SATIRLA DELİNEMEZ', () {
      // Alt hizmet sunan biri, ANA KATEGORİ başlığıyla ilan açarak
      // kendi hizmetini de kapsayan bir talep oluşturabilirdi.
      const secim = {'Kombi Bakımı'};
      expect(
          ilanAcilabilir(
              saglayiciSecimleri: secim, ilanBasligi: 'Kombi Servis'),
          isFalse);
    });

    test('BAŞKA kategoride ilan açabilir', () {
      const secim = {'Su Tesisatı', 'Kombi Bakımı'};
      expect(
          ilanAcilabilir(
              saglayiciSecimleri: secim, ilanBasligi: 'Ev Temizliği'),
          isTrue);
      expect(
          ilanAcilabilir(
              saglayiciSecimleri: secim, ilanBasligi: 'Boya ve Badana'),
          isTrue);
    });

    test('hizmet veren DEĞİLSE kural uygulanmaz', () {
      expect(
          ilanAcilabilir(
              saglayiciSecimleri: const <String>[],
              ilanBasligi: 'Su Tesisatı'),
          isTrue);
    });

    test('katalogda olmayan başlık çatışma üretmez', () {
      expect(
          catisanKategori(
              saglayiciSecimleri: const {'Su Tesisatı'},
              ilanBasligi: 'Böyle Bir Hizmet Yok'),
          isNull);
    });

    test('birden çok seçimde HER BİRİ kendi hizmetini kapatır', () {
      const secim = {'Su Tesisatı', 'Elektrik Tesisatı', 'Halı Yıkama'};
      for (final b in secim) {
        expect(ilanAcilabilir(saglayiciSecimleri: secim, ilanBasligi: b),
            isFalse,
            reason: b);
      }
    });

    test('mesaj ne yapılacağını söyler', () {
      final m = catismaMesaji('Su Tesisatı');
      expect(m.contains('Su Tesisatı'), isTrue);
      expect(m.contains('ilan açamazsınız'), isTrue);
      expect(m.contains('Hizmet Kategorilerim'), isTrue);
    });

    test('⚠ MESAJ KATEGORİ DEĞİL HİZMET DER', () {
      // Kural daraldığına göre metin de daralmalı; yoksa kullanıcı
      // öteki hizmetler için de açamayacağını sanır.
      expect(catismaMesaji('Kombi Bakımı').contains('bu hizmet için'),
          isTrue);
      expect(catismaMesaji('Kombi Bakımı').contains('bu kategoride'),
          isFalse);
    });
  });

  group('UYGULANDIĞI YERLER', () {
    test('kural TEK KAYNAKTA — port kendi kopyasını yazmaz', () {
      final m = _kod('lib/data/ports/mock_ports.dart');
      expect(m.contains('catisanKategori('), isTrue);
      expect(m.contains('catismaMesaji('), isTrue);
      // Eski yerel kopya kalmamalı.
      expect(m.contains('anaKategorileri(acc.categories).contains(ana)'),
          isFalse);
    });

    test('ilan formunda SEÇİM ANINDA uygulanır', () {
      final c = _kod('lib/screens/create_listing_screen.dart');
      expect(c.contains('void _kategoriSec(String ad)'), isTrue);
      expect(c.contains('catisanKategori('), isTrue);
      expect(c.contains('onTap: () => _kategoriSec(c)'), isFalse,
          reason: 'kart ızgarası geri gelmiş');
      expect(c.contains('_kategoriSec(altHizmet ?? kategori)'), isTrue);
    });

    test('ana sayfa / arama / Tüm Kategoriler yolunda da uygulanır', () {
      // Bu yol formu SEÇİLİ kategoriyle açar; kural orada da gerekir.
      final h = _kod('lib/screens/home_screen.dart');
      expect(h.contains('catisanKategori('), isTrue);
      expect(h.contains('catismaMesaji('), isTrue);
    });

    test('PORT DENETİMİ KALDIRILMADI — ikinci savunma', () {
      final m = _kod('lib/data/ports/mock_ports.dart');
      expect(m.contains('final hata = _cikarCatismasi(ownerId, title);'),
          isTrue);
    });
  });
}
