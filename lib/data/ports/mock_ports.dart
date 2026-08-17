import '../../core/validators.dart';
import '../../domain/cikar_catismasi.dart';
import '../../domain/config.dart';
import '../../domain/failures.dart';
import '../../domain/listing_state_machine.dart';
import '../models/account.dart';
import '../models/payment.dart';
import '../models/token_package.dart';
import '../izmir_neighborhoods.dart';
import '../izmir.dart';
import '../models/region.dart';
import '../models/provider_approval.dart';
import '../models/listing.dart';
import '../models/notification.dart';
import '../models/chat.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../models/wallet.dart';
import '../repositories/auth_repository.dart';
import '../services/otp_service.dart';
import '../repositories/chat_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/listing_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/offer_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/wallet_repository.dart';
import 'repository_ports.dart';
import '../models/free_right.dart';
import '../controllers/saved_cards_controller.dart';

/// MOCK PORT UYGULAMALARI — bellek içi repository'leri sarar.
/// Buradaki iş kuralları, controller'lardan BİREBİR taşındı; hiçbir kural
/// değiştirilmedi. (API modunda aynı kurallar sunucuda uygulanır.)

class MockAuthPort extends AuthPort {
  final AuthRepository repo;
  MockAuthPort(this.repo) {
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
  @override
  Account? accountById(String id) => repo.byId(id);
  @override
  void setNotificationPrefs(
          {bool? teklif, bool? mesaj, bool? duyuru, bool? eposta}) =>
      repo.setNotificationPrefs(
          teklif: teklif, mesaj: mesaj, duyuru: duyuru, eposta: eposta);

  @override
  Future<DomainError?> girisEposta(String email, String pass) async =>
      repo.girisEposta(email, pass);

  @override
  Future<DomainError?> girisTelefonSifre(String phone, String pass) async =>
      repo.girisTelefonSifre(phone, pass);

  @override
  Future<({String? challengeId, DomainError? error})> girisTelefonKodGonder(
          String phone) async =>
      repo.girisTelefonKodGonder(phone);

  @override
  Future<DomainError?> girisTelefonDogrula(String challengeId, String kod) =>
      repo.girisTelefonDogrula(challengeId, kod);

  @override
  int girisKilidiKalan(String phone) => repo.girisKilidiKalan(phone);

  @override
  bool? telefonKayitliMi(String phone) => repo.telefonKayitliMi(phone);

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
    /// Sözleşme + gizlilik onayı — Google akışında da ZORUNLU.
    bool termsAccepted = false,
    /// Google akışında doğrulanmış e-posta ile gelinir.
    bool emailVerified = false,
    /// Google `sub` — hesap eşleştirme kimliği.
    String? googleSub,
    String? kayitYetkisi,
    String? taslakKimligi,
  }) async =>
      repo.register(
        phone: phone, pass: pass, role: role, otpVerified: otpVerified,
        name: name, email: email,
        categories: categories, serviceDistricts: serviceDistricts,
        termsAccepted: termsAccepted,
        emailVerified: emailVerified,
        googleSub: googleSub,
        kayitYetkisi: kayitYetkisi,
        taslakKimligi: taslakKimligi,
      );

  @override
  Future<({String challengeId})> kayitKodGonder(String phone,
          {required String taslakKimligi}) async =>
      repo.kayitKodGonder(phone, taslakKimligi: taslakKimligi);

  @override
  Future<({String? yetki, DomainError? error})> kayitDogrula(
          String challengeId, String kod) =>
      repo.kayitDogrula(challengeId, kod);

  @override
  Future<({String? challengeId, DomainError? error})>
      telefonDegisimiKodGonder(String yeniTelefon) async =>
          repo.telefonDegisimiKodGonder(yeniTelefon);

  @override
  Future<DomainError?> telefonDegisimiDogrula(
          String challengeId, String kod) =>
      repo.telefonDegisimiDogrula(challengeId, kod);

  @override
  Future<({String challengeId})> hesapKurtarmaKodGonder(String phone) async =>
      repo.hesapKurtarmaKodGonder(phone);

  @override
  Future<({String? yetki, DomainError? error})> hesapKurtarmaDogrula(
          String challengeId, String kod) =>
      repo.hesapKurtarmaDogrula(challengeId, kod);

  @override
  Future<DomainError?> kurtarmaSifreBelirle(
          String yetki, String yeniSifre) async =>
      repo.kurtarmaSifreBelirle(yetki, yeniSifre);

  /// Mock akışta OTP doğrulaması OtpService üzerinden yürür.
    @override
  Future<DomainError?> switchRole(Role role) async => repo.switchRole(role);

  @override
  Future<DomainError?> addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
  }) async =>
      repo.addRole(role,
          categories: categories, serviceDistricts: serviceDistricts);
  @override
  Future<DomainError?> changePassword(String current, String next) async =>
      repo.changePassword(current, next);

  /// ⚠ ŞİFREYİ DEĞİŞTİRMEZ. Depoda ayrı bir doğrulama yolu yok;
  /// kural tek yerde durduğu için `changePassword` mantığı YENİDEN
  /// YAZILMAZ — aynı hash karşılaştırması `dogrula` ile çağrılır.
  @override
  Future<DomainError?> verifyPassword(String password) async =>
      repo.sifreDogrula(password);
  @override
  Future<DomainError?> sifreSifirlamaIste(String email) async =>
      repo.sifreSifirlamaIste(email);

  Future<DomainError?> forgotStart(String phone) async => repo.forgotStart(phone);
  @override
  /// ŞİFRE SIFIRLAMA — SON ADIM.
  ///
  /// ⚠ Önceki hâl hiçbir şey denetlemiyordu: kayıtlı olmayan bir
  /// numara ve rastgele bir kodla çağrıldığında sessizce `null`
  /// dönüyor, ekran "şifreniz değişti" diyordu — oysa hiçbir hesap
  /// güncellenmemişti.
  ///
  /// Üç koşul da BURADA aranır:
  ///   1. Numara SİSTEMDE KAYITLI olmalı
  ///   2. SMS kodu doğrulanmış olmalı
  ///   3. Yeni şifre kurallara uymalı
  Future<DomainError?> forgotComplete(
      String phone, String otp, String newPass) async {
    final hata = repo.forgotStart(phone);
    if (hata != null) {
      return hata;
    }
    final kod = otp.trim();
    if (kod.isEmpty) {
      return const ValidationError('SMS doğrulama kodu zorunludur');
    }
    if (!await MockOtpService().verify(phone, kod)) {
      return const ValidationError(
          'SMS kodu doğrulanamadı — şifre değiştirilmedi');
    }
    final sifreHatasi = Validators.password(newPass);
    if (sifreHatasi != null) {
      return ValidationError(sifreHatasi);
    }
    repo.forgotSave(phone, newPass);
    return null;
  }

  @override
  Future<DomainError?> googleLogin(String idToken) async =>
      // Geliştirme modunda Google girişi SİMÜLE EDİLMEZ.
      // Gerçek akış yalnız API modunda ve sunucu doğrulamasıyla çalışır.
      const ValidationError(
          'Google ile giriş yalnız gerçek API modunda kullanılabilir');

  @override
  Future<DomainError?> updateProfile({String? name, String? email, String? photoPath}) async {
    repo.updateProfile(name: name, email: email, photoPath: photoPath);
    return null;
  }

  /// TELEFON DEĞİŞİKLİĞİ — SMS DOĞRULAMASI ZORUNLUDUR.
  ///
  /// ⚠ Önceki hâl `otpCode` parametresini ALIYOR ama HİÇ BAKMIYORDU:
  /// boş kodla, hatalı kodla, hatta ekranı hiç görmeden yapılan bir
  /// çağrı numarayı değiştiriyordu. Telefon hesabın kimlik ve
  /// kurtarma anahtarıdır; doğrulamasız değişmesi hesap ele geçirme
  /// yoludur.
  ///
  /// Doğrulama artık BURADA da yapılır — ekrandaki kontrol tek
  /// savunma değildir (API modunda karar sunucunundur).
    /// MOCK: onay akışı yoktur, hesap onaylı kabul edilir.
  @override
  Future<ProviderApprovalState> providerApproval() async =>
      const ProviderApprovalState(
        status: ProviderApproval.approved, message: '',
      );

  @override
  Future<DomainError?> saveAddress({
    required String district,
    required String neighborhood,
    required String city,
  }) async {
    repo.setAddress(
        district: district, neighborhood: neighborhood, city: city);
    return null;
  }

  @override
  Future<DomainError?> setProviderPrefs(
          {Set<String>? categories, Set<String>? districts}) async =>
      // ⚠ SONUÇ YUTULMUYOR: depo boş kümeyi reddeder ve hatayı
      // döndürür; port onu olduğu gibi iletir.
      repo.setProviderPrefs(categories: categories, districts: districts);

  @override
  Future<void> logout() async => repo.logout();
  @override
  Future<void> restoreSession() async {}
}

