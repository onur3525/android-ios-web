// HİZMET VEREN — MÜŞTERİ YORUMLARI: TAMAMLANAN İŞ (22 Eki, kullanıcı isteği)
//
// Hizmet veren kendi yorumlar ekranının özet kartında tamamladığı toplam
// iş sayısını görür. Kaynak sunucu (`completedJobs`, kişi özetiyle aynı
// sayı); mock modda ortak `tamamlananIsSayisi`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final k = _kodu('lib/screens/my_reviews_screen.dart');

  test('sayı sunucu yanıtından okunur', () {
    expect(k.contains("_tamamlananIs = (j['completedJobs'] as num?)?.toInt() ?? 0;"), isTrue);
  });

  test('mock modda ortak sayaç kullanılır (kopya hesap yok)', () {
    expect(k.contains('tamamlananIsSayisi(context, me.id, izle: false)'), isTrue);
  });

  test('özet kartında gösterilir (sıfır da)', () {
    final ozet = k.substring(k.indexOf('Widget _summary()'));
    expect(ozet.contains(r"'$_tamamlananIs iş tamamladı'"), isTrue);
  });
}
