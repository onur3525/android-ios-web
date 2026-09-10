// BİLDİRİMLER AKTİF ROLE GÖRE SÜZÜLÜR — KİLİT
//
// ⚠ KULLANICI KURALI (9 Eyl): "Hizmet veren veya alan bir kişi mevcut
// rolünden diğer role geçiş yaptığında diğer rolüne ait bildirimleri
// vb. şeyleri GÖRMEMELİ."
//
// ⚠ SORUNUN KAYNAĞI: `AppNotification` yalnız `userId` taşır, rol
// taşımaz. Kimlik telefon ya da e-posta değil değişmeyen `userId`
// olduğu için (hesap modeli kesin kararı), aynı kişi iki rolde de
// aynı hesabı kullanır ve `forUser(me.id)` iki rolün bildirimlerini
// birlikte döndürür.
//
// ⚠ MODELE ALAN EKLENMEDİ: bildirimin hangi tarafa ait olduğu zaten
// TÜRÜNDE saklı. Yeni alan, geçmiş kayıtların onu boş taşıması ve
// sunucunun da doldurması demekti.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/domain/bildirim_rolu.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

AppNotification _b(NotifType tur, {bool okundu = false}) => AppNotification(
      id: 'n-${tur.name}',
      userId: 'u1',
      type: tur,
      title: tur.name,
      body: '',
      read: okundu,
    );

void main() {
  group('1 — TÜR → ROL EŞLEMESİ', () {
    test('hizmet alana ait türler', () {
      for (final t in const [
        NotifType.newOffer,
        NotifType.listingExpired,
        NotifType.teklifVerildi,
        NotifType.teklifIsiTamamlandi,
      ]) {
        expect(bildirimRolu(t), Role.customer, reason: '$t');
      }
    });

    test('hizmet verene ait türler', () {
      for (final t in const [
        NotifType.offerSelected,
        NotifType.refund,
        NotifType.accountStatus,
        NotifType.categoryRequest,
        NotifType.teklifTalebiGeldi,
        NotifType.teklifSecildi,
        NotifType.teklifReddedildi,
        NotifType.teklifSuresiDoldu,
      ]) {
        expect(bildirimRolu(t), Role.provider, reason: '$t');
      }
    });

    test('⚠ İKİ ROLDE DE GÖRÜNENLER', () {
      // Mesaj ve iletişim bildirimleri karşı taraf kim olursa olsun
      // üretilir; tek role bağlanamaz. Duyuru herkese gider.
      for (final t in const [
        NotifType.contactOpened,
        NotifType.newMessage,
        NotifType.teklifYeniMesaj,
        NotifType.announcement,
      ]) {
        expect(bildirimRolu(t), isNull, reason: '$t');
      }
    });

    test('⚠ BİLİNMEYEN TÜR GİZLENMEZ', () {
      // Sunucu yeni bir tür eklerse bildirim sessizce kaybolmamalı.
      expect(bildirimRolu(NotifType.unknown), isNull);
    });

    test('⚠ HER TÜR EŞLENMİŞ OLMALI', () {
      // `switch` tüm değerleri kapsıyor; yeni bir tür eklenince bu
      // dosyanın da güncellenmesi ZORUNLU olsun diye sayılır.
      for (final t in NotifType.values) {
        expect(() => bildirimRolu(t), returnsNormally, reason: '$t');
      }
    });
  });

  group('2 — SÜZME', () {
    final hepsi = <AppNotification>[
      _b(NotifType.newOffer),
      _b(NotifType.offerSelected),
      _b(NotifType.newMessage),
      _b(NotifType.teklifTalebiGeldi, okundu: true),
    ];

    test('hizmet alan rolünde karşı rolün bildirimleri YOK', () {
      final l = rolBildirimleri(hepsi, Role.customer);
      final turler = l.map((n) => n.type).toSet();
      expect(turler.contains(NotifType.newOffer), isTrue);
      expect(turler.contains(NotifType.newMessage), isTrue,
          reason: 'mesaj bildirimi iki rolde de görünmeli');
      expect(turler.contains(NotifType.offerSelected), isFalse);
      expect(turler.contains(NotifType.teklifTalebiGeldi), isFalse);
    });

    test('hizmet veren rolünde karşı rolün bildirimleri YOK', () {
      final turler =
          rolBildirimleri(hepsi, Role.provider).map((n) => n.type).toSet();
      expect(turler.contains(NotifType.offerSelected), isTrue);
      expect(turler.contains(NotifType.newMessage), isTrue);
      expect(turler.contains(NotifType.newOffer), isFalse);
    });

    test('⚠ OKUNMAMIŞ SAYISI DA SÜZÜLÜR', () {
      // Rozet ham sayıyı okusaydı kullanıcı noktayı görüp listeyi
      // açtığında hiçbir şey bulamazdı.
      expect(rolOkunmamisSayisi(hepsi, Role.customer), 2); // newOffer + mesaj
      expect(rolOkunmamisSayisi(hepsi, Role.provider), 2); // seçildi + mesaj
    });
  });

  group('3 — İKİ TÜKETİCİ DE SÜZGEÇTEN GEÇER', () {
    test('bildirimler ekranı', () {
      final k = _kodu('lib/screens/notifications_screen.dart');
      expect(k.contains('rolBildirimleri('), isTrue);
      // ⚠ Ham liste doğrudan gösterilmemeli.
      expect(k.contains('ctl.unreadCount(me.id)'), isFalse,
          reason: 'sayı süzülmeden okunuyor');
    });

    test('alt bar rozeti', () {
      final k = _kodu('lib/screens/nav_actions.dart');
      expect(k.contains('rolOkunmamisSayisi('), isTrue);
      expect(k.contains('unreadCount(me.id)'), isFalse,
          reason: 'rozet ham sayıyı okuyor — karşı rolün bildirimi '
              'noktayı yakar');
    });

    test('⚠ "Tümünü Okundu Yap" karşı rolü ETKİLEMEZ', () {
      // `markAllRead(userId)` hesabın TÜMÜNÜ okundu yapar; görünmeyen
      // bildirimler sessizce okunmuş sayılırdı.
      final k = _kodu('lib/screens/notifications_screen.dart');
      expect(k.contains('markAllRead('), isFalse,
          reason: 'toplu işaretleme karşı rolün bildirimlerini de siler');
      expect(k.contains('ctl.markRead(n.id)'), isTrue);
    });
  });
}
