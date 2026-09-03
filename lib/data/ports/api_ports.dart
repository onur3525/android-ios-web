import '../../domain/failures.dart';
import '../remote/api_client.dart';
import '../models/account.dart';
import '../remote/api/region_api.dart';
import '../models/region.dart';
import '../models/provider_approval.dart';
import '../models/chat.dart';
import '../models/listing.dart';
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../remote/repositories/api_chat_repositories.dart';
import '../remote/repositories/api_repositories.dart';
import 'repository_ports.dart';
import '../remote/api_error_mapper.dart';
import '../remote/api_config.dart';

/// API PORT UYGULAMALARI — iş kuralları SUNUCUDA yürür; burada yalnız
/// çağrı, önbellek ve hata aktarımı vardır. İstemci tarafında sahte
/// başarı ÜRETİLMEZ: her işlem sunucunun kesin cevabını bekler.

class ApiAuthPort extends AuthPort {
  final ApiAuthRepository repo;
  ApiAuthPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Account? get currentAccount => repo.currentAccount;
  @override
  bool get loggedIn => repo.loggedIn;
  @override
  Role get activeRole => repo.activeRole;

  /// Başka kullanıcıların hesapları API modunda ayrı uçtan gelir;
  /// bu pakette yalnız oturum sahibi önbellektedir.
  @override
  Account? accountById(String id) =>
      repo.currentAccount?.id == id ? repo.currentAccount : null;

  /// ⚠ API MODUNDA GERÇEK UÇ YOK: "kategoriye göre hizmet veren
  /// bul" bir arama/dizin uç noktası (`GET /providers?service=...`)
  /// gerektirir; henüz TANIMLANMADI. Sahte sonuç ÜRETİLMEZ — boş
  /// liste dönülür, "Bul" akışı mock havuza düşer.
  @override
  List<Account> saglayicilarKimSunuyor(String kategori, String hizmet,
          {required String haricTutulacakId}) =>
      const [];

  /// ⚠ API modunda tercih SUNUCUYA da yazılmalıdır (`PATCH
  /// /profiles/me/notifications`). Uç hazır olmadığı için şimdilik
  /// yalnız yerel önbellek güncellenir; ekran davranışı iki modda da
  /// aynıdır, backend bağlanınca bu metodun gövdesi genişletilir.
  @override
  void setNotificationPrefs(
      {bool? teklif, bool? mesaj, bool? duyuru, bool? eposta}) {
    final acc = repo.currentAccount;
    if (acc == null) {
      return;
    }
    if (teklif != null) {
      acc.bildirimTeklif = teklif;
    }
    if (mesaj != null) {
      acc.bildirimMesaj = mesaj;
    }
    if (duyuru != null) {
      acc.bildirimDuyuru = duyuru;
    }
    if (eposta != null) {
      acc.bildirimEposta = eposta;
    }
    repo.bildir();
  }

  /// ⚠ SUNUCU UÇLARI HENÜZ YOK.
  ///
  /// `POST /auth/login/email`, `/auth/login/phone/start`, `/verify`
  /// sözleşmede tanımlı ama sunucuda yazılmadı. SAHTE BAŞARI
  /// ÜRETİLMEZ: uçlar gelene kadar API modunda bu yollar açık bir
  /// hata döndürür (bkz. docs/hesap_modeli_denetim_ve_sozlesme.md).
  @override
  Future<DomainError?> girisEposta(String email, String pass) async =>
      const ValidationError(_kUcYok);

  @override
  Future<DomainError?> girisTelefonSifre(String phone, String pass) async =>
      const ValidationError(_kUcYok);

  @override
  Future<({String? challengeId, DomainError? error})> girisTelefonKodGonder(
          String phone) async =>
      (challengeId: null, error: const ValidationError(_kUcYok));

  @override
  Future<DomainError?> girisTelefonDogrula(
          String challengeId, String kod) async =>
      const ValidationError(_kUcYok);

  // ⚠ SUNUCU UÇLARI HENÜZ YOK — SAHTE BAŞARI ÜRETİLMEZ.
  //
  // Challenge/yetki akışlarının sunucu karşılığı sözleşmede tanımlı
  // ama yazılmadı. API modunda bu yollar açık hata döndürür.
  @override
  Future<({String challengeId})> kayitKodGonder(String phone,
          {required String taslakKimligi}) async =>
      // ⚠ Boş kimlik: doğrulama adımı zaten hata döndürür.
      (challengeId: '');

