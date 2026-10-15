import '../models/account.dart';
import 'gorsel_adresi.dart';
import '../models/chat.dart';
import '../models/listing.dart';
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/teklif_talebi.dart' show IletisimTercihi;
import '../models/review.dart';

abstract final class Mappers {
  static DateTime _date(dynamic v) =>
      v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();

  /// ── ⚠ NİHAİ DURUM EŞLEMESİ (API sözleşmesi §24) ──
  ///
  /// Sunucu dört değer gönderir: ACTIVE · EXPIRED · USER_DELETED ·
  /// ADMIN_REMOVED.
  ///
  /// ⚠ ESKİ DEĞERLER SESSİZCE ÇEVRİLMEZ. Backend geçiş döneminde
  /// `OPEN`, `PROVIDER_SELECTED`, `IN_PROGRESS`, `COMPLETED` ya da
  /// `CANCELLED` gönderirse:
  ///   · `OPEN`     → `active` (ad değişikliği; anlam AYNI)
  ///   · `CANCELLED`→ `userDeleted` (kullanıcı kapatması)
  ///   · ötekiler   → `active` ama ⚠ TAMAMLANMIŞLIK BİLGİSİ BURADAN
  ///     GELMEZ; `selectedOfferId` alanından türetilir. Yani
  ///     `COMPLETED` gelen bir ilan sessizce "tamamlanmadı" sayılmaz —
  ///     seçilmiş teklifi varsa tamamlanmış görünmeye devam eder.
  ///
  /// ⚠ BACKEND'E NOT: bu uyumluluk eşlemesi geçicidir. Sunucu nihai
  /// dört değere geçtiğinde eski satırlar kaldırılmalıdır.
  ///
  /// ⚠ Tanınmayan değerde `active` seçilir — güvenli taraf: ilan
  /// görünür kalır, kullanıcı verisi kaybolmuş gibi olmaz.
  static ListingStatus listingStatus(String s) => switch (s) {
        'ACTIVE' || 'OPEN' => ListingStatus.active,
        'EXPIRED' => ListingStatus.expired,
        'USER_DELETED' || 'CANCELLED' => ListingStatus.userDeleted,
        'ADMIN_REMOVED' => ListingStatus.adminRemoved,
        // Eski iş-gidişatı değerleri: yaşam durumu ACTIVE'dir.
        'PROVIDER_SELECTED' || 'IN_PROGRESS' || 'COMPLETED' =>
          ListingStatus.active,
        _ => ListingStatus.active,
      };

  static Listing listing(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
        // ⚠ NUMARAYI SUNUCU ÜRETİR.
        //
        // İstemci burada numara UYDURMAZ: alan gelmezse boş kalır ve
        // ekranlar numarayı çizmez. Sahte bir referans göstermek,
        // destek süreçlerinde yanlış ilana bakılmasına yol açar.
        ilanNo: (j['ilanNo'] ?? j['listingNo'] ?? '') as String,
        ownerId: j['ownerId'] as String,
        title: j['title'] as String,
        location: j['location'] as String,
        desc: (j['description'] ?? j['desc'] ?? '') as String,
        status: listingStatus((j['status'] ?? 'OPEN') as String),
        // Görüntüleme için imzalı adres (varsa) — bkz. gorsel_adresi.dart.
        photoPaths: gorselYollari(j['photoPaths'], j['photoUrls']),
        // ⚠ ALAN YOKSA `null` KALIR: seçim yapılmamış demektir ve
        // bilinmeyen bir değer gelirse de `null` döner (uygulama
        // çökmez, yalnız etiket gösterilmez).
        isZamani: IsZamani.koddan(j['workTiming'] as String?),
        // 16 Eki: alan yoksa (eski sunucu) telefon görünür — önceki davranış.
        iletisimTercihi: j['iletisimTercihi'] == 'yalnizMesaj'
            ? IletisimTercihi.yalnizMesaj
            : IletisimTercihi.telefonGoster,
        createdAt: _date(j['createdAt']),
      )..selectedOfferId = j['selectedOfferId'] as String?;

  /// ── ⚠ NİHAİ TEKLİF DURUMU (API sözleşmesi §24) ──
  ///
  /// ACTIVE · SELECTED · EXPIRED · CLOSED.
  ///
  /// ⚠ `WITHDRAWN` ve `CANCELLED` NİHAİ SÖZLEŞMEDE YOKTUR. Geçiş
  /// döneminde sunucu gönderirse `closed`a eşlenir — ikisi de
  /// "sistemsel kapanış" anlamına gelir. `expired` ile
  /// KARIŞTIRILMAZ: o yalnız 30 saat dolumu içindir.
  ///
  /// ⚠ BACKEND'E NOT: eski iki değer sunucudan kalktığında bu satır
  /// da kaldırılmalıdır.
  static OfferStatus offerStatus(String s) => switch (s) {
        'ACTIVE' => OfferStatus.active,
        'SELECTED' => OfferStatus.selected,
        'EXPIRED' => OfferStatus.expired,
        'CLOSED' || 'CANCELLED' || 'WITHDRAWN' => OfferStatus.closed,
        _ => OfferStatus.active,
      };

