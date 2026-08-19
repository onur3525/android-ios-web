import 'package:flutter/foundation.dart';

import '../../../domain/failures.dart';
import '../../models/account.dart';
import '../../models/payment.dart';
import '../../models/token_package.dart';
import '../../models/provider_approval.dart';
import '../../models/listing.dart';
import '../../models/offer.dart';
import '../../models/wallet.dart';
import '../api/auth_api.dart';
import '../api/contact_api.dart';
import '../api/listing_api.dart';
import '../api/offer_api.dart';
import '../api/profile_api.dart';
import '../api/wallet_api.dart';
import '../api_client.dart';
import '../api_error_mapper.dart';
import '../mappers.dart';

/// Sunucu çağrısını DomainError'a çeviren ortak sarmalayıcı.
/// İŞ KURALLARI SUNUCUDA yaşar; burada yalnız taşıma ve dönüşüm vardır.
Future<(T?, DomainError?)> _guard<T>(Future<T> Function() fn) async {
  try {
    return (await fn(), null);
  } on ApiFailure catch (e) {
    return (null, e.error);
  } catch (_) {
    return (null, const ValidationError('İşlem tamamlanamadı. Lütfen tekrar deneyin.'));
  }
}

/// Oturum + hesap. Mock AuthRepository ile AYNI iş kurallarını kullanır;
/// fark: doğrulama ve şifre işlemleri sunucuda yapılır.
class ApiAuthRepository extends ChangeNotifier {
  /// Dışarıdan haber vermek için — bildirim tercihleri gibi yalnız
  /// yerel önbelleği değiştiren işlemler bunu kullanır.
  void bildir() => notifyListeners();

  final AuthApi _auth;
  final ProfileApi _profile;
  final ApiClient _client;
  ApiAuthRepository(this._client, this._auth, this._profile);

  Account? currentAccount;
  bool get loggedIn => currentAccount != null;
  Role get activeRole => currentAccount?.activeRole ?? Role.customer;

  Future<DomainError?> login(String phone, String password) async {
    final (res, err) = await _guard(() => _auth.login(phone: phone, password: password));
    if (err != null) {
      return err;
    }
    await _client.tokens.save(
      access: res!['accessToken'] as String,
      refresh: res['refreshToken'] as String,
    );
    return loadMe();
  }

  /// GOOGLE İLE GİRİŞ — `idToken` sunucuda doğrulanır.
  /// İstemci e-posta/ad göndermez; sunucu Google'dan okur.
  Future<DomainError?> googleLogin(String idToken) async {
    final (res, err) = await _guard(() => _auth.googleLogin(idToken));
    if (err != null) {
      return err;
    }
    await _client.tokens.save(
      access: res!['accessToken'] as String,
      refresh: res['refreshToken'] as String,
    );
    return loadMe();
  }

  /// Profil + TEK adres. Adres ayrı uçtan gelir (GET /profiles/me/address);
  /// kayıt yoksa sunucu null döner ve hesabın adresi boş kalır.
  Future<DomainError?> loadMe() async {
    final (me, err) = await _guard(() => _profile.me());
    if (err != null) {
      return err;
    }
    final acc = Mappers.account(me!);
    final (addr, aerr) = await _guard(() => _profile.address());
    if (aerr == null && addr != null) {
      acc.address = Mappers.address(addr);
    }
    currentAccount = acc;
    notifyListeners();
    return null;
  }

  Future<DomainError?> register({
    required String phone, required String password, required String name,
    required String email, required Role role, required String otpCode,
  }) async {
    final (res, err) = await _guard(() => _auth.register(
          phone: phone, password: password, name: name,
          email: email, role: Mappers.roleApi(role), otpCode: otpCode,
        ));
    if (err != null) {
      return err;
    }
    final at = res!['accessToken'] as String?;
    final rt = res['refreshToken'] as String?;
    if (at != null && rt != null) {
      await _client.tokens.save(access: at, refresh: rt);
      return loadMe();
    }
    return null;
  }

  Future<DomainError?> requestOtp(String phone, String purpose) async =>
      (await _guard(() => _auth.requestOtp(phone: phone, purpose: purpose))).$2;

