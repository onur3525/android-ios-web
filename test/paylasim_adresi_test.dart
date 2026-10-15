// Paylaşım bağlantısı (16 Eki): test/canlı deneme sürümleri (mobil + web)
// test adresini paylaşır; production web derlemesi hizmetcep.com'u.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/config.dart';

void main() {
  test('production dışı derleme test adresini paylaşır', () {
    expect(DomainConfig.paylasimAdresi, 'https://onur3525.github.io/android-ios-web/');
    expect(DomainConfig.shareText.endsWith(DomainConfig.paylasimAdresi), isTrue);
  });

  test('test yayını önizleme adreslerini test adresine çevirir', () {
    final w = File('.github/workflows/web-test.yml').readAsStringSync();
    expect(w.contains('onur3525.github.io/android-ios-web/og-paylasim.png'), isTrue);
  });
}
