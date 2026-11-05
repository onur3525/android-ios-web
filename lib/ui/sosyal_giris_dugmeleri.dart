import 'dart:async';

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
    this.aktif = true,
  });

  /// Kayıt ekranındaki rol; giriş ekranında `null` (kayıtta sorulur).
  final Role? rol;

  /// Oturum açıldı (giriş ya da kayıt) — çağıran ekran yönlendirir.
  final void Function(String? eposta) tamam;

  /// İstek sürerken (çağıran ekran meşgulken) düğmeler pasif.
  final bool aktif;

  @override
  State<SosyalGirisDugmeleri> createState() => _SosyalGirisDugmeleriState();
}

class _SosyalGirisDugmeleriState extends State<SosyalGirisDugmeleri> {
  SosyalSaglayici? _mesgul;

  // ── ⚠ BEKLEME EKRANI (5 Kas, kullanıcı kararı) ──
  // Google/Apple penceresinde e-posta seçildikten sonra kimlik doğrulanıp
  // sunucuda oturum açılırken (≈1–2 sn) giriş/kayıt formu GÖRÜNMEZ:
  // düğmeye basılınca form tam ekran bekleme görünümüyle örtülür.
  //   · oturum açıldı → çağıranın yönlendirmesi (pushNamedAndRemoveUntil)
  //     bekleme ekranını da kaldırır; yeni ekran bekleme ekranının
  //     ÜSTÜNE gelir, form arada görünmez ve süre UZAMAZ;
  //   · hesap yok → bekleme ekranı yerini doğrudan Üyelik Koşulları'na
  //     bırakır;
  //   · vazgeçildi/hata → bekleme ekranı kalkar, form olduğu gibi döner.
  Future<void> _devam(SosyalSaglayici s) async {
    if (_mesgul != null) {
      return;
    }
    setState(() => _mesgul = s);
    final nav = Navigator.of(context);
    final bekleme = _beklemeRotasi();
    unawaited(nav.push(bekleme));
    final auth = context.read<AuthController>();
    final sonuc = await auth.sosyalGiris(s, rol: widget.rol);
    // Yalnız hâlâ en üstteyse kaldırılır: çağıran gezindiyse (yeni ekran
    // üstte) bekleme ekranı o gezinmeyle zaten kaldırılıyordur.
    void beklemeyiKaldir() {
      if (bekleme.isCurrent) {
        nav.removeRoute(bekleme);
      }
    }

    if (!mounted) {
      beklemeyiKaldir();
      return;
    }
    setState(() => _mesgul = null);
    if (sonuc.iptal) {
      beklemeyiKaldir();
      return;
    }
    if (sonuc.girisYapildi) {
      if (sonuc.hata != null) {
        sysToastErr(context, SysKind.genericError, extra: sonuc.hata);
      }
      widget.tamam(sonuc.eposta);
      // Çağıran gezindiyse bekleme ekranı zaten kalktı; gezinmediyse kalkar.
      beklemeyiKaldir();
      return;
    }
    final belge = sonuc.kayitBelgesi;
    if (belge == null) {
      beklemeyiKaldir();
      sysToastErr(context, SysKind.genericError, extra: sonuc.hata);
      return;
    }
    final kayit = panelRotasi<bool>(
      settings: const RouteSettings(name: SosyalKayitScreen.rotaAdi),
      builder: (_) => SosyalKayitScreen(
        belge: belge,
        saglayici: s,
        rol: widget.rol,
        ad: sonuc.ad,
        eposta: sonuc.eposta,
      ),
    );
    if (bekleme.isCurrent) {
      nav.replace(oldRoute: bekleme, newRoute: kayit);
    } else {
      unawaited(nav.push(kayit));
    }
    final kaydoldu = await kayit.popped;
    if (kaydoldu == true && mounted) {
      widget.tamam(sonuc.eposta);
    }
  }

  /// Tam ekran, geçişsiz bekleme sayfası; geri tuşuyla kapanmaz.
  Route<void> _beklemeRotasi() => PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const SosyalGirisBekleme(),
      );

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
            onPressed: widget.aktif && _mesgul == null ? () => _devam(s) : null,
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

/// Google/Apple ile devam ederken gösterilen tam ekran bekleme görünümü:
/// beyaz zemin, ortada HizmetCep logosu ve dönen işaret (5 Kas).
class SosyalGirisBekleme extends StatelessWidget {
  const SosyalGirisBekleme({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Material(
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo/logo_mark.png', height: 64),
                const SizedBox(height: 12),
                Image.asset('assets/logo/wordmark.png', height: 26),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: RC.blue),
                ),
              ],
            ),
          ),
        ),
      );
}