  static Offer offer(Map<String, dynamic> j) => Offer(
        id: j['id'] as String,
        listingId: j['listingId'] as String,
        providerId: j['providerId'] as String,
        amount: (j['amountTl'] as num).toInt(),
        note: (j['note'] ?? '') as String,
        status: offerStatus((j['status'] ?? 'ACTIVE') as String),
        createdAt: _date(j['createdAt']),
      );

  static Address address(Map<String, dynamic> j) => Address(
        id: j['id'] as String? ?? '',
        city: j['city'] as String? ?? 'İzmir',
        district: j['district'] as String? ?? '',
        neighborhood: j['neighborhood'] as String? ?? '',
      );

  static Role role(String s) => s == 'PROVIDER' ? Role.provider : Role.customer;  static String roleApi(Role r) => r == Role.provider ? 'PROVIDER' : 'CUSTOMER';

  /// KARŞI TARAF ÖZETİ → Account (yalnız gösterim alanları).
  ///
  /// ⚠ E-posta hiç gelmez; telefon yalnız sunucu izin verdiyse gelir,
  /// aksi hâlde boş kalır (ekranlar boş telefonu "—"/kilitli gösterir).
  static Account kisiOzeti(Map<String, dynamic> j) {
    final a = Account(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      email: '',
      phone: (j['phone'] ?? '') as String,
      passwordHash: '',
      salt: '',
      roles: {Role.customer},
      tamamlananIs: (j['completedJobsAsProvider'] as num?)?.toInt() ?? 0,
      kayitTarihi: j['createdAt'] is String
          ? DateTime.tryParse(j['createdAt'] as String)
          : null,
    );
    a.tamamlananIsHizmetAlan =
        (j['completedJobsAsCustomer'] as num?)?.toInt() ?? 0;
    final adres = j['address'];
    if (adres is Map<String, dynamic>) {
      a.address = address(adres);
    }
    final foto = j['photos'];
    if (foto is Map) {
      a.fotografAta(Role.customer, foto['customer'] is String ? foto['customer'] as String : '');
      a.fotografAta(Role.provider, foto['provider'] is String ? foto['provider'] as String : '');
    }
    return a;
  }

  /// Sunucudaki kullanıcı → Account. ŞİFRE ALANLARI BOŞ BIRAKILIR:
  /// istemci şifre hash'i tutmaz.
  static Account account(Map<String, dynamic> j) {
    final roles = ((j['roles'] ?? const []) as List)
        .map((e) => role(e as String))
        .toSet();
    final a = Account(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      phone: (j['phone'] ?? '') as String,
      passwordHash: '',
      salt: '',
      roles: roles.isEmpty ? {Role.customer} : roles,
      activeRole: role((j['activeRole'] ?? 'CUSTOMER') as String),
      // ⚠ Sunucu göndermezse `Account` kurucusu ŞİMDİKİ ZAMANI
      // varsayar — yanlış olabilir ama çökmez.
      kayitTarihi: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'] as String)
          : null,
    );
    // Doğrulama durumları sunucudan (önceden okunmuyordu: API modunda her
    // hesap "doğrulanmamış" görünüyordu).
    a.phoneVerified = j['phoneVerified'] == true;
    a.emailVerified = j['emailVerified'] == true;
    // Profil fotoğrafları (rol bazlı) sunucudan imzalı adres olarak gelir.
    final foto = j['photos'];
    if (foto is Map) {
      a.fotografAta(Role.customer, foto['customer'] is String ? foto['customer'] as String : '');
      a.fotografAta(Role.provider, foto['provider'] is String ? foto['provider'] as String : '');
    }
    // Bildirim tercihleri sunucuda tutulur; alan yoksa (eski sunucu)
    // varsayılan AÇIK kalır.
    final tercih = j['notificationPrefs'];
    if (tercih is Map) {
      a.bildirimTeklif = tercih['offer'] != false;
      a.bildirimMesaj = tercih['message'] != false;
      a.bildirimDuyuru = tercih['announcement'] != false;
      a.bildirimEposta = tercih['email'] != false;
    }
    final p = j['providerProfile'] as Map<String, dynamic>?;
    if (p != null) {
      a.categories.addAll(((p['categories'] ?? const []) as List).cast<String>());
      a.serviceDistricts.addAll(((p['districts'] ?? const []) as List).cast<String>());
    }
    return a;
  }

  // ── mesajlaşma ──
  static MessageStatus messageStatus(String s) => switch (s) {
        'SENDING' => MessageStatus.sending,
        'DELIVERED' => MessageStatus.delivered,
        'READ' => MessageStatus.read,
        'FAILED' => MessageStatus.failed,
        _ => MessageStatus.sent,
      };

  static ChatMessage message(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderId: (j['senderId'] ?? '') as String,
        text: j['text'] as String?,
        imagePath: gorselYolu(j['storageRef'], j['storageUrl']),
        status: messageStatus((j['status'] ?? 'SENT') as String),
      );

