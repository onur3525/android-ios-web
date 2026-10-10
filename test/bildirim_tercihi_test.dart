// BİLDİRİM TERCİHLERİ SUNUCUDA
//
// Önceden tercih yalnız cihazdaydı: kapatılan türde push gelmeye devam
// ediyordu ve tercih yeniden girişte AÇIK'a dönüyordu. Artık:
//   · /users/me yanıtındaki `notificationPrefs` hesaba okunur
//   · anahtar değişince PATCH /profiles/me/notifications çağrılır,
//     sunucu reddederse eski değer geri alınır
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/mappers.dart';

String _kod(String yol) => const LineSplitter()
    .convert(File(yol).readAsStringSync())
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  test('sunucudaki tercih ve doğrulama durumu hesaba okunur', () {
    final a = Mappers.account({
      'id': 'u1', 'name': 'Test', 'email': 'a@b.c', 'phone': '5321112233',
      'roles': ['CUSTOMER'], 'activeRole': 'CUSTOMER',
      'phoneVerified': true, 'emailVerified': true,
      'notificationPrefs': {
        'offer': false, 'message': true, 'announcement': false, 'email': true,
      },
    });
    expect(a.bildirimTeklif, isFalse);
    expect(a.bildirimMesaj, isTrue);
    expect(a.bildirimDuyuru, isFalse);
    expect(a.bildirimEposta, isTrue);
    expect(a.phoneVerified, isTrue);
    expect(a.emailVerified, isTrue);
  });

  test('alan yoksa (eski sunucu) tercihler AÇIK, doğrulama KAPALI kalır', () {
    final a = Mappers.account({
      'id': 'u1', 'name': 'Test', 'email': 'a@b.c', 'phone': '5321112233',
      'roles': ['CUSTOMER'], 'activeRole': 'CUSTOMER',
    });
    expect(a.bildirimTeklif && a.bildirimMesaj && a.bildirimDuyuru && a.bildirimEposta,
        isTrue);
    expect(a.emailVerified, isFalse);
  });

  test('API modunda tercih sunucuya yazılır, hata olursa geri alınır', () {
    final p = _kod('lib/data/ports/api_ports.dart');
    expect(p.contains('repo.bildirimTercihleriniKaydet(degisenler)'), isTrue);
    expect(p.contains('acc.bildirimTeklif = once.\$1;'), isTrue);
    final a = _kod('lib/data/remote/api/profile_api.dart');
    expect(a.contains("c.patch('/profiles/me/notifications', body: degisenler)"),
        isTrue);
    final b = File('backend/src/routes/kullanici.js').readAsStringSync();
    expect(b.contains("r.patch('/api/v1/profiles/me/notifications'"), isTrue);
    expect(File('backend/src/fcm.js').readAsStringSync().contains('pushIzniVar('),
        isTrue);
  });
}
