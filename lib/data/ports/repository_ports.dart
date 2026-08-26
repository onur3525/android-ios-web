import 'package:flutter/foundation.dart';

import '../../domain/failures.dart';
import '../models/account.dart';
import '../models/payment.dart';
import '../models/token_package.dart';
import '../models/region.dart';
import '../models/provider_approval.dart';
import '../models/listing.dart';
import '../models/chat.dart';
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../models/wallet.dart';
import '../models/free_right.dart';
import '../controllers/saved_cards_controller.dart';

/// VERİ KAYNAĞI PORTLARI — controller'lar somut repository OLUŞTURMAZ,
/// yalnız bu arayüzlere bağlıdır. İki uygulaması vardır:
///   • mock  → bellek içi repository'ler (iş kuralları istemcide)
///   • api   → gerçek backend (iş kuralları sunucuda)
/// Okuma getter'ları SENKRONDUR (ekran tasarımı değişmesin diye);
/// veri, load* çağrılarıyla doldurulan önbellekten okunur.

abstract class AuthPort extends ChangeNotifier {
  Account? get currentAccount;
  bool get loggedIn;
  Role get activeRole;
  Account? accountById(String id);

  /// Bildirim tercihleri — yalnız verilen alanlar değişir.
  void setNotificationPrefs(
      {bool? teklif, bool? mesaj, bool? duyuru, bool? eposta});

  /// E-POSTA + ŞİFRE İLE GİRİŞ.
  Future<DomainError?> girisEposta(String email, String pass);

  /// TELEFON + ŞİFRE İLE GİRİŞ.
  ///
  /// ⚠ Kayıtlı kullanıcı her iki kimlikle de ŞİFRESİYLE girer;
  /// SMS OTP giriş anahtarı DEĞİLDİR (yalnız sahiplik doğrular).
  Future<DomainError?> girisTelefonSifre(String phone, String pass);

  /// TELEFONLA GİRİŞ — KOD İSTEĞİ.
  ///
  /// ⚠ K5: kayıtlı olsun olmasın AYNI nötr sonuç döner.
  /// ⚠ GERÇEK SMS YALNIZ UYGUN HESABA gider — nötr cevap kullanıcıya
  /// gösterilen şeydir, gönderim kararı değil. Sunucu kayıtsız
  /// numaraya SMS GÖNDERMEZ (aksi hâlde ücret ve taciz kapısı olur).
  Future<({String? challengeId, DomainError? error})> girisTelefonKodGonder(
      String phone);

  /// TELEFONLA GİRİŞ — KOD DOĞRULAMA.
  ///
  /// ⚠ K2: kayıtsız numarada HESAP OLUŞTURMAZ; nötr hata döner.
  /// ⚠ DOĞRULAMA BU ÇAĞRININ İÇİNDE yapılır — ekran yalnız kodu
  /// toplar. `challengeId` tek kullanımlıktır, süresi ve deneme
  /// hakkı vardır.
  Future<DomainError?> girisTelefonDogrula(String challengeId, String kod);

  /// GİRİŞ KİLİDİNİN KALAN SÜRESİ (saniye); kilit yoksa 0.
  ///
  /// ⚠ Ekran geri sayımı bunu SANİYEDE BİR sorar; metin içine gömülü
  /// donmuş bir sayı göstermez.
  ///
  /// ⚠ API modunda kilit SUNUCUDA tutulur ve istemci onu bilmez;
  /// orada 0 döner ve mesaj sunucudan geldiği gibi gösterilir.
  int girisKilidiKalan(String phone);

  /// TELEFON SİSTEME KAYITLI MI?
  ///
  /// ⚠ ÜÇ DEĞERLİ: `true` kayıtlı · `false` kayıtsız · `null` BİLİNMİYOR.
  ///
  /// Ürün kararı: kullanıcı numarasının tanınmadığını ÖĞRENMELİ —
  /// kayıtsız numarayla doğrulama adımına geçirilip orada tıkanmasın.
  /// (Numara enumerasyonu bu ekranda kabul edilmiş bir istisnadır.)
  ///
  /// ⚠ Sunucuda böyle bir uç YOKKEN `null` döner; ekran o zaman
  /// uyarı göstermez ve kararı gönderim sonucuna bırakır — SAHTE
  /// BİLGİ ÜRETİLMEZ.
  bool? telefonKayitliMi(String phone);

