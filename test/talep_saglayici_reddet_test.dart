// HİZMET VEREN TALEBİ REDDEDER (22 Eki, kullanıcı kararı): hizmet veren
// doğrudan teklif talebine teklif vermek zorunda değil. "Talebi Reddet"
// ile talep hizmet verenin listesinden kalkar; hizmet alan "Hizmet veren
// reddetti" olarak PASİF görür, bildirim alır ve kendisi silebilir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/account.dart' show Role;
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/data/ports/teklif_talebi_port.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'package:hizmetcep/data/repositories/teklif_talebi_repository.dart';
import 'package:hizmetcep/domain/bildirim_rolu.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  late TeklifTalebiRepository repo;
  late MockTeklifTalebiPort port;

  setUp(() {
    repo = TeklifTalebiRepository();
    port = MockTeklifTalebiPort(repo);
  });

  Future<String> gonder() async {
    final err = await port.gonder(
      hizmetAlanId: 'alan-1',
      saglayiciId: 'veren-1',
      saglayiciAdi: 'Usta',
      kategori: 'Doğalgaz',
      hizmet: 'Doğalgaz Kaçak Kontrolü',
      aciklama: 'Acil kontrol',
      iletisimTercihi: IletisimTercihi.telefonGoster,
    );
    expect(err, isNull);
    return port.bySaglayici('veren-1').first.id;
  }

  test('hizmet veren reddeder: kendi listesinden kalkar, hizmet alanda pasif kalır',
      () async {
    final id = await gonder();
    expect(await port.saglayiciReddet(id), isNull);
    expect(port.bySaglayici('veren-1'), isEmpty);
    final alan = port.byHizmetAlan('alan-1').single;
    expect(alan.durum, TeklifTalebiDurumu.reddedildi);
    expect(alan.saglayiciReddetti, isTrue);
    expect(alan.silinebilir, isTrue, reason: 'hizmet alan kendisi silebilir');
    expect(await port.sil(id), isNull);
    expect(port.byHizmetAlan('alan-1'), isEmpty);
  });

  test('teklif verildikten sonra hizmet veren reddedemez', () async {
    final id = await gonder();
    await port.teklifVer(id, fiyat: 500, aciklama: '');
    expect(await port.saglayiciReddet(id), isNotNull);
    expect(port.bySaglayici('veren-1').single.saglayiciReddetti, isFalse);
  });

  test('hizmet alanın reddettiği talep "hizmet veren reddetti" sayılmaz',
      () async {
    final id = await gonder();
    await port.reddet(id);
    expect(port.byId(id)!.saglayiciReddetti, isFalse);
    expect(port.bySaglayici('veren-1').single.id, id);
  });

  test('sunucu alanı ve bildirim türü eşlenir; bildirim hizmet alana', () {
    expect(Mappers.notifType('TALEP_DECLINED'), NotifType.talepSaglayiciReddetti);
    expect(bildirimRolu(NotifType.talepSaglayiciReddetti), Role.customer);
    final k = _kodu('lib/data/remote/api_teklif_talebi_port.dart');
    expect(k.contains("saglayiciReddetti: j['saglayiciReddetti'] == true,"), isTrue);
    expect(k.contains("_c.post('/teklif-talepleri/\$id/reddet'"), isTrue);
  });

  test('ekranlar: hizmet verende "Talebi Reddet", hizmet alanda pasif metin', () {
    final d = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
    expect(d.contains("Text('Talebi Reddet'"), isTrue);
    expect(d.contains('onReddet: () => _saglayiciReddet(t),'), isTrue);
    expect(d.contains("'Hizmet veren bu talebi reddetti.'"), isTrue);
    final l = _kodu('lib/screens/teklif_istediklerim_screen.dart');
    expect(l.contains("('Hizmet veren reddetti', HC.grey)"), isTrue);
  });
}
