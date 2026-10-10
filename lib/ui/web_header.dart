import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'olcu.dart';
import 'header_arama.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// Masaüstü web'de üst navigasyon çizilsin mi?
///
/// ── ⚠ İKİ KOŞUL BİRLİKTE ──
///
/// `kIsWeb` OLACAK ve ekran geniş OLACAK.
///
/// Yalnız genişliğe bakılsaydı Android/iOS TABLETLERİ de (>600 px) bu
/// dala düşer, alt navigasyonları kaybolur ve kilitli mobil baseline
/// bozulurdu. Yalnız `kIsWeb`e bakılsaydı dar tarayıcı penceresinde
/// üst menü sıkışır, mobil web görünümü bozulurdu.
///
/// ⚠ EŞİK `masaustuMu` (≥1024), `genisMi` (≥600) DEĞİL: 700 px'lik
/// bir tarayıcı penceresinde üst menü sıkışır, sekmeler ve "İlan Ver"
/// düğmesi yan yana sığmaz. O genişlikte mobil düzen daha iyidir ve
/// talimat da "dar tarayıcı genişliklerinde mobil web davranışını
/// bozma" diyor.
///
/// ⚠ `RefBottomSheet` `genisMi` KULLANIR, BU FARK BİLİNÇLİDİR: panel
/// 700 px'te de ortalanmış dialog olarak düzgün durur (560 px'lik
/// içeriği vardır); navigasyon ise yatay yer ister.
bool masaustuNav(BuildContext context) =>
    kIsWeb && ekranSinifi(context).masaustuMu;

/// ═══════════════════════════════════════════════════════════════
/// MASAÜSTÜ ÜST NAVİGASYON
///
/// ## ⚠ YENİ TASARIM DEĞİL, AYNI ÖĞELERİN YATAY DİZİLİŞİ
///
/// Girdi `RefBottomNav` ile BİREBİR aynı kayıt tipidir: aynı `key`,
/// `label`, `asset`, `onTap`, `rozet` ve `belirginRozetSayisi`.
/// Çağıran ekranlar navigasyon öğelerini İKİNCİ KEZ tanımlamaz;
/// `nav_actions.dart`taki tek kaynak ikisini de besler.
///
/// Renkler `RC`, yazı `refText`, ikonlar aynı SVG dosyaları. Yeni
/// renk, yeni ikon, yeni tipografi ÜRETİLMEDİ.
///
/// ## ⚠ NİÇİN ALT BAR MASAÜSTÜNDE KULLANILMAZ
///
/// Alt navigasyon parmağın eriştiği yere göre tasarlanmıştır. 1920 px
/// bir ekranda dört sekme ekranın altına dağılır, aralarında devasa
/// boşluk kalır ve fare oraya kadar iner. Masaüstünde beklenti üst
/// menüdür.
///
/// ## ⚠ "İlan Ver" ÇENTİĞİ MASAÜSTÜNDE YOK
///
/// Alt barda "İlan Ver" ortada, çentikli ve yükseltilmiş bir düğmedir;
/// o biçim parmak erişimi için vardır. Üst menüde aynı öğe SAĞ UÇTA,
/// birincil düğme olarak durur — işlevi, adı ve ikonu aynıdır, yalnız
/// yeri değişir. Hizmet veren tarafında bu öğe zaten YOKTUR
/// (`nav_actions.dart`), o tarafta menü yalnız sekmelerden oluşur.
///
/// ## ⚠ `PreferredSizeWidget`
///
/// Hem `Scaffold.appBar` olarak (jobs_screen) hem düz widget olarak
/// (RefShell) kullanılabilsin diye. İki ekran iki farklı iskelet
/// kullanıyor; tek bileşen ikisine de uyar.
/// ═══════════════════════════════════════════════════════════════
class WebHeader extends StatelessWidget implements PreferredSizeWidget {
  const WebHeader({super.key, required this.items, required this.activeKey});

  /// ⚠ TİP `RefBottomNav.items` İLE AYNI OLMALI. Biri güncellenip
  /// öteki unutulursa derleme hatası verir — sessiz ayrışma olmaz.
  final List<
      ({
        String key,
        String label,
        String asset,
        VoidCallback onTap,
        bool rozet,
        int belirginRozetSayisi,
      })> items;

  final String activeKey;

