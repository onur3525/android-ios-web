import '../models/chat.dart';
import '../models/listing.dart';
import '../models/notification.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../models/teklif_talebi.dart';

/// ═══════════════════════════════════════════════════════════════
/// SEKME ANLIĞI — mock verinin JSON karşılığı (YALNIZ WEB + MOCK)
///
/// Mobil tarayıcıda "Masaüstü sitesi" geçişi/yenileme sayfayı baştan
/// yükler; mock modda bütün veri bellekte olduğundan ilanlar, teklifler,
/// sohbetler, talepler, bildirimler ve yorumlar kayboluyordu. Bu dosya
/// onları sekmeye özel depoya (sessionStorage) yazılabilir biçime çevirir;
/// açılışta geri yüklenir (bkz. main.dart). Sekme kapanınca silinir.
///
/// ⚠ Bozuk/eksik kayıt açılışı KİLİTLEMEZ: çözülemeyen öğe atlanır.
/// ⚠ API modunda KULLANILMAZ (veri sunucudadır).
/// ═══════════════════════════════════════════════════════════════

String? _t(DateTime? d) => d?.toIso8601String();
DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;
T? _e<T extends Enum>(List<T> values, Object? v) {
  for (final x in values) {
    if (x.name == v) {
      return x;
    }
  }
  return null;
}

Map<String, dynamic> ilanJson(Listing l) => {
      'id': l.id, 'ilanNo': l.ilanNo, 'ownerId': l.ownerId, 'title': l.title,
      'location': l.location, 'desc': l.desc, 'status': l.status.name,
      'photoPaths': l.photoPaths, 'selectedOfferId': l.selectedOfferId,
      'iletisimTercihi': l.iletisimTercihi.name, 'isZamani': l.isZamani?.name,
      'createdAt': _t(l.createdAt),
    };

Listing ilanCoz(Map<String, dynamic> j) => Listing(
      id: j['id'] as String,
      ilanNo: j['ilanNo'] as String,
      ownerId: j['ownerId'] as String,
      title: j['title'] as String,
      location: j['location'] as String,
      desc: j['desc'] as String,
      status: _e(ListingStatus.values, j['status']) ?? ListingStatus.active,
      isZamani: _e(IsZamani.values, j['isZamani']),
      iletisimTercihi: _e(IletisimTercihi.values, j['iletisimTercihi']) ?? IletisimTercihi.telefonGoster,
      photoPaths: ((j['photoPaths'] as List?) ?? const []).map((e) => '$e').toList(),
      createdAt: _d(j['createdAt']),
    )..selectedOfferId = j['selectedOfferId'] as String?;

Map<String, dynamic> teklifJson(Offer o) => {
      'id': o.id, 'listingId': o.listingId, 'providerId': o.providerId,
      'amount': o.amount, 'note': o.note, 'status': o.status.name, 'createdAt': _t(o.createdAt),
    };

Offer teklifCoz(Map<String, dynamic> j) => Offer(
      id: j['id'] as String,
      listingId: j['listingId'] as String,
      providerId: j['providerId'] as String,
      amount: (j['amount'] as num).toInt(),
      note: (j['note'] ?? '') as String,
      status: _e(OfferStatus.values, j['status']) ?? OfferStatus.active,
      createdAt: _d(j['createdAt']),
    );

Map<String, dynamic> mesajJson(ChatMessage m) => {
      'id': m.id, 'senderId': m.senderId, 'text': m.text, 'imagePath': m.imagePath, 'status': m.status.name,
    };

ChatMessage mesajCoz(Map<String, dynamic> j) => ChatMessage(
      id: j['id'] as String,
      senderId: j['senderId'] as String,
      text: j['text'] as String?,
      imagePath: j['imagePath'] as String?,
      status: _e(MessageStatus.values, j['status']) ?? MessageStatus.sent,
    );

Map<String, dynamic> bildirimJson(AppNotification n) => {
      'id': n.id, 'userId': n.userId, 'type': n.type.name, 'title': n.title,
      'body': n.body, 'refId': n.refId, 'read': n.read,
    };

