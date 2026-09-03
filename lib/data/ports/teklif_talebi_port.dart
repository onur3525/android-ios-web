import 'package:flutter/foundation.dart';

import '../../domain/failures.dart';
import '../models/teklif_talebi.dart';
import '../repositories/teklif_talebi_repository.dart';

/// ── ⚠ MEVCUT PORT MİMARİSİYLE AYNI ŞEKİL ──
///
/// Projedeki her özellik (`OfferPort`, `NotificationPort`...) bir
/// PORT arayüzü + MOCK/API uygulaması üzerinden çalışır. Bu yeni
/// özellik de AYNI ŞEKİLDE kuruldu: gerçek backend geldiğinde
/// yalnız `ApiTeklifTalebiPort` gibi yeni bir sınıf eklenir,
/// `TeklifTalebiController` ve ekranlar DEĞİŞMEZ.
///
/// Ayrı bir dosyada tutuldu — mevcut `repository_ports.dart` /
/// `mock_ports.dart` dosyalarına DOKUNULMADI.
abstract class TeklifTalebiPort extends ChangeNotifier {
  List<TeklifTalebi> byHizmetAlan(String hizmetAlanId);
  List<TeklifTalebi> bySaglayici(String saglayiciId);
  TeklifTalebi? byId(String id);

  Future<DomainError?> gonder({
    required String hizmetAlanId,
    required String saglayiciId,
    required String saglayiciAdi,
    required String kategori,
    required String hizmet,
    required String aciklama,
    required IletisimTercihi iletisimTercihi,
    List<String> fotograflar,
  });

  Future<DomainError?> teklifVer(String id,
      {required int fiyat, required String aciklama});
  Future<DomainError?> secToVer(String id);
  Future<DomainError?> reddet(String id);
  Future<DomainError?> tamamla(String id);

  /// ⚠ Yalnız `teklifTarihi` dolduktan SONRA gerçek gönderim yapar
  /// (bkz. repository).
  Future<DomainError?> mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu});
}

class MockTeklifTalebiPort extends TeklifTalebiPort {
  MockTeklifTalebiPort(this._repo) {
    _repo.addListener(notifyListeners);
  }

  final TeklifTalebiRepository _repo;

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  List<TeklifTalebi> byHizmetAlan(String hizmetAlanId) =>
      _repo.byHizmetAlan(hizmetAlanId);

  @override
  List<TeklifTalebi> bySaglayici(String saglayiciId) =>
      _repo.bySaglayici(saglayiciId);

  @override
  TeklifTalebi? byId(String id) => _repo.byId(id);

  @override
  Future<DomainError?> gonder({
    required String hizmetAlanId,
    required String saglayiciId,
    required String saglayiciAdi,
    required String kategori,
    required String hizmet,
    required String aciklama,
    required IletisimTercihi iletisimTercihi,
    List<String> fotograflar = const [],
  }) async {
    _repo.create(
      hizmetAlanId: hizmetAlanId,
      saglayiciId: saglayiciId,
      saglayiciAdi: saglayiciAdi,
      kategori: kategori,
      hizmet: hizmet,
      aciklama: aciklama,
      iletisimTercihi: iletisimTercihi,
      fotograflar: fotograflar,
    );
    return null;
  }

  @override
  Future<DomainError?> teklifVer(String id,
      {required int fiyat, required String aciklama}) async {
    _repo.teklifVer(id, fiyat: fiyat, aciklama: aciklama);
    return null;
  }

  @override
  Future<DomainError?> secToVer(String id) async {
    _repo.secToVer(id);
    return null;
  }

  @override
  Future<DomainError?> reddet(String id) async {
    _repo.reddet(id);
    return null;
  }

  @override
  Future<DomainError?> tamamla(String id) async {
    _repo.tamamla(id);
    return null;
  }

  @override
  Future<DomainError?> mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu}) async {
    _repo.mesajGonder(id,
        gonderenId: gonderenId, metin: metin, fotografYolu: fotografYolu);
    return null;
  }
}
