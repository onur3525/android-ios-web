import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/listing.dart';
import '../models/teklif_talebi.dart' show IletisimTercihi;
import 'ilan_no_uretici.dart';

class ListingRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<Listing> _items = [];

  // ── Sekme anlığı (yalnız web + mock; bkz. sekme_anligi.dart) ──
  List<Listing> get sekmeKayitlari => List.unmodifiable(_items);
  void sekmeKayitlariniYukle(Iterable<Listing> kayitlar) {
    _items
      ..clear()
      ..addAll(kayitlar);
    notifyListeners();
  }

  /// ── İLAN NUMARASI ÜRETİMİ ──
  ///
  /// ⚠ SAYAÇ BU SINIFTAN ÇIKARILDI (12 Eyl). Numara artık
  /// `IlanNoUretici` üzerinden, TEKLİF TALEPLERİYLE AYNI diziden
  /// gelir: ürün kararına göre ilan ve talep kullanıcı için aynı
  /// şeydir, aynı numara iki kayıtta çıkamaz.
  ///
  /// Üretim kuralları (artan sayaç, verilmiş numaraların
  /// unutulmaması, istemci simülasyonu uyarısı) o dosyada.
  String _ilanNoUret() => IlanNoUretici.uret();

  /// Numaraya göre ilan — ARAMA için.
  ///
  /// ⚠ İLİŞKİ KURMAK İÇİN DEĞİL: teklif/mesaj/ödeme bağları `id`
  /// üzerinden kurulur. Bu yalnız kullanıcının yazdığı referansı
  /// ilana çevirir.
  Listing? byIlanNo(String ilanNo) {
    final n = ilanNo.trim();
    if (n.isEmpty) {
      return null;
    }
    for (final l in _items) {
      if (l.ilanNo == n) {
        return l;
      }
    }
    return null;
  }

  List<Listing> get all => List.unmodifiable(_items);
  List<Listing> byOwner(String ownerId) =>
      _items.where((l) => l.ownerId == ownerId).toList();
  Listing? byId(String id) {
    for (final l in _items) {
      if (l.id == id) {
        return l;
      }
    }
    return null;
  }

  Listing create({
    required String ownerId,
    required String title,
    required String location,
    required String desc,
    List<String>? photoPaths,
    DateTime? createdAt,
    // ⚠ İsteğe bağlı; `null` seçim yapılmadı demektir.
    IsZamani? isZamani,
    // ⚠ YENİ — verilmezse `Listing` kurucusundaki varsayılan
    // (`telefonGoster`) uygulanır.
    IletisimTercihi? iletisimTercihi,
  }) {
    // ⚠ Numara BURADA üretilir; kullanıcıdan İSTENMEZ ve form
    // üzerinden geçirilmez.
    final l = Listing(
        id: _uuid.v4(), ilanNo: _ilanNoUret(), ownerId: ownerId,
        title: title,
        location: location, desc: desc, photoPaths: photoPaths,
        isZamani: isZamani,
        iletisimTercihi: iletisimTercihi ?? IletisimTercihi.telefonGoster,
        createdAt: createdAt);
    _items.insert(0, l); // UUID sayesinde index kaydırma derdi YOK
    notifyListeners();
    return l;
  }

  void setStatus(String id, ListingStatus status) {
    final l = byId(id);
    if (l == null) {
      return;
    }
    l.status = status;
    notifyListeners();
  }

  void remove(String id) {
    // ⚠ NUMARA SERBEST KALMAZ: `IlanNoUretici` kümesi temizlenmez,
    // sayaç geri alınmaz. Silinen ilanın numarası bir daha
    // verilmez — destek kayıtlarında eski referanslar yanlış ilana
    // düşmesin.
    _items.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}
