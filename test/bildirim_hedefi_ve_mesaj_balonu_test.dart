// BİLDİRİM HEDEFİ VE YENİ MESAJ BALONU (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (12 Eyl):
//   1. "Bildirimlerde hangi mesaj gelirse tıklandığında direkt o
//      ekrana gidilmeli. Örnek: mesaj geldi, tıklandığında direkt
//      ilgili mesajlaşma ekranına gidilmeli."
//   2. "İki taraf birbirine mesaj gönderdiğinde sadece bildirim ile
//      değil, mesaj kartları üzerinde de mesaj geldiğini gösteren bir
//      şeyler konulmalı. Yeni mesaj gibi şık bir bulut içinde yazı."
//
// ⚠ BURADA BİR HATA DA BULUNDU: `newMessage` bildiriminin `refId`si
// TEKLİF id'sidir (`mock_ports`: `refId: offerId`), ilan id'si DEĞİL.
// Yönlendirme onu `JobDetailScreen`e `listingId` olarak geçiriyordu —
// var olmayan bir ilan aranıyordu, bildirime dokunmak hiçbir yere
// götürmüyordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/chat.dart';
import 'package:hizmetcep/domain/sohbet_okunmamis.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// `_openTarget` içindeki tek `case NotifType.<tur>:` dalının gövdesi.
String _dal(String kaynak, String tur) {
  final i = kaynak.indexOf('case NotifType.$tur:');
  if (i < 0) {
    throw StateError('$tur dalı yok');
  }
  final j = kaynak.indexOf('case NotifType.', i + 1);
  return kaynak.substring(i, j < 0 ? kaynak.length : j);
}

ChatMessage _mesaj(String gonderen, MessageStatus d) =>
    ChatMessage(id: 'm', senderId: gonderen, text: 'selam', status: d);

void main() {
  final n = _kod('lib/screens/notifications_screen.dart');

  group('1 — ⚠ MESAJ BİLDİRİMİ SOHBETİ AÇAR', () {
    test('ilan akışı: ChatScreen, teklif id ile', () {
      final dal = _dal(n, 'newMessage');
      expect(dal.contains('ChatScreen(offerId: ilan)'), isTrue);
      // Eski, hatalı hedef geri gelmemeli. (`offerSelected` dalı ilan
      // id'si taşıdığı için `JobDetailScreen(listingId: ilan)` orada
      // DOĞRUDUR; denetim yalnız mesaj dalında yapılır.)
      expect(dal.contains('JobDetailScreen('), isFalse,
          reason: 'teklif id\'si ilan id\'si gibi geçiriliyor');
    });

    test('Bul akışı: TeklifTalebiSohbetScreen', () {
      expect(n.contains('TeklifTalebiSohbetScreen('), isTrue);
      expect(n.contains('baslik: talep.hizmet'), isTrue,
          reason: 'başlık çağırandan gelmeli');
    });

    test('⚠ TALEP OKUNAMAZSA EKRAN AÇILMAZ', () {
      // Uydurma bir başlıkla boş sohbet açmaktansa bildirim sessiz
      // kalır.
      expect(n.contains('if (talep != null)'), isTrue);
    });

    test('⚠ `contactOpened` SOHBETE GİTMEZ', () {
      // Orada haber "telefon numarası artık görünüyor"dur, sohbet
      // değil.
      //
      // ⚠ GÜNCEL (12 Eyl): hedef OKUYANA göre dallanır — ilan sahibi
      // kendi ilan ekranına, hizmet veren kendi iş ekranına. `refId`
      // teklif id'sidir; ilan teklif üzerinden bulunur.
      final dal = _dal(n, 'contactOpened');
      expect(dal.contains('ChatScreen('), isFalse);
      expect(dal.contains('ListingDetailScreen(listingId: l.id)'), isTrue);
      expect(dal.contains('JobDetailScreen(listingId: l.id)'), isTrue);
      expect(dal.contains('l.ownerId == me.id'), isTrue);
    });
  });

  group('2 — ⚠ OKUNMAMIŞ SAYIMI', () {
    test('karşı tarafın okunmamış mesajı sayılır', () {
      expect(
          okunmamisSohbetMesaji(
              [_mesaj('karsi', MessageStatus.sent)], 'ben'),
          1);
    });

    test('⚠ KENDİ MESAJIN SAYILMAZ', () {
      expect(
          okunmamisSohbetMesaji([_mesaj('ben', MessageStatus.sent)], 'ben'), 0);
    });

    test('⚠ OKUNMUŞ MESAJ SAYILMAZ', () {
      expect(
          okunmamisSohbetMesaji(
              [_mesaj('karsi', MessageStatus.read)], 'ben'),
          0);
    });

    test('sohbet hiç başlamamışsa 0', () {
      expect(okunmamisSohbetMesaji(null, 'ben'), 0);
      expect(okunmamisSohbetMesaji(const [], 'ben'), 0);
    });
  });

  group('3 — ⚠ BALON KARTTA ÇİZİLİR', () {
    // 29 Eki: kart işareti tek bileşende (`TeklifYeniMesaj`), sayı tek
    // kaynakta (`ChatController.okunmamisMesaj`; sunucu + anlık).
    test('ilan akışı kartı sayımı ortak kaynaktan okur', () {
      final j = _kod('lib/screens/jobs_screen.dart');
      expect(j.contains('TeklifYeniMesaj(offerId: mine.id)'), isTrue);
      final w = _kod('lib/screens/widgets/yeni_mesaj_seridi.dart');
      expect(w.contains('c?.okunmamisMesaj(offerId, ben)'), isTrue);
      expect(w.contains('YeniMesajSeridi(sayi)'), isTrue);
    });

    test('⚠ SIFIRDA ÇİZİLMEZ', () {
      // Boş bir balon "mesaj var" izlenimi verirdi.
      final w = _kod('lib/screens/widgets/yeni_mesaj_seridi.dart');
      expect(w.contains('if (sayi <= 0) {'), isTrue);
    });

    test('⚠ BALONUN KUYRUĞU VAR', () {
      // "Dışarı doğru oklu bir bulut olabilir."
      final w = _kod('lib/screens/widgets/yeni_mesaj_seridi.dart');
      expect(w.contains('CustomPaint('), isTrue);
      expect(w.contains('class _KuyrukBoyaci'), isTrue);
    });

    test('⚠ KUYRUK KART İÇERİĞİNİ ÖRTMEZ', () {
      // Kullanıcının şartı: "kart içindeki yazılar okunacak şekilde."
      // Kuyruk `Stack` ile taşırılmadı; `Column`un normal akışında
      // kendi yerini kaplar.
      final w = _kod('lib/screens/widgets/yeni_mesaj_seridi.dart');
      expect(w.contains('Stack('), isFalse,
          reason: 'kuyruk taşırılmış — kart yazılarının üstüne biner');
    });
  });
}
