// KARŞI TARAFIN EKRANI — YÖNLENDİRME VE ERİŞİM (KİLİT)
//
// ⚠ KULLANICI KURALI (12 Eyl): "Kesinlikle kimse karşı tarafın
// ekranına yönlendirilmesin, erişemesin."
//
// ── ⚠ BULUNAN İKİ ARIZA ──
//
//   1. "Teklifiniz seçildi" bildirimi HİZMET VERENE gider
//      (`mock_ports`: `userId: chosen.providerId`) ama `newOffer` ile
//      AYNI `case` kutusundaydı ve `ListingDetailScreen` açıyordu —
//      yani hizmet vereni, hizmet alanın ilan YÖNETİM ekranına
//      düşürüyordu: gelen teklifler, "Teklifi Seç", silme menüsü.
//      İki bildirim aynı `refId`yi (ilan id'si) taşıdığı için fark
//      gizlenmişti.
//
//   2. "İletişim açıldı" bildirimi KARŞI TARAFA gider ve karşı taraf
//      HER İKİ ROL DE olabilir. Tek bir hedefe gönderilince
//      taraflardan biri daima yanlış ekrana düşüyordu.
//
// ── ⚠ İKİ KATMANLI SAVUNMA ──
//
// Yönlendirme tablosunu düzeltmek YETMEZ: yarın yeni bir bildirim
// türü ya da yeni bir `Navigator.push` aynı hatayı yapabilir. Bu
// yüzden ekranların kendisi de "ben kimin ekranıyım" sorusunu sorar.
//
// ⚠ BU BİR YETKİ DENETİMİ DEĞİL, GÖRÜNÜM KAPISIDIR. Gerçek yetki
// sunucudadır ve zaten var (`selectOffer` → `UnauthorizedError`).
// Gerçek backend de aynı denetimi yapmalıdır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// [metin] içinde [bas] ile [son] arasındaki bölümü döner.
///
/// ⚠ SABİT KARAKTER PENCERESİ KULLANILMAZ: araya eklenen satırlar
/// pencereyi kaydırıp testi KURAL BOZULMADAN düşürürdü.
String _pencere(String metin, String bas, String son) {
  final i = metin.indexOf(bas);
  if (i < 0) {
    throw StateError('"$bas" bulunamadı');
  }
  final j = metin.indexOf(son, i + bas.length);
  if (j <= i) {
    throw StateError('"$son" sınırı bulunamadı');
  }
  return metin.substring(i, j);
}

