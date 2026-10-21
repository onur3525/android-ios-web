// TEKLİF TALEBİ DETAYI — BAŞLIK OKLA AYNI SATIRDA (21 Eki, kullanıcı isteği)
//
// "Teklif Talebi" yazısı geri okuyla aynı hizada ve ekrana ortalı;
// ayrı başlık satırı kalktığı için içerik yukarı çekildi.
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final k = _kod('lib/screens/teklif_talebi_detay_screen.dart');

  test('ayrı başlık satırı yok', () {
    expect(k.contains("RefPageTitle('Teklif Talebi'"), isFalse);
  });

  test('başlık ok satırıyla aynı Stack içinde ve ortalı', () {
    final i = k.indexOf('Stack(\n              alignment: Alignment.center,');
    expect(i, greaterThan(-1));
    final blok = k.substring(i, k.indexOf('const SizedBox(height: 12),', i));
    expect(blok.contains("'Teklif Talebi'"), isTrue);
    expect(blok.contains('textAlign: TextAlign.center'), isTrue);
    expect(blok.contains('const RefBackButton()'), isTrue);
    expect(blok.contains('ic_dots.svg'), isTrue);
  });
}
