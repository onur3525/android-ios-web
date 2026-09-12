import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/route_guard.dart';
import 'screens/account_settings_screen.dart';
import 'screens/addresses_screen.dart';
import 'screens/app_rate_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/create_listing_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/my_areas_screen.dart';
import 'screens/my_categories_screen.dart';
import 'screens/find_provider_screen.dart';
import 'screens/my_listings_screen.dart';
import 'screens/my_reviews_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_info_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/provider_status_screen.dart';
import 'core/deep_links.dart';
import 'core/offline_banner.dart';
import 'core/boot_log.dart';
import 'core/theme.dart';
import 'core/yonlendirme.dart';
import 'data/controllers/auth_controller.dart';
import 'data/controllers/chat_controller.dart';
import 'data/controllers/contact_controller.dart';
import 'data/controllers/teklif_talebi_controller.dart';
import 'data/ports/teklif_talebi_port.dart';
import 'data/repositories/teklif_talebi_repository.dart';
import 'data/controllers/listing_controller.dart';
import 'data/controllers/notification_controller.dart';
import 'data/controllers/offer_controller.dart';
import 'data/controllers/profile_controller.dart';
import 'data/controllers/review_controller.dart';
import 'data/models/account.dart';
import 'data/ports/api_ports.dart';
import 'data/ports/mock_ports.dart';
import 'data/repositories/account_test_store.dart';
import 'data/ports/repository_ports.dart';
import 'data/remote/api_client.dart';
import 'data/remote/api_config.dart';
import 'data/remote/api/auth_api.dart';
import 'data/remote/api/chat_api.dart';
import 'data/remote/api/notification_api.dart';
import 'data/remote/api/review_api.dart';
import 'data/remote/api/contact_api.dart';
import 'data/remote/api/listing_api.dart';
import 'data/remote/api/offer_api.dart';
import 'data/remote/api/profile_api.dart';
import 'data/remote/repositories/api_chat_repositories.dart';
import 'data/remote/repositories/api_repositories.dart';
import 'data/remote/ws_auth.dart';
import 'data/remote/ws_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/demo_hesap_ozetleri.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/contact_repository.dart';
import 'data/repositories/listing_repository.dart';
import 'data/models/listing.dart';
import 'data/models/offer.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'data/repositories/review_repository.dart';
import 'domain/config.dart';
import 'data/services/listing_expiry_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_select_screen.dart';
import 'data/controllers/region_controller.dart';
import 'data/remote/api/region_api.dart';
import 'screens/splash_screen.dart';
import 'screens/prelogin_listing_route.dart';
import 'data/controllers/pending_listing_controller.dart';
import 'data/repositories/pending_listing_store.dart';
import 'data/controllers/incelenen_ilan_controller.dart';
import 'data/repositories/incelenen_ilan_store.dart';

/// Uygulamanın kurduğu port kümesi — controller'lar somut repository
/// OLUŞTURMAZ, yalnız bu portları alır.
class AppPorts {
  final AuthPort auth;
  final ListingPort listings;
  final OfferPort offers;
  final ContactPort contact;

  final ChatPort chat;
  final ReviewPort reviews;
  final NotificationPort notifications;

  /// ── ⚠ "DOĞRUDAN TEKLİF İSTE" BİLDİRİMLERİ İÇİN ──
  ///
  /// Diğer mock port'lar (`MockOfferPort` vb.) zaten `notifs:
  /// notifRepo` alıp başarılı eylemlerde `notifs?.push(...)` çağırır
  /// — AYNI ÖRNEĞİ `MockTeklifTalebiPort`e de vermek için buradan
  /// dışa açıldı. API modunda YOKTUR (`null`) — gerçek bildirimler
  /// sunucudan gelir, yerel depo İLGİSİZDİR.
  final NotificationRepository? notifRepo;

  /// ⚠ "Bul" doğrudan teklif akışının deposu — `MockReviewPort`un
  /// artık bu talepleri de doğrulaması gerektiği için (yorum yazma
  /// akışı) dışa açıldı; `notifRepo` İLE AYNI gerekçe/desen.
  final TeklifTalebiRepository? teklifTalebiRepo;

  /// ⚠ HESAP DEPOSU DIŞARI AÇILDI (9 Eyl): tamamlanan iş sayacı
  /// hizmet verenin HESABINA yazılıyor; `MockTeklifTalebiPort` bu
  /// depoya erişmeli. `teklifTalebiRepo` ile AYNI gerekçe — aynı
  /// örneğin paylaşılması.
  final AuthRepository? authRepo;

  /// Bölge verisi (şehir/ilçe/mahalle) — API modunda sunucudan gelir.
  final RegionPort regions;

  /// HTTP İSTEMCİSİ.
  ///
  /// Bazı ekranlar port katmanı dışında doğrudan `*Api` sınıfı kurar
  /// (`StorageApi`, `AccountApi`, `LegalApi`, `ReviewApi`, `ConfigApi`)
  /// ve bunun için `context.read<ApiClient>()` çağırır. İstemci provider ağacına konulmazsa o ekranlar çalışma
  /// zamanında `ProviderNotFoundError` verir.
  ///
  /// ⚠ MOCK MODDA DA kurulur: ekranlar veriyi mock port'lardan okur,
  /// istemci yalnız `*Api` yardımcılarının örneklenebilmesi içindir ve
  /// ağa çıkmaz.
  final ApiClient apiClient;

