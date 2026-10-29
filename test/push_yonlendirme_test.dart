// BİLDİRİME DOKUNUNCA BİLDİRİMİN EKRANINA (29 Eki, kullanıcı isteği):
// telefon kilitli / uygulama kapalı / arka plandayken bildirime dokununca
// hangi ekran açık olursa olsun bildirimin geldiği ekran açılır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart' show Role;
import 'package:hizmetcep/data/models/notification.dart' show NotifType;
import 'package:hizmetcep/ui/push_kapisi.dart';

void main() {
  group('gereken rol', () {
    test('role bağlı bildirimler o rolü ister', () {
      expect(pushGerekenRol(NotifType.newOffer), Role.customer);
      expect(pushGerekenRol(NotifType.teklifVerildi), Role.customer);
      expect(pushGerekenRol(NotifType.offerSelected), Role.provider);
      expect(pushGerekenRol(NotifType.newListing), Role.provider);
      expect(pushGerekenRol(NotifType.teklifTalebiGeldi), Role.provider);
    });

    test('sohbet ve duyuru rol istemez', () {
      expect(pushGerekenRol(NotifType.newMessage), isNull);
      expect(pushGerekenRol(NotifType.teklifYeniMesaj), isNull);
      expect(pushGerekenRol(NotifType.announcement), isNull);
    });

    test('"iletişim açıldı" okuyana göre: ilan sahibi → hizmet alan, değilse → hizmet veren', () {
      expect(pushGerekenRol(NotifType.contactOpened, benId: 'a', ilanSahibiId: 'a'), Role.customer);
      expect(pushGerekenRol(NotifType.contactOpened, benId: 'u', ilanSahibiId: 'a'), Role.provider);
      expect(pushGerekenRol(NotifType.contactOpened), isNull, reason: 'kayıt bulunamadıysa rol değiştirilmez');
    });
  });

  test('aynı dokunuş kısa sürede iki kez gelirse ekran bir kez açılır; sonra yine açılır', () {
    var simdi = DateTime(2026, 10, 29, 12);
    final s = PushTekrarSuzgeci(saat: () => simdi);
    final v = {'bildirimId': 'b1', 'type': 'NEW_MESSAGE', 'id': 'o1'};
    expect(s.tekrarMi(v), isFalse);
    expect(s.tekrarMi(Map.of(v)), isTrue);
    expect(s.tekrarMi({...v, 'bildirimId': 'b2'}), isFalse, reason: 'başka bildirim açılır');
    simdi = simdi.add(const Duration(seconds: 5));
    expect(s.tekrarMi({...v, 'bildirimId': 'b2'}), isFalse, reason: 'pencere geçince yeniden açılır');
  });

  test('yönlendirme: rol geçişi kullanıcının kendi rolleriyle, kayıt önce yüklenir, ortak hedef', () {
    final k = File('lib/ui/push_kapisi.dart').readAsStringSync();
    expect(k.contains('rolUygun'), isFalse, reason: 'farklı roldeki bildirim artık atlanmaz');
    expect(k.contains('!ben.roles.contains(rol) || await auth.switchRole(rol) != null'), isTrue);
    expect(k.contains('await _veriyiHazirla(tur, id, teklifler, ilanlar, talepler);'), isTrue);
    expect(k.contains('NotificationsScreen.hedefeGit(baglam, tur, id)'), isTrue);
    expect(k.contains('if (_tekrar.tekrarMi(veri))'), isTrue);
  });
}
