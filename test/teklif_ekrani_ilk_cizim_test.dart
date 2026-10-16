// HİZMET VEREN İŞ DETAYI — İLK ÇİZİM (16 Eki, kullanıcı bulgusu): ekran
// açılırken açık ilanda bir an "Bu ilan teklif kabul etmiyor" görünmez.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = File('lib/screens/job_detail_screen.dart').readAsStringSync();

  test('"teklif kabul etmiyor" yalnız ilan kapalıysa', () {
    final iKosul = s.indexOf('] else if (!(l.status == ListingStatus.active &&');
    final iYazi = s.indexOf("title: 'Bu ilan teklif kabul etmiyor'");
    expect(iKosul, greaterThan(0));
    expect(iYazi, greaterThan(iKosul));
    expect(s.contains("] else\n              const SysEmpty(\n                  title: 'Bu ilan teklif kabul etmiyor'"), isFalse);
  });

  test('onay durumu yüklenirken bekleme; önceden yüklenmişse hemen kullanılır', () {
    expect(s.contains('else if (_approval == null)'), isTrue);
    expect(s.contains('_approval = context.read<ProfileController>().approval;'), isTrue);
  });
}