  /// Yalnız mock modda kurulur (API modunda süre kuralı sunucudadır).
  final ListingExpiryService? expiry;

  const AppPorts({
    required this.auth,
    required this.listings,
    required this.offers,
    required this.contact,
    required this.chat,
    required this.reviews,
    required this.notifications,
    required this.regions,
    required this.apiClient,
    this.expiry,
    this.notifRepo,
    this.teklifTalebiRepo,
    this.authRepo,
  });
}

/// DATA_SOURCE=api → gerçek API portları; DATA_SOURCE=mock → bellek içi.
AppPorts buildPorts({DataSourceMode? mode, void Function()? onSessionExpired}) {
  final m = mode ?? ApiConfig.mode;
  final notifRepo = NotificationRepository();
  final chatRepo = ChatRepository();
  final reviewRepo = ReviewRepository();
  // ⚠ `MockTeklifTalebiPort`un DIŞARIDA (main() gövdesinde) kurduğu
  // AYNI örnek — bkz. aşağıdaki `AppPorts.teklifTalebiRepo` notu.
  final teklifTalebiRepo = TeklifTalebiRepository();

  if (m == DataSourceMode.api) {
    final client = ApiClient(onSessionExpired: onSessionExpired);
    // ⚠ `apiClient` provider ağacına konur: bazı ekranlar port katmanı
    // dışında doğrudan *Api sınıfı kurar.
    final offersPort = ApiOfferPort(ApiOfferRepository(OfferApi(client)));
    // Gerçek zamanlı mesajlaşma: /ws namespace, access token ile kimlik.
    final ws = WsClient(WsAuth(client.tokens));
    return AppPorts(
      auth: ApiAuthPort(ApiAuthRepository(client, AuthApi(client), ProfileApi(client))),
      listings: ApiListingPort(ApiListingRepository(ListingApi(client))),
      offers: offersPort,
      contact: ApiContactPort(ApiContactRepository(ContactApi(client))),
      chat: ApiChatPort(ApiChatRepository(ChatApi(client), ws: ws)),
      reviews: ApiReviewPort(ApiReviewRepository(ReviewApi(client)), offersPort),
      notifications: ApiNotificationPort(ApiNotificationRepository(NotificationApi(client))),
      // BÖLGE: tek gerçek kaynak veritabanıdır.
      regions: ApiRegionPort(RegionApi(client)),
      // ÜCRETSİZ HAK: kaynağı sunucu belirler; istemci SEÇEMEZ.
      // KAYITLI KART: kart verisi sağlayıcıda kalır.
      apiClient: client,
    );
  }

  // ── mock kurulum (mevcut davranış birebir korunur) ──
  final authRepo = AuthRepository();
  // ⚠ DEMO BAKİYE KAPATILDI: yeni hesap SIFIR bakiye ile başlar.
  // `demoDefaults` 950 TL kullanılabilir + 150 TL bloke yüklüyordu.
  final listingRepo = ListingRepository();
  final offerRepo = OfferRepository();
  final contactRepo = ContactRepository();

  final offerPort = MockOfferPort(offerRepo, listingRepo,
      notifs: notifRepo,
      // ⚠ Teklif seçilince hizmet verenin tamamlanan iş sayacı
      // artırılır; `authRepo` bunun için gerekli.
      auth: authRepo);
  final listingPort =
      MockListingPort(listingRepo, offerRepo, contactRepo, chatRepo, offerPort,
          // Çıkar çatışması denetimi için hesap deposu.
          auth: authRepo);

  // ⚠ DEMO TOHUMLAMA ARTIK AÇILIŞI BLOKLAMIYOR.
  //
  // Burada doğrudan `_seedDemo(authRepo)` çağrılıyordu; içindeki
  // `auth.register` PBKDF2-HMAC-SHA256 ile 20.000 tur hesaplıyor ve
  // bu iş `runApp`'ten ÖNCE, UI izleğinde bitiyordu. Debug derlemede
  // (JIT) ilk Flutter karesi bu kadar geciktiği için native splash
  // fail-safe'e kadar ekranda kalıyordu.
  //
  // ⚠ DEMO VERİSİ KALDIRILMADI: aynı hesap, aynı kategoriler, aynı
  // adres, aynı `register` sözleşmesinden geçerek üretilir — yalnız
  // ZAMANI değişti: İLK KARE ÇİZİLDİKTEN sonra.
  // ── ⚠ DEMO TOHUMLAMA KAPATILDI (canlı hazırlığı) ──
  //
  // Hazır demo hesap ve demo ilan ÜRETİLMEZ. Kullanıcı hesap
  // oluşturmadan giriş yapamaz; hizmet alan ve hizmet veren
  // ekranları boş başlar.
  //
  // ⚠ `demoTohumla` SİLİNMEDİ, yalnız ÇAĞRILMIYOR: yerel geliştirmede
  // gerekirse bu blok geri açılabilir.
  //
  // ⚠ OTP test kodu (123456) DEĞİŞMEDİ — talimat gereği aynı kaldı.

  return AppPorts(
    chat: MockChatPort(chatRepo, offerRepo, listingRepo,
        contacts: contactRepo, notifs: notifRepo),
    reviews: MockReviewPort(
        reviewRepo, listingRepo, offerRepo, contactRepo, teklifTalebiRepo),
    notifications: MockNotificationPort(notifRepo),
    notifRepo: notifRepo,
    teklifTalebiRepo: teklifTalebiRepo,
    authRepo: authRepo,
    // MOCK: sabit dosyalardan üretilir (yalnız geliştirme).
    regions: MockRegionPort(),
    // Geliştirmede varsayılan: hak YOK — cüzdan akışı da görülebilsin.
    // Geliştirme modunda kayıtlı kart KAPALI — sahte kart üretilmez.
    // Mock modda da istemci kurulur: ekranlar `context.read<ApiClient>()`
    // ile *Api yardımcıları oluşturur. Mock modda ağ çağrısı YAPILMAZ;
    // ekranlar veriyi mock port'lardan okur.
    apiClient: ApiClient(onSessionExpired: onSessionExpired),
    auth: MockAuthPort(authRepo),
    listings: listingPort,
    offers: offerPort,
    contact: MockContactPort(contactRepo, offerRepo, listingRepo,
        notifs: notifRepo),
    expiry: ListingExpiryService(listingRepo, offerPort, notifications: notifRepo),
  );
}

