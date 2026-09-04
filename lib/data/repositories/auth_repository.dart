import 'package:flutter/foundation.dart';
import '../../core/validators.dart';
import 'dart:async';
import '../../domain/otp_challenge.dart';
import '../services/otp_service.dart';
import '../../core/eposta_oneri.dart';
import '../../domain/form_mesajlari.dart';
import 'package:uuid/uuid.dart';
import '../../domain/failures.dart';
import '../../domain/password_hasher.dart';
import '../models/account.dart';
import 'demo_hesap_ozetleri.dart';

/// Hesap defteri + oturum. Backend geldiğinde API'si korunarak
class AuthRepository extends ChangeNotifier {
  final _uuid = const Uuid();

  final List<Account> accounts = [];
  Account? currentAccount;

  /// [seedTestAccount] yalnız debug/test ortamında true olmalıdır;
  /// release derlemede test hesabı OLUŞMAZ.
  /// ⚠ DOĞRULAMANIN AUTHORITATIVE NOKTASI BURASIDIR.
  ///
  /// Kodu ekran değil bu servis doğrular. Mock modda
  /// `MockOtpService` (debug'da sabit kod), API modunda sunucu ucu.
  final OtpService _otp;

  /// Üretilmiş challenge'lar — kimlikle saklanır.
  final Map<String, OtpChallenge> _challenges = {};

  /// Challenge ömrü. ⚠ Sunucu da kendi süresini uygular.
  static const _kChallengeOmru = Duration(minutes: 3);

  /// Doğrulama sonrası verilen kısa ömürlü yetkilerin ömrü.
  ///
  /// ⚠ OTP'nin kendisi bir yetki DEĞİLDİR: doğrulama başarılı
  /// olduğunda ayrı, süreli ve tek kullanımlık bir yetki üretilir.
  ///
  /// ⚠ Kurucudan verilebilir — süre dolumu DAVRANIŞI test edilebilsin
  /// diye. Üretimde varsayılan kullanılır.
  final Duration _yetkiOmru;

  /// ⚠ ENJEKTE EDİLEBİLİR SAAT (Y7).
  ///
  /// Süre dolumu testleri gerçek zamanı BEKLEMEDEN koşsun diye.
  /// ⚠ Production'da süre otoritesi BACKEND saatidir (C5); bu saat
  /// yalnız istemci tarafı davranışı içindir ve güvenlik kararı
  /// vermez.
  final DateTime Function() _now;

  /// KAYIT YETKİSİ — yalnız telefona değil, KAYIT DENEMESİNE bağlı.
  ///
  /// ⚠ Bağlar: amaç (kayıt) · normalize telefon · taslak kimliği ·
  /// bitiş · tüketilme. Başka bir taslak, başka bir telefon veya
  /// sonradan değiştirilmiş bir form aynı yetkiyi KULLANAMAZ.
  ///
  /// ⚠ EN SERT KURAL: bu yetkiyle BAŞKA BİR TELEFONA hesap
  /// açılamaz.
  final Map<String, ({String phone, String taslak, DateTime bitis})>
      _kayitYetkileri = {};

  /// HESAP KURTARMA YETKİSİ — KULLANICIYA bağlı.
  ///
  /// ⚠ Bağlar: amaç (şifre kurtarma) · userId · bitiş · tüketilme.
  /// Başka kullanıcıya uygulanamaz, ikinci kez kullanılamaz.
  final Map<String, ({String userId, DateTime bitis})> _kurtarmaYetkileri = {};

  AuthRepository({
    bool seedTestAccount = kDebugMode,
    OtpService? otpService,
    Duration yetkiOmru = const Duration(minutes: 10),
    DateTime Function()? nowProvider,
  })  : _otp = otpService ?? MockOtpService(),
        _yetkiOmru = yetkiOmru,
        _now = nowProvider ?? DateTime.now {
    if (seedTestAccount) {
      // ⚠ DEMO ŞİFRE ŞİFRE KURALINA UYAR (16 Ağu).
      //
      // Eski değer `123456` idi: 6 hane, yeni asgari 8'in ALTINDA.
      // Giriş ekranı şifrede yalnız DOLULUK aradığı için çalışmaya
      // devam ediyordu (o kural bilinçli — kural değişince eski
      // şifreli kullanıcı kendi hesabından kilitlenmesin diye).
      // Ama demo hesabın kurala uymaması, kuralı kâğıt üstünde
      // bırakıyordu: ekipteki herkes 6 haneyle çalışmaya devam ederdi.
      //
      // Yeni değer 8 hane ve doğrulayıcının üç zayıflık denetiminden
      // de geçiyor (ardışık değil, tekrar değil, yaygın değil).
      // Prototip test hesabı (532 111 22 33 / 1986onur)
      // ⚠ KURUCU `buildPorts` İÇİNDE, YANİ `runApp`'TEN ÖNCE ÇALIŞIR.
      // Burada PBKDF2 hesaplansaydı ilk Flutter karesi o kadar
      _seed(hazirTuz: kDemoMusteriTuz, hazirOzet: kDemoMusteriOzet,
          phone: '5321112233', pass: '1986onur',
          roles: {Role.customer}, name: 'Onur Bütün',
          // ⚠ Demo hesabın e-postası da doldurulur: profil ekranı
          // gerçek veriyle denenebilsin, boş alan yüzünden e-posta
          // kuralları test dışı kalmasın.
          // ⚠ GİRİŞ ARTIK E-POSTA İLE: demo hesabın adresi giriş
          // ekranındaki test bilgisiyle AYNI olmak zorunda.
          email: 'test@hizmetcep.com',
          // Kayıt sırasında girilmiş adres — Adreslerim ekranı dolu açılır.
          ilce: 'Karşıyaka', mahalle: 'İmbatlı');
    }
  }

  void _seed({required String phone, required String pass, required Set<Role> roles,
      String name = '', String email = '',
      String ilce = '', String mahalle = '',
      /// ⚠ AÇILIŞ YOLUNDAN PBKDF2'Yİ ÇIKARIR — bkz.
      String? hazirTuz, String? hazirOzet}) {
    final hazir = hazirTuz != null && hazirOzet != null;
    final salt = hazir ? hazirTuz : _uuid.v4();
    accounts.add(Account(
      id: _uuid.v4(),
      name: name,
      email: email,
      phone: phone,
      passwordHash: hazir ? hazirOzet : PasswordHasher.hash(pass, salt),
      salt: salt,
      roles: roles,
      // Tohumlanan test hesabı kayıt akışını TAMAMLAMIŞ sayılır:
      // SMS OTP, e-posta doğrulaması ve sözleşme onayı geçmiştir.
      // Aksi hâlde giriş sonrası onboarding'e takılır.
      phoneVerified: true,
      emailVerified: true,
      termsAccepted: true,
    ));
    // ⚠ TOHUM HESABIN ADRESİ DE DOLDURULUR.
    //
    // Adres alanı boş kaldığında Adreslerim ekranı "Seçiniz" ile
    // açılıyor ve kayıtlı adres yokmuş gibi görünüyordu. Gerçek
    // kullanımda kayıt sırasında girilen adres burada durur; demo
    // hesap da aynı durumu yansıtmalıdır.
    if (ilce.isNotEmpty && mahalle.isNotEmpty) {
      accounts.last.address = Address(
        id: 'addr-${accounts.last.id}',
        district: ilce,
        neighborhood: mahalle,
      );
    }
  }

