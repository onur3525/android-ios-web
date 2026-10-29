import 'dart:async';

import '../../domain/failures.dart';
import '../models/listing.dart' show IsZamani;
import '../models/review.dart';
import '../models/teklif_talebi.dart';
import '../ports/teklif_talebi_port.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'fotograf_yukleyici.dart';
import 'gorsel_adresi.dart';
import 'veri_imzasi.dart';

/// ═══════════════════════════════════════════════════════════════
/// TEKLİF TALEBİ — GERÇEK API PORTU (`/api/v1/teklif-talepleri`)
///
/// `MockTeklifTalebiPort` ile AYNI sözleşme (`TeklifTalebiPort`):
/// ekranlar ve `TeklifTalebiController` DEĞİŞMEDİ. Yalnız API modunda
/// (`ApiConfig.useRealApi`) kurulur; mock mod/web demosu aynen.
///
/// Okumalar (`byHizmetAlan`, `bySaglayici`, `byId`) senkron kalır:
/// önbellekten döner; ilk okumada yüklenir, sonra anlık haberle tazelenir;
/// her yazma işleminden sonra sunucu yanıtı önbelleğe işlenir.
///
/// İş kuralları (durum makinesi, taraf denetimi, 30 saatlik teklif
/// süresi) SUNUCUDA zorlanır; burada yalnız yanıt eşlenir.
/// ═══════════════════════════════════════════════════════════════
class ApiTeklifTalebiPort extends TeklifTalebiPort {
  ApiTeklifTalebiPort(this._c, {Future<String> Function(String yol)? fotografYukleyici})
      : _ozelYukleyici = fotografYukleyici;

  /// Testlerde sahte yükleyici; verilmezse `FotografYukleyici.yukle`.
  final Future<String> Function(String yol)? _ozelYukleyici;

  /// Telefondaki fotoğrafı depoya yükleyip `storageRef` döndürür.
  Future<String> _fotografYukle(String yol) {
    final ozel = _ozelYukleyici;
    return ozel != null ? ozel(yol) : FotografYukleyici.yukle(_c, yol);
  }

  final ApiClient _c;
  final Map<String, TeklifTalebi> _onbellek = {};
  DateTime? _sonTazeleme;
  bool _tazeleniyor = false;
  String? _imza;

  /// Sunucunun talep görünümündeki değerlendirmeler (talepId → Review).
  final Map<String, Review> _degerlendirmeler = {};

  /// Talebin değerlendirmesi (yoksa null) — `ApiReviewRepository.
  /// talepCozucu` olarak bağlanır.
  Review? degerlendirme(String talepId) => _degerlendirmeler[talepId];

  void _degerlendirmeyiOku(Map<String, dynamic> j) {
    final d = j['degerlendirme'];
    final id = j['id'];
    if (d is! Map || id is! String) {
      return;
    }
    _degerlendirmeler[id] = Review(
      id: '${d['id']}',
      talepId: id,
      providerId: '${j['saglayiciId'] ?? ''}',
      authorId: '${j['hizmetAlanId'] ?? ''}',
      stars: (d['stars'] as num?)?.toInt() ?? 0,
      text: '${d['text'] ?? ''}',
      status: ReviewStatus.published,
      createdAt: DateTime.tryParse('${d['createdAt']}'),
    );
  }

  // ── ⚠ OKUMADA YOKLAMA KALDIRILDI (28 Eki, kullanıcı kararı) ──
  // Eskiden her okumada 15 sn geçtiyse arka planda yeniden çekiliyordu
  // (ekran açık kaldıkça sürekli istek + yeniden çizim). Artık yalnız İLK
  // okumada yüklenir; sonrası talep haberi (anlık bağlantı / push),
  // uygulamanın öne gelmesi ve yeniden bağlanma ile tazelenir
  // (`AnlikTazeleme`).
  void _gerekirseTazele() {
    if (_tazeleniyor || _sonTazeleme != null) {
      return;
    }
    unawaited(yenile());
  }

  @override
  void oturumDegisti() {
    _sonTazeleme = null;
    _imza = null;
    if (_onbellek.isEmpty && _degerlendirmeler.isEmpty) {
      return;
    }
    _onbellek.clear();
    _degerlendirmeler.clear();
    notifyListeners();
  }

  /// Sunucudan kullanıcının taraf olduğu bütün talepleri çeker.
  @override
  Future<void> yenile() async {
    _tazeleniyor = true;
    try {
      final liste = await _c.getList('/teklif-talepleri');
      _sonTazeleme = DateTime.now();
      // ⚠ DEĞİŞMEYEN VERİ (28 Eki): aynı yanıt yeniden uygulanmaz.
      final imza = veriImzasi(liste);
      if (imza != null && imza == _imza) {
        return;
      }
      _imza = imza;
      final kayitlar = liste.whereType<Map<String, dynamic>>().toList();
      _onbellek
        ..clear()
        ..addEntries(kayitlar.map(_talep).map((t) => MapEntry(t.id, t)));
      _degerlendirmeler.clear();
      kayitlar.forEach(_degerlendirmeyiOku);
      notifyListeners();
    } catch (_) {
      // Ağ/oturum hatası: önbellek korunur; sonraki okumada yeniden denenir.
      _sonTazeleme = null;
    } finally {
      _tazeleniyor = false;
    }
  }

