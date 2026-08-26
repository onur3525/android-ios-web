import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hizmetcep/core/route_guard.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/main.dart';
import 'package:hizmetcep/data/controllers/profile_controller.dart';
import '../support/test_config.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/controllers/region_controller.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/controllers/offer_controller.dart';
import 'package:hizmetcep/data/controllers/contact_controller.dart';
import 'package:hizmetcep/data/controllers/wallet_controller.dart';
import 'package:hizmetcep/data/controllers/chat_controller.dart';
import 'package:hizmetcep/data/controllers/review_controller.dart';
import 'package:hizmetcep/data/controllers/notification_controller.dart';
import 'package:hizmetcep/data/controllers/free_right_controller.dart';
import 'package:hizmetcep/data/controllers/saved_cards_controller.dart';
import 'package:hizmetcep/data/remote/api_config.dart';
import 'package:hizmetcep/screens/splash_screen.dart';

/// ROUTE GUARD ve LOGOUT SONRASI GERİ DÖNÜŞ
///
/// RoleGuard, korumalı ekranların YALNIZ doğru rolde ve açık oturumda
/// çizilmesini sağlar. Deep link ile doğrudan route'a gelinse bile aynı
/// kontrol uygulanır (guard route'un içindedir, çağıranın değil).
void main() {

  // Gerçek uygulama route tablosu üzerinden doğrulama.
  _realRouteTableTests();

  late AuthRepository repo;
  late AuthController auth;

  /// Guard'lı route tablosuna sahip küçük bir uygulama.
  Widget app({String initial = '/'}) {
    repo = AuthRepository();
    auth = AuthController(MockAuthPort(repo));
    return ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp(
        theme: HC.theme(),
        initialRoute: initial,
        routes: {
          '/': (_) => const Scaffold(body: Text('ANA')),
          '/login': (_) => const Scaffold(body: Text('GIRIS')),
          // ⚠ Oturumsuz korumalı route'un hedefi ANA SAYFADIR.
          // Referans `pfLogout()` → `navigate('home')`.
          '/home': (_) => const Scaffold(body: Text('ANA_SAYFA')),
          '/provider/only': (_) => RoleGuard.provider(
                builder: (_) => const Scaffold(body: Text('USTA_EKRANI')),
              ),
          '/customer/only': (_) => RoleGuard.customer(
                builder: (_) => const Scaffold(body: Text('MUSTERI_EKRANI')),
              ),
          '/any/protected': (_) => RoleGuard(
                builder: (_) => const Scaffold(body: Text('KORUMALI')),
              ),
        },
      ),
    );
  }

  Future<void> loginAs(WidgetTester t, Role role) async {
    repo.register(
      phone: kTestPhone, pass: kTestPass, role: role, otpVerified: true, termsAccepted: true,
    );
    await t.pump();
  }

  group('Rol tabanlı erişim', () {
    testWidgets('MÜŞTERİ hizmet veren ekranına GİREMEZ', (t) async {
      await t.pumpWidget(app());
      await loginAs(t, Role.customer);

      final nav = tester0(t);
      nav.pushNamed('/provider/only');
      await t.pumpAndSettle();

      expect(find.text('USTA_EKRANI'), findsNothing);
      expect(find.text('Bu ekrana erişiminiz yok'), findsOneWidget);
    });

    testWidgets('HİZMET VEREN müşteri ekranına GİREMEZ', (t) async {
      await t.pumpWidget(app());
      await loginAs(t, Role.provider);

      tester0(t).pushNamed('/customer/only');
      await t.pumpAndSettle();

      expect(find.text('MUSTERI_EKRANI'), findsNothing);
      expect(find.text('Bu ekrana erişiminiz yok'), findsOneWidget);
    });

    testWidgets('doğru rolde ekran ÇİZİLİR', (t) async {
      await t.pumpWidget(app());
      await loginAs(t, Role.provider);

      tester0(t).pushNamed('/provider/only');
      await t.pumpAndSettle();

      expect(find.text('USTA_EKRANI'), findsOneWidget);
    });

    testWidgets('ROL DEĞİŞİNCE erişim güncellenir', (t) async {
      await t.pumpWidget(app());
      // Her iki role sahip hesap
      repo.register(
        phone: kTestPhone, pass: kTestPass, role: Role.customer,
        otpVerified: true, termsAccepted: true,
      );
      await t.pump();

      tester0(t).pushNamed('/provider/only');
      await t.pumpAndSettle();
      expect(find.text('Bu ekrana erişiminiz yok'), findsOneWidget);

      // Rol hizmet verene geçirilir → aynı ekran artık açılır.
      final acc = repo.currentAccount!;
      acc.roles.add(Role.provider);
      await auth.switchRole(Role.provider);
      await t.pumpAndSettle();

      expect(find.text('USTA_EKRANI'), findsOneWidget);
      expect(find.text('Bu ekrana erişiminiz yok'), findsNothing);
    });

    testWidgets('DEEP LINK guard\'ı AŞAMAZ (doğrudan route ile açılış)',
        (t) async {
      // Uygulama doğrudan korumalı route ile başlatılır (deep link benzeri).
      await t.pumpWidget(app(initial: '/provider/only'));
      await t.pumpAndSettle();

      // Oturum yok → korumalı ekran ÇİZİLMEZ, ana sayfaya yönlenir.
      expect(find.text('USTA_EKRANI'), findsNothing);
      expect(find.text('ANA_SAYFA'), findsOneWidget);
    });

    testWidgets('yetkisiz erişim GÜVENLİ ekrana yönlendirir', (t) async {
      await t.pumpWidget(app(initial: '/any/protected'));
      await t.pumpAndSettle();
      // Oturumsuz korumalı route → /home (rol kartları ekranı)
      expect(find.text('KORUMALI'), findsNothing);
      expect(find.text('ANA_SAYFA'), findsOneWidget);
    });
  });

  group('Logout sonrası geri dönüş', () {
    testWidgets('logout NAVIGATION STACK\'i temizler ve ANA SAYFAYA atar',
        (t) async {
      await t.pumpWidget(app());
      await loginAs(t, Role.provider);

      tester0(t).pushNamed('/provider/only');
      await t.pumpAndSettle();
      expect(find.text('USTA_EKRANI'), findsOneWidget);

      // Korumalı ekrandayken çıkış yapılır.
      await auth.logout();
      await t.pumpAndSettle();

      // Guard oturumsuz kalınca ekranı çizmez ve /home'a yönlendirir.
      expect(find.text('USTA_EKRANI'), findsNothing);
      expect(find.text('ANA_SAYFA'), findsOneWidget);
    });

    testWidgets('GERİ TUŞUYLA korumalı ekrana DÖNÜLEMEZ', (t) async {
      await t.pumpWidget(app());
      await loginAs(t, Role.provider);

      tester0(t).pushNamed('/provider/only');
      await t.pumpAndSettle();

      await auth.logout();
      await t.pumpAndSettle();
      expect(find.text('ANA_SAYFA'), findsOneWidget);

      // Android geri tuşu benzetimi: yığın temizlendiği için geri
      // dönülecek korumalı ekran YOKTUR.
      final popped = await tester0(t).maybePop();
      await t.pumpAndSettle();

      expect(popped, isFalse, reason: 'yığında geri dönülecek ekran kalmamalı');
      expect(find.text('USTA_EKRANI'), findsNothing);
    });

    testWidgets('oturum YOKKEN korumalı route açılamaz', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();

      tester0(t).pushNamed('/any/protected');
      await t.pumpAndSettle();

      expect(find.text('KORUMALI'), findsNothing);
      expect(find.text('ANA_SAYFA'), findsOneWidget);
    });

    testWidgets('OTURUM TEMİZLENMEDEN ana ekrana yönlenilmez', (t) async {
      await t.pumpWidget(app());
      await loginAs(t, Role.provider);

      tester0(t).pushNamed('/provider/only');
      await t.pumpAndSettle();
      expect(find.text('USTA_EKRANI'), findsOneWidget);

      // Oturum hâlâ açık: guard ekranı çizmeye DEVAM eder.
      expect(repo.currentAccount, isNotNull);
      expect(find.text('ANA_SAYFA'), findsNothing);

      // Ancak logout sonrası token temizlenir ve yönlendirme yapılır.
      await auth.logout();
      await t.pumpAndSettle();
      expect(repo.currentAccount, isNull);
      expect(find.text('ANA_SAYFA'), findsOneWidget);
    });
  });
}

