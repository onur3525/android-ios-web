// BİLDİRİM SİMGESİ (16 Eki, kullanıcı isteği): bildirim gelince durum
// çubuğunda beyaz kare değil HizmetCep logosu görünür.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tek renk logo her yoğunlukta var ve manifestte varsayılan', () {
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('android/app/src/main/res/drawable-$d/ic_stat_hizmetcep.png').existsSync(), isTrue, reason: d);
    }
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m.contains('com.google.firebase.messaging.default_notification_icon'), isTrue);
    expect(m.contains('@drawable/ic_stat_hizmetcep'), isTrue);
    expect(m.contains('@color/hc_blue'), isTrue);
  });
}