  bool get loggedIn => currentAccount != null;
  Role get activeRole => currentAccount?.activeRole ?? Role.customer;

  String _norm(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');

  Account? byId(String id) {
    for (final a in accounts) {
      if (a.id == id) {
        return a;
      }
    }
    return null;
  }

  /// ── ⚠ "BUL" AKIŞI — GERÇEK HİZMET VEREN EŞLEŞMESİ ──
  ///
  /// `kategori` veya `hizmet` adı, hizmet verenin KENDİ seçtiği
  /// `categories` kümesinde varsa eşleşir — `MyCategoriesScreen`'de
  /// hem ana kategori hem alt hizmet AYNI kümeye toggle edilir (bkz.
  /// o ekranın notu), bu yüzden ikisi de burada aranır.
  ///
  /// ⚠ Yalnız hizmet veren rolü olan, KENDİ hesabı OLMAYAN hesaplar
  /// döner — bir kullanıcı kendi aramasında kendini görmez.
  List<Account> saglayicilarKimSunuyor(
    String kategori,
    String hizmet, {
    required String haricTutulacakId,
  }) {
    return accounts
        .where((a) =>
            a.isProvider &&
            a.id != haricTutulacakId &&
            (a.categories.contains(kategori) ||
                a.categories.contains(hizmet)))
        .toList(growable: false);
  }

  Account? findByPhone(String phone) {
    final p = _norm(phone);
    for (final a in accounts) {
      if (a.phone == p) {
        return a;
      }
    }
    return null;
  }

  /// E-POSTA İLE HESAP BULMA — K1: CASE-INSENSITIVE.
  ///
  /// ⚠ Karşılaştırma DAİMA `epostaNormalize` sonrası yapılır:
  /// `Onur@Gmail.com` ile `onur@gmail.com` AYNI hesaptır. Ham metin
  /// karşılaştırması yapılırsa aynı kişi iki hesap açabilir ve
  /// e-posta giriş kimliği belirsizleşir.
  ///
  /// Boş e-posta hiçbir hesabı bulmaz: e-postası olmayan kayıtlar
  /// birbirini eşleştirmemelidir.
  Account? findByEmail(String email) {
    final e = epostaNormalize(email);
    if (e.isEmpty) {
      return null;
    }
    for (final a in accounts) {
      if (epostaNormalize(a.email) == e) {
        return a;
      }
    }
    return null;
  }

  /// Bu e-posta BAŞKA bir hesapta kullanılıyor mu? (K1)
  ///
  /// [haricTutulanId] kendi hesabını güncelleyen kullanıcı içindir:
  /// kişi kendi adresini yeniden yazarsa çakışma sayılmaz.
  bool epostaBaskaHesaptaMi(String email, {String? haricTutulanId}) {
    final sahip = findByEmail(email);
    return sahip != null && sahip.id != haricTutulanId;
  }

  /// Bu telefon BAŞKA bir hesapta kullanılıyor mu?
  bool telefonBaskaHesaptaMi(String phone, {String? haricTutulanId}) {
    final sahip = findByPhone(phone);
    return sahip != null && sahip.id != haricTutulanId;
  }

  bool _verify(Account a, String pass) =>
      PasswordHasher.verify(pass, a.salt, a.passwordHash);

  /// Kimlik doğrulamalı giriş. Hata GENELDİR (hangi alanın yanlış
  /// olduğu söylenmez). Başarıda hesabın activeRole'ü geçerlidir.
  /// ── GİRİŞ DENEMESİ SINIRI ──
  ///
  /// ⚠ BU ASIL KORUMA DEĞİLDİR. Gerçek sınır SUNUCUDA olmalıdır:
  /// istemci kurcalanabilir, saldırgan uygulamayı hiç açmadan doğrudan
  /// API'ye istek atabilir. Buradaki sınır yalnız SÜRTÜNME ekler ve
  /// aynı cihazdan kaba kuvvet denemesini yavaşlatır.
  ///
  /// Numara başına sayaç tutulur; başarılı girişte sıfırlanır.
  static const int _maxDeneme = 5;
  static const Duration _kilitSuresi = Duration(minutes: 1);
  final Map<String, int> _denemeler = {};
  final Map<String, DateTime> _kilitler = {};

  /// GİRİŞ KİLİDİNİN KALAN SÜRESİ (saniye) — DIŞARIYA AÇIK.
  ///
  /// ⚠ EKRAN GERİ SAYIMI BUNDAN OKUR.
  ///
  /// Eskiden kalan süre yalnız hata METNİNİN İÇİNE gömülüyordu
  /// ("20 saniye sonra tekrar deneyin"). O metin bir kez üretilip
  /// ekranda donuyordu: sayı ilerlemiyor, kullanıcı yeniden
  /// denemeden güncellenmiyordu. Kalan süre artık her an
  /// sorulabilir; tek kaynak burasıdır.
  int girisKilidiKalan(String phone) => _kilitKalan(_norm(phone));

  /// E-POSTA kanalının kalan kilit süresi (saniye).
  ///
  /// ⚠ Kilit anahtar bazlıdır; e-posta ve telefon kanalları ayrı
  /// sayılır. Aynı hesabın iki kanalı birbirini kilitlemez.
  int girisKilidiKalanEposta(String email) =>
      _kilitKalan(epostaNormalize(email));

  /// Kalan kilit süresi (saniye); kilit yoksa 0.
  int _kilitKalan(String p) {
    final t = _kilitler[p];
    if (t == null) {
      return 0;
    }
    final k = t.difference(DateTime.now()).inSeconds;
    return k > 0 ? k : 0;
  }

  /// E-POSTA + ŞİFRE İLE GİRİŞ.
  ///
  /// ⚠ HESAP MODELİ KARARI: şifreli giriş E-POSTA iledir; telefonla
  /// giriş şifre değil SMS OTP kullanır (`girisTelefonDogrula`).
  ///
  /// Kilit, deneme sayacı ve nötr hata mesajı telefon girişiyle AYNI
  /// kurallara tabidir: hesabın var olup olmadığı sızdırılmaz —
  /// bulunamayan e-posta da "telefon veya şifre hatalı" ile aynı
  /// mesajı alır.
  DomainError? girisEposta(String email, String pass) {
    final e = epostaNormalize(email);
    final kalan = _kilitKalan(e);
    if (kalan > 0) {
      return ValidationError(
          'Çok fazla hatalı deneme. $kalan saniye sonra tekrar deneyin.');
    }
    final acc = findByEmail(e);
    // ⚠ Hesap yoksa da şifre yanlışsa da AYNI cevap.
    if (acc == null || !_verify(acc, pass)) {
      _denemeArtir(e);
      // ⚠ TİP GÜVENLİ VE GENEL: hesabın var olup olmadığı
      // söylenmez; mesaj `FormMesaj.kimlikHatali` ile aynıdır.
      return const AuthFailedError();
    }
    _denemeSifirla(e);
    _oturumAc(acc);
    return null;
  }

  /// TELEFON + ŞİFRE İLE GİRİŞ.
  ///
  /// ⚠ KARAR GÜNCELLENDİ (14 Ağu, ürün kararı).
  ///
  /// Hesap modeli belgesi "telefonla girişte şifre KULLANILMASIN,
  /// SMS OTP kullanılsın" diyordu. Ürün tarafı bunu geri aldı:
  /// KAYITLI kullanıcı her iki kimlikle de ŞİFRESİYLE girer.
  ///
  /// ⚠ SMS OTP KALDIRILMADI, YERİ DEĞİŞTİ: artık yalnız kayıt,
  /// telefon numarası değişikliği ve hesap kurtarma akışlarında
  /// telefon SAHİPLİĞİNİ doğrular. Giriş anahtarı değildir.
  ///
  /// Kilit ve deneme sayacı e-posta kanalından AYRIDIR (numara
  /// anahtarlı); mesaj her hâlde aynıdır — hesabın var olup
  /// olmadığı sızdırılmaz.
  DomainError? girisTelefonSifre(String phone, String pass) {
    final p = _norm(phone);
    final kalan = _kilitKalan(p);
    if (kalan > 0) {
      return ValidationError(
          'Çok fazla hatalı deneme. $kalan saniye sonra tekrar deneyin.');
    }
    final acc = findByPhone(p);
    if (acc == null || !_verify(acc, pass)) {
      _denemeArtir(p);
      return const AuthFailedError();
    }
    _denemeSifirla(p);
    _oturumAc(acc);
    return null;
  }

  /// TELEFONLA GİRİŞ — SMS OTP İLE.
  ///
  /// ⚠ ARTIK GİRİŞ EKRANINDAN KULLANILMIYOR (bkz. üstteki karar
  /// notu). Challenge altyapısı kayıt / telefon değişikliği / hesap
  /// kurtarma akışlarında sürüyor; bu iki metot da hesap kurtarma
  /// senaryolarının testlerinde kalıyor.
  ///
  /// ⚠ K2: BU YOL ASLA HESAP OLUŞTURMAZ.
  ///
  /// Numara kayıtlı değilse doğrulama başarısız sayılır. Aksi hâlde
  /// "giriş" sessizce bir kayıt yoluna dönüşür ve sözleşme onayı,
  /// e-posta, rol seçimi atlanır.
  ///
  /// ⚠ K5: BAŞLANGIÇ UCU HESAP ENUMERATİON YAPMAZ. Numara kayıtlı
  /// olsun olmasın `null` (başarı) döner; kod yalnız kayıtlı numaraya
  /// gönderilir. Kullanıcıya "bu numara kayıtlı değil" DENMEZ.
  ({String? challengeId, DomainError? error}) girisTelefonKodGonder(
      String phone) {
    final p = _norm(phone);
    // ⚠ C7: ÖNCEKİ AKTİF GİRİŞ CHALLENGE'I İPTAL EDİLİR.
    //
    // Bu satır eksikti: giriş akışı challenge'ı elle kuruyor ve
    // `_challengeUret` yardımcısını atlıyordu. Sonuç: yeniden
    // gönderimden sonra ESKİ kod da geçerli kalıyordu — kullanıcının
    // eline geçen eski SMS ölmüyordu.
    final ch = _challengeUret(p, OtpAmac.giris);

    // ⚠ GERÇEK SMS YALNIZ KAYITLI NUMARAYA GİDER.
    //
    // Challenge her hâlde üretilir ki cevap ve akış AYNI görünsün
    // (K5); ama kayıtsız numaraya kod GÖNDERİLMEZ — aksi hâlde
    // ücret ve taciz kapısı olurdu. Kullanıcı farkı GÖREMEZ:
    // doğrulama adımı kayıtsız numarada zaten başarısız olur.
    if (findByPhone(p) != null) {
      unawaited(_otp.sendCode(p));
    }
    return (challengeId: ch.id, error: null);
  }

  /// CHALLENGE DOĞRULAMA — TEK OTORİTE.
  ///
  /// ⚠ EKRAN BYPASS EDİLSE BİLE ÇALIŞIR. Depo/use-case doğrudan
  /// çağrılsa da rastgele bir 6 haneli kodla oturum AÇILAMAZ:
  /// kod `OtpService`'e sorulur, challenge süresi/denemesi/tek
  /// kullanımı burada denetlenir.
  ///
  /// [tuket] false verilirse başarılı kodda challenge TÜKETİLMEZ;
  /// çağıran, işin tamamı başarıyla bitince `challengeTuket` çağırır
  /// (Y5/Y6). Böylece benzersizlik gibi sonraki bir adım
  /// başarısız olursa kullanıcı yeniden SMS istemek zorunda kalmaz.
  Future<OtpSonuc> challengeDogrula(
      String challengeId, String kod, OtpAmac amac,
      {bool tuket = true}) async {
    final ch = _challenges[challengeId];
    if (ch == null || ch.amac != amac) {
      return OtpSonuc.gecersizChallenge;
    }
    if (ch.consumed) {
      return OtpSonuc.kullanilmis;
    }
    if (ch.suresiDolduMu(_now())) {
      return OtpSonuc.suresiDoldu;
    }
    if (ch.denemeBitti) {
      return OtpSonuc.denemeBitti;
    }
    ch.deneme++;
    final ok = await _otp.verify(ch.phone, kod);
    if (!ok) {
      return OtpSonuc.kodHatali;
    }
    // ⚠ TEK KULLANIM: başarılı kod bir daha kullanılamaz.
    if (tuket) {
      ch.consumed = true;
    }
    return OtpSonuc.basarili;
  }

  /// İş başarıyla bittiğinde challenge'ı tüketir (Y5/Y6).
  void challengeTuket(String challengeId) {
    _challenges[challengeId]?.consumed = true;
  }

  /// Telefon OTP doğrulaması — başarılıysa oturum açar.
  ///
  /// ⚠ Kod doğru ama numara kayıtlı DEĞİLSE hesap AÇILMAZ (K2);
  /// nötr bir hata döner.
  Future<DomainError?> girisTelefonDogrula(
      String challengeId, String kod) async {
    final ch = _challenges[challengeId];
    if (ch == null) {
      return const ValidationError(FormMesaj.otpHatali);
    }
    final p = ch.phone;
    final kalan = _kilitKalan(p);
    if (kalan > 0) {
      return ValidationError(
          'Çok fazla hatalı deneme. $kalan saniye sonra tekrar deneyin.');
    }

    // ⚠ ÖNCE KOD, SONRA HESAP.
    //
    // Sıra önemlidir: hesap denetimi önce yapılsaydı, yanlış kodla
    // bile "bu numara kayıtlı mı" bilgisi zamanlamadan sızabilirdi.
    final sonuc = await challengeDogrula(challengeId, kod, OtpAmac.giris);
    if (sonuc != OtpSonuc.basarili) {
      _denemeArtir(p);
      return ValidationError(_otpMesaji(sonuc));
    }

    // ⚠ K2: KOD DOĞRU AMA HESAP YOKSA HESAP AÇILMAZ.
    final acc = findByPhone(p);
    if (acc == null) {
      _denemeArtir(p);
      // ⚠ "Bu numara kayıtlı değil" DEMEZ (K5).
      return const ValidationError(FormMesaj.otpHatali);
    }
    _denemeSifirla(p);
    _oturumAc(acc);
    return null;
  }

  // ══════════════════════════════════════════════════════════════
  // TELEFON SAHİPLİĞİ DOĞRULANAN ÖTEKİ ÜÇ AKIŞ
  //
  // ⚠ HEPSİ AYNI CHALLENGE MODELİNİ KULLANIR. Ekran hiçbirinde
  // "6 hane doğruysa tamam" demez; karar burada verilir.
  // ══════════════════════════════════════════════════════════════

  /// Aynı amaç için ÖNCEKİ aktif challenge'ı iptal eder (C7).
  ///
  /// ⚠ İki challenge aynı anda geçerli kalmaz: kullanıcı yeni kod
  /// isteyince eski kod ÖLÜR. Aksi hâlde eski SMS'i eline geçiren
  /// biri, kullanıcı yeni kod istemiş olsa bile ilerleyebilirdi.
  void _oncekiChallengeIptal(String phone, OtpAmac amac) {
    for (final c in _challenges.values) {
      if (c.phone == phone && c.amac == amac && !c.consumed) {
        c.consumed = true;
      }
    }
  }

  OtpChallenge _challengeUret(String phone, OtpAmac amac) {
    _oncekiChallengeIptal(phone, amac);
    final ch = OtpChallenge(
      id: _uuid.v4(),
      phone: phone,
      amac: amac,
      expiresAt: _now().add(_kChallengeOmru),
    );
    _challenges[ch.id] = ch;
    return ch;
  }

  /// KAYIT — telefon doğrulama kodu ister.
  ///
  /// ⚠ Kayıtta numara zaten YENİ olabilir; SMS her hâlde gider.
  ///
  /// [taslakKimligi] o kayıt denemesini temsil eder. Kullanıcı formu
  /// kapatıp yeniden açarsa yeni taslak üretilir ve eski yetki
  ({String challengeId}) kayitKodGonder(String phone,
      {required String taslakKimligi}) {
    final p = _norm(phone);
    final ch = _challengeUret(p, OtpAmac.kayit);
    _challengeTaslaklari[ch.id] = taslakKimligi;
    unawaited(_otp.sendCode(p));
    return (challengeId: ch.id);
  }

  /// Challenge → taslak kimliği eşlemesi.
  final Map<String, String> _challengeTaslaklari = {};

  /// KAYIT KODUNU DOĞRULAR ve KISA ÖMÜRLÜ KAYIT YETKİSİ üretir.
  ///
  /// ⚠ HESAP BURADA OLUŞMAZ. Doğrulama yalnız "bu telefon bu
  /// kişinin" der; kaydı `register` tamamlar ve bu yetkiyi ister.
  ///
  /// ⚠ Yetki TELEFONA BAĞLIDIR: başka numarayla ya da başka
  /// taslakla kullanılamaz.
  Future<({String? yetki, DomainError? error})> kayitDogrula(
      String challengeId, String kod) async {
    final ch = _challenges[challengeId];
    final sonuc = await challengeDogrula(challengeId, kod, OtpAmac.kayit);
    if (sonuc != OtpSonuc.basarili || ch == null) {
      return (yetki: null, error: ValidationError(_otpMesaji(sonuc)));
    }
    final yetki = _uuid.v4();
    _kayitYetkileri[yetki] = (
      phone: ch.phone,
      taslak: _challengeTaslaklari[challengeId] ?? '',
      bitis: _now().add(_yetkiOmru),
    );
    return (yetki: yetki, error: null);
  }

  /// TELEFON DEĞİŞİKLİĞİ — YENİ numaraya kod gönderir.
  ///
  /// ⚠ MEVCUT TELEFON DEĞİŞMEZ. Değişiklik yalnız doğrulama
  /// başarılı olduğunda, tek adımda uygulanır.
  ({String? challengeId, DomainError? error}) telefonDegisimiKodGonder(
      String yeniTelefon) {
    final acc = currentAccount;
    if (acc == null) {
      return (challengeId: null, error: const UnauthorizedError('Oturum yok'));
    }
    final p = _norm(yeniTelefon);
    // ⚠ ERKEN UYARI: numara başkasındaysa kod bile gönderilmez.
    if (telefonBaskaHesaptaMi(p, haricTutulanId: acc.id)) {
      return (
        challengeId: null,
        error: const ValidationError(FormMesaj.telefonKullanimda)
      );
    }
    final ch = _challengeUret(p, OtpAmac.telefonDegisimi);
    unawaited(_otp.sendCode(p));
    return (challengeId: ch.id, error: null);
  }

  /// Doğrulama başarılıysa yeni numarayı TEK ADIMDA bağlar (K4).
  ///
  /// ⚠ BAŞARISIZ / SÜRESİ DOLMUŞ / İPTAL durumunda eski telefon
  /// AYNEN kalır.
  Future<DomainError?> telefonDegisimiDogrula(
      String challengeId, String kod) async {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum yok');
    }
    final ch = _challenges[challengeId];
    // ⚠ Y6: KOD DOĞRU OLSA BİLE HENÜZ TÜKETİLMEZ.
    final sonuc = await challengeDogrula(
        challengeId, kod, OtpAmac.telefonDegisimi,
        tuket: false);
    if (sonuc != OtpSonuc.basarili || ch == null) {
      return ValidationError(_otpMesaji(sonuc));
    }
    // ⚠ SON BİR KEZ DAHA BENZERSİZLİK: bekleme süresince başkası
    // aynı numarayı almış olabilir. Gerçek otorite veritabanındaki
    // normalize telefon UNIQUE kısıtıdır; burada istemci tarafı
    // denetimidir.
    //
    // ⚠ BAŞARISIZSA BAŞKA HESABIN TELEFONU EZİLMEZ ve challenge
    // TÜKETİLMEZ — kullanıcı yeniden SMS istemek zorunda kalmaz.
    if (telefonBaskaHesaptaMi(ch.phone, haricTutulanId: acc.id)) {
      return const ValidationError(FormMesaj.telefonKullanimda);
    }
    // Tek adım: eski numara bu satırda bırakılır.
    acc.phone = ch.phone;
    acc.phoneVerified = true;
    // ⚠ İŞ BİTTİ: challenge ŞİMDİ tüketilir.
    challengeTuket(challengeId);
    notifyListeners();
    return null;
  }

