import 'dart:async';
import '../../domain/failures.dart';
import '../remote/firebase_kimlik.dart';
import '../models/account.dart';
import '../remote/api/region_api.dart';
import '../models/region.dart';
import '../models/provider_approval.dart';
import '../models/chat.dart';
import '../models/listing.dart';
import '../models/teklif_talebi.dart' show IletisimTercihi;
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../remote/repositories/api_chat_repositories.dart';
import '../remote/repositories/api_repositories.dart';
import 'repository_ports.dart';
import '../remote/api_error_mapper.dart';

/// API PORT UYGULAMALARI — iş kuralları SUNUCUDA yürür; burada yalnız
/// çağrı, önbellek ve hata aktarımı vardır. İstemci tarafında sahte
/// başarı ÜRETİLMEZ: her işlem sunucunun kesin cevabını bekler.

class ApiAuthPort extends AuthPort {
  final ApiAuthRepository repo;
  ApiAuthPort(this.repo) {
    repo.addListener(_repoDegisti);
  }
  @override
  void dispose() {
    _kapandi = true;
    repo.removeListener(_repoDegisti);
    super.dispose();
  }

  bool _kapandi = false;

  /// Oturum sahibi değişince (çıkış / başka hesapla giriş) karşı taraf
  /// özetleri SİLİNİR: bir kullanıcının gördüğü telefon/ad bir sonrakine
  /// taşınmaz.
  String? _ozetSahibi;
  void _repoDegisti() {
    final id = repo.currentAccount?.id;
    if (id != _ozetSahibi) {
      _ozetSahibi = id;
      _ozetler.clear();
      _ozetIsteniyor.clear();
      _ozetHatasi.clear();
    }
    notifyListeners();
  }

  // ── KARŞI TARAF ÖZETLERİ (15 Eki) ──
  //
  // Ekranlar karşı tarafın adını, konumunu, fotoğrafını, iş sayısını ve
  // telefonunu `accountById` ile EŞZAMANLI okur. API modunda bu bilgi
  // sunucudan gelir: ilk okumada istek ARKA PLANDA başlatılır, yanıt
  // gelince dinleyiciler uyarılır ve ekranlar kendiliğinden yeniden
  // çizilir. Ekran kodu değişmez (tek kaynak).
  //
  // · Tazelik: özet [_ozetOmru] sonra okunursa arka planda yenilenir
  //   (iletişim açılınca telefonun görünmesi için); eski değer bu sırada
  //   gösterilir.
  // · Hata (ilişki yok, hız sınırı, ağ): [_hataBekleme] boyunca yeniden
  //   istenmez.
  // · Aynı kişi için aynı anda tek istek.
  static const _ozetOmru = Duration(seconds: 120);
  static const _hataBekleme = Duration(seconds: 60);
  final Map<String, ({Account hesap, DateTime zaman})> _ozetler = {};
  final Set<String> _ozetIsteniyor = {};
  final Map<String, DateTime> _ozetHatasi = {};

  void _ozetGerekirseIste(String id) {
    if (!repo.loggedIn || _ozetIsteniyor.contains(id)) {
      return;
    }
    final simdi = DateTime.now();
    final kayit = _ozetler[id];
    if (kayit != null && simdi.difference(kayit.zaman) < _ozetOmru) {
      return;
    }
    // ⚠ Hata sonrası (404, 429, ağ) eski kayıt olsa da beklenir: aksi
    // hâlde her yeniden çizimde istek tekrarlanırdı.
    final hata = _ozetHatasi[id];
    if (hata != null && simdi.difference(hata) < _hataBekleme) {
      return;
    }
    _ozetIsteniyor.add(id);
    // ⚠ Çizim (build) sırasında çağrılır: istek bir sonraki olay
    // döngüsünde başlar, dinleyiciler yalnız yanıt gelince uyarılır.
    unawaited(Future<void>(() => _ozetGetir(id)));
  }

