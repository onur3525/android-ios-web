// İLETİŞİM PAYLAŞIMI — İKİ TARAF DA AÇAR (16 Eki, kullanıcı kararı; 15 Eki'deki
// "yalnız ilan sahibi açar" kuralının yerini aldı).
//   · Hizmet verende de "İletişimi Aç" düğmesi var; sunucu ve mock iki tarafı
//     da kabul eder.
//   · Kim açarsa açsın iki taraf birbirinin bilgisini görür; hizmet alan
//     ilanda "Sadece Uygulama İçi Mesaj" seçtiyse telefonu gösterilmez,
//     mesajlaşma açılır. Seçim sunucuya iletilir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String p) => File(p).readAsStringSync();

void main() {
  test('hizmet veren ekranında "İletişimi Aç" düğmesi var', () {
    final j = _oku('lib/screens/job_detail_screen.dart');
    expect(j.contains("SysButton('İletişimi Aç'"), isTrue);
    expect(j.contains('.openShared(mine.id, actorId: me.id)'), isTrue);
    expect(j.contains('hizmet alan iletişimi açtığında'), isFalse);
    // Telefon yalnız ilan sahibi gizlemediyse görünür.
    expect(j.contains('acik && l.iletisimTercihi == IletisimTercihi.telefonGoster'), isTrue);
  });

  test('hizmet alan ekranı açmaya devam eder', () {
    expect(
        _oku('lib/screens/offer_detail_screen.dart')
            .contains('.openShared(offer.id, actorId: me.id)'),
        isTrue);
  });

  test('demo (mock) kural backend ile aynı: iki taraf açar', () {
    final m = _oku('lib/data/ports/mock_ports.dart');
    expect(m.contains("'İletişimi yalnızca ilan sahibi açabilir'"), isFalse);
    expect(m.contains('final allowed = actorId == o.providerId || actorId == l.ownerId;'), isTrue);
    final b = _oku('backend/src/routes/ilan.js');
    expect(b.contains("'İletişimi yalnızca ilan sahibi açabilir'"), isFalse);
    // 23 Eki (KVKK E1): telefon kuralı tek kaynakta (kisi_ozeti.js);
    // ilan sahibinin telefonu yalnız "telefonGoster" seçildiyse görünür.
    expect(b.contains('ilanTelefonuGorunur({ iletisimAcik: true, karsiIlanSahibi: karsiId === l.owner_id, tercih: l.iletisim_tercihi })'), isTrue);
    expect(_oku('backend/src/routes/kisi_ozeti.js').contains("return karsiIlanSahibi ? tercih === 'telefonGoster' : true;"), isTrue);
  });

  test('ilan oluştururken seçilen iletişim tercihi sunucuya gider ve geri okunur', () {
    expect(_oku('lib/data/remote/api/listing_api.dart').contains("'iletisimTercihi': iletisimTercihi.name,"), isTrue);
    expect(_oku('lib/data/ports/api_ports.dart').contains('iletisimTercihi: iletisimTercihi ?? IletisimTercihi.telefonGoster);'), isTrue);
    expect(_oku('lib/data/remote/mappers.dart').contains("j['iletisimTercihi'] == 'yalnizMesaj'"), isTrue);
  });
}