  Future<DomainError?> switchRole(Role role) async {
    final (res, err) = await _guard(() => _profile.setActiveRole(Mappers.roleApi(role)));
    if (err != null) {
      return err;
    }
    currentAccount = Mappers.account(res!);
    notifyListeners();
    return null;
  }

  Future<DomainError?> addRole(Role role, String password, String otpCode) async {
    final err = (await _guard(() =>
        _auth.addRole(role: Mappers.roleApi(role), password: password, otpCode: otpCode))).$2;
    return err ?? await loadMe();
  }

  Future<DomainError?> changePassword(String current, String next) async =>
      (await _guard(() => _auth.changePassword(current: current, next: next))).$2;

  /// ⚠ SUNUCU UCU HENÜZ YOK.
  ///
  /// `POST /auth/verify-password` sözleşmesi burada tanımlıdır;
  /// backend bu ucu açana kadar gerçek API modunda doğrulama
  /// BAŞARISIZ döner. Sessizce "doğru" saymak, kritik işlemi
  /// doğrulamasız yapmak demek olurdu.
  // ⚠ `@override` KALDIRILDI: `AuthPort` arayüzünde `verifyPassword`
  // TANIMLI DEĞİL; bu sınıfa özel bir uç. Yanlış işaret analyzer
  // uyarısı üretiyordu.
  Future<DomainError?> verifyPassword(String password) async =>
      (await _guard(() => _auth.verifyPassword(password: password))).$2;

  Future<DomainError?> forgotComplete(String phone, String otp, String newPass) async =>
      (await _guard(() => _auth.forgotComplete(phone: phone, otpCode: otp, newPassword: newPass))).$2;

  Future<DomainError?> updateProfile({String? name, String? email, String? photoRef}) async {
    final (res, err) =
        await _guard(() => _profile.updateProfile(name: name, email: email, photoRef: photoRef));
    if (err != null) {
      return err;
    }
    currentAccount = Mappers.account(res!);
    notifyListeners();
    return null;
  }

  Future<DomainError?> changePhone(String newPhone, String otpCode) async {
    final (res, err) = await _guard(() => _profile.changePhone(newPhone: newPhone, otpCode: otpCode));
    if (err != null) {
      return err;
    }
    currentAccount = Mappers.account(res!);
    notifyListeners();
    return null;
  }

  /// Hizmet veren platform onay durumu.
  /// Hata durumunda ONAYLI SAYILMAZ: güvenli varsayılan döner.
  Future<ProviderApprovalState> providerApproval() async {
    final (res, err) = await _guard(() => _profile.providerApproval());
    if (err != null || res == null) {
      return ProviderApprovalState.unknown;
    }
    return ProviderApprovalState.fromJson(res);
  }

  /// TEK ADRES — güncelleme (upsert). Ekleme/silme akışı YOKTUR.
  /// Sunucu kesin cevap verdikten sonra hesap yeniden okunur.
  Future<DomainError?> saveAddress({
    required String city,
    required String district,
    required String neighborhood,
  }) async {
    final err = (await _guard(() => _profile.saveAddress(
          city: city, district: district, neighborhood: neighborhood,
        ))).$2;
    return err ?? await loadMe();
  }

  Future<DomainError?> saveProviderProfile(Set<String> categories, Set<String> districts) async {    final err = (await _guard(() => _profile.saveProviderProfile(
        categories: categories.toList(), districts: districts.toList()))).$2;
    return err ?? await loadMe();
  }

  Future<void> logout() async {
    await _guard(() => _auth.logout());
    await _client.clearSession();
    currentAccount = null;
    notifyListeners();
  }

  /// Uygulama açılışında: saklı token varsa oturumu geri yükler.
  Future<void> restoreSession() async {
    if (await _client.tokens.accessToken() == null) {
      return;
    }
    await loadMe();
  }
}

/// İlanlar — 30 saat kuralı, durum makinesi ve iade kuralları SUNUCUDA.
class ApiListingRepository extends ChangeNotifier {
  final ListingApi _api;
  ApiListingRepository(this._api);

  final List<Listing> _cache = [];
  List<Listing> get all => List.unmodifiable(_cache);
  Listing? byId(String id) {
    for (final l in _cache) {
      if (l.id == id) {
        return l;
      }
    }
    return null;
  }