  /// GOOGLE İLE GİRİŞ — `idToken` sunucuda doğrulanır.
  /// İstemci e-posta/ad göndermez; sunucu Google'dan okur.
  // ⚠ `googleLogin` KALDIRILDI — üçüncü taraf girişi yok.
  Future<({Account? account, DomainError? error})> register({
    required String phone,
    required String pass,
    required Role role,
    required bool otpVerified,
    String otpCode = '',
    String name,
    String email,
    Set<String> categories,
    Set<String> serviceDistricts,

    // ── KAYIT / DOĞRULAMA SÖZLEŞMESİ ──
    //
    // Bu üç alan HizmetCep'in kayıt kurallarının parçasıdır ve
    // domain → port → controller → UI zincirinin TAMAMINDA taşınır.

    /// Kullanım Sözleşmesi + Gizlilik Politikası onayı.
    /// ⚠ Google ile kayıt bunu BYPASS ETMEZ.
    bool termsAccepted,

    /// Google akışında doğrulanmış e-posta ile gelinir; normal kayıtta
    /// yalnız gerçek doğrulama tamamlanınca true olur.
    bool emailVerified,

    /// Google hesabının benzersiz kimliği (`sub`).
    /// Hesap eşleştirmesi e-posta metniyle DEĞİL bu kimlikle yapılır.

    /// ⚠ OTP DOĞRULAMASINDAN ÜRETİLEN KAYIT YETKİSİ (Y1).
    /// Telefona VE kayıt taslağına bağlıdır; verildiğinde
    /// `otpVerified` bayrağına bakılmaz.
    String? kayitYetkisi,

    /// Kayıt denemesinin kimliği — yetkiyle eşleşmek zorundadır.
    String? taslakKimligi,
  });

  // ══════════════════════════════════════════════════════════════
  // TELEFON SAHİPLİĞİ — CHALLENGE / YETKİ SÖZLEŞMESİ
  //
  // ⚠ Ekran hiçbir akışta kodu kendi doğrulamaz; karar bu
  // metotlarındır (bkz. sözleşme C0-C1).
  // ══════════════════════════════════════════════════════════════

  /// KAYIT — telefon doğrulama kodu ister.
  Future<({String challengeId})> kayitKodGonder(String phone,
      {required String taslakKimligi});

  /// Kodu doğrular ve kısa ömürlü KAYIT YETKİSİ üretir.
  /// ⚠ Hesap burada OLUŞMAZ.
  Future<({String? yetki, DomainError? error})> kayitDogrula(
      String challengeId, String kod);

  /// TELEFON DEĞİŞİKLİĞİ — YENİ numaraya kod gönderir.
  /// ⚠ Mevcut telefon bu aşamada DEĞİŞMEZ.
  Future<({String? challengeId, DomainError? error})> telefonDegisimiKodGonder(
      String yeniTelefon);

  /// Doğrulama başarılıysa yeni numarayı tek adımda bağlar.
  /// ⚠ Numara challenge'ın İÇİNDEN gelir (Y4).
  Future<DomainError?> telefonDegisimiDogrula(String challengeId, String kod);

  /// HESAP KURTARMA — telefona kod gönderir (nötr cevap).
  Future<({String challengeId})> hesapKurtarmaKodGonder(String phone);

  /// Kod doğruysa KURTARMA YETKİSİ üretir.
  /// ⚠ OTURUM AÇMAZ; yalnız telefon sahipliğini doğrular.
  Future<({String? yetki, DomainError? error})> hesapKurtarmaDogrula(
      String challengeId, String kod);

  /// Kurtarma yetkisiyle yeni şifre belirler. ⚠ Oturum açmaz.
  Future<DomainError?> kurtarmaSifreBelirle(String yetki, String yeniSifre);
  // ⚠ `requestOtp` KALDIRILDI — challenge üretmeyen generic gönderim
  // yolu bırakılmaz (C7). Her akış kendi challenge-start metodunu
  // çağırır.
  Future<DomainError?> switchRole(Role role);

