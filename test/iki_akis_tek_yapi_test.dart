// İKİ AKIŞ, TEK DETAY YAPISI (KİLİT)
//
// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "İlan oluştururken görülen ekran
// Bul ekranında da aynı düzende olmalı. Aynı butonlar, aynı yerleşim,
// aynı assetler. Hizmet veren ilanı nereden oluşturursa oluştursun
// aynı ekran yapısını görmeli."
//
// ⚠ ÖNCEKİ DURUM: iki ekran aynı bilgiyi farklı çiziyordu.
//   · Bul tarafında ilan numarası HİÇ YOKTU.
//   · Karşı taraf özeti EN ALTTA, ayrı bir kartta duruyordu.
//   · Bilgi tablosu (konum + tarih) yoktu; tarih hiçbir yerde
//     görünmüyordu.
//   · İletişim kutuları daha küçük bir KOPYAYDI (`_MiniIletisimKutusu`):
//     farklı daire çapı, farklı punto, kilit rozeti yok.
//   · Bölüm etiketleri ayrıydı: "Hizmet Zamanı" / "Zaman tercihi",
//     "Açıklama" / "İşin detayı".
//
// ⚠ SEBEP, ilan akışının parçalarının `private` olmasıydı: Bul akışı
// onları GÖREMİYOR, benzerini yazıyordu. Dart dosyalar arası private
// import etmez — bu yüzden "kopyala ve uyarla" tek yol gibi
// görünüyordu. Parçalar ortak dosyaya çıkarıldı.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/repositories/ilan_no_uretici.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final ilan = _kod('lib/screens/job_detail_screen.dart');
  final bul = _kod('lib/screens/teklif_talebi_detay_screen.dart');
  final ortak = _kod('lib/screens/widgets/detay_karti_parcalari.dart');

  group('1 — ⚠ PARÇALAR ORTAK DOSYADA, PRIVATE DEĞİL', () {
    test('üç parça ortak dosyada tanımlı', () {
      expect(ortak.contains('class SahipKarti'), isTrue);
      expect(ortak.contains('class BilgiSatiri'), isTrue);
      expect(ortak.contains('class IletisimKutusu'), isTrue);
    });

    test('⚠ İLAN EKRANINDA PRIVATE KOPYA KALMADI', () {
      // Kopyalar burada yaşıyordu; ortak dosyaya taşındılar.
      expect(ilan.contains('class _SahipKarti'), isFalse);
      expect(ilan.contains('class _BilgiSatiri'), isFalse);
      expect(ilan.contains('class _IletisimKutusu'), isFalse);
    });

    test('⚠ BUL EKRANINDA KÜÇÜLTÜLMÜŞ KOPYA KALMADI', () {
      expect(bul.contains('_MiniIletisimKutusu'), isFalse,
          reason: 'aynı iki düğme yine iki farklı boyda çizilir');
    });

    test('iki ekran da ortak parçaları çağırır', () {
      for (final e in {'ilan': ilan, 'bul': bul}.entries) {
        expect(e.value.contains('SahipKarti('), isTrue, reason: e.key);
        expect(e.value.contains('BilgiSatiri('), isTrue, reason: e.key);
        expect(e.value.contains('IletisimKutusu('), isTrue, reason: e.key);
        expect(e.value.contains('IlanNoEtiketi('), isTrue, reason: e.key);
        expect(e.value.contains('IlanBaslikSatiri('), isTrue, reason: e.key);
      }
    });
  });

  group('2 — ⚠ AYNI SIRA', () {
    // numara → karşı taraf → başlık satırı → bilgi tablosu
    test('ilan ekranında sıra', () {
      expect(ilan.indexOf('IlanNoEtiketi('),
          lessThan(ilan.indexOf('SahipKarti(')));
      expect(ilan.indexOf('SahipKarti('),
          lessThan(ilan.indexOf('IlanBaslikSatiri(')));
      expect(ilan.indexOf('IlanBaslikSatiri('),
          lessThan(ilan.indexOf('BilgiSatiri(')));
    });

    test('bul ekranında AYNI sıra', () {
      expect(bul.indexOf('IlanNoEtiketi('),
          lessThan(bul.indexOf('SahipKarti(')));
      expect(bul.indexOf('SahipKarti('),
          lessThan(bul.indexOf('IlanBaslikSatiri(')));
      expect(bul.indexOf('IlanBaslikSatiri('),
          lessThan(bul.indexOf('BilgiSatiri(')));
    });

    test('⚠ BÖLÜM ETİKETLERİ AYNI', () {
      for (final e in {'ilan': ilan, 'bul': bul}.entries) {
        expect(e.value.contains("'Zaman tercihi'"), isTrue, reason: e.key);
        expect(e.value.contains("'İşin detayı'"), isTrue, reason: e.key);
      }
      // Eski adlar geri gelmemeli.
      expect(bul.contains("'Hizmet Zamanı'"), isFalse);
      expect(bul.contains("Text('Açıklama',"), isFalse);
    });

    test('⚠ BAŞLIK KAYDIN GERÇEK ADINI SÖYLER', () {
      // Bul akışında ortada bir ilan yok; "İlan Detayı" olmayan bir
      // nesneye atıfta bulunurdu. Aynı gerekçeyle tarih satırı da
      // "Talep Tarihi".
      expect(ilan.contains("'İlan Detayı'"), isTrue);
      expect(bul.contains("'Talep Detayı'"), isTrue);
      expect(bul.contains("'İlan Detayı'"), isFalse);
      expect(ilan.contains("'İlan Tarihi'"), isTrue);
      expect(bul.contains("'Talep Tarihi'"), isTrue);
    });

    test('⚠ NOT BÖLÜMÜ EN ALTTA KALDI (kullanıcı şartı)', () {
      // ⚠ AD DEĞİŞTİ (12 Eyl): "Açıklamanız" → "Notunuz". Şart
      // bölümün ADI değil, VARLIĞI ve yeriydi.
      final ham = File('lib/screens/teklif_talebi_detay_screen.dart')
          .readAsStringSync();
      expect(ham.contains("Text('Notunuz'"), isTrue,
          reason: 'teklif formundaki not alanı kaldırılmış');
    });
  });

  group('3 — ⚠ NUMARA: TEK DİZİ, TEK BİÇİM', () {
    setUp(IlanNoUretici.sifirlaTestIcin);

    test('ilan ve talep AYNI diziden numara alır', () {
      // İki ayrı sayaç tutulsaydı aynı numara hem bir ilanda hem bir
      // talepte çıkabilirdi; "#10458231" referansı belirsizleşirdi.
      final a = IlanNoUretici.uret();
      final b = IlanNoUretici.uret();
      expect(a, IlanNoUretici.kBaslangic.toString());
      expect(b, (IlanNoUretici.kBaslangic + 1).toString());
      expect(a == b, isFalse);
    });

    test('⚠ NUMARA YENİDEN KULLANILMAZ', () {
      // Kayıt silinse de sayaç geri alınmaz: destek kayıtlarındaki
      // eski referanslar yanlış kayda düşmesin.
      final ilk = IlanNoUretici.uret();
      IlanNoUretici.rezerveEt((IlanNoUretici.kBaslangic + 1).toString());
      final sonra = IlanNoUretici.uret();
      expect(sonra == ilk, isFalse);
      expect(sonra, (IlanNoUretici.kBaslangic + 2).toString());
    });

    test('⚠ BİÇİM TEK YERDE', () {
      expect(IlanNoUretici.etiket('10458231'), '#10458231');
      // Modeller kendi biçimlerini yazmaz.
      final l = _kod('lib/data/models/listing.dart');
      expect(l.contains("'#\$ilanNo'"), isFalse);
    });

    test('talep deposu numara verir', () {
      final r = _kod('lib/data/repositories/teklif_talebi_repository.dart');
      expect(r.contains('talepNo: IlanNoUretici.uret()'), isTrue);
      final li = _kod('lib/data/repositories/listing_repository.dart');
      expect(li.contains('IlanNoUretici.uret()'), isTrue);
      // İkinci bir sayaç açılmamalı.
      expect(li.contains('_sonrakiIlanNo'), isFalse);
    });
  });
}
