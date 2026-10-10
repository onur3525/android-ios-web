import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import 'gezgin.dart';

/// ═══════════════════════════════════════════════════════════════
/// YASAL BELGE KABUL KAPISI — yeni sürüm yayınlanınca onay
///
/// Admin panelinden "kabul gerektiren" bir belgenin (KVKK, Gizlilik,
/// Kullanım Koşulları, Üyelik Sözleşmesi…) yeni sürümü yayınlandığında,
/// oturum açık kullanıcı uygulamayı açtığında / giriş yaptığında:
///
///   "<Belge> güncellendi"  [Metni Görüntüle]  [Kabul Et ve Devam Et]
///
/// Kabul sunucuya kullanıcı + belge + sürüm + belge özeti (SHA-256) +
/// platform + zaman olarak kaydedilir (`/legal/:slug/accept`). Kabul
/// edilmeden pencere kapanmaz.
///
/// ⚠ YALNIZ API MODUNDA çalışır; mock mod (web demosu, testler) için
/// hiçbir şey değişmez. Mevcut ekranlara dokunmaz; metin görüntüleme
/// mevcut `/legal` rotasını (LegalScreen) kullanır.
/// ═══════════════════════════════════════════════════════════════
class YasalKabulKapisi extends StatefulWidget {
  const YasalKabulKapisi({super.key, required this.child});

  final Widget child;

  @override
  State<YasalKabulKapisi> createState() => _YasalKabulKapisiState();
}

class _YasalKabulKapisiState extends State<YasalKabulKapisi> {
  AuthController? _auth;
  String? _denetlenenKullanici;
  bool _calisiyor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ApiConfig.useRealApi || _auth != null) {
      return;
    }
    _auth = context.read<AuthController>()..addListener(_degisti);
    WidgetsBinding.instance.addPostFrameCallback((_) => _degisti());
  }

  @override
  void dispose() {
    _auth?.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() {
    final id = _auth?.currentAccount?.id;
    if (id == null) {
      _denetlenenKullanici = null; // çıkış: sonraki girişte yeniden denetlenir
      return;
    }
    if (_calisiyor || id == _denetlenenKullanici) {
      return;
    }
    _denetlenenKullanici = id;
    _denetle();
  }

  Future<void> _denetle() async {
    _calisiyor = true;
    try {
      final api = context.read<ApiClient>();
      final bekleyen = await api.getList('/legal/pending-acceptances');
      for (final b in bekleyen.whereType<Map<String, dynamic>>()) {
        final tamam = await _sor(api, b);
        if (!tamam) {
          break;
        }
      }
    } catch (_) {
      // Ağ hatası: sonraki girişte/açılışta yeniden sorulur.
      _denetlenenKullanici = null;
    } finally {
      _calisiyor = false;
    }
  }

  Future<bool> _sor(ApiClient api, Map<String, dynamic> b) async {
    final ctx = gezginAnahtari.currentContext;
    if (ctx == null) {
      return false;
    }
    final slug = '${b['slug']}';
    final baslik = '${b['title']}';
    final sonuc = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (d) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('$baslik güncellendi'),
          content: const Text(
              'Uygulamayı kullanmaya devam etmek için güncel metni okuyup onaylamanız gerekiyor.'),
          actions: [
            TextButton(
              onPressed: () => gezginAnahtari.currentState?.pushNamed('/legal',
                  arguments: {'slug': slug, 'title': baslik}),
              child: const Text('Metni Görüntüle'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await api.post('/legal/$slug/accept', body: {
                    'version': '${b['version']}',
                    'sha256': '${b['sha256']}',
                    'platform': kIsWeb
                        ? 'web'
                        : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
                  });
                  if (d.mounted) {
                    Navigator.of(d).pop(true);
                  }
                } catch (_) {
                  // Arada yeni sürüm yayınlandıysa ya da ağ hatası: pencere
                  // kapanır, liste yeniden çekilir (güncel sürüm sorulur).
                  if (d.mounted) {
                    Navigator.of(d).pop(false);
                  }
                }
              },
              child: const Text('Kabul Et ve Devam Et'),
            ),
          ],
        ),
      ),
    );
    if (sonuc != true) {
      _denetlenenKullanici = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _degisti());
    }
    return sonuc == true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
