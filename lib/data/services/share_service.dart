import 'package:share_plus/share_plus.dart';
import '../../domain/config.dart';

/// Uygulamayı Paylaş — metin tek merkezden (DomainConfig.shareText).
/// [sharer] test için enjekte edilebilir; hata durumunda false döner,
/// çağıran ekran kullanıcıya anlaşılır mesaj gösterir.
class ShareService {
  final Future<void> Function(String text) _sharer;
  ShareService({Future<void> Function(String text)? sharer})
      : _sharer = sharer ??
            ((t) => SharePlus.instance.share(ShareParams(text: t)));

  Future<bool> shareApp() async {
    try {
      await _sharer(DomainConfig.shareText);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// NOT: Mağazaya yönlendiren eski puanlama servisi kaldırılmıştır.
// Uygulama içi puanlama app_rate_screen.dart üzerinden backend'e kaydedilir
// (HTML referansındaki davranış). Mağaza bağlantısı yalnız ZORUNLU
// GÜNCELLEME akışında kullanılır; gerçek kimlikler data/store_links.dart
// içinde tutulur.
