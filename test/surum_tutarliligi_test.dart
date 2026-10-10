import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/api_config.dart';

/// Zorunlu güncelleme kontrolü `ApiConfig.appVersion` ile çalışır; değer
/// `pubspec.yaml` sürüm adından farklı olursa uygulama kendini yanlış
/// sürümde sanar. Tek kaynak `pubspec.yaml`dır.
void main() {
  test('ApiConfig.appVersion pubspec.yaml sürüm adıyla aynı', () {
    final satir = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final ad = satir.split(':').last.trim().split('+').first;
    expect(ApiConfig.appVersion, ad);
  });
}
