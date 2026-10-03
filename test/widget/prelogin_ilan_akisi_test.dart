import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/controllers/pending_listing_controller.dart';
import 'package:hizmetcep/data/controllers/region_controller.dart';
import 'package:hizmetcep/data/models/account.dart';
import 'package:hizmetcep/data/models/pending_listing.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/data/repositories/pending_listing_store.dart';
import 'package:hizmetcep/screens/category_screen.dart';
import 'package:hizmetcep/screens/create_listing_screen.dart';
import 'package:hizmetcep/screens/prelogin_listing_route.dart';
import 'package:hizmetcep/screens/role_select_screen.dart';
import '../support/test_config.dart';
import 'package:hizmetcep/data/controllers/listing_controller.dart';
import 'package:hizmetcep/data/ports/repository_ports.dart';
import 'package:hizmetcep/data/remote/api_client.dart';
import 'package:hizmetcep/data/remote/api_config.dart';
import 'package:hizmetcep/main.dart';

/// Bellek içi taslak deposu (platform kanalı gerekmez).
class _FakeStore implements PendingListingStore {
  String? raw;
  @override
  Future<PendingListing?> read() async => PendingListing.decode(raw);
  @override
  Future<void> save(PendingListing p) async => raw = p.encode();
  @override
  Future<void> clear() async => raw = null;
}

