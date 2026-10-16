import 'dart:async';

import '../../domain/failures.dart';
import '../models/review.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';

/// Değerlendirmeler. Kurallar mock modda port'ta, API modunda sunucudadır.
/// Silinen (soft-deleted) yorumlar listelenmez ve ortalamaya girmez.
class ReviewController extends BaseController {
  final ReviewPort _reviews;
  ReviewController(this._reviews) : super([_reviews]);

  Review? byOffer(String offerId) => _reviews.byOffer(offerId);
  Review? byTalep(String talepId) => _reviews.byTalep(talepId);
  /// ── ⚠ HİZMET VERENİN YORUMLARI HER ZAMAN AÇIK (16 Eki, kullanıcı kuralı) ──
  /// "Hizmet alan, teklif veren kişinin yorumlarını, puanını ve bitirdiği
  /// iş sayısını iletişimi açmamış olsa da görebilmeli."
  ///
  /// API modunda bir hizmet verenin yorumları hiçbir ekranda sunucudan
  /// İSTENMİYORDU: gelen teklif, teklif talebi, sonuç listesi ve teklif
  /// iste ekranları boş depodan okuyup "— (0 yorum)" gösteriyordu. Sunucu
  /// ucu (`/providers/:id/reviews`) iletişim durumuna bakmaz.
  ///
  /// TEK KAYNAK: yorumu okuyan her ekran bu iki okuyucuyu kullanır; okuma
  /// ilk kez (ya da [_tazelemeAraligi]'ndan eski) yapılıyorsa yorumlar
  /// arka planda yüklenir, gelince ekranlar kendiliğinden yenilenir.
  /// Çizim sırasında bildirim yayılmasın diye yükleme bir sonraki
  /// mikro göreve bırakılır. Mock modda yükleme işlemsizdir.
  List<Review> byProvider(String providerId) {
    _gerekirseYukle(providerId);
    return _reviews.byProvider(providerId);
  }

  static const Duration _tazelemeAraligi = Duration(minutes: 1);
  final Map<String, DateTime> _sonIstek = {};

  void _gerekirseYukle(String providerId) {
    if (providerId.isEmpty) {
      return;
    }
    final simdi = DateTime.now();
    final son = _sonIstek[providerId];
    if (son != null && simdi.difference(son) < _tazelemeAraligi) {
      return;
    }
    _sonIstek[providerId] = simdi;
    scheduleMicrotask(() async {
      final err = await _reviews.loadForProvider(providerId);
      if (err != null) {
        // Başarısız okuma bir sonraki çizimde yeniden denenir (hata
        // bildirim yaymadığı için döngü oluşmaz).
        _sonIstek.remove(providerId);
      }
    });
  }

  /// Müşterinin YAZDIĞI değerlendirmeler — bkz. depo notu.
  List<Review> byAuthor(String authorId) => _reviews.byAuthor(authorId);
  double? averageOf(String providerId) {
    _gerekirseYukle(providerId);
    return _reviews.averageOf(providerId);
  }

  Future<DomainError?> loadForProvider(String providerId) =>
      runLoad(() => _reviews.loadForProvider(providerId));

  /// ⚠ İKİ MOD: `listingId`+`offerId` (normal akış) YA DA `talepId`
  /// ("Bul" doğrudan teklif akışı) — bkz. `ReviewPort.submit` notu.
  Future<DomainError?> submit({
    String? listingId,
    String? offerId,
    String? talepId,
    required String actorId,
    required int stars,
    required String text,
  }) =>
      runAction(
        'review:${offerId ?? talepId}',
        () => _reviews.submit(
            listingId: listingId, offerId: offerId, talepId: talepId,
            actorId: actorId, stars: stars, text: text),
      );
}