  /// Konuşma listesi öğesi — sunucu teklif özetini döndürür.
  static Offer conversationOffer(Map<String, dynamic> j) {
    final o = (j['offer'] ?? j) as Map<String, dynamic>;
    return Offer(
      id: o['id'] as String,
      listingId: (o['listingId'] ?? '') as String,
      providerId: (o['providerId'] ?? '') as String,
      amount: (o['amountTl'] as num?)?.toInt() ?? 0,
      note: (o['note'] ?? '') as String,
      status: offerStatus((o['status'] ?? 'ACTIVE') as String),
      createdAt: _date(o['createdAt']),
    );
  }

  // ── değerlendirme ──
  static Review review(Map<String, dynamic> j, {required String providerId}) => Review(
        id: j['id'] as String,
        listingId: (j['listingId'] ?? '') as String,
        offerId: (j['offerId'] ?? '') as String,
        providerId: providerId,
        authorId: (j['authorId'] ?? '') as String,
        stars: (j['stars'] as num).toInt(),
        text: (j['text'] ?? '') as String,
        // ⚠ YAYIN DURUMU SUNUCUDAN OKUNUR (§14).
        //
        // Alan gelmezse `null` bırakılır ve model yerel gecikme
        // kuralına düşer. Burada VARSAYIM YAPILMAZ: gelmeyen alanı
        // "yayınlandı" saymak, bekleyen yorumu erken göstermek olurdu.
        status: ReviewStatus.fromJson(j['status'] as String?),
        publishedAt: j['publishedAt'] == null
            ? null
            : DateTime.tryParse(j['publishedAt'] as String),
        // ⚠ SUNUCUNUN ZAMANI TAŞINIR.
        //
        // Okunmuyordu ve model her yorumu `DateTime.now()` ile
        // damgalıyordu: liste her açıldığında bütün yorumlar "az önce
        // yazılmış" görünüyor, 1 günlük yayın gecikmesi hiç dolmuyordu.
        //
        // Alan yoksa `null` bırakılır ve model şimdiki zamanı
        // kullanır — sahte bir tarih UYDURULMAZ.
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'] as String)?.toLocal(),
      );

  // ── bildirim ──
  /// Sunucu bildirim kodu → tür.
  ///
  /// ⚠ BUL AKIŞI AYRI KODLARLA GELİR (14 Eki): `TALEP_*`. Eskiden talep
  /// bildirimleri ilan kodlarıyla (`NEW_OFFER`…) yazılıyordu; uygulama
  /// onları İLAN bildirimi sanıp talep kimliğiyle ilan ekranını açıyordu
  /// ("alakasız ekran"). Eski kayıtlar için [hedef] (`target`/push
  /// `hedef`) `talep` ise ilan kodu talep türüne çevrilir.
  static NotifType notifType(String s, [String? hedef]) {
    if (hedef == 'talep') {
      switch (s) {
        case 'NEW_OFFER':
          return NotifType.teklifVerildi;
        case 'OFFER_SELECTED':
          return NotifType.teklifSecildi;
        case 'NEW_MESSAGE':
          return NotifType.teklifYeniMesaj;
      }
    }
    return _notifKodu(s);
  }

  static NotifType _notifKodu(String s) => switch (s) {
        'TALEP_REQUEST' => NotifType.teklifTalebiGeldi,
        'TALEP_OFFER' => NotifType.teklifVerildi,
        'TALEP_ACCEPTED' => NotifType.teklifSecildi,
        'TALEP_MESSAGE' => NotifType.teklifYeniMesaj,
        'NEW_OFFER' => NotifType.newOffer,
        'OFFER_SELECTED' => NotifType.offerSelected,
        'REFUND' => NotifType.refund,
        'CONTACT_OPENED' => NotifType.contactOpened,
        'NEW_MESSAGE' => NotifType.newMessage,
        'LISTING_EXPIRED' => NotifType.listingExpired,
        'ACCOUNT_STATUS' => NotifType.accountStatus,
        'CATEGORY_REQUEST' => NotifType.categoryRequest,
        'ANNOUNCEMENT' => NotifType.announcement,
        'NEW_LISTING' => NotifType.newListing,
        // BİLİNMEYEN tip uygulamayı çökertmez ve yanlış tipe eşlenmez.
        _ => NotifType.unknown,
      };

  static AppNotification notification(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: (j['userId'] ?? '') as String,
        type: notifType((j['type'] ?? '') as String, j['target'] as String?),
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        refId: j['refId'] as String?,
        read: j['readAt'] != null || (j['read'] ?? false) as bool,
        // ⚠ SUNUCUNUN ZAMANI (11 Eki): okunmazsa her bildirim liste
        // yüklendiği an gelmiş gibi görünüyordu.
        createdAt: j['createdAt'] is String
            ? DateTime.tryParse(j['createdAt'] as String)?.toLocal()
            : null,
      );
}
