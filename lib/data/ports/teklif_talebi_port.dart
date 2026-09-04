import 'package:flutter/foundation.dart';

import '../../domain/failures.dart';
import '../models/notification.dart';
import '../models/teklif_talebi.dart';
import '../repositories/notification_repository.dart';
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
  Future<DomainError?> reddet(String id, {String? gerekce});
  Future<DomainError?> tamamla(String id);

  /// ⚠ Yalnız `teklifTarihi` dolduktan SONRA gerçek gönderim yapar
  /// (bkz. repository).
  Future<DomainError?> mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu});
}

/// ── ⚠ BİLDİRİM ZİNCİRİ — MEVCUT `NotificationRepository`YE YAZAR ──
///
/// `MockOfferPort`/`MockContactPort` ile AYNI desen: başarılı her
/// durum değişikliğinde `notifs?.push(...)` çağrılır. Kullanıcı
/// bunu ALT BARDAKİ "Bildirimler" sekmesinde ve rozet sayısında
/// GÖRÜR — ayrı bir bildirim sistemi İCAT EDİLMEDİ, var olana
/// bağlanıldı.
class MockTeklifTalebiPort extends TeklifTalebiPort {
  MockTeklifTalebiPort(this._repo, {this.notifs}) {
    _repo.addListener(notifyListeners);
  }

  final TeklifTalebiRepository _repo;

  /// ⚠ İSTEĞE BAĞLI: `null` verilirse bildirim YAZILMAZ ama akış
  /// yine de çalışır (testlerde kolayca kurulabilsin diye) —
  /// `MockOfferPort`taki `notifs` ile AYNI kural.
  final NotificationRepository? notifs;

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
    final t = _repo.create(
      hizmetAlanId: hizmetAlanId,
      saglayiciId: saglayiciId,
      saglayiciAdi: saglayiciAdi,
      kategori: kategori,
      hizmet: hizmet,
      aciklama: aciklama,
      iletisimTercihi: iletisimTercihi,
      fotograflar: fotograflar,
    );
    // ⚠ HİZMET VERENE — yeni doğrudan talep geldi.
    notifs?.push(
        userId: saglayiciId,
        type: NotifType.teklifTalebiGeldi,
        refId: t.id,
        title: 'Yeni teklif isteği',
        body: '"$hizmet" için doğrudan bir teklif isteği aldınız.');
    return null;
  }

  @override
  Future<DomainError?> teklifVer(String id,
      {required int fiyat, required String aciklama}) async {
    final onceki = _repo.byId(id);
    _repo.teklifVer(id, fiyat: fiyat, aciklama: aciklama);
    final t = _repo.byId(id);
    // ⚠ Yalnız GERÇEKTEN değiştiyse bildirim gider — `teklifVer`
    // ikinci kez çağrılırsa (kilitli) repository SESSİZCE hiçbir
    // şey yapmaz; burada da bildirim TEKRARLANMAZ.
    if (t != null && onceki?.teklifTarihi == null && t.teklifTarihi != null) {
      // ⚠ HİZMET ALANA — teklif geldi.
      notifs?.push(
          userId: t.hizmetAlanId,
          type: NotifType.teklifVerildi,
          refId: t.id,
          title: 'Teklifiniz geldi',
          body: '"${t.hizmet}" talebiniz için $fiyat TL teklif aldınız.');
    }
    return null;
  }

  @override
  Future<DomainError?> secToVer(String id) async {
    _repo.secToVer(id);
    final t = _repo.byId(id);
    if (t != null && t.durum == TeklifTalebiDurumu.secildi) {
      // ⚠ HİZMET VERENE — teklifi kabul edildi, iş aktif.
      notifs?.push(
          userId: t.saglayiciId,
          type: NotifType.teklifSecildi,
          refId: t.id,
          title: 'Teklifiniz kabul edildi',
          body: '"${t.hizmet}" için teklifiniz seçildi — iş aktif.');
    }
    return null;
  }

  @override
  Future<DomainError?> reddet(String id, {String? gerekce}) async {
    _repo.reddet(id, gerekce: gerekce);
    final t = _repo.byId(id);
    if (t != null && t.durum == TeklifTalebiDurumu.reddedildi) {
      // ⚠ HİZMET VERENE — teklifi reddedildi.
      notifs?.push(
          userId: t.saglayiciId,
          type: NotifType.teklifReddedildi,
          refId: t.id,
          title: 'Teklifiniz reddedildi',
          body: '"${t.hizmet}" için verdiğiniz teklif reddedildi.');
    }
    return null;
  }

  @override
  Future<DomainError?> tamamla(String id) async {
    _repo.tamamla(id);
    final t = _repo.byId(id);
    if (t != null && t.durum == TeklifTalebiDurumu.tamamlandi) {
      // ⚠ HİZMET ALANA — iş tamamlandı işaretlendi.
      notifs?.push(
          userId: t.hizmetAlanId,
          type: NotifType.teklifIsiTamamlandi,
          refId: t.id,
          title: 'İş tamamlandı',
          body: '"${t.hizmet}" işi tamamlandı olarak işaretlendi.');
    }
    return null;
  }

  @override
  Future<DomainError?> mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu}) async {
    final onceki = _repo.byId(id)?.mesajlar.length ?? 0;
    _repo.mesajGonder(id,
        gonderenId: gonderenId, metin: metin, fotografYolu: fotografYolu);
    final t = _repo.byId(id);
    // ⚠ Yalnız GERÇEKTEN eklendiyse (boş mesaj repository'de
    // reddedilir, sayı değişmez) bildirim gider.
    if (t != null && t.mesajlar.length > onceki) {
      final aliciId =
          gonderenId == t.hizmetAlanId ? t.saglayiciId : t.hizmetAlanId;
      notifs?.push(
          userId: aliciId,
          type: NotifType.teklifYeniMesaj,
          refId: t.id,
          title: 'Yeni mesaj',
          body: metin ?? 'Fotoğraf gönderildi.');
    }
    return null;
  }
}
