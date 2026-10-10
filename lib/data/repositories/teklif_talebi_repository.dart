import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// ⚠ `IsZamani` tip olarak `listing.dart`ta tanımlıdır; `show` ile
// YALNIZ o alınır — bu dosyaya `Listing` modeli SIZMAZ.
import '../models/listing.dart' show IsZamani;
import '../models/teklif_talebi.dart';
import 'ilan_no_uretici.dart';

/// ── ⚠ MOCK DEPO — GERÇEK BACKEND DEĞİL ──
///
/// Diğer depolarla (`OfferRepository` vb.) AYNI ŞEKİLDE bellek-içi
/// tutulur; kalıcı bir mimari İDDİA ETMEZ. Gerçek backend geldiğinde
/// bu sınıfın YERİNE bir API deposu geçecek; `TeklifTalebiController`
/// arayüzü DEĞİŞMEYECEK.
class TeklifTalebiRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final Map<String, TeklifTalebi> _items = {};

  // ── Sekme anlığı (yalnız web + mock; bkz. sekme_anligi.dart) ──
  List<TeklifTalebi> get sekmeKayitlari => List.unmodifiable(_items.values);
  void sekmeKayitlariniYukle(Iterable<TeklifTalebi> kayitlar) {
    _items
      ..clear()
      ..addEntries(kayitlar.map((t) => MapEntry(t.id, t)));
    notifyListeners();
  }

  /// ⚠ SÜRESİ DOLAN TEKLİFLER — her okumadan ÖNCE tembelce (lazily)
  /// uygulanır: 30 saat geçtiyse ve hâlâ `teklifGeldi` durumundaysa
  /// artık SEÇİLEMEZ. Ayrı bir zamanlayıcı/arka plan görevi İCAT
  /// EDİLMEDİ — her okuma anında kontrol edilir.
  void _suresiDolanlariUygula() {
    var degisti = false;
    for (final t in _items.values) {
      if (t.durum == TeklifTalebiDurumu.teklifGeldi && t.suresiGecmisMi) {
        t.durum = TeklifTalebiDurumu.suresiDoldu;
        degisti = true;
      }
    }
    if (degisti) notifyListeners();
  }

  TeklifTalebi? byId(String id) {
    _suresiDolanlariUygula();
    return _items[id];
  }

  /// Bir hizmet alanın GÖNDERDİĞİ tüm talepler — en yeni üstte.
  List<TeklifTalebi> byHizmetAlan(String hizmetAlanId) {
    _suresiDolanlariUygula();
    return _items.values.where((t) => t.hizmetAlanId == hizmetAlanId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Bir hizmet verene GELEN tüm talepler — en yeni üstte.
  List<TeklifTalebi> bySaglayici(String saglayiciId) {
    _suresiDolanlariUygula();
    return _items.values.where((t) => t.saglayiciId == saglayiciId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  TeklifTalebi create({
    required String hizmetAlanId,
    required String saglayiciId,
    required String saglayiciAdi,
    required String kategori,
    required String hizmet,
    required String aciklama,
    required IletisimTercihi iletisimTercihi,
    List<String> fotograflar = const [],
    IsZamani? isZamani,
  }) {
    final t = TeklifTalebi(
      id: _uuid.v4(),
      // ⚠ İLANLARLA AYNI DİZİDEN (12 Eyl, ürün kararı): numara
      // `IlanNoUretici`den gelir; aynı numara bir ilanda ve bir
      // talepte birden çıkamaz. Ayrı bir sayaç AÇILMAZ.
      talepNo: IlanNoUretici.uret(),
      hizmetAlanId: hizmetAlanId,
      saglayiciId: saglayiciId,
      saglayiciAdi: saglayiciAdi,
      kategori: kategori,
      hizmet: hizmet,
      aciklama: aciklama,
      iletisimTercihi: iletisimTercihi,
      fotograflar: fotograflar,
      isZamani: isZamani,
      createdAt: DateTime.now(),
    );
    _items[t.id] = t;
    notifyListeners();
    return t;
  }

  /// ⚠ TEK SEFERLİK: `teklifTarihi` dolduktan sonra bu metot bir daha
  /// hiçbir şey YAZMAZ — gönderilen teklif değiştirilemez/tekrar
  /// gönderilemez. Bu an AYNI ZAMANDA maskelemeyi kaldıran ve
  /// mesajlaşmayı açan TEK tetikleyicidir (bkz. model doküman notu).
  void teklifVer(String id, {required int fiyat, required String aciklama}) {
    final t = _items[id];
    if (t == null || t.teklifTarihi != null) {
      return;
    }
    t
      ..teklifFiyati = fiyat
      ..teklifAciklamasi = aciklama
      ..teklifTarihi = DateTime.now()
      ..durum = TeklifTalebiDurumu.teklifGeldi;
    notifyListeners();
  }

  /// ⚠ SÜRESİ DOLMUŞ TEKLİF SEÇİLEMEZ — kontrol ÖNCE yapılır.
  void secToVer(String id) {
    _suresiDolanlariUygula();
    final t = _items[id];
    if (t == null || t.durum != TeklifTalebiDurumu.teklifGeldi) return;
    t.durum = TeklifTalebiDurumu.secildi;
    notifyListeners();
  }

  void reddet(String id, {String? gerekce}) {
    final t = _items[id];
    // ⚠ DÜZELTİLDİ — önceden yalnız `teklifGeldi` durumu kabul
    // ediliyordu; `beklemede` (teklif henüz verilmeden) durumundaki
    // bir talebi silme/iptal isteği SESSİZCE HİÇBİR ŞEY YAPMADAN
    // reddediliyordu (kullanıcı tüm akışı tamamlasa bile talep
    // silinmiyordu). Artık ikisi de kabul edilir.
    if (t == null ||
        (t.durum != TeklifTalebiDurumu.teklifGeldi &&
            t.durum != TeklifTalebiDurumu.beklemede)) {
      return;
    }
    t
      ..durum = TeklifTalebiDurumu.reddedildi
      ..redGerekcesi = gerekce;
    notifyListeners();
  }

  /// İş tamamlandı — hizmet verenin profili SİSTEMDEN GİZLENMEZ,
  /// yalnız BU işin bağlantısı kapanır; hizmet veren "Bul" ile yeni
  /// müşteriler tarafından yine bulunabilir.
  void tamamla(String id) {
    final t = _items[id];
    if (t == null || t.durum != TeklifTalebiDurumu.secildi) return;
    t.durum = TeklifTalebiDurumu.tamamlandi;
    notifyListeners();
  }

  /// ⚠ UYGULAMA İÇİ MESAJ — yalnız `teklifTarihi` DOLDUKTAN SONRA
  /// gönderilebilir. Öncesinde sessizce hiçbir şey YAZMAZ (ekran zaten
  /// bu durumda kutuyu göstermez; burası ikinci bir güvenlik katmanı).
  void mesajGonder(String id,
      {required String gonderenId, String? metin, String? fotografYolu}) {
    final t = _items[id];
    if (t == null || t.teklifTarihi == null) {
      return;
    }
    final temizMetin = metin?.trim();
    if ((temizMetin == null || temizMetin.isEmpty) && fotografYolu == null) {
      return; // ⚠ Boş mesaj YAZILMAZ.
    }
    t.mesajlar.add(TeklifMesaj(
      id: _uuid.v4(),
      gonderenId: gonderenId,
      zaman: DateTime.now(),
      metin: (temizMetin == null || temizMetin.isEmpty) ? null : temizMetin,
      fotografYolu: fotografYolu,
    ));
    notifyListeners();
  }

  /// ⚠ KULLANICI İSTEĞİ — "gönderildi = 1 tik, iletildi/okundu = 2
  /// tik, okunduysa renk değişik" (`chat_screen.dart`daki
  /// `MessageStatus` ile AYNI ürün mantığı). Karşı taraf sohbet
  /// ekranını AÇTIĞINDA çağrılır; kendi gönderdiği mesajlara
  /// dokunmaz, yalnız KARŞI TARAFTAN gelenleri "okundu" yapar.
  ///
  /// ⚠ MUTABLE ALAN DOĞRUDAN GÜNCELLENİR — `TeklifMesaj.durum`
  /// `final` değil (bkz. model notu); yeni bir liste/kopya
  /// OLUŞTURULMAZ, mevcut nesneler yerinde değiştirilir.
  void mesajlariOkunduIsaretle(String talepId, String okuyanId) {
    final t = _items[talepId];
    if (t == null) {
      return;
    }
    var degisti = false;
    for (final m in t.mesajlar) {
      if (m.gonderenId != okuyanId &&
          m.durum != TeklifMesajDurumu.okundu) {
        m.durum = TeklifMesajDurumu.okundu;
        degisti = true;
      }
    }
    if (degisti) {
      notifyListeners();
    }
  }
}
