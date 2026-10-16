// UYGULAMA KAPALIYKEN BİLDİRİM (16 Eki, kullanıcı bulgusu): telefon ayarı
// "Bu uygulama henüz hiç bildirim almadı" diyordu. Firebase yalnız Dart'ta
// başlatıldığı için uygulama kapalıyken gelen bildirimi Android'in yerel
// Firebase servisi işleyemiyordu. Yerel başlatma kaynakları eklendi; değerler
// Dart tarafındaki seçeneklerle BİREBİR aynı olmalı (aksi hâlde iki taraf
// farklı uygulama kimliği kullanır).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/push/firebase_secenekleri.dart';

String _deger(String yol, String ad) {
  final m = RegExp('<string name="$ad"[^>]*>([^<]+)</string>')
      .firstMatch(File(yol).readAsStringSync());
  return m?.group(1) ?? '';
}

void main() {
  const ana = 'android/app/src/main/res/values/firebase_degerleri.xml';
  const debug = 'android/app/src/debug/res/values/firebase_degerleri.xml';

  test('ana (release) kaynaklar Dart android seçenekleriyle aynı', () {
    const o = FirebaseSecenekleri.android;
    expect(_deger(ana, 'google_app_id'), o.appId);
    expect(_deger(ana, 'google_api_key'), o.apiKey);
    expect(_deger(ana, 'gcm_defaultSenderId'), o.messagingSenderId);
    expect(_deger(ana, 'project_id'), o.projectId);
    expect(_deger(ana, 'google_storage_bucket'), o.storageBucket);
  });

  test('debug derlemesi kendi uygulama kimliğini kullanır', () {
    expect(_deger(debug, 'google_app_id'), FirebaseSecenekleri.androidDebug.appId);
  });

  test('kaynak küçültmede korunur', () {
    final k = File('android/app/src/main/res/raw/firebase_kaynaklari_koru.xml').readAsStringSync();
    expect(k.contains('@string/google_app_id'), isTrue);
  });
}
