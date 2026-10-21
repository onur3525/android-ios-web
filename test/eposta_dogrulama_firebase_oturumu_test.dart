// E-POSTA DOĞRULAMA — FIREBASE OTURUMU YOKSA KÖPRÜ BELGESİ (21 Eki)
//
// Web'de Firebase oturumu kalıcı tutulmaz (Persistence.NONE); sayfa
// yenilenince "Güvenlik için yeniden giriş yapın" hatası çıkıyordu.
// Artık iki e-posta işlemi de önce sunucudan kısa ömürlü belge alıp
// Firebase oturumunu kurar.
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
  final p = _kod('lib/data/ports/api_ports.dart');

  test('iki e-posta işlemi de önce Firebase oturumunu hazırlar', () {
    expect(p.contains('Future<DomainError?> _firebaseOturumuHazirla() async {'), isTrue);
    expect('await _firebaseOturumuHazirla() ??'.allMatches(p).length, 2);
    expect(p.contains('repo.firebaseBaglantiBelgesi()'), isTrue);
    expect(p.contains('FirebaseKimlik.i.ozelBelgeyleBaglan(belge!)'), isTrue);
  });

  test('istemci köprü belgesini doğru uçtan ister', () {
    final a = _kod('lib/data/remote/api/auth_api.dart');
    expect(a.contains("c.post('/auth/firebase/baglanti')"), isTrue);
  });
}
