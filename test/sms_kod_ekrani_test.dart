import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api_error_mapper.dart';
import 'package:hizmetcep/domain/failures.dart';

/// SMS KODU — PROFİL TAMAMLAMA EKRANI VE GÖNDERİM KURALI (4 Kas)
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('GÖNDERİM KURALI — İSTEMCİ', () {
    test('OTP_LOCKED / OTP_WAIT kalan süreyle KodSiniriError olur', () {
      final kilit = mapErrorBody(429, {
        'error': {
          'code': 'OTP_LOCKED',
          'message': 'Çok fazla kod istendi. 4 dakika sonra tekrar deneyin.',
          'details': {'retryAfterSec': 239},
        }
      });
      expect(kilit, isA<KodSiniriError>());
      expect((kilit as KodSiniriError).kalanSaniye, 239);
      expect(kilit.kilit, isTrue);

      final bekle = mapErrorBody(429, {
        'error': {
          'code': 'OTP_WAIT',
          'message': 'Yeni kod istemek için 42 saniye bekleyin.',
          'details': {'retryAfterSec': 42},
        }
      });
      expect((bekle as KodSiniriError).kalanSaniye, 42);
      expect(bekle.kilit, isFalse);
    });

    test('⚠ her Firebase kod gönderimi önce sunucu iznine gider (tek yardımcı)', () {
      final p = _kodu('lib/data/ports/api_ports.dart');
      expect('FirebaseKimlik.i.kodGonder('.allMatches(p).length, 1,
          reason: 'izin almadan doğrudan Firebase gönderimi var');
      expect(p.contains('await repo.smsIzni(telefon, amac)'), isTrue);
      for (final amac in const [
        'LOGIN', 'REGISTER', 'PHONE_CHANGE', 'FORGOT', 'PHONE_VERIFY', 'ROLE_ADD',
      ]) {
        expect(p.contains("_firebaseKodGonder(") && p.contains("'$amac')"),
            isTrue, reason: amac);
      }
      expect(_kodu('lib/data/remote/api/auth_api.dart').contains("'/auth/otp/permit'"),
          isTrue);
    });
  });

  group('PROFİL TAMAMLAMA EKRANI', () {
    final k = _kodu('lib/screens/profil_tamamlama_screen.dart');

    test('telefon kutusu: ikon + silik örnek, içeride açıklama yazısı yok', () {
      expect(k.contains("'5XX XXX XX XX',\n                    'assets/svg/ic_phone.svg'"),
          isTrue);
      expect(k.contains('Telefon (SMS kodu gönderilecek)'), isFalse);
      expect(k.contains("labelText: dogrulanmis"), isFalse);
    });

    test('kod aynı ekranda: kod kutusu, geri sayım, tekrar gönder', () {
      expect(k.contains("'Telefonunuza gelen 6 haneli kodu girin'"), isTrue);
      expect(k.contains('AutofillHints.oneTimeCode'), isTrue);
      // 5 Kas: gönderme, sayaç, tekrar gönder ve kilit TEK KAYNAKTA
      // (`ui/sms_kod_akisi.dart`); ekran onu kullanır.
      expect(k.contains('final SmsKodAkisi _akis = SmsKodAkisi();'), isTrue);
      expect(k.contains('SmsKodAltSatiri('), isTrue);
      final a = _kodu('lib/ui/sms_kod_akisi.dart');
      expect(a.contains("metin: 'Kodu tekrar gönder',"), isTrue);
      // Kilitte sunucunun uyarısı ("... dakika sonra tekrar deneyin.") ve
      // kalan süre geri sayımı.
      expect(a.contains("Text(akis.kilitMesaji ?? 'Çok fazla kod istendi.',"), isTrue);
      expect(a.contains("Text('Kalan süre: \${akis.sayacMetni}', style: kucuk),"), isTrue);
      // Gönderime basıldıktan sonra (kod gelsin gelmesin) sayaç bitince
      // "Kodu tekrar gönder" çıkar.
      expect(a.contains('if (!akis.gonderildiMi(telefon) && !akis.denendiMi(telefon)) {'), isTrue);
      expect(a.contains('_denendi = true;'), isTrue);
      expect(k.contains('OtpScreen('), isFalse, reason: 'ayrı kod ekranına geçilmez');
    });

    test('düğme: "SMS Kodu Gönder" → kod girilince "Devam Et"', () {
      expect(k.contains("'SMS Kodu Gönder'"), isTrue);
      expect(k.contains("'Devam Et'"), isTrue);
      expect(k.contains('if (dogrulanmis || (_kodGonderildi && _kodGirildi))'), isTrue);
      expect(k.contains('Kodu Gönder ve Devam Et'), isFalse);
    });

    test('Android otomatik kod kutuyu doldurur; numara değişince kod sıfırlanır', () {
      expect(k.contains('otomatikSmsKodu'), isTrue);
      expect(k.contains('_kod.text = o.kod;'), isTrue);
      expect(k.contains('void _telefonDegisti('), isTrue);
    });
  });

  group('PROFİL BİLGİLERİM — ONAYLI TELEFONU OLMAYAN HESAP (5 Kas)', () {
    final k = _kodu('lib/screens/profile_info_screen.dart');

    test('satır içi: Kod Gönder → kod alanı → Telefon onaylı ✓', () {
      expect(k.contains("label: const Text('Kod Gönder'),"), isTrue);
      expect(k.contains("'Telefonunuza gelen 6 haneli kodu girin'"), isTrue);
      expect(k.contains("Text('Telefon onaylı ✓',"), isTrue);
      expect(k.contains("Text('Telefon numarası onaylanmadı',"), isTrue);
      expect(k.contains('if (v.length == 6) {\n                            _telDogrula();'), isTrue);
      expect(k.contains('final SmsKodAkisi _smsAkis = SmsKodAkisi();'), isTrue);
      expect(k.contains('SmsKodAltSatiri('), isTrue);
    });

    test('şifre sorusu ve ayrı kod ekranı yalnız ONAYLI numaranın değişiminde', () {
      expect(k.contains('if (_telefonOnayli && newPhone != oldPhone) {'), isTrue);
      expect(k.contains('if (!_telefonOnayli) {\n      return false;'), isTrue);
    });
  });
}
