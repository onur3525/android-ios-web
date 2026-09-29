import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hizmetcep/screens/widgets/profil_fotografi.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';

/// PROFİL BİLGİLERİM — WEB'DE ORTALI AVATAR, KAMERA ROZETİ YOK
///
/// ⚠ MOBİL KİLİTLİ: Android/iOS'ta Profil Bilgilerim ve Profil
/// ekranları DEĞİŞMEZ. Web dalı `kIsWeb` derleme sabitine bağlı
/// olduğu için VM testinde açılamaz; bu yüzden:
///   · bileşenin rozet anahtarı widget testiyle,
///   · ekrandaki web/mobil ayrımı kaynak metniyle kilitlenir.
void main() {
  bool rozetVar(WidgetTester t) => find
      .byWidgetPredicate(
          (w) => w is RefSvg && w.asset == 'assets/svg/ic_cam.svg')
      .evaluate()
      .isNotEmpty;

  Future<void> kur(WidgetTester t, {bool? rozet}) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: rozet == null
            ? const ProfilFotografi(ad: 'Gönül', fotoYolu: '')
            : ProfilFotografi(ad: 'Gönül', fotoYolu: '', kameraRozeti: rozet),
      ),
    ));
  }

  testWidgets('varsayılan: kamera rozeti ÇİZİLİR (mobil davranış)',
      (t) async {
    await kur(t);
    expect(rozetVar(t), isTrue);
  });

  testWidgets('kameraRozeti:false → rozet ÇİZİLMEZ, harf avatarı kalır',
      (t) async {
    await kur(t, rozet: false);
    expect(rozetVar(t), isFalse);
    expect(find.text('G'), findsOneWidget);
  });

  test('Profil Bilgilerim: rozet ve ortalama YALNIZ web', () {
    final k = File('lib/screens/profile_info_screen.dart').readAsStringSync();
    expect(k.contains('kameraRozeti: !kIsWeb'), isTrue,
        reason: 'rozet mobilde de kapanmış olabilir');
    expect(k.contains('child: kIsWeb ? Center(child: foto) : foto'), isTrue,
        reason: 'ortalama mobile de uygulanmış olabilir');
  });

  test('Profil ekranı rozet anahtarını KULLANMAZ (mobil aynen)', () {
    final p = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(p.contains('kameraRozeti'), isFalse);
  });
}
