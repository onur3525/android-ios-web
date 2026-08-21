/// Kullanıcı rolleri. Bir hesap BİRDEN FAZLA role sahip olabilir;
/// [Account.activeRole] o anda hangi panelde gezildiğini belirler.
enum Role { customer, provider }

/// TEK ADRES KURALI
/// Kullanıcının en fazla BİR adres kaydı olur ve adres yalnız
/// il / ilçe / mahalle seçiminden oluşur. Başlık (Ev, İşyeri) ve
/// serbest açık adres alanı YOKTUR.
class Address {
  final String id;
  String city;
  String district;
  String neighborhood;

  Address({
    required this.id,
    this.city = 'İzmir',
    required this.district,
    required this.neighborhood,
  });

  /// Ekranlarda tek satır gösterim: "Mahalle, İlçe / İl"
  String get display => '$neighborhood, $district / $city';

  bool get isComplete =>
      city.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      neighborhood.trim().isNotEmpty;
}

class Account {
  final String id;           // değişmez UUID
  String name;               // görünen ad (kayıtta ad soyad)
  String email;
  /// ── PROFİL FOTOĞRAFI ROL BAZLIDIR ──
  ///
  /// ⚠ TEK ALAN YETMİYORDU. Eskiden `photoPath` tekti; çift rollü
  /// kullanıcı hizmet alan rolünde fotoğraf yükleyince hizmet veren
  /// profilinde de AYNI fotoğraf görünüyordu. Oysa bunlar farklı
  /// kimliklerdir: biri kişisel, öteki iş profilidir.
  ///
  /// Her rolün fotoğrafı AYRI yüklenir, AYRI silinir, AYRI güncellenir.
  String _fotoAlan = '';
  String _fotoVeren = '';

  /// Belirtilen rolün fotoğrafı.
  String fotografi(Role r) => r == Role.provider ? _fotoVeren : _fotoAlan;

  /// Belirtilen rolün fotoğrafını yazar. Boş dize SİLME demektir.
  void fotografAta(Role r, String yol) {
    if (r == Role.provider) {
      _fotoVeren = yol;
    } else {
      _fotoAlan = yol;
    }
  }

  /// AKTİF ROLÜN fotoğrafı — eski `photoPath` sözleşmesi korunur.
  ///
  /// Ekranlar ve depolar bu adı kullanmaya devam eder; hangi rolün
  /// fotoğrafına yazdıkları `activeRole` ile belirlenir.
  String get photoPath => fotografi(activeRole);
  set photoPath(String v) => fotografAta(activeRole, v);
  String phone;              // 0'sız 10 hane — SMS doğrulamalı güncellenebilir
  /// TEK adres kaydı (yoksa null). Liste DEĞİLDİR — birden fazla adres
  /// tutulamaz; ekleme/silme akışı yoktur, yalnız güncelleme vardır.
  Address? address;

  /// ── BİLDİRİM TERCİHLERİ ──
  ///
  /// ⚠ Varsayılan AÇIK: kullanıcı teklif ve mesajlardan haberdar
  /// olmazsa pazaryeri işlemez. Kapatma kararı kullanıcınındır.
  ///
  /// ⚠ `bildirimHesap` KAPATILAMAZ ve burada tutulmaz: güvenlik ve
  /// hesap durumu bildirimleri (şifre değişikliği, hesap askıya alma)
  /// tercihe bağlı değildir.
  bool bildirimTeklif = true;
  bool bildirimMesaj = true;
  bool bildirimDuyuru = true;
  bool bildirimEposta = true;
  final Set<String> categories = {};    // hizmet veren kategorileri
  final Set<String> serviceDistricts = {}; // hizmet veren bölgeleri
  String passwordHash;       // düz metin şifre SAKLANMAZ (tuz + SHA-256)
  final String salt;
  final Set<Role> roles;
  Role activeRole;

  // ═══════════════════════════════════════════════════════════════
  // DOĞRULAMA DURUMLARI
  //
  // `emailVerified` ve `phoneVerified` AYRI tutulur; biri diğerini
  // ima etmez.
  // ═══════════════════════════════════════════════════════════════

  /// Telefon SMS OTP ile doğrulandı mı?
  ///
  /// ⚠ Doğrulanmamış numara "doğrulanmış" olarak KAYDEDİLMEZ.
  bool phoneVerified;

  /// E-posta doğrulandı mı?
  ///
  /// Normal kayıtta yalnız gerçek doğrulama işlemi başarıyla
  /// tamamlanınca `true` olur. Google akışında Google'ın doğrulanmış
  /// e-postası kabul edilir (ikinci doğrulama istenmez).
  ///
  /// ⚠ E-posta DEĞİŞİRSE `false`'a döner (bkz. `changeEmail`).
  bool emailVerified;

  /// DOĞRULANMAYI BEKLEYEN YENİ E-POSTA (K4).
  ///
  /// ⚠ `email` alanı DEĞİŞMEZ: yeni adres doğrulanana kadar hesabın
  /// geçerli e-postası eskisidir. Kullanıcı yanlış bir adres yazarsa
  /// doğrulanmış adresini KAYBETMEZ ve kurtarma kanalsız kalmaz.
  ///
  /// Doğrulama tamamlanınca `AuthRepository.epostaDogrula()` üç işi
  /// TEK ADIMDA yapar: eskisini bırak, yenisini bağla, doğrulanmış
  /// işaretle.
  String? bekleyenEposta;

