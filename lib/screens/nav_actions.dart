import 'package:flutter/material.dart';

/// ALT NAVİGASYON ÖĞELERİ — referans `custNav(act)`
///
/// ```js
/// let items = [
///   ['ilanver',  'İlan Ver',    IC_ADDBOX(22), "openPost()"],
///   ['ilanlarim','İlanlarım',   IC_CLIP(22),   "navigate('cust')"],
///   ['bildirim', 'Bildirimler', IC_BELL(22),   "navigate('notif')"],
///   ['profil',   'Profil',      IC_PROFILE,    "navigate('profile')"],
/// ];
/// if (MODE === 'provider') items = items.filter(i => i[0] !== 'ilanver');
/// ```
///
/// Hizmet veren modunda "İlan Ver" sekmesi LİSTEDEN ÇIKARILIR —
/// gizlenmez, hiç oluşturulmaz (referansta `filter`).
List<({String key, String label, String asset, VoidCallback onTap})>
    custNavItems(BuildContext context, {required bool saglayici}) {
  final t = <({String key, String label, String asset, VoidCallback onTap})>[
    if (!saglayici)
      (
        key: 'ilanver',
        label: 'İlan Ver',
        asset: 'assets/svg/ic_addbox.svg',
        onTap: () => Navigator.pushNamed(context, '/customer/new-listing'),
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
      ),
    (
      key: 'bildirim',
      label: 'Bildirimler',
      asset: 'assets/svg/ic_bell.svg',
      onTap: () => Navigator.pushNamed(context, '/notifications'),
    ),
    (
      key: 'profil',
      label: 'Profil',
      asset: 'assets/svg/ic_profile.svg',
      onTap: () => Navigator.pushNamed(context, '/profile'),
    ),
  ];
  return t;
}
