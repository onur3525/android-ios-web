import 'dart:async';
import 'dart:convert';

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
import 'screens/baglaniyor_screen.dart';
import 'screens/provider_status_screen.dart';
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
import 'data/repositories/chat_repository.dart';
import 'data/repositories/contact_repository.dart';
import 'data/repositories/listing_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/offer_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/ilan_no_uretici.dart';
import 'data/models/notification.dart';
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
import 'ui/bakim_ekrani.dart';
import 'ui/global_web_kabugu.dart';
import 'ui/panel_rotasi.dart';
import 'ui/gezgin.dart';
import 'data/remote/token_store.dart' show oturumIziVar;
import 'ui/web_header.dart' show masaustuNav;
import 'ui/yasal_kabul_kapisi.dart';
import 'ui/push_kapisi.dart';
import 'core/sekme_durumu.dart';
import 'data/repositories/sekme_anligi.dart';
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

  /// Yalnız mock modda: web'de yenilemede veriyi korumak için (sekme anlığı).
  final MockDepolar? mockDepolar;

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
    this.mockDepolar,
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
    final offerRepo = ApiOfferRepository(OfferApi(client));
    final offersPort = ApiOfferPort(offerRepo);
    // İlan sahibine gelen teklifler ilan uçlarından gelir; teklif deposuna
    // aktarılır (15 Eki: hizmet alan teklifleri görmüyordu).
    final listingRepo = ApiListingRepository(ListingApi(client))
      ..teklifleriAktar = offerRepo.ilanTeklifleriniAl;
    // Teklif verdiğim ilanlar (seçilmiş olsa da) ilan deposunda bulunur
    // (16 Eki: Kazandığım kartında "İlan kaldırıldı" görünüyordu).
    offerRepo.ilanlariAktar = listingRepo.teklifIlanlariniAl;
    // Gerçek zamanlı mesajlaşma: /ws namespace, access token ile kimlik.
    final ws = WsClient(WsAuth(client.tokens));
    return AppPorts(
      auth: ApiAuthPort(ApiAuthRepository(client, AuthApi(client), ProfileApi(client))),
      listings: ApiListingPort(listingRepo),
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

  // ── ⚠ DEMO VERİSİ YOK (canlı hazırlığı, 15 Eki) ──
  //
  // Mock modda da hazır hesap, ilan veya sabit OTP kodu YOKTUR;
  // hesap defteri ve ilan listesi boş başlar.

  return AppPorts(
    chat: MockChatPort(chatRepo, offerRepo, listingRepo,
        contacts: contactRepo, notifs: notifRepo),
    reviews: MockReviewPort(
        reviewRepo, listingRepo, offerRepo, contactRepo, teklifTalebiRepo),
    notifications: MockNotificationPort(notifRepo),
    notifRepo: notifRepo,
    teklifTalebiRepo: teklifTalebiRepo,
    authRepo: authRepo,
    mockDepolar: MockDepolar(listingRepo, offerRepo, chatRepo, contactRepo,
        reviewRepo, notifRepo, teklifTalebiRepo),
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
  // "Bul" değerlendirmesi: sunucunun talep görünümündeki değerlendirme
  // yorum deposuna bağlanır (yeniden girişte "Değerlendirme Yapıldı").
  final yorumPortu = ports.reviews;
  if (yorumPortu is ApiReviewPort && teklifTalebiPort is ApiTeklifTalebiPort) {
    yorumPortu.repo.talepCozucu = teklifTalebiPort.degerlendirme;
  }
  // Karşı taraf özetleri (API modu): iletişim açılınca ya da talepte
  // teklif verilince telefon/tam ad görünür hâle gelir; özetler eskitilir,
  // ekran bir sonraki okumada sunucudan tazesini alır.
  final authPortu = ports.auth;
  if (authPortu is ApiAuthPort) {
    ports.contact.addListener(authPortu.karsiTarafOzetleriniEskit);
    teklifTalebiPort.addListener(authPortu.karsiTarafOzetleriniEskit);
  }
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
  // ── ⚠ WEB: YENİLEMEDE AYNI EKRAN ("Masaüstü sitesi" geçişi dahil) ──
  //
  // Mobil tarayıcıda masaüstü/mobil görünüm değiştirilince sayfa BAŞTAN
  // yüklenir. Mock modda bütün veri bellekte olduğundan kayıtlı hesaplar
  // ve açık oturum kayboluyor, açılış ana sayfaya düşüyordu. Çözüm, SEKMEYE
  // ÖZEL depo (sessionStorage — sekme kapanınca silinir):
  //   · mock hesaplar ve sekmenin açık oturumu (yalnız MOCK modda),
  //   · açık ekranın rotası (AktifRota yazar, aşağıda okunur).
  // ⚠ MOBİL DEĞİŞMEZ (kIsWeb). API modunda jeton buraya YAZILMAZ.
  if (kIsWeb && ports.auth is MockAuthPort) {
    final repo = (ports.auth as MockAuthPort).repo;
    // Demo hesaplar KALICI depodan (mobildeki gibi; kullanıcı kararı 1 Eki).
    void hesaplariYukle() {
      final ham = kaliciOku(_kSekmeHesaplar);
      final liste = ham == null ? const [] : jsonDecode(ham);
      if (liste is List) {
        for (final j in liste.whereType<Map<String, dynamic>>()) {
          final h = Account.fromJson(j);
          repo.accounts.removeWhere((a) => a.id == h.id);
          repo.accounts.add(h);
        }
      }
    }

    try {
      hesaplariYukle();
      final tel = sekmeOku(_kSekmeOturum);
      final acc = tel == null ? null : repo.findByPhone(tel);
      if (acc != null) {
        repo.oturumuGeriYukle(acc);
      }
    } catch (_) {
      // Bozuk kayıt açılışı kilitlemez; sekme sıfırdan başlar.
    }
    final depolar = ports.mockDepolar;
    if (depolar != null) {
      depolar.sekmedenYukle();
      depolar.sekmeyeKaydetmeyiBaslat();
    }
    // İKİ SEKMEDE İKİ ROL: başka sekme hesap/veri yazınca bu sekme eşitlenir.
    kaliciDegisince((anahtar) {
      try {
        if (anahtar == _kSekmeHesaplar) {
          // Bildirim YOK: geri yazım tetiklenmez (sekmeler arası döngü olmaz);
          // giriş anında hesap listesi zaten okunur.
          hesaplariYukle();
        } else if (anahtar == MockDepolar.anahtar) {
          depolar?.sekmedenYukle();
        }
      } catch (_) {}
    });
    repo.addListener(() {
      kaliciYaz(_kSekmeHesaplar, jsonEncode(repo.accounts.map((a) => a.toJson()).toList()));
      final aktif = repo.currentAccount;
      if (aktif == null) {
        sekmeSil(_kSekmeOturum);
      } else {
        sekmeYaz(_kSekmeOturum, aktif.phone);
      }
    });
  }

  String? ilkRota;
  if (kIsWeb) {
    // ── ⚠ AÇILIŞ ROTASI (oturum geri yüklendikten SONRA hesaplanır) ──
    // `ilkRota` ve argümanlı kayıtlı ekran. Gecikmeli açılışta
    // (`BaglaniyorEkrani`) da AYNI hesap kullanılır; ikinci kopya yok.
    Future<({String rota, String? argRota, Object? arg})> acilisRotasi() async {
      final acc = ports.auth.currentAccount;
      String rota;
      if (acc != null) {
        // ── ⚠ YENİLEMEDE ROL KORUNUR (15 Eki) ──
        // İŞ KURALI (splash ile aynı): YENİ AÇILIŞTA çift rollü kullanıcı
        // hizmet veren panelinde açılır. Ama bu kural her yenilemede de
        // uygulanıyordu: hizmet alan rolünde "Masaüstü sitesi"ne geçen ya
        // da F5 yapan kullanıcı rolü değişmiş hâlde, kaldığı ekranla
        // uyuşmayan bir sayfaya düşüyordu. Sekmede kayıtlı ekran varsa bu
        // bir YENİLEMEDİR: o anki rol aynen korunur.
        final yenileme = sekmeOku(kSekmeRota) != null &&
            acc.roles.contains(acc.activeRole);
        final hedefRol = yenileme
            ? acc.activeRole
            : (acc.roles.contains(Role.provider)
                ? Role.provider
                : Role.customer);
        if (acc.activeRole != hedefRol) {
          await ports.auth.switchRole(hedefRol);
        }
        rota = hedefRol == Role.provider
            ? '/provider/jobs'
            : '/customer/listings';
      } else {
        rota = '/home';
      }
      // ⚠ Yenileme öncesi AÇIK EKRAN varsa oraya dönülür. Oturumluysa her
      // ekran; oturumsuzsa yalnız oturum gerektirmeyen ekranlar. Rota
      // yine onGenerateRoute + RoleGuard'dan geçer (yetki atlanamaz).
      final kayitli = sekmeOku(kSekmeRota);
      if (kayitli != null &&
          (acc != null || _kOturumsuzAcilabilir.any(kayitli.startsWith))) {
        final argHam = sekmeOku(kSekmeRotaArg);
        if (argHam == null) {
          return (rota: kayitli, argRota: null, arg: null);
        }
        // Argümanlı ekran: ana ekran üzerine, ilk kareden sonra AYNI
        // argümanla açılır (geri tuşu da doğal çalışır).
        Object? arg;
        try {
          arg = jsonDecode(argHam);
        } catch (_) {}
        if (arg != null) {
          return (rota: rota, argRota: kayitli, arg: arg);
        }
      }
      return (rota: rota, argRota: null, arg: null);
    }

    // ⚠ BÜTÇELİ: oturum web'de çerezle sunucudan yenilenir. Sunucu
    // uyanıkken 1 sn sürmez; bekleme dolarsa (aşağıda) karar oturum
    // izine göre verilir.
    final geriYukleme = ports.auth.restoreSession();
    // Bekleme dolduktan sonra gelen hata yakalanmamış sayılmasın.
    geriYukleme.ignore();
    try {
      // ⚠ 1200 → 2500 ms (15 Eki): web'de açılış ekranı yok (beyaz
      // sayfa); uzun bekleme yapılmaz. Süre dolarsa oturum izi olan
      // kullanıcı "Bağlanılıyor" ekranında sunucuyu bekler (aşağıda).
      await geriYukleme.timeout(const Duration(milliseconds: 2500));
      final r = await acilisRotasi();
      ilkRota = r.rota;
      if (r.argRota != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => gezginAnahtari
            .currentState
            ?.pushNamed(r.argRota!, arguments: r.arg));
      }
    } on TimeoutException {
      // ── ⚠ SUNUCU UYKUDA (15 Eki, kullanıcı bulgusu) ──
      // "1. girişimde ana sayfaya, 2. girişimde rol ekranıma gidiyor":
      // ücretsiz plandaki sunucu 30–60 sn'de uyanıyor. Bu tarayıcıda açık
      // bir oturum izi varsa ana sayfaya ATILMAZ; "Bağlanılıyor" ekranı
      // sunucuyu bekler, sonra aynı açılış hesabıyla yönlendirir. İz
      // yoksa (ziyaretçi) beklenmez, ana sayfa açılır.
      if (oturumIziVar()) {
        BootLog.olay('WEB_BOOT_BEKLE');
        BaglaniyorEkrani.bekleyen = () async {
          final bitis = DateTime.now().add(const Duration(seconds: 90));
          try {
            await geriYukleme;
          } catch (_) {}
          // Uyanma sırasında istek zaman aşımına uğrayabilir; iz durdukça
          // (sunucu çerezi reddetmedikçe) kısa aralıkla yeniden denenir.
          while (ports.auth.currentAccount == null &&
              oturumIziVar() &&
              DateTime.now().isBefore(bitis)) {
            await Future<void>.delayed(const Duration(seconds: 2));
            try {
              await ports.auth.restoreSession();
            } catch (_) {}
          }
          return acilisRotasi();
        }();
        ilkRota = BaglaniyorEkrani.rota;
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
        // ⚠ BakimKapisi (22 Eki): PushKapisi yalnız yaşam döngüsü sarmalayıcısı
        // olduğundan bakım katmanı onun hemen içinde, BÜTÜN ekranların üstünde.
        builder: (context, child) => PushKapisi(
          child: BakimKapisi(
            child: YasalKabulKapisi(
              child: GlobalWebKabugu(
                child: OfflineBanner(child: child ?? const SizedBox.shrink()),
              ),
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
          // Sunucu uykudayken oturumlu açılış: web (bkz. main()) ve mobil (SplashScreen).
          BaglaniyorEkrani.rota: (_) => const BaglaniyorEkrani(),


          // ── Ortak (her iki rol) ──
          // ── ⚠ MASAÜSTÜ WEB'DE PROFİL = PROFİL BİLGİLERİM (15 Eki) ──
          // Profil sayfasının menüsü kenar çubuğunda zaten var; masaüstü
          // düzeninde aynı liste sağda ikinci kez çiziliyordu ("ekranlar
          // karışıyor"). Karar TEK YERDE, rotada: sekme, yenilemede geri
          // açılış ve derin bağlantı aynı sonucu verir. Telefon ve dar
          // web'de (`masaustuNav` false) ekran AYNEN `ProfileScreen`.
          '/profile': (_) => RoleGuard(
              builder: (c) => masaustuNav(c)
                  ? const ProfileInfoScreen()
                  : const ProfileScreen()),

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

/// Sekme deposu anahtarları (yalnız web + mock; bkz. main()).
const String _kSekmeHesaplar = 'hc.demo.hesaplar'; // KALICI (localStorage)
const String _kSekmeOturum = 'hc.sekme.oturum';

/// Oturum gerektirmeyen ve yenilemede geri dönülebilen ekranlar.
const List<String> _kOturumsuzAcilabilir = [
  '/home', '/login', '/register', '/listing/new', '/legal', '/kategori', '/hizmet-alani', '/search',
];

/// ═══════════════════════════════════════════════════════════════
/// MOCK DEPOLAR — web'de yenilemede (masaüstü görünümü geçişi dahil)
/// ilan, teklif, sohbet, iletişim, yorum, bildirim ve teklif talebi
/// verisi SEKMEYE ÖZEL depoya yazılır ve açılışta geri yüklenir.
/// Yalnız web + mock modda kullanılır (bkz. main()); mobil değişmez.
/// ═══════════════════════════════════════════════════════════════
class MockDepolar {
  MockDepolar(this.ilan, this.teklif, this.sohbet, this.iletisim, this.yorum,
      this.bildirim, this.talep);

  final ListingRepository ilan;
  final OfferRepository teklif;
  final ChatRepository sohbet;
  final ContactRepository iletisim;
  final ReviewRepository yorum;
  final NotificationRepository bildirim;
  final TeklifTalebiRepository talep;

  static const String anahtar = 'hc.demo.veri';
  bool _yukleniyor = false;
  bool _kayitBekliyor = false;

  void sekmedenYukle() {
    final ham = kaliciOku(anahtar);
    if (ham == null) {
      return;
    }
    _yukleniyor = true;
    try {
      final j = jsonDecode(ham) as Map<String, dynamic>;
      List<Map<String, dynamic>> liste(String k) =>
          ((j[k] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
      final ilanlar = liste('ilan').map(ilanCoz).toList();
      for (final l in ilanlar) {
        IlanNoUretici.rezerveEt(l.ilanNo);
      }
      ilan.sekmeKayitlariniYukle(ilanlar);
      teklif.sekmeKayitlariniYukle(liste('teklif').map(teklifCoz));
      sohbet.sekmeKayitlariniYukle({
        for (final e in ((j['sohbet'] as Map?) ?? const {}).entries)
          '${e.key}': ((e.value as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(mesajCoz)
              .toList(),
      });
      iletisim.sekmeKayitlariniYukle(((j['iletisim'] as List?) ?? const []).map((e) => '$e'));
      yorum.sekmeKayitlariniYukle(liste('yorum').map(yorumCoz));
      bildirim.sekmeKayitlariniYukle(liste('bildirim').map(bildirimCoz).whereType<AppNotification>());
      final talepler = liste('talep').map(talepCoz).toList();
      for (final t in talepler) {
        IlanNoUretici.rezerveEt(t.talepNo);
      }
      talep.sekmeKayitlariniYukle(talepler);
    } catch (_) {
      // Bozuk anlık açılışı kilitlemez; sekme boş veriyle sürer.
    } finally {
      _yukleniyor = false;
    }
  }

  void sekmeyeKaydetmeyiBaslat() {
    for (final d in <ChangeNotifier>[ilan, teklif, sohbet, iletisim, yorum, bildirim, talep]) {
      d.addListener(_kaydetIste);
    }
  }

  // Aynı karede gelen çok sayıda değişiklik TEK yazıma toplanır.
  void _kaydetIste() {
    if (_yukleniyor || _kayitBekliyor) {
      return;
    }
    _kayitBekliyor = true;
    scheduleMicrotask(() {
      _kayitBekliyor = false;
      try {
        kaliciYaz(anahtar, jsonEncode({
          'ilan': ilan.sekmeKayitlari.map(ilanJson).toList(),
          'teklif': teklif.sekmeKayitlari.map(teklifJson).toList(),
          'sohbet': {
            for (final e in sohbet.sekmeKayitlari.entries) e.key: e.value.map(mesajJson).toList(),
          },
          'iletisim': iletisim.sekmeKayitlari,
          'yorum': yorum.sekmeKayitlari.map(yorumJson).toList(),
          'bildirim': bildirim.sekmeKayitlari.map(bildirimJson).toList(),
          'talep': talep.sekmeKayitlari.map(talepJson).toList(),
        }));
      } catch (_) {
        // Depo dolu/kapalı: bellekteki veri etkilenmez.
      }
    });
  }
}
