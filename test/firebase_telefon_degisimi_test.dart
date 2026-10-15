// TELEFON DEĞİŞİMİ — Firebase Auth numarası (15 Eki güvenlik denetimi):
// telefon değişiminde numara açık Firebase kullanıcısına `updatePhoneNumber`
// ile bağlanır; web'de de (`confirm()` ayrı kullanıcı açıyordu). Sunucu
// belgede hesabın Firebase uid'sini ister (backend/test/firebase_oturum_iptali).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final k = File('lib/data/remote/firebase_kimlik.dart').readAsStringSync();

  test('telefon değişiminde web dahil updatePhoneNumber; confirm/signIn yalnız giriş için', () {
    final iDegisim = k.indexOf('if (mevcutKullanici && u != null) {');
    final iConfirm = k.indexOf('sonuc = await b.onay!.confirm(kod.trim());');
    expect(iDegisim, greaterThan(0));
    expect(iDegisim, lessThan(iConfirm),
        reason: 'telefon değişimi confirm() öncesinde ayrılmalı');
    expect(k.contains('verificationId: b.onay!.verificationId'), isTrue,
        reason: 'web doğrulama kimliğinden kimlik bilgisi üretilir');
    expect('await u.updatePhoneNumber(kimlik);'.allMatches(k).length, 1);
  });

  test('işlemi yapan cihaz Firebase\'e yeniden bağlanır: şifrede yeni şifreyle, telefonda özel belgeyle', () {
    expect(k.contains('await a.signInWithEmailAndPassword(email: email, password: yeniSifre);'), isTrue);
    expect(k.contains('await a.signInWithCustomToken(belge);'), isTrue);
    final p = File('lib/data/ports/api_ports.dart').readAsStringSync();
    expect(p.contains('await FirebaseKimlik.i.yeniSifreyleYenidenBaglan(next);'), isTrue);
    expect(p.contains('await FirebaseKimlik.i.ozelBelgeyleBaglan(ozel);'), isTrue);
    final r = File('lib/data/remote/repositories/api_repositories.dart').readAsStringSync();
    expect(r.contains("res!['firebaseCustomToken']"), isTrue);
  });
}