void main() {
  final n = _kod('lib/screens/notifications_screen.dart');

  group('1 — ⚠ BİLDİRİM DOĞRU TARAFIN EKRANINI AÇAR', () {
    test('"Teklifiniz seçildi" → hizmet verenin iş ekranı', () {
      final dal = _pencere(
          n, 'case NotifType.offerSelected:', 'case NotifType.newMessage:');
      expect(dal.contains('JobDetailScreen(listingId: ilan)'), isTrue);
      expect(dal.contains('ListingDetailScreen'), isFalse,
          reason: 'hizmet veren yine ilan sahibinin ekranına düşüyor');
    });

    test('"Yeni teklif aldınız" → ilan sahibinin ilan ekranı', () {
      final dal = _pencere(
          n, 'case NotifType.newOffer:', 'case NotifType.offerSelected:');
      expect(dal.contains('ListingDetailScreen(listingId: ilan)'), isTrue);
    });

    test('⚠ İKİ BİLDİRİM AYRI `case` KUTUSUNDA', () {
      // Aynı kutuda toplanmaları, aynı `refId`yi taşıyıp AYRI TARAFA
      // gittikleri gerçeğini gizliyordu.
      expect(
          n.contains('case NotifType.newOffer:\n      case NotifType.offerSelected:'),
          isFalse,
          reason: 'iki bildirim yine tek dalda birleştirilmiş');
    });

    test('⚠ "İletişim açıldı" OKUYANA GÖRE DALLANIR', () {
      final dal = _pencere(
          n, 'case NotifType.contactOpened:', 'case NotifType.teklifYeniMesaj:');
      expect(dal.contains('l.ownerId == me.id'), isTrue,
          reason: 'hedef okuyanın rolüne göre seçilmiyor');
      expect(dal.contains('ListingDetailScreen(listingId: l.id)'), isTrue);
      expect(dal.contains('JobDetailScreen(listingId: l.id)'), isTrue);
    });

    test('⚠ OKUNAMAYAN KAYITTA HİÇBİR YERE GİDİLMEZ', () {
      // Yanlış ekran açmaktansa bildirim sessiz kalır.
      final dal = _pencere(
          n, 'case NotifType.contactOpened:', 'case NotifType.teklifYeniMesaj:');
      expect(dal.contains('if (me != null && l != null)'), isTrue);
    });
  });

  group('2 — ⚠ EKRANLARIN KENDİ KAPISI', () {
    test('ilan ekranı: yalnız ilan sahibi', () {
      final k = _kod('lib/screens/listing_detail_screen.dart');
      expect(k.contains('l != null && l.ownerId != me.id'), isTrue);
      expect(k.contains('YanlisTarafKapisi()'), isTrue);
    });

    test('iş ekranı: ilan sahibi giremez', () {
      final k = _kod('lib/screens/job_detail_screen.dart');
      expect(k.contains('l != null && l.ownerId == me.id'), isTrue);
      expect(k.contains('YanlisTarafKapisi()'), isTrue);
    });

    test('⚠ SIRA: ÖNCE "VAR MI", SONRA "BENİM Mİ"', () {
      // Ters sırada, silinmiş bir ilan için "size ait değil" denirdi.
      for (final yol in const [
        'lib/screens/listing_detail_screen.dart',
        'lib/screens/job_detail_screen.dart',
      ]) {
        final k = _kod(yol);
        expect(k.contains('l != null &&'), isTrue,
            reason: '$yol: null denetimi kapının içinde değil');
      }
    });

    test('⚠ KAPI HİÇBİR METİN GÖSTERMEZ', () {
      // ── ⚠ KULLANICI KARARI (12 Eyl) ──
      //
      // "Bu ekranı kimsenin görmesini istemiyorum, yazıyı kaldır.
      // Birbirinin ekranını görmemesi için gerekli tüm önlemi al ama
      // yazı gösterme."
      //
      // Önce "Bu ekran size ait değil" başlıklı bir boş durum
      // çiziliyordu. Engelleme duruyor, yalnız görünürlüğü kalktı.
      final k = _kod('lib/screens/widgets/yanlis_taraf_kapisi.dart');
      expect(k.contains('SysEmpty'), isFalse,
          reason: 'metinli boş durum geri gelmiş');
      expect(k.contains('Text('), isFalse, reason: 'ekranda yazı var');
      expect(k.contains('SizedBox.shrink()'), isTrue,
          reason: 'boş zemin yerine bir şey çiziliyor');
    });

    test('⚠ SAYFA SESSİZCE KAPANIR', () {
      final k = _kod('lib/screens/widgets/yanlis_taraf_kapisi.dart');
      // ⚠ `maybePop`: sayfa en alttaki olabilir. `pop` orada yığını
      // boşaltıp siyah ekran bırakırdı.
      expect(k.contains('Navigator.of(context).maybePop()'), isTrue);
      expect(k.contains('Navigator.of(context).pop()'), isFalse);
      // ⚠ `build` içinde gezinilmez; Flutter hata atar.
      expect(k.contains('addPostFrameCallback'), isTrue);
      // ⚠ TEK SEFER: `build` her çizimde koşup arka arkaya kapatma
      // denemesi üretirdi.
      expect(k.contains('void initState()'), isTrue);
      // ⚠ Sayfa kapanmışsa `context` kullanılmaz.
      expect(k.contains('if (mounted)'), isTrue);
    });
  });

  group('3 — ⚠ ROL-NÖTR EKRANLARA KAPI KONULMAZ', () {
    test('sohbet ekranları iki tarafa da açıktır', () {
      // Mesaj bildirimleri her iki role de gider; sohbet ekranı
      // kimliği `currentAccount` üzerinden okuyup baloncukları
      // hizalar. Kapı koymak, karşı tarafın sohbetini kapatırdı.
      for (final yol in const [
        'lib/screens/chat_screen.dart',
        'lib/screens/teklif_talebi_sohbet_screen.dart',
      ]) {
        expect(_kod(yol).contains('YanlisTarafKapisi'), isFalse, reason: yol);
      }
    });

    test('Bul akışı detay ekranı rol farkındadır', () {
      // Tek ekran iki görünümü `benSaglayiciMi` ile ayırır; ayrı bir
      // kapıya gerek yok.
      final k = _kod('lib/screens/teklif_talebi_detay_screen.dart');
      expect(k.contains('benSaglayiciMi'), isTrue);
      expect(k.contains('YanlisTarafKapisi'), isFalse);
    });
  });
}
