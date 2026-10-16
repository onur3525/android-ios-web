// TEKLİF İSTEKLERİ — HİZMET ALAN FOTOĞRAFI (16 Eki, kullanıcı bulgusu):
// iletişim açılınca (teklif verildi) kartta hizmet alanın profil fotoğrafı
// görünür; açılmadan önce kilitli simge kalır. Sohbet listesinde de karşı
// tarafın fotoğrafı görünür.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kart: açıkken fotoğraf, kapalıyken kilit', () {
    final s = File('lib/screens/teklif_istekleri_screen.dart').readAsStringSync();
    expect(s.contains('fotoYolu: hizmetAlan?.fotografi(Role.customer) ??'), isTrue);
    expect(s.contains("const RefSvg('assets/svg/ic_avlock.svg', size: 44)"), isTrue);
    expect(s.indexOf('ProfilAvatari('), lessThan(s.indexOf("ic_avlock.svg")));
  });

  test('sohbet listesi karşı tarafın fotoğrafını kullanır', () {
    final s = File('lib/screens/chat_screen.dart').readAsStringSync();
    expect(s.contains('fotoYolu: other?.fotografi(me.id == o.providerId'), isTrue);
  });
}
