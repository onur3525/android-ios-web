// YORUM YAPILDIKTAN SONRAKİ DURUM — KİLİT
//
// ⚠ KURAL (kullanıcı, 9 Eyl): yorum gönderildikten sonra "Yorum Yaz"
// düğmesi ÇİZİLMEZ, yerinde "Yorum Yapıldı" yazısı kalır; kullanıcı o
// ilana/talebe ait yorumu ve puanı SONRADAN görebilir.
//
// ⚠ KAPSAM SINIRI: görüntülenen şey YALNIZ o ilana/talebe ait tek
// yorumdur (`byOffer(offerId)` / `byTalep(talepId)`) — hizmet verenin
// bütün yorumlarının listesi DEĞİL, toplu "yorumlarım" ekranı da
// DEĞİL (kullanıcı toplu listeyi açıkça İSTEMEDİ).
//
// ── ⚠ NEDEN KAYNAK METNİ OKUNUYOR ──
//
// İki ekran da (`offer_detail_screen`, `teklif_talebi_detay_screen`)
// çok sayıda controller ve gerçek model kurulumu ister; buradaki
// ortamda Flutter SDK olmadığı için widget testi YAZILIP
// KOŞULAMIYOR. Bu test, kuralın KODDA DURDUĞUNU kilitler — "ekranda
// çalışıyor" iddiası ETMEZ, onu cihaz doğrular.
//
// ⚠ VARLIK denetimi yapılır, YOKLUK denetimi YAPILMAZ (bir adın
// açıklamada geçmesi onu kod sanmaya yol açar). Yorum satırları
// yine de elenir: denetlenen şey kodun kendisidir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

/// [metin] içinde [ad] ile başlayan üyenin gövdesini kabaca döndürür.
///
/// ⚠ SABİT KARAKTER PENCERESİ KULLANILMAZ — eklenen birkaç satır
/// pencereyi kaydırıp testi KURAL BOZULMADAN düşürüyordu (bkz.
/// `incelenen_ilan_test` dersi). Sınır, metinden okunur.
String _pencere(String metin, String bas, String son) {
  final i = metin.indexOf(bas);
  if (i < 0) {
    throw StateError('"$bas" bulunamadı');
  }
  final j = metin.indexOf(son, i + bas.length);
  if (j <= i) {
    throw StateError('"$son" sınırı "$bas" sonrasında bulunamadı');
  }
  return metin.substring(i, j);
}

void main() {
  group('1 — İLAN / TEKLİF AKIŞI (offer_detail_screen)', () {
    final k = _kodu('lib/screens/offer_detail_screen.dart');

    test('yorum varsa "Yorum Yaz" düğmesi çizilmez', () {
      // Düğme `if (!reviewed)` kapısının ARDINDA olmalı.
      expect(k.contains('if (!reviewed)'), isTrue,
          reason: 'düğmeyi gizleyen kapı kaybolmuş');
      final p = _pencere(k, 'if (!reviewed)', 'if (reviewed)');
      expect(p.contains("'Yorum Yaz'"), isTrue,
          reason: '"Yorum Yaz" düğmesi kapının içinde değil');
    });

    test('yorum varsa "Yorum Yapıldı" yazısı ve puan gösterilir', () {
      expect(k.contains('if (reviewed)'), isTrue);
      expect(k.contains("'Yorum Yapıldı "), isTrue);
      expect(k.contains('byOffer(offer.id)!.stars'), isTrue,
          reason: 'puan bu teklifin yorumundan okunmuyor');
    });

    test('yazı dokunulabilir ve YALNIZ bu teklifin yorumunu açar', () {
      // ⚠ "Sonradan görebilme" kuralının kilidi. `ReviewScreen`
      // `listingId` + `offerId` ile açılır: kapsam tek yorumdur.
      expect(k.contains('ReviewScreen(listingId: l.id, offerId: offer.id)'),
          isTrue,
          reason: 'görüntüleme tek yoruma bağlı açılmıyor');
    });
  });

  group('2 — BUL / TEKLİF TALEBİ AKIŞI (teklif_talebi_detay_screen)', () {
    final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');

    test('tamamlandı dalı yorum var mı diye SORAR', () {
      // ⚠ ESKİ HATA: bu dal `byTalep`i hiç çağırmıyordu, düğme her
      // koşulda çiziliyordu.
      expect(k.contains('byTalep(talep.id)'), isTrue,
          reason: 'yorum denetimi yok — düğme her zaman çizilir');
    });

    test('yorum yokken düğme, varken "Yorum Yapıldı" yazısı', () {
      expect(k.contains('if (yorum == null)'), isTrue,
          reason: 'düğmeyi gizleyen kapı yok');
      final p = _pencere(k, 'if (yorum == null)', 'RefTap(');
      expect(p.contains("'Yorum Yaz'"), isTrue,
          reason: 'düğme kapının içinde değil');
      expect(k.contains("'Yorum Yapıldı ("), isTrue);
      expect(k.contains(r'${yorum.stars} puan'), isTrue,
          reason: 'puan bu talebin yorumundan okunmuyor');
    });
  });

  group('3 — GÖRÜNTÜLEME EKRANLARI SALT OKUNURDUR', () {
    test('ilan akışı: yorum varsa başlık "Değerlendirmen"', () {
      final k = _kodu('lib/screens/review_screen.dart');
      expect(k.contains("done == null ? 'Yorum Yaz' : 'Değerlendirmen'"),
          isTrue);
      expect(k.contains('byOffer(widget.offerId)'), isTrue,
          reason: 'gösterilen yorum bu teklife bağlı değil');
    });

    test('talep akışı: yorum varsa başlık "Değerlendirmen"', () {
      final k = _kodu('lib/screens/teklif_talebi_yorum_screen.dart');
      expect(k.contains("done == null ? 'Yorum Yaz' : 'Değerlendirmen'"),
          isTrue);
      expect(k.contains('byTalep(widget.talep.id)'), isTrue,
          reason: 'gösterilen yorum bu talebe bağlı değil');
    });

    test('⚠ YORUM DEĞİŞTİRİLEMEZ KURALI DURUYOR', () {
      // ⚠ KİLİT CÜMLEDEN DAVRANIŞA TAŞINDI (9 Eyl): yeşil bilgi
      // şeridi kullanıcı isteğiyle kaldırıldı. Kural DEĞİŞMEDİ —
      // kayıt varken ekran form dalını HİÇ çizmez, yalnız salt
      // okunur kartı gösterir. Test artık o dalı denetliyor;
      // metnin varlığını değil.
      for (final yol in const [
        'lib/screens/teklif_talebi_yorum_screen.dart',
        'lib/screens/review_screen.dart',
      ]) {
        final a = _kodu(yol);
        expect(a.contains('done == null'), isTrue,
            reason: '$yol yorum var/yok ayrımını yapmıyor — '
                'yazılmış yorum yeniden düzenlenebilir hâle gelir');
      }
    });
  });
}
