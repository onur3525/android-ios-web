// AÇILIŞ ROLÜ VE ROL DEĞİŞTİRME KAPISI (6 Kas, kullanıcı kararı)
//
// · Hizmet veren bilgileri eksik hesap hizmet veren ekranına GEÇEMEZ:
//   Rol Değiştir'de önce Profilinizi Tamamlayın açılır; vazgeçilirse hizmet
//   alan rolünde kalınır.
// · Uygulama açılışında eksik hesap hizmet veren panelinde açılmaz.
// · İşlerim ekranının üstündeki "Profilinizi Tamamlayın" düğmesi kaldırıldı.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

Account _hesap(Set<Role> roller, {required bool saglayiciTamam}) {
  final a = Account(
    id: 'a1',
    phone: '5321112233',
    passwordHash: '',
    salt: '',
    roles: roller,
    activeRole: roller.first,
  );
  a.sunucuProfilEksikleri = {
    Role.customer: const <String>[],
    Role.provider: saglayiciTamam ? const <String>[] : const ['SERVICES'],
  };
  return a;
}

void main() {
  group('acilisRolu — tek kaynak', () {
    test('çift rol + hizmet veren bilgileri tamam → hizmet veren', () {
      expect(
          _hesap({Role.customer, Role.provider}, saglayiciTamam: true).acilisRolu,
          Role.provider);
    });

    test('çift rol + hizmet veren bilgileri eksik → hizmet alan', () {
      expect(
          _hesap({Role.customer, Role.provider}, saglayiciTamam: false)
              .acilisRolu,
          Role.customer);
    });

    test('yalnız hizmet alan → hizmet alan', () {
      expect(_hesap({Role.customer}, saglayiciTamam: false).acilisRolu,
          Role.customer);
    });

    test('yalnız hizmet veren (başka paneli yok) → hizmet veren', () {
      expect(_hesap({Role.provider}, saglayiciTamam: false).acilisRolu,
          Role.provider);
    });
  });

  group('açılış rotası', () {
    test('mobil açılış (splash) iki yerde de acilisRolu kullanır', () {
      final s = _kod('lib/screens/splash_screen.dart');
      expect('final hedefRol = acc.acilisRolu;'.allMatches(s).length, 2);
      expect(s.contains('acc.roles.contains(Role.provider) ? Role.provider'),
          isFalse);
    });

    test('web açılışı/yenileme: eksik hesap hizmet veren paneline dönmez', () {
      final m = _kod('lib/main.dart');
      expect(m.contains('final hedefRol = yenileme ? acc.activeRole : acc.acilisRolu;'),
          isTrue);
      expect(m.contains('!eksikSaglayici;'), isTrue);
      expect(m.contains('!eksikSaglayici &&\n          !kGeriYuklenmeyenRotalar'),
          isTrue, reason: 'kayıtlı hizmet veren ekranına geri dönülmemeli');
    });
  });

  group('Rol Değiştir kapısı', () {
    final r = _kod('lib/screens/role_switch_screen.dart');

    test('hizmet verene geçmeden ÖNCE profil kapısı; vazgeçilirse geçiş yok', () {
      final iKapi = r.indexOf('await profilKapisi(context, Role.provider);');
      final iGecis = r.indexOf('await auth.switchRole(hedef);');
      expect(iKapi, greaterThan(0));
      expect(iKapi, lessThan(iGecis));
      final govde = r.substring(iKapi, iGecis);
      expect(govde.contains('if (!tamam) {'), isTrue);
      expect(govde.contains('return;'), isTrue);
    });
  });

  group('İşlerim ekranı', () {
    final j = _kod('lib/screens/jobs_screen.dart');

    test('"Profilinizi Tamamlayın" düğmesi kaldırıldı', () {
      expect(j.contains("RefWideButton('Profilinizi Tamamlayın'"), isFalse);
    });

    test('formdan vazgeçilirse hizmet alan rolüne ve paneline dönülür', () {
      final i = j.indexOf('Future<void> _profiliTamamla() async {');
      final govde = j.substring(i, j.indexOf('\n  }\n', i));
      expect(govde.contains('await auth.switchRole(Role.customer);'), isTrue);
      expect(govde.contains("'/customer/listings'"), isTrue);
      expect(govde.contains('!me.roles.contains(Role.customer)'), isTrue);
    });
  });
}