  void _merge(List<dynamic> rows) {
    _cache
      ..clear()
      ..addAll(rows.map((e) => Mappers.listing(e as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<DomainError?> loadMine() async {
    final (rows, err) = await _guard(() => _api.my());
    if (err != null) {
      return err;
    }
    _merge(rows!);
    return null;
  }

  Future<DomainError?> loadAvailable({String? category, String? district}) async {
    final (rows, err) = await _guard(() => _api.available(category: category, district: district));
    if (err != null) {
      return err;
    }
    _merge(rows!);
    return null;
  }

  /// Tek ilan — detay ekranı ve işlem sonrası tazeleme için.
  Future<DomainError?> loadOne(String id) async {
    final (res, err) = await _guard(() => _api.byId(id));
    if (err != null) {
      return err;
    }
    final l = Mappers.listing(res!);
    final i = _cache.indexWhere((e) => e.id == l.id);
    if (i >= 0) {
      _cache[i] = l;
    } else {
      _cache.add(l);
    }
    lastDetailOffers = ((res['offers'] ?? const []) as List)
        .map((e) => Mappers.offer(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
    return null;
  }

  /// İlan detayı ile birlikte gelen teklifler (yalnız yetkili tarafa döner).
  List<Offer> lastDetailOffers = const [];

  Future<(Listing?, DomainError?)> create({
    required String title, required String location,
    required String description, List<String> photoRefs = const [],
  }) async {
    final (res, err) = await _guard(() => _api.create(
        title: title, location: location, description: description, photoRefs: photoRefs));
    if (err != null) {
      return (null, err);
    }
    final l = Mappers.listing(res!);
    _cache.insert(0, l);
    notifyListeners();
    return (l, null);
  }

  // ⚠ `cancel` KALDIRILDI — tek kanonik silme `delete`tir
  // (`DELETE /listings/{id}`). Aynı iş için iki uç bırakılmaz.
  // ⚠ `start` / `complete` KALDIRILDI (§11, Paket 1 kalıntısı).

  Future<DomainError?> remove(String id, {String? reason}) async {
    final err = (await _guard(() => _api.remove(id, reason: reason))).$2;
    if (err != null) {
      return err;
    }
    _cache.removeWhere((l) => l.id == id);
    notifyListeners();
    return null;
  }

  Future<DomainError?> _mutate(Future<Map<String, dynamic>> Function() fn) async {
    final (res, err) = await _guard(fn);
    if (err != null) {
      return err;
    }
    final updated = Mappers.listing(res!);
    final i = _cache.indexWhere((l) => l.id == updated.id);
    if (i >= 0) {
      _cache[i] = updated;
    } else {
      _cache.add(updated);
    }
    notifyListeners();
    return null;
  }
}

/// Teklifler — teklif verme 50 TL bloke eder; TÜM finansal POST'lar
/// Idempotency-Key ile gönderilir.
class ApiOfferRepository extends ChangeNotifier {
  final OfferApi _api;
  ApiOfferRepository(this._api);

  final Map<String, Offer> _cache = {};
  Offer? byId(String id) => _cache[id];
  List<Offer> forListing(String listingId) =>
      _cache.values.where((o) => o.listingId == listingId).toList();
  List<Offer> byProvider(String providerId) =>
      _cache.values.where((o) => o.providerId == providerId).toList();

  /// İlanın teklifleri — mobil API'de ayrı uç yoktur; ilan detayındaki
  /// teklif listesi kullanılır (sunucu yetkiye göre süzer).
  Future<DomainError?> loadForListing(String listingId, {List<Offer>? fromDetail}) async {
    if (fromDetail != null) {
      for (final o in fromDetail) {
        _cache[o.id] = o;
      }
      notifyListeners();
      return null;
    }
    return loadMine();
  }

  Future<DomainError?> loadMine() async {
    final (rows, err) = await _guard(() => _api.my());
    if (err != null) {
      return err;
    }
    _cache.clear();
    for (final e in rows!) {
      final o = Mappers.offer(e as Map<String, dynamic>);
      _cache[o.id] = o;
    }
    notifyListeners();
    return null;
  }

  Future<(Offer?, DomainError?)> create({
    required String listingId, required int amountTl, required String note,
  }) async {
    final key = ApiClient.newIdempotencyKey();
    final (res, err) = await _guard(() =>
        _api.create(listingId: listingId, amountTl: amountTl, note: note, idempotencyKey: key));
    if (err != null) {
      return (null, err);
    }
    final o = Mappers.offer(res!);
    _cache[o.id] = o;
    notifyListeners();
    return (o, null);
  }

  /// ⚠ NİHAİ UÇ İLANA AİTTİR: seçim, ilanın `selectedOffer` alanını
  /// yazar. Bu yüzden `listingId` de gerekir (OpenAPI:
  /// `PUT /listings/{listingId}/selected-offer`).
  Future<DomainError?> select(String listingId, String offerId) =>
      _mutate(() => _api.select(listingId,
          offerId: offerId,
          idempotencyKey: ApiClient.newIdempotencyKey()));

  Future<DomainError?> _mutate(Future<Map<String, dynamic>> Function() fn) async {
    final (res, err) = await _guard(fn);
    if (err != null) {
      return err;
    }
    final o = Mappers.offer(res!);
    _cache[o.id] = o;
    notifyListeners();
    return null;
  }
}

/// Cüzdan — bakiye ve hareketler yalnız SUNUCUDAN okunur; istemci
/// hesaplama yapmaz.
class ApiWalletRepository extends ChangeNotifier {
  final WalletApi _api;
  ApiWalletRepository(this._api);

  Wallet? _wallet;
  Wallet? get wallet => _wallet;

  Future<DomainError?> load() async {
    final (w, err) = await _guard(() => _api.me());
    if (err != null) {
      return err;
    }
    final (rows, lerr) = await _guard(() => _api.ledger());
    if (lerr != null) {
      return lerr;
    }
    _wallet = Mappers.wallet(w!, rows!);
    notifyListeners();
    return null;
  }

  /// ADIM 1 — ödeme oturumu aç.
  /// KART BİLGİSİ GÖNDERİLMEZ. Idempotency-Key ZORUNLU: ağ tekrarında
  /// ikinci oturum açılmaz (sunucu aynı anahtarda mevcut oturumu döner).
  /// Satın alınabilir paketler. Geçersiz kayıtlar elenir.
  Future<(List<TokenPackage>?, DomainError?)> tokenPackages() async {
    final (res, err) = await _guard(() => _api.tokenPackages());
    if (err != null) {
      return (null, err);
    }
    return (TokenPackage.listFrom(res ?? const <dynamic>[]), null);
  }

  Future<(PaymentSession?, DomainError?)> createTopupSession({
    String? packageId,
    int? amountTl,
    required String idempotencyKey,
    String? returnUrl,
    String? savedCardToken,
  }) async {
    final (res, err) = await _guard(() => _api.createTopupSession(
          amountTl: amountTl,
          savedCardToken: savedCardToken,
          idempotencyKey: idempotencyKey,
          returnUrl: returnUrl,
        ));
    if (err != null) {
      return (null, err);
    }
    return (PaymentSession.fromJson(res!), null);
  }

  /// ADIM 2 — sonucu backend üzerinden doğrula. Başarılıysa cüzdan yenilenir.
  Future<(PaymentStatus?, DomainError?)> confirmTopup(String sessionId) async {
    final (res, err) = await _guard(() => _api.confirmTopup(sessionId: sessionId));
    if (err != null) {
      return (null, err);
    }
    final status = PaymentStatus.parse(res!['status'] as String?);
    if (status == PaymentStatus.succeeded) {
      await load();
    }
    return (status, null);
  }
}

/// İletişim — açma TEK TÜKETİMDİR; çift tıklamada ikinci ücret alınmaz.
class ApiContactRepository extends ChangeNotifier {
  final ContactApi _api;
  ApiContactRepository(this._api);

  final Set<String> _open = {};
  bool isOpen(String offerId) => _open.contains(offerId);

  Future<DomainError?> refresh(String offerId) async {
    final (res, err) = await _guard(() => _api.status(offerId));
    if (err != null) {
      return err;
    }
    if ((res!['open'] ?? res['contactOpenAt']) != null) {
      _open.add(offerId);
    }
    notifyListeners();
    return null;
  }

  Future<DomainError?> open(String offerId) async {
    final err = (await _guard(
        () => _api.open(offerId, idempotencyKey: ApiClient.newIdempotencyKey()))).$2;
    if (err != null) {
      return err;
    }
    _open.add(offerId);
    notifyListeners();
    return null;
  }
}