/// Testte Navigator'a erişim kısayolu.
NavigatorState tester0(WidgetTester t) =>
    t.state<NavigatorState>(find.byType(Navigator).first);

/// ─────────────────────────────────────────────────────────────────────
/// GERÇEK ROUTE TABLOSU ÜZERİNDEN DOĞRULAMA
///
/// Yukarıdaki testler guard davranışını izole ederken, bu blok
/// UYGULAMANIN KENDİ route kaydını (HizmetCepApp) kullanır — sahte bir
/// MaterialApp ile yetinilmez. Böylece "route tabloda var ama guard'sız"
/// regresyonu yakalanır.
void _realRouteTableTests() {
  group('Gerçek uygulama route tablosu', () {
    late AuthRepository repo;
    late AuthController auth;
    final navKey = GlobalKey<NavigatorState>();

    /// GERÇEK route tablosu (`HizmetCepApp`) ile kurulum.
    ///
    /// ⚠ Uygulamanın kökündeki `MultiProvider` ile AYNI bağımlılıklar
    /// sağlanmalıdır. Guard'ın GEÇİRDİĞİ ekranlar port katmanı dışında
    /// doğrudan `*Api` sınıfı kurar ve `context.read<ApiClient>()`
    /// çağırır (`my_reviews`, `my_categories`, `account_settings`,
    /// `legal`, `app_rate`, `splash`).
    ///
    /// `ApiClient` sağlanmazsa test `ProviderNotFoundError` ile düşer —
    /// bu bir HARNESS eksiğidir, guard davranışı doğrudur.
    Widget realApp() {
      repo = AuthRepository();
      auth = AuthController(MockAuthPort(repo));
      final ports = buildPorts(mode: DataSourceMode.mock);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<ProfileController>(
              create: (_) => ProfileController(MockAuthPort(repo))),
          // Uygulamanın kökündeki wiring ile aynı.
          Provider<ApiClient>.value(value: ports.apiClient),
          ChangeNotifierProvider(
              create: (_) => RegionController(ports.regions)),
          ChangeNotifierProvider(
              create: (_) => ListingController(ports.listings)),
          ChangeNotifierProvider(
              create: (_) =>
                  OfferController(ports.offers, ports.listings, ports.wallet)),
          ChangeNotifierProvider(
              create: (_) => ContactController(
                  ports.contact, ports.offers, ports.wallet)),
          ChangeNotifierProvider(
              create: (_) => WalletController(ports.wallet, ports.auth)),
          ChangeNotifierProvider(create: (_) => ChatController(ports.chat)),
          ChangeNotifierProvider(
              create: (_) => ReviewController(ports.reviews)),
          ChangeNotifierProvider(
              create: (_) => NotificationController(ports.notifications)),
          ChangeNotifierProvider(
              create: (_) => FreeRightController(ports.freeRights)),
          ChangeNotifierProvider(
              create: (_) => SavedCardsController(ports.savedCards)),
        ],
        child: HizmetCepApp(navigatorKey: navKey),
      );
    }

    /// AÇILIŞIN TAMAMLANMASINI BEKLER.
    ///
    /// ⚠ Sabit süreli tek `pump` YETERSİZDİR: açılış bitmeden testin
    /// push ettiği route, boot'un `pushReplacementNamed('/home')`
    /// çağrısıyla EZİLİR ve guard ekranı kaybolur.
    ///
    /// `pumpAndSettle` de kullanılamaz: splash yüzeyindeki yükleniyor
    /// göstergesi sürekli animasyondur ve asla durulmaz.
    ///
    /// Bu yüzden splash ağaçtan kalkana kadar SINIRLI sayıda kare
    /// ilerletilir. Boot davranışı DEĞİŞTİRİLMEZ; yalnız test doğru
    /// ana kadar bekler.
    Future<void> acilisiTamamla(WidgetTester t) async {
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 200));
        if (find.byType(SplashView).evaluate().isEmpty) {
          return;
        }
      }
      fail('Açılış 4 sn içinde tamamlanmadı — splash ekranda kaldı');
    }

    testWidgets('hizmet verene özel route MÜŞTERİ için ÇİZİLMEZ', (t) async {
      await t.pumpWidget(realApp());
      await acilisiTamamla(t);
      repo.register(
        phone: kTestPhone, pass: kTestPass, role: Role.customer,
        otpVerified: true, termsAccepted: true,
      );
      await t.pump();

      navKey.currentState!.pushNamed('/provider/reviews');
      await t.pumpAndSettle();

      // Guard devrede: erişim reddi ekranı görünür.
      expect(find.text('Bu ekrana erişiminiz yok'), findsOneWidget);
    });

    testWidgets('OTURUMSUZ korumalı route giriş ekranına yönlenir',
        (t) async {
      await t.pumpWidget(realApp());
      await acilisiTamamla(t);

      navKey.currentState!.pushNamed('/profile/account');
      await t.pumpAndSettle();

      // Oturum yok → guard ekranı çizmez, /home'a yönlendirir.
      expect(find.text('Bu ekrana erişiminiz yok'), findsNothing);
    });

    testWidgets('KORUMALI route\'ların tamamı RoleGuard ile sarılıdır',
        (t) async {
      await t.pumpWidget(realApp());
      await acilisiTamamla(t);
      repo.register(
        phone: kTestPhone, pass: kTestPass, role: Role.customer,
        otpVerified: true, termsAccepted: true,
      );
      await t.pump();

      // Hizmet verene özel route'lar müşteri oturumunda ASLA çizilmemeli.
      for (final r in const [
        '/provider/reviews', '/provider/categories',
        '/provider/areas', '/provider/wallet', '/provider/topup',
      ]) {
        navKey.currentState!.pushNamed(r);
        await t.pumpAndSettle();
        expect(find.text('Bu ekrana erişiminiz yok'), findsOneWidget,
            reason: '$r guard\'sız olabilir');
        navKey.currentState!.pop();
        await t.pumpAndSettle();
      }
    });
  });
}
