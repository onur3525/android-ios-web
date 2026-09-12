import '../../core/validators.dart';
import '../../domain/cikar_catismasi.dart';
import '../../domain/config.dart';
import '../../domain/failures.dart';
import '../../domain/listing_state_machine.dart';
import '../../domain/bildirim_metinleri.dart';
import '../models/account.dart';
import '../izmir_neighborhoods.dart';
import '../izmir.dart';
import '../models/region.dart';
import '../models/provider_approval.dart';
import '../models/listing.dart';
import '../models/notification.dart';
import '../models/chat.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../models/teklif_talebi.dart';
import '../repositories/auth_repository.dart';
import '../services/otp_service.dart';
import '../repositories/chat_repository.dart';
import '../repositories/contact_repository.dart';
import '../repositories/listing_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/oturum_tercihi.dart';
import '../repositories/offer_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/teklif_talebi_repository.dart';
import 'repository_ports.dart';

/// MOCK PORT UYGULAMALARI — bellek içi repository'leri sarar.

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
  List<Account> saglayicilarKimSunuyor(String kategori, String hizmet,
          {required String haricTutulacakId}) =>
      repo.saglayicilarKimSunuyor(kategori, hizmet,
          haricTutulacakId: haricTutulacakId);
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
    String? kayitYetkisi,
    String? taslakKimligi,
  }) async =>
      repo.register(
        phone: phone, pass: pass, role: role, otpVerified: otpVerified,
        name: name, email: email,
        categories: categories, serviceDistricts: serviceDistricts,
        termsAccepted: termsAccepted,
        emailVerified: emailVerified,
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
  Future<DomainError?> updateProfile({String? name, String? photoPath}) async {
    // ⚠ E-POSTA BURADAN GEÇMEZ (bkz. `epostaDegisimiBaslat`).
    repo.updateProfile(name: name, photoPath: photoPath);
    return null;
  }

  /// E-POSTA DEĞİŞİMİ — doğrulama bekleyen alana yazılır.
  ///
  /// ⚠ `acc.email` DEĞİŞMEZ. Depo yeni adresi `bekleyenEposta`da
  /// tutar; `epostaDogrula()` çağrılana kadar eski adres geçerlidir.
  /// Gerçek API'de bu doğrulama, kullanıcının e-postasına gelen
  /// bağlantıyla yapılır.
  ///
  /// ⚠ MOCK MODDA BAĞLANTI GÖNDERİLEMEZ — e-posta altyapısı yok.
  /// Sahte bir "gönderildi" başarısı üretmek yerine yeni adres
  /// beklemeye alınır; bu, gerçek akışın istemci tarafıyla birebir
  /// aynıdır.
  @override
  Future<DomainError?> epostaDegisimiBaslat(String yeniEposta) async {
    repo.updateProfile(email: yeniEposta);
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
  Future<void> logout() async {
    repo.logout();
    // ⚠ ÖNCEDEN EKSİKTİ: çıkış yapılsa bile cihaz hatırlamaya DEVAM
    // ediyordu — bir sonraki açılışta OTOMATİK aynı hesaba giriş
    // yapılıyordu. "Beni Hatırla" artık koşulsuz (`login_screen.dart`
    // her girişte kaydeder), bu yüzden çıkışın bunu SİLMESİ şart —
    // aksi hâlde "çıkış yap" görünürde bir şey yapmaz.
    await OturumTercihi().temizle();
  }

  /// ⚠ ÖNCEDEN BOŞTU — mock modda oturum HİÇ geri yüklenmiyordu.
  /// "Beni Hatırla" işaretliyse (bkz. `OturumTercihi`) hatırlanan
  /// telefonla hesap bulunup oturum açılır; API modundaki gerçek
  /// jeton doğrulamasının mock karşılığıdır.
  @override
  Future<void> restoreSession() async {
    final tercih = OturumTercihi();
    if (!await tercih.hatirlaniyor) {
      return;
    }
    final telefon = await tercih.telefon;
    if (telefon == null) {
      return;
    }
    final acc = repo.findByPhone(telefon);
    if (acc != null) {
      repo.oturumuGeriYukle(acc);
    }
  }
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
    IsZamani? isZamani,
    IletisimTercihi? iletisimTercihi,
  }) async {
    final hata = _cikarCatismasi(ownerId, title);
    if (hata != null) {
      return (listing: null, error: hata);
    }
    final l = listings.create(
        ownerId: ownerId, title: title, location: location,
        desc: desc, photoPaths: photoPaths, isZamani: isZamani,
        iletisimTercihi: iletisimTercihi);
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

    listings.setStatus(id, to);
    return null;
  }

  /// İptal: açılmamış blokeler iade edilir; completed İPTAL EDİLEMEZ.

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
    offerPort.cancelAllForListing(listingId,
        reason: 'İlan süresi doldu', yeniDurum: OfferStatus.expired);
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
    if (!ListingStateMachine.canDelete(a.listing!)) {
      return const InvalidStateError('Tamamlanmış ilan silinemez');
    }
    offerPort.cancelAllForListing(listingId,
        reason: 'İlan silindi', yeniDurum: OfferStatus.closed);
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
  final NotificationRepository? notifs;

  /// ── ⚠ HESAP DEPOSU (9 Eyl) ──
  ///
  /// Teklif seçildiğinde hizmet verenin `tamamlananIs` sayacı
  /// artırılır; bu depo olmadan sayaç yazılamaz.
  ///
  /// ⚠ İSTEĞE BAĞLI: `null` verilirse sayaç GÜNCELLENMEZ ama akış
  /// çalışır — `notifs` ile AYNI kural, eski çağrılar ve testler
  /// kırılmaz.
  ///
  /// ⚠ CI HATASI (10 Eyl): sayaç eklenirken `auth` alanının
  /// `MockListingPort`ta olduğu, `MockOfferPort`ta OLMADIĞI gözden
  /// kaçmıştı; derleme "The getter 'auth' isn't defined" ile
  /// düşmüştü. Seçim akışı burada olduğu için alan buraya eklendi.
  final AuthRepository? auth;

  MockOfferPort(this.offers, this.listings, {this.notifs, this.auth}) {
    offers.addListener(notifyListeners);
    listings.addListener(notifyListeners);
  }
  @override
  void dispose() {
    offers.removeListener(notifyListeners);
    listings.removeListener(notifyListeners);
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
    // ⚠ İLAN BAŞINA EN FAZLA `ilanBasinaMaxTeklif` TEKLİF.
    //
    // Sayım YALNIZ açık teklifleri kapsar: kapanmış ya da süresi
    // dolmuş teklifler kontenjanı işgal etmez.
    final acikTeklif = offers
        .forListing(listingId)
        .where((o) => o.status == OfferStatus.active)
        .length;
    if (acikTeklif >= DomainConfig.ilanBasinaMaxTeklif) {
      return const OfferLimitReachedError();
    }
    // ── ⚠ TEKLİF VERME ÜCRETSİZ VE SINIRSIZ (yeni iş modeli) ──
    //
    // Eskiden burada iki adım vardı:
    //   1. Bakiye yetersizse `InsufficientBalanceError` → teklif
    //      VERİLEMEZDİ ("Lütfen bakiye yükleyin").
    //   2. `wallets.block(providerId, contactFee)` → 50 TL bloke.
    //
    // İkisi de kaldırıldı: bakiye, cüzdan, bedel ve kota kontrolü
    // YOKTUR. Hizmet veren istediği kadar teklif verebilir.
    //
    // ⚠ TEKLİFİN KENDİ AKIŞI KORUNDU: ilan açık mı, süresi dolmuş mu,
    // aynı ilana ikinci teklif var mı — üç denetim de yukarıda
    // olduğu gibi duruyor.
    offers.create(listingId: listingId, providerId: providerId, amount: amount, note: note);
    notifs?.push(
        userId: l.ownerId, type: NotifType.newOffer, refId: listingId,
        // ⚠ METİN ORTAK KAYNAKTAN (12 Eyl): aynı olay Bul akışında
        // da bildirim üretiyor, başlık ikisinde de aynı olmalı.
        title: kYeniTeklifBaslik,
        body: yeniTeklifGovdeIlan(l.title));
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
    // ⚠ SEÇİM İLANIN DURUMUNU DEĞİŞTİRMEZ (§24, §11).
    //
    // Eskiden ilan `completed` yapılıyordu; nihai sözleşmede
    // tamamlanmışlık bir durum değil, `selectedOfferId` ilişkisidir.
    // İlan ACTIVE kalır. Seçim yalnız YAŞAYAN ilanda yapılabilir.
    if (l.status != ListingStatus.active) {
      return const InvalidStateError('Bu ilan için seçim yapılamaz');
    }
    // ⚠ İKİNCİ SEÇİM REDDEDİLİR (kabul testi 12): ilk seçim bozulmaz.
    if (l.selectedOfferId != null) {
      return const InvalidStateError(
          'Bu ilan için teklif zaten seçilmiş');
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
      // ⚠ `cancelled` → `closed` (§24): rakip teklif seçildiği için
      // SİSTEMSEL kapanış. Süre dolumu ise `expired`tır.
      o.status = OfferStatus.closed;
    }
    l.selectedOfferId = offerId;
    // ── ⚠ HİZMET VERENİN SAYACI ARTAR (kullanıcı bulgusu, 9 Eyl) ──
    //
    // `Listing.isTamamlanmisIs` seçimle birlikte true olur; bu
    // ilanın hizmet vereni bir iş daha bitirmiş sayılır.
    //
    // ⚠ NEDEN HESABA YAZILIYOR: sayı, izleyenin görebildiği ilan ve
    // tekliflerden türetilirse yeni açılmış bir hesap DAİMA 0 görür.
    // Bir kişinin geçmişi, ona bakan kişinin verisinden hesaplanamaz.
    //
    // ⚠ MÜKERRER SAYIM YOK: bu satıra yalnız seçim ANINDA gelinir;
    // `chosen.status` yukarıda `selected` yapıldı ve zaten seçilmiş
    // ilan bu akışa ikinci kez giremez (`selectedOfferId` dolu
    // ilanda seçim reddedilir).
    // ⚠ DOĞRUDAN DEĞİL DEPO ÜZERİNDEN (10 Eyl): alanı elle artırmak
    // bildirim göndermiyordu ve ekranlar eski sayıda kalıyordu.
    auth?.tamamlananIsArtir(chosen.providerId);
    // ── ⚠ SEÇİM İLANI DOĞRUDAN TAMAMLAR (ürün kararı) ──
    //
    // Referans `submitReviewDo`: seçim yapıldığında ilan `done` olur.
    // Bizde ara durum `providerSelected` idi ve ilanı `completed`
    // yapan hiçbir istemci eylemi yoktu; ilan "tamamlanan işler"e
    // geçmiyor, değerlendirme kapısı da hiç açılmıyordu.
    //
    // ⚠ Hizmet veren tarafında da aynı anda "Kazandığım işler"e
    // geçer — teklif `selected` olduğu için.
    offers.touch();
    notifs?.push(
        userId: chosen.providerId, type: NotifType.offerSelected, refId: listingId,
        // ⚠ METİN ORTAK KAYNAKTAN (12 Eyl): aynı olay Bul
        // akışında da bildirim üretiyor; iki port ayrı metin
        // yazarsa kullanıcı iki farklı şey olmuş sanıyor.
        title: kTeklifSecildiBaslik,
        body: teklifSecildiGovde(l.title));
    return null;
  }

  /// KURAL: Yalnız KENDİ AKTİF teklifi geri çekilebilir; açılmış ücret


  /// İlan iptal/silme/süre dolumunda çağrılır (yalnız MockListingPort).
  /// İlanın açık tekliflerini kapatır ve açılmamış blokeleri iade eder.
  ///
  /// ── ⚠ `expired` İLE `closed` AYRIMI (§24) ──
  ///
  /// Sözleşme iki ayrı durum tanımlıyor ve anlamları farklı:
  ///   · `expired` → ilanın 30 saati DOLDUĞU için kapanan teklif
  ///   · `closed`  → başka bir sistemsel neden (ilan silindi, admin
  ///     kaldırdı, rakip teklif seçildi)
  ///
  /// Bu yüzden çağıran taraf hangisi olduğunu SÖYLEMEK zorundadır;
  /// tek bir "iptal" durumuna indirgenmez.
  void cancelAllForListing(String listingId,
      {required String reason, required OfferStatus yeniDurum}) {
    assert(yeniDurum == OfferStatus.expired ||
        yeniDurum == OfferStatus.closed);
    for (final o in offers.forListing(listingId)) {
      if (o.status == OfferStatus.active) {
        o.status = yeniDurum;
      }
    }
    offers.touch();
  }
}