  @override
  Future<({String? yetki, DomainError? error})> kayitDogrula(
          String challengeId, String kod) async =>
      (yetki: null, error: const ValidationError(_kUcYok));

  @override
  Future<({String? challengeId, DomainError? error})>
      telefonDegisimiKodGonder(String yeniTelefon) async =>
          (challengeId: null, error: const ValidationError(_kUcYok));

  @override
  Future<DomainError?> telefonDegisimiDogrula(
          String challengeId, String kod) async =>
      const ValidationError(_kUcYok);

  @override
  Future<({String challengeId})> hesapKurtarmaKodGonder(String phone) async =>
      (challengeId: '');

  @override
  Future<({String? yetki, DomainError? error})> hesapKurtarmaDogrula(
          String challengeId, String kod) async =>
      (yetki: null, error: const ValidationError(_kUcYok));

  @override
  Future<DomainError?> kurtarmaSifreBelirle(
          String yetki, String yeniSifre) async =>
      const ValidationError(_kUcYok);

  static const _kUcYok =
      'Bu giriş yöntemi henüz sunucuda etkin değil. Lütfen daha sonra '
      'tekrar deneyin.';

  /// ⚠ API MODUNDA KİLİT SUNUCUDADIR.
  ///
  /// İstemci kalan süreyi BİLMEZ; uydurmak yanlış geri sayım
  /// gösterirdi. 0 döner ve ekran sunucunun mesajını olduğu gibi
  /// gösterir.
  @override
  int girisKilidiKalan(String phone) => 0;

  /// ⚠ Sunucuda sorgu ucu YOK → BİLİNMİYOR. Ekran uyarı göstermez.
  @override
  bool? telefonKayitliMi(String phone) => null;

  @override
  Future<({Account? account, DomainError? error})> register({
    required String phone,
    required String pass,
    required Role role,
    required bool otpVerified,
    String otpCode = '',
    String name = '',
    String email = '',
    Set<String> categories = const {},
    Set<String> serviceDistricts = const {},
    bool termsAccepted = false,
    bool emailVerified = false,
    String? kayitYetkisi,
    String? taslakKimligi,
  }) async {
    // ⚠ Sözleşme onayı SUNUCUDA da doğrulanır; istemci kontrolü tek
    // savunma değildir. Burada erken çıkış kullanıcıya hızlı geri
    // bildirim içindir.
    if (!termsAccepted) {
      return (
        account: null,
        error: const ValidationError(
            'Kullanım sözleşmesi ve gizlilik politikası onayı zorunludur'),
      );
    }
    // otpVerified mock akışının kalıntısıdır; sunucu OTP kodunu kendi doğrular.
    final err = await repo.register(
        phone: phone, password: pass, name: name,
        email: email, role: role, otpCode: otpCode);
    if (err != null) {
      return (account: null, error: err);
    }
    if (categories.isNotEmpty || serviceDistricts.isNotEmpty) {
      await repo.saveProviderProfile(categories, serviceDistricts);
    }
    return (account: repo.currentAccount, error: null);
  }

    /// API modunda ikinci rol ekleme sunucuda şifre + OTP ister
  /// (`ApiAuthRepository.addRole(role, password, otpCode)`).
  ///
  /// Bu port imzası UI'ın kullandığı sözleşmedir; API modunda kullanıcı
  /// doğrulama adımından geçmeden rol eklenemeyeceği için burada
  /// yönlendirici hata döner. Mock modda rol doğrudan eklenir.
  /// ⚠ `switchRole` GERİ EKLENDİ.
  ///
  /// Generic `requestOtp` silinirken bu override yanlışlıkla aynı
  /// kesitte gitmişti ve `ApiAuthPort` arayüzü tamamlamıyordu
  /// (analyzer: non_abstract_class_inherits_abstract_member).
  ///
  /// Sunucu ucu VAR: aktif rol değişimi profil ucundan yapılır.
  @override
  Future<DomainError?> switchRole(Role role) => repo.switchRole(role);

