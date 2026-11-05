import 'package:flutter/material.dart';

import '../../data/models/account.dart' show Role;
import '../../ui/kalan_alanda_ortala.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../nav_actions.dart';
import '../profil_tamamlama_screen.dart' show profilKapisi;

/// ═══════════════════════════════════════════════════════════════
/// EKSİK HİZMET VEREN KAPISI — TEK KAYNAK (6 Kas, kullanıcı kararı)
///
/// Kaydı tamamlanmamış hizmet veren aktif hesap sayılmaz: hizmet veren
/// rolündeki ekranlar (İşlerim, Kazandığım, Bildirimler, iş/talep detayı,
/// sohbet, Hizmet Kategorilerim/Bölgelerim, Durum, Yorumlar) içerik yerine
/// BU uyarıyı çizer. "Formu Doldur" → Profilinizi Tamamlayın. Form
/// tamamlanınca `RoleGuard` hesabı izlediği için asıl ekran kendiliğinden
/// açılır. Alt menüde Profil açık kalır (çıkış, hesap ayarları, destek).
///
/// Çağıran: `RoleGuard` (`eksikSaglayiciyiKapat`). Ekranlar kendi kapısını
/// yazmaz. Sunucu aynı kuralı ayrıca uygular (`profilKapisi`,
/// `saglayiciEtkinMi`).
/// ═══════════════════════════════════════════════════════════════
class SaglayiciProfilKapisi extends StatelessWidget {
  const SaglayiciProfilKapisi({super.key});

  static const String baslik = 'Önce formu tamamlayalım!';
  static const String metin =
      'Formu eksiksiz doldurmazsanız ilanları göremez, Bul özelliğinde '
      'görünemez ve hiçbir ilana ya da isteğe teklif veremezsiniz. Hemen '
      'formu doldurun, işleri listelemeye başlayalım.';
  static const String dugme = 'Formu Doldur';

  /// Alt menüde seçili görünecek sekme — açılan rotaya göre.
  static String _aktifSekme(BuildContext context) {
    final ad = ModalRoute.of(context)?.settings.name;
    if (ad == '/provider/won') {
      return 'kazandigim';
    }
    if (ad == '/notifications') {
      return 'bildirim';
    }
    return 'ilanlarim';
  }

  @override
  Widget build(BuildContext context) {
    return RefShell(
      nav: RefBottomNav(
        activeKey: _aktifSekme(context),
        items: custNavItems(context, saglayici: true),
      ),
      child: KalanAlandaOrtala(
        altBosluk: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                baslik,
                textAlign: TextAlign.center,
                style: refText(size: RF.s20, weight: RF.w700, color: RC.text),
              ),
              const SizedBox(height: 10),
              Text(
                metin,
                textAlign: TextAlign.center,
                style: refText(
                  size: RF.s14,
                  weight: RF.w400,
                  color: RC.textSoft,
                  height: RF.lh150,
                ),
              ),
              const SizedBox(height: 20),
              RefPrimaryButton(
                dugme,
                onPressed: () => profilKapisi(context, Role.provider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
