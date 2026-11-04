import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/firebase/sosyal_giris_ayarlari.dart';
import 'package:hizmetcep/data/remote/api_error_mapper.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/domain/sosyal_saglayici.dart';

/// GOOGLE / APPLE İLE GİRİŞ (4 Kas) — istemci sözleşmesi.
void main() {
  Map<String, dynamic> hesap([Map<String, dynamic> ek = const {}]) => {
        'id': 'u1', 'name': 'Test Kişi', 'email': 'a@b.c', 'phone': '',
        'roles': ['CUSTOMER'], 'activeRole': 'CUSTOMER',
        ...ek,
      };

  test('sunucu hasPassword=false → şifresiz hesap ve sağlayıcısı', () {
    final a = Mappers.account(
        hesap({'hasPassword': false, 'socialProvider': 'apple.com'}));
    expect(a.sifresiVar, isFalse);
    expect(SosyalSaglayici.kimliktenBul(a.sosyalSaglayici),
        SosyalSaglayici.apple);
  });

  test('alan yoksa (eski sunucu) şifreli hesap sayılır', () {
    final a = Mappers.account(hesap());
    expect(a.sifresiVar, isTrue);
    expect(a.sosyalSaglayici, isNull);
  });

  test('SOCIAL_SIGNUP_REQUIRED kayıt adımına çevrilir', () {
    final e = mapErrorBody(404, {
      'error': {'code': 'SOCIAL_SIGNUP_REQUIRED', 'message': 'Kaydınızı tamamlayın'}
    });
    expect(e, isA<SosyalKayitGerekliError>());
    expect(e, isA<NotFoundError>());
    expect(e.message, 'Kaydınızı tamamlayın');
  });

  test('Android: Google açık, Apple yapılandırılana kadar gizli', () {
    // Testler Android hedefinde koşar (4 Kas: yükleme anahtarının SHA-1'i
    // Firebase'de kayıtlı).
    expect(SosyalGirisAyarlari.googleWebIstemciKimligi, isNotEmpty);
    expect(SosyalGirisAyarlari.googleAndroidAcik, isTrue);
    expect(SosyalGirisAyarlari.gorunenler, [SosyalSaglayici.google]);
  });

  test('mock modda düğme gösterilmez (sunucusuz çalışmaz)', () {
    final k = File('lib/ui/sosyal_giris_dugmeleri.dart').readAsStringSync();
    expect(k.contains('? SosyalGirisAyarlari.gorunenler'),
        isTrue);
  });

  test('sağlayıcı kimlikleri sunucuyla aynı', () {
    expect(SosyalSaglayici.google.kimlik, 'google.com');
    expect(SosyalSaglayici.apple.kimlik, 'apple.com');
    expect(SosyalSaglayici.kimliktenBul('password'), isNull);
  });
}
