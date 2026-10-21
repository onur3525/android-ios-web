// E-POSTA DOĞRULAMA — GÖNDERİM SONUCU EKRANDA GÖRÜNÜR (21 Eki, kullanıcı bulgusu)
//
// Başarı uyarıları (`sysToastOk`) bilerek çizilmiyor; doğrulama bağlantısı
// gönderildiğinde ekranda hiçbir şey değişmiyordu. Sonuç artık düğmenin
// altında kalıcı yazı olarak görünür.
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
  final p = _kod('lib/screens/profile_info_screen.dart');

  test('iki gönderim de sonucu ekrandaki duruma yazar', () {
    // ⚠ Yalnız gönderim sonuçları sayılır; adres değişince yapılan
    // temizleme (`= null)`) aynı satırda kalır ve sayılmaz.
    expect('setState(() => _epostaGonderimDurumu =\n'.allMatches(p).length, 2);
    expect(p.contains('istenmeyen (spam) klasörünü kontrol'), isTrue);
  });

  test('durum yazısı düğmelerin altında çizilir', () {
    expect(p.contains('if (_epostaGonderimDurumu != null && !onayli)'), isTrue);
    expect(p.contains('_epostaGonderimDurumu!,'), isTrue);
  });

  test('adres değişince eski durum silinir', () {
    expect(p.contains('onChanged: (_) => setState(() => _epostaGonderimDurumu = null)'),
        isTrue);
  });
}
