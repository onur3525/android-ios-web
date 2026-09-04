import '../../domain/failures.dart';
import '../models/teklif_talebi.dart';
import '../ports/teklif_talebi_port.dart';
import 'base_controller.dart';

/// "Teklif İstediklerim" (hizmet alan) ve "Teklif İstekleri" (hizmet
/// veren) ekranlarının ortak denetleyicisi.
class TeklifTalebiController extends BaseController {
  final TeklifTalebiPort _port;
  TeklifTalebiController(this._port) : super([_port]);

  List<TeklifTalebi> byHizmetAlan(String hizmetAlanId) =>
      _port.byHizmetAlan(hizmetAlanId);
  List<TeklifTalebi> bySaglayici(String saglayiciId) =>
      _port.bySaglayici(saglayiciId);
  TeklifTalebi? byId(String id) => _port.byId(id);

  Future<DomainError?> gonder({
    required String hizmetAlanId,
    required String saglayiciId,
    required String saglayiciAdi,
    required String kategori,
    required String hizmet,
    required String aciklama,
    required IletisimTercihi iletisimTercihi,
    List<String> fotograflar = const [],
  }) =>
      runAction(
          'teklif-talebi-gonder',
          () => _port.gonder(
                hizmetAlanId: hizmetAlanId,
                saglayiciId: saglayiciId,
                saglayiciAdi: saglayiciAdi,
                kategori: kategori,
                hizmet: hizmet,
                aciklama: aciklama,
                iletisimTercihi: iletisimTercihi,
                fotograflar: fotograflar,
              ));

  Future<DomainError?> teklifVer(String id,
          {required int fiyat, required String aciklama}) =>
      runAction('teklif-ver-$id',
          () => _port.teklifVer(id, fiyat: fiyat, aciklama: aciklama));

  Future<DomainError?> secToVer(String id) =>
      runAction('teklif-sec-$id', () => _port.secToVer(id));
  Future<DomainError?> reddet(String id, {String? gerekce}) =>
      runAction('teklif-reddet-$id', () => _port.reddet(id, gerekce: gerekce));
  Future<DomainError?> tamamla(String id) =>
      runAction('teklif-tamamla-$id', () => _port.tamamla(id));

  /// ⚠ Her çağrı KENDİ anahtarını taşır (zaman damgalı) — art arda
  /// gönderilen mesajlar birbirini `runAction`ın tekilleştirme
  /// kilidiyle ENGELLEMEZ.
  Future<DomainError?> mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu}) {
    final anahtar =
        'teklif-mesaj-$id-${DateTime.now().microsecondsSinceEpoch}';
    return runAction(
        anahtar,
        () => _port.mesajGonder(id,
            gonderenId: gonderenId,
            metin: metin,
            fotografYolu: fotografYolu));
  }
}