  @override
  Future<DomainError?> addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
  }) async =>
      const ValidationError(
          'Rol eklemek için şifre ve SMS doğrulaması gerekir.');
  @override
  Future<DomainError?> changePassword(String current, String next) =>
      repo.changePassword(current, next);

  @override
  Future<DomainError?> verifyPassword(String password) =>
      repo.verifyPassword(password);

  /// Sunucuda ayrı bir "başlat" ucu yoktur: OTP isteği bu akışı başlatır.
  @override
  Future<DomainError?> sifreSifirlamaIste(String email) async =>
      // ⚠ SUNUCU UCU YOK — SAHTE BAŞARI ÜRETİLMEZ.
      const ValidationError(_kUcYok);

  Future<DomainError?> forgotStart(String phone) => repo.requestOtp(phone, 'FORGOT');
  @override
  Future<DomainError?> forgotComplete(String phone, String otp, String newPass) =>
      repo.forgotComplete(phone, otp, newPass);

  @override
  Future<DomainError?> updateProfile({String? name, String? photoPath}) =>
      // ⚠ E-posta GÖNDERİLMEZ: doğrulamayı atlatmak olurdu.
      repo.updateProfile(name: name, photoRef: photoPath);

  @override
  Future<DomainError?> epostaDegisimiBaslat(String yeniEposta) =>
      repo.changeEmail(yeniEposta);

  @override
  Future<ProviderApprovalState> providerApproval() => repo.providerApproval();

  /// Şehir SUNUCUDAN gelen bölge ağacından alınır; sabit dosya kullanılmaz.
  @override
  Future<DomainError?> saveAddress({
    required String district,
    required String neighborhood,
    required String city,
  }) =>
      repo.saveAddress(
        city: city, district: district, neighborhood: neighborhood,
      );
  @override
  Future<DomainError?> setProviderPrefs({Set<String>? categories, Set<String>? districts}) =>
      repo.saveProviderProfile(
        categories ?? repo.currentAccount?.categories ?? {},
        districts ?? repo.currentAccount?.serviceDistricts ?? {},
      );

  @override
  Future<void> logout() => repo.logout();
  @override
  Future<void> restoreSession() => repo.restoreSession();
}

class ApiListingPort extends ListingPort {
  final ApiListingRepository repo;
  ApiListingPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<Listing> get all => repo.all;
  @override
  Listing? byId(String id) => repo.byId(id);

  /// ⚠ ÖNBELLEKTEN ARAR. Sunucuda numaraya göre sorgu ucu
  /// tanımlanınca oraya bağlanacak; şu an yalnız yüklenmiş
  /// ilanlarda bulur ve SAHTE SONUÇ üretmez.
  @override
  Listing? byIlanNo(String ilanNo) {
    final n = ilanNo.trim();
    if (n.isEmpty) {
      return null;
    }
    for (final l in repo.all) {
      if (l.ilanNo == n) {
        return l;
      }
    }
    return null;
  }

  @override
  List<Listing> byOwner(String ownerId) =>
      repo.all.where((l) => l.ownerId == ownerId).toList();

  @override
  Future<DomainError?> loadMine(String ownerId) => repo.loadMine();
  @override
  Future<DomainError?> loadAvailable({String? category, String? district}) =>
      repo.loadAvailable(category: category, district: district);
  @override
  Future<DomainError?> loadOne(String id) => repo.loadOne(id);

  @override
  Future<({Listing? listing, DomainError? error})> publish({
    required String ownerId,
    required String title,
    required String location,
    required String desc,
    List<String>? photoPaths,
    IsZamani? isZamani,
  }) async {
    final (l, err) = await repo.create(
        title: title, location: location, description: desc,
        photoRefs: photoPaths ?? const [], isZamani: isZamani);
    return (listing: l, error: err);
  }

  /// Süre dolumu SUNUCUDA (30 saat zamanlayıcısı) işlenir; istemci tetiklemez.
  @override
  Future<DomainError?> expire(String listingId, {required String actorId}) async =>
      const InvalidStateError('Süre dolumu sunucu tarafından yönetilir');

  @override
  Future<DomainError?> delete(String listingId,
          {required String actorId, String? reason}) =>
      repo.remove(listingId, reason: reason);
}

class ApiOfferPort extends OfferPort {
  final ApiOfferRepository repo;
  ApiOfferPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<Offer> offersForListing(String listingId) => repo.forListing(listingId);
  @override
  List<Offer> offersByProvider(String providerId) =>
      repo.byProvider(providerId)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Offer? myOfferFor(String listingId, String providerId) {
    for (final o in repo.forListing(listingId)) {
      if (o.providerId == providerId) {
        return o;
      }
    }
    return null;
  }

  @override
  Offer? byId(String id) => repo.byId(id);

  @override
  Future<DomainError?> loadMine() => repo.loadMine();
  @override
  Future<DomainError?> loadForListing(String listingId) =>
      repo.loadForListing(listingId);

