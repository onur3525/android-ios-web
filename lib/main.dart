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
import 'data/remote/api_teklif_talebi_port.dart';
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
import 'screens/role_switch_screen.dart';
import 'data/controllers/region_controller.dart';
import 'data/remote/api/region_api.dart';
import 'data/remote/sabitlemeli_istemci.dart';
import 'screens/splash_screen.dart';
import 'screens/prelogin_listing_route.dart';
import 'data/controllers/pending_listing_controller.dart';
import 'data/repositories/pending_listing_store.dart';
import 'data/controllers/incelenen_ilan_controller.dart';
import 'data/repositories/incelenen_ilan_store.dart';
import 'ui/global_web_kabugu.dart';
import 'ui/panel_rotasi.dart';
import 'ui/gezgin.dart';
import 'ui/yasal_kabul_kapisi.dart';
import 'ui/push_kapisi.dart';
import 'screens/bulunamadi_screen.dart';
import 'screens/listing_detail_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/offer_detail_screen.dart';
import 'screens/teklif_talebi_detay_screen.dart';

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
  // ── ⚠ SERTİFİKA SABİTLEME SESSİZCE KAPALI KALAMAZ ──
  //
  // Pin verilmeden çıkılan bir RELEASE sürümünde sabitleme devre dışı
  // kalır ve bunu hiçbir şey haber vermez. `API_BASE_URL` için zaten
  // bir zorunluluk var (`ApiConfig.baseUrl` StateError fırlatır);
  // aynı katılık pin için de gerekir.
  //
  // ⚠ YALNIZ GERÇEK API MODUNDA: mock derlemede sunucuya hiç
  // bağlanılmaz, pin istemek anlamsız olurdu.
  //
  // ⚠ BURADA ÇAĞRILIR çünkü `buildPorts` hem uygulamanın hem
  // testlerin tek giriş noktasıdır; başka bir yere konsa bir yol
  // denetimi atlayabilirdi.
  // ⚠ KÖPRÜ ÜZERİNDEN: `sertifika_sabitleme.dart` `dart:io` içerir ve
  // doğrudan import edilirse web derlemesini kırar. Mobilde aynı
  // denetim çalışır; web'de karşılığı yoktur (bkz. köprü notu).
  pinDenetimi(gercekApi: m == DataSourceMode.api);
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

  // ⚠ ORTAK ANAHTAR (`ui/gezgin.dart`): kabuk katmanı da bunu
  // kullanır. Yerel bir anahtar üretilseydi kenar çubuğu boş bir
  // anahtara bakardı.
  final navKey = gezginAnahtari;
  BootLog.olay('BUILD_PORTS_START');
  final ports = buildPorts(
    // Oturum kurtarılamazsa (refresh de geçersiz) giriş ekranına dönülür.
    // OTURUM DÜŞMESİ → HOME
    //
    // HTML sözleşmesinde giriş ekranı otomatik AÇILMAZ; kullanıcı
    // karşılama ekranına döner ve isterse profil ikonundan giriş yapar.
    //
    // ⚠ WEB'DE DE ANA SAYFA: anonim açılış her platformda `/home`
    // olduğu için oturum düştüğünde de oraya dönülür. Bir tur web'de
    // `/role`a yönlendirilmişti; geri alındı.
    //
    // ⚠ `pushNamedAndRemoveUntil` DEĞİŞMEDİ: yığın tamamen
    // temizlenir, korumalı ekranlar arkada açık kalmaz. Jetonlar
    // `_forceLogout` içinde ZATEN silinmiş durumda.
    onSessionExpired: () =>
        navKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false),
  );

  // ── ⚠ "DOĞRUDAN TEKLİF İSTE" — TEK ÖRNEKLEME ──
  //
  // Öteki portlarla AYNI kural: burada BİR KEZ kurulur, tüm ekranlar
  // aynı örneği paylaşır. `AppPorts`e yalnız `notifRepo` alanı
  // EKLENDİ (bkz. sınıf tanımındaki not) — bildirimler mevcut
  // `NotificationController`ın GÖRDÜĞÜ AYNI depoya yazılsın diye;
  // başka hiçbir port/repository DEĞİŞMEDİ.
  // ⚠ API MODUNDA gerçek sunucu portu; mock modda (web demosu, testler)
  // bugünkü mock port AYNEN. Ekranlar ve denetleyici aynı arayüzü görür.
  final TeklifTalebiPort teklifTalebiPort = ApiConfig.useRealApi
      ? ApiTeklifTalebiPort(ports.apiClient)
      : MockTeklifTalebiPort(
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
  // ⚠ WEB'DE TEST HESABI DEPOSU OKUNMAZ.
  //
  // `AccountTestStore` bir GELİŞTİRME kolaylığıdır: cihazda kayıtlı
  // demo hesaplarını geri yükler. Web'de bunun karşılığı yok ama
  // okuması var — `flutter_secure_storage`ın tarayıcı uygulaması
  // devreye giriyor, IndexedDB açılıyor ve WebCrypto anahtar türetmesi
  // çalışıyor. Bu, AÇILIŞTA BEKLENEN SÜREYE doğrudan ekleniyordu ve
  // kullanıcı o süreyi beyaz ekran olarak görüyordu.
  //
  // ⚠ MOBİLDE AYNEN KALIR: geliştirme akışı bozulmasın.
  if (!kIsWeb && ports.auth is MockAuthPort) {
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

  // ══════════════════════════════════════════════════════════════
  // ⚠ WEB'DE SPLASH EKRANI YOKTUR — HEDEF `runApp`TAN ÖNCE BELLİ
  // ══════════════════════════════════════════════════════════════
  //
  // Web'de açılış ekranı diye bir kalıp yoktur: sayfa yüklenir ve
  // içerik gelir. `SplashScreen`, açılış kararını verdiği İÇİN
  // zincirde duruyordu; web'de hiçbir şey çizmediğinden kullanıcı o
  // süreyi BOŞ SAYFA olarak görüyordu.
  //
  // Karar buraya, `runApp`tan ÖNCEYE alındı. `MaterialApp` açıldığında
  // hedef ekran ZATEN bellidir ve doğrudan o çizilir — arada hiçbir
  // route, hiçbir bekleme yüzeyi yok.
  //
  // ⚠ MOBİL DEĞİŞMEZ: `kIsWeb` değilse `ilkRota` null kalır ve
  // `MaterialApp.home` bugünkü gibi `SplashScreen` olur. Marka
  // splash'ı, bakım/zorunlu güncelleme kararları ve native splash
  // köprüsü orada aynen sürer.
  //
  // ⚠ OTURUM MEKANİZMASI AYNI: `restoreSession` bugünkü port üzerinden
  // çağrılır, jetonlar yine `flutter_secure_storage`ta durur. Yeni bir
  // auth ya da saklama sistemi kurulmadı.
  //
  // ⚠ ÇİFT ROL → HİZMET VEREN ve `switchRole` kuralı `SplashScreen`
  // içindekiyle AYNI: `RoleGuard` hedefe değil `activeRole`e bakar;
  // yönlendirmeden önce eşitlenmezse kullanıcı kendi paneline
  // giremez.
  //
  // ⚠ BAKIM / ZORUNLU GÜNCELLEME BURADA SORULMAZ. O denetimler ağ
  // çağrısı gerektiriyor ve buraya alınsaydı açılış yine bekleyecekti
  // — çözülmek istenen sorunun ta kendisi. Karar: web'de açılış
  // hızlıdır, bloke durumları ilk API çağrısında zaten ortaya çıkar
  // (`onSessionExpired` ve hata eşlemesi devrede). Bunu RAPORLUYORUM,
  // gizlemiyorum.
  String? ilkRota;
  if (kIsWeb) {
    try {
      // ⚠ BÜTÇELİ: güvenli depo okuması web'de IndexedDB açılışı ve
      // WebCrypto anahtar türetmesi demek. Askıda kalırsa kullanıcı
      // beyaz ekranda bekler; 1200 ms sonra anonim açılışa düşülür.
      // Oturum varsa ilk API çağrısında zaten geri yüklenir.
      await ports.auth
          .restoreSession()
          .timeout(const Duration(milliseconds: 1200));
      final acc = ports.auth.currentAccount;
      if (acc != null) {
        final hedefRol =
            acc.roles.contains(Role.provider) ? Role.provider : Role.customer;
        if (acc.activeRole != hedefRol) {
          await ports.auth.switchRole(hedefRol);
        }
        ilkRota = hedefRol == Role.provider
            ? '/provider/jobs'
            : '/customer/listings';
      } else {
        ilkRota = '/home';
      }
    } catch (e) {
      // ⚠ HATA AÇILIŞI KİLİTLEMEZ: oturum çözülemezse anonim açılış.
      BootLog.olay('WEB_BOOT_FALLBACK', e.runtimeType.toString());
      ilkRota = '/home';
    }
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
    child: HizmetCepApp(navigatorKey: navKey, ilkRota: ilkRota),
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
      // ⚠ Düz şifre kaynakta YOK: hazır özet kullanılır, `pass` yok sayılır.
      phone: '5507654321', pass: '', role: Role.provider,
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
      // ⚠ Düz şifre kaynakta YOK: demo ustayla aynı hazır özet.
      hazirTuz: kDemoUstaTuz, hazirOzet: kDemoUstaOzet,
      phone: '5559998877', pass: '', role: Role.provider,
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

  /// Web'de açılışta doğrudan gösterilecek rota.
  ///
  /// ⚠ NULL İSE MOBİL DAVRANIŞI: `home` olarak `SplashScreen` kurulur.
  final String? ilkRota;

  const HizmetCepApp({super.key, this.navigatorKey, this.ilkRota});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HizmetCep',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: HC.theme(),
        // ── ⚠ GLOBAL WEB KABUĞU (tek kaynak) ──
        //
        // Her route'un ÜSTÜNDE çalışır; 48 ekranı tek tek sarmaya
        // gerek kalmaz ve yeni eklenen ekran kuralı kendiliğinden
        // alır. Geniş ekranda içerik `IcerikGenisligi.izgara` (1200)
        // sınırında ortalanır, zemin kenardan kenara uzanır.
        //
        // ⚠ YALNIZ WEB: kabuk `kIsWeb` ile korunuyor. Korunmasaydı
        // Android/iOS TABLETLERİ de (>600 px) etkilenir ve kilitli
        // mobil baseline değişirdi.
        //
        // ⚠ SIRA: kabuk `OfflineBanner`ın DIŞINDA. Çevrimdışı şeridi
        // sayfanın tamamına değil, ortalanmış içeriğe ait olmalı;
        // tersi olsaydı şerit 2560 px boyunca uzanırdı.
        // ⚠ AKTİF ROTAYI İZLER: web kabuğu içerik genişliğini rota
        // adına göre seçer (form 560 / liste 760 / geniş 1200) ve
        // `MaterialApp.builder` Navigator'ın üstünde çalıştığı için
        // rotayı başka türlü öğrenemez.
        navigatorObservers: [AktifRota()],
        // ⚠ PushKapisi (FCM yaşam döngüsü; izin yalnız girişte) ve
        // YasalKabulKapisi (yalnız API modu) ekran DIŞINDAN sarar; mevcut
        // builder yapısı (GlobalWebKabugu → OfflineBanner) AYNEN korunur.
        builder: (context, child) => PushKapisi(
          child: YasalKabulKapisi(
            child: GlobalWebKabugu(
              child: OfflineBanner(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
        // ⚠ İKİSİ BİRDEN VERİLEMEZ: `home` ve `initialRoute` aynı anda
        // tanımlanırsa Flutter `home`u kullanır. Web'de `home` null
        // bırakılır ki `initialRoute` işlesin.
        home: ilkRota == null ? const SplashScreen() : null,
        initialRoute: ilkRota,
        routes: {
          '/home': (_) => const HomeScreen(),


          // ── Ortak (her iki rol) ──
          '/profile': (_) => RoleGuard(builder: (_) => const ProfileScreen()),

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
          // ⚠ WEB'DE HARİTADA YOK: web'de bu ad `onGenerateRoute`ta
          // panel rotasıyla kurulur (giriş ekranı gibi). Haritada
          // kalsaydı Flutter `onGenerateRoute`u hiç çağırmazdı.
          // Mobilde satır AYNEN durur.
          if (!kIsWeb) PreLoginListingRoute.name: preLoginListingBuilder,

        },
        // ── ⚠ PARAMETRELİ ADRESLER (web için) ──
        //
        // Detay ekranları bugüne kadar YALNIZ `Navigator.push` ile
        // açılıyordu; adresleri yoktu. Web'de bunun anlamı: bağlantı
        // paylaşılamaz, F5 yapılınca ekran kaybolur, tarayıcı geçmişi
        // anlamsız kalır.
        //
        // ⚠ MOBİL AKIŞ BOZULMADI: mevcut 79 `Navigator.push` çağrısı
        // aynen duruyor. Bu dal yalnız ADRESLE gelindiğinde çalışır;
        // mobilde adres çubuğu olmadığı için hiç tetiklenmez.
        //
        // ⚠ `RoleGuard` KORUNDU: adresle gelen kullanıcı da aynı yetki
        // kapısından geçer. Aksi hâlde adres çubuğu, rol denetimini
        // atlamanın yolu olurdu.
        //
        // ⚠ HASH ADRESLER BİLİNÇLİ: `usePathUrlStrategy` (temiz yol)
        // EKLENMEDİ. Temiz yol, sunucunun bütün adresleri
        // `index.html`e yönlendirmesini ZORUNLU kılar; barındırma
        // sağlayıcısı henüz belli değil ve o kural olmadan kullanıcı
        // `/ilan/123` adresinde F5 yapınca SUNUCUDAN 404 alır —
        // uygulama hiç yüklenmediği için kendi 404 ekranımız bile
        // çalışmaz. Hash biçimi (`/#/ilan/123`) her statik sunucuda
        // yenilemeyi ÇALIŞIR hâlde tutar. Barındırma seçilince tek
        // satırla geçilebilir.
        //
        // ⚠ TÜRKÇE ADRESLER: kullanıcıya görünen metinler Türkçe;
        // adres de öyle olmalı.
        onGenerateRoute: (settings) {
          final ad = settings.name ?? '';

          // ── ⚠ ROTALAR `routes:` HARİTASINDAN BURAYA TAŞINDI ──
          //
          // ⚠ HANGİSİ MODAL, HANGİSİ SAYFA (19 Eyl, kullanıcı kararı):
          //
          //   · OTURUM ÖNCESİ akış (giriş, rol seçimi) → MODAL.
          //     Kullanıcı ana sayfayı gezerken araya giren kısa bir
          //     adımdır; arkasında sayfa durmalı.
          //
          //   · OTURUM İÇİ ekranlar (hizmet bölgelerim, kategorilerim,
          //     profil bilgileri, ilan oluştur …) → SIRADAN SAYFA.
          //     Bunlar kenar çubuğundan açılan BÖLÜMLERDİR; üstte
          //     modal olarak çıkınca kenar çubuğu kararıyor ve
          //     kullanıcı bölüm değiştirdiğini değil, bir pencere
          //     açtığını sanıyordu.
          //
          // ⚠ MOBİLDE İKİSİ DE AYNI: `panelRotasi` zaten `kIsWeb`
          // değilse düz `MaterialPageRoute` döndürüyordu; bu ayrım
          // yalnız web'i etkiler.
          //
          // `routes:` haritası her zaman `MaterialPageRoute` üretir ve
          // o rota OPAKTIR: altındaki sayfa çizilmez. Masaüstü web'de
          // panelin arkasında önceki sayfanın görünmesi için rotanın
          // `opaque: false` olması gerekiyor ve bu, rota kurulurken
          // verilen bir özellik.
          //
          // ⚠ AYNI EKRANLAR, AYNI KORUMALAR: `RoleGuard` sarmalayıcıları
          // birebir taşındı; yetki kapıları değişmedi.
          //
          // ⚠ MOBİLDE FARK YOK: `panelRotasi` `kIsWeb` değilse ya da
          // ekran dar ise düpedüz `MaterialPageRoute` döndürür.
          //
          // ⚠ `routes:` İLE ÇAKIŞMA OLMAZ: bu adlar haritadan
          // ÇIKARILDI. Haritada kalsalardı Flutter onGenerateRoute'u
          // hiç çağırmazdı.
          if (ad == '/login') {
            return panelRotasi<void>(
              settings: settings,
              builder: (_) => const LoginScreen(),
            );
          }
          if (ad == '/role') {
            return panelRotasi<void>(
              settings: settings,
              builder: (_) => const RoleSelectScreen(),
            );
          }
          // ── ⚠ YALNIZ WEB: ROL DEĞİŞTİR SAĞ ALANDA ──
          //
          // Web kenar çubuğundaki "Rol Değiştir" bu adı açar. Ekran
          // Android'in profil ekranından açtığı `RoleSwitchScreen`'in
          // KENDİSİ — kopya değil; düz sayfa rotası olduğu için diğer
          // menü sayfaları gibi sağ alanda çizilir.
          //
          // ⚠ MOBİL KİLİTLİ: `kIsWeb` koşulu yüzünden Android/iOS'ta bu
          // dal hiç eşleşmez; orada profil ekranı `RoleSwitchScreen`'i
          // bugünkü gibi doğrudan açar.
          if (kIsWeb && ad == '/profile/role') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  RoleGuard(builder: (_) => const RoleSwitchScreen()),
            );
          }
          if (ad == '/profile/info') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard(builder: (_) => const ProfileInfoScreen()),
            );
          }
          if (ad == '/profile/address') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard(builder: (_) => const AddressesScreen()),
            );
          }
          if (ad == '/profile/password') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard(builder: (_) => const ChangePasswordScreen()),
            );
          }
          if (ad == '/profile/account') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard(builder: (_) => const AccountSettingsScreen()),
            );
          }
          if (ad == '/profile/rate') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard(builder: (_) => const AppRateScreen()),
            );
          }
          if (ad == '/provider/categories') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard.provider(builder: (_) => const MyCategoriesScreen()),
            );
          }
          if (ad == '/provider/areas') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard.provider(builder: (_) => const MyAreasScreen()),
            );
          }
          // ── ⚠ İLAN OLUŞTURMA: WEB'DE PANEL (giriş ekranı gibi) ──
          //
          // Kullanıcı kararı: kategori kartlarıyla başlayan akış ve ilan
          // oluşturma ekranları web'de tam ekran değil, panel olarak
          // açılır. `akisRotasi` web değilse bugünkü `MaterialPageRoute`un
          // KENDİSİNİ döndürür — mobil DEĞİŞMEZ.
          if (ad == '/customer/new-listing') {
            return akisRotasi<void>(
              settings: settings,
              builder: (_) => RoleGuard.customer(builder: (_) => const CreateListingScreen()),
            );
          }
          if (kIsWeb && ad == PreLoginListingRoute.name) {
            return akisRotasi<void>(
              settings: settings,
              builder: preLoginListingBuilder,
            );
          }

          // `/ilan/<id>` — hizmet alanın kendi ilanı.
          final ilan = _idAyikla(ad, '/ilan/');
          if (ilan != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard.customer(
                  builder: (_) => ListingDetailScreen(listingId: ilan)),
            );
          }

          // `/is/<id>` — hizmet verenin gördüğü ilan.
          //
          // ⚠ AYRI ADRES, AYNI İLAN: iki taraf aynı ilanı FARKLI
          // ekranda görür (`yanlis_taraf_kapisi` bunu zorunlu kılıyor).
          // Tek adres verilseydi taraflardan biri kapıya çarpardı.
          final is_ = _idAyikla(ad, '/is/');
          if (is_ != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard.provider(
                  builder: (_) => JobDetailScreen(listingId: is_)),
            );
          }

          // `/teklif/<id>` — hizmet alanın gördüğü teklif detayı.
          final teklif = _idAyikla(ad, '/teklif/');
          if (teklif != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => RoleGuard.customer(
                  builder: (_) => OfferDetailScreen(offerId: teklif)),
            );
          }

          // `/talep/<id>` — Bul akışı; ekran iki rolü kendi ayırır.
          final talep = _idAyikla(ad, '/talep/');
          if (talep != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  RoleGuard(builder: (_) => TeklifTalebiDetayScreen(talepId: talep)),
            );
          }

          // `/mesaj/<teklifId>` — ilan akışı sohbeti.
          //
          // ⚠ `refId` TEKLİF kimliğidir, ilan değil (bildirim
          // yönlendirmesiyle aynı sözleşme).
          final mesaj = _idAyikla(ad, '/mesaj/');
          if (mesaj != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  RoleGuard(builder: (_) => ChatScreen(offerId: mesaj)),
            );
          }

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
        // ── ⚠ BİLİNMEYEN ADRES → 404 ──
        //
        // Web'de adres çubuğu KULLANICIYA aittir; `/olmayan-sayfa`
        // yazıldığında `MaterialApp` varsayılan olarak hiçbir şey
        // çizmiyor ve kullanıcı boş ekranda kalıyordu. Mobilde bu
        // durum oluşmaz (route adları koddan gelir), bu yüzden mobil
        // davranış da değişmez — bu dal orada hiç çalışmaz.
        //
        // ⚠ `onGenerateRoute`tan SONRA: o, tanıdığı adresleri zaten
        // karşılar; 404 yalnız geriye kalan için devreye girer.
        onUnknownRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BulunamadiScreen(),
        ),
      );

  /// `/ilan/abc` gibi bir adresten kimliği çıkarır; eşleşmezse `null`.
  ///
  /// ⚠ BOŞ KİMLİK KABUL EDİLMEZ: `/ilan/` adresi eşleşirse ekran boş
  /// kimlikle açılır ve "bulunamadı" yerine bozuk bir sayfa çizerdi.
  /// `null` dönünce `onUnknownRoute` devreye girer ve kullanıcı 404
  /// görür — doğru davranış budur.
  ///
  /// ⚠ ALT YOL KABUL EDİLMEZ: `/ilan/abc/def` gibi bir adres de 404'e
  /// gider; sessizce `abc` sayılması yanlış sayfayı açardı.
  static String? _idAyikla(String adres, String onek) {
    if (!adres.startsWith(onek)) {
      return null;
    }
    final kalan = adres.substring(onek.length).trim();
    if (kalan.isEmpty || kalan.contains('/')) {
      return null;
    }
    return kalan;
  }
}
