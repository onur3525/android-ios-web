import 'package:flutter/foundation.dart';

import '../../domain/bildirim_metinleri.dart';
import '../../domain/failures.dart';
// ⚠ `IsZamani` tip olarak `listing.dart`ta tanımlıdır; `show` ile
// YALNIZ o alınır — bu dosyaya `Listing` modeli SIZMAZ.
import '../models/listing.dart' show IsZamani;
import '../models/notification.dart';
import '../models/teklif_talebi.dart';
import '../repositories/auth_repository.dart';
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
    IsZamani? isZamani,
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

  /// ⚠ YENİ — karşı taraf sohbet ekranını açtığında "okundu" tik
  /// durumunu tetikler.
  Future<void> mesajlariOkunduIsaretle(String talepId, String okuyanId);
}

/// ── ⚠ BİLDİRİM ZİNCİRİ — MEVCUT `NotificationRepository`YE YAZAR ──
///
/// `MockOfferPort`/`MockContactPort` ile AYNI desen: başarılı her
/// durum değişikliğinde `notifs?.push(...)` çağrılır. Kullanıcı
/// bunu ALT BARDAKİ "Bildirimler" sekmesinde ve rozet sayısında
/// GÖRÜR — ayrı bir bildirim sistemi İCAT EDİLMEDİ, var olana
/// bağlanıldı.
class MockTeklifTalebiPort extends TeklifTalebiPort {
  MockTeklifTalebiPort(this._repo, {this.notifs, this.auth}) {
    _repo.addListener(notifyListeners);
  }

  final TeklifTalebiRepository _repo;

  /// ⚠ İSTEĞE BAĞLI: `null` verilirse bildirim YAZILMAZ ama akış
  /// yine de çalışır (testlerde kolayca kurulabilsin diye) —
  /// `MockOfferPort`taki `notifs` ile AYNI kural.
  final NotificationRepository? notifs;