  /// İLETİŞİM / TEKLİF DEĞİŞTİ — telefonu henüz görünmeyen özetler
  /// eskitilir; bir sonraki okumada sunucudan tazesi istenir (iletişim
  /// açılınca telefonun beklemeden görünmesi için). İstek burada
  /// BAŞLATILMAZ, dinleyiciler uyarılmaz. Son 10 sn'de alınmış özetler
  /// dokunulmaz (bildirim fırtınasında istek yağmuru olmasın).
  void karsiTarafOzetleriniEskit() {
    final esik = DateTime.now().subtract(const Duration(seconds: 10));
    final eski = DateTime.fromMillisecondsSinceEpoch(0);
    for (final e in _ozetler.entries.toList()) {
      if (e.value.hesap.phone.isEmpty && e.value.zaman.isBefore(esik)) {
        _ozetler[e.key] = (hesap: e.value.hesap, zaman: eski);
      }
    }
  }

  Future<void> _ozetGetir(String id) async {
    final sahip = _ozetSahibi;
    final (hesap, _) = await repo.kisiOzeti(id);
    _ozetIsteniyor.remove(id);
    if (_kapandi || sahip != _ozetSahibi) {
      return; // port kapandı ya da oturum değişti; yanıt artık geçersiz
    }
    if (hesap == null) {
      _ozetHatasi[id] = DateTime.now();
      return;
    }
    _ozetHatasi.remove(id);
    final onceki = _ozetler[id]?.hesap;
    _ozetler[id] = (hesap: hesap, zaman: DateTime.now());
    // ⚠ DEĞİŞMEYEN ÖZET (28 Eki, telefon performansı): özetler 2 dk'da bir
    // arka planda tazelenir. Bilgi aynıysa haber verilmez; aksi hâlde
    // oturum denetleyicisini izleyen BÜTÜN ekranlar boşuna yeniden çiziliyordu.
    if (onceki != null && _ozetImzasi(onceki) == _ozetImzasi(hesap)) {
      return;
    }
    notifyListeners();
  }

  /// Ekranda gösterilen özet alanları (kayıt tarihi değişmez, katılmaz).
  static String _ozetImzasi(Account a) => [
        a.name, a.phone, a.tamamlananIs, a.tamamlananIsHizmetAlan,
        a.address?.city, a.address?.district, a.address?.neighborhood,
        a.fotografi(Role.customer), a.fotografi(Role.provider),
      ].join('\u0000');

  @override
  Account? get currentAccount => repo.currentAccount;
  @override
  bool get loggedIn => repo.loggedIn;
  @override
  Role get activeRole => repo.activeRole;

  /// Oturum sahibi doğrudan; başka kullanıcılar karşı taraf özetinden
  /// (ilk okumada arka planda istenir, gelince ekran yenilenir).
  @override
  Account? accountById(String id) {
    if (id.isEmpty) {
      return null;
    }
    final ben = repo.currentAccount;
    if (ben?.id == id) {
      return ben;
    }
    _ozetGerekirseIste(id);
    return _ozetler[id]?.hesap;
  }

  /// API modunda "Bul" ekranı hizmet verenleri SUNUCUDAN, ASENKRON
  /// çeker (`SaglayiciApi.ara` → `GET /providers/search`; bkz.
  /// `sonuclar_screen`). Bu EŞZAMANLI yerel yol yalnız mock moda aittir;
  /// API modunda yerelde başka hesap tutulmadığı için boş döner.
  @override
  List<Account> saglayicilarKimSunuyor(String kategori, String hizmet,
          {required String haricTutulacakId}) =>
      const [];

