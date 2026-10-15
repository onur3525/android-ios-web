import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../domain/failures.dart';
import '../../models/account.dart';
import '../../models/provider_approval.dart';
import '../../models/listing.dart';
import '../../models/offer.dart';
import '../api/auth_api.dart';
import '../api/contact_api.dart';
import '../api/listing_api.dart';
import '../api/offer_api.dart';
import '../api/profile_api.dart';
import '../api/storage_api.dart';
import '../../../core/platform/yerel_gorsel.dart';
import '../../../core/boot.dart' show currentPlatform;
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
  void bildir() => notifyListeners();

  /// Bildirim tercihlerini sunucuya yazar. Hata dönerse çağıran yerel
  /// değeri geri alır (ekran sunucudan farklı bir durum göstermez).
  Future<DomainError?> bildirimTercihleriniKaydet(Map<String, bool> degisenler) async =>
      (await _guard(() => _profile.updateNotificationPrefs(degisenler))).$2;

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

  /// Profil + TEK adres. Adres ayrı uçtan gelir (GET /profiles/me/address);
  /// kayıt yoksa sunucu null döner ve hesabın adresi boş kalır.
  /// KARŞI TARAF ÖZETİ — `GET /users/{id}/summary`. Yetki ve görünürlük
  /// (tam ad, telefon) sunucuda belirlenir; ilişki yoksa hata döner.
  Future<(Account?, DomainError?)> kisiOzeti(String id) async {
    final (j, err) = await _guard(() => _profile.kisiOzeti(id));
    if (err != null || j == null) {
      return (null, err);
    }
    return (Mappers.kisiOzeti(j), null);
  }

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
    String? firebaseIdToken,
    required bool termsAccepted,
    required bool ageConfirmed,
  }) async {
    final (res, err) = await _guard(() => _auth.register(
          phone: phone, password: password, name: name,
          email: email, role: Mappers.roleApi(role), otpCode: otpCode,
          firebaseIdToken: firebaseIdToken,
          termsAccepted: termsAccepted,
          ageConfirmed: ageConfirmed,
          platform: currentPlatform(),
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

  /// Firebase ID token → HizmetCep oturumu (sunucu doğrular ve eşleştirir).
  Future<DomainError?> firebaseOturum(String idToken) async {
    final (res, err) = await _guard(() => _auth.firebaseSession(idToken));
    if (err != null) {
      return err;
    }
    await _client.tokens.save(
      access: res!['accessToken'] as String,
      refresh: res['refreshToken'] as String,
    );
    return loadMe();
  }

  Future<DomainError?> forgotCompleteFirebase(String phone, String idToken, String newPass) async =>
      (await _guard(() => _auth.forgotComplete(
              phone: phone, otpCode: '', newPassword: newPass, firebaseIdToken: idToken)))
          .$2;

  /// Telefon değişikliğinden sonra sunucunun verdiği kısa ömürlü Firebase
  /// özel belgesi (15 Eki): sunucu bütün Firebase oturumlarını iptal eder;
  /// bu cihaz `signInWithCustomToken` ile yeniden bağlanır. Okuyan temizler.
  String? firebaseOzelBelgesi;

  Future<DomainError?> changePhoneFirebase(String newPhone, String idToken,
      {String? mevcutSifre}) async {
    firebaseOzelBelgesi = null;
    final (res, err) = await _guard(() => _profile.changePhone(
        newPhone: newPhone, otpCode: '', firebaseIdToken: idToken,
        currentPassword: mevcutSifre));
    if (err != null) {
      return err;
    }
    final ozel = res!['firebaseCustomToken'];
    firebaseOzelBelgesi = ozel is String && ozel.isNotEmpty ? ozel : null;
    currentAccount = Mappers.account(res);
    notifyListeners();
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

  Future<DomainError?> addRole(Role role, String password, String firebaseIdToken) async {
    final err = (await _guard(() => _auth.addRole(
        role: Mappers.roleApi(role), password: password, firebaseIdToken: firebaseIdToken))).$2;
    return err ?? await loadMe();
  }

  Future<DomainError?> changePassword(String current, String next) async =>
      (await _guard(() => _auth.changePassword(current: current, next: next))).$2;

  /// `POST /auth/verify-password` — kritik işlem (hesap silme vb.) öncesi
  /// şifre doğrulaması. Sunucu, Firebase'e bağlı hesapta Firebase şifresini
  /// esas alır. Hata sessizce "doğru" sayılmaz.
  Future<DomainError?> verifyPassword(String password) async =>
      (await _guard(() => _auth.verifyPassword(password: password))).$2;

  Future<DomainError?> forgotComplete(String phone, String otp, String newPass) async =>
      (await _guard(() => _auth.forgotComplete(phone: phone, otpCode: otp, newPassword: newPass))).$2;

  Future<DomainError?> updateProfile({String? name, String? email}) async {
    final (res, err) =
        await _guard(() => _profile.updateProfile(name: name, email: email));
    if (err != null) {
      return err;
    }
    currentAccount = Mappers.account(res!);
    notifyListeners();
    return null;
  }

  /// ── PROFİL FOTOĞRAFI (API modu) ──
  ///
  /// Önceden yerel dosya yolu `photoRef` diye sunucuya gidiyor ve
  /// yok sayılıyordu: fotoğraf hiçbir zaman yüklenmiyordu. Akış artık:
  /// bayt + tür → `upload-ref` (`profile-photo`) → imzalı adrese yükle →
  /// `PATCH /profiles/me` {photoRef, photoRole} → sunucu doğrular →
  /// yanıttaki imzalı adresler hesaba yazılır. Yükleme yarıda kalırsa
  /// bekleyen referans atılır. [yol] boşsa fotoğraf KALDIRILIR.
  Future<DomainError?> profilFotografiniKaydet(String yol, Role rol) async {
    final rolKodu = rol == Role.provider ? 'PROVIDER' : 'CUSTOMER';
    String? ref;
    if (yol.isNotEmpty) {
      final veri = await _fotoVerisi(yol);
      if (veri == null) {
        return const ValidationError('Yalnızca JPG, PNG, WEBP ya da HEIC yüklenebilir.');
      }
      final depo = StorageApi(_client);
      final (yanit, hata) = await _guard(() => depo.createUploadRef(
          kind: 'profile-photo', contentType: veri.$2, sizeBytes: veri.$1.length));
      if (hata != null) {
        return hata;
      }
      ref = yanit!['storageRef'] as String?;
      final adres = yanit['uploadUrl'] as String?;
      if (ref == null || adres == null) {
        return const ValidationError('Fotoğraf yüklenemedi. Lütfen tekrar deneyin.');
      }
      try {
        await depo.uploadBytes(uploadUrl: adres, bytes: veri.$1, contentType: veri.$2);
      } catch (_) {
        final atilacak = ref;
        unawaited(depo.discardPending(atilacak).then((_) {}, onError: (_) {}));
        return const ValidationError('Fotoğraf yüklenemedi. Lütfen tekrar deneyin.');
      }
    }
    final (res, err) = await _guard(() => _profile.updatePhoto(ref, rolKodu));
    if (err != null) {
      return err;
    }
    currentAccount = Mappers.account(res!);
    notifyListeners();
    return null;
  }

  /// (bayt, içerik türü) — web'de `data:` adresi, mobilde dosya yolu.
  /// Tür çözülemezse null (yanlış `Content-Type` gönderilmez).
  static Future<(List<int>, String)?> _fotoVerisi(String yol) async {
    const turler = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'webp': 'image/webp', 'heic': 'image/heic',
    };
    if (yol.startsWith('data:')) {
      final virgul = yol.indexOf(',');
      if (virgul < 0) {
        return null;
      }
      final baslik = yol.substring(5, virgul);
      final tur = baslik.split(';').first.toLowerCase();
      if (!turler.values.contains(tur) || !baslik.contains('base64')) {
        return null;
      }
      return (base64Decode(yol.substring(virgul + 1)), tur);
    }
    final nokta = yol.lastIndexOf('.');
    final tur = nokta < 0 ? null : turler[yol.substring(nokta + 1).toLowerCase()];
    if (tur == null) {
      return null;
    }
    return (await yerelBaytlar(yol), tur);
  }

  /// E-POSTA DEĞİŞİM BAĞLANTISI İSTER.
  ///
  /// ⚠ YEREL HESAP GÜNCELLENMEZ. Değişiklik ancak kullanıcı
  /// bağlantıya tıklayınca sunucuda yürürlüğe girer; istemci burada
  Future<DomainError?> changeEmail(String newEmail) async =>
      (await _guard(() => _profile.changeEmail(newEmail: newEmail))).$2;

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
      // Web: sayfa yenilendi / sekme yeniden açıldı — bellekte token yok,
      // oturum HttpOnly çerezle sürdürülür (çıkış yapılmadıysa).
      if (!await _client.cerezleOturumuSurdur()) {
        return;
      }
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

  /// İlan sahibine gelen teklifler (sunucu `offers` alanını YALNIZ ilan
  /// sahibine gönderir, 15 Eki). Teklif deposuna aktarılır; hizmet alan
  /// gelen teklifleri ilan detayında ve İlanlarım'da böyle görür.
  /// `main()` bağlar: `ApiOfferRepository.ilanTeklifleriniAl`.
  void Function(String listingId, List<Offer> teklifler)? teklifleriAktar;

  void _teklifleriAyikla(Map<String, dynamic> j) {
    final ham = j['offers'];
    final aktar = teklifleriAktar;
    if (ham is! List || aktar == null) {
      return;
    }
    aktar(j['id'] as String,
        ham.map((e) => Mappers.offer(e as Map<String, dynamic>)).toList());
  }
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
    for (final e in rows) {
      _teklifleriAyikla(e as Map<String, dynamic>);
    }
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
    _teklifleriAyikla(res);
    notifyListeners();
    return null;
  }

  /// İlan detayı ile birlikte gelen teklifler (yalnız yetkili tarafa döner).
  List<Offer> lastDetailOffers = const [];

  Future<(Listing?, DomainError?)> create({
    required String title, required String location,
    required String description, List<String> photoRefs = const [],
    IsZamani? isZamani,
  }) async {
    final (res, err) = await _guard(() => _api.create(
        title: title, location: location, description: description,
        photoRefs: photoRefs, isZamani: isZamani));
    if (err != null) {
      return (null, err);
    }
    final l = Mappers.listing(res!);
    _cache.insert(0, l);
    notifyListeners();
    return (l, null);
  }

  Future<DomainError?> remove(String id, {String? reason}) async {
    final err = (await _guard(() => _api.remove(id, reason: reason))).$2;
    if (err != null) {
      return err;
    }
    _cache.removeWhere((l) => l.id == id);
    notifyListeners();
    return null;
  }
}

/// Teklifler.
///
/// ⚠ "teklif verme 50 TL bloke eder" KALDIRILDI (16 Eyl): uygulama
/// 29 Ağu'dan beri iki taraf için de ücretsizdir; teklif vermenin
/// finansal sonucu yoktur.
///
/// ⚠ `Idempotency-Key` ZORUNLULUĞU DURUYOR — gerekçesi değişti:
/// ücret değil, YİNELENME. Ağ kopmasında yeniden denenen POST aynı
/// ilana ikinci bir teklif oluşturmamalıdır.
class ApiOfferRepository extends ChangeNotifier {
  final OfferApi _api;
  ApiOfferRepository(this._api);

  final Map<String, Offer> _cache = {};

  /// `/offers/my`den gelen (hizmet verenin KENDİ) teklif kimlikleri:
  /// `loadMine` yalnız bunları yeniler, ilan sahibinin ilanlarından gelen
  /// teklifleri silmez.
  final Set<String> _benimkiler = {};
  Offer? byId(String id) => _cache[id];

  /// İlan sahibinin ilanına gelen teklifler (ilan detayı / İlanlarım).
  /// O ilanın önbellekteki teklifleri sunucunun güncel listesiyle değişir.
  void ilanTeklifleriniAl(String listingId, List<Offer> teklifler) {
    final yeni = {for (final o in teklifler) o.id: o};
    _cache.removeWhere((id, o) =>
        o.listingId == listingId && !yeni.containsKey(id) && !_benimkiler.contains(id));
    _cache.addAll(yeni);
    notifyListeners();
  }
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
    for (final id in _benimkiler) {
      _cache.remove(id);
    }
    _benimkiler.clear();
    for (final e in rows!) {
      final o = Mappers.offer(e as Map<String, dynamic>);
      _cache[o.id] = o;
      _benimkiler.add(o.id);
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
    _benimkiler.add(o.id);
    notifyListeners();
    return (o, null);
  }

  /// ⚠ NİHAİ UÇ İLANA AİTTİR: seçim, ilanın `selectedOffer` alanını
  /// yazar. Bu yüzden `listingId` de gerekir (OpenAPI:
  /// `PUT /listings/{listingId}/selected-offer`).
  ///
  /// ⚠ YANIT İLANDIR, TEKLİF DEĞİL (15 Eki): sunucu güncel ilanı döndürür;
  /// eskiden teklif gibi çözülmeye çalışılıyor ve tür hatası veriyordu.
  /// Teklif durumları (seçilen SELECTED, diğerleri CLOSED) ardından ilan
  /// detayının teklif listesiyle tazelenir (`OfferController.selectOffer`).
  Future<DomainError?> select(String listingId, String offerId) async {
    final (_, err) = await _guard(() => _api.select(listingId,
        offerId: offerId, idempotencyKey: ApiClient.newIdempotencyKey()));
    return err;
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
