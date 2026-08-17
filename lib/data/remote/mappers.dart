import '../models/account.dart';
import '../models/chat.dart';
import '../models/listing.dart';
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../models/wallet.dart';

/// Sunucu JSON'u → mevcut Flutter modelleri. Modeller DEĞİŞTİRİLMEDİ;
/// alan adları backend sözleşmesine göre eşlenir.
abstract final class Mappers {
  static DateTime _date(dynamic v) =>
      v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();

  static ListingStatus listingStatus(String s) => switch (s) {
        'OPEN' => ListingStatus.open,
        'PROVIDER_SELECTED' => ListingStatus.providerSelected,
        'IN_PROGRESS' => ListingStatus.inProgress,
        'COMPLETED' => ListingStatus.completed,
        'CANCELLED' => ListingStatus.cancelled,
        'EXPIRED' => ListingStatus.expired,
        _ => ListingStatus.open,
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
        photoPaths: ((j['photoPaths'] ?? const []) as List).cast<String>(),
        createdAt: _date(j['createdAt']),
      )..selectedOfferId = j['selectedOfferId'] as String?;

  static OfferStatus offerStatus(String s) => switch (s) {
        'SELECTED' => OfferStatus.selected,
        'CANCELLED' || 'WITHDRAWN' => OfferStatus.cancelled,
        _ => OfferStatus.active,
      };

  static Offer offer(Map<String, dynamic> j) => Offer(
        id: j['id'] as String,
        listingId: j['listingId'] as String,
        providerId: j['providerId'] as String,
        amount: (j['amountTl'] as num).toInt(),
        note: (j['note'] ?? '') as String,
        status: offerStatus((j['status'] ?? 'ACTIVE') as String),
        escrowBlocked: (j['escrowBlocked'] ?? true) as bool,
        escrowConsumed: (j['escrowConsumed'] ?? false) as bool,
        createdAt: _date(j['createdAt']),
      );

  static TxKind txKind(String s) => switch (s) {
        'LOAD' => TxKind.load,
        'BLOCK' => TxKind.block,
        'CONTACT' => TxKind.contact,
        'REFUND' => TxKind.refund,
        _ => TxKind.load,
      };

  static WalletTx tx(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as String,
        kind: txKind((j['kind'] ?? 'LOAD') as String),
        title: (j['title'] ?? '') as String,
        sub: (j['detail'] ?? '') as String,
        amount: (j['amountTl'] as num).toInt(),
        // ⚠ SUNUCUNUN ZAMANI TAŞINIR.
        //
        // Alan yoksa `null` bırakılır ve model şimdiki zamanı kullanır
        // — sahte bir tarih UYDURULMAZ. Sunucu `createdAt` alanını
        // eklediğinde ekran kendiliğinden doğru tarihi gösterir.
        time: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal(),
      );

  /// Cüzdan + hareketler tek modele toplanır.
  static Wallet wallet(Map<String, dynamic> w, List<dynamic> ledger) {
    final out = Wallet(
      avail: (w['availTl'] as num?)?.toInt() ?? 0,
      blocked: (w['blockedTl'] as num?)?.toInt() ?? 0,
    );
    for (final e in ledger) {
      out.txs.add(tx(e as Map<String, dynamic>));
    }
    return out;
  }

  static Address address(Map<String, dynamic> j) => Address(
        id: j['id'] as String? ?? '',
        city: j['city'] as String? ?? 'İzmir',
        district: j['district'] as String? ?? '',
        neighborhood: j['neighborhood'] as String? ?? '',
      );

  static Role role(String s) => s == 'PROVIDER' ? Role.provider : Role.customer;  static String roleApi(Role r) => r == Role.provider ? 'PROVIDER' : 'CUSTOMER';

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
    );
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
        imagePath: j['storageRef'] as String?,
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
      escrowBlocked: (o['escrowBlocked'] ?? true) as bool,
      escrowConsumed: (o['escrowConsumed'] ?? false) as bool,
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
      );

  // ── bildirim ──
  static NotifType notifType(String s) => switch (s) {
        'NEW_OFFER' => NotifType.newOffer,
        'OFFER_SELECTED' => NotifType.offerSelected,
        'REFUND' => NotifType.refund,
        'CONTACT_OPENED' => NotifType.contactOpened,
        'NEW_MESSAGE' => NotifType.newMessage,
        'LISTING_EXPIRED' => NotifType.listingExpired,
        'ACCOUNT_STATUS' => NotifType.accountStatus,
        'CATEGORY_REQUEST' => NotifType.categoryRequest,
        'ANNOUNCEMENT' => NotifType.announcement,
        // BİLİNMEYEN tip uygulamayı çökertmez ve yanlış tipe eşlenmez.
        _ => NotifType.unknown,
      };

  static AppNotification notification(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: (j['userId'] ?? '') as String,
        type: notifType((j['type'] ?? '') as String),
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        refId: j['refId'] as String?,
        read: j['readAt'] != null || (j['read'] ?? false) as bool,
      );
}