Future<void> main() async {
  BootLog.olay('MAIN_ENTRY');

  // Platform kanalı çağrılarından ÖNCE binding hazır olmalıdır.
  WidgetsFlutterBinding.ensureInitialized();
  BootLog.olay('ENSURE_INITIALIZED_END');

  // ── ⚠ SİSTEM ÇUBUKLARI: BEYAZ ZEMİN, KOYU İKON ──
  //
  // KULLANICI İSTEĞİ (9 Eyl): "Android ikonları gri/koyu ve belirgin
  // olmalı; zemin beyaz olacağı için kaybolmamalı."
  //
  // ⚠ ÖNCEDEN HİÇ AYARLANMAMIŞTI: uygulamada `SystemChrome`
  // çağrısı da, temada `statusBarColor`/`windowLightStatusBar` da
  // YOKTU. Yani durum çubuğu ve gezinme çubuğu tamamen cihazın
  // varsayılanına bırakılmıştı — bir cihazda koyu ikon, ötekinde
  // beyaz ikon çıkabiliyordu ve beyaz ikonlar beyaz zeminde
  // KAYBOLUYORDU.
  //
  // ⚠ NEDEN DART, NEDEN ANDROID TEMASI DEĞİL: aynı sonuç
  // `windowLightStatusBar` ile de alınabilirdi. Bu turda Android
  // tema/pencere tarafına DOKUNMAMAYI seçtim — bir önceki turda
  // `MainActivity`ye eklenen tek satır, uygulamanın altında ve
  // üstünde siyah bantlara yol açmıştı ve geri alındı. Değer
  // `core/theme.dart` içinde tek yerde (`kSistemCubuklari`).
  //
  // ⚠ UYGULAMANIN KOYU TEMASI YOK: her ekranın zemini beyaz, bu
  // yüzden ikon parlaklığı cihazın açık/koyu temasına göre
  // DEĞİŞMEZ — her koşulda koyu ikon istenir.
  //
  // ⚠ AppBar AYRICA BAĞLANDI: uygulamada iki `AppBar` var
  // (`route_guard`, `legal_screen`) ve `AppBar` kendi
  // `systemOverlayStyle`ı ile buradaki ayarı EZER. Bu yüzden aynı
  // sabit `AppBarTheme`e de verildi; o iki ekranda da ikonlar koyu
  // kalır.
  SystemChrome.setSystemUIOverlayStyle(kSistemCubuklari);

  // ── ⚠ EKRAN YÖNLENDİRMESİ: TELEFON DİKEY, TABLET SERBEST ──
  //
  // Ürün kararı (12 Eyl). Kural ve gerekçesi TEK YERDE:
  // `core/yonlendirme.dart`. Burada yalnız çağrılır.
  //
  // ⚠ EKRANLAR KENDİ YÖNLENDİRMESİNİ AYARLAMAZ. Tek tek ekranda
  // kısıt değiştirmek, geri dönüşte eski hâli geri getirmeyi de
  // gerektirir ve o adım unutulur.
  //
  // ⚠ MANIFEST'E `screenOrientation` YAZILMAZ: statiktir, cihaz
  // ayrımı yapamaz ve tableti de kilitlerdi.
  yonlendirmeyiUygula();


  // DERİN BAĞLANTI: uygulama açık/arka plandayken gelen bağlantılar için
  // dinleyici başlatılır. Uygulama TAMAMEN KAPALIYKEN açılışa sebep olan
  // bağlantı aşağıda `initialLink()` ile bir kez okunur.
  //
  // GÜVENLİK: bağlantı yalnız TETİKLEYİCİDİR — ödeme sonucu her zaman
  // backend'in confirmTopup çağrısıyla doğrulanır.
  unawaited(DeepLinks.instance.start());

  final navKey = GlobalKey<NavigatorState>();
  BootLog.olay('BUILD_PORTS_START');
  final ports = buildPorts(
    // Oturum kurtarılamazsa (refresh de geçersiz) giriş ekranına dönülür.
    // OTURUM DÜŞMESİ → HOME
    //
    // HTML sözleşmesinde giriş ekranı otomatik AÇILMAZ; kullanıcı
    // karşılama ekranına döner ve isterse profil ikonundan giriş yapar.
    onSessionExpired: () => navKey.currentState
        ?.pushNamedAndRemoveUntil('/home', (route) => false),
  );

  // ── ⚠ "DOĞRUDAN TEKLİF İSTE" — TEK ÖRNEKLEME ──
  //
  // Öteki portlarla AYNI kural: burada BİR KEZ kurulur, tüm ekranlar
  // aynı örneği paylaşır. `AppPorts`e yalnız `notifRepo` alanı
  // EKLENDİ (bkz. sınıf tanımındaki not) — bildirimler mevcut
  // `NotificationController`ın GÖRDÜĞÜ AYNI depoya yazılsın diye;
  // başka hiçbir port/repository DEĞİŞMEDİ.
  final teklifTalebiPort = MockTeklifTalebiPort(
      ports.teklifTalebiRepo ?? TeklifTalebiRepository(),
      notifs: ports.notifRepo,
      // ⚠ Tamamlanan iş sayacı hizmet verenin hesabına yazılır.
      auth: ports.authRepo);
  BootLog.olay('BUILD_PORTS_END');

  // ═══════════════════════════════════════════════════════════════
  // ── ⚠ APK TEST KALICILIĞI — YALNIZ TEST AMAÇLI, GEÇİCİ ──
  //
  // Mock modda kayıtlı hesaplar yalnız BELLEKTEYDİ; APK kapatılıp
  // açılınca (gerçek cihaz testinde olduğu gibi) kaybolur, tekrar
  // kayıt gerekirdi. Bkz. `account_test_store.dart`'taki tam not.
  //
  // ⚠ KULLANICI "SİL" DEDİĞİNDE: bu blok + import satırı +
  // `account_test_store.dart` birlikte kaldırılacak.
  //
  // `AppPorts`e DOKUNULMADI: `MockAuthPort.repo` zaten PUBLIC bir
  // alan (bkz. `mock_ports.dart`), doğrudan ondan erişildi.
  if (ports.auth is MockAuthPort) {
    final authRepo = (ports.auth as MockAuthPort).repo;
    final accountStore = AccountTestStore();
    final kayitliHesaplar = await accountStore.read();
    for (final restored in kayitliHesaplar) {
      // ⚠ AYNI id'li hesap (ör. sabit demo hesabı) varsa YENİ
      // (kaydedilmiş) sürümle DEĞİŞTİRİLİR — çift kayıt OLUŞMAZ.
      authRepo.accounts.removeWhere((a) => a.id == restored.id);
      authRepo.accounts.add(restored);
    }
    // ⚠ Kayıt/profil güncelleme gibi her değişiklikte OTOMATİK
    // kaydeder — `authRepo` zaten `notifyListeners()` çağırıyor,
    // ayrı bir tetikleyici İCAT EDİLMEDİ.
    authRepo.addListener(() => accountStore.save(authRepo.accounts));
  }

  // İLAN SÜRESİ KURALI — yalnız mock modda istemcide işlenir.
  final expiry = ports.expiry;
  if (expiry != null) {
    expiry.sweep();
    Timer.periodic(const Duration(minutes: 1), (_) => expiry.sweep());
  }

  BootLog.olay('RUN_APP_CALL');
  runApp(MultiProvider(
    providers: [
      // ── HTTP İSTEMCİSİ ──
      //
      // Bazı ekranlar port katmanı dışında doğrudan `*Api` sınıfı kurar
      // (`StorageApi`, `AccountApi`, `LegalApi`, `ReviewApi`,
      // `ConfigApi`) ve bunun için `context.read<ApiClient>()` çağırır.
      //
      // İstemci burada sunulmazsa o ekranlar çalışma zamanında
      // `ProviderNotFoundError` ile kırmızı hata ekranı verir —
      // "İlan Ver" akışında görülen hata buydu.
      //
      // MultiProvider `runApp`'in KÖKÜNDEDİR; dolayısıyla named route,
      // `Navigator.push` ve `RoleGuard` altındaki tüm ekranlar bu
      // kapsamı görür.
      Provider<ApiClient>.value(value: ports.apiClient),

      ChangeNotifierProvider(create: (_) => AuthController(ports.auth)),
      // Faturalar SALT OKUNUR gelir; port gerektirmez.
      // İncelenen ilanlar — okundu/okunmadı durumu (kalıcı).
      ChangeNotifierProvider(
          create: (_) => IncelenenIlanController(IncelenenIlanStore())..load()),
      // Kayıt öncesi ilan taslağı — kalıcı saklama ile.
      ChangeNotifierProvider(
          create: (_) => PendingListingController(PendingListingStore())
            ..load()),
      ChangeNotifierProvider(create: (_) => ProfileController(ports.auth)),
      // BÖLGE VERİSİ: açılışta yüklenir, tüm ekranlar buradan okur.
      ChangeNotifierProvider(create: (_) => RegionController(ports.regions)..load()),
      ChangeNotifierProvider(
          create: (_) => OfferController(ports.offers, ports.listings)),
      ChangeNotifierProvider(create: (_) => ListingController(ports.listings)),
      ChangeNotifierProvider(
          create: (_) => ContactController(ports.contact, ports.offers)),
      ChangeNotifierProvider(create: (_) => ChatController(ports.chat)),
      // ── ⚠ "DOĞRUDAN TEKLİF İSTE" — YENİ VE AYRI ÖZELLİK ──
      //
      // `AppPorts`/`buildPorts()`'a DOKUNULMADI: bu özelliğin
      // deposu/portu/denetleyicisi, öteki portlarla AYNI TEK
      // ÖRNEKLEME kuralına uyarak (bkz. `teklifTalebiPort` yukarıda)
      // burada sabitlenmiş nesneleri kullanır. Gerçek backend
      // geldiğinde yalnız `MockTeklifTalebiPort`'un yerine bir API
      // portu geçecek.
      ChangeNotifierProvider.value(value: teklifTalebiPort),
      ChangeNotifierProvider(
          create: (_) => TeklifTalebiController(teklifTalebiPort)),
      ChangeNotifierProvider(create: (_) => ReviewController(ports.reviews)),
      ChangeNotifierProvider(create: (_) => NotificationController(ports.notifications)),
    ],
    child: HizmetCepApp(navigatorKey: navKey),
  ));
}