  /// HESAP KURTARMA — telefona kod gönderir.
  ///
  /// ⚠ K5/C9: kayıtlı olsun olmasın AYNI cevap; gerçek SMS YALNIZ
  /// kayıtlı numaraya gider.
  /// TELEFON SİSTEME KAYITLI MI?
  ///
  /// ⚠ Mock depoda kesin cevap verilebilir; bu yüzden `null`
  /// DÖNDÜRÜLMEZ. API portu `null` döner (sunucuda uç yok).
  bool? telefonKayitliMi(String phone) => findByPhone(_norm(phone)) != null;

  ({String challengeId}) hesapKurtarmaKodGonder(String phone) {
    final p = _norm(phone);
    final ch = _challengeUret(p, OtpAmac.hesapKurtarma);
    if (findByPhone(p) != null) {
      unawaited(_otp.sendCode(p));
    }
    return (challengeId: ch.id);
  }

  /// Kod doğruysa KISA ÖMÜRLÜ KURTARMA YETKİSİ üretir.
  ///
  /// ⚠ OTURUM AÇILMAZ. OTP yalnız telefonun kullanıcıya ait
  /// olduğunu söyler; şifre değiştirme yetkisi AYRI ve SÜRELİ bir
  /// yetkiyle verilir. Aksi hâlde SMS kodu doğrudan hesaba giriş
  /// anahtarı olurdu.
  Future<({String? yetki, DomainError? error})> hesapKurtarmaDogrula(
      String challengeId, String kod) async {
    final ch = _challenges[challengeId];
    final sonuc =
        await challengeDogrula(challengeId, kod, OtpAmac.hesapKurtarma);
    if (sonuc != OtpSonuc.basarili || ch == null) {
      return (yetki: null, error: ValidationError(_otpMesaji(sonuc)));
    }
    final acc = findByPhone(ch.phone);
    if (acc == null) {
      // ⚠ Kayıtsız numara: nötr hata, hesap SÖYLENMEZ (K5).
      return (yetki: null, error: const ValidationError(FormMesaj.otpHatali));
    }
    final yetki = _uuid.v4();
    _kurtarmaYetkileri[yetki] = (
      userId: acc.id,
      bitis: _now().add(_yetkiOmru),
    );
    return (yetki: yetki, error: null);
  }