  /// İkinci rolü aynı hesaba ekler (eksik rol tamamlama akışı).
  Future<DomainError?> addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
  });
  Future<DomainError?> changePassword(String current, String next);

  /// ŞİFRE DOĞRULAMA — KRİTİK İŞLEM KAPISI.
  ///
  /// ⚠ Hesap silme gibi geri alınamaz işlemler doğrulamasız
  /// yapılmaz: telefonu açık bırakılmış bir kullanıcının hesabı
  /// üç dokunuşla kapatılabilirdi.
  ///
  /// Şifreyi DEĞİŞTİRMEZ; yalnız doğru olup olmadığını söyler.
  Future<DomainError?> verifyPassword(String password);
  /// E-POSTA İLE ŞİFRE YENİLEME BAĞLANTISI İSTEĞİ (ana yol).
  ///
  /// ⚠ K5: hesap bulunsa da bulunmasa da AYNI nötr sonuç.
  /// ⚠ Nötr BAŞARI metni YALNIZ sunucu isteği KABUL ETTİĞİNDE
  /// gösterilir; uç yoksa veya ağ hatası varsa açık sistem hatası
  /// döner — kullanıcıya e-posta gitmiş izlenimi VERİLMEZ.
  Future<DomainError?> sifreSifirlamaIste(String email);

  Future<DomainError?> forgotStart(String phone);
  Future<DomainError?> forgotComplete(String phone, String otp, String newPass);
  /// ⚠ `email` PARAMETRESİ KALDIRILDI.
  ///
  /// E-posta yalnız doğrulama bağlantısıyla değişir
  /// (`epostaDegisimiBaslat`). Bu uçtan göndermek doğrulamayı
  /// atlatmak olurdu.
  Future<DomainError?> updateProfile({String? name, String? photoPath});

  /// E-POSTA DEĞİŞİMİ — yeni adrese doğrulama bağlantısı yollar.
  ///
  /// ⚠ Hesabın e-postası bu çağrıyla DEĞİŞMEZ; bağlantı tıklanana
  /// kadar eski adres geçerlidir (iş kuralları §4).
  Future<DomainError?> epostaDegisimiBaslat(String yeniEposta);
  // ⚠ `updatePhone(newPhone, otpCode)` KALDIRILDI.
  //
  // Telefon değişikliği artık challenge sözleşmesinden geçiyor
  // (`telefonDegisimiKodGonder` / `telefonDegisimiDogrula`). Eski yol
  // kodu parametre olarak alıyordu ve doğrulamayı port yapıyordu;
  // numara da çağıranın alan değerinden geliyordu (Y4 ihlali).
  /// Hizmet veren platform onay durumu (teklif kapısı için).
  Future<ProviderApprovalState> providerApproval();

  /// TEK ADRES: kullanıcının en fazla bir adresi olur. Yalnız güncelleme
  /// vardır — ekleme ve silme akışı BULUNMAZ.
  Future<DomainError?> saveAddress({
    required String district,
    required String neighborhood,
    required String city,
  });
  Future<DomainError?> setProviderPrefs({Set<String>? categories, Set<String>? districts});
  Future<void> logout();

  /// Uygulama açılışı: saklı oturum varsa profil + aktif rol yüklenir.
  Future<void> restoreSession();
}

abstract class ListingPort extends ChangeNotifier {
  List<Listing> get all;
  Listing? byId(String id);

  /// İLAN NUMARASINA GÖRE ARAMA.
  ///
  /// ⚠ TEKNİK İLİŞKİ İÇİN DEĞİL: teklif, mesaj, ödeme ve şikâyet
  /// bağları DAİMA `id` (UUID) üzerinden kurulur. Bu uç yalnız
  /// kullanıcının/adminin yazdığı okunabilir referansı ilana çevirir.
  Listing? byIlanNo(String ilanNo);

  List<Listing> byOwner(String ownerId);

  Future<DomainError?> loadMine(String ownerId);
  Future<DomainError?> loadAvailable({String? category, String? district});
  Future<DomainError?> loadOne(String id);

