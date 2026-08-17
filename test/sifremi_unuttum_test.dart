// ŞİFREMİ UNUTTUM — UYARI VE DÜĞME KURALI
//
// KARARLAR:
//   1. Telefon alanında YAZARKEN uyarı çıkmaz. "Bu alan zorunludur" ve
//      "Geçerli bir telefon numarası giriniz" bu ekranda GÖSTERİLMEZ;
//      alan Form'un doğrulama zincirinden çıkarılmıştır.
//   2. "Doğrulama Kodu Gönder" numara TAM olmadan AKTİF OLMAZ.
//   3. Numara tam yazılıp gönderildiğinde sunucu "kayıtlı değil" derse
//      TEK uyarı gösterilir ve aynı numarayla düğme yeniden aktif
//      olmaz; numara değişince uyarı kalkar, düğme açılır.
//   4. Telefon alanında son kalan `0` sorunsuz silinmelidir: boş değer
//      GEÇERLİ imleç konumuyla döner.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

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
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  // ⚠ EKRAN BAŞTAN YAZILDI (hesap modeli kararı).
  //
  // Eski sözleşme telefon + SMS OTP üzerineydi ve bu dosya onu
  // koruyordu: telefon alanı, `_telefonUyarisi`, `_kayitsizNumaralar`,
  // üç adımlı `_verified` akışı. Hepsi kalktı.
  //
  // YENİ SÖZLEŞME: ana yol e-posta, alternatif yol telefon kurtarma.
  final k = _kod('lib/screens/forgot_password_screen.dart');
  final y = _kod('lib/screens/yeni_sifre_screen.dart');

  group('ANA YOL E-POSTA', () {
    test('e-posta alanı ve bağlantı düğmesi var', () {
      // ⚠ Etiket kaldırıldı; alan yer tutucusuyla tanınıyor.
      expect(k.contains("hint: 'E-posta'"), isTrue);
      expect(k.contains("'Şifre Yenileme Bağlantısı Gönder'"), isTrue);
      expect(k.contains('Validators.email'), isTrue);
    });

    test('telefon ana yol DEĞİL — alternatif altında', () {
      // ⚠ BAŞLANGIÇ YOLU EKRANI AÇAN YERDEN GELİYOR.
      //
      // Eskiden sabit `false` idi. Giriş ekranı telefon modundayken
      // "Şifremi Unuttum" denince kullanıcı e-posta formuyla
      // karşılaşmasın diye parametreleştirildi; VARSAYILAN hâlâ
      // e-postadır.
      // ⚠ KARAR GERİ ALINDI: ekran GİRİŞ MODUNA BAĞLANMIYOR.
      //
      // Bir tur telefon modundan gelen kullanıcı doğrudan telefon
      // formunu görüyordu. Artık ekran HER ZAMAN e-posta formuyla
      // açılır; telefon doğrulaması alttaki seçenekten ulaşılır.
      expect(k.contains('bool _telefonYolu = false;'), isTrue,
          reason: 'varsayılan e-posta olmalı');
      expect(k.contains('widget.telefonYolu'), isFalse,
          reason: 'giriş moduna bağlanma geri gelmiş');
      // ⚠ METİN DEĞİŞTİ: alt bağlantı gidilecek yolun ADINI yazıyor.
      expect(k.contains("'Telefon ile devam et'"), isTrue);
    });

    test('SAHTE BAŞARI YOK — nötr metin yalnız kabul edilen istekte', () {
      // ⚠ Uç yok / ağ hatası varsa kullanıcıya e-posta gitmiş
      // izlenimi verilmez.
      expect(k.contains('.sifreSifirlamaIste('), isTrue);
      final i = k.indexOf('if (hata != null) {');
      final j = k.indexOf('_gonderildi = true;');
      expect(i, greaterThan(0));
      expect(j, greaterThan(i), reason: 'başarı hata denetiminden önce');
      expect(k.substring(i, j).contains('_sistemHatasi = hata'), isTrue);
      expect(k.contains('Future<void>.delayed'), isFalse,
          reason: 'sahte gecikmeli başarı geri gelmiş');
    });

    test('BAŞARI ve SİSTEM HATASI aynı anda ekranda kalamaz', () {
      // ⚠ Her denemenin başında ikisi de sıfırlanır; hata dalı erken
      // döner, başarı yalnız hatasız yolda yazılır.
      final i = k.indexOf('Future<void> _baglantiGonder()');
      final govde = k.substring(i, k.indexOf('\n  }', i));
      final iSifirla = govde.indexOf('_gonderildi = false;');
      final iHata = govde.indexOf('if (hata != null) {');
      final iBasari = govde.indexOf('_gonderildi = true;');
      expect(iSifirla, greaterThan(-1), reason: 'başarı bayrağı sıfırlanmıyor');
      expect(iSifirla, lessThan(iHata));
      expect(iBasari, greaterThan(iHata));
      expect(govde.substring(iHata, iBasari).contains('return;'), isTrue,
          reason: 'hata dalı erken dönmüyor');
      // Sistem hatası da her denemede sıfırlanır.
      expect(govde.indexOf('_sistemHatasi = null;'), lessThan(iHata));
    });

    test('yola geçişte ikisi de temizlenir', () {
      final i = k.indexOf('_telefonYolu = true;');
      final govde = k.substring(i, i + 200);
      expect(govde.contains('_gonderildi = false;'), isTrue);
      expect(govde.contains('_sistemHatasi = null;'), isTrue);
    });

    test('E-POSTA yolunda NÖTR başarı metni (K5)', () {
      // ⚠ K5 E-POSTA YOLUNDA AYNEN GEÇERLİ: adres kayıtlı olsun
      // olmasın aynı nötr metin gösterilir.
      //
      // ⚠ TELEFON YOLU DA ARTIK NÖTR (16 Ağu): kayıtsızlık uyarısı
      // enumeration riski nedeniyle kaldırıldı. İki yol aynı ilkeyi
      // uygular; ayrım yalnız hangi kanaldan söz edildiğidir.
      expect(k.contains('FormMesaj.sifirlamaGonderildi'), isTrue);
      final i = k.indexOf('Future<void> _baglantiGonder()');
      final govde = k.substring(i, k.indexOf('\n  }', i));
      expect(govde.contains('numaraKayitsiz'), isFalse,
          reason: 'e-posta yolunda kayıt bilgisi sızmamalı');
    });
  });

  group('ALTERNATİF YOL — TELEFON KURTARMA', () {
    test('challenge use-case\'i çağrılıyor', () {
      expect(k.contains('.hesapKurtarmaKodGonder('), isTrue);
      expect(k.contains('.hesapKurtarmaDogrula('), isTrue);
      expect(k.contains('purpose: OtpPurpose.hesapKurtarma'), isTrue);
    });

    test('EKRAN KODU DOĞRULAMAZ', () {
      expect(k.contains('dogrula: (kod) async {'), isTrue);
    });

    test('doğrulama sonrası YENİ ŞİFRE ekranına gidilir', () {
      expect(k.contains('YeniSifreScreen(kurtarmaYetkisi:'), isTrue);
    });
  });

  group('YENİ ŞİFRE BELİRLE EKRANI', () {
    test('OTP alanı YOK', () {
      expect(y.contains('RefOtpBoxes'), isFalse);
      expect(y.contains('OtpScreen'), isFalse);
      expect(y.contains('otpCode'), isFalse);
    });

    test('iki şifre alanı ve ortak kural', () {
      expect(y.contains("hint: 'Yeni şifre'"), isTrue);
      expect(y.contains("hint: 'Yeni şifre tekrar'"), isTrue);
      expect(y.contains('Validators.passwordRepeat'), isTrue);
      expect(y.contains('bool _gonderimAninda = false;'), isTrue);
    });

    test('TOKEN/YETKİ HATASI validator İÇİNE yazılmaz', () {
      expect(y.contains('String? _yetkiHatasi;'), isTrue);
      final i = y.indexOf('validator: (v) =>');
      final govde = y.substring(i, i + 200);
      expect(govde.contains('_yetkiHatasi'), isFalse);
    });

    test('iki kaynaktan çalışır: reset token VEYA kurtarma yetkisi', () {
      expect(y.contains('final String? resetToken;'), isTrue);
      expect(y.contains('final String? kurtarmaYetkisi;'), isTrue);
      expect(y.contains('.kurtarmaSifreBelirle('), isTrue);
    });

    test('başarıda OTURUM AÇILMAZ, giriş ekranına dönülür', () {
      expect(y.contains("pushNamedAndRemoveUntil('/login'"), isTrue);
    });
  });

  group('OTP EKRANI — FALLBACK KALDIRILDI', () {
    final o = _kod('lib/screens/otp_screen.dart');

    test('dogrula ZORUNLU', () {
      expect(
          o.contains('final Future<String?> Function(String kod) dogrula;'),
          isTrue);
      expect(o.contains('required this.dogrula,'), isTrue);
    });

    test('yerel "6 hane" kararı KALMADI', () {
      final i = o.indexOf('Future<void> _verify(String code)');
      final govde = o.substring(i, o.indexOf('\n  }', i));
      expect(govde.contains('code.length == 6'), isFalse);
      expect(govde.contains('_mock.verify('), isFalse);
      expect(govde.contains('await widget.dogrula(code)'), isTrue);
    });

    test('TÜM çağrılar dogrula veriyor', () {
      var cagri = 0;
      for (final f in const [
        'lib/screens/register_screen.dart',
        'lib/screens/profile_info_screen.dart',
        'lib/screens/forgot_password_screen.dart',
      ]) {
        final src = _kod(f);
        if (src.contains('OtpScreen(')) {
          cagri++;
          expect(src.contains('dogrula:'), isTrue, reason: f);
        }
      }
      // ⚠ Giriş ekranında OTP akışı OLMAMALI.
      expect(_kod('lib/screens/login_screen.dart').contains('OtpScreen('),
          isFalse,
          reason: 'giriş ekranına OTP akışı geri gelmiş');
      // ⚠ ÜÇ AKIŞ: kayıt · telefon değişikliği · hesap kurtarma.
      //
      // Giriş ekranı listede DEĞİL: ürün kararıyla telefonla giriş de
      // şifreyle yapılıyor, OTP giriş anahtarı değil.
      expect(cagri, 3);
    });
  });

  group('ÖLÜ KOD TEMİZLENDİ', () {
    test('updatePhone(newPhone, otpCode) zinciri kaldırıldı', () {
      for (final f in const [
        'lib/data/ports/repository_ports.dart',
        'lib/data/ports/mock_ports.dart',
        'lib/data/ports/api_ports.dart',
        'lib/data/controllers/profile_controller.dart',
      ]) {
        expect(_kod(f).contains('updatePhone(String newPhone, String otpCode)'),
            isFalse,
            reason: f);
      }
    });

    test('generic requestOtp TAMAMEN KALDIRILDI', () {
      // ⚠ SÖZLEŞME DEĞİŞTİ. Bir tur "yeniden gönderme için gerekli"
      // diye korunmuştu; sonra görüldü ki o yol challenge ÜRETMİYOR,
      // yalnız SMS gönderiyordu — C7 gereği eski challenge iptal
      // olduğu için gönderilen kod HİÇBİR ZAMAN doğrulanamıyordu.
      // Yeniden gönderim artık her akışın kendi challenge-start
      // metodudur.
      expect(_kod('lib/data/controllers/auth_controller.dart')
          .contains('requestOtp('), isFalse);
    });
  });

  group('YENİDEN GÖNDERİM AKIŞA ÖZELDİR (C7)', () {
    test('OtpScreen yenidenGonder ZORUNLU', () {
      final o = _kod('lib/screens/otp_screen.dart');
      expect(o.contains('final Future<String?> Function() yenidenGonder;'),
          isTrue);
      expect(o.contains('required this.yenidenGonder,'), isTrue);
      expect(o.contains('await widget.yenidenGonder()'), isTrue);
    });

    test('generic requestOtp KALDIRILDI', () {
      // Yalnız SMS gönderen, challenge üretmeyen yol bırakılmaz.
      for (final f in const [
        'lib/data/controllers/auth_controller.dart',
        'lib/data/ports/repository_ports.dart',
        'lib/data/ports/mock_ports.dart',
        'lib/screens/otp_screen.dart',
      ]) {
        expect(_kod(f).contains('requestOtp('), isFalse, reason: f);
      }
    });

    test('her akış KENDİ challenge-start metodunu çağırıyor', () {
      // ⚠ GİRİŞ EKRANI ÇIKARILDI: orada OTP akışı yok.
      const beklenen = {
        'lib/screens/register_screen.dart': '.kayitKodGonder(',
        'lib/screens/profile_info_screen.dart': '.telefonDegisimiKodGonder(',
        'lib/screens/forgot_password_screen.dart': '.hesapKurtarmaKodGonder(',
      };
      beklenen.forEach((dosya, metot) {
        final src = _kod(dosya);
        final i = src.indexOf('yenidenGonder:');
        expect(i, greaterThan(0), reason: dosya);
        // Yeniden gönderim gövdesi kendi start metodunu çağırmalı.
        expect(src.substring(i, i + 400).contains(metot), isTrue,
            reason: dosya);
      });
    });

    test('TÜM çağrılarda İKİ parametre de verilmiş', () {
      // ⚠ Giriş ekranı yok — OTP akışı oradan kaldırıldı.
      const dosyalar = [
        'lib/screens/register_screen.dart',
        'lib/screens/profile_info_screen.dart',
        'lib/screens/forgot_password_screen.dart',
      ];
      for (final f in dosyalar) {
        final src = _kod(f);
        final i = src.indexOf('OtpScreen(');
        expect(i, greaterThan(0), reason: f);
        final govde = src.substring(i, i + 2600);
        expect(govde.contains('dogrula:'), isTrue, reason: '$f: dogrula yok');
        expect(govde.contains('yenidenGonder:'), isTrue,
            reason: '$f: yenidenGonder yok');
      }
    });

    test('challengeId YENİDEN ATANABİLİR bir değişkendir', () {
      // ⚠ YARDIMCI KONTROL — esas kabul kriteri davranış testidir
      // (`test/otp_akislari_test.dart` → "YENİDEN GÖNDERİM DAVRANIŞI").
      //
      // ⚠ TEKNİK DÜZELTME: Dart kapanışları değeri değil DEĞİŞKENİ
      // yakalar; `final` kapanışa "ilk değeri dondurmaz". Sorun
      // şudur: `final` değişkene YENİ challengeId ATANMASINI
      // engeller, dolayısıyla yeniden gönderim yeni kimliği
      // yazamaz ve doğrulama ölü challenge'a gider.
      const beklenen = {
        'lib/screens/profile_info_screen.dart':
            'var challengeId = ch.challengeId!;',
        'lib/screens/register_screen.dart': 'var ch = await context',
        'lib/screens/forgot_password_screen.dart': 'var ch = await context',
      };
      beklenen.forEach((dosya, satir) {
        expect(_kod(dosya).contains(satir), isTrue, reason: dosya);
      });
    });

    test('yeni challengeId doğrulamada KULLANILIR', () {
      // challengeId sabit değil değişken olmalı; yoksa yeni kod
      // eski challenge'a gider ve hiçbir zaman çalışmaz.
      expect(_kod('lib/screens/profile_info_screen.dart')
          .contains('var challengeId = ch.challengeId!;'), isTrue);
      expect(_kod('lib/screens/register_screen.dart')
          .contains('var ch = await context'), isTrue);
      expect(_kod('lib/screens/forgot_password_screen.dart')
          .contains('var ch = await context'), isTrue);
    });

    test('ekranda yerel OTP servisi KALMADI', () {
      final o = _kod('lib/screens/otp_screen.dart');
      expect(o.contains('MockOtpService'), isFalse);
      expect(o.contains('_mock'), isFalse);
    });
  });


  group('EKRAN DÜZELTMELERİ (14 Ağu)', () {
    final k = _kod('lib/screens/forgot_password_screen.dart');

    test('alt bağlantı ÖTEKİ YOLUN ADINI yazar', () {
      // ⚠ Telefon yolunda "E-posta ile devam et" yazıyordu ama
      // e-posta yolunda "E-posta adresime erişemiyorum" yazıyordu —
      // biri hedefi, öteki gerekçeyi anlatıyordu. İkisi de artık
      // gidilecek yolun adını söylüyor.
      expect(k.contains("'Telefon ile devam et'"), isTrue);
      expect(k.contains("'E-posta ile devam et'"), isTrue);
      expect(k.contains("'E-posta adresime erişemiyorum'"), isFalse,
          reason: 'eski metin geri gelmiş');
    });

    test('düğme GEÇERLİ e-posta olmadan aktif olmaz', () {
      // Alan boş değil diye aktif oluyordu; adresin yarısı yazılıyken
      // basılabiliyordu.
      expect(k.contains('bool get _epostaGecerli'), isTrue);
      expect(k.contains('Validators.email(_email.text) == null'), isTrue);
      expect(k.contains(': _epostaGecerli;'), isTrue);
      expect(k.contains(': _email.text.trim().isNotEmpty;'), isFalse,
          reason: 'yalnız doluluk denetimi geri gelmiş');
    });

    test('YARIM adres reddedilir, GERÇEK adres kabul edilir', () {
      for (final yarim in const [
        'o',
        'onur',
        'onur@',
        'onur@gmail',
        'onur@gmail.',
        'onur@gmail.c',
      ]) {
        expect(Validators.email(yarim), isNotNull, reason: yarim);
      }
      for (final tam in const [
        'onur@gmail.com',
        'a@b.co',
        'ad.soyad@firma.com.tr',
      ]) {
        expect(Validators.email(tam), isNull, reason: tam);
      }
    });

    test('alanlar AYRI KİMLİKLİ — klavye türü karışmaz', () {
      // İki alan aynı konumda ve aynı tipte; anahtar olmadan Flutter
      // Element'i yeniden kullanıyor ve e-posta alanı TELEFON
      // klavyesiyle açılıyordu.
      expect(k.contains("key: const ValueKey('kurtarma-eposta')"), isTrue);
      expect(k.contains("key: const ValueKey('kurtarma-telefon')"), isTrue);
      expect(k.contains('keyboardType: TextInputType.emailAddress'), isTrue);
      expect(k.contains('keyboardType: TextInputType.phone'), isTrue);
    });
  });
}
