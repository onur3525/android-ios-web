import 'package:flutter/foundation.dart';
import '../../domain/config.dart';
import 'package:uuid/uuid.dart';
import '../models/review.dart';

class ReviewRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, Review> _items = {}; // reviewId → Review

  Review? byOffer(String offerId) {
    for (final r in _items.values) {
      if (r.offerId == offerId) {
        return r;
      }
    }
    return null;
  }

  /// ⚠ `byOffer` İLE AYNI DESEN — "Bul" üzerinden doğrudan teklif
  /// akışının kendi eşdeğeri. Tek fark kaynak alanı (`talepId`).
  Review? byTalep(String talepId) {
    for (final r in _items.values) {
      if (r.talepId == talepId) {
        return r;
      }
    }
    return null;
  }

  /// HİZMET VERENE ULAŞAN değerlendirmeler.
  ///
  /// ── ⚠ 1 GÜN YAYIN GECİKMESİ (API sözleşmesi §14) ──
  ///
  /// "Değerlendirme Hizmet Veren'e 1 gün sonra yansır." Yorum anında
  /// KAYDEDİLİR — yazan kişi "Yorum Yapıldı" görür ve ikinci kez
  /// yazamaz — ama hizmet verenin profiline, ortalamasına ve yorum
  /// listesine süre dolmadan GİRMEZ.
  ///
  /// ⚠ Süzme TEK YERDE yapılır. Ortalama ve liste ayrı ayrı süzülseydi
  /// biri güncellenip öteki unutulabilirdi; ikisi de bu metottan
  /// beslenir.
  List<Review> byProvider(String providerId) {
    final sinir = DateTime.now().subtract(DomainConfig.yorumYayinGecikmesi);
    return _items.values
        .where((r) => r.providerId == providerId)
        // ⚠ `isBefore` DEĞİL `!isAfter`: gecikme sıfır olduğunda
        // sınır "şimdi"dir; aynı milisaniyede yazılan yorum
        // `isBefore` ile ELENİRDİ ve "anında yansısın" kuralı ilk
        // saniyede bozulurdu.
        .where((r) => !r.createdAt.isAfter(sinir))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// ⚠ YAYIN BEKLEYENLER DÂHİL — yalnız YAZAN kişiye gösterilir.
  ///
  /// Hizmet alan kendi yorumunu hemen görebilmeli ("Yorum Yapıldı"
  /// bilgisi buna dayanır); gecikme yalnız KARŞI TARAFA yansımayı
  /// erteler.
  List<Review> byProviderTumu(String providerId) =>
      _items.values.where((r) => r.providerId == providerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// MÜŞTERİNİN YAZDIĞI değerlendirmeler (yeniden eskiye).
  ///
  /// ⚠ `byProvider` ALINAN değerlendirmelerdir; bu ise VERİLEN.
  /// Hizmet alan kendi yazdıklarını görüntüler, düzenleyemez.
  List<Review> byAuthor(String authorId) =>
      _items.values.where((r) => r.authorId == authorId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Review create({
    String? listingId,
    String? offerId,
    String? talepId,
    required String providerId,
    required String authorId,
    required int stars,
    required String text,
  }) {
    final r = Review(
        id: _uuid.v4(), listingId: listingId, offerId: offerId,
        talepId: talepId, providerId: providerId, authorId: authorId,
        stars: stars, text: text);
    _items[r.id] = r;
    notifyListeners();
    return r;
  }
}
