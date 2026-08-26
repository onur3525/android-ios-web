import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/listing.dart';

class ListingRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<Listing> _items = [];

  /// ── İLAN NUMARASI ÜRETİMİ ──
  ///
  /// ⚠ ARTAN SAYAÇ, "EN BÜYÜK + 1" DEĞİL.
  ///
  /// Mevcut ilanlara bakıp en büyüğü bulmak, silinen/kapanan bir
  /// ilanın numarasının YENİDEN VERİLMESİNE yol açar. Sayaç yalnız
  /// ileri gider; listeden kayıt çıkması onu geri almaz.
  ///
  /// ⚠ BU İSTEMCİ TARAFI BİR SİMÜLASYONDUR. Gerçek benzersizlik
  /// otoritesi veritabanıdır: `ilanNo` üzerinde UNIQUE kısıt ve
  /// atomik üretim (sequence / identity) gerekir. "Önce kontrol et,
  /// sonra yaz" yeterli değildir — iki paralel istek aynı anda
  /// kontrolü geçebilir.
  ///
  /// Başlangıç değeri sabit: testler DETERMİNİSTİK olsun diye
  /// rastgelelik kullanılmaz.
  static const int _kIlanNoBaslangic = 10458231;
  int _sonrakiIlanNo = _kIlanNoBaslangic;

  /// Üretilmiş TÜM numaralar — kayıt silinse de burada kalır.
  ///
  /// ⚠ Yeniden kullanımı engellemenin ikinci savunması.
  final Set<String> _verilmisIlanNolari = {};

  /// Bir sonraki benzersiz numarayı üretir.
  String _ilanNoUret() {
    var no = (_sonrakiIlanNo++).toString();
    // Dışarıdan verilmiş numaralarla çakışma ihtimaline karşı ilerle.
    while (_verilmisIlanNolari.contains(no)) {
      no = (_sonrakiIlanNo++).toString();
    }
    _verilmisIlanNolari.add(no);
    return no;
  }

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
  }) {
    // ⚠ Numara BURADA üretilir; kullanıcıdan İSTENMEZ ve form
    // üzerinden geçirilmez.
    final l = Listing(
        id: _uuid.v4(), ilanNo: _ilanNoUret(), ownerId: ownerId,
        title: title,
        location: location, desc: desc, photoPaths: photoPaths,
        isZamani: isZamani,
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
    // ⚠ NUMARA SERBEST KALMAZ: `_verilmisIlanNolari` temizlenmez,
    // sayaç geri alınmaz. Silinen ilanın numarası bir daha
    // verilmez — destek kayıtlarında eski referanslar yanlış ilana
    // düşmesin.
    _items.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}