AppNotification? bildirimCoz(Map<String, dynamic> j) {
  final tur = _e(NotifType.values, j['type']);
  if (tur == null) {
    return null;
  }
  return AppNotification(
    id: j['id'] as String,
    userId: j['userId'] as String,
    type: tur,
    title: j['title'] as String,
    body: j['body'] as String,
    refId: j['refId'] as String?,
    read: j['read'] == true,
  );
}

Map<String, dynamic> yorumJson(Review r) => {
      'id': r.id, 'listingId': r.listingId, 'offerId': r.offerId, 'talepId': r.talepId,
      'providerId': r.providerId, 'authorId': r.authorId, 'stars': r.stars, 'text': r.text,
      'status': r.status?.name, 'publishedAt': _t(r.publishedAt), 'createdAt': _t(r.createdAt),
    };

Review yorumCoz(Map<String, dynamic> j) => Review(
      id: j['id'] as String,
      listingId: j['listingId'] as String?,
      offerId: j['offerId'] as String?,
      talepId: j['talepId'] as String?,
      providerId: j['providerId'] as String,
      authorId: j['authorId'] as String,
      stars: (j['stars'] as num).toInt(),
      status: _e(ReviewStatus.values, j['status']),
      publishedAt: _d(j['publishedAt']),
      text: (j['text'] ?? '') as String,
      createdAt: _d(j['createdAt']),
    );

Map<String, dynamic> talepJson(TeklifTalebi t) => {
      'id': t.id, 'talepNo': t.talepNo, 'hizmetAlanId': t.hizmetAlanId, 'saglayiciId': t.saglayiciId,
      'saglayiciAdi': t.saglayiciAdi, 'kategori': t.kategori, 'hizmet': t.hizmet, 'aciklama': t.aciklama,
      'iletisimTercihi': t.iletisimTercihi.name, 'createdAt': _t(t.createdAt), 'fotograflar': t.fotograflar,
      'isZamani': t.isZamani?.name, 'durum': t.durum.name, 'teklifFiyati': t.teklifFiyati,
      'teklifAciklamasi': t.teklifAciklamasi, 'teklifTarihi': _t(t.teklifTarihi), 'redGerekcesi': t.redGerekcesi,
      'mesajlar': [
        for (final m in t.mesajlar)
          {'id': m.id, 'gonderenId': m.gonderenId, 'zaman': _t(m.zaman), 'metin': m.metin, 'fotografYolu': m.fotografYolu, 'durum': m.durum.name},
      ],
    };

TeklifTalebi talepCoz(Map<String, dynamic> j) => TeklifTalebi(
      id: j['id'] as String,
      talepNo: j['talepNo'] as String,
      hizmetAlanId: j['hizmetAlanId'] as String,
      saglayiciId: j['saglayiciId'] as String,
      saglayiciAdi: (j['saglayiciAdi'] ?? '') as String,
      kategori: j['kategori'] as String,
      hizmet: j['hizmet'] as String,
      aciklama: j['aciklama'] as String,
      iletisimTercihi: _e(IletisimTercihi.values, j['iletisimTercihi']) ?? IletisimTercihi.yalnizMesaj,
      createdAt: _d(j['createdAt']) ?? DateTime.now(),
      fotograflar: ((j['fotograflar'] as List?) ?? const []).map((e) => '$e').toList(),
      isZamani: _e(IsZamani.values, j['isZamani']),
      durum: _e(TeklifTalebiDurumu.values, j['durum']) ?? TeklifTalebiDurumu.beklemede,
      teklifFiyati: (j['teklifFiyati'] as num?)?.toInt(),
      teklifAciklamasi: j['teklifAciklamasi'] as String?,
      teklifTarihi: _d(j['teklifTarihi']),
      redGerekcesi: j['redGerekcesi'] as String?,
      mesajlar: [
        for (final m in ((j['mesajlar'] as List?) ?? const []).whereType<Map<String, dynamic>>())
          TeklifMesaj(
            id: m['id'] as String,
            gonderenId: m['gonderenId'] as String,
            zaman: _d(m['zaman']) ?? DateTime.now(),
            metin: m['metin'] as String?,
            fotografYolu: m['fotografYolu'] as String?,
            durum: _e(TeklifMesajDurumu.values, m['durum']) ?? TeklifMesajDurumu.gonderildi,
          ),
      ],
    );
