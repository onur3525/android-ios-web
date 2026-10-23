import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../domain/profil_menusu.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';

/// SÖZLEŞMELER VE POLİTİKALAR (23 Eki, kullanıcı kararı)
///
/// Profildeki tek "Sözleşmeler ve Politikalar" satırının açtığı sayfa.
/// Belge listesi tek kaynaktan gelir (`kYasalBelgeler`); her satır mevcut
/// `/legal` ekranında belgenin yayımdaki sürümünü açar. Çerez Politikası
/// yalnız web'de listelenir (mobil uygulama çerez kullanmaz).
class YasalBelgelerScreen extends StatelessWidget {
  const YasalBelgelerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final belgeler = kYasalBelgeler.where((b) => kIsWeb || !b.yalnizWeb);
    return RefShell(
      nav: RefBottomNav(
        activeKey: 'profil',
        items: custNavItems(
          context,
          saglayici:
              context.watch<AuthController>().activeRole == Role.provider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠ BAŞLIK MENÜ ADIYLA AYNI (kullanıcı tıkladığı yere geldiğini
          // başlıktan anlar).
          const RefPageTitle(kYasalBelgelerBaslik),
          for (final b in belgeler)
            RefMenuRow(
              key: ValueKey('yasal-${b.slug}'),
              iconAsset: b.ikon,
              iconBg: b.ikonZemini,
              title: b.baslik,
              subtitle: b.altYazi,
              onTap: () => Navigator.pushNamed(context, '/legal',
                  arguments: {'slug': b.slug, 'title': b.baslik}),
            ),
        ],
      ),
    );
  }
}