  /// Tercih SUNUCUYA yazılır (`PATCH /profiles/me/notifications`); push
  /// gönderimi sunucuda bu tercihe uyar. Ekran anında güncellenir
  /// (iyimser); sunucu reddederse eski değer GERİ ALINIR. İmza ve ekran
  /// davranışı mock moduyla aynıdır.
  @override
  void setNotificationPrefs(
      {bool? teklif, bool? mesaj, bool? duyuru, bool? eposta}) {
    final acc = repo.currentAccount;
    if (acc == null) {
      return;
    }
    final once = (acc.bildirimTeklif, acc.bildirimMesaj, acc.bildirimDuyuru,
        acc.bildirimEposta);
    final degisenler = <String, bool>{};
    if (teklif != null) {
      acc.bildirimTeklif = teklif;
      degisenler['offer'] = teklif;
    }
    if (mesaj != null) {
      acc.bildirimMesaj = mesaj;
      degisenler['message'] = mesaj;
    }
    if (duyuru != null) {
      acc.bildirimDuyuru = duyuru;
      degisenler['announcement'] = duyuru;
    }
    if (eposta != null) {
      acc.bildirimEposta = eposta;
      degisenler['email'] = eposta;
    }
    repo.bildir();
    if (degisenler.isEmpty) {
      return;
    }
    unawaited(repo.bildirimTercihleriniKaydet(degisenler).then((hata) {
      if (hata == null || !identical(repo.currentAccount, acc)) {
        return;
      }
      acc.bildirimTeklif = once.$1;
      acc.bildirimMesaj = once.$2;
      acc.bildirimDuyuru = once.$3;
      acc.bildirimEposta = once.$4;
      repo.bildir();
    }));
  }

  // ═══ FIREBASE AUTHENTICATION (kalıcı üretim yolu) ═══
  // Firebase kimliği doğrular; backend ID token'ı doğrulayıp KENDİ
  // oturumunu verir (hesap/rol/iş verisi backend'de). Mock mod aynen.

  @override
  Future<DomainError?> girisEposta(String email, String pass) async {
    final r = await FirebaseKimlik.i.epostaSifreGiris(email, pass);
    if (r.error != null) {
      return r.error;
    }
    return repo.firebaseOturum(r.idToken!);
  }

  /// Telefon + şifre: backend doğrular (Firebase'e bağlı hesapta şifreyi
  /// sunucu Firebase'e doğrulatır).
  @override
  Future<DomainError?> girisTelefonSifre(String phone, String pass) =>
      repo.login(phone, pass);

  @override
  Future<({String? challengeId, DomainError? error})> girisTelefonKodGonder(
      String phone) async {
    final r = await FirebaseKimlik.i.kodGonder(phone);
    return (challengeId: r.id, error: r.error);
  }

  @override
  Future<DomainError?> girisTelefonDogrula(String challengeId, String kod) async {
    final r = await FirebaseKimlik.i.kodDogrula(challengeId, kod);
    if (r.error != null) {
      return r.error;
    }
    return repo.firebaseOturum(r.idToken!);
  }

  /// Kayıt: SMS kodu Firebase'den. Gönderim hatası doğrulama adımında
  /// gösterilir (imza değişmez: ekran aynı akışı izler).
  @override
  Future<({String challengeId})> kayitKodGonder(String phone,
      {required String taslakKimligi}) async {
    final r = await FirebaseKimlik.i.kodGonder(phone);
    return (challengeId: r.id ?? '');
  }

  /// Doğrulanan kodun kanıtı (Firebase ID token) "yetki" olarak döner ve
  /// `register(kayitYetkisi: ...)` ile sunucuya gider.
  @override
  Future<({String? yetki, DomainError? error})> kayitDogrula(
      String challengeId, String kod) async {
    final r = await FirebaseKimlik.i.kodDogrula(challengeId, kod);
    return (yetki: r.idToken, error: r.error);
  }

  @override
  Future<({String? challengeId, DomainError? error})> telefonDegisimiKodGonder(
      String yeniTelefon) async {
    final r = await FirebaseKimlik.i.kodGonder(yeniTelefon);
    return (challengeId: r.id, error: r.error);
  }

  @override
  Future<DomainError?> telefonDegisimiDogrula(String challengeId, String kod,
      {String? mevcutSifre}) async {
    final r = await FirebaseKimlik.i.kodDogrula(challengeId, kod, mevcutKullanici: true);
    final tel = r.idToken == null ? null : FirebaseKimlik.i.tokenTelefonu(r.idToken!);
    if (r.error != null || tel == null) {
      return r.error ?? const ValidationError('Doğrulama tamamlanamadı');
    }
    final err = await repo.changePhoneFirebase(tel, r.idToken!, mevcutSifre: mevcutSifre);
    // ⚠ Sunucu bütün Firebase oturumlarını iptal etti (bu cihazınki dahil):
    // verilen özel belgeyle bu cihaz yeniden bağlanır (15 Eki).
    final ozel = repo.firebaseOzelBelgesi;
    repo.firebaseOzelBelgesi = null;
    if (err == null && ozel != null) {
      await FirebaseKimlik.i.ozelBelgeyleBaglan(ozel);
    }
    return err;
  }