void main() {
  late AuthRepository repo;
  late AuthController auth;
  late PendingListingController pending;
  late _FakeStore store;
  late ListingPort listingPort;
  late ApiClient apiClient;

  setUp(() {
    repo = AuthRepository(seedTestAccount: false);
    auth = AuthController(MockAuthPort(repo));
    store = _FakeStore();
    pending = PendingListingController(store);
    final ports = buildPorts(mode: DataSourceMode.mock);
    listingPort = ports.listings;
    apiClient = ports.apiClient;
  });

  Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<PendingListingController>.value(
              value: pending),
          ChangeNotifierProvider(
              create: (_) => RegionController(MockRegionPort())..load()),
          // ⚠ Ekranların GERÇEK bağımlılıkları:
          //   CategoryScreen / SearchScreen → ListingController
          //   CreateListingScreen           → ApiClient (StorageApi)
          // Eksikse `ProviderNotFoundError` ile düşer.
          ChangeNotifierProvider(
              create: (_) => ListingController(listingPort)),
          Provider<ApiClient>.value(value: apiClient),
        ],
        child: MaterialApp(
          home: home,
          routes: {
            PreLoginListingRoute.name: preLoginListingBuilder,
          },
        ),
      );

  /// Oturum açar ve verilen rolleri tanımlar.
  void oturumAc({required Set<Role> roller, Role? aktif}) {
    repo.register(
      phone: kTestPhone,
      pass: kTestPass,
      role: roller.first,
      otpVerified: true,
      termsAccepted: true,
      name: 'Test Kullanıcı',
      email: 'test@ornek.com',
    );
    final acc = repo.currentAccount!;
    acc.roles.addAll(roller);
    acc.activeRole = aktif ?? roller.first;
  }

  group('A — Giriş yolları', () {
    testWidgets('1/3/4/5. kategori → public form, RoleSelectScreen YOK',
        (t) async {
      await t.pumpWidget(app(const CategoryScreen(category: 'Su Tesisatı')));
      await t.pumpAndSettle();

      // Alt hizmet çipine dokun.
      //
      // ⚠ Kategori ↔ alt hizmet TUTARLI olmalı. Adlar katalogdan
      // gelir (`category_tree.dart`):
      //   'Su Tesisatçısı' ∈ Su Tesisatı · 'Kombi Bakımı' ∈ Kombi
      // ⚠ ÇİP KALKTI, SATIR GELDİ (15 Ağu): kategori ekranında
      // hizmetler tek sütun satır olarak listeleniyor ve TEK seçim
      // yapılıyor. Seçimden sonra "Devam Et" ile akış sürüyor.
      final satir = find.text('Su Tesisatçısı');
      expect(satir, findsOneWidget, reason: 'hizmet satırı çizilmedi');
      await t.tap(satir);
      await t.pumpAndSettle();

      // ⚠ DÜĞME LİSTENİN ALTINDA: `ListView` görünmeyen çocuğu
      // ÇİZMEZ, bu yüzden önce kaydırılır. Kaydırmadan aranırsa
      // "0 widget bulundu" hatası alınır.
      await t.scrollUntilVisible(find.text('Devam Et'), 200,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Devam Et'));
      await t.pumpAndSettle();

      expect(find.byType(RoleSelectScreen), findsNothing,
          reason: 'bu akışta rol seçim ekranı AÇILMAZ');
      final form = t.widget<CreateListingScreen>(
          find.byType(CreateListingScreen));
      expect(form.preLogin, isTrue, reason: 'public taslak formu');
      expect(form.initialCategory, 'Su Tesisatı');
      expect(form.initialSubService, 'Su Tesisatçısı');
    });

    testWidgets('oturumlu MÜŞTERİ korumalı forma gider (preLogin false)',
        (t) async {
      oturumAc(roller: {Role.customer});
      await t.pumpWidget(app(const CategoryScreen(category: 'Su Tesisatı')));
      await t.pumpAndSettle();
      // ⚠ Satırlar kategorinin ALT HİZMETLERİDİR.
      // ⚠ Çip → satır + "Devam Et" (15 Ağu, tek seçim kuralı).
      await t.tap(find.text('Su Tesisatçısı'));
      await t.pumpAndSettle();
      // ⚠ Düğme listenin altında; önce kaydırılır (bkz. yukarıdaki not).
      await t.scrollUntilVisible(find.text('Devam Et'), 200,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Devam Et'));
      await t.pumpAndSettle();

      final form = t.widget<CreateListingScreen>(
          find.byType(CreateListingScreen));
      expect(form.preLogin, isFalse);
      expect(form.initialSubService, 'Su Tesisatçısı');
    });
  });

  group('Provider-only kullanıcı', () {
    testWidgets('yalnız HİZMET VEREN rolü → sessiz ölü dal YOK', (t) async {
      oturumAc(roller: {Role.provider});
      await t.pumpWidget(app(const CategoryScreen(category: 'Su Tesisatı')));
      await t.pumpAndSettle();
      // ⚠ Satırlar kategorinin ALT HİZMETLERİDİR.
      // ⚠ Çip → satır + "Devam Et" (15 Ağu, tek seçim kuralı).
      await t.tap(find.text('Su Tesisatçısı'));
      await t.pumpAndSettle();
      // ⚠ Düğme listenin altında; önce kaydırılır (bkz. yukarıdaki not).
      await t.scrollUntilVisible(find.text('Devam Et'), 200,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Devam Et'));
      await t.pumpAndSettle();

      expect(find.byType(CreateListingScreen), findsOneWidget);
      final form = t.widget<CreateListingScreen>(
          find.byType(CreateListingScreen));
      // Sağlayıcı ilan formuna GÖNDERİLMEZ; taslak formu açılır.
      expect(form.preLogin, isTrue,
          reason: 'yetkisiz customer route\'una zorlanmamalı');
      expect(find.byType(RoleSelectScreen), findsNothing);
    });

    testWidgets('her İKİ role sahip kullanıcı korumalı forma gider',
        (t) async {
      oturumAc(roller: {Role.customer, Role.provider}, aktif: Role.provider);
      await t.pumpWidget(app(const CategoryScreen(category: 'Su Tesisatı')));
      await t.pumpAndSettle();
      // ⚠ Satırlar kategorinin ALT HİZMETLERİDİR.
      // ⚠ Çip → satır + "Devam Et" (15 Ağu, tek seçim kuralı).
      await t.tap(find.text('Su Tesisatçısı'));
      await t.pumpAndSettle();
      // ⚠ Düğme listenin altında; önce kaydırılır (bkz. yukarıdaki not).
      await t.scrollUntilVisible(find.text('Devam Et'), 200,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Devam Et'));
      await t.pumpAndSettle();

      final form = t.widget<CreateListingScreen>(
          find.byType(CreateListingScreen));
      expect(form.preLogin, isFalse);
      expect(auth.activeRole, Role.customer,
          reason: 'hizmet ALMA niyeti için müşteri rolüne geçilir');
    });
  });

  group('B — Taslak korunması', () {
    testWidgets('15. route değişiminde pending draft KAYBOLMAZ', (t) async {
      await pending.saveDraft(PendingListing(
        category: 'Tesisat',
        subService: 'Kombi Bakımı',
        description: 'Açıklama metni burada.',
        city: 'İzmir',
        district: 'Bornova',
        neighborhood: 'Erzene',
        createdAt: DateTime(2026),
      ));

      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<PendingListingController>.value(
              value: pending),
        ],
        child: MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('A')),
          routes: {'/b': (_) => const Scaffold(body: Text('B'))},
        ),
      ));
      await t.pumpAndSettle();

      nav.currentState!.pushNamed('/b');
      await t.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(pending.hasDraft, isTrue, reason: 'route değişimi taslağı silmez');

      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(pending.hasDraft, isTrue);
      expect(pending.draft!.subService, 'Kombi Bakımı');
    });

    testWidgets('16. uygulama KAPANIP açılınca taslak okunur', (t) async {
      await pending.saveDraft(PendingListing(
        category: 'Elektrik',
        description: 'Priz arızası var.',
        city: 'İzmir',
        district: 'Konak',
        neighborhood: 'Alsancak',
        localPhotoPaths: const ['/yok/foto.jpg'],
        createdAt: DateTime(2026),
      ));

      // Yeni uygulama yaşam döngüsü: controller sıfırdan kurulur,
      // AYNI kalıcı depo kullanılır.
      final yeni = PendingListingController(store);
      await yeni.load();
      expect(yeni.hasDraft, isTrue);
      // ⚠ Taslak YUKARIDA 'Elektrik' ile kuruldu; bu bir VERİ
      // değeridir, katalog araması değil. Toplu ad değişiminde
      // yanlışlıkla güncellenmişti.
      expect(yeni.draft!.category, 'Elektrik');
      expect(yeni.draft!.neighborhood, 'Alsancak');
      expect(yeni.draft!.localPhotoPaths, ['/yok/foto.jpg']);

      // Fotoğraf artık erişilemez → kullanıcı müdahalesi akışı.
      var cagri = 0;
      final r = await yeni.publishIfAny(yayinla: (_, __) async {
        cagri++;
        return true;
      });
      expect(r, PendingPublishOutcome.eksikFotograf);
      expect(cagri, 0, reason: 'sessiz veri kaybı YOK');
      expect(yeni.hasDraft, isTrue, reason: 'crash yok, taslak korunur');
    });
  });

  group('C/D — Yayın kapısı (onboarding)', () {
    /// Gerçek publish kapısı: `customerOnboardingComplete`.
    Future<PendingPublishOutcome> yayinDene(Account acc) async {
      if (!acc.roles.contains(Role.customer) ||
          !acc.customerOnboardingComplete) {
        return PendingPublishOutcome.yok;
      }
      return pending.publishIfAny(yayinla: (_, __) async => true);
    }

    setUp(() async {
      await pending.saveDraft(PendingListing(
        category: 'Tesisat',
        description: 'Açıklama metni burada.',
        city: 'İzmir',
        district: 'Bornova',
        neighborhood: 'Erzene',
        createdAt: DateTime(2026),
      ));
    });

    test('19. SMS OTP tamamlanmadan publish YOK', () async {
      oturumAc(roller: {Role.customer});
      final acc = repo.currentAccount!..phoneVerified = false;
      expect(await yayinDene(acc), PendingPublishOutcome.yok);
      expect(pending.hasDraft, isTrue);
    });

    test('20. e-posta doğrulanmadan publish YOK', () async {
      oturumAc(roller: {Role.customer});
      final acc = repo.currentAccount!;
      acc.address =
          Address(id: 'a', district: 'Bornova', neighborhood: 'Erzene');
      expect(acc.emailVerified, isFalse);
      expect(await yayinDene(acc), PendingPublishOutcome.yok);
      expect(pending.hasDraft, isTrue);
    });

    test('21. adres/onboarding eksikken publish YOK', () async {
      oturumAc(roller: {Role.customer});
      final acc = repo.currentAccount!;
      repo.completeEmailVerification('123456');
      expect(acc.address, isNull);
      expect(await yayinDene(acc), PendingPublishOutcome.yok);
      expect(pending.hasDraft, isTrue);
    });

    test('22/28. tüm zorunluluklar tamam → TEK publish, taslak silinir',
        () async {
      oturumAc(roller: {Role.customer});
      final acc = repo.currentAccount!;
      acc.address =
          Address(id: 'a', district: 'Bornova', neighborhood: 'Erzene');
      repo.completeEmailVerification('123456');
      expect(acc.customerOnboardingComplete, isTrue);

      expect(await yayinDene(acc), PendingPublishOutcome.yayinlandi);
      expect(pending.hasDraft, isFalse);
      expect(store.raw, isNull);

      // İkinci çağrı yeni ilan ÜRETMEZ.
      expect(await yayinDene(acc), PendingPublishOutcome.yok);
    });

    test('23. provider-only kullanıcı için publish YOK', () async {
      oturumAc(roller: {Role.provider});
      expect(await yayinDene(repo.currentAccount!),
          PendingPublishOutcome.yok);
      expect(pending.hasDraft, isTrue);
    });

    test('rol eklenip onboarding tamamlanınca taslak yayınlanır', () async {
      oturumAc(roller: {Role.provider});
      final acc = repo.currentAccount!;
      // Hizmet Alan rolü mevcut `addRole` sözleşmesiyle eklenir.
      expect(repo.addRole(Role.customer), isNull);
      acc.address =
          Address(id: 'a', district: 'Bornova', neighborhood: 'Erzene');
      repo.completeEmailVerification('123456');

      expect(await yayinDene(acc), PendingPublishOutcome.yayinlandi,
          reason: 'taslak rol tamamlanana kadar KORUNDU');
    });
  });

  group('Google kayıt akışı', () {
    test('Google ile kayıt sırasında taslak KAYBOLMAZ', () async {
      await pending.saveDraft(PendingListing(
        category: 'Boya',
        subService: 'İç Cephe Boya',
        description: 'Salon boyanacak.',
        city: 'İzmir',
        district: 'Bornova',
        neighborhood: 'Erzene',
        createdAt: DateTime(2026),
      ));

      // Doğrulanmış e-postayla kayıt (eski Google kaydının yerini alan akış;
      // `googleSub` parametresi Google girişi kaldırılınca API'den çıktı).
      final r = repo.register(
        phone: '5401112233',
        pass: 'g-oauth',
        role: Role.customer,
        otpVerified: true,
        termsAccepted: true,
        name: 'Ayşe Yılmaz',
        email: 'ayse@gmail.com',
        emailVerified: true,
      );
      expect(r.error, isNull);
      expect(pending.hasDraft, isTrue, reason: 'kayıt taslağı silmez');

      final acc = r.account!;
      // ⚠ Google e-postası doğrulanmış olsa da ADRES eksikse publish YOK.
      expect(acc.customerOnboardingComplete, isFalse);
      expect(acc.missingSteps, contains(OnboardingStep.address));

      acc.address =
          Address(id: 'a', district: 'Bornova', neighborhood: 'Erzene');
      expect(acc.customerOnboardingComplete, isTrue);

      final sonuc = await pending.publishIfAny(yayinla: (p, __) async {
        expect(p.subService, 'İç Cephe Boya', reason: 'alt hizmet korundu');
        return true;
      });
      expect(sonuc, PendingPublishOutcome.yayinlandi);
      expect(pending.hasDraft, isFalse);
    });
  });

  group('E — photo_picker davranışı', () {
    test('preLogin formu uploadEnabled=false geçirir', () {
      final src =
          File('lib/screens/create_listing_screen.dart').readAsStringSync();
      expect(src.contains('uploadEnabled: !widget.preLogin'), isTrue);
    });

    test('uploadEnabled=false iken yükleme dalı ERKEN döner', () {
      final pp =
          File('lib/screens/widgets/photo_picker.dart').readAsStringSync();
      final i = pp.indexOf('Future<void> _upload(PhotoItem p) async {');
      expect(i, greaterThan(0), reason: '_upload metodu bulunamadı');

      // ⚠ SABİT PENCERE KULLANILMAZ: yorum/biçim değiştiğinde
      // pencere metot gövdesini kesip testi yanıltıyordu.
      // Gövde SÜSLÜ PARANTEZ DENGESİYLE çıkarılır — biçimden bağımsız,
      // semantik AYNI: guard, backend çağrısından ÖNCE olmalı.
      final acilis = pp.indexOf('{', i);
      var derinlik = 0;
      var kapanis = acilis;
      for (var k = acilis; k < pp.length; k++) {
        if (pp[k] == '{') {
          derinlik++;
        } else if (pp[k] == '}') {
          derinlik--;
          if (derinlik == 0) {
            kapanis = k;
            break;
          }
        }
      }
      expect(kapanis, greaterThan(acilis), reason: 'gövde çıkarılamadı');
      final govde = pp.substring(acilis, kapanis + 1);

      final iGuard = govde.indexOf('if (!widget.uploadEnabled)');
      final iUpload = govde.indexOf('createUploadRef');
      expect(iGuard, greaterThanOrEqualTo(0),
          reason: 'uploadEnabled guard\'ı YOK');
      expect(iUpload, greaterThan(iGuard),
          reason: 'kayıtsızken backend çağrısı YAPILMAMALI — '
              'guard createUploadRef\'ten ÖNCE gelmeli');
    });

    test('authenticated akışta upload varsayılan AÇIK', () {
      final pp =
          File('lib/screens/widgets/photo_picker.dart').readAsStringSync();
      expect(pp.contains('this.uploadEnabled = true'), isTrue);
      // Mevcut kurallar bozulmadı.
      expect(pp.contains('kMaxListingPhotos = 5'), isTrue);
      expect(pp.contains('kMaxPhotoBytes = 10 * 1024 * 1024'), isTrue);
    });
  });
}
