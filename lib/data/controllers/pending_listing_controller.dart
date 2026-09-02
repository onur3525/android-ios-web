import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/pending_listing.dart';
import '../repositories/pending_listing_store.dart';

/// Yayın denemesinin sonucu.
enum PendingPublishOutcome {
  /// Bekleyen ilan yok — yapılacak bir şey yoktu.
  yok,

  yayinlandi,

  /// Bazı fotoğraf dosyaları cihazda BULUNAMADI.
  ///
  /// ⚠ İlan OTOMATİK yayınlanmaz. Kullanıcı ya eksik fotoğrafları
  /// kaldırıp devam etmeli ya da yeniden seçmelidir.
  eksikFotograf,

  /// Yayın sırasında hata oluştu — taslak KORUNUR.
  hata,
}

/// KAYIT ÖNCESİ İLAN TASLAĞI DENETLEYİCİSİ
///
/// Kayıtsız kullanıcının hazırladığı ilanı taşır ve kayıt +
/// doğrulamalar tamamlandıktan SONRA tek sefer yayınlar.
///
/// ⚠ GÜVENLİK: bu sınıf yayın YETKİSİ vermez. Yayın çağrısı yalnız
/// oturum açılmış ve doğrulaması tamamlanmış kullanıcı için yapılır;
/// `RoleGuard` ve rota koruması AYNEN korunur.
class PendingListingController extends ChangeNotifier {
  PendingListingController(this._store);

  final PendingListingStore _store;

  PendingListing? _draft;
  PendingListing? get draft => _draft;
  bool get hasDraft => _draft != null;

  // ── DOUBLE-PUBLISH KORUMASI (üç katman) ──
  //
  // 1) `_publishing`: eşzamanlı çağrılar reddedilir.
  // 2) `_published` : aynı oturumda ikinci çağrı reddedilir.
  // 3) taslak silme : başarıdan HEMEN SONRA temizlenir; `_draft`
  //    null olduğu için sonraki çağrı erken döner.
  bool _publishing = false;
  bool _published = false;

  bool get publishing => _publishing;
  bool get published => _published;

  /// Cihazda bulunamayan fotoğraf yolları (son denemeden).
  List<String> _kayipFotograflar = const [];
  List<String> get kayipFotograflar => _kayipFotograflar;

  /// Kalıcı taslağı belleğe alır (uygulama açılışında).
  Future<void> load() async {
    _draft = await _store.read();
    notifyListeners();
  }

  /// Taslağı kaydeder. Kayıt akışına geçmeden ÖNCE çağrılır.
  Future<void> saveDraft(PendingListing p) async {
    _draft = p;
    _published = false;
    _kayipFotograflar = const [];
    await _store.save(p);
    notifyListeners();
  }

  Future<void> updateDraft(PendingListing p) => saveDraft(p);

  /// Taslağı siler (kullanıcı vazgeçti veya yayın tamamlandı).
  Future<void> clear() async {
    _draft = null;
    _kayipFotograflar = const [];
    await _store.clear();
    notifyListeners();
  }

  /// Cihazda gerçekten var olan fotoğraf yollarını döndürür.
  ///
  /// ⚠ Kayıt akışı sırasında kullanıcı galeriden dosya silmiş
  /// olabilir; yükleme öncesi DOĞRULANIR.
  List<String> mevcutFotograflar(PendingListing p) => p.localPhotoPaths
      .where((yol) => File(yol).existsSync())
      .toList(growable: false);

  List<String> kayipOlanlar(PendingListing p) => p.localPhotoPaths
      .where((yol) => !File(yol).existsSync())
      .toList(growable: false);

  /// BEKLEYEN İLANI YAYINLA
  ///
  /// Kayıt ve zorunlu doğrulamalar tamamlandıktan SONRA çağrılır.
  ///
  /// [yayinla] gerçek yayın işini yapar; fotoğraf yükleme de bu
  /// geri çağrının içindedir (kayıtsızken yükleme YAPILMAZ).
  ///
  /// [eksikFotografaIzinVer] `false` iken kayıp dosya bulunursa
  /// yayın YAPILMAZ ve `eksikFotograf` döner — kullanıcı karar
  /// vermeden ilan yayınlanmaz.
  Future<PendingPublishOutcome> publishIfAny({
    required Future<bool> Function(PendingListing p, List<String> fotograflar)
        yayinla,
    bool eksikFotografaIzinVer = false,
  }) async {
    // Katman 1 — eşzamanlı çağrı.
    if (_publishing) {
      return PendingPublishOutcome.yok;
    }
    // Katman 2 — aynı oturumda tekrar.
    if (_published) {
      return PendingPublishOutcome.yok;
    }
    // Katman 3 — taslak yok (yayın sonrası silinmiş olabilir).
    final p = _draft;
    if (p == null) {
      return PendingPublishOutcome.yok;
    }

    _publishing = true;
    notifyListeners();
    try {
      final kayip = kayipOlanlar(p);
      if (kayip.isNotEmpty && !eksikFotografaIzinVer) {
        // ⚠ OTOMATİK fotoğrafsız yayın YAPILMAZ.
        _kayipFotograflar = kayip;
        return PendingPublishOutcome.eksikFotograf;
      }

      final ok = await yayinla(p, mevcutFotograflar(p));
      if (!ok) {
        // Taslak KORUNUR; kullanıcı tekrar deneyebilir.
        return PendingPublishOutcome.hata;
      }

      _published = true;
      _draft = null;
      _kayipFotograflar = const [];
      await _store.clear();
      return PendingPublishOutcome.yayinlandi;
    } finally {
      _publishing = false;
      notifyListeners();
    }
  }
}
