import '../../domain/failures.dart';
import '../models/account.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Oturum ve hesap. Somut repository OLUŞTURMAZ — yalnız AuthPort'a bağlıdır.
class AuthController extends BaseController {
  final AuthPort _auth;
  AuthController(this._auth) : super([_auth]);

  bool get loggedIn => _auth.loggedIn;
  Account? get currentAccount => _auth.currentAccount;
  Role get activeRole => _auth.activeRole;
  Account? accountById(String id) => _auth.accountById(id);

  /// Bkz. `AuthPort.saglayicilarKimSunuyor`.
  List<Account> saglayicilarKimSunuyor(String kategori, String hizmet,
          {required String haricTutulacakId}) =>
      _auth.saglayicilarKimSunuyor(kategori, hizmet,
          haricTutulacakId: haricTutulacakId);

  /// Bildirim tercihleri — bkz. depo notu.
  void setNotificationPrefs({
    bool? teklif,
    bool? mesaj,
    bool? duyuru,
    bool? eposta,
  }) =>
      _auth.setNotificationPrefs(
          teklif: teklif, mesaj: mesaj, duyuru: duyuru, eposta: eposta);

  /// E-POSTA + ŞİFRE İLE GİRİŞ — mesaj döner, başarıda `null`.
  Future<String?> girisEposta(String email, String pass) async {
    final err =
        await runAction('girisEposta', () => _auth.girisEposta(email, pass));
    return err?.message;
  }

  /// TELEFON + ŞİFRE İLE GİRİŞ — mesaj döner, başarıda `null`.
  Future<String?> girisTelefonSifre(String phone, String pass) async {
    final err = await runAction(
        'girisTelefonSifre', () => _auth.girisTelefonSifre(phone, pass));
    return err?.message;
  }

  /// TELEFONLA GİRİŞ — kod isteği (nötr cevap).
  /// Başarıda `challengeId` döner; doğrulama onunla yapılır.
  Future<({String? challengeId, String? hata})> girisTelefonKodGonder(
      String phone) async {
    final r = await _auth.girisTelefonKodGonder(phone);
    return (challengeId: r.challengeId, hata: r.error?.message);
  }

  /// TELEFONLA GİRİŞ — kod doğrulama.
  ///
  /// ⚠ Hesap OLUŞTURMAZ; doğrulama use-case içinde yapılır.
  Future<String?> girisTelefonDogrula(String challengeId, String kod) async {
    final err = await runAction('girisTelefonDogrula',
        () => _auth.girisTelefonDogrula(challengeId, kod));
    return err?.message;
  }


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

    /// ⚠ OTP doğrulamasından üretilen kayıt yetkisi (Y1).
    String? kayitYetkisi,

