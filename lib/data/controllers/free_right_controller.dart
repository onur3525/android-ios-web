import '../models/free_right.dart';
import '../ports/repository_ports.dart';
import 'base_controller.dart';
import '../../domain/failures.dart';

/// ÜCRETSİZ İLETİŞİM AÇMA HAKKI denetleyicisi.
///
/// ⚠ YALNIZ HİZMET VEREN görünümünde kullanılır.
/// Hizmet Alan tarafında hiçbir ekran bu denetleyiciyi okumaz —
/// müşteride cüzdan, bakiye, ledger ve ücretsiz hak GÖSTERİLMEZ.
///
/// Hak PARA DEĞİLDİR: cüzdan bakiyesi, jeton veya promosyon bakiyesi
/// değildir; nakde çevrilemez, devredilemez.
class FreeRightController extends BaseController {
  FreeRightController(this._port) : super(const []);
  final FreeRightPort _port;

  FreeRightSummary? _summary;
  FundingDecision? _funding;

  /// Kullanılabilir hak özeti. Yüklenmediyse `null`.
  FreeRightSummary? get summary => _summary;

  /// Teklif bedelinin kaynağı — SUNUCU belirler, istemci SEÇEMEZ.
  FundingDecision? get funding => _funding;

  /// Kalan hak adedi (TL değil). Bilinmiyorsa 0.
  int get remainingRights => _summary?.remainingRights ?? 0;

  /// Bu teklif ücretsiz hakla mı verilecek?
  /// Karar alınamadıysa **false** döner — güvenli taraf cüzdan akışıdır.
  bool get willUseFreeRight => _funding?.isFree ?? false;

  /// Hak özetini ve kaynak kararını sunucudan okur.
  ///
  /// Hata durumunda SESSİZCE BAŞARI DÖNMEZ: kaynak kararı cüzdana
  /// düşürülür ve `lastError` doldurulur; ekran bloke uyarısını gösterir.
  Future<DomainError?> load() => runLoad(() async {
        final (ozet, ozetErr) = await _port.summary();
        if (ozetErr != null) {
          _summary = null;
          _funding = _walletVarsayilani();
          return ozetErr;
        }
        _summary = ozet;

        final (karar, kararErr) = await _port.fundingPreview();
        if (kararErr != null) {
          _funding = _walletVarsayilani();
          return kararErr;
        }
        _funding = karar;
        return null;
      });

  /// Teklif verildikten sonra kalan hakkı tazeler.
  Future<void> refreshAfterOffer() async {
    await load();
  }

  /// Kaynak belirlenemediğinde GÜVENLİ varsayılan: cüzdan blokesi.
  /// Ücretsiz hak varmış gibi göstermek, kullanıcıyı yanıltır.
  FundingDecision _walletVarsayilani() => const FundingDecision(
        source: OfferFundingSource.wallet,
        aciklama: 'İletişim açma bedeli cüzdanınızda bloke edilecek.',
      );
}
