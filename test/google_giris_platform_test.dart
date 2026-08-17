import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/platform_kapilari.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/controllers/region_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/screens/login_screen.dart';
import 'package:hizmetcep/screens/register_screen.dart';
import 'package:provider/provider.dart';

/// GOOGLE İLE GİRİŞ — PLATFORM GÖRÜNÜRLÜĞÜ
///
/// ⚠ SÖZLEŞME: "Google ile Devam Et" düğmesi ANDROID'DE VARDIR,
/// iOS'TA YOKTUR.
///
/// Gerekçe (App Store kuralı 4.8): üçüncü taraf giriş servisi sunan
/// uygulamalardan eşdeğer bir giriş seçeneği daha isteniyor. Aynı
/// kuralın muafiyeti şudur: uygulama YALNIZCA kendi hesap sistemini
/// kullanıyorsa gerekmez. HizmetCep'in kendi iki yolu (e-posta+şifre,
/// telefon+SMS) zaten var; Google iOS'ta gizlenince muafiyet birebir
/// uygulanır. Sign in with Apple EKLENMEDİ — o yol ortak giriş
/// ekranlarını değiştirirdi ve Android tasarımı korunamazdı.
///
/// ⚠ BU BİR WIDGET TESTİDİR, kaynak-metin testi değil: ekranlar
/// gerçekten pump edilir ve düğmenin varlığı/yokluğu ağaçta aranır.
///
/// ⚠ `google_sign_in` paketi KALDIRILMADI; Android'de kullanılıyor.
/// Aşağıda pubspec de denetleniyor — paketin sessizce düşmediğinden
/// emin olmak için.
void main() {
  /// ⚠ PLATFORM GEÇERSİZ KILMASI GÖVDE BİTMEDEN SIFIRLANIR.
  ///
  /// Flutter test çatısı, test gövdesi biter bitmez
  /// `debugAssertAllFoundationVarsUnset` ile denetim yapar ve
  /// `debugDefaultTargetPlatformOverride` hâlâ set ise testi düşürür:
  /// "The value of a foundation debug variable was changed by the
  /// test."
  ///
  /// ⚠ NE `tearDown` NE `addTearDown` YETİYOR — İKİSİ DE GEÇ.
  /// Denetim `_runTestBody` içinde, gövdenin hemen ardında çalışıyor;
  /// her iki kanca da ondan SONRA tetikleniyor. (Bunu iki koşuda
  /// ölçtük: önce `tearDown` denendi, sonra `addTearDown`; ikisi de
  /// aynı hatayla düştü.)
  ///
  /// Doğrusu sıfırlamayı GÖVDENİN İÇİNDE yapmaktır. Bu yardımcı
  /// platformu ayarlar, gövdeyi çalıştırır ve `finally` ile —
  /// gövde hata atsa bile — sıfırlar.
  ///
  /// ⚠ Platform yalnız AĞAÇ KURULURKEN okunur; `pump` sonrası
  /// sıfırlamak beklentileri etkilemez.
  Future<void> platformda(
      TargetPlatform p, Future<void> Function() govde) async {
    debugDefaultTargetPlatformOverride = p;
    try {
      await govde();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Widget loginApp() {
    final repo = AuthRepository();
    return ChangeNotifierProvider(
      create: (_) => AuthController(MockAuthPort(repo)),
      child: MaterialApp(theme: HC.theme(), home: const LoginScreen()),
    );
  }

  Widget registerApp() {
    final repo = AuthRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthController(MockAuthPort(repo))),
        ChangeNotifierProvider(
            create: (_) => RegionController(MockRegionPort())),
      ],
      child: MaterialApp(
        theme: HC.theme(),
        home: const RegisterScreen(role: Role.customer),
      ),
    );
  }

  // ⚠ İKİ EKRANDA METİN FARKLI: girişte "Devam Et", kayıtta
  // "Kaydol". Aynı bulucu ikisinde de kullanılamaz.
  final girisDugmesi = find.text('Google ile Devam Et');
  final kayitDugmesi = find.text('Google ile Kaydol');

  group('1 — ANDROID: düğme VAR', () {
    testWidgets('giriş ekranı', (t) async {
      await platformda(TargetPlatform.android, () async {
        await t.pumpWidget(loginApp());
        await t.pump();
        expect(girisDugmesi, findsOneWidget,
            reason: 'Android\'de Google düğmesi kaldırılmış');
      });
    });

    testWidgets('kayıt ekranı', (t) async {
      await platformda(TargetPlatform.android, () async {
        await t.pumpWidget(registerApp());
        await t.pump();
        expect(kayitDugmesi, findsOneWidget,
            reason: 'Android\'de Google düğmesi kaldırılmış');
      });
    });
  });

  group('2 — iOS: düğme YOK', () {
    testWidgets('giriş ekranı', (t) async {
      await platformda(TargetPlatform.iOS, () async {
        await t.pumpWidget(loginApp());
        await t.pump();
        expect(girisDugmesi, findsNothing,
            reason: 'iOS\'ta Google düğmesi görünüyor — 4.8 riski');
      });
    });

    testWidgets('kayıt ekranı', (t) async {
      await platformda(TargetPlatform.iOS, () async {
        await t.pumpWidget(registerApp());
        await t.pump();
        expect(kayitDugmesi, findsNothing,
            reason: 'iOS\'ta Google düğmesi görünüyor — 4.8 riski');
      });
    });
  });

  group('3 — Sahipsiz "veya" ayırıcısı kalmaz', () {
    // ⚠ Düğme gizlenip ayırıcı kalsaydı ekranda anlamsız bir çizgi
    // dururdu. İkisi AYNI koşulun içindedir.
    testWidgets('iOS giriş ekranında ayırıcı da gizlenir', (t) async {
      await platformda(TargetPlatform.iOS, () async {
        await t.pumpWidget(loginApp());
        await t.pump();
        expect(find.text('veya'), findsNothing,
            reason: 'düğme gizlendi ama ayırıcı kaldı');
      });
    });

    testWidgets('Android giriş ekranında ayırıcı DURUR', (t) async {
      await platformda(TargetPlatform.android, () async {
        await t.pumpWidget(loginApp());
        await t.pump();
        expect(find.text('veya'), findsOneWidget,
            reason: 'Android\'de ayırıcı kaybolmuş');
      });
    });
  });

  group('4 — Kapı fonksiyonunun kendisi', () {
    test('android → true, iOS → false', () {
      // ⚠ Bu düz bir test; sıfırlama yine GÖVDE İÇİNDE yapılır.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(googleGirisiGosterilir, isTrue);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(googleGirisiGosterilir, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('5 — Paket ve iş mantığı KALDIRILMADI', () {
    test('google_sign_in pubspec\'te duruyor', () {
      // ⚠ Gizlenen yalnız iOS'taki GÖRÜNÜRLÜKTÜR. Paket Android'de
      // kullanılıyor; düşerse Android girişi kırılır.
      final p = File('pubspec.yaml').readAsStringSync();
      expect(p.contains('google_sign_in:'), isTrue,
          reason: 'google_sign_in pubspec\'ten çıkarılmış');
    });

    test('GoogleAuthService ve çağrıları duruyor', () {
      expect(File('lib/data/services/google_auth_service.dart').existsSync(),
          isTrue);
      for (final yol in [
        'lib/screens/login_screen.dart',
        'lib/screens/register_screen.dart',
      ]) {
        final k = File(yol).readAsStringSync();
        expect(k.contains('GoogleAuthService()'), isTrue,
            reason: '$yol: Google giriş çağrısı silinmiş');
      }
    });
  });
}