  /// KURTARMA YETKİSİYLE YENİ ŞİFRE.
  ///
  /// ⚠ TEK KULLANIMLIK ve SÜRELİ. Yetki tüketildikten sonra aynı
  /// kodla ikinci bir şifre değişikliği yapılamaz.
  /// ⚠ OTURUM AÇMAZ: kullanıcı yeni şifresiyle normal yoldan girer.
  DomainError? kurtarmaSifreBelirle(String yetki, String yeniSifre) {
    final kayit = _kurtarmaYetkileri[yetki];
    if (kayit == null || _now().isAfter(kayit.bitis)) {
      _kurtarmaYetkileri.remove(yetki);
      return const ValidationError(FormMesaj.sifirlamaSuresiDoldu);
    }
    final acc = byId(kayit.userId);
    if (acc == null) {
      return const ValidationError(FormMesaj.sifirlamaGecersiz);
    }
    // ⚠ Y5: ŞİFRE POLİTİKASI ÖNCE, TÜKETİM SONRA.
    //
    // Politika reddederse yetki TÜKETİLMEZ; kullanıcı daha güçlü
    // bir şifreyle aynı yetkiyi kullanabilir, baştan SMS istemez.
    final policy = Validators.password(yeniSifre);
    if (policy != null) {
      return ValidationError(policy);
    }
    acc.passwordHash = PasswordHasher.hash(yeniSifre, acc.salt);
    // ⚠ İŞ BİTTİ: yetki ŞİMDİ tüketilir.
    _kurtarmaYetkileri.remove(yetki);
    notifyListeners();
    return null;
  }

