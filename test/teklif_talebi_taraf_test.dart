import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/teklif_talebi.dart';

/// TEKLİF TALEBİ — TARAF DENETİMİ (arka plan güvenlik düzeltmesi)
///
/// Talebi yalnız iki taraf görebilir ve üzerinde işlem yapabilir:
/// talebi açan hizmet alan ve talebin gönderildiği hizmet veren.
/// Önceden `/talep/<id>` adresini bilen herhangi bir oturumlu kullanıcı
/// talebi (hizmet alan görünümünde) açabiliyor, mock portta başkasının
/// talebine mesaj yazabiliyordu.
///
/// ⚠ ARAYÜZ DEĞİŞMEDİ: taraflar için ekranlar aynen; taraf olmayana
/// mevcut "Talep bulunamadı" ekranı gösterilir.
TeklifTalebi _talep() => TeklifTalebi(
      id: 't1',
      talepNo: '10458231',
      hizmetAlanId: 'a1',
      saglayiciId: 'v1',
      saglayiciAdi: 'Usta',
      kategori: 'Doğalgaz',
      hizmet: 'Doğalgaz Kaçak Kontrolü',
      aciklama: 'acil',
      iletisimTercihi: IletisimTercihi.telefon,
      createdAt: DateTime(2026, 9, 12),
    );

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('tarafMi: yalnız hizmet alan ve hizmet veren', () {
    final t = _talep();
    expect(t.tarafMi('a1'), isTrue);
    expect(t.tarafMi('v1'), isTrue);
    expect(t.tarafMi('baskasi'), isFalse);
    expect(t.tarafMi(''), isFalse);
  });

  test('detay ekranı taraf olmayana talebi göstermez', () {
    final k = _kod('lib/screens/teklif_talebi_detay_screen.dart');
    expect(k.contains('if (t == null || me == null || !t.tarafMi(me.id)) {'),
        isTrue);
  });

  test('sohbet ekranı taraf olmayana mesajları göstermez, okundu koymaz', () {
    final k = _kod('lib/screens/teklif_talebi_sohbet_screen.dart');
    expect(k.contains('talepKaydi.tarafMi(me.id)'), isTrue);
    expect(k.contains('?.tarafMi(me.id) != true'), isTrue);
  });

  test('mock port taraf olmayanın mesajını ve okundu işaretini reddeder', () {
    final k = _kod('lib/data/ports/teklif_talebi_port.dart');
    expect(k.contains('if (!kayit.tarafMi(gonderenId)) {\n'
            '      return const UnauthorizedError();'),
        isTrue);
    expect(k.contains('_repo.byId(talepId)?.tarafMi(okuyanId) != true'),
        isTrue);
  });

  test('talep detayı aktif rolü denetler (mevcut RoleGuard ekranı)', () {
    final k = _kod('lib/screens/teklif_talebi_detay_screen.dart');
    expect(
        k.contains(
            'final gerekenRol = benSaglayiciMi ? Role.provider : Role.customer;'),
        isTrue);
    expect(k.contains('RoleGuard.provider(builder: (_) => const SizedBox.shrink())'),
        isTrue);
    expect(k.contains('RoleGuard.customer(builder: (_) => const SizedBox.shrink())'),
        isTrue);
  });

  test('/mesaj/<id>: taraf olmayana "Talep bulunamadı", mesaj sızmaz', () {
    final k = _kod('lib/screens/chat_screen.dart');
    expect(
        k.contains(
            'if (_accessError is UnauthorizedError || _accessError is NotFoundError) {'),
        isTrue);
    expect(k.contains("child: Center(child: Text('Talep bulunamadı'))"), isTrue);
    expect(k.contains('final msgs = (oList.isNotEmpty || _erisimOnaylandi)'),
        isTrue);
    // Port düzeyindeki taraf denetimi (sunucunun yapması gereken) yerinde.
    final p = _kod('lib/data/ports/mock_ports.dart');
    expect(p.contains('if (actorId != o.providerId && actorId != l.ownerId) {'),
        isTrue);
  });

  test('M-01: kaynakta (lib/) düz demo şifresi yok', () {
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      expect(f.readAsStringSync().contains('1986onur'), isFalse,
          reason: f.path);
    }
  });
}
