// KART FORMU · BAKİYE YÜKLEME · ÜCRETSİZ HAK GÖRÜNÜRLÜĞÜ
//
// Bu dosya üç kararı kilitler:
//   1. Ücretsiz İletişim Hakkı kartı YALNIZ hakkı olan hizmet verende
//      görünür; hak bitince kendiliğinden kalkar.
//   2. Bakiye yükleme minimumu KESİN sınırdır ve uyarı ekranda BİR KEZ
//      yazar.
//   3. Kart formu doldurulabilir; "Kartı Kaydet" yalnız dört alan da
//      geçerliyken aktifleşir, fazladan hane girilemez.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR; aksi
// hâlde kaldırma gerekçesini anlatan açıklamalar yanlış alarm verir.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/kart_kurallari.dart';
import 'package:hizmetcep/domain/config.dart';

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
  // ── 1. KART AİLESİ VE HANE SAYISI ───────────────────────────────
  group('KART AİLESİ', () {
    test('Amex 34/37 → 15 hane, 4 haneli güvenlik kodu', () {
      expect(kartAilesi('378282246310005'), KartAilesi.amex);
      expect(kartAilesi('34'), KartAilesi.amex);
      expect(kartHaneSayisi('378282246310005'), 15);
      expect(kartCvvUzunlugu('378282246310005'), 4);
    });

    test('Diners 36/38/30x → 14 hane', () {
      expect(kartAilesi('36227206271667'), KartAilesi.diners);
      expect(kartAilesi('305'), KartAilesi.diners);
      expect(kartHaneSayisi('36227206271667'), 14);
    });

    test('Visa · Mastercard · Troy → 16 hane, 3 haneli kod', () {
      for (final n in [
        '4242424242424242', // Visa
        '5555555555554444', // Mastercard
        '9792030000000000', // Troy
      ]) {
        expect(kartAilesi(n), KartAilesi.standart, reason: n);
        expect(kartHaneSayisi(n), 16, reason: n);
        expect(kartCvvUzunlugu(n), 3, reason: n);
      }
    });
  });

  // ── 2. NUMARA GEÇERLİLİĞİ ───────────────────────────────────────
  group('KART NUMARASI', () {
    test('geçerli test numaraları KABUL edilir', () {
      for (final n in [
        '4242424242424242',
        '5555555555554444',
        '378282246310005',
        '36227206271667',
        '9792030000000000',
      ]) {
        expect(kartNumarasiGecerli(n), isTrue, reason: n);
      }
    });

    test('Luhn tutmayan numara REDDEDİLİR', () {
      expect(kartLuhn('4242424242424241'), isFalse);
      expect(kartNumarasiGecerli('4242424242424241'), isFalse);
    });

    test('EKSİK hane reddedilir — kaydet düğmesi bu yüzden pasif kalır', () {
      expect(kartNumarasiGecerli('424242424242424'), isFalse);
      expect(kartNumarasiGecerli(''), isFalse);
    });

    test('Amex 16 haneye tamamlanamaz — ailesi 15 ister', () {
      expect(kartHaneSayisi('3782822463100051'), 15);
      expect(kartNumarasiGecerli('3782822463100051'), isFalse);
    });

    test('gruplama: Amex 4-6-5, diğerleri 4-4-4-4', () {
      expect(kartNumarasiBicimle('4242424242424242'), '4242 4242 4242 4242');
      expect(kartNumarasiBicimle('378282246310005'), '3782 822463 10005');
    });
  });

  // ── 3. SON KULLANMA VE CVV ──────────────────────────────────────
  group('SON KULLANMA TARİHİ', () {
    final simdi = DateTime(2026, 8, 13);

    test('içinde bulunulan ay HÂLÂ geçerlidir', () {
      expect(kartSonKullanmaGecerli('08/26', simdi: simdi), isTrue);
    });

    test('geçmiş tarih reddedilir', () {
      expect(kartSonKullanmaGecerli('07/26', simdi: simdi), isFalse);
      expect(kartSonKullanmaGecerli('12/25', simdi: simdi), isFalse);
    });

    test('geçersiz ay reddedilir', () {
      expect(kartSonKullanmaGecerli('13/28', simdi: simdi), isFalse);
      expect(kartSonKullanmaGecerli('00/28', simdi: simdi), isFalse);
    });

    test('eksik hane reddedilir', () {
      expect(kartSonKullanmaGecerli('8/26', simdi: simdi), isFalse);
      expect(kartSonKullanmaGecerli('', simdi: simdi), isFalse);
    });
  });

  group('CVV', () {
    test('standart kartta TAM 3 hane', () {
      expect(kartCvvGecerli('123', '4242424242424242'), isTrue);
      expect(kartCvvGecerli('12', '4242424242424242'), isFalse);
      expect(kartCvvGecerli('1234', '4242424242424242'), isFalse);
    });

    test('Amex kartta TAM 4 hane', () {
      expect(kartCvvGecerli('1234', '378282246310005'), isTrue);
      expect(kartCvvGecerli('123', '378282246310005'), isFalse);
    });
  });

  group('KART SAHİBİ ADI', () {
    test('en az iki kelime ister', () {
      expect(kartAdiGecerli('Onur Bütün'), isTrue);
      expect(kartAdiGecerli('Onur'), isFalse);
    });

    test('rakam ve simge kabul edilmez', () {
      expect(kartAdiGecerli('Onur B2tün'), isFalse);
      expect(kartAdiGecerli('Onur_Bütün'), isFalse);
    });
  });

  // ── 4. KART FORMU EKRANI ────────────────────────────────────────
  group('KART FORMU AÇIKTIR, DÜĞME KOŞULLUDUR', () {
    final k = _kod('lib/screens/widgets/saved_cards_section.dart');

    test('alanlar sağlayıcıdan bağımsız DOLDURULABİLİR', () {
      expect(k.contains('enabled: kullanilabilir'), isFalse,
          reason: 'alanlar yine sağlayıcıya bağlanmış');
      expect(k.contains('kullanilabilir'), isFalse,
          reason: 'eski tek bayrak kalmış');
      expect(k.contains('saglayiciHazir'), isTrue);
    });

    test('varsayılan kart onay kutusu işaretlenebilir', () {
      expect(k.contains('onChanged: (v) => setState(() => _varsayilanYap'),
          isTrue);
    });

    test('"Kartı Kaydet" YALNIZ form geçerliyse aktif', () {
      expect(k.contains('bool get _formGecerli'), isTrue);
      expect(k.contains('onPressed:\n                _formGecerli'), isTrue);
    });

    test('dört alanın dördü de geçerlilik koşuluna girer', () {
      for (final f in [
        'kartAdiGecerli(_ad.text)',
        'kartNumarasiGecerli(_haneler)',
        'kartSonKullanmaGecerli(_sonKullanma.text)',
        'kartCvvGecerli(_cvv.text, _haneler)',
      ]) {
        expect(k.contains(f), isTrue, reason: f);
      }
    });

    test('hane sınırı SABİT DEĞİL, aileye göre daralır', () {
      expect(k.contains('LengthLimitingTextInputFormatter(16)'), isFalse,
          reason: 'sabit 16 sınırı Amex/Diners için yanlıştı');
      expect(k.contains('kartHaneSayisi(rakam)'), isTrue);
      expect(k.contains('LengthLimitingTextInputFormatter(kartCvvUzunlugu('),
          isTrue);
    });

    test('kurallar TEK MERKEZDE — yerel Luhn kopyası yok', () {
      expect(k.contains('bool _luhn('), isFalse);
      expect(k.contains("import '../../core/kart_kurallari.dart';"), isTrue);
    });

    test('sağlayıcı yoksa SAHTE BAŞARI yok', () {
      // Düğme aktifleşse bile tokenizasyon açık hata fırlatır.
      expect(k.contains('CardTokenizationException'), isTrue);
      expect(k.contains('PROVIDER_NOT_CONFIGURED'), isTrue);
    });
  });

  // ── 5. BAKİYE YÜKLEME ───────────────────────────────────────────
  group('BAKİYE YÜKLEME MİNİMUMU', () {
    final k = _kod('lib/screens/topup_screen.dart');

    test('minimum 500 TL', () {
      expect(DomainConfig.minTopup, 500);
    });

    test('uyarı ekranda TEK KEZ yazar', () {
      final adet = 'Minimum yükleme tutarı'.allMatches(k).length;
      expect(adet, 2,
          reason: 'ekranda bir yardım metni + bir hata mesajı olmalı, '
              'üstteki bilgi kutusu kaldırıldı (bulunan: $adet)');
      expect(k.contains('InfoBox'), isFalse,
          reason: 'üstteki minimum tutar bilgi kutusu geri gelmiş');
    });

    test('minimumun ALTINDA düğme pasif', () {
      expect(k.contains('bool get _tutarGecerli'), isTrue);
      expect(k.contains('onPressed: _tutarGecerli ? _bakiyeYukle : null'),
          isTrue);
    });

    test('sunucu çağrısı da ayrıca korunur', () {
      expect(k.contains('if (!_tutarGecerli) {'), isTrue,
          reason: 'ikinci savunma kalkmış');
    });
  });

  // ── 6. ÜCRETSİZ HAK GÖRÜNÜRLÜĞÜ ─────────────────────────────────
  group('ÜCRETSİZ İLETİŞİM HAKKI KARTI', () {
    final k = _kod('lib/screens/wallet_screen.dart');

    test('hak yoksa kart HİÇ çizilmez', () {
      expect(
          k.contains('if (ctl.loading || ozet == null || kalan <= 0 || '
              '!ozet.hasUsableRight) {'),
          isTrue,
          reason: 'görünürlük kapısı kalkmış');
      expect(k.contains('return const SizedBox.shrink();'), isTrue);
    });

    test('"hakkınız bulunmuyor" metni kalmadı', () {
      expect(k.contains('Kullanılabilir ücretsiz hakkınız bulunmuyor.'),
          isFalse);
    });

    test('kart gizlenince BOŞLUK da kalmaz', () {
      // Dolgu kartın içindedir; dış `Padding` sarmalayıcı yoktur.
      expect(k.contains('child: _FreeRightCard()'), isFalse);
      expect(k.contains('const _FreeRightCard(),'), isTrue);
      expect(k.contains('margin: const EdgeInsets.fromLTRB(20, 14, 20, 0)'),
          isTrue);
    });
  });


  group('TEK İŞLEMDE ÜST SINIR', () {
    String _kod(String yol) => File(yol)
        .readAsStringSync()
        .split('\n')
        .where((l) =>
            !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
        .join('\n');

    final t = _kod('lib/screens/topup_screen.dart');

    test('SINIR 10000 TL ve tek kaynaktan', () {
      expect(DomainConfig.maxTopup, 10000);
      // ⚠ Sayı ekrana GÖMÜLMEZ; iki yerde farklı kalırsa kural çatlar.
      expect(t.contains('DomainConfig.maxTopup'), isTrue);
      expect(t.contains('> 10000'), isFalse, reason: 'ham sayı gömülmüş');
    });

    test('geçerlilik ALT ve ÜST sınırı birlikte arar', () {
      expect(t.contains('_girilenTutar <= DomainConfig.maxTopup'), isTrue);
      expect(t.contains('_girilenTutar >= DomainConfig.minTopup'), isTrue);
    });

    test('HANE SINIRI var — altıncı hane girilemez', () {
      // 10000 beş hanedir; 100000 yazılamaz.
      expect(t.contains('LengthLimitingTextInputFormatter'), isTrue);
      expect(t.contains("'\${DomainConfig.maxTopup}'.length"), isTrue);
    });

    test('UYARI YALNIZ SINIR AŞILINCA', () {
      // ⚠ Sürekli görünen bir üst sınır satırı istenmedi: metin ancak
      // girilen tutar sınırı geçince değişir.
      expect(t.contains('_tutarCokFazla'), isTrue);
      expect(t.contains('_tutarCokFazla\n                ?'), isTrue,
          reason: 'uyarı koşulsuz gösteriliyor');
    });

    test('İKİNCİ SAVUNMA: gönderimde de denetlenir', () {
      // Düğme pasif olsa bile kural yayınlama yolunda tekrar bakılır.
      final i = t.indexOf('Future<void> _bakiyeYukle()');
      expect(i, greaterThan(-1));
      final govde = t.substring(i, i + 900);
      expect(govde.contains('_tutarCokFazla'), isTrue);
    });

    test('SINIR MESAJI tek cümle', () {
      expect(
          t.contains(
              "Bir işlemde en fazla \${DomainConfig.maxTopup} TL "),
          isTrue);
    });
  });
}
