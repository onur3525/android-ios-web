import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../core/yasal_pdf_ac.dart';
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
    // 22 Eki: PDF'li sürümde kısa özet gösterilir; isteyen PDF'in tamamını
    // açar, "Tamam" ile kabul eder (okumadan da kabul edilebilir).
    final ozet = b['summary'] is String ? b['summary'] as String : null;
    final pdf = yasalPdfAdresi(b['pdfUrl']) != null ? b['pdfUrl'] : null;
    final sonuc = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (d) => PopScope(
        canPop: false,
        child: AlertDialog(
          // 22 Eki: kullanıcı bu belgeyi daha önce HİÇ onaylamadıysa
          // "güncellendi" denmez (yanıltıcıydı).
          title: Text(b['firstTime'] == true
              ? '$baslik onayınız gerekiyor'
              : '$baslik güncellendi'),
          content: ozet != null
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bu belge kısaca şunları kapsar:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(ozet),
                        const SizedBox(height: 12),
                        const Text(
                            '"Tamam"a basarak belgenin güncel sürümünü kabul etmiş olursunuz.',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )
              : const Text(
                  'Uygulamayı kullanmaya devam etmek için güncel metni okuyup onaylamanız gerekiyor.'),
          actions: [
            if (pdf != null)
              TextButton(
                onPressed: () => yasalPdfAc(pdf),
                child: const Text('Tamamını Oku (PDF)'),
              )
            else
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
              child: Text(ozet != null ? 'Tamam' : 'Kabul Et ve Devam Et'),
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