/// Prototip demo verisi — YALNIZ debug + mock modda.
/// DEMO HESAPLARI — YALNIZ DEBUG.
///
/// ⚠ Demo İLAN üretmez; yalnız giriş denemek için hesap açar.
/// (`ListingRepository` parametresi kaldırıldı: ilan tohumlanmıyor.)
/// DEMO TOHUMLAMASINI İLK KAREDEN SONRAYA ERTELER.
///
/// ⚠ `addPostFrameCallback`: iş, Flutter'ın İLK KARESİ çizildikten
/// sonra çalışır. Böylece açılış hiçbir koşulda beklemez.
///
/// ⚠ TEK SEFER: `_tohumlandi` bayrağı sıcak yeniden başlatmada
/// (hot restart) ikinci kaydı engeller.
///
/// ⚠ Testler `_seedDemo`'yu doğrudan çağırabilir; o yol
bool _tohumlandi = false;

void demoTohumla(
  AuthRepository auth, {
  ListingRepository? listings,
  OfferRepository? offers,
  ReviewRepository? reviews,
  ContactRepository? contacts,
}) {
  if (_tohumlandi) {
    return;
  }
  _tohumlandi = true;

  // ⚠ BINDING HER ORTAMDA HAZIR DEĞİLDİR.
  //
  // `buildPorts` yalnız uygulamadan değil, WIDGET OLMAYAN birim
  // testlerinden de çağrılıyor. Orada `WidgetsBinding.instance`
  // "Binding has not yet been initialized" hatası atar ve port
  // kurulumunun tamamı çöker (di_and_guard_test bunu yakaladı).
  //
  // Uygulamada binding hazırdır (`main()` ilk iş olarak
  // `ensureInitialized` çağırır) → tohumlama İLK KAREDEN SONRA
  // çalışır, açılışı bekletmez.
  //
  // Testte binding yoksa iş SENKRON yapılır: orada kare döngüsü ve
  // açılış süresi diye bir kavram yok, sonuç aynı veridir.
  try {
    // ⚠ SIRA GARANTİSİ — YARIŞ YOK.
    //
    // Bu geri çağrı, `runApp`'ten ÖNCE (buildPorts sırasında)
    // kaydedilir; `SplashScreen.initState` içindeki açılış geri
    // çağrısı ise SONRA. Flutter post-frame geri çağrılarını KAYIT
    // SIRASINA göre işler, dolayısıyla tohumlama açılış kararından
    // ÖNCE tamamlanır. Kullanıcı hiçbir aşamada eksik
    // kategori/adres/hesap görmez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BootLog.olc('SEED_DEMO',
          () => _seedDemo(auth, listings, offers, reviews, contacts));
    });
  } on FlutterError {
    // Binding yok (birim testi) — doğrudan tohumla.
    BootLog.olc('SEED_DEMO',
          () => _seedDemo(auth, listings, offers, reviews, contacts));
  }
}

