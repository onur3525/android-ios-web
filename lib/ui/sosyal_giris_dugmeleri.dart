import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/firebase/sosyal_giris_ayarlari.dart';
import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../data/remote/api_config.dart';
import '../domain/sosyal_saglayici.dart';
import '../screens/sosyal_kayit_screen.dart';
import 'panel_rotasi.dart';
import 'ref_tokens.dart';

/// ═══════════════════════════════════════════════════════════════
/// GOOGLE / APPLE İLE DEVAM ET — TEK KAYNAK (4 Kas, kullanıcı talebi)
///
/// Giriş ve kayıt ekranları AYNI bileşeni kullanır:
///   1. Google/Apple penceresi açılır (kimliği Firebase doğrular).
///   2. Hesap varsa oturum açılır → [tamam].
///   3. Hesap yoksa kayıt ekranı açılır (ad, soyad, rol, iki zorunlu
///      onay); kayıt bitince → [tamam].
/// Kayıt ekranından gelindiyse [rol] bellidir: hesap varsa ve o rol yoksa
/// aynı hesaba eklenir (bir kişi, bir hesap). Telefon ve adres e-postalı
/// kayıttaki AYNI profil tamamlama adımında istenir.
///
/// Düğmeler yalnız platform yapılandırıldığında görünür
/// (`SosyalGirisAyarlari.gorunenler`); hiçbiri yoksa bileşen boştur.
/// ═══════════════════════════════════════════════════════════════
class SosyalGirisDugmeleri extends StatefulWidget {
  const SosyalGirisDugmeleri({
    super.key,
    this.rol,
    required this.tamam,
    this.enabled = true,
  });

  /// Kayıt ekranındaki rol; giriş ekranında `null` (kayıtta sorulur).
  final Role? rol;

  /// Oturum açıldı (giriş ya da kayıt) — çağıran ekran yönlendirir.
  final void Function(String? eposta) tamam;

  final bool enabled;

  @override
  State<SosyalGirisDugmeleri> createState() => _SosyalGirisDugmeleriState();
}

class _SosyalGirisDugmeleriState extends State<SosyalGirisDugmeleri> {
  SosyalSaglayici? _mesgul;

  Future<void> _devam(SosyalSaglayici s) async {
    if (_mesgul != null) {
      return;
    }
    setState(() => _mesgul = s);
    final auth = context.read<AuthController>();
    final sonuc = await auth.sosyalGiris(s, rol: widget.rol);
    if (!mounted) {
      return;
    }
    setState(() => _mesgul = null);
    if (sonuc.iptal) {
      return;
    }
    if (sonuc.girisYapildi) {
      if (sonuc.hata != null) {
        sysToastErr(context, SysKind.genericError, extra: sonuc.hata);
      }
      widget.tamam(sonuc.eposta);
      return;
    }
    final belge = sonuc.kayitBelgesi;
    if (belge == null) {
      sysToastErr(context, SysKind.genericError, extra: sonuc.hata);
      return;
    }
    final kaydoldu = await Navigator.push<bool>(
      context,
      panelRotasi<bool>(
        settings: const RouteSettings(name: SosyalKayitScreen.rotaAdi),
        builder: (_) => SosyalKayitScreen(
          belge: belge,
          saglayici: s,
          rol: widget.rol,
          ad: sonuc.ad,
          eposta: sonuc.eposta,
        ),
      ),
    );
    if (kaydoldu == true && mounted) {
      widget.tamam(sonuc.eposta);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Google/Apple girişi kimliği Firebase'de doğrular ve sunucuya gider;
    // bellek içi (mock) modda çalışmadığı için düğme gösterilmez.
    final liste =
        ApiConfig.useRealApi
        ? SosyalGirisAyarlari.gorunenler
        : const <SosyalSaglayici>[];
    if (liste.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('ya da',
                  style: refText(
                      size: RF.s13, weight: RF.w400, color: RC.textSoft)),
            ),
            const Expanded(child: Divider()),
          ]),
        ),
        for (final s in liste) ...[
          _SosyalDugme(
            saglayici: s,
            busy: _mesgul == s,
            onPressed: widget.enabled && _mesgul == null ? () => _devam(s) : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Apple düğmesi siyah zemin + beyaz yazı (Apple'ın düğme kuralı); Google
/// düğmesi beyaz zemin + çerçeve.
class _SosyalDugme extends StatelessWidget {
  const _SosyalDugme({
    required this.saglayici,
    required this.busy,
    required this.onPressed,
  });

  final SosyalSaglayici saglayici;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final apple = saglayici == SosyalSaglayici.apple;
    final zemin = apple ? Colors.black : Colors.white;
    final yazi = apple ? Colors.white : RC.text;
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: zemin,
          foregroundColor: yazi,
          disabledBackgroundColor: zemin.withValues(alpha: 0.6),
          side: BorderSide(
              color: apple ? Colors.black : RC.borderAlt, width: 1.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RR.r12)),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: yazi))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (apple) ...[
                    Icon(Icons.apple, color: yazi, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text('${saglayici.ad} ile devam et',
                      style: refText(
                          size: RF.s14, weight: RF.w700, color: yazi)),
                ],
              ),
      ),
    );
  }
}