    /// Kayıt denemesinin kimliği — yetkiyle eşleşmek zorundadır.
    String? taslakKimligi,
  }) async {
    if (isBusy('register')) {
      return (account: null, error: const ValidationError('Kayıt işlemi sürüyor — lütfen bekleyin'));
    }
    ({Account? account, DomainError? error}) result =
        (account: null, error: const ValidationError('Kayıt tamamlanamadı'));
    await runAction('register', () async {
      result = await _auth.register(
        phone: phone, pass: pass, role: role, otpVerified: otpVerified,
        otpCode: otpCode, name: name, email: email,
        categories: categories, serviceDistricts: serviceDistricts,
        termsAccepted: termsAccepted,
        emailVerified: emailVerified,
        kayitYetkisi: kayitYetkisi,
        taslakKimligi: taslakKimligi,
      );
      return result.error;
    });
    return result;
  }

  // ══════════════════════════════════════════════════════════════
  // TELEFON SAHİPLİĞİ — CHALLENGE / YETKİ
  //
  // ⚠ Ekranlar kodu kendileri doğrulamaz; bu metotları çağırır.
  // ══════════════════════════════════════════════════════════════

  Future<({String challengeId})> kayitKodGonder(String phone,
          {required String taslakKimligi}) =>
      _auth.kayitKodGonder(phone, taslakKimligi: taslakKimligi);

  /// Kodu doğrular; başarıda kayıt yetkisi döner. ⚠ Hesap açmaz.
  Future<({String? yetki, String? hata})> kayitDogrula(
      String challengeId, String kod) async {
    final r = await _auth.kayitDogrula(challengeId, kod);
    return (yetki: r.yetki, hata: r.error?.message);
  }

  Future<({String? challengeId, String? hata})> telefonDegisimiKodGonder(
      String yeniTelefon) async {
    final r = await _auth.telefonDegisimiKodGonder(yeniTelefon);
    return (challengeId: r.challengeId, hata: r.error?.message);
  }

  /// ⚠ Numara challenge'ın İÇİNDEN gelir; alan değeri geçilmez (Y4).
  Future<String?> telefonDegisimiDogrula(String challengeId, String kod) async {
    final err = await runAction('telefonDegisimi',
        () => _auth.telefonDegisimiDogrula(challengeId, kod));
    return err?.message;
  }

  Future<({String challengeId})> hesapKurtarmaKodGonder(String phone) =>
      _auth.hesapKurtarmaKodGonder(phone);

  /// ⚠ OTURUM AÇMAZ; yalnız telefon sahipliğini doğrular.
  Future<({String? yetki, String? hata})> hesapKurtarmaDogrula(
      String challengeId, String kod) async {
    final r = await _auth.hesapKurtarmaDogrula(challengeId, kod);
    return (yetki: r.yetki, hata: r.error?.message);
  }

  /// Kurtarma yetkisiyle yeni şifre. ⚠ Oturum açmaz.
  Future<String?> kurtarmaSifreBelirle(String yetki, String yeniSifre) async {
    final err = await runAction('kurtarmaSifre',
        () => _auth.kurtarmaSifreBelirle(yetki, yeniSifre));
    return err?.message;
  }

  Future<DomainError?> switchRole(Role role) =>
      runAction('switchRole', () => _auth.switchRole(role));

  /// Eksik rolü hesaba ekler ve aktif role geçer.
  Future<DomainError?> addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
  }) =>
      runAction(
          'addRole',
          () => _auth.addRole(role,
              categories: categories, serviceDistricts: serviceDistricts));

  Future<DomainError?> changePassword(String current, String next) =>
      runAction('changePassword', () => _auth.changePassword(current, next));

  /// Kritik işlem öncesi şifre doğrulaması (hesap silme).
  Future<DomainError?> verifyPassword(String password) =>
      runAction('verifyPassword', () => _auth.verifyPassword(password));

  /// E-posta ile şifre yenileme bağlantısı isteği (ana yol).
  ///
  /// Başarıda `null`; hata varsa kullanıcıya gösterilecek mesaj.
  Future<String?> sifreSifirlamaIste(String email) async {
    final err = await runAction(
        'sifreSifirlama', () => _auth.sifreSifirlamaIste(email));
    return err?.message;
  }

  Future<DomainError?> forgotStart(String phone) =>
      runAction('forgotStart', () => _auth.forgotStart(phone));

  Future<DomainError?> forgotComplete(String phone, String otp, String newPass) =>
      runAction('forgotComplete', () => _auth.forgotComplete(phone, otp, newPass));

  /// GİRİŞ KİLİDİNİN KALAN SÜRESİ (saniye); kilit yoksa 0.
  ///
  /// Ekran geri sayımı bunu saniyede bir sorar — bkz. `AuthPort`.
  int girisKilidiKalan(String phone) => _auth.girisKilidiKalan(phone);

  /// Telefon kayıtlı mı? `null` = bilinmiyor (sunucuda uç yok).
  bool? telefonKayitliMi(String phone) => _auth.telefonKayitliMi(phone);

  /// Uygulama açılışı: saklı oturum varsa profil ve aktif rol backend'den gelir.
  Future<void> restoreSession() => _auth.restoreSession();

  Future<void> logout() => _auth.logout();
}
