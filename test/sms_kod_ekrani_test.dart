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
          'message': 'Çok fazla kod istendi. 14 dakika sonra tekrar deneyebilirsiniz.',
          'details': {'retryAfterSec': 812},
        }
      });
      expect(kilit, isA<KodSiniriError>());
      expect((kilit as KodSiniriError).kalanSaniye, 812);
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
      expect(k.contains("'Kodu tekrar gönder'"), isTrue);
      expect(k.contains('sonra tekrar deneyebilirsiniz'), isTrue);
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
}
