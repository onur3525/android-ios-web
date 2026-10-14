// 15 Eki — Kayıtta hizmet veren profili (kategori/ilçe) sunucuda
// kaydedilemezse hata artık YUTULMAZ: hesap açık kalır (aynı numarayla
// yeniden kayıt "kayıtlı" hatası verirdi), kullanıcı uyarılır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  test('API kaydı: profil hatası döner, hesap da döner', () {
    final p = _kod('lib/data/ports/api_ports.dart');
    expect(p.contains('final profilHatasi ='), isTrue);
    expect(p.contains('await repo.saveProviderProfile(categories, serviceDistricts);'),
        isTrue);
    expect(p.contains('if (profilHatasi != null) {'), isTrue);
    expect(
        RegExp(r'\{\s*\n\s*await repo\.saveProviderProfile\(')
            .hasMatch(p),
        isFalse,
        reason: 'sonuç yine yok sayılıyor');
  });

  test('kayıt ekranı: kısmi başarıda forma dönmez, uyarır', () {
    final r = _kod('lib/screens/register_screen.dart');
    expect(r.contains('if (r.error != null && r.account == null) {'), isTrue);
    expect(r.contains('r.account != null ? r.error?.message : null'), isTrue);
    final iUyari = r.indexOf('if (profilUyarisi != null) {');
    final iGecis = r.indexOf('const RegisterDoneScreen()');
    expect(iUyari, greaterThan(0));
    expect(iGecis, greaterThan(iUyari), reason: 'uyarı geçişten ÖNCE gösterilmeli');
  });
}
