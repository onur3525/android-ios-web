import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/notification_controller.dart';

/// ALT NAVİGASYON ÖĞELERİ
///
/// ── ⚠ MÜŞTERİDE 5 SEKME, SAĞLAYICIDA 4 ──
///
/// Müşteri: Bul → İlanlarım → İlan Ver → Bildirimler → Profil.
/// Sağlayıcı: İşlerim → Kazandığım → Bildirimler → Profil (DEĞİŞMEDİ).
///
/// "Bul" yalnız müşteride vardır — hizmet veren kendi hizmetini
/// aramaz. "İlan Ver" sağlayıcı modunda LİSTEDEN ÇIKARILIR —
/// gizlenmez, hiç oluşturulmaz.
List<({
  String key,
  String label,
  String asset,
  VoidCallback onTap,
  bool rozet
})>
    custNavItems(BuildContext context, {required bool saglayici}) {
  // ── ⚠ OKUNMAMIŞ BİLDİRİM ──
  //
  // Sayı DEĞİL, yalnız "var mı" bilgisi taşınır: alt bar dar, iki
  // haneli sayı hizayı bozardı. Sayı Bildirimler ekranında görünür.
  //
  // ⚠ `watch`: yeni bildirim gelince alt bar KENDİLİĞİNDEN yenilenir;
  // kullanıcı ekrana girmeden noktayı görür.
  final me = context.watch<AuthController>().currentAccount;
  final okunmamis = me != null &&
      context.watch<NotificationController>().unreadCount(me.id) > 0;

  final t = <({
  String key,
  String label,
  String asset,
  VoidCallback onTap,
  bool rozet
})>[
    // ── ⚠ "BUL" YALNIZ MÜŞTERİDE, EN SOLDA ──
    //
    // Hizmet verenin arayacağı bir "hizmet" yok; bu sekme yalnız
    // müşteri modunda üretilir.
    if (!saglayici)
      (
        key: 'bul',
        label: 'Bul',
        asset: 'assets/svg/ic_search.svg',
        onTap: () => Navigator.pushNamed(context, '/customer/find-provider'),
        rozet: false,
      ),
    (
      key: 'ilanlarim',
      label: saglayici ? 'İşlerim' : 'İlanlarım',
      asset: 'assets/svg/ic_clip.svg',
      onTap: () => Navigator.pushNamedAndRemoveUntil(
        context,
        saglayici ? '/provider/jobs' : '/customer/listings',
        (r) => false,
      ),
      rozet: false,
    ),
    // ⚠ "İlan Ver" ORTA konuma taşındı (Bul, İlanlarım, İlan Ver,
    // Bildirim, Profil) — yalnız SIRASI değişti, davranışı AYNI.
    if (!saglayici)
      (
        key: 'ilanver',
        label: 'İlan Ver',
        asset: 'assets/svg/ic_addbox.svg',
        onTap: () => Navigator.pushNamed(context, '/customer/new-listing'),
        rozet: false,
      ),
    // ⚠ SAĞLAYICIYA ÖZEL SEKME.
    //
    // Üstteki "Kazandığım işler" segment sekmesi buraya taşındı:
    // aynı bilgi iki yerde durmaz ve sağlayıcıda alt bar da müşteri
    // tarafındaki gibi DÖRT eşit sekmeye tamamlanır.
    if (saglayici)
      (
        key: 'kazandigim',
        label: 'Kazandığım',
        asset: 'assets/svg/ic_checkc.svg',
        onTap: () => Navigator.pushNamedAndRemoveUntil(
          context,
          '/provider/won',
          (r) => false,
        ),
        rozet: false,
      ),
    (
      key: 'bildirim',
      label: 'Bildirimler',
      asset: 'assets/svg/ic_bell.svg',
      onTap: () => Navigator.pushNamed(context, '/notifications'),
      // ⚠ YALNIZ BİLDİRİM SEKMESİNDE: nokta okunmamış bildirim
      // varsa çizilir.
      rozet: okunmamis,
    ),
    (
      key: 'profil',
      label: 'Profil',
      asset: 'assets/svg/ic_profile.svg',
      onTap: () => Navigator.pushNamed(context, '/profile'),
      rozet: false,
    ),
  ];
  return t;
}
