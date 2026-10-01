import 'dart:async';

import '../../domain/failures.dart';
import '../models/listing.dart' show IsZamani;
import '../models/teklif_talebi.dart';
import '../ports/teklif_talebi_port.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';

/// ═══════════════════════════════════════════════════════════════
/// TEKLİF TALEBİ — GERÇEK API PORTU (`/api/v1/teklif-talepleri`)
///
/// `MockTeklifTalebiPort` ile AYNI sözleşme (`TeklifTalebiPort`):
/// ekranlar ve `TeklifTalebiController` DEĞİŞMEDİ. Yalnız API modunda
/// (`ApiConfig.useRealApi`) kurulur; mock mod/web demosu aynen.
///
/// Okumalar (`byHizmetAlan`, `bySaglayici`, `byId`) senkron kalır:
/// önbellekten döner ve en fazla 15 sn'de bir arka planda tazelenir;
/// her yazma işleminden sonra sunucu yanıtı önbelleğe işlenir.
///
/// İş kuralları (durum makinesi, taraf denetimi, 30 saatlik teklif
/// süresi) SUNUCUDA zorlanır; burada yalnız yanıt eşlenir.
/// ═══════════════════════════════════════════════════════════════
class ApiTeklifTalebiPort extends TeklifTalebiPort {
  ApiTeklifTalebiPort(this._c);

  final ApiClient _c;
  final Map<String, TeklifTalebi> _onbellek = {};
  DateTime? _sonTazeleme;
  bool _tazeleniyor = false;

  static const _tazelemeAraligi = Duration(seconds: 15);

  void _gerekirseTazele() {
    final son = _sonTazeleme;
    if (_tazeleniyor || (son != null && DateTime.now().difference(son) < _tazelemeAraligi)) {
      return;
    }
    unawaited(yenile());
  }

  /// Sunucudan kullanıcının taraf olduğu bütün talepleri çeker.
  Future<void> yenile() async {
    _tazeleniyor = true;
    try {
      final liste = await _c.getList('/teklif-talepleri');
      _onbellek
        ..clear()
        ..addEntries(liste
            .whereType<Map<String, dynamic>>()
            .map(_talep)
            .map((t) => MapEntry(t.id, t)));
      _sonTazeleme = DateTime.now();
      notifyListeners();
    } catch (_) {
      // Ağ/oturum hatası: önbellek korunur; sonraki okumada yeniden denenir.
      _sonTazeleme = DateTime.now();
    } finally {
      _tazeleniyor = false;
    }
  }