  /// ⚠ İSTEĞE BAĞLI: `null` verilirse tamamlanan iş sayacı
  /// GÜNCELLENMEZ ama akış çalışır — `notifs` ile AYNI kural, eski
  /// çağrılar ve testler kırılmaz.
  final AuthRepository? auth;

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
    IsZamani? isZamani,
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
      isZamani: isZamani,
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
    // ⚠ DÜZELTİLDİ — KESİN BUG: `_repo.byId(id)` bir REFERANS
    // döndürür (`TeklifTalebi` reference type). `onceki` burada
    // NESNENİN KENDİSİNİ tutuyordu; `_repo.teklifVer(...)` çağrısı
    // AYNI nesneyi YERİNDE değiştirdiği için `onceki.teklifTarihi`
    // de otomatik doluyordu — "önce/sonra" karşılaştırması HER ZAMAN
    // false dönüyor, bildirim ASLA gönderilmiyordu. Düzeltme: nesne
    // yerine, değişmeyecek bir DEĞER (bool) saklanır — `reddet()`/
    // `mesajGonder()`teki AYNI doğru desen (enum/int, reference
    // DEĞİL).
    final oncedenTeklifVardi = _repo.byId(id)?.teklifTarihi != null;
    _repo.teklifVer(id, fiyat: fiyat, aciklama: aciklama);
    final t = _repo.byId(id);
    // ⚠ Yalnız GERÇEKTEN değiştiyse bildirim gider — `teklifVer`
    // ikinci kez çağrılırsa (kilitli) repository SESSİZCE hiçbir
    // şey yapmaz; burada da bildirim TEKRARLANMAZ.
    if (t != null && !oncedenTeklifVardi && t.teklifTarihi != null) {
      // ⚠ HİZMET ALANA — teklif geldi.
      notifs?.push(
          userId: t.hizmetAlanId,
          type: NotifType.teklifVerildi,
          refId: t.id,
          // ── ⚠ BAŞLIK İLAN AKIŞIYLA EŞİTLENDİ (12 Eyl, ürün
          // kararı) ──
          //
          // Burası "Teklifiniz geldi" diyordu. İki sorunu vardı:
          //   1. İlan akışı aynı olaya "Yeni teklif aldınız" diyordu;
          //      bildirim listesinde iki başlık iki farklı şey olmuş
          //      izlenimi veriyordu.
          //   2. YANILTICIYDI: bildirimi alan hizmet ALANDIR, teklifi
          //      o vermemiştir. "Teklifiniz" iyelik eki karşı tarafın
          //      teklifini okuyana aitmiş gibi gösteriyordu.
          title: kYeniTeklifBaslik,
          body: yeniTeklifGovdeTalep(t.hizmet, fiyat));
    }
    return null;
  }

  @override
  Future<DomainError?> secToVer(String id) async {
    _repo.secToVer(id);
    final t = _repo.byId(id);
    if (t != null && t.durum == TeklifTalebiDurumu.secildi) {
      // ── ⚠ HİZMET VERENE — TEKLİFİ SEÇİLDİ ──
      //
      // ⚠ METİN İLAN AKIŞIYLA EŞİTLENDİ (12 Eyl, ürün kararı):
      // burası "Teklifiniz kabul edildi" diyordu, ilan akışı ise
      // "Teklifiniz seçildi 🎉". Hizmet veren için olay AYNI ve
      // bildirim listesinde iki başlık alt alta düşüp iki farklı şey
      // olmuş izlenimi veriyordu.
      //
      // ⚠ PORT KENDİ METNİNİ YAZMAZ: başlık ve gövde
      // `domain/bildirim_metinleri.dart` içinde tek yerde.
      notifs?.push(
          userId: t.saglayiciId,
          type: NotifType.teklifSecildi,
          refId: t.id,
          title: kTeklifSecildiBaslik,
          body: teklifSecildiGovde(t.hizmet));
    }
    return null;
  }

  @override
  Future<DomainError?> reddet(String id, {String? gerekce}) async {
    // ── ⚠ RED/İPTALDE BİLDİRİM GÖNDERİLMEZ (12 Eyl, kullanıcı
    // isteği) ──
    //
    // Burada iki bildirim vardı ve ikisi de kaldırıldı:
    //   · "Teklifiniz reddedildi" — hizmet veren sonucu zaten
    //     görüyor; kart ve detay "Reddedildi" durumuna geçiyor.
    //     Olumsuz haber ikinci kez, ansızın önüne çıkıyordu.
    //   · "Talep iptal edildi" — teklif verilmeden iptal edilen
    //     talepler için gidiyordu. Kullanıcı bunun da kalkmasını
    //     istedi.
    //
    // ⚠ İŞLEM DEĞİŞMEDİ: `_repo.reddet` aynen çalışır, talep
    // `reddedildi` durumuna geçer ve ekranlar bunu gösterir. Kalkan
    // yalnız BİLDİRİMDİR.
    //
    // ⚠ İŞLEM ÖNCESİ DURUMU SAKLAMAYA ARTIK GEREK YOK: `oncekiDurum`
    // ve `teklifVerilmisti` yalnız bildirim METNİNİ seçmek için
    // vardı. Ölü bırakılsalardı, bildirim hâlâ gönderiliyormuş
    // izlenimi verirlerdi.
    //
    // ⚠ `NotifType.teklifReddedildi` SİLİNMEDİ: geçmişte gönderilmiş
    // bildirimler hâlâ o türle kayıtlı ve yönlendirmesi duruyor.
    _repo.reddet(id, gerekce: gerekce);
    return null;
  }

  @override
  Future<DomainError?> tamamla(String id) async {
    // ⚠ ÖNCEKİ DURUM OKUNUR: sayaç yalnız GERÇEKTEN bu çağrıda
    // tamamlanan işler için artmalı. Zaten `tamamlandi` olan bir
    // talep ikinci kez tamamlanırsa sayaç YANLIŞ artardı.
    final oncekiDurum = _repo.byId(id)?.durum;
    _repo.tamamla(id);
    final t = _repo.byId(id);
    if (t != null &&
        t.durum == TeklifTalebiDurumu.tamamlandi &&
        oncekiDurum != TeklifTalebiDurumu.tamamlandi) {
      // ── ⚠ HİZMET VERENİN SAYACI ARTAR (kullanıcı bulgusu, 9 Eyl) ──
      //
      // "Bul" akışından kazanılan iş de bitirilmiş bir iştir; ilan
      // akışıyla aynı sayaca yazılır, yoksa iki akış ayrı sayılırdı.
      // ⚠ DOĞRUDAN DEĞİL DEPO ÜZERİNDEN (10 Eyl): bkz.
      // `AuthRepository.tamamlananIsArtir` notu.
      auth?.tamamlananIsArtir(t.saglayiciId);
    }
    // ── ⚠ "İş tamamlandı" BİLDİRİMİ KALDIRILDI (12 Eyl, kullanıcı
    // isteği) ──
    //
    // "Hizmet alan bildirimlerde iş tamamlandı bildirimi gereksiz,
    // gelmesin."
    //
    // Hizmet alan işin bittiğini zaten görüyor: talep detayında
    // "Yorum Yaz" düğmesi beliriyor ve kart "Tamamlanan işler"e
    // geçiyor. Bildirim üçüncü kez aynı şeyi söylüyordu.
    //
    // ⚠ TAMAMLAMA İŞLEMİNİN KENDİSİ DEĞİŞMEDİ: durum güncellemesi,
    // sayaç artışı ve değerlendirme kapısı aynen çalışır — kalkan
    // yalnız BİLDİRİM.
    //
    // ⚠ `NotifType.teklifIsiTamamlandi` SİLİNMEDİ: geçmişte
    // gönderilmiş bildirimler hâlâ o türle kayıtlı; tür kalkarsa
    // eski kayıtlar çözümlenemez.
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
          // ⚠ METİN ORTAK KAYNAKTAN (12 Eyl): ilan akışı aynı olayı
          // "Yeni mesajınız var" / "Sohbette yeni bir mesaj aldınız."
          // diye anlatıyordu. Başlık ve gövde artık tek yerde.
          title: kYeniMesajBaslik,
          body: yeniMesajGovde(metin));
    }
    return null;
  }

  @override
  Future<void> mesajlariOkunduIsaretle(
      String talepId, String okuyanId) async {
    _repo.mesajlariOkunduIsaretle(talepId, okuyanId);
  }
}
