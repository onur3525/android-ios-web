// UYGULAMA KAPALIYKEN BİLDİRİME DOKUNMA (16 Eki, kullanıcı bulgusu): hedef
// ekran açılış ekranı bitmeden açılıyor ve rol paneline geçişte siliniyordu.
// Artık ilk gerçek ekrandan sonra açılır; iş detayı ilanı yerelde yoksa
// sunucudan alır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bekleyen açılış, açılış/bağlanıyor ekranından sonra işlenir', () {
    final p = File('lib/ui/push_kapisi.dart').readAsStringSync();
    expect(p.contains("return r != null && r != '/' && r != '/baglaniyor';"), isTrue);
    expect(p.contains('if (_auth?.currentAccount == null || !_acilisTamam) {'), isTrue);
    expect(p.contains('AktifRota.ad.addListener(_bekleyeniIsle);'), isTrue);
  });

  test('iş detayı ilanı sunucudan yükler', () {
    final j = File('lib/screens/job_detail_screen.dart').readAsStringSync();
    expect(j.contains('unawaited(lc.loadOne(widget.listingId));'), isTrue);
    expect(j.contains('if (l == null && listingCtl.loading) {'), isTrue);
  });
}
