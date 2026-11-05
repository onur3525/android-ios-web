// GOOGLE / APPLE HESABINA ŞİFRE OLUŞTURMA (5 Kas, kullanıcı talebi)
//
// İsteğe bağlıdır: Google/Apple ile açılmış (şifresiz) hesap, Hesap
// Ayarları › Giriş Yöntemi kartından AYNI şifre ekranını "Şifre Oluştur"
// kipinde açar (mevcut şifre alanı yok; yeni şifre + tekrar). Sunucu
// sözleşmesi (backend/test/sosyal_giris.test.js): POST /auth/password/set
// { newPassword, firebaseIdToken }.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api/auth_api.dart';
import 'package:hizmetcep/data/remote/api/profile_api.dart';
import 'package:hizmetcep/data/remote/repositories/api_repositories.dart';
import 'package:hizmetcep/domain/failures.dart';

import 'support/fake_backend.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('Depo (API)', () {
    test('şifre ve kanıt sunucuya gider; başarıda hesap yeniden okunur',
        () async {
      Map<String, dynamic>? gonderilen;
      var sifreVar = false;
      final be = FakeBackend({
        'GET /users/me': (_) => {...userJson(role: 'CUSTOMER'), 'hasPassword': sifreVar},
        'GET /profiles/me/address': (_) => null,
        'POST /auth/password/set': (b) {
          gonderilen = b;
          sifreVar = true;
          return null;
        },
      });
      final c = be.client();
      final repo = ApiAuthRepository(c, AuthApi(c), ProfileApi(c));
      await repo.restoreSession();
      expect(repo.currentAccount!.sifresiVar, isFalse);

      expect(await repo.sifreOlustur('YeniSifre123', 'belge'), isNull);
      expect(gonderilen,
          {'newPassword': 'YeniSifre123', 'firebaseIdToken': 'belge'});
      expect(repo.currentAccount!.sifresiVar, isTrue);
    });

    test('eski kanıt WRONG_PASSWORD → WrongPasswordError (istemci yeniden doğrulatır)',
        () async {
      final be = FakeBackend({
        'GET /users/me': (_) => {...userJson(role: 'CUSTOMER'), 'hasPassword': false},
        'GET /profiles/me/address': (_) => null,
        'POST /auth/password/set': (_) =>
            apiError(400, 'WRONG_PASSWORD', 'Kimliğinizi yeniden doğrulayın.'),
      });
      final c = be.client();
      final repo = ApiAuthRepository(c, AuthApi(c), ProfileApi(c));
      await repo.restoreSession();
      expect(await repo.sifreOlustur('YeniSifre123', 'eski'),
          isA<WrongPasswordError>());
      expect(repo.currentAccount!.sifresiVar, isFalse);
    });
  });

  group('API portu', () {
    final p = _kod('lib/data/ports/api_ports.dart');

    test('önce açık oturumun belgesi, eskiyse aynı sağlayıcıyla yeniden doğrulama',
        () {
      final i = p.indexOf('Future<DomainError?> sifreOlustur(String yeni) async {');
      expect(i, greaterThan(0));
      final g = p.substring(i, i + 700);
      expect(g.contains('FirebaseKimlik.i.mevcutBelge()'), isTrue);
      expect(g.contains('if (h is! WrongPasswordError)'), isTrue);
      expect(g.contains('sosyalKimlikKaniti()'), isTrue);
    });
  });

  group('Ekranlar', () {
    final s = _kod('lib/screens/change_password_screen.dart');
    final a = _kod('lib/screens/account_settings_screen.dart');

    test('şifre ekranı şifresiz hesapta "Şifre Oluştur" kipinde açılır', () {
      expect(s.contains('?.sifresiVar ==\n      false;'), isTrue);
      expect(s.contains("_olustur ? 'Şifre Oluştur' : 'Şifre Değiştir'"), isTrue);
      expect(s.contains('if (!_olustur) ...['), isTrue,
          reason: 'mevcut şifre alanı oluşturma kipinde gizlenmeli');
      expect(s.contains('await auth.sifreOlustur(_new1.text)'), isTrue);
      expect(s.contains("_olustur ? 'Şifreyi Oluştur' : 'Şifreyi Güncelle'"),
          isTrue);
    });

    test('kural tek kaynakta: yeni şifre ve tekrar aynı doğrulayıcılarla', () {
      expect(s.contains('Validators.password(x)'), isTrue);
      expect(s.contains('Validators.passwordRepeat(x, _new1.text)'), isTrue);
    });

    test('Giriş Yöntemi kartı şifre ekranını açar (artık pasif değil)', () {
      final i = a.indexOf("baslik: 'Giriş Yöntemi',");
      expect(i, greaterThan(0));
      final g = a.substring(i, i + 400);
      expect(g.contains('Dilerseniz şifre de oluşturabilirsiniz.'), isTrue);
      expect(g.contains("Navigator.pushNamed(context, '/profile/password')"),
          isTrue);
      expect(g.contains('onTap: null'), isFalse);
    });
  });
}
