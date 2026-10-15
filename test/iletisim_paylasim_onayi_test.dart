// İLETİŞİM PAYLAŞIM ONAYI (15 Eki güvenlik denetimi, karar 5): ilan akışında
// iletişimi YALNIZ ilan sahibi (hizmet alan) açar. Hizmet veren teklif
// vererek kendi bilgisini paylaşmayı kabul eder; müşterinin numarası onun
// işlemi olmadan açılmaz. Sunucu da hizmet verenin isteğini 403 ile reddeder.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  test('hizmet veren ekranında "İletişimi Aç" düğmesi yok; açıklama var', () {
    final j = _oku('lib/screens/job_detail_screen.dart');
    expect(j.contains("SysButton('İletişimi Aç'"), isFalse);
    expect(j.contains('.openShared('), isFalse);
    expect(j.contains('hizmet alan iletişimi açtığında'), isTrue);
  });

  test('hizmet alan ekranı açmaya devam eder', () {
    expect(
        _oku('lib/screens/offer_detail_screen.dart')
            .contains('.openShared(offer.id, actorId: me.id)'),
        isTrue);
  });

  test('demo (mock) kural backend ile aynı', () {
    final m = _oku('lib/data/ports/mock_ports.dart');
    expect(m.contains('if (actorId != l.ownerId) {'), isTrue);
    expect(m.contains("'İletişimi yalnızca ilan sahibi açabilir'"), isTrue);
  });
}
