// PROFİL BİLGİLERİM — FORM DAVRANIŞI SÖZLEŞMESİ
//
// İKİ KAVRAM AYRIDIR VE KARIŞTIRILMAZ:
//   • GEÇERLİLİK  — formun iç durumu; buton bundan beslenir.
//   • GÖRÜNÜRLÜK  — kullanıcıya kırmızı hata gösterme kararı.
//
// Kullanıcı "O" yazarken buton pasif olabilir ama hata metni ÇIKMAZ.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

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
  final p = _kod('lib/screens/profile_info_screen.dart');

  group('YAZARKEN HATA GÖSTERİLMEZ', () {
    test('hata görünürlüğü ODAK kapısından geçer', () {
      // Alan odaktayken (yani kullanıcı yazarken) doğrulayıcı null
      // döner: "O", "On", "Onu" ara değerlerinde kırmızı metin yok.
      expect(p.contains('if (odak.hasFocus) {'), isTrue);
      expect(p.contains('return null;'), isTrue);
      expect(p.contains('!_terkEdilen.contains(alan)'), isTrue);
    });

    test('hiçbir alan her tuşta doğrulama yapmaz', () {
      for (final k in const [
        '_adKey',
        '_soyadKey',
        '_epostaKey',
        '_telefonKey',
      ]) {
        expect(p.contains('$k.currentState?.validate()'), isFalse, reason: k);
        expect(p.contains('$k.currentState?.reset()'), isFalse, reason: k);
      }
    });

    test('dört alan da kapıya bağlı', () {
      for (final a in const [
        "_kural('ad', _fAd",
        "_kural('soyad', _fSoyad",
        "_kural('eposta', _fEposta",
        "_kural('telefon', _fTelefon",
      ]) {
        expect(p.contains(a), isTrue, reason: a);
      }
    });

    test('gönderimde kapı geçici olarak açılır, sonra kapanır', () {
      expect(p.contains('_gonderimAninda = true;'), isTrue);
      expect(p.contains('_gonderimAninda = false;'), isTrue);
      expect(p.contains('bool _gonderimAninda = false;'), isTrue);
    });
  });

  group('GEÇERLİLİK ≠ GÖRÜNÜRLÜK', () {
    test('iç geçerlilik ayrı getter\'larla hesaplanır', () {
      for (final g in const [
        'String? get _adHata',
        'String? get _soyadHata',
        'String? get _epostaHata',
        'String? get _telefonHata',
        'bool get _formGecerli',
      ]) {
        expect(p.contains(g), isTrue, reason: g);
      }
    });

    test('geçerlilik hesabı hata GÖSTERMEZ', () {
      // Getter'lar doğrudan Validators çağırır; FormFieldState'e
      // dokunmaz, yani ekrana kırmızı metin basmaz.
      final i = p.indexOf('String? get _adHata');
      final govde = p.substring(i, p.indexOf('bool get _formGecerli'));
      expect(govde.contains('currentState'), isFalse);
      expect(govde.contains('validate()'), isFalse);
    });
  });

  group('DOĞRULAMA BİLGİ KUTULARI — ÜÇ KOŞUL', () {
    test('e-posta kutusu boş/geçersizde GÖRÜNMEZ', () {
      final i = p.indexOf('bool get _epostaDegisti');
      final govde = p.substring(i, p.indexOf('bool get _degisiklikVar'));
      expect(govde.contains("_email.text.trim().isEmpty"), isTrue,
          reason: 'boş kontrolü yok');
      expect(govde.contains('_epostaHata != null'), isTrue,
          reason: 'geçerlilik kontrolü yok');
      expect(govde.contains('epostaNormalize(acc.email)'), isTrue,
          reason: 'farklılık kontrolü yok');
    });

    test('telefon kutusu boş/geçersizde GÖRÜNMEZ', () {
      final i = p.indexOf('bool get _telefonDegisti');
      final govde = p.substring(i, p.indexOf('bool get _epostaDegisti'));
      expect(govde.contains("_phone.text.trim().isEmpty"), isTrue);
      expect(govde.contains('_telefonHata != null'), isTrue);
      expect(govde.contains('!= acc.phone'), isTrue);
    });

    test('kutular yeni getter\'lara bağlı, eski bayraklar yok', () {
      expect(p.contains('if (_epostaDegisti)'), isTrue);
      expect(p.contains('if (_telefonDegisti)'), isTrue);
      expect(p.contains('_emailChanged'), isFalse,
          reason: 'eski koşulsuz bayrak geri gelmiş');
      expect(p.contains('_phoneChanged'), isFalse);
    });

    test('iki doğrulama AYRI tutulur', () {
      // Birinin doğrulanması ötekini doğrulanmış saymaz.
      expect(p.contains('bool get _dogrulamaGerekli =>'), isTrue);
      expect(p.contains('_telefonDegisti || _epostaDegisti'), isTrue);
    });
  });

  group('BUTON DURUMU', () {
    test('form geçersiz veya değişiklik yoksa PASİF', () {
      expect(
          p.contains(
              'onPressed: (_formGecerli && _degisiklikVar) ? _save : null'),
          isTrue);
    });

    test('metin değişikliğin TÜRÜNE göre seçilir', () {
      expect(
          p.contains(
              "_dogrulamaGerekli ? 'Doğrula ve Kaydet' : 'Bilgileri Güncelle'"),
          isTrue);
    });

    test('ad/soyad değişikliği butonu tazeler ama doğrulamaz', () {
      final i = p.indexOf('alanAnahtari: _adKey');
      final govde = p.substring(i, i + 300);
      expect(govde.contains('onChanged: (_) => setState(() {})'), isTrue);
      expect(govde.contains('validate()'), isFalse);
    });

    test('boşaltma geçerli değişiklik SAYILMAZ', () {
      // `_telefonDegisti`/`_epostaDegisti` boş alanda false döner;
      // dolayısıyla `_degisiklikVar` da bunu değişiklik saymaz.
      expect(p.contains('bool get _degisiklikVar =>'), isTrue);
      expect(p.contains('_adSoyadDegisti || _telefonDegisti || _epostaDegisti'),
          isTrue);
    });
  });

  group('KURALLAR KORUNDU — YENİ KURAL İCAT EDİLMEDİ', () {
    test('mevcut Validators kuralları kullanılır', () {
      expect(p.contains("Validators.name(_first.text, min: 3, label: 'ad')"),
          isTrue);
      expect(p.contains("Validators.name(_last.text, min: 2, label: 'soyad')"),
          isTrue);
      expect(p.contains('Validators.email(_email.text)'), isTrue);
      expect(p.contains('Validators.phone(_phone.text)'), isTrue);
    });

    test('boş alan mesajı ile format mesajı AYRIDIR', () {
      expect(Validators.name('', min: 3), 'Bu alan zorunludur');
      expect(Validators.name('O', min: 3), isNot('Bu alan zorunludur'));
      expect(Validators.email(''), 'Bu alan zorunludur');
      expect(Validators.email('onur@'), isNot('Bu alan zorunludur'));
      expect(Validators.phone(''), 'Bu alan zorunludur');
    });

    test('geçerli değer hatayı temizler', () {
      expect(Validators.name('Onur', min: 3), isNull);
      expect(Validators.email('onur@gmail.com'), isNull);
      expect(Validators.phone('05321112233'), isNull);
    });

    test('ara değerler GEÇERSİZDİR ama bu görünürlük demek değildir', () {
      // Kural değişmedi: "O" geçersiz. Değişen tek şey, bunun
      // kullanıcıya NE ZAMAN söylendiği.
      expect(Validators.name('O', min: 3), isNotNull);
      expect(Validators.email('onur@gmail'), isNotNull);
      expect(Validators.phone('532'), isNotNull);
    });
  });

  group('KLAVYE VE TASARIM KORUNDU', () {
    test('klavye türleri değişmedi', () {
      expect(p.contains('keyboardType: TextInputType.emailAddress'), isTrue);
      expect(p.contains('keyboardType: TextInputType.number'), isTrue);
    });

    test('yer tutucu metinleri yeni sözleşmeye uygun', () {
      // ⚠ METİNLER 16 AĞUSTOS'TA KISALDI.
      //
      // Etiketler kaldırılıp zorunluluk alanın içine taşınınca yer
      // tutucular alanın KİMLİĞİ hâline geldi ve "…ınız/…iniz"
      // biçimleri bırakıldı: `Adınız` → `Ad`,
      // `ornek@eposta.com` → `E-posta`.
      //
      // ⚠ Metinler 320 dp genişlikte %130 yazı ölçeğinde bile sığacak
      // şekilde seçildi; uzatılırsa kesilme riski doğar.
      expect(p.contains("hint: 'Ad'"), isTrue);
      expect(p.contains("hint: 'Soyad'"), isTrue);
      expect(p.contains("hint: 'E-posta'"), isTrue);
      expect(p.contains("hint: '5XX XXX XX XX'"), isTrue);
      // Eski uzun biçimler geri gelmemeli.
      expect(p.contains("hint: 'Adınız'"), isFalse);
      expect(p.contains("hint: 'ornek@eposta.com'"), isFalse);
    });

    test('telefon biçimlendirici TEK kaynak', () {
      expect(p.contains('TelefonBicimlendirici()'), isTrue);
    });

    test('alan sırası ve başlıklar korundu', () {
      // ⚠ Sıra artık YER TUTUCULARDAN okunuyor; etiketler kaldırıldı.
      final iAd = p.indexOf("hint: 'Ad'");
      final iSoyad = p.indexOf("hint: 'Soyad'");
      final iEposta = p.indexOf("hint: 'E-posta'");
      final iTel = p.indexOf("hint: '5XX XXX XX XX'");
      expect(iAd, greaterThan(0));
      expect(iSoyad, greaterThan(iAd));
      expect(iEposta, greaterThan(iSoyad));
      expect(iTel, greaterThan(iEposta));
    });

    test('kaydetme akışı bozulmadı', () {
      expect(p.contains('profile.updateProfile('), isTrue);
      expect(p.contains('OtpPurpose.phoneChange'), isTrue);
    });
  });
}