  /// Kullanım Sözleşmesi ve Gizlilik Politikası kabul edildi mi?
  ///
  /// ⚠ Google ile kayıt bunu BYPASS ETMEZ.
  bool termsAccepted;

  // ⚠ `googleSub` KALDIRILDI — üçüncü taraf girişi yok.

  Account({
    required this.id,
    this.name = '',
    this.email = '',
    String photoPath = '',
    required this.phone,
    required this.passwordHash,
    required this.salt,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.termsAccepted = false,
    Set<Role>? roles,
    Role? activeRole,
  })  : roles = roles ?? {Role.customer},
        activeRole = activeRole ?? (roles ?? {Role.customer}).first {
    assert(this.roles.isNotEmpty, 'Hesabın en az bir rolü olmalı');
    if (!this.roles.contains(this.activeRole)) {
      this.activeRole = this.roles.first;
    }
    // ⚠ Kurucudaki fotoğraf AKTİF ROLE yazılır; diğer rol BOŞ kalır.
    // Rollerin fotoğrafı asla birbirine kopyalanmaz.
    if (photoPath.isNotEmpty) {
      fotografAta(this.activeRole, photoPath);
    }
  }

  bool get isProvider => roles.contains(Role.provider);
  bool get isCustomer => roles.contains(Role.customer);

  // ═══════════════════════════════════════════════════════════════
  // ONBOARDING (KAYIT TAMAMLANMA) DURUMU
  //
  // ⚠ Yalnız UI kontrolüne güvenilmez: bu kurallar domain
  // katmanındadır ve kayıt/rol aktifleştirme akışları bunu kullanır.
  //
  // Google ile kayıt HİÇBİR zorunluluğu bypass ETMEZ; tek fark
  // Google'ın doğrulanmış e-postası için ikinci doğrulama
  // istenmemesidir (`emailVerified` zaten true gelir).
  // ═══════════════════════════════════════════════════════════════

  /// Her iki rol için ORTAK zorunluluklar.
  ///
  /// Ad, Soyad, Telefon, E-posta, İl/İlçe/Mahalle, SMS OTP,
  /// e-posta doğrulaması ve sözleşme onayı.
  bool get _ortakTamam =>
      name.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      phoneVerified &&
      emailVerified &&
      termsAccepted &&
      (address?.isComplete ?? false);

  /// Müşteri (Hizmet Alan) kaydı tamamlandı mı?
  bool get customerOnboardingComplete => _ortakTamam;

  /// Hizmet Veren rolü aktif edilebilir mi?
  ///
  /// Ortak zorunluluklara EK OLARAK hizmet kategorisi ve hizmet
  /// bölgesi seçimi gerekir.
  bool get providerOnboardingComplete =>
      _ortakTamam && categories.isNotEmpty && serviceDistricts.isNotEmpty;

  /// Aktif role göre kayıt tamamlanmış mı?
  bool get onboardingComplete => activeRole == Role.provider
      ? providerOnboardingComplete
      : customerOnboardingComplete;

  /// Eksik kalan zorunlu adımlar — kullanıcı doğru adıma yönlendirilir.
  ///
  /// Yarım kayıt tekrar açıldığında tamamlanan bilgiler KAYBOLMAZ;
  /// bu liste yalnız eksikleri söyler.
  List<OnboardingStep> get missingSteps {
    final eksik = <OnboardingStep>[];
    if (name.trim().isEmpty) {
      eksik.add(OnboardingStep.name);
    }
    if (email.trim().isEmpty) {
      eksik.add(OnboardingStep.email);
    } else if (!emailVerified) {
      eksik.add(OnboardingStep.emailVerification);
    }
    if (phone.trim().isEmpty) {
      eksik.add(OnboardingStep.phone);
    } else if (!phoneVerified) {
      eksik.add(OnboardingStep.phoneVerification);
    }
    if (!(address?.isComplete ?? false)) {
      eksik.add(OnboardingStep.address);
    }
    if (!termsAccepted) {
      eksik.add(OnboardingStep.terms);
    }
    if (activeRole == Role.provider) {
      if (categories.isEmpty) {
        eksik.add(OnboardingStep.providerCategories);
      }
      if (serviceDistricts.isEmpty) {
        eksik.add(OnboardingStep.providerAreas);
      }
    }
    return eksik;
  }
}

/// Kayıt akışında eksik kalabilecek zorunlu adımlar.
enum OnboardingStep {
  name,
  email,
  emailVerification,
  phone,
  phoneVerification,
  address,
  terms,
  providerCategories,
  providerAreas;

  /// Kullanıcıya gösterilecek kısa açıklama.
  String get label => switch (this) {
        OnboardingStep.name => 'Ad ve soyad',
        OnboardingStep.email => 'E-posta adresi',
        OnboardingStep.emailVerification => 'E-posta doğrulaması',
        OnboardingStep.phone => 'Telefon numarası',
        OnboardingStep.phoneVerification => 'SMS doğrulaması',
        OnboardingStep.address => 'İl / İlçe / Mahalle',
        OnboardingStep.terms => 'Sözleşme onayı',
        OnboardingStep.providerCategories => 'Hizmet kategorileri',
        OnboardingStep.providerAreas => 'Hizmet bölgeleri',
      };
}
