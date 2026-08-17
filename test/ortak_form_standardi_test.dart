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

    test('etiket yıldız ÇİZMEZ', () {
      final w = _kod('lib/ui/ref_widgets.dart');
      final i = w.indexOf('class RefFieldLabel');
      final govde = w.substring(i, w.indexOf('\n}', i));
      expect(govde.contains('RC.requiredStar'), isFalse,
          reason: 'etikete yıldız geri gelmiş');
    });

    test('YILDIZ YER TUTUCUNUN SONUNDA çizilir', () {
      // ⚠ 16 Ağu: yıldız artık ne etikette ne alanın solunda; kayıt
      // ekranının deseniyle YER TUTUCUNUN SONUNDA duruyor. Tek kaynak
      // `refYerTutucu`; iki bileşen de onu kullanır.
      final w = _kod('lib/ui/ref_widgets.dart');
      expect(w.contains('Widget refYerTutucu('), isTrue,
          reason: 'ortak yer tutucu yardımcısı yok');
      expect(w.contains('color: RC.requiredStar'), isTrue);
      // ⚠ `hintText` KULLANILMAZ: tek renklidir, yıldızı griye boyar.
      expect(w.contains('hint: refYerTutucu(hint, zorunlu: zorunlu'), isTrue,
          reason: 'RefFormField yer tutucuyu kullanmıyor');
      expect(w.contains('refYerTutucu(hint!, zorunlu: zorunlu)'), isTrue,
          reason: 'RefTextField yer tutucuyu kullanmıyor');
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
