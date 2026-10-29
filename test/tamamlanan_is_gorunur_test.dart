// TAMAMLANAN İŞ SAYISI İLETİŞİM AÇILMADAN DA GÖRÜNÜR (29 Eki, kullanıcı
// isteği). Sayı sunucunun kişi özetinden gelir (iletişimden bağımsız) ve
// tek kaynaktan okunur; kartlar 0 olsa da satırı çizer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol).readAsStringSync();

void main() {
  // ⚠ İlan detayındaki teklif ÖNİZLEME kartına eklenmez (21 Eki kullanıcı
  // kararı, `teklif_karti_sadelestirme_test`): sayı teklif detayında görünür.
  test('teklif detayı 0 iken de yazar', () {
    final k = _kod('lib/screens/offer_detail_screen.dart');
    expect(k.contains('if (_tamamlananIs(context, offer.providerId) >'), isFalse);
    expect(k.contains("'\${_tamamlananIs(context, offer.providerId)} iş tamamladı'"), isTrue);
  });

  test('hizmet verenin gördüğü ilan sahibi kartı sunucu sayısını kullanır', () {
    final k = _kod('lib/screens/job_detail_screen.dart');
    expect(k.contains('tamamlananIs: hizmetAlanTamamlananIs(context, l.ownerId),'), isTrue);
    expect(k.contains('.byOwner(l.ownerId)'), isFalse,
        reason: 'hizmet veren başkasının ilanlarını görmez; yerel sayım 0 çıkıyordu');
  });

  test('sunucu sayıyı iletişim koşuluna bağlamaz', () {
    final s = _kod('backend/src/routes/kisi_ozeti.js');
    expect(s.contains('const isSaglayici = g.saglayici ? await saglayiciTamamlananIs(db, x.id) : 0;'), isTrue);
  });
}
