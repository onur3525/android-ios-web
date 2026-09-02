import 'package:flutter/foundation.dart';

import '../../domain/failures.dart';

/// Bağımlı port/repository'lerdeki değişiklikleri kendi dinleyicilerine iletir
/// ve ASENKRON işlemler için ortak durum yönetimi sağlar.
abstract class BaseController extends ChangeNotifier {
  final List<Listenable> _deps;
  BaseController(this._deps) {
    for (final d in _deps) {
      d.addListener(notifyListeners);
    }
  }

  bool _loading = false;
  DomainError? _lastError;
  final Set<String> _inFlight = {};

  /// Ekranlar bu bayrağa bakarak yükleniyor durumu gösterir.
  bool get loading => _loading;

  /// Son işlemin hatası (başarıda null) — ekranlar mesajı gösterir.
  DomainError? get lastError => _lastError;
  String? get lastErrorMessage => _lastError?.message;
  void clearError() {
    if (_lastError == null) {
      return;
    }
    _lastError = null;
    notifyListeners();
  }

  /// Belirli bir işlem sürüyor mu (çift tıklama koruması için).
  bool isBusy(String key) => _inFlight.contains(key);

  /// Çok adımlı akışlar (ör. ödeme oturumu → doğrulama) için meşguliyet
  /// bayrağını doğrudan yönetir. Aynı anahtar zaten meşgulse true döner
  /// ve çağıran işlemi başlatmamalıdır.
  bool setBusy(String key, bool busy) {
    if (busy) {
      if (_inFlight.contains(key)) {
        return false;
      }
      _inFlight.add(key);
    } else {
      _inFlight.remove(key);
    }
    notifyListeners();
    return true;
  }

  /// VERİ YÜKLEME sarmalayıcısı: loading + hata durumunu yönetir.
  Future<DomainError?> runLoad(Future<DomainError?> Function() task) async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final err = await task();
      _lastError = err;
      return err;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// İŞLEM sarmalayıcısı: aynı anahtarla ikinci istek ENGELLENİR.
  /// Sunucu kesin cevap vermeden başarı döndürülmez.
  Future<DomainError?> runAction(
    String key,
    Future<DomainError?> Function() task, {
    Future<void> Function()? onSuccess,
  }) async {
    if (_inFlight.contains(key)) {
      return const ValidationError('Bu işlem sürüyor — lütfen bekleyin');
    }
    _inFlight.add(key);
    _lastError = null;
    notifyListeners();
    try {
      final err = await task();
      _lastError = err;
      if (err == null && onSuccess != null) {
        await onSuccess(); // işlem sonrası ilgili liste/detay yeniden yüklenir
      }
      return err;
    } finally {
      _inFlight.remove(key);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final d in _deps) {
      d.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