  @override
  Future<DomainError?> placeOffer({
    required String listingId,
    required String providerId,
    required int amount,
    required String note,
  }) async {
    final (_, err) = await repo.create(listingId: listingId, amountTl: amount, note: note);
    return err;
  }

  @override
  Future<DomainError?> selectOffer({
    required String listingId,
    required String offerId,
    required String actorId,
  }) =>
      // ⚠ Nihai uç ilana aittir; `listingId` artık ZORUNLU.
      repo.select(listingId, offerId);
}

class ApiContactPort extends ContactPort {
  final ApiContactRepository repo;
  ApiContactPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  bool isOpen(String offerId) => repo.isOpen(offerId);
  @override
  Future<DomainError?> refresh(String offerId) => repo.refresh(offerId);
  @override
  Future<DomainError?> openShared(String offerId, {required String actorId}) =>
      repo.open(offerId);
}

// ══════════════════════════════════════════════════════════════════
// Chat / Review / Notification — API portları.
// ══════════════════════════════════════════════════════════════════

class ApiChatPort extends ChatPort {
  final ApiChatRepository repo;
  ApiChatPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<ChatMessage>? threadFor(String offerId) => repo.threadFor(offerId);

  /// Sunucu yalnız iletişimi AÇILMIŞ teklifleri döndürür.
  @override
  List<Offer> conversationsFor(String actorId) => repo.conversations;

  @override
  Future<DomainError?> loadConversations(String actorId) => repo.loadConversations();

  @override
  Future<DomainError?> loadThread(String offerId, {required String actorId}) =>
      repo.loadThread(offerId);

  @override
  Future<({ChatMessage? message, DomainError? error})> send(
    String offerId, {
    required String senderId,
    String? text,
    String? storageRef,
  }) =>
      repo.send(offerId, senderId: senderId, text: text, storageRef: storageRef);

  @override
  Future<bool> retry(String offerId, ChatMessage message) => repo.retry(offerId, message);

  @override
  Future<DomainError?> markRead(String offerId, {required String readerId}) =>
      repo.markRead(offerId);

  @override
  Future<void> connectRealtime() => repo.connectRealtime();
  @override
  Future<void> disconnectRealtime() => repo.disconnectRealtime();
  @override
  bool get realtimeConnected => repo.realtimeConnected;
}

class ApiReviewPort extends ReviewPort {
  final ApiReviewRepository repo;
  final OfferPort offers;
  ApiReviewPort(this.repo, this.offers) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Review? byOffer(String offerId) => repo.byOffer(offerId);
  @override
  List<Review> byProvider(String providerId) => repo.byProvider(providerId);
  @override
  List<Review> byAuthor(String authorId) => repo.byAuthor(authorId);
  @override
  double? averageOf(String providerId) => repo.averageOf(providerId);
  @override
  Future<DomainError?> loadForProvider(String providerId) => repo.loadForProvider(providerId);

  /// Kural denetimi SUNUCUDA; hizmet veren, seçilmiş tekliften çözülür.
  @override
  Future<DomainError?> submit({
    required String listingId,
    required String offerId,
    required String actorId,
    required int stars,
    required String text,
  }) async {
    final providerId = offers.byId(offerId)?.providerId;
    if (providerId == null) {
      return const NotFoundError('Teklif bulunamadı');
    }
    return repo.submit(
        listingId: listingId, providerId: providerId, stars: stars, text: text);
  }
}

class ApiNotificationPort extends NotificationPort {
  final ApiNotificationRepository repo;
  ApiNotificationPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<AppNotification> forUser(String userId) => repo.items;
  @override
  int unreadCount(String userId) => repo.unread;
  @override
  Future<DomainError?> load(String userId) => repo.load();
  @override
  Future<DomainError?> loadUnreadCount(String userId) => repo.loadUnreadCount();
  @override
  Future<DomainError?> markRead(String id) => repo.markRead(id);
  @override
  Future<DomainError?> markAllRead(String userId) => repo.markAllRead();
}

/// Gerçek API üzerinden bölge verisi.
class ApiRegionPort implements RegionPort {
  final RegionApi api;
  ApiRegionPort(this.api);

  @override
  Future<(RegionTree?, DomainError?)> regionTree() async {
    try {
      final j = await api.tree();
      return (RegionTree.fromJson(j), null);
    } on ApiFailure catch (e) {
      return (null, e.error);
    } catch (_) {
      return (null, const ValidationError('Bölge verisi alınamadı'));
    }
  }
}