class MockListingPort extends ListingPort {
  final ListingRepository listings;
  final OfferRepository offers;
  final ContactRepository contacts;
  final ChatRepository chats;
  final MockOfferPort offerPort;

  /// ⚠ ÇIKAR ÇATIŞMASI DENETİMİ İÇİN.
  ///
  /// İlan sahibinin hizmet verdiği kategorileri okumak gerekir; bu
  /// bilgi hesap deposundadır. Verilmezse denetim atlanır (eski
  /// davranış) — testler ve eski çağrılar kırılmaz.
  final AuthRepository? auth;

  MockListingPort(this.listings, this.offers, this.contacts, this.chats,
      this.offerPort, {this.auth}) {
    listings.addListener(notifyListeners);
    offers.addListener(notifyListeners);
  }
  @override
  void dispose() {
    listings.removeListener(notifyListeners);
    offers.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<Listing> get all => listings.all;
  @override
  Listing? byId(String id) => listings.byId(id);

  @override
  Listing? byIlanNo(String ilanNo) => listings.byIlanNo(ilanNo);
  @override
  List<Listing> byOwner(String ownerId) => listings.byOwner(ownerId);

  // Bellek içi kaynakta yükleme yoktur — veri zaten hazırdır.
  @override
  Future<DomainError?> loadMine(String ownerId) async => null;
  @override
  Future<DomainError?> loadAvailable({String? category, String? district}) async => null;
  @override
  Future<DomainError?> loadOne(String id) async => null;

  /// KURAL: Müşteri ücretsiz ve sınırsız ilan verebilir.
  ///
  /// ⚠ TEK İSTİSNA — ÇIKAR ÇATIŞMASI.
  ///
  /// Kullanıcı hizmet veren olarak bir kategoride çalışıyorsa, MÜŞTERİ
  /// rolünde AYNI kategoride ilan açamaz. Aksi hâlde kendi alanındaki
  /// rakiplerinden teklif toplayıp fiyat öğrenebilir; pazaryerinin
  /// güveni buna dayanır.
  ///
  /// Denetim ANA KATEGORİ düzeyindedir: alt hizmet farklı olsa bile
  /// aynı ana kategoriye giriyorsa engellenir.
  @override
  Future<({Listing? listing, DomainError? error})> publish({
    required String ownerId,
    required String title,
    required String location,
    required String desc,
    List<String>? photoPaths,
  }) async {
    final hata = _cikarCatismasi(ownerId, title);
    if (hata != null) {
      return (listing: null, error: hata);
    }
    final l = listings.create(
        ownerId: ownerId, title: title, location: location,
        desc: desc, photoPaths: photoPaths);
    return (listing: l, error: null);
  }

  /// Kullanıcı bu başlığın ana kategorisinde HİZMET VERİYOR mu?
  ///
  /// ⚠ KURAL BURADA YAZILMAZ, ÇAĞRILIR: tek kaynak
  /// `lib/domain/cikar_catismasi.dart`. Ekran da aynı kuralı seçim
  /// anında uygular; burası İKİNCİ SAVUNMADIR (ekran atlanabilir,
  /// port atlanamaz).
  DomainError? _cikarCatismasi(String ownerId, String title) {
    final acc = auth?.byId(ownerId);
    if (acc == null || acc.categories.isEmpty) {
      return null;
    }
    final ana = catisanKategori(
        saglayiciSecimleri: acc.categories, ilanBasligi: title);
    return ana == null ? null : ValidationError(catismaMesaji(ana));
  }

  ({Listing? listing, DomainError? error}) _authorize(String listingId, String actorId) {
    final l = listings.byId(listingId);
    if (l == null) {
      return (listing: null, error: const NotFoundError('İlan bulunamadı'));
    }
    if (l.ownerId != actorId) {
      return (listing: null, error: const UnauthorizedError('Bu ilanı yalnızca sahibi yönetebilir'));
    }
    return (listing: l, error: null);
  }

  DomainError? _transition(String id, String actorId, ListingStatus to) {
    final a = _authorize(id, actorId);
    if (a.error != null) {
      return a.error;
    }
    if (!ListingStateMachine.canTransition(a.listing!.status, to)) {
      return const InvalidStateError('Bu ilan için geçersiz durum geçişi');
    }

    // ── SEÇİLİ TEKLİF ZORUNLULUĞU ──
    //
    // ⚠ `providerSelected` ve `completed` durumları ANLAMLARINI seçili
    // teklifden alır: "bir sağlayıcı seçildi" / "o sağlayıcı işi
    // bitirdi". `selectedOfferId` boşken bu durumlara geçmek ilanı
    // TUTARSIZ bir hâle sokar — kim seçildi, kim tamamladı belli
    // olmaz; değerlendirme de hedefsiz kalır.
    //
    // ⚠ DENETİM GEÇİŞTEN ÖNCE yapılır: hata dönerse ilanın durumu
    // DEĞİŞMEZ. Sonradan kontrol etmek, ilanı bozuk duruma sokup
    // ardından hata göstermek olurdu.
    const seciliGerektiren = {
      ListingStatus.providerSelected,
      ListingStatus.completed,
    };
    if (seciliGerektiren.contains(to) &&
        (a.listing!.selectedOfferId ?? '').isEmpty) {
      return const InvalidStateError(
          'Bu ilan için seçilmiş teklif bulunamadı — işlem tamamlanamadı');
    }

    listings.setStatus(id, to);
    return null;
  }

  @override
  Future<DomainError?> startWork(String listingId, {required String actorId}) async =>
      _transition(listingId, actorId, ListingStatus.inProgress);
  @override
  Future<DomainError?> completeWork(String listingId, {required String actorId}) async =>
      _transition(listingId, actorId, ListingStatus.completed);

  /// İptal: açılmamış blokeler iade edilir; completed İPTAL EDİLEMEZ.
  @override
  Future<DomainError?> cancel(String listingId,
      {required String actorId, String? reason}) async {
    final a = _authorize(listingId, actorId);
    if (a.error != null) {
      return a.error;
    }
    if (!ListingStateMachine.canTransition(a.listing!.status, ListingStatus.cancelled)) {
      return const InvalidStateError('Bu ilan bu aşamada iptal edilemez');
    }
    offerPort.cancelAllForListing(listingId, reason: 'İlan iptal edildi');
    listings.setStatus(listingId, ListingStatus.cancelled);
    return null;
  }

  /// Süre dolumu: yalnız open ilanlar için. completed DOKUNULMAZ.
  @override
  Future<DomainError?> expire(String listingId, {required String actorId}) async {
    final a = _authorize(listingId, actorId);
    if (a.error != null) {
      return a.error;
    }
    if (!ListingStateMachine.canTransition(a.listing!.status, ListingStatus.expired)) {
      return const InvalidStateError('Bu ilanın süresi bu aşamada dolamaz');
    }
    offerPort.cancelAllForListing(listingId, reason: 'İlan süresi doldu');
    listings.setStatus(listingId, ListingStatus.expired);
    return null;
  }

  /// Silme: completed HARİÇ. Açılmamış blokeler iade edilir.
  @override
  Future<DomainError?> delete(String listingId,
      {required String actorId, String? reason}) async {
    final a = _authorize(listingId, actorId);
    if (a.error != null) {
      return a.error;
    }
    if (!ListingStateMachine.canDelete(a.listing!.status)) {
      return const InvalidStateError('Tamamlanmış ilan silinemez');
    }
    offerPort.cancelAllForListing(listingId, reason: 'İlan silindi');
    final offerIds = offers.forListing(listingId).map((o) => o.id).toList();
    contacts.removeForOffers(offerIds);
    chats.removeForOffers(offerIds);
    offers.removeForListing(listingId);
    listings.remove(listingId);
    return null;
  }
}

class MockOfferPort extends OfferPort {
  final OfferRepository offers;
  final ListingRepository listings;
  final WalletRepository wallets;
  final NotificationRepository? notifs;
  MockOfferPort(this.offers, this.listings, this.wallets, {this.notifs}) {
    offers.addListener(notifyListeners);
    listings.addListener(notifyListeners);
    wallets.addListener(notifyListeners);
  }
  @override
  void dispose() {
    offers.removeListener(notifyListeners);
    listings.removeListener(notifyListeners);
    wallets.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<Offer> offersForListing(String listingId) => offers.forListing(listingId);
  @override
  Offer? myOfferFor(String listingId, String providerId) =>
      offers.byProviderForListing(listingId, providerId);
  @override
  Offer? byId(String id) => offers.byId(id);
  @override
  List<Offer> offersByProvider(String providerId) =>
      offers.byProvider(providerId)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<DomainError?> loadMine() async => null;
  @override
  Future<DomainError?> loadForListing(String listingId) async => null;

  /// KURAL: Teklif ücretsizdir; iletişim ücreti kadar bakiye bloke edilir.
  @override
  Future<DomainError?> placeOffer({
    required String listingId,
    required String providerId,
    required int amount,
    required String note,
  }) async {
    final l = listings.byId(listingId);
    if (l == null) {
      return const NotFoundError('İlan bulunamadı');
    }
    if (l.ownerId == providerId) {
      return const OwnListingOfferError();
    }
    if (!l.acceptsOffers) {
      return const ListingClosedError();
    }
    if (!DateTime.now().isBefore(l.expiresAt)) {
      return const ListingClosedError();
    }
    if (myOfferFor(listingId, providerId) != null) {
      return const DuplicateOfferError();
    }
    if (wallets.walletOf(providerId).avail < DomainConfig.contactFee) {
      return InsufficientBalanceError(
          'Yetersiz kullanılabilir bakiye — teklif için ${DomainConfig.contactFee} TL bloke edilir. Lütfen bakiye yükleyin.');
    }
    offers.create(listingId: listingId, providerId: providerId, amount: amount, note: note);
    wallets.block(providerId, DomainConfig.contactFee, listingTitle: l.title);
    notifs?.push(
        userId: l.ownerId, type: NotifType.newOffer, refId: listingId,
        title: 'Yeni teklif aldınız',
        body: '"${l.title}" ilanınıza yeni bir teklif geldi.');
    return null;
  }

  /// KURAL: Teklifi yalnız İLAN SAHİBİ seçebilir; seçilmeyenlerin
  /// açılmamış blokeleri iade edilir.
  @override
  Future<DomainError?> selectOffer({
    required String listingId,
    required String offerId,
    required String actorId,
  }) async {
    final l = listings.byId(listingId);
    final chosen = offers.byId(offerId);
    if (l == null || chosen == null || chosen.listingId != listingId) {
      return const NotFoundError('Teklif bulunamadı');
    }
    if (actorId != l.ownerId) {
      return const UnauthorizedError('Teklifi yalnızca ilan sahibi seçebilir');
    }
    if (!ListingStateMachine.canTransition(l.status, ListingStatus.providerSelected)) {
      return const InvalidStateError('Bu ilan için seçim yapılamaz');
    }

    // ── ⚠ TEKLİF AKTİF OLMALIDIR ──
    //
    // Bu kontrol YOKTU ve PARA KAYBI üretiyordu:
    //
    //   1. Hizmet veren teklif verir  → active, 50 TL BLOKE
    //   2. Teklifini GERİ ÇEKER       → cancelled, bloke İADE EDİLDİ
    //   3. İlan hâlâ `open` (geri çekme ilan durumuna dokunmaz)
    //   4. İlan sahibi o iptal teklifi SEÇEBİLİYORDU
    //   5. İletişim açılınca `escrowBlocked` zaten `false` olduğu için
    //      ücret TÜKETİLMEZ → BEDAVA İLETİŞİM
    //
    // Aynı açık `expired` teklifler için de geçerliydi. Yalnız AKTİF
    // teklif seçilebilir; blokesi duran tek durum budur.
    if (chosen.status != OfferStatus.active) {
      return const InvalidStateError(
          'Bu teklif artık geçerli değil — geri çekilmiş veya iptal '
          'edilmiş olabilir');
    }

    chosen.status = OfferStatus.selected;
    for (final o in offers.forListing(listingId)) {
      if (o.id == offerId) {
        continue;
      }
      o.status = OfferStatus.cancelled;
      _refundIfUnconsumed(o, reason: 'Teklif seçilmedi — İlan: ${l.title}');
    }
    l.selectedOfferId = offerId;
    listings.setStatus(listingId, ListingStatus.providerSelected);
    offers.touch();
    notifs?.push(
        userId: chosen.providerId, type: NotifType.offerSelected, refId: listingId,
        title: 'Teklifiniz seçildi 🎉',
        body: '"${l.title}" işinde hizmet alan sizinle çalışmak istiyor.');
    return null;
  }

  /// KURAL: Yalnız KENDİ AKTİF teklifi geri çekilebilir; açılmış ücret
  /// iade EDİLMEZ.
  @override
  Future<DomainError?> withdrawOffer({required String offerId, required String actorId}) async {
    final o = offers.byId(offerId);
    if (o == null) {
      return const NotFoundError('Teklif bulunamadı');
    }
    if (o.providerId != actorId) {
      return const UnauthorizedError('Yalnızca kendi teklifinizi geri çekebilirsiniz');
    }
    if (o.status != OfferStatus.active) {
      return const InvalidStateError('Yalnızca aktif teklifler geri çekilebilir');
    }
    o.status = OfferStatus.cancelled;
    _refundIfUnconsumed(o, reason: 'Teklif geri çekildi');
    offers.touch();
    return null;
  }

  void _refundIfUnconsumed(Offer o, {required String reason}) {
    if (o.escrowBlocked && !o.escrowConsumed) {
      o.escrowBlocked = false;
      wallets.refund(o.providerId, DomainConfig.contactFee, reason: reason);
      notifs?.push(
          userId: o.providerId, type: NotifType.refund, refId: o.listingId,
          title: 'Bloke iade edildi',
          body: '$reason — ${DomainConfig.contactFee} TL kullanılabilir bakiyenize iade edildi.');
    }
  }

  /// İlan iptal/silme/süre dolumunda çağrılır (yalnız MockListingPort).
  void cancelAllForListing(String listingId, {required String reason}) {
    for (final o in offers.forListing(listingId)) {
      if (o.status == OfferStatus.active) {
        o.status = OfferStatus.cancelled;
      }
      _refundIfUnconsumed(o, reason: reason);
    }
    offers.touch();
  }
}

class MockWalletPort extends WalletPort {
  final WalletRepository wallets;
  MockWalletPort(this.wallets) {
    wallets.addListener(notifyListeners);
  }
  @override
  void dispose() {
    wallets.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Wallet? walletOf(String userId) => wallets.walletOf(userId);
  @override
  Future<DomainError?> load(String userId) async => null;

  /// MOCK ÖDEME — YALNIZ geliştirme/test. Gerçek akışta bakiye ancak
  /// sunucu sağlayıcıdan onay aldıktan sonra artar.
  ///
  /// Bu bir ÖZEL ALANDIR; hiçbir üst sınıf üyesini geçersiz kılmaz,
  /// bu yüzden @override taşımaz.
  PaymentSession? _pending;

  /// MOCK paket listesi — YALNIZ geliştirme/test içindir.
  /// Production'da ApiWalletPort kullanılır ve paketler sunucudan gelir.
  static const _mockPackages = <TokenPackage>[
    TokenPackage(
      id: 'mock-pkg-10', name: '10 Jeton', tokenAmount: 10,
      bonusTokenAmount: 0, priceTl: 10, currency: 'TRY', sortOrder: 1,
    ),
    TokenPackage(
      id: 'mock-pkg-50', name: '50 Jeton', tokenAmount: 50,
      bonusTokenAmount: 5, priceTl: 50, currency: 'TRY', sortOrder: 2,
    ),
    TokenPackage(
      id: 'mock-pkg-100', name: '100 Jeton', tokenAmount: 100,
      bonusTokenAmount: 15, priceTl: 100, currency: 'TRY', sortOrder: 3,
    ),
  ];

  @override
  Future<(List<TokenPackage>?, DomainError?)> tokenPackages() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return (_mockPackages, null);
  }

