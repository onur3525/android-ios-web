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

    test('6 Kas: Kaydet formu toptan denetlemez (yalnız ad/soyad kaydedilir)', () {
      // Düğme yalnız ad/soyad geçerli ve değişmişken aktiftir; boş telefon
      // ya da e-posta alanı ad/soyad kaydını engellemez, kırmızıya boyanmaz.
      expect(p.contains('_form.currentState!.validate()'), isFalse);
      expect(p.contains('_gonderimAninda'), isFalse);
    });
  });

  group('GEÇERLİLİK ≠ GÖRÜNÜRLÜK', () {
    test('iç geçerlilik ayrı getter\'larla hesaplanır', () {
      for (final g in const [
        'String? get _adHata',
        'String? get _soyadHata',
        'String? get _epostaHata',
        'String? get _telefonHata',
      ]) {
        expect(p.contains(g), isTrue, reason: g);
      }
    });

    test('geçerlilik hesabı hata GÖSTERMEZ', () {
      // Getter'lar doğrudan Validators çağırır; FormFieldState'e
      // dokunmaz, yani ekrana kırmızı metin basmaz.
      final i = p.indexOf('String? get _adHata');
      final govde = p.substring(i, p.indexOf('Account? get _hesap'));
      expect(govde.contains('currentState'), isFalse);
      expect(govde.contains('validate()'), isFalse);
    });
  });

  group('6 Kas (kullanıcı kararı): SADE KAYDET, BİLGİ KUTUSU YOK', () {
    test('doğrulama bilgi kutuları kaldırıldı', () {
      expect(p.contains('Numara doğrulanmadan telefon güncellemesi kaydedilmez.'),
          isFalse);
      expect(p.contains('Yeni e-posta adresinize doğrulama bağlantısı '), isFalse);
      expect(p.contains('if (_telefonDegisti)'), isFalse);
      expect(p.contains('_emailChanged'), isFalse,
          reason: 'eski koşulsuz bayrak geri gelmiş');
      expect(p.contains('_phoneChanged'), isFalse);
    });

    test('e-posta değişikliği yalnız boş değil · geçerli · farklıyken', () {
      final i = p.indexOf('bool get _epostaDegisti');
      final govde = p.substring(i, p.indexOf('bool _busy = false;'));
      expect(govde.contains("_email.text.trim().isEmpty"), isTrue,
          reason: 'boş kontrolü yok');
      expect(govde.contains('_epostaHata != null'), isTrue,
          reason: 'geçerlilik kontrolü yok');
      expect(govde.contains('epostaNormalize(acc.email)'), isTrue,
          reason: 'farklılık kontrolü yok');
    });
  });

  group('BUTON DURUMU', () {
    test('sade "Kaydet": yalnız ad/soyad geçerli ve değişmişken aktif', () {
      expect(p.contains("RefNextButton(\n              'Kaydet',"), isTrue);
      expect(p.contains('onPressed: _adSoyadDegisti ? _save : null'), isTrue);
      expect(p.contains('Doğrula ve Kaydet'), isFalse);
      expect(p.contains('Bilgileri Güncelle'), isFalse);
    });

    test('ad/soyad değişikliği butonu tazeler ama doğrulamaz', () {
      final i = p.indexOf('alanAnahtari: _adKey');
      final govde = p.substring(i, i + 300);
      expect(govde.contains('onChanged: (_) => setState(() {})'), isTrue);
      expect(govde.contains('validate()'), isFalse);
    });

    test('Kaydet YALNIZ adı gönderir; e-posta/telefon akışı ve gezinme yok', () {
      final i = p.indexOf('Future<void> _save() async {');
      final govde = p.substring(i, p.indexOf('\n  }\n', i));
      expect(govde.contains('updateProfile('), isTrue);
      expect(govde.contains('epostaDegisimiBaslat'), isFalse);
      expect(govde.contains('telefonDegisimi'), isFalse);
      expect(govde.contains('kayittanSonra'), isFalse);
      expect(govde.contains('sysToastOk'), isFalse);
      expect(govde.contains('_kaydedildiGoster();'), isTrue);
    });

    test('düğmenin altında 5 sn yeşil "Kaydedildi"', () {
      expect(p.contains('Timer(const Duration(seconds: 5), () {'), isTrue);
      expect(p.contains("child: Text('Kaydedildi',"), isTrue);
      expect(p.contains('color: RC.success)),'), isTrue);
      expect(p.contains('_kaydedildiZamanlayici?.cancel();'), isTrue);
    });

    test('açılır pencere yok: şifre, Google ile devam, yeniden giriş', () {
      expect(p.contains('sifreIleDogrula('), isFalse);
      expect(p.contains('_epostaIcinSifre'), isFalse);
      expect(p.contains('sosyalKimlikKaniti'), isFalse);
      expect(p.contains('showDialog'), isFalse);
      expect(p.contains('OtpScreen('), isFalse);
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
      // ⚠ Telefon alanı etiketli biçime geçti: başlık `etiket:`,
      // örnek numara `yerTutucu:` (metin aynı).
      expect(p.contains("etiket: 'Telefon'"), isTrue);
      expect(p.contains("yerTutucu: '5XX XXX XX XX'"), isTrue);
      // Eski uzun biçimler geri gelmemeli.
      expect(p.contains("hint: 'Adınız'"), isFalse);
      expect(p.contains("hint: 'ornek@eposta.com'"), isFalse);
    });

    test('telefon biçimlendirici TEK kaynak', () {
      expect(p.contains('TelefonBicimlendirici()'), isTrue);
    });

    test('alan sırası ve başlıklar korundu', () {
      final iAd = p.indexOf("hint: 'Ad'");
      final iSoyad = p.indexOf("hint: 'Soyad'");
      final iEposta = p.indexOf("hint: 'E-posta'");
      final iTel = p.indexOf("yerTutucu: '5XX XXX XX XX'");
      expect(iAd, greaterThan(0));
      expect(iSoyad, greaterThan(iAd));
      expect(iEposta, greaterThan(iSoyad));
      expect(iTel, greaterThan(iEposta));
    });

    test('kaydetme akışı bozulmadı', () {
      // 6 Kas: ad/soyad Kaydet'le, telefon satır içi SMS koduyla.
      expect(p.contains('.updateProfile(\n        name:'), isTrue);
      expect(p.contains('auth.telefonDegisimiDogrula('), isTrue);
    });
  });
}