void _seedDemo(
  AuthRepository auth, [
  ListingRepository? listings,
  OfferRepository? offers,
  ReviewRepository? reviews,
  ContactRepository? contacts,
]) {
  // ⚠ Demo hesap da GERÇEK kayıt sözleşmesinden geçer:
  // sözleşme onayı zorunludur (`termsAccepted`), aksi hâlde
  // `register` `ValidationError` döner ve hesap oluşmaz.
  // E-posta doğrulaması demo hesapta da AYRICA yapılır; burada
  // `emailVerified` verilmez — normal kayıt kuralı korunur.
  final usta = auth.register(
      // ⚠ PBKDF2 AÇILIŞ YOLUNDAN ÇIKARILDI.
      //
      // Bu çağrı SENKRONDUR ve `PasswordHasher.hash` 20.000 tur
      // döner — post-frame'e taşınsa bile AYNI isolate'ı o kadar
      // süre bloke ederdi ve boot kararı gecikirdi. Önceden
      // hesaplanmış tuz+özet kullanılır (`demo_hesap_ozetleri.dart`).
      //
      // ⚠ Kayıt sözleşmesinin geri kalanı DEĞİŞMEDİ: OTP, sözleşme
      // onayı ve tüm doğrulamalar aynen işler.
      hazirTuz: kDemoUstaTuz, hazirOzet: kDemoUstaOzet,
      phone: '5507654321', pass: '1986onur', role: Role.provider,
      otpVerified: true, name: 'Ali Usta', termsAccepted: true,
      // Demo hesabın e-postası da doldurulur — profil ekranı boş
      // alanla değil gerçek veriyle denenebilsin.
      email: 'ali.usta@example.com');
  // Demo ustanın adresi de doldurulur — Adreslerim ekranı hizmet
  // veren tarafında da dolu açılır.
  if (usta.account != null) {
    auth.setAddressFor(usta.account!.id,
        district: 'Konak', neighborhood: 'Alsancak');
    // ⚠ KAYIT SIRASINDA GİRİLEN HİZMET BİLGİLERİ DE TOHUMLANIR.
    //
    // Kategori ve bölge boş kalınca Hizmet Kategorilerim / Hizmet
    // Bölgelerim ekranları "hiç seçilmedi" ile açılıyordu; oysa gerçek
    // kayıtta bu bilgiler zorunludur ve profilde dolu görünür.
    // ⚠ YENİ KATALOG YAPISINA TAŞINDI.
    //
    // `Kombi Bakımı` / `Kombi Tamiri` eskiden `Doğalgaz` altındaydı;
    // artık ayrı bir `Kombi` ana kategorisi var. Ayrıca ana kategori
    // SAYI SINIRI kalktığı için demo hesap üç ana kategori taşır —
    // sınırın gerçekten kalktığı APK'da da görülür.
    usta.account!.categories
      ..clear()
      ..addAll({
        'Doğalgaz',
        'Doğalgaz Tesisatı',
        // ⚠ Kombi ikiye ayrıldı: Montaj + Servis.
        'Kombi Servis',
        'Kombi Bakımı',
        'Kombi Tamiri',
        'Su Tesisatı',
        'Petek Temizliği',
      });
    usta.account!.serviceDistricts
      ..clear()
      ..addAll({'Konak', 'Karşıyaka', 'Bornova'});
  }
  auth.logout();

  assert(usta.account != null);

  // ── ⚠ DEMO SENARYOSU — YALNIZ DEBUG ──
  //
  // Bir tur önce demo ilanlar TAMAMEN kaldırılmıştı; gerekçe geçerliydi
  // ("Boya" katalogda yoktu, ilanlar gerçek sanılıyordu). Karar
  // kullanıcı isteğiyle GERİ ALINDI, ama iki şart eklendi:
  //
  //   1. ⚠ YALNIZ DEBUG. Çağrı `kDebugMode` kapısının arkasında;
  //      mağazaya giden release paketinde bu veri ÜRETİLMEZ. Gerçek
  //      kullanıcı hiçbir zaman uydurma ilan görmez.
  //   2. ⚠ BAŞLIKLAR KATALOGDAN. Eski hatanın tekrarı önlensin diye
  //      seçilen adlar `kCategoryTree` içinde birebir vardır; kategori
  //      satırı ve ikon bu yüzden doğru çözülür.
  //
  // ── SENARYO ──
  //
  // İki ilan açılır (müşteri: Onur Bütün):
  //   A. "Kombi Bakımı" — İKİ TEKLİF gelmiş durumda. Müşteri tarafı
  //      buradan teklif karşılaştırma, seçim, iletişim açma ve
  //      değerlendirme akışını baştan sona gezebilir.
  //   B. "Petek Temizliği" — HİÇ TEKLİF YOK. Hizmet veren tarafı
  //      buradan gerçek teklif verme akışını kendisi deneyebilir;
  //      "yeni ilan geldi" hâli korunmuş olur.
  //
  // ⚠ İKİNCİ USTA GEREKLİ: iki teklifin farklı hizmet verenlerden
  // gelmesi için. Tek hesapla aynı ilana iki teklif verilemez ve
  // teklif karşılaştırma ekranı gerçekçi olmaz.
  //
  // ⚠ BLOKE GERÇEKTEN DÜŞÜLÜR: teklif verince iletişim bedeli
  // bloke edilir. Doğrudan kayıt eklemek cüzdanı tutarsız
  // bırakırdı; `wallets.block` çağrılarak gerçek kural işletilir.
  if (listings == null || offers == null) {
    return; // birim testleri depo geçmeden çağırabilir
  }

  final ikinciUsta = auth.register(
      phone: '5559998877', pass: '1986onur', role: Role.provider,
      otpVerified: true, name: 'Mehmet Yıldız', termsAccepted: true,
      email: 'mehmet.yildiz@example.com');
  if (ikinciUsta.account != null) {
    auth.setAddressFor(ikinciUsta.account!.id,
        district: 'Karşıyaka', neighborhood: 'Bostanlı');
    ikinciUsta.account!.categories
      ..clear()
      ..addAll({'Kombi Servis', 'Kombi Bakımı', 'Petek Temizliği'});
    ikinciUsta.account!.serviceDistricts
      ..clear()
      ..addAll({'Karşıyaka', 'Konak'});
  }
  auth.logout();

  final musteri = auth.findByPhone('5321112233');
  final usta1 = usta.account;
  final usta2 = ikinciUsta.account;
  if (musteri == null || usta1 == null || usta2 == null) {
    return;
  }

  // ── A. İKİ TEKLİFLİ İLAN ──
  final ilanA = listings.create(
      ownerId: musteri.id,
      title: 'Kombi Bakımı',
      location: 'Alsancak, Konak / İzmir',
      desc: 'Kombi iki haftadır düzensiz yanıyor, radyatörler '
          'alttan ısınmıyor. Bakım ve gerekiyorsa parça değişimi '
          'için uygun gün arıyorum.');

  offers.create(
      listingId: ilanA.id, providerId: usta1.id, amount: 1450,
      note: 'Bakım, petek havası alma ve basınç ayarı dâhildir. '
          'Yedek parça gerekirse önce bilgi veririm.');

  offers.create(
      listingId: ilanA.id, providerId: usta2.id, amount: 1200,
      note: 'Aynı gün gelebilirim. Fiyata iş gücü dâhil, parça '
          'çıkarsa ayrıca konuşuruz.');

  // ── GEÇMİŞ İŞLER VE DEĞERLENDİRMELER ──
  //
  // ⚠ PUAN VE YORUM EKRANLARI VERİSİZ BOŞ GÖRÜNÜYORDU.
  //
  // Teklif kartında yıldız ve ortalama, teklif detayında puan
  // dağılımı ve yorum listesi ZATEN vardı; ama demo hizmet
  // verenlerin hiç tamamlanmış işi olmadığı için ortalama "—",
  // liste de "Henüz yorum yapılmamış." gösteriyordu. Özellik
  // çalışmıyor sanılıyordu.
  //
  // Burada KAPANMIŞ üç iş ve onların değerlendirmeleri üretilir.
  // Böylece müşteri, gelen tekliflerde hizmet verenin gerçek
  // puanını ve yorumlarını görebilir.
  //
  // ⚠ Değerlendirme kuralı KORUNUR: yalnız ilan sahibi, tamamlanmış
  // iş ve seçili teklif için, teklif başına tek yorum.
  void gecmisIs({
    required String baslik,
    required String konum,
    required String aciklama,
    required String ustaId,
    required int tutar,
    required int yildiz,
    required String yorum,
  }) {
    final ilan = listings.create(
        ownerId: musteri.id, title: baslik, location: konum, desc: aciklama);
    final teklif = offers.create(
        listingId: ilan.id, providerId: ustaId, amount: tutar,
        note: 'İş tamamlandı.');
    // ── ⚠ TAMAMLANMIŞ İŞ = SEÇİLMİŞ TEKLİF ──
    //
    // Burada yalnız `setStatus(completed)` yazılıyordu; teklif hâlâ
    // `active`, `selectedOfferId` ise BOŞTU. Ekran bu ilanı "iletişimi
    // açılmamış" sayıp "İletişimi Aç" düğmesini çiziyordu —
    // kullanıcının gördüğü hata tam olarak buydu ve kaynağı EKRAN
    // DEĞİL, BU TOHUMDU.
    //
    // Tamamlanmış bir işte zincirin tamamı yazılı olmalıdır:
    // teklif seçili · ilan o teklifi işaret ediyor · iletişim açık ·
    // bloke tüketilmiş. Aksi hâlde ekran tutarsız bir durumu çizmek
    // zorunda kalır.
    teklif.status = OfferStatus.selected;
    ilan.selectedOfferId = teklif.id;
    contacts?.open(teklif.id);
    // ⚠ İLAN DURUMU DEĞİŞMEZ (§24): tamamlanmışlık `selectedOfferId`
    reviews?.create(
        listingId: ilan.id, offerId: teklif.id, providerId: ustaId,
        authorId: musteri.id, stars: yildiz, text: yorum);
  }

  gecmisIs(
      baslik: 'Kombi Bakımı',
      konum: 'Alsancak, Konak / İzmir',
      aciklama: 'Yıllık bakım yaptırıldı.',
      ustaId: usta1.id, tutar: 1300, yildiz: 5,
      yorum: 'Randevu saatinde geldi, işini titiz yaptı. '
          'Kullandığı parçaların faturasını da verdi.');
  gecmisIs(
      baslik: 'Petek Temizliği',
      konum: 'Bostanlı, Karşıyaka / İzmir',
      aciklama: 'Sekiz petek temizlendi.',
      ustaId: usta1.id, tutar: 900, yildiz: 4,
      yorum: 'İş güzel oldu ama biraz geç geldi.');
  gecmisIs(
      baslik: 'Kombi Tamiri',
      konum: 'Bostanlı, Karşıyaka / İzmir',
      aciklama: 'Arıza giderildi.',
      ustaId: usta2.id, tutar: 1100, yildiz: 5,
      yorum: 'Sorunu hemen buldu, fiyatı da konuştuğumuz gibiydi.');

  // ── B. TEKLİFSİZ İLAN ──
  //
  // ⚠ Hizmet veren tarafı için BİLEREK boş bırakıldı: teklif verme
  // akışı gerçekten denensin, hazır teklifle atlanmasın.
  listings.create(
      ownerId: musteri.id,
      title: 'Petek Temizliği',
      location: 'Bostanlı, Karşıyaka / İzmir',
      desc: 'Üç odalı dairede sekiz adet petek var. Isınma çok '
          'zayıf, temizlik ve gerekirse vana değişimi istiyorum.');
}

