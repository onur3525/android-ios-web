// GİRİŞ KİLİDİ MESAJI (28 Eki): kullanıcı kilidi admine bağlı kalmadan açar;
// mesaj yolu söyler (Şifremi Unuttum / SMS kodu). Sunucu ve uygulama AYNI
// metni kullanır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api_error_mapper.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/hata_mesajlari.dart';

void main() {
  test('mesaj kullanıcının kendi açabileceği yolu söyler', () {
    expect(kGirisKilidiMesaji, contains('Şifremi Unuttum'));
    expect(kGirisKilidiMesaji, contains('SMS koduyla'));
  });

  test('sunucudaki mesajla birebir aynı', () {
    final k = File('backend/src/routes/kullanici.js').readAsStringSync();
    expect(k.contains("const GIRIS_KILIDI_MESAJI = '$kGirisKilidiMesaji';"), isTrue);
  });

  test('LOGIN_LOCKED sunucu mesajıyla gösterilir', () {
    final e = mapErrorBody(429, {
      'error': {'code': 'LOGIN_LOCKED', 'message': kGirisKilidiMesaji}
    });
    expect(e, isA<ValidationError>());
    expect(e.message, kGirisKilidiMesaji);
  });

  test('Firebase deneme kilidi (e-posta girişi) aynı mesajı gösterir', () {
    final k = File('lib/data/remote/firebase_kimlik.dart').readAsStringSync();
    expect(k.contains("e.code == 'too-many-requests'"), isTrue);
    expect(k.contains('const ValidationError(kGirisKilidiMesaji)'), isTrue);
  });
}