  /// Kayıt yetkisi geçerli mi ve BU telefona mı ait?
  ///
  /// ⚠ ÜÇ BAĞ BİRDEN: telefon + taslak + süre. Biri bile tutmazsa
  bool kayitYetkisiGecerli(String? yetki, String phone,
      {String? taslakKimligi}) {
    if (yetki == null) {
      return false;
    }
    final k = _kayitYetkileri[yetki];
    if (k == null || _now().isAfter(k.bitis)) {
      _kayitYetkileri.remove(yetki);
      return false;
    }
    if (k.phone != _norm(phone)) {
      return false;
    }
    // Taslak verildiyse eşleşmek ZORUNDA.
    return taslakKimligi == null || k.taslak == taslakKimligi;
  }

  /// Kullanılan kayıt yetkisi TÜKETİLİR (tek kullanım).
  void kayitYetkisiTuket(String yetki) => _kayitYetkileri.remove(yetki);

  /// Challenge sonucunu kullanıcıya gösterilecek metne çevirir.
  ///
  /// ⚠ Hiçbiri hesabın var olup olmadığını söylemez (K5).
  static String _otpMesaji(OtpSonuc s) => switch (s) {
        OtpSonuc.suresiDoldu => FormMesaj.otpSuresiDoldu,
        OtpSonuc.denemeBitti => FormMesaj.otpCokDeneme,
        _ => FormMesaj.otpHatali,
      };

  /// ── ORTAK GİRİŞ YARDIMCILARI ──
  ///
  /// ⚠ Deneme sayacı ve kilit ANAHTAR BAZLIDIR: e-posta girişinde
  /// normalize e-posta, telefon girişinde normalize numara. Böylece
  /// bir kanaldaki hatalı denemeler ötekini kilitlemez ama her kanal
  /// kendi içinde korunur.
  void _denemeArtir(String anahtar) {
    final n = (_denemeler[anahtar] ?? 0) + 1;
    _denemeler[anahtar] = n;
    if (n >= _maxDeneme) {
      _kilitler[anahtar] = DateTime.now().add(_kilitSuresi);
      _denemeler[anahtar] = 0;
    }
  }

  void _denemeSifirla(String anahtar) {
    _denemeler.remove(anahtar);
    _kilitler.remove(anahtar);
  }

  void _oturumAc(Account acc) {
    currentAccount = acc;
    notifyListeners();
  }

  /// ⚠ YALNIZ MOCK OTURUM GERİ YÜKLEME İÇİN — `MockAuthPort.restoreSession`
  /// buradan çağırır. `_oturumAc` (normal giriş akışı) ile AYNI işi
  /// yapar; PUBLIC olması gerekir çünkü çağıran farklı bir dosyadadır
  /// (`data/ports/mock_ports.dart`).
  void oturumuGeriYukle(Account acc) {
    currentAccount = acc;
    notifyListeners();
  }

