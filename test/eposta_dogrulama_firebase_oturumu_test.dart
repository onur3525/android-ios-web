// E-POSTA DOĞRULAMA — FIREBASE OTURUM KÖPRÜSÜ YOK (21 Eki, güvenlik Y1)
//
// Önceki sürümde istemci, Firebase oturumu yoksa sunucudan
// (`/auth/firebase/baglanti`) özel belge alıp Firebase'e bağlanıyordu. Bu,
// ele geçirilmiş bir erişim belgesini Firebase'de şifre/e-posta
// değiştirebilen bir oturuma yükseltiyordu. Köprü kaldırıldı: e-posta
// doğrulama ve değişikliği yalnız sunucudan yapılır.
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
  test('istemcide köprü çağrısı yok', () {
    final p = _kod('lib/data/ports/api_ports.dart');
    expect(p.contains('_firebaseOturumuHazirla'), isFalse);
    expect(p.contains('firebaseBaglantiBelgesi'), isFalse);
    expect(p.contains('FirebaseKimlik.i.epostaDegistir('), isFalse);
    expect(p.contains('FirebaseKimlik.i.mevcutEpostaDogrulamaGonder('), isFalse);
    expect(_kod('lib/data/remote/api/auth_api.dart').contains('/auth/firebase/baglanti'), isFalse);
    expect(_kod('lib/data/remote/repositories/api_repositories.dart').contains('firebaseBaglanti'), isFalse);
  });

  test('e-posta kanalı yoksa Firebase\'e düşülmez, açık hata döner', () {
    final p = _kod('lib/data/ports/api_ports.dart');
    expect('return gonderildi ? null : _kanalYok;'.allMatches(p).length, 2);
  });
}
