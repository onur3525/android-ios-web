import 'package:flutter/material.dart';

import '../ui/gezgin.dart';
import '../ui/ref_tokens.dart';

/// ═══════════════════════════════════════════════════════════════
/// BAĞLANILIYOR — SUNUCU UYKUDAYKEN OTURUMLU AÇILIŞ (web + mobil, 15 Eki)
///
/// Kullanıcı bulgusu: "1. girişimde ana kayıt sayfasına, 2. girişimde
/// kayıtlı olduğum rol ekranına yönlendiriyor." Sunucu (Render ücretsiz
/// planı) uykudayken oturum kısa bekleme içinde yenilenemiyor ve açılış ana
/// sayfaya düşüyordu.
///
/// Bu tarayıcıda oturum izi varsa `main()` bu ekranı açar ve oturum
/// yenilemesini bekletir (`bekleyen`). Sonuç geldiğinde normal açılışla
/// AYNI hesaptan çıkan rotaya geçilir; oturum gerçekten bittiyse ana
/// sayfaya.
///
/// MOBİL (15 Eki): uygulama açılışında sunucu kısa bütçede yanıt vermezse
/// ama cihazda oturum jetonu varsa `SplashScreen` de bu ekranı açar
/// (`_oturumuBekle`); kullanıcı yeniden giriş ekranına düşmez.
/// ═══════════════════════════════════════════════════════════════
class BaglaniyorEkrani extends StatefulWidget {
  const BaglaniyorEkrani({super.key});

  static const String rota = '/baglaniyor';

  /// `main()` tarafından açılıştan önce kurulur; bir kez tüketilir.
  static Future<({String rota, String? argRota, Object? arg})>? bekleyen;

  @override
  State<BaglaniyorEkrani> createState() => _BaglaniyorEkraniState();
}

class _BaglaniyorEkraniState extends State<BaglaniyorEkrani> {
  @override
  void initState() {
    super.initState();
    _bekle();
  }

  Future<void> _bekle() async {
    final f = BaglaniyorEkrani.bekleyen;
    BaglaniyorEkrani.bekleyen = null;
    // ⚠ Bekleyen yoksa (ör. bu adres elle açıldı) ana sayfaya geçilir.
    ({String rota, String? argRota, Object? arg}) r =
        (rota: '/home', argRota: null, arg: null);
    if (f != null) {
      try {
        r = await f;
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    final gezgin = gezginAnahtari.currentState ?? Navigator.of(context);
    gezgin.pushNamedAndRemoveUntil(r.rota, (_) => false);
    if (r.argRota != null) {
      gezgin.pushNamed(r.argRota!, arguments: r.arg);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RC.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo/wordmark.png', height: 30),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(height: 18),
                Text('Bağlanılıyor…',
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s16, weight: RF.w700, color: RC.text)),
                const SizedBox(height: 6),
                Text('Oturumunuz açılıyor, bu birkaç saniye sürebilir.',
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s125, weight: RF.w400, color: RC.textSoft)),
              ],
            ),
          ),
        ),
      );
}