  @override
  List<TeklifTalebi> byHizmetAlan(String hizmetAlanId) {
    _gerekirseTazele();
    return _onbellek.values
        .where((t) => t.hizmetAlanId == hizmetAlanId && !t.hizmetAlanSildi)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  List<TeklifTalebi> bySaglayici(String saglayiciId) {
    _gerekirseTazele();
    return _onbellek.values
        .where((t) => t.saglayiciId == saglayiciId && !t.saglayiciReddetti)
        .toList()
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
        _imza = null; // önbellek liste dışı yoldan değişti
        _onbellek[t.id] = t;
        _degerlendirmeyiOku(j);
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
      // Idempotency-Key: ağ kesintisinde yeniden deneme ikinci talep açmaz.
      _yaz(() => _c.post('/teklif-talepleri', idempotencyKey: ApiClient.newIdempotencyKey(), body: {
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
  Future<DomainError?> saglayiciReddet(String id) =>
      _yaz(() => _c.post('/teklif-talepleri/$id/reddet', body: const <String, String>{}));

  @override
  Future<DomainError?> sil(String id, {String? gerekce}) =>
      _yaz(() => _c.post('/teklif-talepleri/$id/sil', body: {if (gerekce != null) 'gerekce': gerekce}));

  @override
  Future<DomainError?> tamamla(String id) => _yaz(() => _c.post('/teklif-talepleri/$id/tamamla'));

  @override
  Future<DomainError?> mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu}) async {
    // ── ⚠ 29 Eki: FOTOĞRAF ÖNCE DEPOYA YÜKLENİR (ilan sohbetiyle aynı) ──
    // Önceden telefondaki dosya YOLU `fotografRef` diye gidiyor, sunucu
    // "Geçersiz fotoğraf" diyordu. Yükleme bitmeden mesaj gönderilmez.
    var ref = fotografYolu;
    if (ref != null && !FotografYukleyici.sunucuRefMi(ref)) {
      try {
        ref = await _fotografYukle(ref);
      } on FotografYuklemeHatasi catch (e) {
        return ValidationError(e.mesaj);
      } on ApiFailure catch (e) {
        return e.error;
      } catch (_) {
        return const ValidationError(FotografYukleyici.yuklemeHatasi);
      }
    }
    final gidecek = ref;
    return _yaz(() => _c.post('/teklif-talepleri/$id/mesajlar', idempotencyKey: ApiClient.newIdempotencyKey(), body: {
          if (metin != null) 'metin': metin,
          if (gidecek != null) 'fotografRef': gidecek,
        }));
  }

  @override
  Future<void> mesajlariOkunduIsaretle(String talepId, String okuyanId) async {
    try {
      await _c.post('/teklif-talepleri/$talepId/okundu');
      final t = _onbellek[talepId];
      _imza = null;
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
        // Görüntüleme için imzalı adres (varsa) — bkz. gorsel_adresi.dart.
        fotograflar: gorselYollari(j['fotograflar'], j['fotografAdresleri']),
        isZamani: IsZamani.koddan(j['isZamani'] as String?),
        durum: _durum(j['durum'] as String?),
        teklifFiyati: (j['teklifFiyati'] as num?)?.toInt(),
        teklifAciklamasi: j['teklifAciklamasi'] as String?,
        teklifTarihi: j['teklifTarihi'] == null ? null : _zaman(j['teklifTarihi']),
        redGerekcesi: j['redGerekcesi'] as String?,
        silindiAt: j['silindiAt'] == null ? null : _zaman(j['silindiAt']),
        saglayiciReddetti: j['saglayiciReddetti'] == true,
        mesajlar: ((j['mesajlar'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((m) => TeklifMesaj(
                  id: '${m['id']}',
                  gonderenId: '${m['gonderenId'] ?? ''}',
                  zaman: _zaman(m['createdAt']),
                  metin: m['metin'] as String?,
                  fotografYolu: gorselYolu(m['fotografRef'], m['fotografUrl']),
                  // 29 Eki: tek tik (sunucuda) → iki gri (alıcıya ulaştı) → mavi (okundu).
                  durum: m['okundu'] == true
                      ? TeklifMesajDurumu.okundu
                      : m['iletildi'] == true
                          ? TeklifMesajDurumu.iletildi
                          : TeklifMesajDurumu.gonderildi,
                ))
            .toList(),
      );
}