class HizmetCepApp extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const HizmetCepApp({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HizmetCep',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: HC.theme(),
        builder: (context, child) =>
            OfflineBanner(child: child ?? const SizedBox.shrink()),
        home: const SplashScreen(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/login': (_) => const LoginScreen(),
          '/role': (_) => const RoleSelectScreen(),

          // ── Ortak (her iki rol) ──
          '/profile': (_) => RoleGuard(builder: (_) => const ProfileScreen()),
          '/profile/info': (_) =>
              RoleGuard(builder: (_) => const ProfileInfoScreen()),
          '/profile/address': (_) =>
              RoleGuard(builder: (_) => const AddressesScreen()),
          '/profile/password': (_) =>
              RoleGuard(builder: (_) => const ChangePasswordScreen()),
          '/profile/account': (_) =>
              RoleGuard(builder: (_) => const AccountSettingsScreen()),
          '/profile/rate': (_) =>
              RoleGuard(builder: (_) => const AppRateScreen()),
          '/notifications': (_) =>
              RoleGuard(builder: (_) => const NotificationsScreen()),

          // ── YALNIZ HİZMET VEREN ──
          // Müşteri bu adreslere derin bağlantıyla gelse bile
          // RoleGuard ekranı çizmez.
          // Hizmet veren ANA PANELİ — referans `vCust` (MODE='provider'):
          // "Yeni işler" / "Kazandığım işler" sekmeleri.
          // Başarılı girişte hizmet veren buraya yönlendirilir.
          '/provider/jobs': (_) =>
              RoleGuard.provider(builder: (_) => const JobsScreen()),
          // Aynı ekran, "Kazandığım işler" listesiyle açılır.
          '/provider/won': (_) => RoleGuard.provider(
              builder: (_) => const JobsScreen(kazandigim: true)),
          '/provider/status': (_) =>
              RoleGuard.provider(builder: (_) => const ProviderStatusScreen()),
          '/provider/reviews': (_) =>
              RoleGuard.provider(builder: (_) => const MyReviewsScreen()),
          '/provider/categories': (_) =>
              RoleGuard.provider(builder: (_) => const MyCategoriesScreen()),
          '/provider/areas': (_) =>
              RoleGuard.provider(builder: (_) => const MyAreasScreen()),

          // ── YALNIZ MÜŞTERİ ──
          '/customer/listings': (_) =>
              RoleGuard.customer(builder: (_) => const MyListingsScreen()),
          // ⚠ "BUL" AKIŞI 1. AŞAMA — hizmet arayıp hizmet veren bulma.
          // Tarama (aşama 2) ve sonuç (aşama 3) ekranları henüz YOK.
          '/customer/find-provider': (_) =>
              RoleGuard.customer(builder: (_) => const FindProviderScreen()),
          // ⚠ PUBLIC (kayıt öncesi) — yalnız TASLAK üretir, yayın YAPMAZ.
          // `/customer/new-listing` korumalı KALIR; bu route onu
          // bypass etmez (bkz. prelogin_listing_route.dart).
          PreLoginListingRoute.name: preLoginListingBuilder,
          '/customer/new-listing': (_) =>
              RoleGuard.customer(builder: (_) => const CreateListingScreen()),
        },
        // Yasal metinler parametre aldığı için onGenerateRoute ile açılır.
        onGenerateRoute: (settings) {
          if (settings.name == '/legal') {
            final a = settings.arguments;
            final slug = a is Map ? a['slug'] as String? : null;
            final title = a is Map ? a['title'] as String? : null;
            if (slug != null) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) =>
                    LegalScreen(slug: slug, title: title ?? 'Bilgilendirme'),
              );
            }
          }
          return null;
        },
      );
}
