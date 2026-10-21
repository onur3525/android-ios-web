import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 21 Eki: bildirime dokunmadan ilgili sayfa açılınca o sayfanın
/// bildirimleri okunur. Kural sunucuda (backend `SAYFA_BILDIRIMLERI`);
/// istemcinin gönderdiği sayfa adları o tablonun anahtarlarıyla aynı
/// olmalı ve beş sayfa da çağrıyı yapmalı.
void main() {
  final yardimci = File('lib/ui/sayfa_bildirimleri.dart').readAsStringSync();
  final sunucu = File('backend/src/routes/ilan.js').readAsStringSync();

  test('istemcideki sayfa adları sunucu tablosunda tanımlı', () {
    final tablo = RegExp(r'SAYFA_BILDIRIMLERI = Object\.freeze\(\{([\s\S]*?)\}\);')
        .firstMatch(sunucu)!
        .group(1)!;
    final adlar = RegExp(r"static const \w+ = '([\w-]+)';")
        .allMatches(yardimci)
        .map((m) => m.group(1)!)
        .toList();
    expect(adlar, ['ilan', 'is', 'sohbet', 'talep', 'talep-sohbet']);
    for (final ad in adlar) {
      expect(RegExp("(^|\\s)'?$ad'?:").hasMatch(tablo), isTrue, reason: ad);
    }
  });

  test('beş sayfa açılışta doğru adla çağırır', () {
    const beklenen = {
      'listing_detail_screen.dart': 'BildirimSayfasi.ilan, widget.listingId',
      'job_detail_screen.dart': 'BildirimSayfasi.isEkrani, widget.listingId',
      'chat_screen.dart': 'BildirimSayfasi.sohbet, widget.offerId',
      'teklif_talebi_detay_screen.dart': 'BildirimSayfasi.talep, widget.talepId',
      'teklif_talebi_sohbet_screen.dart': 'BildirimSayfasi.talepSohbet, widget.talepId',
    };
    beklenen.forEach((dosya, cagri) {
      final k = File('lib/screens/$dosya').readAsStringSync();
      expect(k.contains('sayfaBildirimleriniOku(this, $cagri)'), isTrue, reason: dosya);
    });
  });
}
