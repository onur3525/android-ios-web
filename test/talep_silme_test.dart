// TEKLİF TALEBİ SİLME (15 Eki, kullanıcı bulgusu): "Talebi Sil" talebi
// "Reddedildi" olarak listede bırakıyordu. Gerekçe ne olursa olsun talep
// hizmet alanın listesinden kalkmalı; hizmet veren "İptal edildi" görmeli.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';
import 'package:hizmetcep/data/ports/teklif_talebi_port.dart';
import 'package:hizmetcep/data/repositories/teklif_talebi_repository.dart';
import 'package:hizmetcep/domain/teklif_talebi_asamasi.dart';

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

  for (final gerekce in const [
    'İhtiyacım kalmadı / vazgeçtim',
    'Dışarıdan biri ile anlaştım',
    'Diğer: taşındım',
    null,
  ]) {
    test('gerekçe "$gerekce" → hizmet alan listesinden kalkar', () async {
      final id = await gonder();
      expect(await port.sil(id, gerekce: gerekce), isNull);
      expect(port.byHizmetAlan('alan-1'), isEmpty);
      final usta = port.bySaglayici('veren-1').single;
      expect(usta.hizmetAlanSildi, isTrue);
      expect(usta.durum, TeklifTalebiDurumu.reddedildi);
    });
  }

  test('teklif geldikten sonra silinir; iletişim kapanır', () async {
    final id = await gonder();
    await port.teklifVer(id, fiyat: 500, aciklama: '');
    expect(talepIletisimAcikMi(port.byId(id)!), isTrue);
    expect(await port.sil(id, gerekce: 'Gelen teklif uygun değildi'), isNull);
    expect(port.byHizmetAlan('alan-1'), isEmpty);
    expect(talepIletisimAcikMi(port.byId(id)!), isFalse);
  });

  test('kabul edilmiş iş silinemez, listede kalır', () async {
    final id = await gonder();
    await port.teklifVer(id, fiyat: 500, aciklama: '');
    await port.secToVer(id);
    expect(await port.sil(id), isNotNull);
    expect(port.byHizmetAlan('alan-1').single.id, id);
  });

  test('gelen teklifi reddetmek silme DEĞİLDİR: listede "Reddedildi" kalır',
      () async {
    final id = await gonder();
    await port.teklifVer(id, fiyat: 500, aciklama: '');
    await port.reddet(id);
    final t = port.byHizmetAlan('alan-1').single;
    expect(t.durum, TeklifTalebiDurumu.reddedildi);
    expect(t.hizmetAlanSildi, isFalse);
  });

  test('ekran: "Talebi Sil" sil() çağırır ve ekranı kapatır', () {
    final k = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
    expect(k.contains('.sil(t.id, gerekce: gerekce);'), isTrue);
    expect(k.contains('await _reddet(t, gerekce: gerekce);'), isFalse);
    final api = _kodu('lib/data/remote/api_teklif_talebi_port.dart');
    expect(api.contains("'/teklif-talepleri/\$id/sil'"), isTrue);
    expect(api.contains('!t.hizmetAlanSildi'), isTrue);
  });
}
