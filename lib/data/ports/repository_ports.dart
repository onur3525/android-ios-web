import 'package:flutter/foundation.dart';

import '../../domain/failures.dart';
import '../models/account.dart';
import '../models/region.dart';
import '../models/provider_approval.dart';
import '../models/listing.dart';
import '../models/teklif_talebi.dart' show IletisimTercihi;
import '../models/chat.dart';
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../../domain/sohbet_okunmamis.dart';

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

  /// ── ⚠ "BUL" AKIŞI — GERÇEK HİZMET VEREN EŞLEŞMESİ ──
  ///
  /// Bkz. `AuthRepository.saglayicilarKimSunuyor` — aynı kural.
  List<Account> saglayicilarKimSunuyor(String kategori, String hizmet,
      {required String haricTutulacakId});

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

  /// KAYIT — telefon doğrulaması (OTP/kayıt yetkisi) ile.
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

    /// Kullanım Sözleşmesi onayı (ZORUNLU). 18 yaş koşulu sözleşmenin
    /// 4. maddesindedir; ayrı yaş beyanı alınmaz (16 Eki).
    bool termsAccepted,

    /// Yalnız gerçek doğrulama tamamlanınca true olur.
    bool emailVerified,

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
  ///
  /// ⚠ [mevcutSifre] (15 Eki): sunucu numara değişiminde MEVCUT ŞİFREYİ de
  /// doğrular — çalınmış oturumla numara değiştirip şifre sıfırlayarak hesap
  /// ele geçirilemesin. Ekran şifreyi ortak panelle (`sifreIleDogrula`) alır.
  Future<DomainError?> telefonDegisimiDogrula(String challengeId, String kod,
      {String? mevcutSifre});

  /// HESAP KURTARMA — telefona kod gönderir (nötr cevap).
  Future<({String challengeId})> hesapKurtarmaKodGonder(String phone);

  /// Kod doğruysa KURTARMA YETKİSİ üretir.
  /// ⚠ OTURUM AÇMAZ; yalnız telefon sahipliğini doğrular.
  Future<({String? yetki, DomainError? error})> hesapKurtarmaDogrula(
      String challengeId, String kod);

  /// Kurtarma yetkisiyle yeni şifre belirler. ⚠ Oturum açmaz.
  Future<DomainError?> kurtarmaSifreBelirle(String yetki, String yeniSifre);
  Future<DomainError?> switchRole(Role role);

  /// İkinci rolü aynı hesaba ekler (eksik rol tamamlama akışı).
  ///
  /// [sifre] ve [telefonKaniti] yalnız [rolEklemeDogrulamaIster] true
  /// olan uygulamada (API) kullanılır: sunucu şifreyi ve YENİ bir
  /// telefon doğrulamasının kanıtını (Firebase ID token) ister.
  Future<DomainError?> addRole(
    Role role, {
    Set<String>? categories,
    Set<String>? serviceDistricts,
    String? sifre,
    String? telefonKaniti,
  });

  /// Rol eklemeden önce şifre + SMS doğrulaması gerekiyor mu?
  /// Mock (bellek içi) uygulamada gerekmez; API'de sunucu ister.
  bool get rolEklemeDogrulamaIster => false;

  /// Rol ekleme için hesabın kayıtlı telefonuna SMS kodu gönderir.
  Future<({String? challengeId, DomainError? error})> rolEklemeKodGonder() async =>
      (challengeId: null, error: const ValidationError('Bu işlem için doğrulama gerekmiyor'));

  /// Kodu doğrular; başarıda sunucuya gidecek telefon kanıtını döner.
  Future<({String? kanit, DomainError? error})> rolEklemeKodDogrula(
          String challengeId, String kod) async =>
      (kanit: null, error: const ValidationError('Bu işlem için doğrulama gerekmiyor'));
  Future<DomainError?> changePassword(String current, String next);

  /// ŞİFRE DOĞRULAMA — KRİTİK İŞLEM KAPISI.
  ///
  /// ⚠ Hesap silme gibi geri alınamaz işlemler doğrulamasız
  /// yapılmaz: telefonu açık bırakılmış bir kullanıcının hesabı
  /// üç dokunuşla kapatılabilirdi.
  ///
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
  Future<DomainError?> updateProfile({String? name, String? photoPath});

  /// E-POSTA DEĞİŞİMİ — yeni adrese doğrulama bağlantısı yollar.
  ///
  /// ⚠ Hesabın e-postası bu çağrıyla DEĞİŞMEZ; bağlantı tıklanana
  /// kadar eski adres geçerlidir (iş kuralları §4).
  ///
  /// ⚠ 21 Eki (güvenlik Y2): mevcut şifre ZORUNLU; sunucu doğrular.
  Future<DomainError?> epostaDegisimiBaslat(String yeniEposta,
      {required String sifre});
  Future<DomainError?> mevcutEpostaDogrulamaGonder(String mevcutEposta);

  /// E-POSTA ONAYI EŞİTLEME (21 Eki): bağlantıya tıklanınca doğrulama
  /// Firebase'de olur; sunucudaki hesap bununla eşitlenir ve ekran
  /// "onaylı" durumuna geçer. Mock modda yapılacak bir şey yoktur.
  Future<void> epostaOnayiniEsitle() async {}
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
    // ⚠ YENİ — bkz. `ListingController.publish` notu.
    IletisimTercihi? iletisimTercihi,
  });
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

  /// ── YENİ MESAJ SAYISI — TEK KAYNAK (29 Eki) ──
  ///
  /// Bir teklifin sohbetinde karşı taraftan gelip okunmamış mesaj
  /// sayısı. Varsayılan: yüklenmiş konuşmadan sayılır (mock). API portu
  /// sunucunun sohbet listesindeki sayıyla birleştirir — açılmamış
  /// sohbetteki mesaj da sayılır.
  int okunmamisMesaj(String offerId, String benimId) =>
      okunmamisSohbetMesaji(threadFor(offerId), benimId);

  /// Bir ilanın bütün tekliflerindeki okunmamış mesajların toplamı
  /// (hizmet alanın "İlanlarım" kartı).
  int ilanOkunmamisMesaj(String listingId, String benimId) => conversationsFor(benimId)
      .where((o) => o.listingId == listingId)
      .fold(0, (t, o) => t + okunmamisMesaj(o.id, benimId));
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

  /// ⚠ "Bul" üzerinden doğrudan teklif akışının kendi eşdeğeri —
  /// `byOffer` İLE AYNI DESEN.
  Review? byTalep(String talepId);

  /// ⚠ İKİ MOD: `listingId`+`offerId` (normal akış) YA DA `talepId`
  /// ("Bul" doğrudan teklif akışı) — TAM OLARAK BİRİ dolu olmalı.
  /// Eskiden yalnız ilk modu desteklerdi; ikinci mod EKLENDİ, ilk
  /// modun sözleşmesi DEĞİŞMEDİ.
  Future<DomainError?> submit({
    String? listingId,
    String? offerId,
    String? talepId,
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

  /// Sayfa görüldü → o sayfaya ait okunmamış bildirimler okundu.
  /// Hangi sayfanın hangi bildirimleri gördüğü SUNUCUDA tanımlıdır
  /// (backend `SAYFA_BILDIRIMLERI`, tek kaynak). Varsayılan: bir şey
  /// yapmaz (mock — dağıtılan pakette yok).
  Future<DomainError?> sayfaGoruldu(String sayfa, String refId) async => null;
}

/// BÖLGE VERİSİ PORTU — şehir/ilçe/mahalle tek kaynaktan okunur.
abstract class RegionPort {
  /// Aktif bölge ağacı. Hata durumunda ikinci eleman dolu döner.
  Future<(RegionTree?, DomainError?)> regionTree();
}