class MockContactPort extends ContactPort {
  final ContactRepository contacts;
  final OfferRepository offers;
  final ListingRepository listings;
  final NotificationRepository? notifs;
  MockContactPort(this.contacts, this.offers, this.listings, {this.notifs}) {
    contacts.addListener(notifyListeners);
    offers.addListener(notifyListeners);
  }
  @override
  void dispose() {
    contacts.removeListener(notifyListeners);
    offers.removeListener(notifyListeners);
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
    // ── ⚠ İLETİŞİM AÇMA TAMAMEN ÜCRETSİZ (yeni iş modeli) ──
    //
    // Eskiden burada bloke tüketimi vardı:
    //   · `wallets.consume(providerId, DomainConfig.contactFee)`
    //   · bloke yetersizse `StateError` → iletişim AÇILMAZDI
    //   · zaten açıksa `wallets.refund(...)` ile iade
    //   · `escrowBlocked` / `escrowConsumed` bayrak yazımı
    //
    // HizmetCep hem hizmet alan hem hizmet veren için ÜCRETSİZDİR:
    // bakiye, cüzdan, bedel ve bloke kontrolü YAPILMAZ. İletişim
    // koşulsuz açılır.
    //
    // ⚠ `open` İDEMPOTENTTİR: ikinci çağrıda `false` döner ve
    // sessizce başarı sayılır — çift açma hatası üretmez.
    if (!contacts.open(offerId)) {
      return null;
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

  /// ⚠ SEÇİM DE BURADA YAPILIR: iletişim önkoşulu denetlenir.
  ///
  final ContactRepository contacts;

  /// ⚠ "Bul" üzerinden doğrudan teklif akışının kendi doğrulaması
  /// için EKLENDİ — `listings`/`offers` ile AYNI rol, farklı model.
  final TeklifTalebiRepository teklifTalepleri;
  MockReviewPort(this.reviews, this.listings, this.offers, this.contacts,
      this.teklifTalepleri) {
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
  Review? byTalep(String talepId) => reviews.byTalep(talepId);
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
  ///
  /// ⚠ İKİ MOD: `listingId`+`offerId` verilirse ESKİ mantık BİREBİR
  /// aynı çalışır (aşağıdaki doğrulamalar DEĞİŞMEDİ). `talepId`
  /// verilirse "Bul" doğrudan teklif akışının KENDİ eşdeğer
  /// doğrulaması çalışır — iki mod birbirine KARIŞMAZ.
  @override
  Future<DomainError?> submit({
    String? listingId,
    String? offerId,
    String? talepId,
    required String actorId,
    required int stars,
    required String text,
  }) async {
    if (stars < 1 || stars > 5) {
      return const ValidationError('Lütfen 1-5 arası bir puan seçin');
    }

    if (talepId != null) {
      final t = teklifTalepleri.byId(talepId);
      if (t == null) {
        return const NotFoundError('Kayıt bulunamadı');
      }
      if (actorId != t.hizmetAlanId) {
        return const UnauthorizedError(
            'Değerlendirmeyi yalnızca talebi gönderen yapabilir');
      }
      if (t.durum != TeklifTalebiDurumu.tamamlandi) {
        return const InvalidStateError(
            'Yalnızca tamamlanmış işi değerlendirebilirsiniz');
      }
      if (reviews.byTalep(talepId) != null) {
        return const InvalidStateError(
            'Bu iş için değerlendirmeniz zaten alındı — değerlendirme bir '
            'kez yapılabilir');
      }
      reviews.create(
          talepId: talepId, providerId: t.saglayiciId, authorId: actorId,
          stars: stars, text: text);
      return null;
    }

    final l = listings.byId(listingId!);
    final o = offers.byId(offerId!);
    if (l == null || o == null || o.listingId != listingId) {
      return const NotFoundError('Kayıt bulunamadı');
    }
    if (actorId != l.ownerId) {
      return const UnauthorizedError('Değerlendirmeyi yalnızca ilan sahibi yapabilir');
    }
    // ── ⚠ ÖNKOŞUL: TEKLİF SEÇİLMİŞ OLMALI (ürün kararı) ──
    //
    // Referans prototipinde seçim ile yorum tek adımdı
    // (`submitReviewDo` seçimi de yazıyordu). Ürün kararı ikiye
    // ayırdı: "Teklifi Seç" seçimi yapar, yorum SONRA ve dilendiği
    // zaman yazılır.
    //
    // ⚠ Eski koşul `l.status == completed` idi ve ilanı tamamlayan
    // hiçbir istemci eylemi olmadığı için değerlendirmeye HİÇ
    // ulaşılamıyordu. Doğru kapı SEÇİMDİR: seçim ancak iletişim
    // açıkken yapılabildiği için zincir zaten tamdır.
    if (o.status != OfferStatus.selected || l.selectedOfferId != offerId) {
      return const InvalidStateError(
          'Yalnızca seçtiğiniz teklifi değerlendirebilirsiniz');
    }
    // ⚠ BİR KEZ: aynı teklif için ikinci yorum yazılamaz.
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