  @override
  List<TeklifTalebi> byHizmetAlan(String hizmetAlanId) {
    _gerekirseTazele();
    return _onbellek.values.where((t) => t.hizmetAlanId == hizmetAlanId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  List<TeklifTalebi> bySaglayici(String saglayiciId) {
    _gerekirseTazele();
    return _onbellek.values.where((t) => t.saglayiciId == saglayiciId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  TeklifTalebi? byId(String id) {
    _gerekirseTazele();
    return _onbellek[id];
  }

  Future<DomainError?> _yaz(Future<Map<String, dynamic>> Function() f) async {
    try {
      final j = await f();
      if (j['id'] is String) {
        final t = _talep(j);
        _onbellek[t.id] = t;
        notifyListeners();
      }
      return null;
    } on ApiFailure catch (e) {
      return e.error;
    } catch (_) {
      return const ValidationError('İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    }
  }

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
    IsZamani? isZamani,
  }) =>
      _yaz(() => _c.post('/teklif-talepleri', body: {
            'saglayiciId': saglayiciId,
            'kategori': kategori,
            'hizmet': hizmet,
            'aciklama': aciklama,
            'iletisimTercihi': iletisimTercihi.name,
            'fotograflar': fotograflar,
            if (isZamani != null) 'isZamani': isZamani.kod,
          }));

  @override
  Future<DomainError?> teklifVer(String id, {required int fiyat, required String aciklama}) =>
      _yaz(() => _c.post('/teklif-talepleri/$id/teklif', body: {'fiyat': fiyat, 'aciklama': aciklama}));

  @override
  Future<DomainError?> secToVer(String id) => _yaz(() => _c.post('/teklif-talepleri/$id/sec'));

  @override
  Future<DomainError?> reddet(String id, {String? gerekce}) =>
      _yaz(() => _c.post('/teklif-talepleri/$id/reddet', body: {if (gerekce != null) 'gerekce': gerekce}));

  @override
  Future<DomainError?> tamamla(String id) => _yaz(() => _c.post('/teklif-talepleri/$id/tamamla'));

  @override
  Future<DomainError?> mesajGonder(String id,
          {required String gonderenId, String? metin, String? fotografYolu}) =>
      _yaz(() => _c.post('/teklif-talepleri/$id/mesajlar', body: {
            if (metin != null) 'metin': metin,
            if (fotografYolu != null) 'fotografRef': fotografYolu,
          }));

  @override
  Future<void> mesajlariOkunduIsaretle(String talepId, String okuyanId) async {
    try {
      await _c.post('/teklif-talepleri/$talepId/okundu');
      final t = _onbellek[talepId];
      if (t != null) {
        for (final m in t.mesajlar) {
          if (m.gonderenId != okuyanId) {
            m.durum = TeklifMesajDurumu.okundu;
          }
        }
        notifyListeners();
      }
    } catch (_) {
      // Okundu işareti kritik değil; sonraki tazelemede eşitlenir.
    }
  }

  // ── Eşleme (sunucu JSON → mevcut model) ─────────────────────
  static TeklifTalebiDurumu _durum(String? s) => switch (s) {
        'TEKLIF_GELDI' => TeklifTalebiDurumu.teklifGeldi,
        'SECILDI' => TeklifTalebiDurumu.secildi,
        'REDDEDILDI' => TeklifTalebiDurumu.reddedildi,
        'SURESI_DOLDU' => TeklifTalebiDurumu.suresiDoldu,
        'TAMAMLANDI' => TeklifTalebiDurumu.tamamlandi,
        _ => TeklifTalebiDurumu.beklemede,
      };

  static DateTime _zaman(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal() ?? DateTime.now();

  static TeklifTalebi _talep(Map<String, dynamic> j) => TeklifTalebi(
        id: j['id'] as String,
        talepNo: '${j['talepNo'] ?? ''}',
        hizmetAlanId: '${j['hizmetAlanId'] ?? ''}',
        saglayiciId: '${j['saglayiciId'] ?? ''}',
        saglayiciAdi: '${j['saglayiciAdi'] ?? ''}',
        kategori: '${j['kategori'] ?? ''}',
        hizmet: '${j['hizmet'] ?? ''}',
        aciklama: '${j['aciklama'] ?? ''}',
        iletisimTercihi: j['iletisimTercihi'] == 'telefonGoster'
            ? IletisimTercihi.telefonGoster
            : IletisimTercihi.yalnizMesaj,
        createdAt: _zaman(j['createdAt']),
        fotograflar: ((j['fotograflar'] as List?) ?? const []).map((e) => '$e').toList(),
        isZamani: IsZamani.koddan(j['isZamani'] as String?),
        durum: _durum(j['durum'] as String?),
        teklifFiyati: (j['teklifFiyati'] as num?)?.toInt(),
        teklifAciklamasi: j['teklifAciklamasi'] as String?,
        teklifTarihi: j['teklifTarihi'] == null ? null : _zaman(j['teklifTarihi']),
        redGerekcesi: j['redGerekcesi'] as String?,
        mesajlar: ((j['mesajlar'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((m) => TeklifMesaj(
                  id: '${m['id']}',
                  gonderenId: '${m['gonderenId'] ?? ''}',
                  zaman: _zaman(m['createdAt']),
                  metin: m['metin'] as String?,
                  fotografYolu: m['fotografRef'] as String?,
                  durum: m['okundu'] == true ? TeklifMesajDurumu.okundu : TeklifMesajDurumu.iletildi,
                ))
            .toList(),
      );
}
