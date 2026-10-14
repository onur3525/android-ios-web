// 14 Eki — API modunda iki eksik:
//   1. Bul akışı bildirimleri ilan bildirimi sanılıyordu (talep kimliğiyle
//      ilan ekranı açılıyordu); push dokunuşu uygulama içi kartla aynı
//      yönlendirmeyi kullanmıyordu.
//   2. İlan/talep/sohbet fotoğrafları yalnız depo referansı olarak geliyordu;
//      sunucunun eklediği imzalı adres okunmuyordu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/data/remote/gorsel_adresi.dart';
import 'package:hizmetcep/data/remote/mappers.dart';

String _kod(String yol) => File(yol).readAsStringSync();

void main() {
  group('1 — BİLDİRİM TÜRÜ', () {
    test('Bul akışı kodları talep türlerine eşlenir', () {
      expect(Mappers.notifType('TALEP_REQUEST'), NotifType.teklifTalebiGeldi);
      expect(Mappers.notifType('TALEP_OFFER'), NotifType.teklifVerildi);
      expect(Mappers.notifType('TALEP_ACCEPTED'), NotifType.teklifSecildi);
      expect(Mappers.notifType('TALEP_MESSAGE'), NotifType.teklifYeniMesaj);
    });

    test('eski kayıt: ilan kodu + hedef talep → talep türü (ilan ekranı açılmaz)', () {
      expect(Mappers.notifType('NEW_OFFER', 'talep'), NotifType.teklifVerildi);
      expect(Mappers.notifType('OFFER_SELECTED', 'talep'), NotifType.teklifSecildi);
      expect(Mappers.notifType('NEW_MESSAGE', 'talep'), NotifType.teklifYeniMesaj);
    });

    test('ilan akışı kodları DEĞİŞMEDİ', () {
      expect(Mappers.notifType('NEW_OFFER'), NotifType.newOffer);
      expect(Mappers.notifType('NEW_OFFER', 'ilan'), NotifType.newOffer);
      expect(Mappers.notifType('OFFER_SELECTED', 'is'), NotifType.offerSelected);
      expect(Mappers.notifType('NEW_MESSAGE', 'mesaj'), NotifType.newMessage);
      expect(Mappers.notifType('BILINMEYEN'), NotifType.unknown);
    });

    test('liste yanıtındaki target okunur', () {
      final n = Mappers.notification(<String, dynamic>{
        'id': 'n1', 'type': 'NEW_OFFER', 'target': 'talep', 'refId': 't1',
        'title': 'Teklif geldi', 'body': 'x',
      });
      expect(n.type, NotifType.teklifVerildi);
      expect(n.refId, 't1');
    });

    test('push dokunuşu uygulama içi kartla AYNI yönlendirmeyi kullanır', () {
      final k = _kod('lib/ui/push_kapisi.dart');
      expect(k.contains('NotificationsScreen.hedefeGit(baglam, tur, id)'), isTrue);
      expect(k.contains('Mappers.notifType('), isTrue);
      // Yedek: güvenli hedef tablosu korunur.
      expect(k.contains('pushNamed(pushRotasi(veri))'), isTrue);
      // Rol farklıysa ortak yönlendirme yok (RoleGuard'lı rota).
      expect(k.contains('rol == null || rol == _auth?.activeRole'), isTrue);
      final n = _kod('lib/screens/notifications_screen.dart');
      expect(n.contains('static bool hedefeGit('), isTrue);
      expect(n.contains('NotificationsScreen.hedefeGit(context, n.type, n.refId)'), isTrue);
    });
  });

  group('2 — FOTOĞRAF ADRESİ', () {
    test('imzalı adres varsa o, yoksa referans', () {
      expect(gorselYolu('u/a/b.jpg', 'https://s3.example/k/u/a/b.jpg?X-Amz-Signature=1'),
          'https://s3.example/k/u/a/b.jpg?X-Amz-Signature=1');
      expect(gorselYolu('u/a/b.jpg', null), 'u/a/b.jpg');
      expect(gorselYolu('u/a/b.jpg', 'http://duz.example/x.jpg'), 'u/a/b.jpg',
          reason: 'düz http adresi kabul edilmez');
      expect(gorselYolu(null, null), isNull);
    });

    test('liste: aynı sıra; eksik/null adres referansta kalır', () {
      expect(
          gorselYollari(['a', 'b', 'c'], ['https://x/a', null]),
          ['https://x/a', 'b', 'c']);
      expect(gorselYollari(['a'], null), ['a']);
      expect(gorselYollari(null, null), isEmpty);
    });

    test('ilan ve sohbet eşlemesi adresi okur', () {
      final l = Mappers.listing(<String, dynamic>{
        'id': 'l1', 'ownerId': 'u1', 'title': 'Boya', 'location': 'Bornova',
        'status': 'ACTIVE', 'photoPaths': ['u/u1/a.jpg', 'u/u1/b.jpg'],
        'photoUrls': ['https://s3.example/a', null],
      });
      expect(l.photoPaths, ['https://s3.example/a', 'u/u1/b.jpg']);
      final m = Mappers.message(<String, dynamic>{
        'id': 'm1', 'senderId': 'u1', 'storageRef': 'u/u1/c.jpg',
        'storageUrl': 'https://s3.example/c',
      });
      expect(m.imagePath, 'https://s3.example/c');
    });

    test('teklif talebi eşlemesi adresi okur (tek kaynak)', () {
      final p = _kod('lib/data/remote/api_teklif_talebi_port.dart');
      expect(p.contains("gorselYollari(j['fotograflar'], j['fotografAdresleri'])"), isTrue);
      expect(p.contains("gorselYolu(m['fotografRef'], m['fotografUrl'])"), isTrue);
    });
  });
}
