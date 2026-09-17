import '../../domain/failures.dart';
// ⚠ `IsZamani` tip olarak `listing.dart`ta tanımlıdır; `show` ile
// YALNIZ o alınır — bu dosyaya `Listing` modeli SIZMAZ.
import '../models/listing.dart' show IsZamani;
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

  // ── ⚠ "TEKLİF İSTEKLERİ" SEKMESİ ROZETİ — YENİ GELEN, HENÜZ
  // AÇILMAMIŞ TALEP SAYISI ──
  //
  // ⚠ Bu sayı KALICI DEĞİL (oturum içi, `Map` bellekte tutulur) —
  // uygulama yeniden açılınca sıfırlanır. Kullanıcı isteği yalnız
  // "sekmeye girince rozet silinsin" idi; kalıcı "okundu" durumu
  // (sunucu tarafı) istenmedi, bu yüzden basit ve güvenli bir bellek
  // içi çözüm yeterli.
  final Map<String, DateTime> _sonGorulme = {};

  /// [saglayiciId] için, en son "görüldü" işaretlenen zamandan SONRA
  /// oluşmuş, hâlâ `beklemede` durumundaki talep sayısı.
  int gorulmemisTalepSayisi(String saglayiciId) {
    final sinir = _sonGorulme[saglayiciId];
    return bySaglayici(saglayiciId)
        .where((t) =>
            t.durum == TeklifTalebiDurumu.beklemede &&
            (sinir == null || t.createdAt.isAfter(sinir)))
        .length;
  }

  /// Kullanıcı "Teklif İstekleri" sekmesine girdiğinde çağrılır —
  /// o ANA KADAR gelen talepler artık "görülmüş" sayılır, rozet
  /// silinir. Bundan SONRA gelecek yeni talepler yine rozete yansır.
  void talepleriGorulduIsaretle(String saglayiciId) {
    _sonGorulme[saglayiciId] = DateTime.now();
    notifyListeners();
  }

  // ── ⚠ "BUL" İKONU ROZETİ (HİZMET ALAN) — YENİ GELEN TEKLİF ──
  //
  // Yukarıdaki `_sonGorulme` ile AYNI desen, ama karşı yön: burada
  // hizmet ALAN'ın, gönderdiği taleplere gelen TEKLİFLERİ henüz
  // görüp görmediği izlenir. Ayrı bir `Map` — iki taraf birbirine
  // KARIŞMAZ (aynı kullanıcı bazı akışlarda hem talep gönderen hem
  // teklif alan olabilir).
  final Map<String, DateTime> _sonGorulmeHizmetAlan = {};

  /// [hizmetAlanId] için, en son "görüldü" işaretlenen zamandan
  /// SONRA teklif almış (hâlâ `teklifGeldi` durumundaki) talep var
  /// mı.
  bool yeniTeklifVarMi(String hizmetAlanId) {
    final sinir = _sonGorulmeHizmetAlan[hizmetAlanId];
    return byHizmetAlan(hizmetAlanId).any((t) =>
        t.durum == TeklifTalebiDurumu.teklifGeldi &&
        t.teklifTarihi != null &&
        (sinir == null || t.teklifTarihi!.isAfter(sinir)));
  }

  /// GÖRÜLMEMİŞ yeni teklif SAYISI.
  ///
  /// ⚠ `yeniTeklifVarMi` ile AYNI ölçüt, yalnız sayıya çevrilmiş
  /// hâli — iki ayrı kural yazılmadı. "Bul" sekmesindeki rozet
  /// artık "!" değil SAYI gösterdiği için gerekli.
  int yeniTeklifSayisi(String hizmetAlanId) {
    final sinir = _sonGorulmeHizmetAlan[hizmetAlanId];
    return byHizmetAlan(hizmetAlanId)
        .where((t) =>
            t.durum == TeklifTalebiDurumu.teklifGeldi &&
            t.teklifTarihi != null &&
            (sinir == null || t.teklifTarihi!.isAfter(sinir)))
        .length;
  }

  /// Hizmet alan "Bul" ekranına girdiğinde çağrılır — bkz. yukarıdaki
  /// AYNA fonksiyon notu.
  void teklifleriGorulduIsaretleHizmetAlan(String hizmetAlanId) {
    _sonGorulmeHizmetAlan[hizmetAlanId] = DateTime.now();
    notifyListeners();
  }

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
                isZamani: isZamani,
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

  /// ⚠ YENİ — sohbet ekranı açılınca "okundu" tikini tetikler.
  /// `runAction` KULLANILMADI: bu bir "yazma" eylemi değil, sessiz
  /// bir durum güncellemesi — tekilleştirme kilidine (ve olası hata
  /// toast'una) gerek yok.
  Future<void> mesajlariOkunduIsaretle(String talepId, String okuyanId) =>
      _port.mesajlariOkunduIsaretle(talepId, okuyanId);
}