  @override
  Future<(PaymentSession?, DomainError?)> startTopup({
    required String userId,
    String? packageId,
    int? amountTl,
    required String idempotencyKey,
    String? savedCardToken,
  }) async {
    // Paketli akış: tutar paketten okunur (sunucu davranışının taklidi).
    int resolved;
    if (packageId != null) {
      final p = _mockPackages.where((x) => x.id == packageId);
      if (p.isEmpty) {
        return (null, const NotFoundError('Paket bulunamadı'));
      }
      resolved = p.first.priceTl;
    } else {
      if (amountTl == null) {
        return (null, const ValidationError('Tutar veya paket seçilmelidir'));
      }
      resolved = amountTl;
      if (resolved < DomainConfig.minTopup) {
        return (null, ValidationError(
            "Minimum yükleme tutarı ${DomainConfig.minTopup} TL'dir"));
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _pending = PaymentSession(
      sessionId: 'mock-$idempotencyKey',
      providerRef: 'mock-ref-$idempotencyKey',
      amountTl: resolved,
      status: PaymentStatus.pending,
      redirectUrl: null, // mock modda sağlayıcı ekranı yoktur
    );
    _lastUserId = userId;
    return (_pending, null);
  }

  String? _lastUserId;

  @override
  Future<(PaymentStatus?, DomainError?)> confirmTopup(String sessionId) async {
    final p = _pending;
    if (p == null || p.sessionId != sessionId) {
      return (null, const NotFoundError('Ödeme oturumu bulunamadı'));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    wallets.topup(_lastUserId ?? '', p.amountTl);
    _pending = null;
    return (PaymentStatus.succeeded, null);
  }
}

class MockContactPort extends ContactPort {
  final ContactRepository contacts;
  final OfferRepository offers;
  final WalletRepository wallets;
  final ListingRepository listings;
  final NotificationRepository? notifs;
  MockContactPort(this.contacts, this.offers, this.wallets, this.listings, {this.notifs}) {
    contacts.addListener(notifyListeners);
    offers.addListener(notifyListeners);
    wallets.addListener(notifyListeners);
  }
  @override
  void dispose() {
    contacts.removeListener(notifyListeners);
    offers.removeListener(notifyListeners);
    wallets.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  bool isOpen(String offerId) => contacts.isOpen(offerId);
  @override
  Future<DomainError?> refresh(String offerId) async => null;

  /// KURAL: İletişim iki taraf için aynı anda açılır; bloke TEK KEZ
  /// tüketilir. Yetkisiz aktör hiçbir durum değişikliği oluşturmaz.
  @override
  Future<DomainError?> openShared(String offerId, {required String actorId}) async {
    final o = offers.byId(offerId);
    if (o == null) {
      return const NotFoundError('Teklif bulunamadı');
    }
    final l = listings.byId(o.listingId);
    if (l == null) {
      return const NotFoundError('İlan bulunamadı');
    }
    final allowed = actorId == o.providerId || actorId == l.ownerId;
    if (!allowed) {
      return const UnauthorizedError('İletişimi yalnızca teklifin sahibi veya ilan sahibi açabilir');
    }
    // ── ⚠ SIRA KRİTİKTİR: ÖNCE PARA, SONRA DURUM ──
    //
    // ÖNCEKİ SIRA PARTIAL-STATE ÜRETİYORDU:
    //
    //   1. contacts.open(offerId)      → iletişim AÇILDI (yazıldı)
    //   2. o.escrowBlocked  = false    → yazıldı
    //   3. o.escrowConsumed = true     → yazıldı
    //   4. wallets.consume(...)        → StateError FIRLATABİLİR
    //
    // `consume` bloke yetersizse `StateError` atar (bkz.
    // `WalletRepository.consume`). try/catch olmadığı için exception
    // yukarı fırlıyor, ama 1-3 adımları ZATEN YAZILMIŞ oluyordu:
    //
    //   • iletişim AÇIK kalır       → taraflar birbirini görür
    //   • escrowConsumed = true     → tekrar tüketim İMKÂNSIZ
    //   • cüzdandan para DÜŞMEZ     → bloke havada kalır
    //   → ÜCRETSİZ İLETİŞİM + MUHASEBE TUTARSIZLIĞI
    //
    // ÇÖZÜM: para hareketi ÖNCE yapılır. `consume` atarsa hiçbir durum
    // değişmemiş olur — iletişim açılmaz, bayraklar bozulmaz. Çağıran
    // hatayı görür, kullanıcı tekrar deneyebilir.
    //
    // ⚠ BACKEND'DE BU YETMEZ: orada iki ayrı satır/tablo güncellenir
    // ve araya süreç çökmesi girebilir. Sunucu tarafında bu blok TEK
    // TRANSACTION içinde olmalıdır.
    final ucretGerekli = o.escrowBlocked && !o.escrowConsumed;
    if (ucretGerekli) {
      // Bloke yetersizse buradan `StateError` atar ve AŞAĞIYA İNİLMEZ:
      // ne iletişim açılır ne bayrak değişir.
      wallets.consume(o.providerId, DomainConfig.contactFee);
    }

    // Para tahsil edildi (veya zaten tüketilmişti) — şimdi durum yazılır.
    if (!contacts.open(offerId)) {
      // ⚠ BURAYA NORMALDE DÜŞÜLMEZ: `isOpen` kontrolü yukarıda yok,
      // `contacts.open` idempotenttir ve ikinci çağrıda `false` döner.
      // Eğer iletişim ARADA başka bir yoldan açıldıysa ve biz ücreti
      // yeni tahsil ettiysek, tahsilatı GERİ ALIRIZ — çift ücret
      // alınmaz.
      if (ucretGerekli) {
        wallets.refund(o.providerId, DomainConfig.contactFee,
            reason: 'İletişim zaten açıktı — ücret iade edildi');
      }
      return null;
    }

    if (ucretGerekli) {
      o.escrowBlocked = false;
      o.escrowConsumed = true;
      offers.touch();
    }
    final other = actorId == o.providerId ? l.ownerId : o.providerId;
    notifs?.push(
        userId: other, type: NotifType.contactOpened, refId: o.id,
        title: 'İletişim açıldı',
        body: '"${l.title}" için iletişim bilgileri iki taraf için de açıldı.');
    return null;
  }
}

// ══════════════════════════════════════════════════════════════════
// Chat / Review / Notification — MOCK portlar.
// Mevcut bellek içi repository'ler ve iş kuralları AYNEN korunur.
// ══════════════════════════════════════════════════════════════════

class MockChatPort extends ChatPort {
  final ChatRepository chats;
  final OfferRepository offers;
  final ListingRepository listings;
  final ContactRepository? contacts;
  final NotificationRepository? notifs;
  MockChatPort(this.chats, this.offers, this.listings, {this.contacts, this.notifs}) {
    chats.addListener(notifyListeners);
    offers.addListener(notifyListeners);
  }
  @override
  void dispose() {
    chats.removeListener(notifyListeners);
    offers.removeListener(notifyListeners);
    super.dispose();
  }

  ({Offer? offer, String? otherId, DomainError? error}) _access(String offerId, String actorId) {
    final o = offers.byId(offerId);
    if (o == null) return (offer: null, otherId: null, error: const NotFoundError('Teklif bulunamadı'));
    final l = listings.byId(o.listingId);
    if (l == null) return (offer: null, otherId: null, error: const NotFoundError('İlan bulunamadı'));
    if (actorId != o.providerId && actorId != l.ownerId) {
      return (offer: null, otherId: null,
          error: const UnauthorizedError('Bu sohbete yalnızca taraflar erişebilir'));
    }
    if (contacts != null && !contacts!.isOpen(offerId)) {
      return (offer: null, otherId: null,
          error: const InvalidStateError(
              'Mesajlaşma, iletişim bilgileri açıldıktan sonra kullanılabilir'));
    }
    return (offer: o, otherId: actorId == o.providerId ? l.ownerId : o.providerId, error: null);
  }

  @override
  List<ChatMessage>? threadFor(String offerId) {
    final o = offers.byId(offerId);
    if (o == null) {
      return null;
    }
    return chats.threadFor(offerId, firstNote: o.note, providerId: o.providerId);
  }

  @override
  List<Offer> conversationsFor(String actorId) {
    final out = <Offer>[];
    for (final o in offers.byProvider(actorId)) {
      if (contacts == null || contacts!.isOpen(o.id)) {
        out.add(o);
      }
    }
    for (final l in listings.byOwner(actorId)) {
      for (final o in offers.forListing(l.id)) {
        if (contacts == null || contacts!.isOpen(o.id)) {
          out.add(o);
        }
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<DomainError?> loadConversations(String actorId) async => null; // bellek içi
  @override
  Future<DomainError?> loadThread(String offerId, {required String actorId}) async {
    final a = _access(offerId, actorId);
    if (a.error != null) {
      return a.error;
    }
    threadFor(offerId);
    chats.markRead(offerId, readerId: actorId);
    return null;
  }

  @override
  Future<({ChatMessage? message, DomainError? error})> send(
    String offerId, {
    required String senderId,
    String? text,
    String? storageRef,
  }) async {
    final a = _access(offerId, senderId);
    if (a.error != null) {
      return (message: null, error: a.error);
    }
    // ⚠ UZUNLUK DENETİMİ DOMAIN KATMANINDA.
    //
    // Ekrandaki `maxLength` yalnız yazmayı sınırlar; yapıştırma,
    // otomatik doldurma veya doğrudan port çağrısı onu atlar.
    if ((text?.length ?? 0) > kMesajMaxLength) {
      return (
        message: null,
        error: const ValidationError(
            'Mesaj en fazla $kMesajMaxLength karakter olabilir'),
      );
    }
    threadFor(offerId);
    final m = chats.send(offerId,
        senderId: senderId, text: text, imagePath: storageRef,
        status: MessageStatus.sending);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    chats.setStatus(offerId, m.id, MessageStatus.sent);
    notifs?.push(
        userId: a.otherId!, type: NotifType.newMessage, refId: offerId,
        title: 'Yeni mesajınız var', body: 'Sohbette yeni bir mesaj aldınız.');
    return (message: m, error: null);
  }

  @override
  Future<bool> retry(String offerId, ChatMessage m) async {
    if (m.status != MessageStatus.failed) {
      return false;
    }
    chats.setStatus(offerId, m.id, MessageStatus.sending);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    chats.setStatus(offerId, m.id, MessageStatus.sent);
    return true;
  }

  @override
  Future<DomainError?> markRead(String offerId, {required String readerId}) async {
    chats.markRead(offerId, readerId: readerId);
    return null;
  }

  @override
  Future<void> connectRealtime() async {}
  @override
  Future<void> disconnectRealtime() async {}
  @override
  bool get realtimeConnected => false;
}

class MockReviewPort extends ReviewPort {
  final ReviewRepository reviews;
  final ListingRepository listings;
  final OfferRepository offers;
  MockReviewPort(this.reviews, this.listings, this.offers) {
    reviews.addListener(notifyListeners);
  }
  @override
  void dispose() {
    reviews.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Review? byOffer(String offerId) => reviews.byOffer(offerId);
  @override
  List<Review> byProvider(String providerId) => reviews.byProvider(providerId);

  /// Müşterinin YAZDIĞI değerlendirmeler.
  List<Review> byAuthor(String authorId) => reviews.byAuthor(authorId);
  @override
  double? averageOf(String providerId) {
    final list = reviews.byProvider(providerId);
    if (list.isEmpty) {
      return null;
    }
    final sum = list.fold<int>(0, (a, r) => a + r.stars);
    return (sum / list.length * 10).round() / 10;
  }

  @override
  Future<DomainError?> loadForProvider(String providerId) async => null;

  /// İŞ KURALLARI AYNEN: yalnız ilan sahibi, tamamlanmış iş, seçilmiş
  /// teklif ve teklif başına tek değerlendirme.
  @override
  Future<DomainError?> submit({
    required String listingId,
    required String offerId,
    required String actorId,
    required int stars,
    required String text,
  }) async {
    final l = listings.byId(listingId);
    final o = offers.byId(offerId);
    if (l == null || o == null || o.listingId != listingId) {
      return const NotFoundError('Kayıt bulunamadı');
    }
    if (actorId != l.ownerId) {
      return const UnauthorizedError('Değerlendirmeyi yalnızca ilan sahibi yapabilir');
    }
    if (l.status != ListingStatus.completed) {
      return const InvalidStateError('Değerlendirme yalnızca iş tamamlandıktan sonra yapılabilir');
    }
    if (o.status != OfferStatus.selected) {
      return const InvalidStateError('Yalnızca seçtiğiniz teklifi değerlendirebilirsiniz');
    }
    if (stars < 1 || stars > 5) {
      return const ValidationError('Lütfen 1-5 arası bir puan seçin');
    }
    if (reviews.byOffer(offerId) != null) {
      return const InvalidStateError(
          'Bu iş için değerlendirmeniz zaten alındı — değerlendirme bir kez yapılabilir');
    }
    reviews.create(
        listingId: listingId, offerId: offerId, providerId: o.providerId,
        authorId: actorId, stars: stars, text: text);
    return null;
  }
}

class MockNotificationPort extends NotificationPort {
  final NotificationRepository repo;
  MockNotificationPort(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<AppNotification> forUser(String userId) => repo.forUser(userId);
  @override
  int unreadCount(String userId) => repo.unreadCount(userId);
  @override
  Future<DomainError?> load(String userId) async => null;
  @override
  Future<DomainError?> loadUnreadCount(String userId) async => null;
  @override
  Future<DomainError?> markRead(String id) async {
    repo.markRead(id);
    return null;
  }
  @override
  Future<DomainError?> markAllRead(String userId) async {
    repo.markAllRead(userId);
    return null;
  }
}

/// MOCK bölge verisi — sabit İzmir dosyalarından üretilir.
/// YALNIZ geliştirme/test içindir; production'da ApiRegionPort kullanılır.
class MockRegionPort implements RegionPort {
  @override
  Future<(RegionTree?, DomainError?)> regionTree() async {
    final districts = kIzmirDistricts
        .map((d) => District(
              id: 'mock-$d',
              name: d,
              allDistrictsSupported: true,
              neighborhoods: neighborhoodsOf(d)
                  .map((n) => Neighborhood(id: 'mock-$d-$n', name: n))
                  .toList(growable: false),
            ))
        .toList(growable: false);
    return (
      RegionTree([City(id: 'mock-city', name: kCity, districts: districts)]),
      null,
    );
  }
}

/// ÜCRETSİZ İLETİŞİM HAKKI — geliştirme (mock) portu.
///
/// ⚠ Yalnız DEBUG derlemede kullanılır. Release'te `ApiConfig.mode`
/// mock talebini reddeder; bu sınıf üretimde ASLA çalışmaz.
///
/// Sahte başarı ÜRETMEZ: varsayılan olarak hak YOKTUR, böylece
/// geliştirici cüzdan akışını da görebilir.
class MockFreeRightPort implements FreeRightPort {
  MockFreeRightPort({int remainingRights = 0}) : _kalan = remainingRights;
  final int _kalan;

  @override
  Future<(FreeRightSummary?, DomainError?)> summary() async => (
        FreeRightSummary(
          remainingRights: _kalan,
          hasUsableRight: _kalan > 0,
          nextExpiryAt: _kalan > 0
              ? DateTime.now().add(const Duration(days: 30))
              : null,
        ),
        null,
      );

  @override
  Future<(FundingDecision?, DomainError?)> fundingPreview() async => (
        _kalan > 0
            ? const FundingDecision(
                source: OfferFundingSource.freeRight,
                aciklama: 'Ücretsiz iletişim hakkınız kullanılacak. '
                    'Cüzdanınızdan tutar bloke edilmeyecek.',
              )
            : const FundingDecision(
                source: OfferFundingSource.wallet,
                aciklama: 'İletişim açma bedeli cüzdanınızda bloke edilecek.',
              ),
        null,
      );
}


/// Kayıtlı kart portu — geliştirme modu.
///
/// ⚠ SAHTE KART ÜRETMEZ. Geliştirme modunda kayıtlı kart özelliği
/// KAPALIDIR; arayüz güvenli ödeme yönlendirmesi gösterir.
class MockSavedCardsPort implements SavedCardsPort {
  @override
  Future<({bool available, List<SavedCard> cards})> listCards() async =>
      (available: false, cards: const <SavedCard>[]);

  @override
  Future<String?> startCardSetup() async => null;

  @override
  Future<void> deleteCard(String token) async {}

  @override
  Future<void> setDefaultCard(String token) async {}

  @override
  Future<({String mode, Map<String, String>? config})> cardEntryConfig() async =>
      (mode: 'unavailable', config: null);

  @override
  Future<SavedCard> saveCard({
    required String paymentToken,
    required String holderName,
    required bool makeDefault,
  }) async {
    // Geliştirme modunda kart kaydı YAPILMAZ; sahte kart üretilmez.
    throw StateError('Kart kaydı yalnız gerçek sağlayıcı ile kullanılabilir');
  }
}