  @override
  Future<({String challengeId})> hesapKurtarmaKodGonder(String phone) async {
    final r = await FirebaseKimlik.i.kodGonder(phone);
    return (challengeId: r.id ?? '');
  }

  @override
  Future<({String? yetki, DomainError? error})> hesapKurtarmaDogrula(
      String challengeId, String kod) async {
    final r = await FirebaseKimlik.i.kodDogrula(challengeId, kod);
    return (yetki: r.idToken, error: r.error);
  }

  /// Telefonla kurtarma: sunucudaki şifre ve (varsa) Firebase şifresi
  /// birlikte güncellenir; iki kaynak ayrışmaz.
  @override
  Future<DomainError?> kurtarmaSifreBelirle(String yetki, String yeniSifre) async {
    final tel = FirebaseKimlik.i.tokenTelefonu(yetki);
    if (tel == null) {
      return const ValidationError('Doğrulamanın süresi doldu. Yeni kod isteyin.');
    }
    final err = await repo.forgotCompleteFirebase(tel, yetki, yeniSifre);
    if (err == null) {
      await FirebaseKimlik.i.sifreGuncelle(yeniSifre);
    }
    return err;
  }

  // (Eski "uç yok" metni kaldırıldı: uçlar Firebase Authentication ile tamamlandı.)

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
    // ⚠ Sözleşme onayı SUNUCUDA da doğrulanır (15 Eki;
    // önceden sunucu onayı denetlemiyordu). Buradaki erken çıkış
    // kullanıcıya hızlı geri bildirim içindir.
    if (!termsAccepted) {
      return (
        account: null,
        error: const ValidationError(
            'Kullanım Sözleşmesi onayı zorunludur'),
      );
    }
    // otpVerified mock akışının kalıntısıdır; sunucu OTP kodunu kendi doğrular.
    final err = await repo.register(
        phone: phone, password: pass, name: name,
        email: email, role: role, otpCode: otpCode,
        // Firebase telefon doğrulamasının kanıtı (kayitDogrula'dan).
        firebaseIdToken: kayitYetkisi,
        termsAccepted: termsAccepted);
    if (err != null) {
      return (account: null, error: err);
    }
    // E-posta/şifre Firebase kullanıcısına bağlanır ve DOĞRULAMA E-POSTASI
    // gider. Başarısızlık kaydı geri almaz (doğrulama sonradan yapılabilir).
    if (kayitYetkisi != null && email.isNotEmpty) {
      await FirebaseKimlik.i.epostaBaglaVeDogrulamaGonder(email, pass);
    }
    if (categories.isNotEmpty || serviceDistricts.isNotEmpty) {
      // ⚠ HATA YUTULMAZ (15 Eki): hesap açıldı ama hizmet kategorileri /
      // ilçeleri sunucuda reddedildiyse hizmet veren hiçbir ilan
      // eşleşmesinde görünmezdi ve bunu bilmezdi. Kısmi başarı: hesap
      // DÖNER, hata da döner — ekran kaydı geri almaz, kullanıcıyı uyarır.
      final profilHatasi =
          await repo.saveProviderProfile(categories, serviceDistricts);
      if (profilHatasi != null) {
        return (
          account: repo.currentAccount,
          error: ValidationError(
              'Hesabınız açıldı ancak hizmet kategorileri ve ilçeleri '
              'kaydedilemedi (${profilHatasi.message}). Profilinizden '
              'yeniden kaydedin.'),
        );
      }
    }
    return (account: repo.currentAccount, error: null);
  }

  /// ⚠ `switchRole` GERİ EKLENDİ.
  ///
  /// Generic `requestOtp` silinirken bu override yanlışlıkla aynı
  /// kesitte gitmişti ve `ApiAuthPort` arayüzü tamamlamıyordu
  /// (analyzer: non_abstract_class_inherits_abstract_member).
  ///
  /// Sunucu ucu VAR: aktif rol değişimi profil ucundan yapılır.
  @override
  Future<DomainError?> switchRole(Role role) => repo.switchRole(role);

  /// ROL EKLEME — sunucu şifre ve YENİ telefon doğrulaması ister.
  ///
  /// Kod hesabın KAYITLI telefonuna Firebase ile gönderilir; dönen ID
  /// token sunucuya kanıt olarak gider. Sunucu kanıtın telefonla, bu
  /// oturum açıldıktan sonra ve yakın zamanda alındığını denetler.
  @override
  bool get rolEklemeDogrulamaIster => true;

  @override
  Future<({String? challengeId, DomainError? error})> rolEklemeKodGonder() async {
    final tel = repo.currentAccount?.phone ?? '';
    if (tel.isEmpty) {
      return (challengeId: null, error: const ValidationError('Hesapta kayıtlı telefon yok'));
    }
    final r = await FirebaseKimlik.i.kodGonder(tel);
    return (challengeId: r.id, error: r.error);
  }

  @override
  Future<({String? kanit, DomainError? error})> rolEklemeKodDogrula(
      String challengeId, String kod) async {
    final r = await FirebaseKimlik.i.kodDogrula(challengeId, kod);
    return (kanit: r.idToken, error: r.error);
  }

  @override
  Future<DomainError?> addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
    String? sifre,
    String? telefonKaniti,
  }) async {
    // 21 Eki (kullanıcı kararı): telefon/SMS doğrulaması istenmez; yalnız şifre.
    if (sifre == null || sifre.isEmpty) {
      return const ValidationError('Rol eklemek için şifrenizi girin.');
    }
    final hata = await repo.addRole(role, sifre);
    if (hata != null) {
      return hata;
    }
    // Hizmet veren bilgileri rol eklendikten SONRA yazılır (kayıt
    // akışıyla aynı sıra: sunucu profil ucu rolü arar).
    if (role == Role.provider && categories != null && serviceDistricts != null) {
      final profilHatasi =
          await repo.saveProviderProfile(categories, serviceDistricts);
      if (profilHatasi != null) {
        return ValidationError(
            'Hizmet veren rolü eklendi ancak hizmet kategorileri ve ilçeleri '
            'kaydedilemedi (${profilHatasi.message}). Profilinizden '
            'yeniden kaydedin.');
      }
    }
    return null;
  }
  @override
  Future<DomainError?> changePassword(String current, String next) async {
    final err = await repo.changePassword(current, next);
    // ⚠ Şifre değişince Firebase bütün oturumları (bu cihazınki dahil) iptal
    // eder; bu cihaz YENİ şifreyle yeniden bağlanır, eski oturumlar
    // açılamaz (15 Eki). Firebase oturumu yoksa bir şey yapılmaz.
    if (err == null) {
      await FirebaseKimlik.i.yeniSifreyleYenidenBaglan(next);
    }
    return err;
  }

  @override
  Future<DomainError?> verifyPassword(String password) =>
      repo.verifyPassword(password);

  /// Sunucuda ayrı bir "başlat" ucu yoktur: OTP isteği bu akışı başlatır.
  @override
  /// E-postayla şifre sıfırlama: Firebase'in sıfırlama şablonu.
  Future<DomainError?> sifreSifirlamaIste(String email) =>
      FirebaseKimlik.i.sifreSifirlamaEpostasi(email);

  @override
  Future<DomainError?> forgotStart(String phone) => repo.requestOtp(phone, 'FORGOT');
  @override
  Future<DomainError?> forgotComplete(String phone, String otp, String newPass) =>
      repo.forgotComplete(phone, otp, newPass);

  @override
  Future<DomainError?> updateProfile({String? name, String? photoPath}) async {
    // ⚠ E-posta GÖNDERİLMEZ: doğrulamayı atlatmak olurdu.
    if (name != null) {
      final hata = await repo.updateProfile(name: name);
      if (hata != null || photoPath == null) {
        return hata;
      }
    }
    if (photoPath == null) {
      return null;
    }
    // Fotoğraf AKTİF ROLE yazılır (Account.photoPath ile aynı kural):
    // yerel yol sunucuya YÜKLENİR, yalnız referansı kaydedilir.
    final acc = repo.currentAccount;
    if (acc == null) {
      return const ValidationError('Oturum bulunamadı.');
    }
    return repo.profilFotografiniKaydet(photoPath, acc.activeRole);
  }

  /// ── ⚠ E-POSTA DOĞRULAMA VE DEĞİŞİKLİĞİ YALNIZ SUNUCUDAN (21 Eki, güvenlik) ──
  ///
  /// Bağlantıyı Firebase üretir, e-postayı sunucu gönderir. İstemci Firebase
  /// oturumuna ihtiyaç DUYMAZ: önceki "Firebase oturum köprüsü"
  /// (`/auth/firebase/baglanti`) kaldırıldı (Y1) — erişim belgesini Firebase'de
  /// şifre/e-posta değiştirebilen bir oturuma yükseltiyordu. Sunucuda e-posta
  /// kanalı yoksa Firebase'e düşülmez; açık hata gösterilir.
  static const _kanalYok = ValidationError(
      'E-posta gönderimi şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.');

  @override
  /// Yeni adrese "doğrula ve değiştir" bağlantısı. ⚠ Y2: mevcut şifre
  /// sunucuda doğrulanır; adres yalnız bağlantı tıklanınca değişir.
  Future<DomainError?> epostaDegisimiBaslat(String yeniEposta,
      {required String sifre}) async {
    final (gonderildi, err) = await repo.kurumsalEpostaGonder(
        yeniEposta: yeniEposta, mevcutSifre: sifre);
    if (err != null) {
      return err;
    }
    return gonderildi ? null : _kanalYok;
  }

  @override
  Future<void> epostaOnayiniEsitle() => repo.epostaOnayiniEsitle();

  @override
  Future<DomainError?> mevcutEpostaDogrulamaGonder(String mevcutEposta) async {
    final (gonderildi, err) = await repo.kurumsalEpostaGonder();
    if (err != null) {
      return err;
    }
    return gonderildi ? null : _kanalYok;
  }

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
  Future<void> logout() async {
    await repo.logout();
    await FirebaseKimlik.i.cikis();
  }
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
    // 16 Eki: sunucuya iletilir (backend 022: listings.iletisim_tercihi).
    IletisimTercihi? iletisimTercihi,
  }) async {
    final (l, err) = await repo.create(
        title: title, location: location, description: desc,
        photoRefs: photoPaths ?? const [], isZamani: isZamani,
        iletisimTercihi: iletisimTercihi ?? IletisimTercihi.telefonGoster);
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
  int okunmamisMesaj(String offerId, String benimId) => repo.okunmamis(offerId, benimId);

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
  /// "Bul" teklif talebi değerlendirmesi — sunucudaki talep görünümünden
  /// (`degerlendirme`) ya da bu oturumda gönderilenden okunur.
  @override
  Review? byTalep(String talepId) => repo.byTalep(talepId);
  @override
  List<Review> byProvider(String providerId) => repo.byProvider(providerId);
  @override
  List<Review> byAuthor(String authorId) => repo.byAuthor(authorId);
  @override
  double? averageOf(String providerId) => repo.averageOf(providerId);
  @override
  Future<DomainError?> loadForProvider(String providerId) => repo.loadForProvider(providerId);

  /// Kural denetimi SUNUCUDA; hizmet veren, seçilmiş tekliften çözülür.
  /// `talepId` ile: "Bul" teklif talebi değerlendirmesi
  /// (`POST /teklif-talepleri/{id}/review`).
  @override
  Future<DomainError?> submit({
    String? listingId,
    String? offerId,
    String? talepId,
    required String actorId,
    required int stars,
    required String text,
  }) async {
    if (talepId != null) {
      return repo.submitTalep(talepId: talepId, stars: stars, text: text);
    }
    final providerId = offers.byId(offerId!)?.providerId;
    if (providerId == null) {
      return const NotFoundError('Teklif bulunamadı');
    }
    return repo.submit(
        listingId: listingId!, providerId: providerId, stars: stars, text: text);
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
  @override
  Future<DomainError?> sayfaGoruldu(String sayfa, String refId) =>
      repo.sayfaGoruldu(sayfa, refId);
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

