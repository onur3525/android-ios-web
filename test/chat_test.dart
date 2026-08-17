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

  test('sohbet: geçmiş yazışma YOK; ilk mesaj yalnız teklif verenin notu', () async {
    final l = (await listingCtl.publish(
        ownerId: cust, title: 'Boya', location: 'Konak, İzmir',
        desc: 'Boya işi var evet beş kelime')).listing!;
    await offerCtl.placeOffer(listingId: l.id, providerId: p1, amount: 1400,
        note: 'Boya badana işini üç günde bitiririm söz.');
    final o = offerCtl.myOfferFor(l.id, p1)!;
    final t = chatCtl.threadFor(o.id)!;
    expect(t.length, 1);
    expect(t.first.text, contains('Boya badana'));
    expect(t.first.senderId, p1);
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
    expect(chatCtl.threadFor(o.id)!.length, 1); // mesaj EKLENMEDİ

    // GÜNCEL SÖZLEŞME: mesajlaşma ancak iletişim AÇILDIKTAN sonra
    // mümkündür. İletişimi yetkili aktör (ilan sahibi) açar.
    expect(await contactCtl.openShared(o.id, actorId: cust), isNull);

    // Taraflar artık yazabilir.
    expect((await chatCtl.sendDelivered(o.id, senderId: cust, text: 'Yarın uygun musunuz?')).error, isNull);
    expect((await chatCtl.sendDelivered(o.id, senderId: p1, text: 'Uygunum.')).error, isNull);
    expect(chatCtl.threadFor(o.id)!.length, 3);
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
}
