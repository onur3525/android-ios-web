import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/sekme_durumu.dart';
import 'package:hizmetcep/data/models/chat.dart';
import 'package:hizmetcep/data/models/listing.dart';
import 'package:hizmetcep/data/models/offer.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/data/repositories/sekme_anligi.dart';

/// WEB · YENİLEMEDE AYNI EKRAN ("Masaüstü sitesi" geçişi dahil)
///
/// Mobil tarayıcıda masaüstü görünümü açılıp kapatılınca sayfa baştan
/// yüklenir. Açık ekran, mock hesaplar ve sekmenin oturumu SEKMEYE ÖZEL
/// depoda (sessionStorage) tutulur ve açılışta geri yüklenir.
String _kod(String y) => File(y)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('VM/mobilde sekme deposu yok: hiçbir şey yazılmaz/okunmaz', () {
    sekmeYaz('x', 'y');
    expect(sekmeOku('x'), isNull);
  });

  test('açık ekran adı sekme deposuna yazılır (yalnız web)', () {
    final k = _kod('lib/ui/global_web_kabugu.dart');
    expect(k.contains("if (kIsWeb && yeni != null && yeni.startsWith('/') && yeni != '/') {"), isTrue);
    expect(k.contains('sekmeYaz(kSekmeRota, yeni);'), isTrue);
  });

  test('açılış kayıtlı ekrana döner; oturumsuzsa yalnız açık ekranlar', () {
    final m = _kod('lib/main.dart');
    expect(m.contains('final kayitli = sekmeOku(kSekmeRota);'), isTrue);
    expect(m.contains('(acc != null || _kOturumsuzAcilabilir.any(kayitli.startsWith))'), isTrue);
  });

  test('mock hesaplar ve sekme oturumu yalnız web + mock modda', () {
    final m = _kod('lib/main.dart');
    expect(m.contains('if (kIsWeb && ports.auth is MockAuthPort) {'), isTrue);
    expect(m.contains('kaliciYaz(_kSekmeHesaplar, '), isTrue);
    // API modu jetonu sekme deposuna YAZILMAZ (M-05).
    expect(_kod('lib/core/sekme_durumu_web.dart').contains('accessToken'), isFalse);
  });

  group('MOCK VERİ ANLIĞI — gidiş-dönüş', () {
    test('ilan: seçili teklif, durum, fotoğraf, zaman korunur', () {
      final l = Listing(
        id: 'l1', ilanNo: '10458231', ownerId: 'u1', title: 'Boya Badana',
        location: 'Karşıyaka', desc: 'salon boyanacak acil',
        isZamani: IsZamani.buHafta, photoPaths: ['u/a.jpg'],
        createdAt: DateTime.utc(2026, 10, 1, 9),
      )..selectedOfferId = 'o1';
      final c = ilanCoz(ilanJson(l));
      expect([c.id, c.ilanNo, c.title, c.selectedOfferId, c.isZamani, c.photoPaths, c.createdAt],
          [l.id, l.ilanNo, l.title, 'o1', IsZamani.buHafta, ['u/a.jpg'], l.createdAt]);
      expect(c.expiresAt, l.expiresAt);
    });
    test('teklif ve mesaj korunur', () {
      final o = Offer(id: 'o1', listingId: 'l1', providerId: 'p1', amount: 1500, note: 'yarın', status: OfferStatus.selected);
      final oc = teklifCoz(teklifJson(o));
      expect([oc.amount, oc.note, oc.status], [1500, 'yarın', OfferStatus.selected]);
      final m = mesajCoz(mesajJson(ChatMessage(id: 'm1', senderId: 'u1', text: 'merhaba')));
      expect([m.id, m.senderId, m.text], ['m1', 'u1', 'merhaba']);
    });
    test('teklif talebi ve mesajları korunur', () {
      final t = TeklifTalebi(
        id: 't1', talepNo: '10458240', hizmetAlanId: 'a1', saglayiciId: 'v1', saglayiciAdi: 'Usta',
        kategori: 'Elektrik', hizmet: 'Priz', aciklama: 'priz arızalı acil',
        iletisimTercihi: IletisimTercihi.yalnizMesaj, createdAt: DateTime.utc(2026, 10, 1),
      );
      final c = talepCoz(talepJson(t));
      expect([c.id, c.talepNo, c.durum, c.iletisimTercihi], ['t1', '10458240', t.durum, IletisimTercihi.yalnizMesaj]);
    });
  });

  test('adsız iş/talep/sohbet geçişleri ad taşır (yenilemede geri dönülür)', () {
    final j = _kod('lib/screens/jobs_screen.dart');
    expect(j.contains("settings: RouteSettings(name: '/is/\${l.id}'),"), isTrue);
    expect(j.contains("settings: RouteSettings(name: '/talep/\${t.id}'),"), isTrue);
    expect(_kod('lib/screens/job_detail_screen.dart').contains("settings: RouteSettings(name: '/mesaj/\${mine.id}'),"), isTrue);
  });
}
