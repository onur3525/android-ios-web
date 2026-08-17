import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

/// KURTARMA E-POSTASI (K5) VE KORUNAN DAVRANIŞLAR
///
/// Bu dosya iki işi birden yapar:
///   1. Şifremi Unuttum → e-posta adımındaki düğme kuralını kilitler.
///   2. APK testinde SAĞLAM çıkan davranışların değişmediğini kilitler.
///
/// ⚠ İKİNCİSİ EN AZ BİRİNCİSİ KADAR ÖNEMLİDİR. Bu turda amaç yalnız
/// zorunlu yıldızları düzeltmekti; OTP, Hesabı Dondur ve Şifre
/// Değiştir düğmesi çalışıyordu ve bunlara DOKUNULMADI. Aşağıdaki
/// testler ilerideki bir turda yanlışlıkla değiştirilmelerini
/// engeller.
String _kod(String p) => File(p)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — KURTARMA E-POSTASI: biçim geçersizse düğme PASİF', () {
    test('düğme kuralı Validators.email sonucuna bağlı', () {
      final f = _kod('lib/screens/forgot_password_screen.dart');
      expect(f.contains('bool get _epostaGecerli =>'), isTrue);
      expect(f.contains('Validators.email(_email.text) == null'), isTrue,
          reason: 'e-posta yolunda BİÇİM denetlenmiyor');
      // Düğme doğrudan bu kurala bağlı.
      expect(f.contains('onPressed: _zorunluDolu ? _baglantiGonder : null'),
          isTrue);
      // ⚠ `_zorunluDolu` e-posta yolunda DOLULUĞA değil GEÇERLİLİĞE
      // bakar; eski gevşek kural geri gelmemeli.
      final i = f.indexOf('bool get _zorunluDolu =>');
      expect(i, greaterThan(0));
      final govde = f.substring(i, i + 200);
      expect(govde.contains('_epostaGecerli'), isTrue);
      expect(govde.contains('_email.text.trim().isNotEmpty'), isFalse,
          reason: 'doluluk kuralı geri gelmiş');
    });

    test('geçersiz biçimler REDDEDİLİR', () {
      // Kullanıcının APK testinde denediği örnekler.
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('abc@'), isNotNull);
      expect(Validators.email('@hotmail.com'), isNotNull,
          reason: 'kullanıcı adı olmadan adres kabul edilmemeli');
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
    });

    test('geçerli biçim KABUL EDİLİR', () {
      expect(Validators.email('onurn@hotmail.com'), isNull);
    });
  });

  group('2 — ⚠ K5: KAYITLILIK İSTEMCİDE DENETLENMEZ', () {
    // ⚠ GÜVENLİK KURALI. Kayıtlı olmayan ama biçimi geçerli bir
    // adreste düğme AKTİF kalır ve akış normal ilerler. Aksi hâlde
    // uygulama "bu adres kayıtlı değil" bilgisini sızdırır (hesap
    // sayımı / enumeration).
    test('İKİ YOLDA DA kayıtlılık sorgusu YOK', () {
      final f = _kod('lib/screens/forgot_password_screen.dart');
      // ⚠ 16 Ağu: telefon yolundaki kayıtsızlık denetimi de KALDIRILDI.
      // Önceki hâlde e-posta K5'e uyuyor, telefon uymuyordu; aynı açık
      // telefon tarafında duruyordu.
      expect(f.contains('telefonKayitliMi('), isFalse,
          reason: 'ekran kayıt durumunu sorguluyor — enumeration');
      expect(f.contains('_numaraKayitsiz'), isFalse);
      final i = f.indexOf('bool get _zorunluDolu =>');
      final govde = f.substring(i, i + 200);
      expect(govde.contains('_epostaGecerli'), isTrue);
      expect(govde.contains('epostaKayitsiz'), isFalse,
          reason: 'K5 ihlali: e-posta kayıtlılığı düğmeye bağlanmış');
    });

    test('ekranda "kayıtlı değil" türü e-posta uyarısı YOK', () {
      final f = _kod('lib/screens/forgot_password_screen.dart');
      expect(f.contains('Bu e-posta kayıtlı değil'), isFalse);
      expect(f.contains('e-posta kayıtlı'), isFalse);
    });
  });

  group('3 — KORUNAN DAVRANIŞ: Şifre Değiştir düğmesi', () {
    // ⚠ BU DAVRANIŞ SORUN DEĞİLDİR ve bilerek korunur. Geçersiz
    // mevcut şifre ya da geçersiz yeni şifre girildiğinde düğmenin
    // aktif olması ürün kararıdır; mevcut şifrenin doğruluğuna
    // SUNUCU karar verir.
    test('kural W2-3 öncesiyle AYNI', () {
      final c = _kod('lib/screens/change_password_screen.dart');
      final i = c.indexOf('bool get _formGecerli =>');
      expect(i, greaterThan(0));
      final govde = c.substring(i, i + 200);
      expect(govde.contains('_cur.text.trim().isNotEmpty'), isTrue,
          reason: 'mevcut şifrede yalnız DOLULUK aranır — değişmemeli');
      expect(govde.contains('Validators.password(_new1.text) == null'), isTrue);
      expect(govde.contains('_new2.text == _new1.text'), isTrue);
      expect(c.contains('onPressed: _formGecerli ? _save : null'), isTrue);
    });
  });

  group('4 — KORUNAN DAVRANIŞ: OTP', () {
    // ⚠ APK testinde sorunsuz. Kutu ölçüsü ve doğrulama akışı bu
    // turda DEĞİŞTİRİLMEDİ.
    test('OTP ekranı ortak kutu bileşenini kullanmaya devam ediyor', () {
      final o = _kod('lib/screens/otp_screen.dart');
      expect(o.contains('RefOtpBoxes('), isTrue);
      // Altı hane dolmadan düğme pasif — mevcut kural.
      expect(o.contains('_kodUzunluk < 6'), isTrue,
          reason: 'OTP düğme kuralı değişmiş');
    });

    test('kutu ölçüleri DEĞİŞMEDİ', () {
      final r = _kod('lib/ui/ref_widgets.dart');
      expect(r.contains('maxWidth: 56'), isTrue,
          reason: 'OTP kutu genişliği değişmiş');
      expect(r.contains('height: 58'), isTrue,
          reason: 'OTP kutu yüksekliği değişmiş');
    });
  });

  group('5 — KORUNAN DAVRANIŞ: Hesabı Dondur', () {
    // ⚠ APK testinde sorunsuz. Engel koşuluna DOKUNULMADI.
    test('devam eden iş denetimi yerinde', () {
      final a = _kod('lib/screens/account_settings_screen.dart');
      expect(a.contains('bool _devamEdenIsVar() {'), isTrue);
      expect(a.contains('final engel = _devamEdenIsVar();'), isTrue,
          reason: 'dondurma engeli panel açılmadan ÖNCE denetlenmeli');
      expect(a.contains('ListingStatus.open'), isTrue);
      expect(a.contains('OfferStatus.active'), isTrue);
    });
  });

  group('6 — W2-2 DÜZELTMELERİ KORUNDU', () {
    test('login: buton kuralı biçim denetliyor', () {
      final l = _kod('lib/screens/login_screen.dart');
      expect(l.contains('Validators.email(_email.text) == null'), isTrue);
      expect(l.contains('Validators.phone(_phone.text) == null'), isTrue);
    });

    test('formatter: yazma anında otomatik 0 EKLENMİYOR', () {
      final t = _kod('lib/core/telefon_bicimi.dart');
      // ⚠ Bu satır geri gelirse Android IME uyumsuzluğu ve hızlı
      // yazımda rakam düşmesi de geri gelir.
      expect(t.contains("haneler = '0\$haneler'"), isFalse,
          reason: 'otomatik 0 ekleme geri gelmiş');
      // Sınır baştaki 0'ın varlığına göre hesaplanır.
      expect(t.contains("final sinir = haneler.startsWith('0')"), isTrue);
    });

    test('şifremi unuttum: koşulsuz setState geri gelmemiş', () {
      final f = _kod('lib/screens/forgot_password_screen.dart');
      // ⚠ İDDİA `_telefonDegisti` GÖVDESİNE BAĞLANIR.
      //
      // Aynı satır (`setState(() => _sistemHatasi = null);`) düğmeye
      // basıldığında çalışan `_telefonKodIste` içinde de vardır ve
      // ORASI DOĞRUDUR — tek seferlik bir eylemdir. Sorun, HER TUŞTA
      // çalışan `onChanged` yolunda tüm ekranı yeniden çizmekti.
      final i = f.indexOf('void _telefonDegisti() {');
      expect(i, greaterThan(0));
      final govde = f.substring(i, f.indexOf('\n  }', i));
      expect(govde.contains('setState(() => _sistemHatasi = null);'), isFalse,
          reason: 'her tuşta tüm ekranı çizen setState geri gelmiş');
      expect(govde.contains('if (degisti) {'), isTrue,
          reason: 'setState artık koşullu olmalı');
    });
  });

  group('7 — TelefonBicimlendirici kullanan ekranlar KORUNDU', () {
    // ⚠ Biçimlendirici ortaktır; W2-2 değişikliği tüm bu ekranları
    // etkiler. Hepsinin bileşeni kullanmaya devam ettiği kilitlenir.
    //
    // ⚠ İKİ FARKLI KULLANIM VARDIR, KARIŞTIRILMAMALI:
    //   · `TelefonBicimlendirici()` → GİRİŞ alanında, yazarken
    //   · `TelefonBicimlendirici.gruplu(...)` → OKUMA yerlerinde,
    //     numarayı `0532 111 22 33` biçiminde göstermek için
    // W2-2 değişikliği yalnız birinciyi ilgilendirir.
    for (final yol in [
      'lib/screens/login_screen.dart',
      'lib/screens/register_screen.dart',
      'lib/screens/forgot_password_screen.dart',
      'lib/screens/profile_info_screen.dart',
      'lib/screens/widgets/ilan_kayit_adimi.dart',
    ]) {
      test('${yol.split('/').last} — giriş alanı', () {
        expect(_kod(yol).contains('TelefonBicimlendirici()'), isTrue,
            reason: '$yol ortak biçimlendiriciyi kullanmıyor');
      });
    }

    test('gösterim yerlerinde gruplu biçim korunuyor', () {
      // Bu ekranlar telefonu GÖSTERİR, giriş almaz.
      for (final yol in [
        'lib/screens/profile_screen.dart',
        'lib/screens/job_detail_screen.dart',
        'lib/screens/offer_detail_screen.dart',
        'lib/screens/chat_screen.dart',
      ]) {
        expect(_kod(yol).contains('TelefonBicimlendirici.gruplu') ||
            _kod(yol).contains('Validators.phoneLocal'), isTrue,
            reason: '$yol: telefon gösterim biçimi değişmiş');
      }
    });
  });
}
