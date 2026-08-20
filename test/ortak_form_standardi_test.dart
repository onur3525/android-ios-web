// ORTAK FORM STANDARDI — PAKET 1
//
// Kapsam: şifre göz ikonu ölçüsü + ortak alan bileşeninin yetenekleri.
// Ekran ekran davranış standardizasyonu SONRAKİ paketlerde.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    throw StateError('$yol yok');
  }
  return const LineSplitter()
      .convert(f.readAsStringSync())
      .where((l) =>
          !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  final ref = _kod('lib/ui/ref_widgets.dart');

  group('ŞİFRE GÖZÜ — TEK ÖLÇÜ STANDARDI', () {
    test('ikon 24, dokunma alanı 48', () {
      expect(ref.contains('const double kSifreGozuIkon = 24;'), isTrue);
      expect(ref.contains('const double kSifreGozuDokunma = 48;'), isTrue);
    });

    test('varsayılan boyut SABİTTEN gelir', () {
      // Eskiden 20 idi ve ekranlar kendi değerini verebiliyordu.
      expect(ref.contains('this.boyut = kSifreGozuIkon,'), isTrue);
      expect(ref.contains('this.boyut = 20,'), isFalse);
    });

    test('dokunma alanı bileşende zorlanır', () {
      final i = ref.indexOf('class RefSifreGozu');
      final govde = ref.substring(i, i + 1800);
      expect(govde.contains('minWidth: kSifreGozuDokunma'), isTrue);
      expect(govde.contains('minHeight: kSifreGozuDokunma'), isTrue);
      // Sabit 10px dolgu ile 40×40'a düşen eski hâl geri gelmemeli.
      expect(govde.contains('EdgeInsets.all(10)'), isFalse);
    });

    test('HİÇBİR EKRAN kendi ölçüsünü vermez', () {
      // Ölçü ekran ekran verilirse standart yeniden ayrışır.
      for (final f in const [
        'lib/screens/login_screen.dart',
        'lib/screens/register_screen.dart',
        'lib/screens/forgot_password_screen.dart',
        'lib/screens/change_password_screen.dart',
      ]) {
        final k = _kod(f);
        final i = k.indexOf('RefSifreGozu(');
        if (i < 0) {
          continue;
        }
        // Her kullanımda `boyut:` verilmemeli.
        expect(k.contains('RefSifreGozu(\n        boyut:'), isFalse, reason: f);
        expect(k.contains('boyut: 20'), isFalse, reason: f);
      }
    });

    test('basılı tutma davranışı KORUNDU', () {
      // Şifre yalnız parmak basılıyken görünür.
      expect(ref.contains('onPointerDown: (_) => onDegisti(false)'), isTrue);
      expect(ref.contains('onPointerUp: (_) => onDegisti(true)'), isTrue);
      expect(ref.contains('onPointerCancel: (_) => onDegisti(true)'), isTrue);
    });
  });

  group('ORTAK ALAN BİLEŞENİ — YETENEKLER', () {
    test('onChanged ve enabled var', () {
      expect(ref.contains('final ValueChanged<String>? onChanged;'), isTrue);
      expect(ref.contains('final bool enabled;'), isTrue);
    });

    test('parametreler alta GEÇİRİLİYOR', () {
      final i = ref.indexOf('class RefFormField');
      final govde = ref.substring(i, ref.indexOf('class ', i + 10));
      expect(govde.contains('onChanged: onChanged,'), isTrue);
      expect(govde.contains('enabled: enabled,'), isTrue);
    });

    test('giriş ekranı DOLAYLI yola mecbur değil', () {
      // Bu parametreler yokken ekran TextEditingController dinlemek
      // zorunda kalmıştı.
      final l = _kod('lib/screens/login_screen.dart');
      // ⚠ ÜÇ alan: e-posta, telefon, şifre (iki giriş yolu).
      // Sarmalayıcı `_degerDegisti`: hata temizler + düğme tazeler.
      expect('onChanged: (_) => _degerDegisti()'.allMatches(l).length, 3);
      expect(l.contains('addListener(_kimlikHatasiniTemizle)'), isFalse);
    });

    test('istek sürerken alanlar kilitlenir', () {
      final l = _kod('lib/screens/login_screen.dart');
      expect('enabled: !_busy'.allMatches(l).length, 3);
    });
  });


  group('ŞİFRE GÖZÜ — METİN SEÇİM MENÜSÜ AÇILMAZ', () {
    // ⚠ KULLANICININ BULDUĞU KUSUR (14 Ağu):
    //
    // Göz ikonuna basılı tutulduğunda "Paste / Select all" seçim
    // menüsü açılıyordu. Neden: `Listener` ham işaretçi olaylarını
    // dinler ama JEST ARENASINA GİRMEZ; uzun basışı altındaki
    // `TextField` kendi tanıyıcısıyla yakalıyordu.
    //
    // Çözüm: boş `onLongPress`/`onTap` ile jest bu bileşene
    // kazandırılır. Ham basma/bırakma işi `Listener`'da kalır —
    // arena kararı ham olayları engellemez.

    test('göz ikonu jest arenasına girer', () {
      final w = _kod('lib/ui/ref_widgets.dart');
      final i = w.indexOf('class RefSifreGozu');
      expect(i, greaterThan(0));
      final govde = w.substring(i, w.indexOf('class RefSecimKarti'));
      expect(govde.contains('GestureDetector('), isTrue,
          reason: 'jest arenasına girmiyor');
      expect(govde.contains('onLongPress: () {}'), isTrue);
      expect(govde.contains('onTap: () {}'), isTrue);
    });

    test('BASILI TUTMA davranışı korundu', () {
      // Şifre yalnız basılı tutulduğu sürece görünür; bırakınca
      // yeniden maskelenir.
      final w = _kod('lib/ui/ref_widgets.dart');
      final i = w.indexOf('class RefSifreGozu');
      final govde = w.substring(i, w.indexOf('class RefSecimKarti'));
      expect(govde.contains('onPointerDown: (_) => onDegisti(false)'), isTrue);
      expect(govde.contains('onPointerUp: (_) => onDegisti(true)'), isTrue);
      expect(govde.contains('onPointerCancel: (_) => onDegisti(true)'), isTrue);
    });

    test('DOKUNMA ALANI hâlâ 48 birim', () {
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('minWidth: kSifreGozuDokunma'), isTrue);
      expect(w.contains('minHeight: kSifreGozuDokunma'), isTrue);
    });
  });


  group('ZORUNLU YILDIZI TEK YERDE', () {
    // ⚠ Yıldız hem etikette hem alanın içinde çiziliyordu: "Telefon *"
    // başlığı ve hemen altındaki kutuda ikinci bir yıldız. Aynı bilgi
    // iki kez yazılıyordu.

    test('⚠ ETİKET KUTUNUN DIŞINDA, YILDIZ ETİKETTE', () {
      // ── ÜRÜN KARARI DEĞİŞTİ ──
      //
      // 16 Ağu'da etiketler kaldırılıp alan adı yer tutucuya, yıldız
      // da yer tutucunun sonuna taşınmıştı. Sorun: kullanıcı alanı
      // DOLDURUNCA ad kayboluyor ve formu gözden geçirirken hangi
      // kutunun ne olduğu görünmüyordu.
      //
      // Nihai düzen:
      //
      //     Ad *
      //     [                    ]
      //
      final w = _kod('lib/ui/ref_widgets.dart');
      final i = w.indexOf('class RefFieldLabel');
      final govde = w.substring(i, w.indexOf('\n}', i));
      expect(govde.contains('RC.requiredStar'), isTrue,
          reason: 'yıldız etikette çizilmiyor');
    });

    test('⚠ ALAN ADI KUTUNUN İÇİNDE TEKRARLANMAZ', () {
      // İki yerde birden yazılırsa aynı bilgi iki kez görünür.
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('hint: refYerTutucu(hint, zorunlu: zorunlu'), isFalse,
          reason: 'RefFormField adı hâlâ kutunun içine yazıyor');
      expect(w.contains('refYerTutucu(hint!, zorunlu: zorunlu)'), isFalse,
          reason: 'RefTextField adı hâlâ kutunun içine yazıyor');
      // Etiket iki bileşende de kutunun ÜSTÜNDE çiziliyor.
      expect(w.contains('RefFieldLabel(hint, zorunlu: zorunlu, ilk: true)'),
          isTrue, reason: 'RefFormField etiketi çizmiyor');
      expect(w.contains('RefFieldLabel(ad, zorunlu: zorunlu, ilk: true)'),
          isTrue, reason: 'RefTextField etiketi çizmiyor');
    });

    test('BİÇİM ÖRNEĞİ kutunun içinde KALIR', () {
      // ⚠ "5XX XXX XX XX" alan adı değil, biçim ipucudur; etikete
      // taşınmaz. Ayrı parametre (`yerTutucu`) ile verilir.
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('final String? yerTutucu;'), isTrue);
      final t = _kod('lib/screens/profile_info_screen.dart');
      expect(t.contains("etiket: 'Telefon'"), isTrue);
      expect(t.contains("yerTutucu: '5XX XXX XX XX'"), isTrue);
    });

    test('⚠ BAŞ HARF OTOMATİK BÜYÜR — ZORLAMA DEĞİL', () {
      // Kullanıcı yazmaya başlayınca ilk harf büyük gelir; isterse
      // küçültüp kendi yazabilir.
      //
      // ⚠ BU BİR KLAVYE İPUCUDUR. Metni değiştiren bir
      // `TextInputFormatter` KULLANILMADI: öyle olsaydı kullanıcının
      // düzeltmesi anında geri alınır ve alan kullanılamaz hale
      // gelirdi.
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(
          'this.textCapitalization = TextCapitalization.sentences,'
              .allMatches(w)
              .length,
          2,
          reason: 'iki alan bileşeninde de varsayılan sentences olmalı');
      // Değer gerçekten girdiye geçiyor mu?
      expect('textCapitalization: textCapitalization,'.allMatches(w).length, 2);
    });

    test('⚠ E-POSTA VE ŞİFREDE BÜYÜTME YOK', () {
      // Oralarda baş harf büyütmek yanlış: e-posta küçük harfli,
      // şifre ise birebir yazıldığı gibi olmalı.
      for (final yol in const [
        'lib/screens/register_screen.dart',
        'lib/screens/login_screen.dart',
        'lib/screens/profile_info_screen.dart',
      ]) {
        expect(_kod(yol).contains('TextCapitalization.none'), isTrue,
            reason: '$yol: e-posta/şifre istisnası yok');
      }
    });

    test('açıklama ve not alanlarında büyütme AÇIK', () {
      // İlan açıklaması `RefTextField` kullanır — varsayılan geçerli.
      // Teklif notu ham `TextField`; orada açıkça verildi.
      expect(
          _kod('lib/screens/job_detail_screen.dart')
              .contains('textCapitalization: TextCapitalization.sentences'),
          isTrue,
          reason: 'teklif notunda büyütme yok');
    });

    test('zorunlu parametresi KALDIRILMADI', () {
      // Çağıran ekranlar alanın zorunlu olduğunu bildirmeye devam
      // eder; anlam korunur, yalnız görsel tekrar gider.
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('this.zorunlu = false'), isTrue);
      final f = _kod('lib/screens/forgot_password_screen.dart');
      // ⚠ Etiket kaldırıldı; zorunluluk alanın içindeki yıldızda.
      expect(f.contains("hint: '5XX XXX XX XX'"), isTrue);
    });
  });
}
