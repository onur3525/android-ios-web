import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import 'sys_state.dart';
import 'geri.dart';

/// ROL VE OTURUM KORUMASI
///
/// Korumalı bir ekranı SARAR. Üç durumu ele alır:
///   • Oturum yok            → giriş ekranına yönlendirir
///   • Rol uymuyor           → yetkisiz durumu gösterir, ekranı ÇİZMEZ
///   • Uygun                 → asıl ekranı çizer
///
/// Bu koruma NAVIGATOR SEVİYESİNDE değil EKRAN SEVİYESİNDE çalışır;
/// böylece derin bağlantı, named route veya doğrudan push farketmeksizin
/// aynı kontrol uygulanır. Ekranın kendisi hiçbir zaman inşa edilmez,
/// dolayısıyla veri çağrısı da yapılmaz.
class RoleGuard extends StatelessWidget {
  /// Ekranın gerektirdiği rol. null → yalnız oturum yeterli.
  final Role? requires;
  final WidgetBuilder builder;

  const RoleGuard({super.key, required this.builder, this.requires});

  /// Yalnız hizmet verenin görebileceği ekranlar.
  const RoleGuard.provider({super.key, required this.builder})
      : requires = Role.provider;

  /// Yalnız müşterinin görebileceği ekranlar.
  const RoleGuard.customer({super.key, required this.builder})
      : requires = Role.customer;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final acc = auth.currentAccount;

    // ── Oturum yok: korumalı ekran ÇİZİLMEZ ──
    if (acc == null) {
      // ⚠ HEDEF `/home` — `/login` DEĞİL.
      //
      // Referans `pfLogout()`: `LOGGED=false; navigate('home')`.
      // Guard `/login`'e atıyordu; profilden çıkışta ekran zaten
      // `/home`'a itiliyor, ardından guard'ın post-frame görevi
      // kullanıcıyı GİRİŞ ekranına düşürüyordu. Oturum düşmesi,
      // hesap dondurma ve çıkış — üçünün de hedefi ana sayfadır
      // (rol kartlarının bulunduğu ekran).
      //
      // Logout sonrası geri tuşuyla dönülse bile burada yakalanır.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── Rol uyuşmuyor ──
    if (requires != null && acc.activeRole != requires) {
      final wanted = requires == Role.provider ? 'hizmet veren' : 'hizmet alan';
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => geriGit(context)),
        ),
        body: Center(
          child: SysState(
            SysKind.unauthorized,
            title: 'Bu ekrana erişiminiz yok',
            desc: 'Bu bölüm yalnızca $wanted rolünde kullanılabilir. '
                'Rolünüzü profil ekranından değiştirebilirsiniz.',
            action: 'Geri Dön',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    return builder(context);
  }
}