  /// Kayıt — GÜVENLİK KURALLARI:
  /// * [otpVerified] false ise HİÇBİR yol çalışmaz (SMS doğrulaması zorunlu).
  /// * Telefon KAYITLI ise: girilen şifre MEVCUT hesabın şifresiyle
  ///   doğrulanmadan role eklenemez ve oturum açılamaz; şifre sessizce
  ///   yok sayılmaz — eşleşmezse tip güvenli hata döner.
  /// * Telefon kayıtlı değilse: yeni hesap girilen şifreyle açılır.
  ({Account? account, DomainError? error}) register({
    required String phone,
    required String pass,
    required Role role,
    required bool otpVerified,

    /// ⚠ KAYIT YETKİSİ — `kayitDogrula` üretir.
    ///
    /// Verildiğinde `otpVerified` bayrağına DEĞİL bu yetkiye
    /// bakılır: yetki telefona bağlıdır, süreli ve tek
    /// kullanımlıktır. Bayrak istemcinin "doğruladım" demesinden
    /// ibarettir; yetki ise doğrulamanın kendisinden üretilir.
    ///
    /// Geçiş dönemi: verilmezse eski bayrak yolu sürer (kayıtsız
    /// ilan akışı ve testler henüz taşınmadı).
    String? kayitYetkisi,

    /// Kayıt denemesinin kimliği — yetkiyle EŞLEŞMEK zorundadır.
    String? taslakKimligi,
    String name = '',
    String email = '',
    Set<String> categories = const {},
    Set<String> serviceDistricts = const {},
    /// Kullanım Sözleşmesi + Gizlilik Politikası onayı.
    /// ⚠ Google ile kayıt bunu BYPASS ETMEZ.
    bool termsAccepted = false,
    /// Google akışında doğrulanmış e-posta ile gelinir.
    bool emailVerified = false,
    /// Google `sub` — hesap eşleştirmesi bu kimlikle yapılır.

    /// ⚠ YALNIZ DEBUG TOHUMLAMASI İÇİN — önceden hesaplanmış tuz+özet.
    ///
    /// Normal kayıt bu parametreleri VERMEZ; o yolda tuz rastgele
    /// üretilir ve PBKDF2 hesaplanır. Burada amaç açılış yolundan
    /// 20.000 turluk hesabı çıkarmaktır (bkz.
    /// `demo_hesap_ozetleri.dart`).
    ///
    /// İkisi BİRLİKTE verilmelidir; yalnız biri verilirse yok sayılır
    /// ve normal hesaplama yapılır — yanlış eşleşmiş tuz/özet çifti
    /// oluşamaz.
    String? hazirTuz,
    String? hazirOzet,
  }) {
    // ── SMS OTP ZORUNLU ──
    //
    // ⚠ YETKİ VARSA BAYRAĞA BAKILMAZ. Yetki gerçek doğrulamadan
    // üretildiği için istemcinin sözüne göre daha güçlüdür ve
    // TELEFONA BAĞLIDIR: başka numarayla ya da başka taslakla
    // kullanılamaz.
    if (kayitYetkisi != null) {
      // ⚠ Y5: YETKİ BURADA DOĞRULANIR AMA TÜKETİLMEZ.
      //
      // Tüketim, hesap gerçekten oluştuktan sonra yapılır. Aksi
      // hâlde sonraki bir kural (sözleşme onayı, şifre çakışması,
      // e-posta benzersizliği) işi düşürdüğünde kullanıcı yeniden
      // SMS istemek zorunda kalırdı.
      if (!kayitYetkisiGecerli(kayitYetkisi, phone,
          taslakKimligi: taslakKimligi)) {
        return (account: null, error: const OtpRequiredError());
      }
    } else if (!otpVerified) {
      return (account: null, error: const OtpRequiredError());
    }
    if (!termsAccepted) {
      return (
        account: null,
        error: const ValidationError(
            'Kullanım sözleşmesi ve gizlilik politikası onayı zorunludur'),
      );
    }
    final p = _norm(phone);

    // ── ⚠ K1: E-POSTA BENZERSİZLİĞİ ──
    //
    // Kayıtta yalnız TELEFON çakışması denetleniyordu; aynı e-posta
    // iki hesaba girebiliyordu. E-posta artık giriş kimliği olduğu
    // için bu belirsizlik güvenlik açığıdır: "e-posta + şifre"
    // hangi hesabı açacağı belli olmaz.
    //
    // Karşılaştırma normalize edilmiş hâlle yapılır (K1).
    if (email.trim().isNotEmpty) {
      final sahip = findByEmail(email);
      if (sahip != null && sahip.phone != p) {
        return (account: null, error: const ValidationError(FormMesaj.epostaKullanimda));
      }
    }

    var acc = findByPhone(p);
    if (acc == null) {
      final hazir = hazirTuz != null && hazirOzet != null;
      final salt = hazir ? hazirTuz : _uuid.v4();
      acc = Account(
        id: _uuid.v4(),
        name: name,
        email: email,
        phone: p,
        // ⚠ Hazır özet verilmediyse davranış AYNEN eskisi gibidir.
        passwordHash: hazir ? hazirOzet : PasswordHasher.hash(pass, salt),
        salt: salt,
        roles: {role},
        activeRole: role,
        // SMS OTP bu noktada doğrulanmıştır.
        phoneVerified: true,
        // ⚠ E-posta AYRICA doğrulanır (`verifyEmail`).
        emailVerified: emailVerified,
        termsAccepted: termsAccepted,
      );
      accounts.add(acc);
    } else {
      if (!_verify(acc, pass)) {
        return (
          account: null,
          error: const WrongPasswordError(
              'Bu telefon zaten kayıtlı — role eklemek için mevcut şifrenizle devam edin'),
        );
      }
      acc.roles.add(role);
      acc.activeRole = role;
      // Mevcut hesapta doğrulama durumları KORUNUR; yalnız yükseltilir.
      acc.phoneVerified = true;
      if (emailVerified) {
        acc.emailVerified = true;
      }
      if (termsAccepted) {
        acc.termsAccepted = true;
      }
    }
    if (role == Role.provider) {
      acc.categories.addAll(categories);
      acc.serviceDistricts.addAll(serviceDistricts);
    }
    currentAccount = acc;
    // ⚠ Y5: HESAP OLUŞTU — YETKİ ŞİMDİ TÜKETİLİR.
    //
    // Buraya kadar gelen her erken dönüş yetkiyi tüketmeden
    // döndü; kullanıcı aynı kodla yeniden deneyebilir.
    // Gerçek backend'de bu iki iş TEK TRANSACTION olacaktır.
    if (kayitYetkisi != null) {
      kayitYetkisiTuket(kayitYetkisi);
    }
    notifyListeners();
    return (account: acc, error: null);
  }

  // ═══════════════════════════════════════════════════════════════
  // E-POSTA DOĞRULAMA
  //
  // Normal kayıtta ZORUNLUDUR. Google akışında Google'ın doğrulanmış
  // e-postası kullanılır ve ikinci doğrulama İSTENMEZ.
  // ═══════════════════════════════════════════════════════════════

  /// Doğrulama kodu/bağlantısı gönderimini başlatır.
  ///
  /// ⚠ MOCK: gerçek e-posta gönderimi yoktur. Production'da bu çağrı
  /// backend'in e-posta doğrulama ucuna bağlanır.
  DomainError? startEmailVerification() {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    if (acc.email.trim().isEmpty) {
      return const ValidationError('Önce e-posta adresi giriniz');
    }
    if (acc.emailVerified) {
      return null; // zaten doğrulanmış
    }
    return null;
  }

