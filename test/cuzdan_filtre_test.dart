// CÜZDAN — FİLTRELEME TASARIMI
//
// KARAR: "Tümünü Gör / Daha Az Gör" bağlantısı ve altındaki yatay
// kaydırmalı hap çubuğu (`.wx-pills`) KALDIRILDI.
//
// Yerine uygulamanın diğer ekranlarıyla aynı desen kondu:
//   `RefPillButton(ic_filter, 'Filtrele')` → `RefBottomSheet` →
//   alt alta `RefSecimKarti` seçenekleri.
//
// GEREKÇE: beş hap küçük ekrana sığmıyordu; sonuncusu ("İletişim
// Açma") kenardan taşıyor, yatay kaydırmadan görünmüyordu.
//
// ⚠ Bu dosya KAYNAK METNİ denetler ve YORUM SATIRLARINI ELER; aksi
// hâlde kaldırma gerekçesini anlatan açıklamalar yanlış alarm verir.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) {
  final f = File(yol);
  // ⚠ BURADA `expect` KULLANILMAZ.
  //
  // Bu yardımcı `group(...)` gövdesinde de çağrılıyor; `expect` bir
  // test gövdesi dışında çalışınca `OutsideTestException` atar ve
  // DOSYANIN TAMAMI yüklenemez ("Failed to load"). Eksik dosya
  // durumu düz bir istisnayla bildirilir.
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  final k = _kod('lib/screens/wallet_screen.dart');

  group('ESKİ FİLTRE YÜZEYİ KALDIRILDI', () {
    test('"Tümünü Gör" / "Daha Az Gör" bağlantısı yok', () {
      expect(k.contains('Tümünü Gör'), isFalse);
      expect(k.contains('Daha Az Gör'), isFalse);
    });

    test('yatay hap çubuğu ve `_chip` yardımcısı yok', () {
      expect(k.contains('_chip('), isFalse);
      expect(k.contains('scrollDirection: Axis.horizontal'), isFalse,
          reason: 'yatay kaydırmalı filtre çubuğu geri gelmiş');
    });

    test('`_hepsi` durumu yok — tek bayrak `_filtreli`', () {
      expect(k.contains('_hepsi'), isFalse);
      expect(k.contains('bool _filtreli = false;'), isTrue);
    });
  });

  group('YENİ FİLTRE DÜĞMESİ', () {
    test('başlığın sağında "Filtrele" hap düğmesi var', () {
      expect(k.contains("label: 'Filtrele'"), isTrue);
      expect(k.contains("iconAsset: 'assets/svg/ic_filter.svg'"), isTrue);
      expect(k.contains('onTap: _filtrePaneli'), isTrue);
    });

    test('"Son İşlemler" başlığı korundu', () {
      expect(k.contains("Text('Son İşlemler'"), isTrue);
    });
  });

  group('FİLTRE FORMU — YARIM EKRAN', () {
    test('uygulamanın ortak panel bileşenlerini kullanır', () {
      expect(k.contains('RefBottomSheet.goster'), isTrue);
      expect(k.contains("title: 'Filtrele'"), isTrue);
      expect(k.contains('RefSecimKarti('), isTrue);
    });

    test('BEŞ seçenek de formda — hiçbiri taşmaz', () {
      for (final s in [
        "baslik: 'Tümü'",
        'Yüklemeler',
        'Blokeler',
        'İadeler',
        'İletişim Açma',
      ]) {
        expect(k.contains(s), isTrue, reason: s);
      }
    });

    test('her seçeneğin AÇIKLAMASI var', () {
      // `RefSecimKarti` başlık + açıklama ister; açıklamasız kart
      // desenin dışına düşer.
      expect(k.contains('String _txDesc(TxKind k)'), isTrue);
      expect(k.contains('aciklama: _txDesc(k)'), isTrue);
      expect(k.contains("aciklama: 'Bütün cüzdan hareketleri'"), isTrue);
    });

    test('seçim ANINDA uygulanır — ayrı "Uygula" düğmesi yok', () {
      expect(k.contains("'Uygula'"), isFalse);
      expect(k.contains('_filtreli = true;'), isTrue);
    });
  });

  group('UYGULANMIŞ FİLTRE GÖRÜNÜR VE TEMİZLENEBİLİR', () {
    test('şerit filtre adını ve işlem sayısını yazar', () {
      expect(k.contains('filtreEtiketi'), isTrue);
      expect(k.contains(r'${txs.length} işlem'), isTrue);
    });

    test('"Temizle" özet görünüme döndürür', () {
      expect(k.contains("'Temizle'"), isTrue);
      expect(k.contains('_filtreli = false;'), isTrue);
    });

    test('filtre yokken ÖZET: son 5 işlem', () {
      expect(k.contains('wallet.txs.take(5)'), isTrue);
    });

    test('boş durum metni filtreye göre değişir', () {
      // Filtre uygulanmamışken "Bu filtrede işlem yok." demek yanlıştı.
      expect(k.contains("'Henüz cüzdan hareketiniz yok.'"), isTrue);
      expect(k.contains("'Bu filtrede işlem yok.'"), isTrue);
    });
  });


  group('İŞLEM SATIRI — TARİH VAR, İKON YOK', () {
    final w = _kod('lib/screens/wallet_screen.dart');
    final m = _kod('lib/data/models/wallet.dart');

    test('her işlem TARİH ve SAAT gösterir', () {
      expect(w.contains('Text(t.zamanMetni,'), isTrue);
      expect(m.contains('String get zamanMetni =>'), isTrue);
    });

    test('zaman biçimi TEK YERDE ve KESİN', () {
      // Göreli ifade ("2 saat önce") kullanılmaz: cüzdan muhasebe
      // kaydıdır, hangi gün ve saatte ne olduğu kesin görünmeli.
      expect(m.contains('saat önce'), isFalse);
      expect(m.contains('dk önce'), isFalse);
      expect(m.contains("' · '"), isFalse,
          reason: 'biçim parçalanmış');
      expect(m.contains('padLeft(2'), isTrue);
    });

    test('işlem zamanı DIŞARIDAN verilebilir', () {
      // Eskiden her zaman DateTime.now() idi; sunucudan gelen geçmiş
      // hareketler OKUNDUKLARI ana damgalanıyordu.
      expect(m.contains('DateTime? time,'), isTrue);
      expect(m.contains('time = time ?? DateTime.now()'), isTrue);
      final mp = _kod('lib/data/remote/mappers.dart');
      expect(mp.contains("DateTime.tryParse((j['createdAt']"), isTrue);
    });

    test('LİSTEDE ikon ÇİZİLMEZ', () {
      // Liste gövdesi: itemBuilder'dan filtre paneli METODUNA kadar.
      //
      // ⚠ Sınır `'_filtrePaneli'` ARAMASIYLA BULUNMAZ: o ad daha
      // YUKARIDA, "Filtrele" düğmesinin `onTap`'inde de geçiyor ve
      // pencere TERSE dönüyordu (bitiş < başlangıç). Metot tanımı
      // aranır.
      final i = w.indexOf('itemBuilder: (_, i) {');
      final j = w.indexOf('Future<void> _filtrePaneli()');
      expect(i, greaterThan(0));
      expect(j, greaterThan(i), reason: 'pencere sınırı ters');
      final govde = w.substring(i, j);
      expect(govde.contains('shape: BoxShape.circle'), isFalse,
          reason: 'daire ikon geri gelmiş');
      expect(govde.contains('RefSvg(ic,'), isFalse,
          reason: 'işlem ikonu geri gelmiş');
      // Aynı pencerede tarih ÇİZİLİYOR olmalı.
      expect(govde.contains('Text(t.zamanMetni,'), isTrue);
    });

    test('filtre panelindeki rozetler KORUNDU', () {
      // `_txUi` yalnız orada kullanılır.
      expect(w.contains('ikon: _txUi(k).\$1'), isTrue);
    });
  });
}
