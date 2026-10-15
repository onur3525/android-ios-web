import 'dart:async';

import 'support/test_config.dart';

/// `flutter test` bu dosyayı `test/` altındaki HER test dosyasından
/// önce çalıştırır. Test hesabı ve test OTP doğrulayıcısı yalnız
/// buradan kurulur; uygulama kaynağında karşılıkları YOKTUR.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  testOrtaminiKur();
  await testMain();
}