  static const double _yukseklik = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_yukseklik);

  @override
  Widget build(BuildContext context) {
    // ⚠ "İlan Ver" AYRILIR: sağ uçta birincil düğme olur. Hizmet veren
    // tarafında bu öğe yoktur; `indexWhere` -1 döner ve menü yalnız
    // sekmelerden oluşur.
    final ilanVerIndex = items.indexWhere((it) => it.key == 'ilanver');
    final sekmeler = [...items];
    final ilanVer = ilanVerIndex == -1 ? null : sekmeler.removeAt(ilanVerIndex);

    return Material(
      color: RC.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _yukseklik,
          // ⚠ İÇERİK 1200'DE SINIRLANIR: zemin kenardan kenara uzanır
          // ama menü, sayfanın geri kalanıyla AYNI eksende durur.
          // Sınırlanmasaydı menü 2560 px'e yayılır, içerik ortada
          // kalırdı.
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: IcerikGenisligi.izgara),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    // ⚠ MEVCUT MARKA ASSET'İ: wordmark yeniden
                    // çizilmedi, renkleri değiştirilmedi.
                    Image.asset('assets/logo/wordmark.png', height: 26),
                    const SizedBox(width: 20),
                    // ── ⚠ ARAMA ALANI (`ui/header_arama.dart`) ──
                    //
                    // Web'de arama header'ın parçasıdır; kullanıcı
                    // hangi sayfada olursa olsun oradan aramayı
                    // bekler. Ana sayfadaki `InlineSearchBox`a
                    // DOKUNULMADI — o bir sayfa bileşeni, bu ise
                    // header'a sığan dar kardeşi. İkisi de aynı arama
                    // motorunu ve aynı yönlendirmeyi kullanır.
                    //
                    // ⚠ GENİŞLİK KADEMELİ: laptopta sekmeler ve "İlan
                    // Ver" düğmesiyle birlikte sığması için daralır.
                    // ⚠ GENİŞLİK KADEMELİ: eşik 900'e indiği için
                    // laptop kipi artık 900–1439 arasını kapsıyor.
                    // 900'de 260 px arama + sekmeler + "İlan Ver"
                    // sıkışıyordu; alt uçta 200'e iner.
                    HeaderArama(
                      genislik: switch (ekranSinifi(context)) {
                        EkranSinifi.masaustu => 420,
                        _ => MediaQuery.sizeOf(context).width < 1024 ? 200 : 260,
                      },
                    ),
                    const SizedBox(width: 20),
                    for (final it in sekmeler)
                      _Sekme(oge: it, aktif: it.key == activeKey),
                    const Spacer(),
                    if (ilanVer != null)
                      SizedBox(
                        width: 150,
                        child: RefPrimaryButton(
                          ilanVer.label,
                          iconAsset: ilanVer.asset,
                          onPressed: ilanVer.onTap,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Üst menüdeki tek sekme.
class _Sekme extends StatelessWidget {
  const _Sekme({required this.oge, required this.aktif});

  final ({
    String key,
    String label,
    String asset,
    VoidCallback onTap,
    bool rozet,
    int belirginRozetSayisi,
  }) oge;

  final bool aktif;

  @override
  Widget build(BuildContext context) {
    // ⚠ RENKLER ALT BARDAKİYLE AYNI: aktif mavi, pasif `textMuted`.
    final renk = aktif ? RC.blue : RC.textMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: RefTap(
        onTap: oge.onTap,
        borderRadius: BorderRadius.circular(RR.r9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RefSvg(oge.asset, size: 18, color: renk),
                  const SizedBox(width: 8),
                  Text(oge.label,
                      style: refText(
                          size: RF.s135, weight: RF.w600, color: renk)),
                ],
              ),
              // ⚠ GÖSTERGELER ALT BARDAKİ DİLİ KORUR: nokta "yeni var"
              // der, sayı rozeti "kaç tane" der. Renkleri ve anlamları
              // orada ne ise burada da odur.
              if (oge.rozet)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: RC.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: RC.white, width: 1.5),
                    ),
                  ),
                ),
              if (oge.belirginRozetSayisi > 0)
                Positioned(
                  right: -12,
                  top: -8,
                  child: RefSayiRozeti(
                    sayi: oge.belirginRozetSayisi,
                    halkaRengi: RC.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
