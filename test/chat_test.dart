import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/mock_wiring.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/repositories/chat_repository.dart';
import 'package:hizmetcep/domain/failures.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';

void main() {
  late ChatRepository chats;
  late OfferController offerCtl;
  late ChatController chatCtl;
  late ListingController listingCtl;
  late ContactController contactCtl;
  const p1 = 'usta-1', cust = 'musteri-1', stranger = 'yabanci-9';

  late MockWiring w0;
  setUp(() {
    w0 = MockWiring();
    chats = w0.chats;
    offerCtl = w0.offerCtl;
    chatCtl = w0.chatCtl;
    listingCtl = w0.listingCtl;
    contactCtl = w0.contactCtl;
  });

  test('⚠ SOHBET BOŞ BAŞLAR — teklif notu mesaj DEĞİLDİR', () async {
    // ── ⚠ SÖZLEŞME DEĞİŞTİ (12 Eyl, kullanıcı isteği) ──
    //
    // "Not kısmına yazılan yazı not kısmında kalsın, aynı zamanda
    // mesaj olarak gönderilmesin."
    //
    // Eskiden sohbet ilk açıldığında teklif notu hizmet verenin ilk
    // MESAJI olarak ekleniyordu. İki sorunu vardı:
    //   1. Aynı metin iki yerde: not zaten teklif kartında "Hizmet
    //      Verenin Notu" başlığıyla duruyor.
    //   2. Kart üzerindeki "Yeni mesaj" balonu bu sahte mesajı
    //      sayıyordu; kimse yazmamışken mesaj gelmiş gibi
    //      görünüyordu.
    final l = (await listingCtl.publish(
        ownerId: cust, title: 'Boya', location: 'Konak, İzmir',
        desc: 'Boya işi var evet beş kelime')).listing!;
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 1400,
        note: 'Boya badana işini üç günde bitiririm söz.');
    final o = offerCtl.myOfferFor(l.id, p1)!;

    // ⚠ BOŞ LİSTE, `null` DEĞİL: teklif var, sohbet var, mesaj yok.
    final t = chatCtl.threadFor(o.id)!;
    expect(t, isEmpty);

    // ⚠ NOT YERİNDE DURUYOR: kalkan yalnız mesaja kopyalanmasıydı.
    expect(o.note, contains('Boya badana'));
  });

  test('yalnız TARAFLAR yazabilir; yabancı gönderemez (Y3)', () async {
    final l = (await listingCtl.publish(
        ownerId: cust, title: 'Klima', location: 'Konak, İzmir',
        desc: 'Klima montajı lazım beş kelime')).listing!;
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 800, note: 'Aynı gün montaj.');
    final o = offerCtl.myOfferFor(l.id, p1)!;
    // YABANCI: iletişim kapalıyken de yetkisizdir.
    final r1 = await chatCtl.sendDelivered(o.id, senderId: stranger, text: 'selam');
    expect(r1.error, isA<UnauthorizedError>());
    expect(r1.message, isNull);
    // ⚠ SAYI 1 DEĞİL 0: sohbet artık boş başlıyor (teklif notu mesaj
    // olarak eklenmiyor). Yabancının mesajı da eklenmediği için liste
    // hâlâ boş.
    expect(chatCtl.threadFor(o.id)!, isEmpty);

    // GÜNCEL SÖZLEŞME: mesajlaşma ancak iletişim AÇILDIKTAN sonra
    // mümkündür. İletişimi yetkili aktör (ilan sahibi) açar.
    expect(await contactCtl.openShared(o.id, actorId: cust), isNull);

    // Taraflar artık yazabilir.
    expect((await chatCtl.sendDelivered(o.id, senderId: cust, text: 'Yarın uygun musunuz?')).error, isNull);
    expect((await chatCtl.sendDelivered(o.id, senderId: p1, text: 'Uygunum.')).error, isNull);
    // ⚠ 3 DEĞİL 2: teklif notu artık sohbete eklenmiyor, yalnız iki
    // tarafın gerçekten yazdığı mesajlar var.
    expect(chatCtl.threadFor(o.id)!.length, 2);
  });

  test('silinmiş/geçersiz offerId ile mesaj OLUŞTURULAMAZ (O5)', () async {
    final r0 = await chatCtl.sendDelivered('olmayan-id', senderId: cust, text: 'x');
    expect(r0.error, isA<NotFoundError>());
    expect(chats.existing('olmayan-id'), isNull); // kayıt oluşmadı

    final l = (await listingCtl.publish(
        ownerId: cust, title: 'Halı', location: 'Konak, İzmir',
        desc: 'Halı yıkama lazım beş kelime')).listing!;
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 300, note: 'Not.');
    final o = offerCtl.myOfferFor(l.id, p1)!;
    await chatCtl.sendDelivered(o.id, senderId: cust, text: 'merhaba');
    await listingCtl.delete(l.id, actorId: cust); // ilan + teklif + sohbet silindi
    final r1 = await chatCtl.sendDelivered(o.id, senderId: cust, text: 'orada mısın');
    expect(r1.error, isA<NotFoundError>());
    expect(chats.existing(o.id), isNull); // hayalet sohbet YOK
  });
  group('SOHBET FOTOĞRAFI', _fotografTestleri);
}

/// ── ⚠ SOHBET FOTOĞRAFI ÖNİZLEMESİ ──
///
/// Mesajdaki fotoğraf yerine yalnız bir ikon ve "Fotoğraf" yazısı
/// çiziliyordu: kullanıcı GÖNDERDİĞİ fotoğrafı bile göremiyordu.
String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void _fotografTestleri() {
  final k = _kodu('lib/screens/chat_screen.dart');

  test('⚠ FOTOĞRAF ÖNİZLEMELİ ÇİZİLİR', () {
    expect(k.contains('_SohbetFotografi('), isTrue,
        reason: 'önizleme bileşeni yok');
    // Eski "yalnız yazı" hâli geri gelmemeli.
    expect(k.contains("Text('Fotoğraf',"), isFalse,
        reason: 'fotoğraf yerine hâlâ yazı çiziliyor');
  });

  test('gerçek görsel çizilir — cihaz yolu ve ağ adresi', () {
    expect(k.contains('Image.file(File(yol)'), isTrue);
    expect(k.contains('Image.network(yol'), isTrue);
  });

  test('⚠ DOKUNUNCA TAM EKRAN AÇILIR', () {
    expect(k.contains('_FotografTamEkran('), isTrue);
    // Yakınlaştırma için ek paket EKLENMEDİ.
    expect(k.contains('InteractiveViewer('), isTrue);
  });

  test('⚠ GÖRSEL AÇILAMAZSA BOŞ KUTU KALMAZ', () {
    // Kullanıcı bir fotoğraf gönderildiğini yine de görmeli.
    expect(k.contains('errorBuilder: _hata'), isTrue);
    expect(k.contains('Widget _yerTutucu()'), isTrue);
  });
}