  /// E-posta doğrulamasını TAMAMLAR.
  ///
  /// ⚠ Yalnız gerçek doğrulama işlemi başarıyla bittiğinde çağrılır;
  /// `emailVerified` başka hiçbir yerde doğrudan `true` yapılmaz.
  DomainError? completeEmailVerification(String code) {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    if (code.trim().length < 4) {
      return const ValidationError('Doğrulama kodu geçersiz');
    }
    acc.emailVerified = true;
    notifyListeners();
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // GOOGLE HESAP EŞLEŞTİRME
  // ═══════════════════════════════════════════════════════════════


  DomainError? switchRole(Role role) {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    if (!acc.roles.contains(role)) {
      // ⚠ ÇIKMAZ SOKAK DEĞİL: çağıran katman bu hatayı görünce
      // kullanıcıyı EKSİK ROL TAMAMLAMA akışına yönlendirir
      // (`addRole` ile rol eklenir). Hata metni bu yüzden yönlendirici.
      return const NotFoundError('Bu rol için bilgilerinizi tamamlayın');
    }
    acc.activeRole = role;
    notifyListeners();
    return null;
  }

  /// İKİNCİ ROLÜ AYNI HESABA EKLER.
  ///
  /// Ortak bilgiler (ad, soyad, telefon, e-posta) mevcut hesaptan
  /// taşınır; yalnız role özgü eksik alanlar istenir.
  ///
  /// ⚠ Güvenlik kuralları KORUNUR: rol eklenmesi, kullanıcının kendi
  /// ilanına hizmet veren olarak erişebileceği anlamına gelmez —
  /// o kontrol teklif/iletişim katmanındadır.
  DomainError? addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
  }) {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    if (role == Role.provider) {
      if (categories == null || categories.isEmpty) {
        return const ValidationError(FormMesaj.kategoriSec);
      }
      if (serviceDistricts == null || serviceDistricts.isEmpty) {
        return const ValidationError(FormMesaj.bolgeSec);
      }
      acc.categories
        ..clear()
        ..addAll(categories);
      acc.serviceDistricts
        ..clear()
        ..addAll(serviceDistricts);
    }
    // ── ⚠ MÜŞTERİ ROLÜ EKLENİYOR: ADRES OTOMATİK DOLDURULUR ──
    //
    // ÖNCEDEN: yalnız hizmet veren rolü eklenirken bölge/kategori
    // toplanıyordu; müşteri rolü eklenirken `acc.address` hâlâ null
    // kalabiliyordu — hizmet veren OLARAK kayıt olan bir kullanıcı
    // müşteri rolüne geçtiğinde "Bul" akışı "adresiniz yok" diyordu,
    // oysa hesapta zaten bir konum bilgisi (hizmet verdiği bölge)
    // vardı.
    //
    // ⚠ YALNIZ MEVCUT ADRES YOKSA doldurulur — var olan bir adresin
    // ÜZERİNE YAZILMAZ. Mahalle bilgisi YOKTUR (hizmet veren yalnız
    // İLÇE seçer, sokak/mahalle vermez) — UYDURULMAZ, boş bırakılır;
    // kullanıcı isterse "Adreslerim"den tamamlar.
    if (role == Role.customer &&
        acc.address == null &&
        acc.serviceDistricts.isNotEmpty) {
      acc.address = Address(
        id: 'addr-${acc.id}',
        district: acc.serviceDistricts.first,
        neighborhood: '',
      );
    }
    acc.roles.add(role);
    acc.activeRole = role;
    notifyListeners();
    return null;
  }

  /// ŞİFRE DOĞRULAMA — değiştirmeden yalnız kontrol.
  ///
  /// Hesap silme gibi geri alınamaz işlemlerin kapısıdır.
  DomainError? sifreDogrula(String password) {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    return _verify(acc, password)
        ? null
        : const WrongPasswordError('Şifreniz hatalı');
  }

  DomainError? changePassword(String current, String next) {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    if (!_verify(acc, current)) {
      return const WrongPasswordError('Mevcut şifreniz hatalı');
    }
    // ⚠ YENİ ŞİFRE ESKİSİYLE AYNI OLAMAZ.
    //
    // Aynı şifreyle "değiştirdim" demek yanıltıcıdır: kullanıcı
    // hesabını güvenceye aldığını sanır, oysa sızmış olabilecek şifre
    // hâlâ geçerlidir. Denetim EKRANDA DA yapılır; buradaki son
    // savunmadır (API modunda karar sunucunundur).
    if (_verify(acc, next)) {
      // ⚠ Metin tek kaynaktan: ekranla birebir aynı cümle görünsün.
      return ValidationError(FormMesaj.sifreEskisiyleAyni);
    }
    acc.passwordHash = PasswordHasher.hash(next, acc.salt);
    notifyListeners();
    return null;
  }

  /// ŞİFRE KURTARMA BAŞLANGICI — TELEFON KANALI (alternatif yol).
  ///
  /// ⚠ K5: HESAP ENUMERATION ENGELLENİR.
  ///
  /// Eskiden kayıtsız numara için `NotFoundError('Bu numarayla
  /// kayıtlı hesap yok')` dönüyordu; ekran da bunu "Sisteme kayıtlı
  /// bir numara giriniz" diye gösteriyordu. Bu, bir numaranın
  /// sistemde olup olmadığını herkese söylemek demekti.
  ///
  /// Artık numara kayıtlı olsun olmasın AYNI sonuç döner (`null`);
  /// kod yalnız kayıtlı numaraya gönderilir. Doğrulama adımı da
  /// kayıtsız numarada nötr hata verir (`girisTelefonDogrula`, K2).
  DomainError? forgotStart(String phone) => null;

  /// E-POSTA İLE ŞİFRE YENİLEME BAĞLANTISI İSTEĞİ — ANA YOL.
  ///
  /// ⚠ K5: hesap bulunsa da bulunmasa da AYNI nötr sonuç.
  /// ⚠ K3: DOĞRULANMAMIŞ e-posta kurtarma kanalı DEĞİLDİR — bağlantı
  /// gönderilmez. Aksi hâlde yanlış yazılmış ya da başkasına ait bir
  /// adres, hesabı ele geçirme yolu olurdu. Kullanıcı bunu FARK
  /// ETMEZ (nötr cevap aynı), telefon kurtarma yoluna yönlendirilir.
  DomainError? sifreSifirlamaIste(String email) => null;

  /// Bu e-postaya gerçekten bağlantı gönderilmeli mi? (K3)
  ///
  /// ⚠ SONUÇ KULLANICIYA GÖSTERİLMEZ; yalnız gönderim kararıdır.
  bool sifirlamaBaglantisiGonderilir(String email) {
    final acc = findByEmail(email);
    return acc != null && acc.emailVerified;
  }

  void forgotSave(String phone, String newPass) {
    final acc = findByPhone(phone);
    if (acc == null) {
      return;
    }
    acc.passwordHash = PasswordHasher.hash(newPass, acc.salt);
    notifyListeners();
  }

  /// Numara BAŞKA bir hesaba mı ait? (kendi hesabı hariç)
  ///
  /// ⚠ Telefon numarası GİRİŞ ANAHTARIDIR: iki hesapta aynı numara
  /// bulunamaz. Bulunursa hangi hesaba giriş yapılacağı belirsizleşir
  /// ve doğrulama kodu yanlış hesabı açabilir.
  bool phoneTakenByOther(String phone, {required String exceptId}) {
    final p = _norm(phone);
    for (final a in accounts) {
      if (a.phone == p && a.id != exceptId) {
        return true;
      }
    }
    return false;
  }

  /// SMS doğrulaması SONRASI çağrılır: giriş numarası da güncellenir.
  ///
  /// ⚠ ESKİ NUMARA SİSTEMDEN DÜŞER.
  ///
  /// Hesabın `phone` alanı YERİNDE değiştirilir; ikinci bir kayıt
  /// tutulmaz. Numara aramaları (`findByPhone`, giriş, şifre
  /// sıfırlama) bu alan üzerinden yapıldığı için eski numara artık
  /// hiçbir hesapla eşleşmez: o numaraya kod gönderilemez ve o
  /// numarayla giriş yapılamaz.
  void updatePhoneVerified(String newPhone) {
    final acc = currentAccount;
    if (acc == null) {
      return;
    }
    acc.phone = _norm(newPhone);
    acc.phoneVerified = true;
    notifyListeners();
  }

  /// BİLDİRİM TERCİHLERİ — yalnız verilen alanlar değişir.
  ///
  /// ⚠ Güvenlik ve hesap durumu bildirimleri buradan KAPATILAMAZ;
  /// onlar tercihe bağlı değildir.
  void setNotificationPrefs({
    bool? teklif,
    bool? mesaj,
    bool? duyuru,
    bool? eposta,
  }) {
    final acc = currentAccount;
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
    notifyListeners();
  }

  /// Profil bilgileri (ad, e-posta, foto) — telefon ayrı (SMS doğrulamalı).
  void updateProfile({String? name, String? email, String? photoPath}) {
    final acc = currentAccount;
    if (acc == null) {
      return;
    }
    if (name != null) {
      acc.name = name;
    }
    if (email != null && epostaNormalize(email) != epostaNormalize(acc.email)) {
      // ── ⚠ K4: YENİ DEĞER DOĞRULANANA KADAR ESKİSİ KORUNUR ──
      //
      // Eskiden yeni adres HEMEN yazılıyor ve `emailVerified=false`
      // yapılıyordu. Sonuç: kullanıcı yanlış bir adres yazarsa hem
      // eski doğrulanmış adresini KAYBEDİYOR hem yenisini
      // doğrulayamıyor — hesap kurtarma kanalsız kalıyordu.
      //
      // Artık yeni adres BEKLEYEN alanda tutulur; `epostaDogrula`
      // çağrılana kadar `acc.email` DEĞİŞMEZ.
      acc.bekleyenEposta = epostaNormalize(email);
    }
    if (photoPath != null) {
      acc.photoPath = photoPath;
    }
    notifyListeners();
  }

  /// BEKLEYEN E-POSTAYI DOĞRULAR VE GEÇİŞİ TEK ADIMDA YAPAR (K4).
  ///
  /// ⚠ BÖLÜNEMEZ: "eskisini bırak + yenisini bağla + doğrulanmış
  /// işaretle" üçü birlikte olur. Yarıda kalırsa hesap iletişimsiz
  /// kalırdı.
  ///
  /// ⚠ K1: son bir kez daha benzersizlik denetlenir — bekleme
  /// süresince başka biri aynı adresi almış olabilir.
  DomainError? epostaDogrula() {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    final yeni = acc.bekleyenEposta;
    if (yeni == null || yeni.isEmpty) {
      return const ValidationError('Doğrulanacak yeni e-posta yok');
    }
    if (epostaBaskaHesaptaMi(yeni, haricTutulanId: acc.id)) {
      return const ValidationError(FormMesaj.epostaKullanimda);
    }
    // Tek adım: eski değer bu satırda bırakılır.
    acc.email = yeni;
    acc.emailVerified = true;
    acc.bekleyenEposta = null;
    notifyListeners();
    return null;
  }

  /// Bekleyen e-posta değişikliğini iptal eder — eski adres kalır.
  void epostaDegisikligiIptal() {
    currentAccount?.bekleyenEposta = null;
    notifyListeners();
  }

  /// TEK ADRES: mevcut kayıt güncellenir, yoksa oluşturulur.
  ///
  /// ⚠ `city` DE TAŞINIR. Önceden bu metot il almıyordu; çağıran
  /// katman ili doğru geçse bile burada düşüyor ve `Address`
  /// varsayılanına (İzmir) sabitleniyordu. Yeni bir il aktifleştiğinde
  /// Adreslerim yanlış il gösterirdi.
  /// BELİRLİ BİR HESABIN adresini ayarlar (oturum açık olması gerekmez).
  ///
  /// ⚠ Yalnız tohumlama/demo içindir. Kullanıcı akışında adres her
  /// zaman OTURUMDAKİ hesaba yazılır (`setAddress`).
  void setAddressFor(String accountId,
      {required String district, required String neighborhood,
      String city = 'İzmir'}) {
    final acc = byId(accountId);
    if (acc == null) {
      return;
    }
    acc.address = Address(
      id: 'addr-${acc.id}',
      city: city,
      district: district,
      neighborhood: neighborhood,
    );
    notifyListeners();
  }

  void setAddress({
    required String district,
    required String neighborhood,
    String city = '',
  }) {
    final acc = currentAccount;
    if (acc == null) {
      return;
    }
    final existing = acc.address;
    if (existing == null) {
      acc.address = city.isEmpty
          ? Address(
              id: 'addr-${acc.id}',
              district: district,
              neighborhood: neighborhood,
            )
          : Address(
              id: 'addr-${acc.id}',
              city: city,
              district: district,
              neighborhood: neighborhood,
            );
    } else {
      existing.district = district;
      existing.neighborhood = neighborhood;
      // Boş il mevcut kaydı SİLMEZ.
      if (city.isNotEmpty) {
        existing.city = city;
      }
    }
    notifyListeners();
  }


  /// ⚠ BOŞ KÜME KABUL EDİLMEZ — SON HİZMET/İLÇE KORUNUR.
  ///
  /// Ekran düğmesi boş seçimde pasif olsa da otorite BURASIDIR:
  /// bu metot boş küme aldığında kategorileri/ilçeleri SİLİYORDU ve
  /// hizmet veren hizmetsiz kalabiliyordu.
  ///
  /// ⚠ İŞ KURALI: hizmet verenin en az bir kategorisi ve en az bir
  DomainError? setProviderPrefs(
      {Set<String>? categories, Set<String>? districts}) {
    final acc = currentAccount;
    if (acc == null) {
      return const UnauthorizedError('Oturum bulunamadı');
    }
    if (categories != null && categories.isEmpty) {
      return const ValidationError(FormMesaj.kategoriSec);
    }
    if (districts != null && districts.isEmpty) {
      return const ValidationError(FormMesaj.bolgeSec);
    }
    if (categories != null) acc.categories
      ..clear()
      ..addAll(categories);
    if (districts != null) acc.serviceDistricts
      ..clear()
      ..addAll(districts);
    notifyListeners();
    return null;
  }

  void logout() {
    currentAccount = null;
    notifyListeners();
  }
}