  Future<({Listing? listing, DomainError? error})> publish({
    required String ownerId,
    required String title,
    required String location,
    required String desc,
    List<String>? photoPaths,
    // ⚠ İSTEĞE BAĞLI: `null` = kullanıcı zaman seçmedi.
    IsZamani? isZamani,
  });
  // ⚠ `startWork` / `completeWork` KALDIRILDI (API sözleşmesi §11).
  //
  // Nihai akış: İletişimi Aç → Teklifi Seç → Yorum Yap. Ayrı bir
  // "İşi Başlat" ya da "İşi Tamamla" aşaması YOKTUR; teklif
  // seçildiği anda iş tamamlanmış sayılır.
  //
  // ⚠ Bu paket ENUM GÖÇÜ DEĞİLDİR: `ListingStatus.completed` ve
  // `providerSelected` yerinde duruyor. Nihai enum göçü Paket 2'de.
  /// [reason] — kullanıcının seçtiği gerekçe; denetim için taşınır.
  // ⚠ `cancel` KALDIRILDI — tek kanonik silme `delete`tir
  // (`DELETE /listings/{id}`). Aynı iş için iki uç bırakılmaz.
  Future<DomainError?> expire(String listingId, {required String actorId});
  Future<DomainError?> delete(String listingId,
      {required String actorId, String? reason});
}

abstract class OfferPort extends ChangeNotifier {
  List<Offer> offersForListing(String listingId);
  List<Offer> offersByProvider(String providerId);
  Offer? myOfferFor(String listingId, String providerId);
  Offer? byId(String id);

  Future<DomainError?> loadMine();
  Future<DomainError?> loadForListing(String listingId);

  /// Teklif verir.
  ///
  /// ⚠ TEK GÜVENLİ İŞLEM: teklif kaydı ile bedelin ayrılması
  /// (TL bloke ya da ücretsiz hak tüketimi) birlikte yapılır.
  Future<DomainError?> placeOffer({
    required String listingId,
    required String providerId,
    required int amount,
    required String note,
  });

  /// Teklifi seçer — ilanın `selectedOffer` alanını yazar.
  ///
  /// ⚠ Nihai uç ilana aittir (`PUT /listings/{id}/selected-offer`),
  /// bu yüzden `listingId` zorunludur.
  Future<DomainError?> selectOffer({
    required String listingId,
    required String offerId,
    required String actorId,
  });

  // ⚠ `withdrawOffer` KALDIRILDI (API sözleşmesi §1).
  // Gönderilmiş teklif geri çekilemez; alternatif adla da eklenmez.
}

abstract class WalletPort extends ChangeNotifier {
  Wallet? walletOf(String userId);
  Future<DomainError?> load(String userId);
  /// ADIM 1 — ödeme oturumu aç. KART BİLGİSİ ALINMAZ; kullanıcı kartını
  /// yalnız sağlayıcının kendi sayfasında girer.
  /// Satın alınabilir jeton paketleri (yalnız gösterim).
  Future<(List<TokenPackage>?, DomainError?)> tokenPackages();

  /// [packageId] verilirse tutar SUNUCUDA paketten okunur; istemci fiyat
  /// belirleyemez. Paketsiz (serbest tutarlı) yüklemede [amountTl] verilir.
  Future<(PaymentSession?, DomainError?)> startTopup({
    required String userId,
    String? packageId,
    int? amountTl,
    required String idempotencyKey,
    String? savedCardToken,
  });

  /// ADIM 2 — sonucu SUNUCUDAN doğrula. İstemcinin bildirdiği sonuca
  /// güvenilmez; durum sağlayıcıdan okunur.
  Future<(PaymentStatus?, DomainError?)> confirmTopup(String sessionId);
}

abstract class ContactPort extends ChangeNotifier {
  bool isOpen(String offerId);
  Future<DomainError?> refresh(String offerId);
  Future<DomainError?> openShared(String offerId, {required String actorId});
}

abstract class ChatPort extends ChangeNotifier {
  /// Önbellekteki konuşma (yoksa null) — ekranlar senkron okur.
  List<ChatMessage>? threadFor(String offerId);

  /// Erişimi olan (iletişimi açılmış) konuşmalar.
  List<Offer> conversationsFor(String actorId);

  Future<DomainError?> loadConversations(String actorId);
  Future<DomainError?> loadThread(String offerId, {required String actorId});

  /// Gönderim: aynı mesaj İKİ KEZ gönderilmez (idempotencyKey),
  /// çevrimdışıyken gönderim ENGELLENİR.
  Future<({ChatMessage? message, DomainError? error})> send(
    String offerId, {
    required String senderId,
    String? text,
    String? storageRef,
  });

  /// Gönderilemeyen mesajı AYNI anahtarla tekrar dener.
  Future<bool> retry(String offerId, ChatMessage message);

  Future<DomainError?> markRead(String offerId, {required String readerId});

  /// Gerçek zamanlı bağlantı (mock modda no-op).
  Future<void> connectRealtime();
  Future<void> disconnectRealtime();
  bool get realtimeConnected;
}

abstract class ReviewPort extends ChangeNotifier {
  Review? byOffer(String offerId);
  List<Review> byProvider(String providerId);

  /// Müşterinin YAZDIĞI değerlendirmeler.
  ///
  /// ⚠ ŞU AN HİÇBİR EKRAN KULLANMIYOR. "Değerlendirmelerim" satırı
  /// ürün kararıyla yalnız HİZMET VEREN tarafında bırakıldı; hizmet
  /// alanın verdiği yorumları listeleyen ekran kaldırıldı.
  ///
  /// Veri yolu SİLİNMEDİ: yorum sahibine göre erişim ileride
  /// (ör. yorum düzenleme, moderasyon) gerekebilir ve dört katmanda
  /// yeniden kurmak pahalıdır.
  List<Review> byAuthor(String authorId);

  /// Hizmet verenin ortalama puanı (silinen yorumlar HARİÇ).
  double? averageOf(String providerId);

  Future<DomainError?> loadForProvider(String providerId);
  Future<DomainError?> submit({
    required String listingId,
    required String offerId,
    required String actorId,
    required int stars,
    required String text,
  });
}

abstract class NotificationPort extends ChangeNotifier {
  List<AppNotification> forUser(String userId);
  int unreadCount(String userId);

  Future<DomainError?> load(String userId);
  Future<DomainError?> loadUnreadCount(String userId);
  Future<DomainError?> markRead(String id);
  Future<DomainError?> markAllRead(String userId);
}

/// BÖLGE VERİSİ PORTU — şehir/ilçe/mahalle tek kaynaktan okunur.
abstract class RegionPort {
  /// Aktif bölge ağacı. Hata durumunda ikinci eleman dolu döner.
  Future<(RegionTree?, DomainError?)> regionTree();
}

/// ÜCRETSİZ İLETİŞİM AÇMA HAKKI portu.
///
/// ⚠ YALNIZ HİZMET VEREN rolünde kullanılır.
/// Hizmet Alan görünümünde bu port HİÇ ÇAĞRILMAZ — müşteri tarafında
/// cüzdan, bakiye, ledger ve ücretsiz hak gösterilmez.
///
/// Hak PARA DEĞİLDİR: cüzdan bakiyesi, jeton veya promosyon bakiyesi
/// değildir; nakde çevrilemez, devredilemez.
abstract class FreeRightPort {
  /// Kullanılabilir hak özeti (adet — TL değil).
  Future<(FreeRightSummary?, DomainError?)> summary();

  /// Teklif öncesi kaynak kararı — sunucu belirler, istemci SEÇMEZ.
  Future<(FundingDecision?, DomainError?)> fundingPreview();
}


/// KAYITLI KART PORTU
///
/// ⚠ Ham kart verisi bu arayüzden GEÇMEZ. Kart ekleme, sağlayıcının
/// güvenli sayfasında yapılır; buraya yalnız yönlendirme adresi ve
/// maskeli kart bilgisi döner.
abstract class SavedCardsPort {
  /// Kayıtlı kartlar. `available=false` ise özellik kapalıdır.
  Future<({bool available, List<SavedCard> cards})> listCards();

  /// Kart ekleme oturumu açar; sağlayıcının güvenli sayfa adresini döner.
  Future<String?> startCardSetup();

  /// Kayıtlı kartı siler.
  Future<void> deleteCard(String token);

  /// Varsayılan kartı değiştirir (yıldız butonu).
  Future<void> setDefaultCard(String token);

  /// Kart giriş yapılandırması — hosted-fields SDK anahtarları.
  /// `mode`: hosted_fields · redirect · unavailable
  Future<({String mode, Map<String, String>? config})> cardEntryConfig();

  /// Sağlayıcı SDK tokenını kalıcı karta çevirir.
  ///
  /// ⚠ `paymentToken` HAM KART VERİSİ DEĞİLDİR: kart numarası, CVV ve
  /// son kullanma tarihi sağlayıcının SDK'sı tarafından doğrudan
  /// sağlayıcıya iletilir; uygulama sunucusuna ULAŞMAZ.
  Future<SavedCard> saveCard({
    required String paymentToken,
    required String holderName,
    required bool makeDefault,
  });
}
