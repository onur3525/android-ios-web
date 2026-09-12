import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ref_tokens.dart';
import '../core/turkce_arama.dart';
import '../core/geri.dart';

/// ═══════════════════════════════════════════════════════════════
/// REFERANS ORTAK BİLEŞENLERİ
///
/// Kaynak: `hizmetcep-uygulama-son-kod.html`
/// Her bileşenin CSS karşılığı doküman yorumunda verilmiştir.
///
/// ⚠ Material varsayılanı KULLANILMAZ. `ElevatedButton`, `Card`,
/// `ListTile`, `AppBar` yerine referans ölçülerinde özel widget'lar.
/// ═══════════════════════════════════════════════════════════════

/// Referans `.tap` — dokunma geri bildirimi.
///
/// `animation: inkRipple .30s cubic-bezier(.4,0,.2,1) forwards,
///             inkFade .375s ease-out`
///
/// Flutter'da `InkWell` aynı davranışı verir; splash rengi referans
/// mavisinin düşük opaklığıdır.
class RefTap extends StatelessWidget {
  const RefTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: RC.blue.withValues(alpha: 0.10),
        highlightColor: RC.blue.withValues(alpha: 0.05),
        child: child,
      ),
    );
  }
}

/// Referans `.scroll`
///
/// ```css
/// .scroll{flex:1;overflow-y:auto;overflow-x:hidden;
///   -webkit-overflow-scrolling:touch;   /* momentum */
///   overscroll-behavior-y:auto;         /* elastik uç */
///   scrollbar-width:none;               /* çubuk gizli */
/// }
/// ```
///
/// CSS yorumunda Android için `ClampingScrollPhysics` belirtilmiş;
/// momentum + elastik uç iOS davranışıdır. Flutter platforma göre
/// doğru fiziği kendi seçer (`BouncingScrollPhysics` iOS,
/// `ClampingScrollPhysics` Android) — bu yüzden varsayılan bırakıldı.
/// ODAKLANAN ALANIN KLAVYE ÜSTÜNDE KALMASI İÇİN AYRILAN PAY (px).
///
/// Flutter, bir metin alanı odaklandığında onu görünür alana kaydırır
/// (`EditableText` → `scrollPadding`). Varsayılan 20px yalnız alanın
/// KENARININ görünmesini sağlar; uygulamada birçok ekranın altında
/// SABİT bir düğme şeridi bulunduğu için alan o şeridin ardında
/// kalıyordu.
///
/// 140px = sabit düğme yüksekliği (~72) + üst/alt dolgu (~28) +
/// rahat okuma payı (~40). Böylece odaklanan satır her zaman hem
/// klavyenin hem düğmenin ÜSTÜNDE görünür.
///
/// ⚠ Bu Flutter'ın DESTEKLEDİĞİ parametredir. Yasaklı yollar
/// KULLANILMAZ: global `Scrollable.ensureVisible` sarmalayıcısı yok,
const double kAlanKaydirmaPayi = 140;

class RefScroll extends StatelessWidget {
  const RefScroll({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      // scrollbar-width:none
      behavior: const _NoScrollbar(),
      child: SingleChildScrollView(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _NoScrollbar extends ScrollBehavior {
  const _NoScrollbar();
  @override
  Widget buildScrollbar(BuildContext c, Widget child, ScrollableDetails d) =>
      child;
  @override
  Widget buildOverscrollIndicator(
          BuildContext c, Widget child, ScrollableDetails d) =>
      child;
}

/// Referans SVG ikonu.
///
/// `flutter_svg` ile aynı path verisi çizilir; Material ikon
/// KULLANILMAZ. Renk verilirse SVG'nin kendi rengini ezer.
class RefSvg extends StatelessWidget {
  const RefSvg(
    this.asset, {
    super.key,
    required this.size,
    this.color,
  });

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

/// Referans `.search` — ana sayfa arama kutusu.
///
/// ```css
/// .search{display:flex;align-items:center;gap:10px;height:53px;
///   padding:0 11px;margin-top:12px;background:#fff;
///   border:1px solid #ECEEF2;border-radius:13px;color:#1D6BE3;
///   box-shadow:0 1px 3px rgba(16,24,40,.05);width:100%}
/// .search .t1{font-size:14.5px;font-weight:400;color:#9AA0A6;
///   letter-spacing:-.3px;line-height:1.15;white-space:nowrap}
/// .search .t2{font-size:9.5px;font-weight:400;color:#BCC0C6;
///   margin-top:3px;line-height:1.2;letter-spacing:-.25px;
///   white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
/// ```
class RefSearchBox extends StatelessWidget {
  const RefSearchBox({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        height: 53,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: const Color(0xFFECEEF2)),
          borderRadius: BorderRadius.circular(RR.r13),
          boxShadow: RS.card,
        ),
        child: Row(
          children: [
            // ${IC_SEARCH(23,'#A8ADB4')}
            const RefSvg('assets/svg/ic_search.svg',
                size: 23, color: Color(0xFFA8ADB4)),
            const SizedBox(width: 10), // gap:10px
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: refText(
                      size: 14.5,
                      weight: RF.w400,
                      color: const Color(0xFF9AA0A6),
                      height: RF.lh115,
                      letterSpacing: RF.lsM03,
                    ),
                  ),
                  const SizedBox(height: 3), // margin-top:3px
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                      size: 9.5,
                      weight: RF.w400,
                      color: const Color(0xFFBCC0C6),
                      height: RF.lh120,
                      letterSpacing: RF.lsM025,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ${IC_CHEV('#16233D',23)}
            const RefSvg('assets/svg/ic_chev.svg', size: 23, color: RC.text),
          ],
        ),
      ),
    );
  }
}

/// Referans `.rcbtn` — rol kartı içindeki beyaz CTA butonu.
///
/// ```css
/// .rcbtn{display:inline-flex;align-items:center;gap:8px;background:#fff;
///   border:none;height:31px;padding:0 12px;border-radius:9px;
///   box-shadow:0 3px 9px rgba(16,24,40,.10)}
/// .rcbtn span{font-size:11.5px;font-weight:700;color:#16233D;
///   white-space:nowrap;letter-spacing:-.3px}
/// ```
class RefWhiteCta extends StatelessWidget {
  const RefWhiteCta({
    super.key,
    required this.iconAsset,
    required this.iconColor,
    required this.label,
  });

  final String iconAsset;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: RC.white,
        borderRadius: BorderRadius.circular(RR.r9),
        boxShadow: RS.raised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ${IC_PERSON(renk,17)}
          RefSvg(iconAsset, size: 17, color: iconColor),
          const SizedBox(width: 8), // gap:8px
          // ── ⚠ ETİKET ESNER, TAŞMAZ ──
          //
          // `Row` içinde düz `Text` doğal genişliğini istiyordu; dar
          // ekranda veya büyük yazı ölçeğinde satır taşıyordu
          // ("RenderFlex overflowed by 2.8 pixels on the right").
          //
          // ⚠ `Flexible` yalnız YER YETMEZSE devreye girer: sığdığı
          // sürece görünüm birebir aynı kalır, sığmazsa metin
          // kısalır — ikon ve ok yerinde durur.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: refText(
                size: RF.s115,
                weight: RF.w700,
                color: RC.text,
                letterSpacing: RF.lsM03,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ${IC_CHEV('#16233D',15)}
          const RefSvg('assets/svg/ic_chev.svg', size: 15, color: RC.text),
        ],
      ),
    );
  }
}

/// Referans `.sq` — rol kartı köşe ikonu (gradyanlı kare).
///
/// ```css
/// .sq{width:29px;height:29px;border-radius:9px;display:flex;
///   align-items:center;justify-content:center;flex-shrink:0}
/// .sq-b{background:linear-gradient(160deg,#2E7BF6,#1348C9);
///   box-shadow:0 3px 8px rgba(21,74,196,.26)}
/// .sq-o{background:linear-gradient(160deg,#FF9A2E,#EE7208);
///   box-shadow:0 3px 8px rgba(238,114,8,.24)}
/// ```
class RefGradientSquare extends StatelessWidget {
  const RefGradientSquare({
    super.key,
    required this.gradient,
    required this.shadow,
    required this.child,
  });

  final LinearGradient gradient;
  final List<BoxShadow> shadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(RR.r9),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// Referans `.card` — beyaz bilgi kartı.
///
/// ```css
/// .card{background:#fff;border:1px solid #EFF1F4;border-radius:16px;
///   padding:16px 11px;margin-top:16px;
///   box-shadow:0 1px 3px rgba(16,24,40,.05)}
/// ```
class RefCard extends StatelessWidget {
  const RefCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 11),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border2),
        borderRadius: BorderRadius.circular(RR.r16),
        boxShadow: RS.card,
      ),
      child: child,
    );
  }
}


/// Oranı korunan SVG (illüstrasyonlar için).
///
/// `RefSvg` kare varsayar; bu widget yalnız genişlik alır, yükseklik
/// SVG'nin kendi `viewBox` oranından gelir.
class RefSvgFlexible extends StatelessWidget {
  const RefSvgFlexible(this.asset, {super.key, required this.width});

  final String asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      fit: BoxFit.contain,
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// KAYIT / GİRİŞ FORM BİLEŞENLERİ
//
// Kaynak: `hizmetcep-v66-final__1_.html` → `vLogin`
//
// ⚠ Bu bileşenler YENİDİR; `hc_widgets.dart` DEĞİŞTİRİLMEMİŞTİR.
// Diğer ekranlar eski bileşenleri kullanmaya devam eder.
// ═══════════════════════════════════════════════════════════════

/// `.rg-back` — sol üst geri düğmesi.
///
/// Referansta `<button class="rg-back tap" onclick="history.back()">`.
class RefBackButton extends StatelessWidget {
  const RefBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      // ⚠ Varsayılan geri: yığın boşsa ana ekrana gider
      // (bkz. core/geri.dart) — buton ölü kalmaz.
      onTap: onTap ?? () => geriGit(context),
      borderRadius: BorderRadius.circular(RR.circle),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: RefSvg('assets/svg/ic_back.svg', size: 22),
      ),
    );
  }
}

/// `.lg-ico` — daire içinde ekran ikonu.
///
/// ```css
/// .lg-ico{width:74px;height:74px;border-radius:50%;background:#EAF1FB;
///   display:flex;align-items:center;justify-content:center;
///   margin:6px auto 14px}
/// ```
class RefScreenIcon extends StatelessWidget {
  const RefScreenIcon({
    super.key,
    required this.asset,
    this.iconSize = 40,
    this.iconColor = RC.blue,
  });

  final String asset;

  /// `.lg-ico svg{width:40px;height:40px}`
  final double iconSize;

  /// `.lg-ico{color:#1D6BE3}` — SVG `currentColor` bunu alır.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: RC.blueSoft, // #EAF1FB
        shape: BoxShape.circle,
      ),
      child: RefSvg(asset, size: iconSize, color: iconColor),
    );
  }
}

/// ── ⚠ ZORUNLU ALAN YER TUTUCUSU — TEK KAYNAK ──
///
/// Yer tutucu metni GRİ, sonundaki yıldız KIRMIZI olmalıdır.
///
/// ⚠ `hintText` BUNU YAPAMAZ: düz metindir ve tek renk alır; içine
/// `*` konulursa yıldız da gri placeholder rengini miras alır ve
/// zorunluluk işareti görünmez hâle gelir. Bu yüzden `hintText`
/// yerine `hint` WIDGET'ı kullanılır.
///
/// ⚠ ZORUNLULUK ARTIK ALANIN İÇİNDE, YER TUTUCUNUN SONUNDA GÖSTERİLİR.
///
/// Önceki iki yaklaşım da bırakıldı:
///   · Etikette yıldız (`RefFieldLabel`) — kutunun dışında ayrı satır
///   · Alanın solunda ayrı yıldız bileşeni — metinden kopuk duruyordu
/// Referans, kayıt ekranının deseni: kutu içinde açıklayıcı metin ve
/// hemen ardından yıldız. Böylece dışarıda hiç etiket kalmaz.
///
/// ⚠ METİN TAŞMAZ: `maxLines: 1` ve `ellipsis` verilir. Metinler
/// 320 dp genişlikte %130 yazı ölçeğinde bile sığacak şekilde
/// KISA seçilmiştir (en uzunu `Yeni şifre tekrar *`). Yeni bir metin
/// eklerken bu sınır gözetilmelidir.
///
/// [metin] sondaki `*` OLMADAN verilir; yıldızı bu yardımcı ekler.
Widget refYerTutucu(String metin, {required bool zorunlu, double? boyut}) {
  final gri = refText(
    size: boyut ?? RF.s145,
    weight: RF.w500,
    color: RC.greyLight,
  );
  if (!zorunlu) {
    return Text(metin,
        style: gri, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
  // ⚠ YILDIZ SOLDA — `RefRegDropdown`daki (İl/İlçe/Mahalle/Hizmet
  // Kategorileri) referans desenle TUTARLI hale getirildi. Önceden
  // METNİN SONUNDAYDI ("Ad *"); artık ÖNÜNDE ("* Ad") — uygulama
  // genelinde zorunlu alan yıldızının TEK, TUTARLI konumu budur.
  return RichText(
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    text: TextSpan(style: gri, children: [
      TextSpan(
        text: '* ',
        style: refText(
          size: boyut ?? RF.s145,
          weight: RF.w700,
          color: RC.requiredStar,
        ),
      ),
      TextSpan(text: metin),
    ]),
  );
}

/// `.rg-f` — form alanı kabı (ikon + girdi + son ek).
///
/// ```css
/// .rg-f{display:flex;align-items:center;gap:12px;background:#fff;
///   border:1.5px solid #E7EAEF;border-radius:13px;padding:14px 15px;
///   margin-bottom:11px}
/// .rg-star{color:#FF4D4F;font-weight:700;font-size:15px;line-height:1}
/// .rg-input{font-size:15px;font-weight:500;color:#16233D;
///   letter-spacing:-.1px}
/// ```
class RefFormField extends StatelessWidget {
  const RefFormField({
    super.key,
    required this.iconAsset,
    required this.controller,
    required this.hint,
    this.zorunlu = true,

    /// Kutunun ÜSTÜNDE görünen alan adı. Verilmezse `hint` kullanılır.
    /// ⚠ `RefTextField` ile AYNI sözleşme: iki bileşen de aynı
    /// parametreleri tanır, çağıran taraf hangisini kullandığını
    /// bilmek zorunda kalmaz.
    this.etiket,

    /// Kutunun İÇİNDE görünen BİÇİM ÖRNEĞİ ("5XX XXX XX XX").
    /// ⚠ Alan adı buraya yazılmaz — o `etiket`e aittir.
    this.yerTutucu,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.hatali = false,
    // ⚠ Varsayılan `sentences` (bkz. `RefTextField` notu). Ad/soyad
    // alanları `words`, e-posta ve şifre `none` verir.
    this.textCapitalization = TextCapitalization.sentences,
    this.iconColor,
    this.maxLength,
    this.buildCounter,
    // ⚠ YENİ, VARSAYILANI `true` — diğer ekranlar (login, forgot_
    // password, yeni_sifre) ETKİLENMEZ. `false` verildiğinde üst
    // etiket (`RefFieldLabel`) hiç ÇİZİLMEZ, alan adı bunun yerine
    // KUTUNUN İÇİNDE (`register_screen.dart`daki gibi, sol yıldızla)
    // gösterilir — `ilan_kayit_adimi.dart` bunu kullanır.
    this.etiketGoster = true,
  });

  final String iconAsset;

  /// Alan ikonunun rengi; `null` ise SVG kendi rengini korur.
  final Color? iconColor;

  /// Karakter sınırı; sayaç `buildCounter` ile gizlenebilir.
  final int? maxLength;
  final InputCounterWidgetBuilder? buildCounter;
  final TextEditingController controller;
  final String hint;
  final String? etiket;
  final String? yerTutucu;

  /// `.rg-star` — kırmızı yıldız.
  final bool zorunlu;

  /// Sağdaki ek (ör. `+90` ülke kodu ya da göz düğmesi).
  final Widget? suffix;

  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  /// ⚠ DEĞER DEĞİŞTİĞİNDE — EKRANLARIN DOLAYLI YOLA MECBUR KALMAMASI
  /// İÇİN.
  ///
  /// Bu parametre yoktu; giriş ekranı eski hatayı temizlemek için
  /// `TextEditingController` dinlemek zorunda kalmıştı. Aynı ihtiyaç
  /// her formda var, dolayısıyla ortak bileşende olmalıydı.
  final ValueChanged<String>? onChanged;

  /// ⚠ GÖNDERİM SÜRERKEN ALAN KİLİTLENİR.
  ///
  /// İstek devam ederken değer değişirse, dönen cevap ARTIK GEÇERSİZ
  /// bir değere hata/başarı yazar. `enabled: false` bunu kaynağında
  /// engeller.
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  /// ⚠ Sonraki alana geçişte BUNU kullanın.
  ///
  /// Boş bırakılırsa Flutter `TextInputAction.next` için varsayılan
  /// yolu izler ve önce `unfocus()` çağırır — klavye kapanıp tekrar
  /// açılır. Bu geri çağrı verildiğinde odak doğrudan geçer.
  final VoidCallback? onEditingComplete;

  /// ⚠ ALANIN KENDİ ODAK DÜĞÜMÜ.
  ///
  /// Dışarıdan `Focus(focusNode: ...)` ile SARMALAMAYIN: o düğüm
  /// `requestFocus()` çağrıldığında odağı KENDİSİ alır, içindeki
  /// metin alanına geçirmez — metin bağlantısı kopar ve klavye
  /// kapanır. Düğüm doğrudan buraya verilir.
  final FocusNode? focusNode;

  /// ⚠ Doğrulama hatası — kenarlık KIRMIZI çizilir.
  ///
  /// Dış sarmalayıcı `Container` KULLANILMAZ (`RefTextField` ile
  final bool hatali;

  /// Klavyeye verilen büyük harf İPUCU (ad/soyad alanlarında `words`).
  /// ⚠ Yalnız ipucudur; biçim zorlaması `inputFormatters` ile yapılır.
  final TextCapitalization textCapitalization;

  /// Bkz. constructor notu — varsayılan `true`.
  final bool etiketGoster;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (etiketGoster) RefFieldLabel(etiket ?? hint, zorunlu: zorunlu, ilk: true),
        _kutu(context),
      ],
    );
  }

  Widget _kutu(BuildContext context) {
    return Container(
      // ⚠ ALANLAR ARASI ARALIK TEK DEĞER: 12 dp.
      //
      // Referans CSS'te 11px'ti. Etiketler kaldırılıp aralık ekranlara
      // elle verilince ortaya iki değer çıktı: `RefTextField` ve
      // `RefDropdownField` kullanan ekranlarda 12, kendi margin'i olan
      // bu bileşende 11. Fark gözle ayırt edilmiyordu ama iki ayrı
      // sayı olması sonraki değişikliklerde karışıklık üretir.
      //
      // ⚠ HTML SÖZLEŞMESİNDEN 1 dp SAPMA — bilinçli ve kayıtlı.
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(
            color: hatali ? RC.danger : RC.borderLight,
            width: 1.5), // #E7EAEF / hata: #FF4D4F
        borderRadius: BorderRadius.circular(RR.r13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // .rg-ic{flex:0 0 22px}
          // .rg-ic{flex:0 0 22px}
          // Renk HTML ikon varsayılanlarından gelir:
          //   IC_PHONE_F → fill #1D6BE3 (SVG'nin kendi rengi)
          //   IC_LOCK    → c='#4A5568'
          SizedBox(
            width: 22,
            child: Center(
              child: RefSvg(iconAsset, size: 20, color: iconColor),
            ),
          ),
          const SizedBox(width: 12), // gap:12px
          Expanded(
            child: TextFormField(
              // ⚠ KLAVYE ALTINDA KALMA — Flutter'ın KENDİ ÇÖZÜMÜ.
              //
              // `EditableText` odaklanınca alanı görünür alana kaydırır,
              // ancak varsayılan `scrollPadding` yalnız 20px'tir: alan
              // klavyenin TAM ÜSTÜNE oturur ve üzerinde sabit bir alt
              // düğme varsa (ilan oluşturma, kayıt) onun ARDINDA kalır.
              //
              // Bu değer kaydırmanın alanı ne kadar YUKARI taşıyacağını
              // belirler. `kAlanKaydirmaPayi` sabit yükseklikli alt
              // düğme + rahat okuma payını karşılar.
              //
              // ⚠ Bu Flutter'ın DESTEKLEDİĞİ parametredir; yasaklı
              // `Scrollable.ensureVisible` sarmalayıcısı veya yapay
              // gecikme DEĞİLDİR.
              scrollPadding: const EdgeInsets.only(
                  bottom: kAlanKaydirmaPayi),
              controller: controller,
              focusNode: focusNode,
              textCapitalization: textCapitalization,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLength: maxLength,
              buildCounter: buildCounter,
              obscureText: obscureText,
              onChanged: onChanged,
              enabled: enabled,
              validator: validator,
              textInputAction: textInputAction,
              onFieldSubmitted: onFieldSubmitted,
              onEditingComplete: onEditingComplete,
              style: refText(
                size: RF.s15,
                weight: RF.w500,
                color: RC.text,
                letterSpacing: RF.lsM01,
              ),
              decoration: InputDecoration(
                // ⚠ KUTUNUN İÇİ BOŞ: alan adı ÜSTTEKİ etikette.
                // İkisinde birden yazılırsa aynı bilgi iki kez
                // görünür ve alan doldurulunca içerideki kaybolur.
                //
                // ⚠ Tek istisna BİÇİM ÖRNEĞİ ("5XX XXX XX XX"):
                // o alan adı değil, yazım ipucudur.
                //
                // ⚠ `etiketGoster: false` İKEN TERS: üst etiket HİÇ
                // yok, bu yüzden kutunun içi ARTIK BOŞ KALAMAZ — alan
                // adı (`yerTutucu` verilmediyse `hint`) BURADA, kendi
                // `zorunlu` değeriyle (sol yıldızlı) gösterilir.
                hint: !etiketGoster
                    ? refYerTutucu(
                        (yerTutucu == null || yerTutucu!.isEmpty)
                            ? hint
                            : yerTutucu!,
                        zorunlu: zorunlu,
                        boyut: RF.s15)
                    : (yerTutucu == null || yerTutucu!.isEmpty)
                        ? null
                        : refYerTutucu(yerTutucu!, zorunlu: false, boyut: RF.s15),
                // Kutu `.rg-f` tarafından çiziliyor; girdi çerçevesizdir.
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                // Hata metni kutunun ALTINDA görünür.
                errorStyle: refText(
                  size: RF.s115,
                  weight: RF.w600,
                  color: RC.danger,
                ),
              ),
            ),
          ),
          // ── ⚠ SUFFIX SATIR YÜKSEKLİĞİNİ BÜYÜTMEZ ──
          //
          // Şifre alanı öteki alanlardan DAHA UZUN görünüyordu.
          // Sebep: `RefSifreGozu` erişilebilirlik için en az 48×48
          // dokunma alanı istiyor; kutunun kendi yüksekliği ise
          // 14 dp dolgu + tek satır metin ≈ 46 dp. Göz ikonu satırı
          // birkaç piksel esnetiyordu ve göze çarpıyordu.
          //
          // ⚠ DOKUNMA ALANI KÜÇÜLTÜLMEDİ. `RefSifreGozu` içindeki
          // 48×48 sınırı erişilebilirlik alt sınırıdır ve KORUNUR —
          // burada yalnız DIŞ YÜKSEKLİK sabitleniyor. İkon taşan
          // kısmıyla dokunulabilir kalır, ama satırı büyütmez.
          //
          // ⚠ Ölçü BİLEŞENDE sabit: ekranlar tek tek düzeltme yapmaz,
          // suffix veren her alan aynı yüksekliği alır.
          if (suffix != null)
            SizedBox(
              // ⚠ GENİŞLİK DE VERİLİR.
              //
              // Önce yalnız `height` veriliyordu ve `OverflowBox`'ın
              // `maxWidth`'i boştu. `Row` çocuğuna SINIRSIZ genişlik
              // verir; `OverflowBox` bunu SONSUZ diye alıp taşıyordu:
              //   "RIGHT OVERFLOWED BY Infinity PIXELS"
              // Aynı bozuk düzen kayıt ekranını da çökertiyordu.
              width: kSifreGozuDokunma,
              height: kRefAlanIcYukseklik,
              child: OverflowBox(
                // ⚠ İKİ EKSEN DE SINIRLI: dokunma alanı 48×48 kalır
                // (erişilebilirlik), ama satırı büyütmez.
                maxWidth: kSifreGozuDokunma,
                maxHeight: kSifreGozuDokunma,
                child: suffix,
              ),
            ),
        ],
      ),
    );
  }
}

/// `.lg-cc` — telefon alanındaki `+90` eki.
///
/// ```css
/// .lg-cc{color:#16233D;font-weight:700;font-size:14px;
///   padding-left:10px;border-left:1px solid #EEF0F3}
/// ```
class RefCountryCode extends StatelessWidget {
  const RefCountryCode({super.key, this.kod = '+90'});

  final String kod;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: RC.border2)), // #EFF1F4
      ),
      child: Text(
        kod,
        style: refText(size: RF.s14, weight: RF.w700, color: RC.text),
      ),
    );
  }
}

/// `.rg-infobox` (ve `.blue` varyantı).
///
/// ```css
/// .rg-infobox{display:flex;gap:11px;align-items:flex-start;
///   background:#EEF3FB;border-radius:12px;padding:14px;margin-top:16px;
///   color:#3A4658;font-size:13.5px;line-height:1.5}
/// .rg-infobox.blue{background:#EAF1FB}
/// ```
class RefInfoBox extends StatelessWidget {
  const RefInfoBox({
    super.key,
    required this.child,
    this.mavi = false,
    this.margin,
  });

  final Widget child;

  /// `.blue` varyantı — daha koyu mavi zemin.
  final bool mavi;

  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mavi ? RC.blueSoft : const Color(0xFFEEF3FB),
        borderRadius: BorderRadius.circular(RR.r12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1), // .rg-info-ic{margin-top:1px}
            child: RefSvg('assets/svg/ic_info.svg', size: 18),
          ),
          const SizedBox(width: 11), // gap:11px
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// `.rg-primary` — ana eylem düğmesi (mavi gradyan).
///
/// ```css
/// .rg-primary{width:100%;border-radius:14px;padding:16px;font-size:16px;
///   font-weight:700;color:#fff;
///   background:linear-gradient(180deg,#2E6FE8,#1A4FC4);
///   box-shadow:0 9px 20px rgba(26,79,196,.3)}
/// ```
class RefPrimaryButton extends StatelessWidget {
  const RefPrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.busy = false,
    this.iconAsset,
  });

  final String label;

  /// Metnin SOLUNDA çizilen beyaz ikon (`.pr-cta{gap:8px}`).
  /// Verilmezse buton yalnız metinden oluşur — mevcut çağrılar etkilenmez.
  final String? iconAsset;

  final VoidCallback? onPressed;

  /// İşlem sürerken düğme kilitlenir ve gösterge çizilir.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null && !busy;
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RR.r14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: aktif ? onPressed : null,
            child: Ink(
              decoration: const BoxDecoration(gradient: RG.blueCta),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(RC.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconAsset != null) ...[
                            RefSvg(iconAsset!, size: 18, color: RC.white),
                            const SizedBox(width: 8), // .pr-cta{gap:8px}
                          ],
                          Flexible(
                            child: Text(
                              label,
                              style: refText(
                                size: RF.s16,
                                weight: RF.w700,
                                color: RC.white,
                              ),
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

/// `.rg-google` — beyaz zeminli ikincil düğme.
///
/// ```css
/// .rg-google{width:100%;display:flex;align-items:center;
///   justify-content:center;gap:11px;border:1.5px solid #E7EAEF;
///   background:#fff;border-radius:14px;padding:14px;font-size:15px;
///   font-weight:600;color:#16233D}
/// ```
class RefSecondaryButton extends StatelessWidget {
  const RefSecondaryButton(
    this.label, {
    super.key,
    required this.iconAsset,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null && !busy;
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: Material(
        color: RC.white,
        borderRadius: BorderRadius.circular(RR.r14),
        child: InkWell(
          onTap: aktif ? onPressed : null,
          borderRadius: BorderRadius.circular(RR.r14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: RC.borderLight, width: 1.5),
              borderRadius: BorderRadius.circular(RR.r14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  RefSvg(iconAsset, size: 20),
                const SizedBox(width: 11), // gap:11px
                Text(
                  label,
                  style: refText(
                    size: RF.s15,
                    weight: RF.w600,
                    color: RC.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.rg-or` — "veya" ayırıcısı.
///
/// ```css
/// .rg-or{display:flex;align-items:center;gap:14px;color:#9AA4B5;
///   font-size:13px;margin:18px 0}
/// ```
class RefOrDivider extends StatelessWidget {
  const RefOrDivider({super.key, this.label = 'veya'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18), // margin:18px 0
      child: Row(
        children: [
          const Expanded(child: Divider(color: RC.border, height: 1)),
          const SizedBox(width: 14), // gap:14px
          Text(
            label,
            style: refText(
              size: RF.s13,
              weight: RF.w700,
              color: RC.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Divider(color: RC.border, height: 1)),
        ],
      ),
    );
  }
}

/// `.rg-sheet` — alttan açılan panel.
///
/// ```css
/// .rg-sheet{width:100%;max-height:80%;background:#fff;
///   border-radius:22px 22px 0 0;transform:translateY(100%);
///   transition:transform .26s cubic-bezier(.32,.72,0,1)}
/// ```
///
/// [goster] ile açılır; başlık satırı ve kapatma düğmesi referanstaki
/// `rg-sheeth` yapısını izler.
/// `.rg-ov{background:rgba(15,23,42,.42)}`
const Color _kPerdeRengi = Color(0x6B0F172A);

/// Perde süresi / panel süresi.
///
/// Rota tek bir animasyon yürütür; perde bu animasyonun ilk
/// diliminde tamamlanarak kendi süresini korur:
///   `RA.overlay` (220 ms) / `RA.sheet` (260 ms) = 0,846
///
/// ⚠ `int / int` Dart'ta çift duyarlıklı bölme yapar (`operator /`
/// double döner), tam sayı bölmesi `~/` operatörüdür — bu yüzden
/// sonuç 0 değil 0,846'dır.
///
/// ⚠ `const` DEĞİL `final`: `Duration.inMilliseconds` bir property
/// erişimidir ve Dart sabit ifade değerlendirmesinde kullanılamaz
/// (`const_eval_property_access`). Değer program başlangıcında bir kez
/// hesaplanır; 220 ve 260 sayılarını elle kopyalamak token bağını
/// koparacağı için tercih edilmemiştir.
final double _kPerdeOran =
    RA.overlay.inMilliseconds / RA.sheet.inMilliseconds;

/// Perde opaklık eğrisi — açılışta kullanılır, kapanışta `flipped`.
///
/// `_kPerdeOran` sabit olmadığı için bu da `final`'dır.
final Interval _kPerdeEgrisi =
    Interval(0, _kPerdeOran, curve: Curves.linear);

class RefBottomSheet extends StatelessWidget {
  const RefBottomSheet({super.key, required this.title, required this.child});

  /// Perde (`.rg-ov`) widget anahtarı — animasyon testleri bunu arar.
  static const perdeKey = ValueKey('ref-sheet-scrim');

  final String title;
  final Widget child;

  /// Referans geçiş süresi/eğrisi ile panel açar.
  ///
  /// ```css
  /// .rg-ov   {background:rgba(15,23,42,.42); opacity:0;
  ///           transition:opacity .22s}
  /// .rg-sheet{transform:translateY(100%);
  ///           transition:transform .26s cubic-bezier(.2,.8,.2,1)}
  /// ```
  ///
  /// ── NEDEN `showModalBottomSheet` DEĞİL ──
  ///
  /// `showModalBottomSheet` kendi rotasında bir kaydırma dönüşümü
  /// uygular. Panelin içine ikinci bir `SlideTransition` konursa aynı
  /// hareket İKİ KEZ işlenir (çift translate → zıplama). Ayrıca perde
  /// solması rota süresine bağlıdır; 220 ms ayrı olarak verilemez.
  ///
  /// Bu yüzden `showGeneralDialog` kullanılır: kendi dönüşümü YOKTUR,
  /// hareket TEK katmanda kurulur.
  ///
  /// ── İKİ AYRI SÜRE, TEK ANİMASYON ──
  ///
  /// Rota süresi 260 ms'tir (panelin süresi).
  /// Perde, aynı animasyonun ilk %84,6'lık diliminde solar:
  ///   220 / 260 = 0,846  →  `Interval(0, 0.846)`
  /// Böylece perde gerçekten 220 ms'te tamamlanır, panel 260 ms sürer.
  static Future<T?> goster<T>(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,          // dış alana dokunma kapatır
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // Perde rengi transitionBuilder içinde çizilir; rota perdesi saydam.
      barrierColor: Colors.transparent,
      transitionDuration: RA.sheet,      // 260 ms
      pageBuilder: (_, __, ___) =>
          RefBottomSheet(title: title, child: child),
      transitionBuilder: (context, anim, _, panel) {
        // .rg-ov{transition:opacity .22s}
        //
        // AÇILIŞ  (parent 0→1): `Interval(0, 0.846)` — opacity ilk
        //   andan itibaren artar ve 220 ms'te 1'e ulaşır; kalan 40 ms
        //   boyunca 1'de kalır.
        //
        // KAPANIŞ (parent 1→0): aynı `Interval` KULLANILAMAZ. Ters
        //   yönde `transform(t)` t=1'den başlar ve t 0.846'ya inene
        //   kadar (≈40 ms) 1.0 döner — perde beklerdi.
        //   `flipped` (`1 - curve(1 - t)`) bu gecikmeyi kaldırır:
        //   t=1.000 → 1.000   (0 ms)
        //   t=0.950 → 0.941   (13 ms · azalma BAŞLADI)
        //   t=0.154 → 0.000   (220 ms · tamamlandı)
        //   Kalan 40 ms perde zaten görünmezdir.
        final perde = CurvedAnimation(
          parent: anim,
          curve: _kPerdeEgrisi,
          reverseCurve: _kPerdeEgrisi.flipped,
        );
        // .rg-sheet{transition:transform .26s cubic-bezier(.2,.8,.2,1)}
        final kayma = CurvedAnimation(
          parent: anim,
          curve: RA.easeOutSoft,
          reverseCurve: RA.easeOutSoft.flipped,
        );
        return Stack(
          children: [
            // Perde — kendi süresiyle solar.
            //
            // ⚠ `IgnorePointer` ZORUNLU.
            //
            // `ColoredBox` hit-test'te OPAKTIR (`_RenderColoredBox`
            // varsayılan davranışı `HitTestBehavior.opaque`). Tüm
            // ekranı kapladığı için, altındaki `ModalBarrier`'a giden
            // dokunuşları yutuyordu: `barrierDismissible: true`
            // olmasına rağmen BOŞ ALANA DOKUNMAK PANELİ KAPATMIYORDU.
            // Perde yalnız boya katmanıdır; kapatma işini rota
            // perdesi yapar.
            //
            // Anahtar TESTLER İÇİNDİR: ağaçta MaterialApp'in sayfa
            // geçişinden gelen başka `FadeTransition`'lar da bulunur;
            // `find.byType(FadeTransition).first` yanlış widget'ı
            // yakalayabilir. Perde bu anahtarla kesin bulunur.
            IgnorePointer(
              child: FadeTransition(
                key: RefBottomSheet.perdeKey,
                opacity: perde,
                child: const ColoredBox(
                  color: _kPerdeRengi,
                  child: SizedBox.expand(),
                ),
              ),
            ),
            // Panel — TEK kaydırma katmanı.
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),   // translateY(100%)
                  end: Offset.zero,
                ).animate(kayma),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Klavyenin kapladığı yükseklik (açık değilse 0).
    final klavye = MediaQuery.viewInsetsOf(context).bottom;

    // ⚠ Burada HAREKET YOKTUR. Kaydırma ve perde tek katmanda
    // [goster] içindeki `transitionBuilder` tarafından uygulanır;
    // ikinci bir `SlideTransition` çift translate üretirdi.
    //
    // ⚠ `Material` ZORUNLU.
    //
    // Panel `showGeneralDialog` ile açılır; `showModalBottomSheet`ten
    // farklı olarak altına Material KONULMAZ. Material bağlamı
    // olmayan metinler Flutter'ın "biçimlendirilmemiş metin"
    // göstergesiyle SARI ÇİFT ALT ÇİZGİLİ çizilir — panel başlığında
    // görülen buydu. `transparency` yalnız bağlam sağlar; panelin
    // zemini, köşe yarıçapı ve gölgesi DEĞİŞMEZ.
    return Material(
      type: MaterialType.transparency,
      // ⚠ İKİNCİ SAVUNMA: varsayılan metin biçimi AÇIKÇA verilir.
      //
      // `Material` normalde metin biçimini de sağlar, ancak tema veya
      // sürüm farklarında bu zincir kopabiliyor; kopunca Flutter
      // metinleri SARI ÇİFT ALT ÇİZGİLİ çiziyor. Burada biçim
      // doğrudan tanımlanır — panel içindeki hiçbir metin biçimsiz
      // kalamaz.
      child: DefaultTextStyle(
        style: refText(
            size: RF.s145,
            weight: RF.w400,
            color: RC.text,
            height: RF.lh150),
        // ⚠ KLAVYE PANELİ ÖRTMEZ.
        //
        // Panel `showGeneralDialog` ile açıldığı için `Scaffold`'un
        // klavye yeniden boyutlandırması BURAYA UYGULANMAZ: içinde
        // metin alanı olan paneller (silme gerekçesi, kategori talebi)
        // klavyenin ALTINDA kalıyordu.
        //
        // Alt dolgu klavye yüksekliği kadar verilir; panel klavyenin
        // ÜSTÜNE oturur. Yükseklik sınırı da KALAN alana göre
        // hesaplanır, yoksa panel taşar.
        child: Padding(
          padding: EdgeInsets.only(bottom: klavye),
          child: Container(
      constraints: BoxConstraints(
        // Kalan yüksekliğin %80'i — klavye açıkken panel küçülür,
        maxHeight: (MediaQuery.sizeOf(context).height - klavye) * 0.8,
      ),
      decoration: const BoxDecoration(
        color: RC.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(RR.r22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // .rg-sheeth — başlık + kapat
            Padding(
              // Kompakt panel: başlık şeridi daraltıldı.
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: refText(
                        size: RF.s16,
                        weight: RF.w700,
                        color: RC.text,
                      ),
                    ),
                  ),
                  RefTap(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(RR.circle),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: RefSvg('assets/svg/ic_x.svg', size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: child,
              ),
            ),
          ],
        ),
      ),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// ORTAK EKRAN BİLEŞENLERİ
//
// Kaynak: `hizmetcep-v66-final__1_.html`
//
// ⚠ Referansta Material `AppBar` YOKTUR: her ekran kaydırılabilir bir
// sayfadır ve başlık sayfa içinde `.pf-title` metnidir.
//
// Alt navigasyon ise VARDIR (`custNav()` → `.cust-nav`) ve rol duyarlıdır:
// provider modunda "İlan Ver" sekmesi listeden ÇIKARILIR.
//

/// `.cust-wrap` / `.pf-wrap` — kaydırılabilir sayfa kabı.
///
/// ```css
/// .cust-wrap{padding: calc(12px + env(safe-area-inset-top)) 14px 84px}
/// ```
///
/// Üst boşluk cihazın güvenli alanını İÇERİR; alt boşluk 84px'tir
/// (referansta içerik alt kenara yapışmaz).
class RefPage extends StatelessWidget {
  const RefPage({
    super.key,
    required this.child,
    this.horizontal = 14,
    this.topExtra = 12,
    this.bottom = 84,
  });

  final Widget child;
  final double horizontal;

  /// `calc(Npx + env(safe-area-inset-top))` — N değeri.
  final double topExtra;

  final double bottom;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: RefScroll(
        padding: EdgeInsets.fromLTRB(
            horizontal, topExtra + safeTop, horizontal, bottom),
        child: child,
      ),
    );
  }
}

/// `.pf-title` — sayfa başlığı.
///
/// ```css
/// .pf-title{font-size:25px;font-weight:700;color:#16233D;
///   letter-spacing:-.3px;margin-bottom:16px}
/// ```
class RefPageTitle extends StatelessWidget {
  const RefPageTitle(this.text, {super.key, this.geriDugmesi});

  final String text;

  /// Başlığın üstünde GERİ OKU çizilsin mi?
  ///
  /// ⚠ VARSAYILAN AÇIK — kural `RefDetailHeader` ile AYNIDIR
  /// (bkz. oradaki uzun not). Ok her ekranda ve her platformda
  /// çizilir; `false` verilerek gizlenebilir.
  ///
  /// ⚠ Bu bileşeni kullanan ekranlar (Adreslerim, Şifre Değiştir,
  /// Profil Bilgilerim, Uygulama Değerlendirmesi) profil menüsünden
  /// açılır ve alt navigasyonları yoktur; ok olmadan iOS'ta çıkış
  /// yolu kalmıyordu.
  final bool? geriDugmesi;

  @override
  Widget build(BuildContext context) {
    final okVar = RefDetailHeader.okGosterilirMi(geriDugmesi);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (okVar) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: RefBackButton(),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            text,
            style: refText(
              size: RF.s25,
              weight: RF.w700,
              color: RC.text,
              letterSpacing: RF.lsM03,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.pf-h3` — bölüm başlığı.
///
/// ```css
/// .pf-h3{font-size:16px;font-weight:700;color:#16233D;
///   margin:18px 1px 9px}
/// ```
class RefSectionTitle extends StatelessWidget {
  const RefSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(1, 18, 1, 9),
        child: Text(
          text,
          style: refText(size: RF.s16, weight: RF.w700, color: RC.text),
        ),
      );
}

/// `.pf-group` — satırları saran beyaz kutu.
///
/// ```css
/// .pf-group{background:#fff;border:1px solid #ECEEF1;
///   border-radius:15px;overflow:hidden}
/// ```
///
/// İçindeki satırlar arasında ayırıcı çizgi bulunur.
class RefRowGroup extends StatelessWidget {
  const RefRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ic = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        ic.add(const Divider(height: 1, thickness: 1, color: RC.border));
      }
      ic.add(children[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(RR.r15),
      child: Container(
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border), // #ECEEF1
          borderRadius: BorderRadius.circular(RR.r15),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: ic),
      ),
    );
  }
}

/// `.pf-row` — menü satırı (ikon + başlık/açıklama + chevron).
///
/// ```css
/// .pf-row{display:flex;align-items:center;gap:12px;width:100%;
///   padding:13px 13px;text-align:left}
/// .pf-ic {width:44px;height:44px;border-radius:12px}
/// .pf-t  {font-size:14.5px;font-weight:700;color:#16233D}
/// .pf-d  {font-size:12px;color:#5B6472;line-height:1.4}
/// ```
class RefMenuRow extends StatelessWidget {
  const RefMenuRow({
    super.key,
    required this.iconAsset,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.showChevron = true,
    this.titleColor,
  });

  final String iconAsset;

  /// `.pf-ic` arka planı — her satırın kendi rengi vardır.
  final Color iconBg;

  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  /// `.pf-red{color:#E5452C}` gibi varyantlar için başlık rengi.
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            // .pf-ic
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(RR.r12),
              ),
              child: RefSvg(iconAsset, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12), // gap:12px
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: refText(
                        size: RF.s145,
                        weight: RF.w700,
                        color: titleColor ?? RC.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: refText(
                        size: RF.s12,
                        weight: RF.w400,
                        color: RC.textSoft,
                        height: RF.lh140,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              const RefSvg('assets/svg/ic_chev.svg',
                  size: 18, color: RC.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// `.cust-tabs` — segment sekmeleri (ikon + etiket, seçili mavi).
///
/// ```css
/// .cust-tabs{display:flex;background:#fff;border:1px solid #E7EAEF;
///   border-radius:13px;overflow:hidden;margin-bottom:11px}
/// .cust-tab{flex:1;flex-direction:column;align-items:center;gap:5px;
///   padding:10px 4px;background:#fff}
/// .cust-tab.on{background:#1D6BE3;color:#fff}
/// ```
/// ── ⚠ SAYI ROZETİ — TEK ÇİZİM ──
///
/// Kırmızı, halkalı, sayı taşıyan rozet. Hem sekme çubuğunda
/// (`RefSegmentTabs`) hem alt navigasyonda (`RefBottomNav`) AYNI
/// bileşen kullanılır.
///
/// ⚠ NEDEN ORTAK: iki yerde ayrı ayrı çizilseydi ölçü, konum ve
/// halka kalınlığı kaçınılmaz olarak ayrışırdı — nitekim alt bardaki
/// rozet 15 px ve "!" işaretliyken sekmedeki 17 px ve sayılıydı.
///
/// [halkaRengi] rozetin oturduğu ZEMİNİN rengidir: halka zemine
/// uymazsa rozet yamalı görünür.
class RefSayiRozeti extends StatelessWidget {
  const RefSayiRozeti({
    super.key,
    required this.sayi,
    required this.halkaRengi,
  });

  final int sayi;
  final Color halkaRengi;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
        // ⚠ `minHeight` de verilir: tek haneli sayıda rozet DAİRE
        // kalır, yassı bir hap gibi görünmez.
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RC.danger,
          borderRadius: BorderRadius.circular(RR.circle),
          border: Border.all(color: halkaRengi, width: 2),
        ),
        child: Text(
          sayi > 99 ? '99+' : '$sayi',
          textAlign: TextAlign.center,
          style: refText(size: 9.5, weight: RF.w700, color: RC.white),
        ),
      );
}

class RefSegmentTabs extends StatelessWidget {
  const RefSegmentTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.badges,
  });

  final List<({String asset, String label})> items;
  final int selected;
  final ValueChanged<int> onChanged;

  /// ⚠ YENİ, OPSİYONEL — verilmezse HİÇBİR ŞEY DEĞİŞMEZ (mevcut
  /// tüm çağrı yerleri etkilenmez). Verilirse, `items` ile AYNI
  /// uzunlukta olmalı; `badges[i] > 0` olan sekmenin ikonunun sağ
  /// üstünde kırmızı bir sayı rozeti çizilir.
  final List<int>? badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.borderLight), // #E7EAEF
        borderRadius: BorderRadius.circular(RR.r13),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RR.r13),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: DecoratedBox(
                  // `.cust-tab+.cust-tab{border-left:1px solid #EEF0F3}`
                  // İlk sekmede ayırıcı YOKTUR.
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(
                            left: BorderSide(color: Color(0xFFEEF0F3)),
                          ),
                  ),
                  child: RefTap(
                    onTap: () => onChanged(i),
                    // ── ⚠ ROZET İKONUN DEĞİL, SEKMENİN KÖŞESİNDE
                    // (12 Eyl, kullanıcı isteği) ──
                    //
                    // BULGU: "sayı ok üzerinde duruyor; butonun sol
                    // köşesinde kırmızı daire içinde olsun."
                    //
                    // Rozet İKONA göre konumlanıyordu. 9 Eyl'de ikonun
                    // içinden dışarı alınmıştı ama hâlâ ona teğetti ve
                    // uçuş ikonuyla görsel olarak karışıyordu.
                    //
                    // Artık sekmenin KENDİ sol üst köşesinde: ikondan
                    // bağımsız, sabit bir nokta. Hangi ikon olursa
                    // olsun rozet aynı yerde durur.
                    //
                    // ⚠ HALKA RENGİ SEKME ZEMİNİNE UYAR: seçilide
                    // mavi, seçilmemişte beyaz — rozetin çevresinde
                    // net bir boşluk kalır.
                    child: Stack(
                      // ── ⚠ `passthrough` ŞART (12 Eyl düzeltmesi) ──
                      //
                      // Rozet sekmenin köşesine taşınırken `Container`
                      // bir `Stack` ile sarıldı ve `fit` verilmedi.
                      // Varsayılan `StackFit.loose`, çocuğa GEVŞEK
                      // kısıt geçirir: `Container` genişliğini
                      // içeriğinden alıp `Expanded`ın verdiği yeri
                      // DOLDURMAZ oldu. Sonuç: sekmeler daraldı,
                      // seçili zemin etiketin dışına taşmadı, hizalar
                      // kaydı — kullanıcının bildirdiği bozulma buydu.
                      //
                      // `passthrough` üst kısıtı olduğu gibi geçirir;
                      // sekme yine `Expanded`ın tamamını kaplar.
                      //
                      // ⚠ ROZET KONUMLU ÇOCUKTUR, bu kısıttan
                      // etkilenmez.
                      fit: StackFit.passthrough,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          color: i == selected ? RC.blue : RC.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RefSvg(
                                items[i].asset,
                                size: 20,
                                color: i == selected ? RC.white : RC.text,
                              ),
                              const SizedBox(height: 5), // gap:5px
                              // ⚠ ETİKET KESİLMEZ, KÜÇÜLÜR.
                              //
                              // `maxLines: 1` + `ellipsis` uzun
                              // etiketleri "Tamamlanan ila…" diye
                              // kesiyordu; kullanıcı hangi sekmede
                              // olduğunu okuyamıyordu.
                              //
                              // `FittedBox` metni sığdıracak kadar
                              // küçültür; kısa etiketler tam boyutta
                              // kalır, uzunlar okunur hâlde sığar.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  items[i].label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: refText(
                                    size: RF.s115,
                                    weight: RF.w600,
                                    color:
                                        i == selected ? RC.white : RC.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── ⚠ ROZET SEKMENİN SOL ÜST KÖŞESİNDE ──
                        //
                        // Konum İKONA değil SEKMEYE görelidir: hangi
                        // ikon kullanılırsa kullanılsın rozet aynı
                        // noktada durur. Önceden ikona teğetti ve
                        // uçuş ikonuyla görsel olarak karışıyordu.
                        //
                        // ⚠ HALKA RENGİ SEKME ZEMİNİNE UYAR: seçilide
                        // mavi, seçilmemişte beyaz — rozetin
                        // çevresinde net bir boşluk kalır.
                        if (badges != null &&
                            i < badges!.length &&
                            badges![i] > 0)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: RefSayiRozeti(
                              sayi: badges![i],
                              halkaRengi: i == selected ? RC.blue : RC.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `.cust-pill` — küçük eylem düğmesi (Sırala / Filtreler).
///
/// ```css
/// .cust-pill{display:flex;align-items:center;gap:5px;background:#fff;
///   border:1px solid #E7EAEF;border-radius:10px;padding:7px 11px;
///   font-size:12.5px;font-weight:600}
/// ```
class RefPillButton extends StatelessWidget {
  const RefPillButton({
    super.key,
    required this.iconAsset,
    required this.label,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.borderLight),
          borderRadius: BorderRadius.circular(RR.r10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RefSvg(iconAsset, size: 18, color: RC.text),
            const SizedBox(width: 5), // gap:5px
            Text(
              label,
              style: refText(
                  size: RF.s125, weight: RF.w600, color: RC.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.cust-count` — liste sayacı metni.
///
/// ```css
/// .cust-count{font-size:13.5px;color:#5B6472;font-weight:500;
///   ellipsis}
/// ```
class RefListCount extends StatelessWidget {
  const RefListCount(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: refText(
            size: RF.s135, weight: RF.w500, color: RC.textSoft),
      );
}


/// `.cust-nav` — rol duyarlı alt navigasyon.
///
/// ```css
/// .cust-nav{display:flex;background:#fff;border-top:1px solid #EEF0F3;
///   padding:9px 4px calc(9px + env(safe-area-inset-bottom));
///   box-shadow:0 -2px 12px rgba(20,40,80,.05)}
/// .cust-navitem{flex:1;flex-direction:column;align-items:center;gap:4px;
///   font-size:11px;font-weight:600;color:#9AA4B5;padding:2px 0}
/// .cust-navitem.on{color:#1D6BE3}
/// ```
///
/// Referans `custNav(act)`:
/// ```js
/// let items = [
///   ['ilanver',  'İlan Ver',    IC_ADDBOX, openPost()],
///   ['ilanlarim','İlanlarım',   IC_CLIP,   navigate('cust')],
///   ['bildirim', 'Bildirimler', IC_BELL,   navigate('notif')],
///   ['profil',   'Profil',      IC_PROFILE,navigate('profile')],
/// ];
/// if (MODE === 'provider') items = items.filter(i => i[0] !== 'ilanver');
/// ```
class RefBottomNav extends StatelessWidget {
  const RefBottomNav({
    super.key,
    required this.items,
    required this.activeKey,
  });

  /// ⚠ `rozet`: sekmenin üstünde okunmamış göstergesi çizilsin mi?
  /// Varsayılan davranış YOK — her çağıran açıkça belirtir.
  ///
  /// ⚠ `belirginRozetSayisi` (kullanıcı isteği — "Bul" ikonunda
  /// daha göze çarpan bir gösterge). Bu tip `_NavOgesi.it` ile
  /// AYNI olmalı — biri güncellenip diğeri unutulursa derleme hatası
  /// olur (bkz. bu satırın filed edildiği build log bulgusu).
  final List<
      ({
        String key,
        String label,
        String asset,
        VoidCallback onTap,
        bool rozet,
        int belirginRozetSayisi
      })> items;

  /// Etkin sekmenin anahtarı (`ilanver` / `ilanlarim` / `bildirim` / `profil`).
  final String activeKey;

  static const double _butonCap = 46;
  static const double _tasma = 16;
  static const double _centikGenislik = 62;
  static const double _centikDerinlik = 16;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // ⚠ YALNIZ "İlan Ver" ÖĞESİ VARSA (hizmet alan tarafı) özel
    // çentikli tasarım uygulanır. Hizmet verende bu öğe HİÇ YOK
    // (`nav_actions.dart`daki `if (!saglayici)` koşulu) — o taraf
    // ESKİ, düz bar tasarımıyla DEVAM EDER; DOKUNULMADI.
    final ilanVerIndex = items.indexWhere((it) => it.key == 'ilanver');
    if (ilanVerIndex == -1) {
      return _duzBar(items, safeBottom);
    }

    final ilanVer = items[ilanVerIndex];
    final digerOgeler = [...items]..removeAt(ilanVerIndex);
    // ⚠ SIRA KORUNUR: "İlan Ver" ortadaydı (3./5. öğe) — kalan 4
    // öğe iki eşit gruba bölünüp arada boşluk bırakılır, görünen
    // SOL-SAĞ SIRALARI ve dokunma davranışları DEĞİŞMEZ.
    final ortaNokta = (digerOgeler.length / 2).ceil();
    final sol = digerOgeler.sublist(0, ortaNokta);
    final sag = digerOgeler.sublist(ortaNokta);

    // ⚠ TOPLAM YÜKSEKLİK: eski bara göre yalnız `_tasma` kadar
    // artar — "gereksiz artırma" kuralına uyar; buton bunun
    // İÇİNDE, bar kenarını hafifçe aşacak şekilde konumlanır.
    return SizedBox(
      height: 9 + 46 + 9 + safeBottom + _tasma,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ── ALT BAR — ÜST KENARI ORTADA YUMUŞAKÇA İÇERİ KIVRILIR ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: RC.white,
              // ⚠ `elevation`, `shape`e uyumlu gölge üretir — Flutter'ın
              // `BottomAppBar`ında da AYNI mekanizma kullanılır; ayrı
              // bir gölge çizimi İCAT EDİLMEDİ.
              elevation: 3,
              shadowColor: const Color(0x14142850),
              shape: const _CentikliKenar(
                genislik: _centikGenislik,
                derinlik: _centikDerinlik,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, 9, 4, 9 + safeBottom),
                child: Row(
                  children: [
                    for (final it in sol)
                      Expanded(
                        // ⚠ DÜZELTME: `_NavOgesi` kendi `Expanded`
                        // alanının GENİŞLİĞİNİ doldurmuyordu (Column
                        // içeriği sarıyor), bu yüzden VARSAYILAN olarak
                        // SOLA yaslanıyordu — notch'a yakın öğeler
                        // (İlanlarım) merkeze daha yakın, kenar öğeler
                        // (Bul) daha kenarda görünüyor, aralıklar EŞİT
                        // DEĞİLMİŞ gibi duruyordu. `Center` EKLENDİ —
                        // ikonun/etiketin şekli, boyutu, rengi HİÇ
                        // DEĞİŞMEDİ, yalnız kendi alanının ortasına
                        // hizalandı.
                        child: Center(
                            child: _NavOgesi(
                                it: it, aktifMi: it.key == activeKey)),
                      ),
                    // ── ⚠ ORTA YUVA: SABİT GENİŞLİK DEĞİL, EŞİT PAY ──
                    //
                    // ESKİDEN `SizedBox(width: _centikGenislik)` idi:
                    // dört öğe kalan genişliği eşit paylaşıyor, ortaya
                    // 62 dp SABİT boşluk giriyordu. Çentik bir yuvadan
                    // DAR olduğu için çentiğe komşu öğelerin merkez
                    // mesafesi (yuva + çentik) / 2'ye düşüyor, kenardaki
                    // komşularda ise TAM yuva kalıyordu.
                    //
                    // ⚠ ÖLÇÜLDÜ (kullanıcı ekran görüntüsü, 1080 px /
                    // 480 dp): etiket merkezleri 123,5 · 354,5 · 540 ·
                    // 725,5 · 955 px → aralıklar 231 · 185,5 · 185,5 ·
                    // 229,5 px. Koddaki 4 dp dolgu + 62 dp çentikle
                    // hesaplanan merkezler bu ölçümü 1 px içinde
                    // veriyor; kök neden TAHMİN DEĞİL.
                    //
                    // Orta boşluk da EŞİT PAYLI yuva yapıldı: bar beş
                    // eşit yuvaya bölünür, beş merkez eşit aralıklı
                    // olur. Buton yine TAM ORTADADIR (iki yuva + yarım
                    // yuva = genişliğin yarısı), yani `Stack`in
                    // `bottomCenter` hizası ile çakışır.
                    //
                    // ⚠ `_centikGenislik` KALDIRILMADI — kenar çizimi
                    // (`_CentikliKenar`) ve çentik derinliği hâlâ onu
                    // kullanır. Değişen YALNIZ satırdaki boşluğun
                    // genişliğidir; ikon, etiket, renk, buton çapı ve
                    // çentiğin kendisi AYNEN durur.
                    //
                    // ⚠ DAR EKRAN: yuva genişliği azalır (480 dp'de
                    // 102,25 → 94,4; 360 dp'de 72,5 → 70,4). Orta yuva
                    // 360 dp'de bile çentikten (62) geniş kalır. En
                    // uzun etiket "Bildirimler"dir; daha dar bir ekranda
                    // taşarsa çözüm punto düşürmek DEĞİL, etiketi
                    // kısaltmaktır (ürün kararı).
                    const Expanded(child: SizedBox.shrink()),
                    for (final it in sag)
                      Expanded(
                        child: Center(
                            child: _NavOgesi(
                                it: it, aktifMi: it.key == activeKey)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // ── "İLAN VER" — KÜÇÜK, MERKEZİ, ÇENTİĞE OTURMUŞ ──
          //
          // ⚠ BÜYÜK BİR FAB DEĞİL: çapı diğer öğelerin ikon+etiket
          // yüksekliğine YAKIN tutuldu (46px — standart FAB'in
          // 56px'inden küçük).
          //
          // ⚠ ÖNCEDEN ETİKET YOKTU — yalnız daire çiziliyordu, diğer
          // 4 öğeyle TUTARSIZ görünüyordu. Şimdi AYNI desende: daire
          // + altında "İlan Ver" yazısı. İkisi TEK bir `Column` —
          // `bottom` değeri diğer öğelerle AYNI alt hizadan
          // (`9 + safeBottom`) başlar, buton yalnız kendi
          // yüksekliğince YUKARI çıkar — bar üstünü hâlâ hafifçe
          // aşıyor, ama artık etiketi de bar İÇİNDE, kırpılmadan
          // okunabiliyor.
          Positioned(
            bottom: 9 + safeBottom,
            child: RefTap(
              onTap: ilanVer.onTap,
              borderRadius: BorderRadius.circular(RR.r10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _butonCap,
                    height: _butonCap,
                    decoration: BoxDecoration(
                      color: RC.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: RC.blue.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child:
                          RefSvg(ilanVer.asset, size: 21, color: RC.white),
                    ),
                  ),
                  const SizedBox(height: 4), // gap:4px — diğer öğelerle AYNI
                  Text(
                    ilanVer.label,
                    maxLines: 1,
                    style: refText(
                        size: RF.s11, weight: RF.w600, color: RC.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠ ESKİ TASARIM — hizmet veren tarafı, DOKUNULMADI. Yalnızca
  /// yeniden adlandırılmış bir yardımcı metoda taşındı ki yukarıdaki
  /// yeni dal ile KOD TEKRARI olmasın.
  ///
  /// ⚠ `belirginRozetSayisi` — `_NavOgesi.it` ile AYNI tip olmak
  /// zorunda (derleme hatası bulgusu, bkz. `RefBottomNav.items`daki
  /// AYNI not).
  Widget _duzBar(List<
          ({
            String key,
            String label,
            String asset,
            VoidCallback onTap,
            bool rozet,
            int belirginRozetSayisi
          })>
      ogeler, double safeBottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, 9, 4, 9 + safeBottom),
      decoration: const BoxDecoration(
        color: RC.white,
        border: Border(top: BorderSide(color: RC.border2)), // #EEF0F3
        boxShadow: RS.bottomNav, // 0 -2px 12px rgba(20,40,80,.05)
      ),
      child: Row(
        children: [
          for (final it in ogeler)
            Expanded(child: _NavOgesi(it: it, aktifMi: it.key == activeKey)),
        ],
      ),
    );
  }
}

/// Tek bir alt bar öğesi (ikon + rozet + etiket) — hem eski düz bar
/// hem yeni çentikli bar TARAFINDAN paylaşılır; iki AYRI kopya
/// YAZILMADI.
class _NavOgesi extends StatelessWidget {
  const _NavOgesi({required this.it, required this.aktifMi});

  final ({
    String key,
    String label,
    String asset,
    VoidCallback onTap,
    bool rozet,
    int belirginRozetSayisi
  }) it;
  final bool aktifMi;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: it.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ⚠ OKUNMAMIŞ BİLDİRİM GÖSTERGESİ ──
            //
            // Kullanıcı Bildirimler ekranına GİRMEDEN yeni
            // bildirim olduğunu anlamalı.
            //
            // ⚠ SAYI DEĞİL NOKTA: sekme dar; iki haneli sayı
            // ikonu itip hizayı bozardı. Nokta yalnız "yeni
            // var" bilgisini verir, ekranda sayı zaten
            // görünür.
            //
            // ⚠ ÖLÇÜ DEĞİŞMEZ: nokta `Stack` içinde ikonun
            // ÜSTÜNE çizilir, yer kaplamaz.
            //
            // ── ⚠ RENK MAVİDEN KIRMIZIYA (12 Eyl, kullanıcı
            // isteği) ──
            //
            // "Bildirim geldiğinde mavi nokta değil kırmızı olsun;
            // bildirimler okununca normal rengine dönüşsün."
            //
            // Mavi, uygulamanın SEÇİLİ SEKME rengiydi: Bildirimler
            // sekmesi aktifken ikon da nokta da maviydi ve nokta
            // kayboluyordu. Kırmızı hem seçili hem seçilmemiş zeminde
            // okunur.
            //
            // ⚠ RENK ORTAK KAYNAKTAN: `RC.danger` — "Bul"
            // ikonundaki sayı rozeti de aynı kırmızıyı kullanır
            // (`RefSayiRozeti`). İki gösterge aynı şeyi söylüyor:
            // ilgi bekleyen bir şey var.
            //
            // ⚠ OKUNUNCA KENDİLİĞİNDEN KAYBOLUR: `it.rozet`
            // okunmamış sayısından türer; ayrı bir "normale dön"
            // adımı YOKTUR.
            //
            // ⚠ İKON BOZULMAZ: ne ölçü ne konum değişti, yalnız
            // dolgu rengi. Beyaz halka duruyor — nokta ikonun
            // konturuna yapışmaz.
            Stack(
              clipBehavior: Clip.none,
              children: [
                RefSvg(
                  it.asset,
                  size: 22,
                  color: aktifMi ? RC.blue : RC.textMuted,
                ),
                if (it.rozet)
                  Positioned(
                    // ⚠ KÖŞEYE TEĞET, İKONUN İÇİNE DEĞİL: `-2 / -1`
                    // ile 9 px'lik nokta 22 px ikonun sağ üst
                    // konturuna biniyordu. Dışarı alındı; ikon
                    // bozulmadan görünür.
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: RC.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: RC.white, width: 1.5),
                      ),
                    ),
                  ),
                // ── ⚠ BELİRGİN ROZET — "Bul" ikonu, gelen teklif ──
                //
                // KULLANICI BULGUSU (9 Eyl): "Bul butonu üzerindeki
                // ! rozeti hatalı; teklif geldiğini gösteren bir
                // rozet olmalı."
                //
                // ÖNCEDEN 15 px'lik, üzerinde "!" olan bir uyarı
                // işaretiydi. "!" bir SORUN/UYARI anlatır — oysa
                // burada iyi bir haber var: gelen teklif. Üstelik
                // sayı taşımadığı için kaç teklif geldiği
                // görünmüyordu.
                //
                // Artık sekme çubuğundaki rozetle AYNI bileşen
                // (`RefSayiRozeti`) ve AYNI ölçü/konum kuralı:
                // görülmemiş teklif SAYISI yazar.
                //
                // ⚠ İKİ GÖSTERGE AYNI RENKTE, AYRI DİLDE (12 Eyl):
                // "Bildirimler"deki nokta yalnız "yeni var" der,
                // buradaki rozet KAÇ TANE olduğunu söyler. İkisi de
                // kırmızı — ikisi de ilgi bekliyor.
                //
                // ── ⚠ ROZET İKONU KAPATMAZ (12 Eyl, kullanıcı
                // isteği) ──
                //
                // "Sayı kırmızı daire içinde yazılmalı ama Bul
                // ikonunu kapatmamalı."
                //
                // Rozet en az 17 px; `-10 / -8` ile 22 px'lik ikonun
                // sağ üst köşesine 7 px kadar BİNİYORDU. Dışarı
                // alındı: artık köşeye teğet durur, ikonun gövdesi
                // tümüyle görünür.
                //
                // ⚠ KIRPILMA RİSKİ YOK: `Stack` `Clip.none` ve
                // öğenin üstünde 2 px dolgu var; alt bar kendi
                // yüksekliğini içerikten alır.
                if (it.belirginRozetSayisi > 0)
                  Positioned(
                    right: -14,
                    top: -11,
                    child: RefSayiRozeti(
                      sayi: it.belirginRozetSayisi,
                      // Alt bar zemini daima beyazdır.
                      halkaRengi: RC.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4), // gap:4px
            Text(
              it.label,
              maxLines: 1,
              style: refText(
                size: RF.s11,
                weight: RF.w600,
                color: aktifMi ? RC.blue : RC.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── ⚠ ALT BARIN ÜST KENARI — ORTADA YUMUŞAK, SİMETRİK BİR ÇENTİK ──
///
/// `ShapeBorder` alt sınıfı seçildi (bir `CustomClipper` DEĞİL):
/// `Material(shape: ..., elevation: ...)` bu ikisini BİRLİKTE,
/// birbirine uyumlu (gölge şekli KIRPILMIŞ şekli TAKİP eder) çizer —
/// Flutter'ın kendi `BottomAppBar`/`NotchedShape` mekanizmasıyla
/// AYNI temel. Çentik iki yumuşak `quadraticBezierTo` eğrisiyle
/// çizilir — köşeli bir "V" DEĞİL, "yarım ay" görünümü.
class _CentikliKenar extends ShapeBorder {
  const _CentikliKenar({required this.genislik, required this.derinlik});

  final double genislik;
  final double derinlik;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final merkezX = rect.left + rect.width / 2;
    final yg = genislik / 2;
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(merkezX - yg, rect.top)
      ..quadraticBezierTo(merkezX - yg * 0.5, rect.top, merkezX - yg * 0.5,
          rect.top + derinlik * 0.6)
      ..quadraticBezierTo(merkezX, rect.top + derinlik, merkezX + yg * 0.5,
          rect.top + derinlik * 0.6)
      ..quadraticBezierTo(
          merkezX + yg * 0.5, rect.top, merkezX + yg, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// Alt navigasyonlu sayfa iskeleti.
///
/// `.scroll` + `.cust-nav` yapısının karşılığı: içerik kaydırılır,
/// navigasyon sabit kalır.
class RefShell extends StatelessWidget {
  const RefShell({
    super.key,
    required this.child,
    required this.nav,
    this.horizontal = 14,
    this.topExtra = 12,
    this.bottom = 84,
  });

  final Widget child;
  final RefBottomNav nav;
  final double horizontal;
  final double topExtra;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: Column(
        children: [
          Expanded(
            child: RefScroll(
              padding: EdgeInsets.fromLTRB(
                  horizontal, topExtra + safeTop, horizontal, bottom),
              child: child,
            ),
          ),
          nav,
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// PROFİL ALT EKRANLARI — `.ad-*` / `.pi-*` / `.po-next`
// ═══════════════════════════════════════════════════════════════

/// `.ad-sub{font-size:13px;color:#5B6472;margin-top:6px}`
class RefSubtitle extends StatelessWidget {
  const RefSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: refText(size: RF.s13, weight: RF.w400, color: RC.textSoft),
        ),
      );
}


/// `.ad-h3{font-size:16px;font-weight:700;color:#16233D}`
class RefCardTitle extends StatelessWidget {
  const RefCardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: refText(size: RF.s16, weight: RF.w700, color: RC.text),
      );
}


/// `.po-next` — sayfa altı ana eylem düğmesi.
///
/// ```css
/// .po-next{width:100%;display:flex;justify-content:center;gap:9px;
///   border-radius:13px;padding:15px;font-size:16px;font-weight:700;
///   color:#fff;background:linear-gradient(180deg,#2E6FE8,#1A4FC4)}
/// ```
///
/// [RefPrimaryButton]'dan farkı: yarıçap 13, dolgu 15 ve isteğe bağlı
/// ikon. Referansta iki ayrı sınıftır; tek geometriye zorlanmaz.
class RefNextButton extends StatelessWidget {
  const RefNextButton(
    this.label, {
    super.key,
    this.iconAsset,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final String? iconAsset;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null && !busy;
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RR.r13),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: aktif ? onPressed : null,
            child: Ink(
              decoration: const BoxDecoration(gradient: RG.blueCta),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                alignment: Alignment.center,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(RC.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconAsset != null) ...[
                            RefSvg(iconAsset!, size: 18, color: RC.white),
                            const SizedBox(width: 9), // gap:9px
                          ],
                          Text(
                            label,
                            style: refText(
                                size: RF.s16,
                                weight: RF.w700,
                                color: RC.white),
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

/// `.rv-stars{display:flex;justify-content:center;gap:10px;margin-top:14px}`
///
/// Yıldız `#F5A319`; dolu olanlar `fill`, boşlar yalnız `stroke`.
class RefStars extends StatelessWidget {
  const RefStars({
    super.key,
    required this.value,
    this.size = 40,
    this.onChanged,
  });

  final int value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var k = 1; k <= 5; k++) ...[
          if (k > 1) const SizedBox(width: 10), // gap:10px
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(k),
            child: RefSvg(
              k <= value
                  ? 'assets/svg/ic_star_full.svg'
                  : 'assets/svg/ic_star_empty.svg',
              size: size,
            ),
          ),
        ],
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// KAYIT AKIŞI — `.rg-steps` / `.rg-vicon` / `.rg-otp` / `.rg-done-*`
// ═══════════════════════════════════════════════════════════════


class RefVerifyIcon extends StatelessWidget {
  const RefVerifyIcon({super.key, this.asset = 'assets/svg/ic_verify.svg'});

  final String asset;

  @override
  Widget build(BuildContext context) => Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(top: 24, bottom: 18),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: RC.blueSoft,
          shape: BoxShape.circle,
        ),
        child: RefSvg(asset, size: 36),
      );
}

/// `.rg-vlabel` + `.rg-vvalue` — numara gösterimi.
class RefVerifyTarget extends StatelessWidget {
  const RefVerifyTarget({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // .rg-vlabel{14px #5B6472;margin-bottom:5px}
          Text(
            label,
            textAlign: TextAlign.center,
            style: refText(size: RF.s14, weight: RF.w400, color: RC.textSoft),
          ),
          const SizedBox(height: 5),
          // .rg-vvalue{20px/700 #16233D;ls 1px;margin-bottom:22px}
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: refText(
                size: RF.s20,
                weight: RF.w700,
                color: RC.text,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      );
}

/// `.rg-otprow` + `.rg-otp` — 6 haneli kod kutuları.
///
/// ```css
/// .rg-otprow{display:flex;gap:8px;justify-content:center;margin:0 0 18px}
/// .rg-otp{max-width:56px;height:58px;border:1.6px solid #E1E5EC;
///   border-radius:12px;text-align:center;font-size:22px;font-weight:700}
/// ```
class RefOtpInput extends StatelessWidget {
  const RefOtpInput({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.onCompleted,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < controllers.length; i++) ...[
            if (i > 0) const SizedBox(width: 8), // gap:8px
            SizedBox(
              width: 56,
              height: 58,
              child: TextField(
                controller: controllers[i],
                focusNode: focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: refText(
                    size: RF.s22, weight: RF.w700, color: RC.text),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: RC.white,
                  contentPadding: EdgeInsets.zero,
                  border: _k(RC.borderAlt),
                  enabledBorder: _k(RC.borderAlt),
                  focusedBorder: _k(RC.blue),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < controllers.length - 1) {
                    focusNodes[i + 1].requestFocus();
                  } else if (v.isEmpty && i > 0) {
                    focusNodes[i - 1].requestFocus();
                  }
                  if (controllers.every((c) => c.text.isNotEmpty)) {
                    onCompleted?.call();
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _k(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(RR.r12),
        borderSide: BorderSide(color: c, width: 1.6),
      );
}

/// `.rg-done-ico` — tamamlama ekranı büyük daire.
///
/// ```css
/// .rg-done-ico{150×150;border-radius:50%;background:#E9F9EF;
///   margin:34px auto 26px}
/// ```
class RefDoneIcon extends StatelessWidget {
  const RefDoneIcon({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        height: 150,
        margin: const EdgeInsets.only(top: 34, bottom: 26),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: RC.successSoft,
          shape: BoxShape.circle,
        ),
        child: const RefSvg('assets/svg/ic_checkcircle.svg', size: 78),
      );
}

/// `.rg-redir` — otomatik yönlendirme göstergesi.
///
/// ```css
/// .rg-redir{margin-top:38px}
/// .rg-spinner{34×34;border:3px solid #E1E5EC;border-top-color:#1D6BE3;
///   animation:rgspin .8s linear infinite}
/// .rg-redir-t{15px/600 #16233D}
/// .rg-redir-s{13px #8A94A6;margin-top:4px}
/// ```
class RefRedirectNotice extends StatelessWidget {
  const RefRedirectNotice({
    super.key,
    this.title = 'Yönlendiriliyorsunuz...',
    this.subtitle = '2 saniye sonra otomatik geçiş yapılacak.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 38),
        child: Column(
          children: [
            // .rg-spinner
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: RC.blue,
                backgroundColor: RC.borderAlt,
              ),
            ),
            const SizedBox(height: 14), // margin:0 auto 14px
            Text(
              title,
              style: refText(size: RF.s15, weight: RF.w600, color: RC.text),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: refText(size: RF.s13, weight: RF.w400, color: RC.grey),
            ),
          ],
        ),
      );
}


// ═══════════════════════════════════════════════════════════════
// FORM / DETAY EKRANI BİLEŞENLERİ
// Kaynak: `vAddr`, `vPasswd`, `vPInfo`, `vAppRate`
// ═══════════════════════════════════════════════════════════════

/// Geri düğmesi + `.pf-title` + `.ad-sub` başlığı olan sayfa üstü.
///
/// ```
/// <button class="rg-back" onclick="history.back()">IC_BACK</button>
/// <h1 class="pf-title" style="margin-top:6px">…</h1>
/// <p class="ad-sub">…</p>
/// ```
class RefDetailHeader extends StatelessWidget {
  const RefDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.geriDugmesi,
  });

  final String title;
  final String? subtitle;

  /// Başlığın üstünde GERİ OKU çizilsin mi?
  ///
  /// ⚠ VARSAYILAN AÇIK — HER PLATFORMDA ÇİZİLİR.
  ///
  /// ## KARARIN GEÇMİŞİ
  ///
  final bool? geriDugmesi;

  /// Varsayılan AÇIK — bkz. [geriDugmesi].
  static bool okGosterilirMi(bool? istek) => istek ?? true;

  @override
  Widget build(BuildContext context) {
    final okVar = okGosterilirMi(geriDugmesi);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (okVar)
            Align(
              alignment: Alignment.centerLeft,
              // ⚠ GERİ BUTONU HER DURUMDA ÇALIŞIR.
              //
              // `Navigator.maybePop` yığında geri dönülecek route
              // yoksa SESSİZCE HİÇBİR ŞEY YAPMAZ. `pushReplacement`
              // ile açılan ekranlarda buton ölü kalıyordu.
              //
              // Geri dönülemiyorsa uygulamanın ana ekranına gidilir.
              child: RefBackButton(onTap: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushNamedAndRemoveUntil('/home', (_) => false);
                }
              }),
            ),
          if (okVar)
            const SizedBox(height: 6), // style="margin-top:6px"
          Text(
            title,
            style: refText(
              size: RF.s25,
              weight: RF.w700,
              color: RC.text,
              letterSpacing: RF.lsM03,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: refText(
                size: RF.s135,
                weight: RF.w400,
                color: RC.textSoft,
                height: RF.lh145,
              ),
            ),
          ],
        ],
    );
  }
}

/// `.ad-card` — beyaz form kutusu.
///
/// ```css
/// .ad-card{background:#fff;border:1px solid #ECEEF1;border-radius:15px;
///   padding:15px;margin-top:14px}
/// ```
class RefFormCard extends StatelessWidget {
  const RefFormCard({super.key, required this.child, this.marginTop = 14});

  final Widget child;
  final double marginTop;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: marginTop),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border), // #ECEEF1
          borderRadius: BorderRadius.circular(RR.r15),
        ),
        child: child,
      );
}

/// `.ad-lbl` — alan etiketi (+ isteğe bağlı `.po-req` kırmızı yıldız).
///
/// ```css
/// .ad-lbl{font-size:13.5px;font-weight:700;color:#16233D;
///   margin:15px 1px 7px}
/// .po-req{color:#E5452C;font-weight:600;font-size:12.5px}
/// ```
class RefFieldLabel extends StatelessWidget {
  const RefFieldLabel(this.text, {super.key, this.zorunlu = false, this.ilk = false});

  final String text;
  final bool zorunlu;

  /// İlk etikette üst boşluk uygulanmaz.
  final bool ilk;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(1, ilk ? 0 : 15, 1, 7),
        child: Row(
          children: [
            // ── ⚠ YILDIZ SOLDA — `RefRegDropdown`daki (İl/İlçe/
            // Mahalle/Hizmet Kategorileri) referans desenle TUTARLI
            // hale getirildi. Önceden adın ARDINDAN geliyordu
            // ("Ad *"); artık ÖNÜNDEN gelir ("* Ad") — uygulama
            // genelinde zorunlu alan yıldızının TEK, TUTARLI konumu
            // budur.
            if (zorunlu)
              Text(
                '* ',
                style: refText(
                    size: RF.s135, weight: RF.w700, color: RC.requiredStar),
              ),
            Text(
              text,
              style: refText(
                  size: RF.s135, weight: RF.w700, color: RC.text),
            ),
          ],
        ),
      );
}

/// `.ad-drop` — seçim açan alan.
///
/// ```css
/// .ad-drop{width:100%;justify-content:space-between;gap:10px;
///   border:1.4px solid #E1E5EC;border-radius:12px;background:#fff;
///   padding:13px 13px}
/// ```
class RefDropdownField extends StatelessWidget {
  const RefDropdownField({
    super.key,
    required this.value,
    this.onTap,
    this.placeholder = 'Seçiniz',
    this.zorunlu = false,
    this.etiket,
    this.iconAsset,
  });

  final String? value;
  final VoidCallback? onTap;
  final String placeholder;

  /// Kutunun ÜSTÜNDE görünen alan adı ("İl", "İlçe", "Mahalle").
  /// ⚠ Verilmezse etiket çizilmez — mevcut çağrılar etkilenmez.
  final String? etiket;

  /// ⚠ YENİ, OPSİYONEL — verilmezse HİÇ İKON ÇİZİLMEZ, mevcut
  /// çağrılar (ör. `addresses_screen.dart`) ETKİLENMEZ. Sol taraftaki
  /// ikon `RefRegDropdown`daki (kayıt ekranının İl/İlçe/Mahalle
  /// seçicileri) AYNI görsel yerleşimi kullanır — iki ayrı ikon
  /// deseni İCAT EDİLMEDİ.
  final String? iconAsset;

  /// ⚠ ZORUNLU SEÇİM — yıldız yer tutucunun ÖNÜNDE çizilir.
  ///
  /// Seçim yapılınca yıldız kalkar ve yerini seçilen değere bırakır.
  /// Metin alanlarındaki yıldızla (bkz. `refYerTutucu`) AYNI, tutarlı
  /// konumdadır — ikisi de SOLDA.
  final bool zorunlu;

  @override
  Widget build(BuildContext context) {
    // ⚠ ETİKET KUTUNUN ÜSTÜNDE (bkz. `RefTextField` notu).
    //
    // Seçim alanlarında ad ("İl", "İlçe") yer tutucu olarak
    // yazılıyordu; seçim yapılınca kayboluyordu.
    final alan = _kutu(context);
    if (etiket == null || etiket!.isEmpty) {
      return alan;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefFieldLabel(etiket!, zorunlu: zorunlu, ilk: true),
        alan,
      ],
    );
  }

  Widget _kutu(BuildContext context) {
    final bos = value == null || value!.isEmpty;
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.borderAlt, width: 1.4), // #E1E5EC
          borderRadius: BorderRadius.circular(RR.r12),
        ),
        child: Row(
          children: [
            // ⚠ YENİ — `iconAsset` verilmediyse HİÇBİR ŞEY ÇİZİLMEZ
            // (`addresses_screen.dart` gibi mevcut çağrılar aynı
            // kalır). `RefRegDropdown` ile AYNI 22px/12px yerleşimi.
            if (iconAsset != null) ...[
              SizedBox(
                width: 22,
                child: Center(child: RefSvg(iconAsset!, size: 20)),
              ),
              const SizedBox(width: 12),
            ],
            if (zorunlu && bos) ...[
              Text('*',
                  style: refText(
                      size: RF.s145,
                      weight: RF.w700,
                      color: RC.requiredStar,
                      height: RF.lh100)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                bos ? placeholder : value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: refText(
                  size: RF.s145,
                  weight: RF.w500,
                  color: bos ? RC.greyLight : RC.text,
                ),
              ),
            ),
            const SizedBox(width: 10), // gap:10px
            const RefSvg('assets/svg/ic_chev.svg',
                size: 18, color: RC.textSoft),
          ],
        ),
      ),
    );
  }
}

/// `.pi-in` — düz metin girdisi.
///
/// ```css
/// .pi-in{width:100%;border:1.4px solid #E1E5EC;border-radius:12px;
///   background:#fff;padding:12px 13px;font-size:14.5px;color:#16233D}
/// ```
class RefTextField extends StatelessWidget {
  const RefTextField({
    super.key,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.buildCounter,
    this.onChanged,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.hatali = false,
    this.alanAnahtari,
    this.zorunlu = false,

    /// ── ⚠ BAŞ HARF BÜYÜTME ──
    ///
    /// Varsayılan `sentences`: kullanıcı yazmaya başladığında ilk harf
    /// otomatik büyük gelir. Bu bir KLAVYE İPUCUDUR, zorlama değildir
    /// — kullanıcı isterse küçültüp kendi yazabilir.
    ///
    /// ⚠ Metni DEĞİŞTİREN bir biçimlendirici KULLANILMADI: öyle
    /// olsaydı kullanıcının düzeltmesi anında geri alınır ve alan
    /// kullanılamaz hale gelirdi.
    ///
    /// ⚠ E-posta ve şifre alanlarında çağıran taraf `none` verir;
    /// oralarda büyük harf yanlış olur.
    this.textCapitalization = TextCapitalization.sentences,

    /// Kutunun ÜSTÜNDE görünen alan adı. Verilmezse `hint` kullanılır.
    this.etiket,

    /// Kutunun İÇİNDE görünen BİÇİM ÖRNEĞİ ("5XX XXX XX XX").
    /// ⚠ Alan adı buraya yazılmaz — o `etiket`e aittir.
    this.yerTutucu,
  });

  final TextEditingController controller;

  /// ⚠ GERİYE UYUMLULUK: mevcut ekranlar alan adını `hint` olarak
  /// veriyor. Etiket verilmezse bu metin ETİKET olarak kullanılır;
  /// kutunun içinde çizilmez.
  final String? hint;
  final String? etiket;
  final String? yerTutucu;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;

  /// Karakter sınırı. Sayaç `buildCounter` ile gizlenebilir.
  final int? maxLength;
  final InputCounterWidgetBuilder? buildCounter;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// ⚠ Sonraki alana geçişte BUNU kullanın (bkz. `RefFormField` notu).
  ///
  /// NEXT GEÇİŞİ İÇİN DAVRANIŞ DÜZELTMESİ — kesin kök neden olarak
  /// ilan edilmemiştir; cihaz ölçümüyle doğrulanacaktır.
  final VoidCallback? onEditingComplete;

  /// ⚠ Doğrulama hatası — kenarlık KIRMIZI çizilir.
  ///
  /// Dış sarmalayıcı `Container` KULLANILMAZ: hem odak çerçevesiyle
  /// çakışıp çift renk oluşturuyor, hem de koşullu eklenip
  final bool hatali;

  /// ALAN DÜZELİNCE UYARININ ANINDA KALKMASI İÇİN.
  ///
  /// Form `AutovalidateMode.onUnfocus` ile çalışır: uyarı alandan
  /// çıkılınca görünür — yazarken her tuşta kırmızıya boyanmaz.
  /// Ancak uyarı bir kez göründükten sonra kullanıcı hatayı düzeltse
  /// bile başka bir alana dokunmadan kalkmıyordu.
  ///
  /// Bu anahtar verilirse çağıran ekran, değer geçerli hâle geldiğinde
  /// YALNIZ BU ALANI yeniden doğrulayabilir:
  /// `alanAnahtari.currentState?.validate()`.
  ///
  /// ⚠ Formun tamamı doğrulanmaz — dokunulmamış diğer alanlar erkenden
  /// kırmızıya boyanmaz.
  final GlobalKey<FormFieldState<String>>? alanAnahtari;

  /// `.rg-star` — ZORUNLU ALAN YILDIZI.
  ///
  /// ⚠ VARSAYILAN `false` — `RefFormField`'ınkinden FARKLI, BİLEREK.
  ///
  /// `RefFormField` yalnız zorunlu alanlarda kullanıldığı için orada
  /// varsayılan `true`dur. `RefTextField` ise isteğe bağlı alanlarda
  /// da kullanılıyor: değerlendirme yorumu, uygulama puanlama metni,
  /// çatı ekranı araması, ilan açıklaması ve serbest gerekçe sayfası.
  /// Varsayılan `true` yapılsaydı bu alanların hepsinde yanlışlıkla
  /// yıldız çıkardı.
  ///
  /// ⚠ Bu fark tutarsızlık DEĞİLDİR; iki bileşenin kullanım alanı
  /// farklıdır. Değiştirmeden önce yukarıdaki listeye bakınız.
  ///
  /// ── NEDEN YILDIZ BURADA GEREKLİ ──
  ///
  /// Yıldız `RefFieldLabel` içinde BİLEREK bastırılıyor (aynı bilgi
  /// başlıkta ve kutuda iki kez görünmesin diye) ve `RefFormField`
  /// kutunun içinde çiziyor. `RefTextField` ise yıldız çizmiyordu:
  final bool zorunlu;

  @override
  Widget build(BuildContext context) {
    // ── ⚠ ETİKET KUTUNUN DIŞINDA, SOL ÜSTTE ──
    //
    // Nihai karar: alan adı ("Ad", "Telefon") kutunun İÇİNDE yer
    // tutucu olarak DEĞİL, kutunun ÜSTÜNDE etiket olarak durur.
    //
    // Yer tutucu olarak yazıldığında kullanıcı alanı doldurunca ad
    // KAYBOLUYOR; formu gözden geçirirken hangi kutunun ne olduğu
    // görünmüyordu. Etiket her zaman görünür kalır.
    //
    // ⚠ ETİKET `hint`TEN TÜRETİLİR: çağıran ekranlar zaten alan adını
    // `hint` olarak veriyordu. Otuza yakın çağrı noktasını tek tek
    final ad = etiket ?? hint;
    final alan = _girdi(context);
    if (ad == null || ad.isEmpty) {
      return alan;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefFieldLabel(ad, zorunlu: zorunlu, ilk: true),
        alan,
      ],
    );
  }

  Widget _girdi(BuildContext context) {
    return TextFormField(
      key: alanAnahtari,
      // Klavye altında kalmama payı — bkz. [kAlanKaydirmaPayi].
      scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: buildCounter,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      onEditingComplete: onEditingComplete,
      textCapitalization: textCapitalization,
      style: refText(size: RF.s145, weight: RF.w500, color: RC.text),
      decoration: InputDecoration(
        // ⚠ KUTUNUN İÇİ BOŞ: ad artık ÜSTTEKİ etikette (yukarı bkz.).
        //
        // `hint` yalnız BİÇİM ÖRNEĞİ olduğunda çizilir — "5XX XXX XX
        // XX" gibi. Alan adının kendisi ("Telefon") içeride
        // tekrarlanmaz.
        hint: (yerTutucu == null || yerTutucu!.isEmpty)
            ? null
            : refYerTutucu(yerTutucu!, zorunlu: false),
        filled: true,
        fillColor: RC.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
        suffixIcon: suffix,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 24),
        border: _cerceve(hatali ? RC.danger : RC.borderAlt),
        enabledBorder: _cerceve(hatali ? RC.danger : RC.borderAlt),
        focusedBorder: _cerceve(hatali ? RC.danger : RC.blue),
        errorBorder: _cerceve(RC.danger),
        focusedErrorBorder: _cerceve(RC.danger),
        errorStyle:
            refText(size: RF.s115, weight: RF.w600, color: RC.danger),
      ),
    );
  }

  OutlineInputBorder _cerceve(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(RR.r12),
        borderSide: BorderSide(color: c, width: 1.4),
      );
}

/// `.po-next` — geniş birincil eylem düğmesi (ikonlu).
///
/// ```css
/// .po-next{width:100%;justify-content:center;gap:9px;border-radius:13px;
///   padding:15px;font-size:16px;font-weight:700;color:#fff}
/// ```
class RefWideButton extends StatelessWidget {
  const RefWideButton(
    this.label, {
    super.key,
    this.iconAsset,
    this.onPressed,
    this.busy = false,
    this.marginTop = 0,
  });

  final String label;
  final String? iconAsset;
  final VoidCallback? onPressed;
  final bool busy;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null && !busy;
    return Container(
      margin: EdgeInsets.only(top: marginTop),
      child: Opacity(
        opacity: aktif ? 1 : 0.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RR.r13),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: aktif ? onPressed : null,
              child: Ink(
                decoration: const BoxDecoration(gradient: RG.blueCta),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  alignment: Alignment.center,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(RC.white),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (iconAsset != null) ...[
                              RefSvg(iconAsset!, size: 18, color: RC.white),
                              const SizedBox(width: 9), // gap:9px
                            ],
                            Text(
                              label,
                              style: refText(
                                  size: RF.s16,
                                  weight: RF.w700,
                                  color: RC.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// KAYIT AKIŞI BİLEŞENLERİ — `rgStepper`, `rgOtp`, `rgResendRow`
// ═══════════════════════════════════════════════════════════════

/// `rgStepper(cur)` — 3 adımlı ilerleme göstergesi.
///
/// ```css
/// .rg-steps  { margin:2px 4px 22px }
/// .rg-dot    { 38×38; %50; 15px/700; background:#EDF0F5 }
/// .rg-dot.on { background:#1D6BE3; color:#fff;
///              box-shadow:0 5px 12px rgba(29,107,227,.35) }
/// .rg-conn   { flex:1; height:3px; background:#EDF0F5; radius:2px;
///              margin:0 2px }
/// .rg-conn.on{ background:#1D6BE3 }
/// ```
/// Etiketler: Bilgileriniz · Doğrulama · Tamamla
class RefStepper extends StatelessWidget {
  const RefStepper({super.key, required this.current, this.labels});

  /// 1 tabanlı geçerli adım.
  final int current;

  /// Adım etiketleri. Verilmezse varsayılan üç adım kullanılır.
  ///
  /// ⚠ Hizmet ana sayfadan seçilmişse kategori adımı gösterilmez ve
  /// akış iki adıma iner (Açıklama, Önizle & Yayınla).
  final List<String>? labels;

  static const _etiket = ['Bilgileriniz', 'Doğrulama', 'Tamamla'];

  @override
  Widget build(BuildContext context) {
    final etiketler = labels ?? _etiket;
    final n = etiketler.length;

    Widget nokta(int i) {
      final tamam = i < current;
      final etkin = i == current;
      return Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (tamam || etkin) ? RC.blue : const Color(0xFFEDF0F5),
          shape: BoxShape.circle,
          boxShadow: etkin ? RS.blueButton : null,
        ),
        child: tamam
            ? const RefSvg('assets/svg/ic_checksm.svg',
                size: 18, color: RC.white)
            : Text(
                '$i',
                style: refText(
                  size: RF.s15,
                  weight: RF.w700,
                  color: etkin ? RC.white : RC.textSoft,
                ),
              ),
      );
    }

    Widget cizgi(int i) => Container(
          height: 3,
          decoration: BoxDecoration(
            color: i < current ? RC.blue : const Color(0xFFEDF0F5),
            borderRadius: BorderRadius.circular(2),
          ),
        );

    // ⚠ NOKTA VE ETİKET AYNI SÜTUNDA HİZALANIR.
    //
    // Önceki düzende bağlayıcı çizgi `i < 3` ile sabitlenmişti; 4
    // adımda son bağlantı çizilmiyor, noktalar birbirine yapışıyordu.
    // Etiketler de `spaceBetween` ile serbest dağıldığı için
    // noktalarla KAYIK görünüyordu.
    //
    // Artık her adım eşit genişlikte bir sütundur: nokta ortada,
    // etiket altında ortalı; çizgiler sütunlar arasına yerleşir.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 22),
      child: Column(children: [
        SizedBox(
          height: 38,
          child: Row(children: [
            for (var i = 1; i <= n; i++) ...[
              Expanded(child: Center(child: nokta(i))),
              if (i < n)
                SizedBox(width: 18, child: Center(child: cizgi(i))),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 1; i <= n; i++) ...[
              Expanded(
                child: Text(
                  etiketler[i - 1],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: refText(
                    size: n > 3 ? RF.s11 : RF.s115,
                    weight: i <= current ? RF.w700 : RF.w500,
                    color: i <= current ? RC.blue : RC.textMuted,
                    height: RF.lh120,
                  ),
                ),
              ),
              if (i < n) const SizedBox(width: 18),
            ],
          ],
        ),
      ]),
    );
  }
}

/// `.rg-vicon` + `.rg-vlabel` + `.rg-vvalue` — doğrulama başlığı.
///
/// ```css
/// .rg-vicon {80×80; %50; #EAF1FB; margin:24px auto 18px}
/// .rg-vlabel{center; #5B6472; 14px; margin-bottom:5px}
/// .rg-vvalue{center; #16233D; 20px/700; ls 1px; margin-bottom:22px}
/// ```
class RefVerifyHeader extends StatelessWidget {
  const RefVerifyHeader({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  /// `maskPhone(p)` — `+90 5XX *** ** XX`
  static String maskPhone(String p) {
    final d = p.replaceAll(RegExp(r'\D'), '');
    if (d.length < 5) {
      return '+90 $d';
    }
    return '+90 ${d.substring(0, 3)} *** ** ${d.substring(d.length - 2)}';
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(top: 24, bottom: 18),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: RC.blueSoft, // #EAF1FB
              shape: BoxShape.circle,
            ),
            child: const RefSvg('assets/svg/ic_verify.svg', size: 36),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: refText(
                size: RF.s14, weight: RF.w400, color: RC.textSoft),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: refText(
              size: RF.s20,
              weight: RF.w700,
              color: RC.text,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 22),
        ],
      );
}

/// `.rg-otprow` — 6 haneli kod kutuları.
///
/// ```css
/// .rg-otprow{display:flex;gap:8px;justify-content:center;margin:0 0 18px}
/// .rg-otp   {flex:1;max-width:56px;height:58px;
///            border:1.6px solid #E1E5EC;border-radius:12px;
///            text-align:center;font-size:22px;font-weight:700}
/// ```
class RefOtpBoxes extends StatefulWidget {
  const RefOtpBoxes({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onDegisti,
    this.enabled = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;

  /// ⚠ HER DEĞİŞİMDE haber verir (yalnız tamamlanınca değil).
  ///
  /// Ekranın "Doğrula" düğmesini kod TAM olmadan pasif tutabilmesi
  /// için gerekli: eskiden düğme her zaman aktifti ve eksik kodla
  /// basılınca uyarı çıkıyordu. Ortak kural: eksik girdiyle düğme
  /// AKTİF OLMAZ, uyarı da üretilmez.
  final ValueChanged<String>? onDegisti;

  final bool enabled;

  @override
  State<RefOtpBoxes> createState() => RefOtpBoxesState();
}

class RefOtpBoxesState extends State<RefOtpBoxes> {
  /// SIFIR GENİŞLİKLİ İŞARETÇİ — kutu ASLA gerçekten boş kalmaz.
  ///
  /// ⚠ NEDEN GEREKLİ
  ///
  /// Android yazılım klavyesi, BOŞ bir alanda geri silmeye basıldığında
  /// donanım tuşu olayı ÜRETMEZ; IME yalnız "sil" komutu gönderir ve
  /// metin zaten boş olduğu için `onChanged` de tetiklenmez. Sonuç:
  /// kullanıcı her kutuya ayrı ayrı dokunup silmek zorunda kalıyordu.
  ///
  /// Her kutuda görünmez bir karakter tutulursa silme HER ZAMAN metni
  /// değiştirir, `onChanged` çalışır ve odak kendiliğinden bir önceki
  /// kutuya kayar. Böylece geri silme tuşuna basılı tutmak 6 haneyi
  /// sondan başa siler.
  static const _iz = '\u200b';

  late final List<TextEditingController> _c = List.generate(
      widget.length, (_) => TextEditingController(text: _iz));
  late final List<FocusNode> _f =
      List.generate(widget.length, (_) => FocusNode());

  /// Bir kutunun GÖRÜNEN rakamı (işaretçi hariç).
  String _rakam(int i) => _c[i].text.replaceAll(_iz, '');

  /// Girilen kodu döndürür.
  String get code =>
      List.generate(widget.length, _rakam).join();

  /// Kutuyu işaretçiyle birlikte yazar ve imleci sona alır.
  void _yaz(int i, String rakam) {
    final t = '$_iz$rakam';
    _c[i].value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  /// Hatalı kod sonrası temizleme.
  void clear() {
    for (var i = 0; i < widget.length; i++) {
      _yaz(i, '');
    }
    if (mounted) {
      _f.first.requestFocus();
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final e in _c) {
      e.dispose();
    }
    for (final e in _f) {
      e.dispose();
    }
    super.dispose();
  }

  void _degisti(int i, String v) {
    if (!v.contains(_iz)) {
      final kalan = v.replaceAll(RegExp(r'\D'), '');
      if (kalan.isEmpty) {
        _yaz(i, '');
        if (i > 0) {
          // Bir önceki kutuyu temizle ve oraya geç — zincir devam eder.
          _yaz(i - 1, '');
          _f[i - 1].requestFocus();
        }
        setState(() {});
        return;
      }
      // Nadir durum: işaretçi kaybolmuş ama rakam var.
      _yaz(i, kalan.characters.last);
      if (i < widget.length - 1) {
        _f[i + 1].requestFocus();
      }
      setState(() {});
      _tamamMi();
      return;
    }

    final rakam = v.replaceAll(RegExp(r'\D'), '');

    // Yapıştırma / otomatik doldurma: tek kutuya birden çok hane gelirse dağıt.
    if (rakam.length > 1) {
      for (var k = 0; k < widget.length; k++) {
        _yaz(k, k < rakam.length ? rakam[k] : '');
      }
      final son = rakam.length.clamp(0, widget.length - 1);
      _f[son].requestFocus();
      setState(() {});
      _tamamMi();
      return;
    }

    _yaz(i, rakam);
    if (rakam.isNotEmpty && i < widget.length - 1) {
      _f[i + 1].requestFocus();
    }
    setState(() {});
    _tamamMi();
  }

  void _tamamMi() {
    widget.onDegisti?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  /// KESİNTİSİZ GERİ SİLME
  ///
  /// Aktif kutu BOŞKEN backspace'e basılırsa `onChanged` tetiklenmez
  /// (metin değişmez). Bu yüzden tuş olayı doğrudan yakalanır:
  /// odak bir önceki kutuya kayar ve oradaki karakter silinir.
  ///
  /// Böylece kullanıcı 6 haneyi art arda backspace ile sondan başa
  /// silebilir; kutulara tek tek dokunmak gerekmez.
  KeyEventResult _tus(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_c[i].text.isNotEmpty) {
      // Dolu kutu: normal silme `onChanged` ile işlenir.
      return KeyEventResult.ignored;
    }
    if (i == 0) {
      return KeyEventResult.ignored;
    }
    _c[i - 1].clear();
    _f[i - 1].requestFocus();
    setState(() {});
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.length; i++) ...[
            if (i > 0) const SizedBox(width: 8), // gap:8px
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 56),
                child: SizedBox(
                  height: 58,
                  child: Focus(
                    onKeyEvent: (_, e) => _tus(i, e),
                    child: TextField(
                    controller: _c[i],
                    focusNode: _f[i],
                    enabled: widget.enabled,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    // ⚠ Sınır ve filtre KULLANILMAZ: görünmez işaretçi
                    // hem uzunluğa dahildir hem de rakam filtresine
                    // takılır. Ayıklama `_degisti` içinde yapılır.
                    onChanged: (v) => _degisti(i, v),
                    style: refText(
                        size: RF.s22, weight: RF.w700, color: RC.text),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: RC.white,
                      contentPadding: EdgeInsets.zero,
                      border: _cerceve(RC.borderAlt),
                      enabledBorder: _cerceve(RC.borderAlt),
                      focusedBorder: _cerceve(RC.blue),
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _cerceve(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(RR.r12),
        borderSide: BorderSide(color: c, width: 1.6),
      );
}

/// `.rg-resend` — kod tekrar gönderme satırı.
///
/// ```css
/// .rg-resend  {text-align:center;margin-bottom:20px}
/// .rg-resend-t{color:#5B6472;font-size:13.5px}
/// .rg-resend-c{color:#1D6BE3;font-weight:700;font-size:16px;margin-top:2px}
/// ```
class RefResendRow extends StatelessWidget {
  const RefResendRow({
    super.key,
    required this.saniye,
    this.onResend,
  });

  /// Kalan saniye; 0 ise düğme etkindir.
  final int saniye;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final dk = (saniye ~/ 60).toString().padLeft(2, '0');
    final sn = (saniye % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Text(
            // ⚠ Metin ters kurulmuştu: sayaç DEVAM EDERKEN "Kodu
            // tekrar gönderebilirsiniz" yazıyordu — oysa o sırada
            // tekrar gönderme KAPALIDIR. Doğrusu bekleme mesajıdır.
            saniye > 0
                ? 'Yeni kod isteyebilmek için bekleyin'
                : 'Kod gelmedi mi?',
            style: refText(
                size: RF.s135, weight: RF.w400, color: RC.textSoft),
          ),
          const SizedBox(height: 2),
          if (saniye > 0)
            Text(
              '$dk:$sn',
              style: refText(
                  size: RF.s16, weight: RF.w700, color: RC.blue),
            )
          else ...[
            // ── ⚠ SAYAÇ BİTİNCE TEK CÜMLELİK YÖNLENDİRME ──
            //
            // Kod gelmemesinin en sık sebebi yanlış yazılmış
            // numaradır. Kullanıcı bunu kendisi kontrol edebilir.
            //
            // ⚠ CÜMLE, GİRİLEN NUMARA HAKKINDA HİÇBİR ŞEY SÖYLEMEZ.
            // "Bu numara kayıtlı değil" demek hesap sayımına
            // (enumeration) kapı açardı; "numaranız doğru mu" ise
            // yalnız yapılacak işi gösterir ve dört akışta da
            // geçerlidir: kayıt, giriş, telefon değişimi, kurtarma.
            //
            // ⚠ SAYAÇ SÜRERKEN GÖSTERİLMEZ: kullanıcı daha kodu
            // beklemeye başlamadan telaşlanmasın.
            Text(
              'Numaranızın doğru olduğundan emin olun.',
              textAlign: TextAlign.center,
              style: refText(
                  size: RF.s125, weight: RF.w400, color: RC.textSoft),
            ),
            const SizedBox(height: 2),
            RefTap(
              onTap: onResend,
              borderRadius: BorderRadius.circular(RR.r8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 8),
                child: Text(
                  'Tekrar Gönder',
                  style: refText(
                      size: RF.s16, weight: RF.w700, color: RC.blue),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


/// Tehlikeli eylem düğmesi (sil/iptal) — kırmızı kenarlık.
///
/// Referans `.pr-cta` geometrisini izler; renk `#E5452C`.
class RefDangerButton extends StatelessWidget {
  const RefDangerButton(this.label, {super.key, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final aktif = onPressed != null;
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: Material(
        color: RC.white,
        borderRadius: BorderRadius.circular(RR.r13),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(RR.r13),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: RC.danger, width: 1.4),
              borderRadius: BorderRadius.circular(RR.r13),
            ),
            child: Text(
              label,
              style: refText(
                  size: RF.s15, weight: RF.w700, color: RC.danger),
            ),
          ),
        ),
      ),
    );
  }
}


/// Yalın metin bağlantısı (`.po-homelink` / `.nt-readall` deseni).
class RefTextButton extends StatelessWidget {
  const RefTextButton(this.label, {super.key, this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(RR.r8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text(
            label,
            style: refText(
                size: RF.s135, weight: RF.w700, color: color ?? RC.blue),
          ),
        ),
      );
}

/// Onay kutulu satır (`CheckboxListTile` karşılığı).
///
/// Referansta liste satırları düz kutu + metin biçimindedir; Material
/// `ListTile` geometrisi kullanılmaz.
class RefCheckRow extends StatelessWidget {
  const RefCheckRow({
    super.key,
    required this.value,
    required this.label,
    this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String label;
  final String? subtitle;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(RR.r12),
        child: Padding(
          // `.ma-row{padding:12px 3px;gap:11px;font-size:14px}`
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: refText(
                            size: RF.s145,
                            weight: value ? RF.w700 : RF.w500,
                            color: RC.text)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            style: refText(
                                size: RF.s12,
                                weight: RF.w400,
                                color: RC.textSoft)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ⚠ GERÇEK ONAY KUTUSU — referans: seçim satırının SAĞINDA.
              //
              // Önceden 2×2 ızgara ikonu kullanılıyordu; cihazda
              // kutucuk yerine dört küçük kare görünüyordu.
              // Burada kutu doğrudan çizilir: `RefAgreeRow` ile aynı
              // görünüm (22×22, r6, #C7CEDA → seçiliyken #1D6BE3).
              RefCheckBox(value: value),
            ],
          ),
        ),
      );
}


/// Onay kutusu görseli — `.rg-cb` ile AYNI.
///
/// ```css
/// .rg-cb        {22×22; border:2px solid #C7CEDA; border-radius:6px}
/// .rg-cb:checked{background:#1D6BE3; border-color:#1D6BE3}
/// ```
class RefCheckBox extends StatelessWidget {
  const RefCheckBox({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value ? RC.blue : Colors.transparent,
          border: Border.all(
              color: value ? RC.blue : const Color(0xFFC7CEDA), width: 2),
          borderRadius: BorderRadius.circular(RR.r6),
        ),
        child: value
            ? const RefSvg('assets/svg/ic_checksm.svg',
                size: 13, color: RC.white)
            : null,
      );
}

// ═══════════════════════════════════════════════════════════════
// KAYIT FORMU — referans `vRegStep1()` yardımcıları
// ═══════════════════════════════════════════════════════════════

/// `rgDrop()` — `.rg-f` kutusu içinde seçim satırı.
///
/// ```
/// <div class="rg-f tap" onclick="...">
///   <span class="rg-ic">ICON</span>
///   <div class="rg-val">{rgStar}<span class="rg-ph">label</span></div>
///   <span class="rg-chevd">IC_CHEVD('#98A2B3',20)</span>
/// </div>
/// ```
/// ```css
/// .rg-val  {flex:1;gap:6px;font-size:15px;font-weight:500;ellipsis}
/// .rg-ph   {color:#9AA4B5}
/// .rg-selv {color:#16233D}
/// ```
///
/// ⚠ Metin girdisiyle AYNI kutu ailesini kullanır (`.rg-f`);
/// alt çizgili Material `DropdownButton` görünümü KULLANILMAZ.
class RefRegDropdown extends StatelessWidget {
  const RefRegDropdown({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.value,
    this.onTap,
    this.zorunlu = true,
    this.iconColor,
  });

  final String iconAsset;

  /// Seçim yokken gösterilen etiket (`.rg-ph`).
  final String label;

  /// Seçili değer (`.rg-selv`); `null` ise etiket gösterilir.
  final String? value;

  final VoidCallback? onTap;
  final bool zorunlu;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final secili = value != null && value!.isNotEmpty;
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        // ⚠ Aralık `RefFormField` ile AYNI olmalı: kayıt ekranında
        // metin alanları ve açılır menüler alt alta dizilir.
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Row(
          children: [
            // .rg-ic{flex:0 0 22px}
            SizedBox(
              width: 22,
              child: Center(
                child: RefSvg(iconAsset, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 12), // gap:12px
            // .rg-val
            Expanded(
              child: Row(
                children: [
                  if (zorunlu && !secili) ...[
                    Text('*',
                        style: refText(
                            size: RF.s15,
                            weight: RF.w700,
                            color: RC.requiredStar,
                            height: RF.lh100)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      secili ? value! : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                        size: RF.s15,
                        weight: RF.w500,
                        color: secili ? RC.text : RC.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // .rg-chevd
            const RefSvg('assets/svg/ic_chevd.svg',
                size: 20, color: RC.greyLight),
          ],
        ),
      ),
    );
  }
}

/// `.rg-cc` — telefon alanının sağındaki ülke kodu + aşağı ok.
///
/// ```css
/// .rg-cc{gap:2px;font-weight:600;color:#16233D;font-size:15px;
///   border-left:1.5px solid #E7EAEF;padding-left:11px;margin-left:2px}
/// ```
class RefCountryCodeDrop extends StatelessWidget {
  const RefCountryCodeDrop({super.key, this.kod = '+90', this.onTap});

  final String kod;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.r8),
        child: Container(
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.only(left: 11),
          decoration: const BoxDecoration(
            border: Border(
                left: BorderSide(color: RC.borderLight, width: 1.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kod,
                  style: refText(
                      size: RF.s15, weight: RF.w600, color: RC.text)),
              const SizedBox(width: 2), // gap:2px
              const RefSvg('assets/svg/ic_chevd.svg',
                  size: 16, color: RC.text),
            ],
          ),
        ),
      );
}

/// `.rg-agree` — sözleşme onay satırı.
///
/// ```css
/// .rg-agree{display:flex;align-items:flex-start;gap:11px;
///           margin:6px 2px 18px}
/// .rg-cb   {22×22; border:2px solid #C7CEDA; border-radius:6px}
/// .rg-cb:checked{background:#1D6BE3;border-color:#1D6BE3}
/// .rg-link {color:#1D6BE3;font-weight:600}
/// ```
///
/// ⚠ GERÇEK onay kutusudur; ikon dizisi DEĞİLDİR.
class RefAgreeRow extends StatelessWidget {
  const RefAgreeRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.parts,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// ZORUNLU ALANLAR TAMAMLANMADAN İŞARETLENEMEZ.
  ///
  /// ⚠ İŞ KURALI: kullanıcı formu doldurmadan sözleşmeyi onaylayamaz.
  /// Kapalıyken satır soluk çizilir, dokunma yok sayılır ve yasal
  /// bağlantılar da açılmaz — yanlışlıkla onay imkânsızdır.
  final bool enabled;

  /// Metin parçaları: `(metin, tıklanabilir mi, onTap)`.
  final List<({String text, VoidCallback? onTap})> parts;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // Kapalıyken satır soluk çizilir — kullanıcı neden
      // işaretleyemediğini görür.
      opacity: enabled ? 1 : 0.45,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .rg-cb
          RefTap(
            // ⚠ Kapalıyken `null` verilir: dokunma HİÇ işlenmez.
            onTap: enabled ? () => onChanged(!value) : null,
            borderRadius: BorderRadius.circular(RR.r6),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value ? RC.blue : Colors.transparent,
                border: Border.all(
                    color: value ? RC.blue : const Color(0xFFC7CEDA),
                    width: 2),
                borderRadius: BorderRadius.circular(RR.r6),
              ),
              child: value
                  ? const RefSvg('assets/svg/ic_checksm.svg',
                      size: 13, color: RC.white)
                  : null,
            ),
          ),
          const SizedBox(width: 11), // gap:11px
          Expanded(
            child: RichText(
              text: TextSpan(
                style: refText(
                    size: RF.s135,
                    weight: RF.w400,
                    color: RC.textDark,
                    height: RF.lh145),
                children: [
                  for (final p in parts)
                    TextSpan(
                      text: p.text,
                      style: p.onTap == null
                          ? null
                          : refText(
                              size: RF.s135,
                              weight: RF.w600,
                              color: RC.blue,
                              height: RF.lh145),
                      recognizer: (p.onTap == null || !enabled)
                          ? null
                          : (TapGestureRecognizer()..onTap = p.onTap),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}


/// ÇOKLU SEÇİM SAYFASI — `rgMulti()` karşılığı
///
/// Referans yapı:
/// ```
///   Başlık                                    [X]
///   [ Ara... ]
///   Seçenek 1                                 [✓]
///   Seçenek 2                                 [ ]
///   ...
///   [           TAMAM           ]   ← sabit alt
/// ```
///
/// ⚠ Seçenekler ANA FORMA chip olarak dökülmez; seçim yalnız bu
/// sayfada yapılır ve ana formda tek satır özet gösterilir.
///
/// [tumuEtiketi] verilirse listenin başına "hepsini seç" satırı
/// eklenir (ör. "Tüm İlçeler").
class RefMultiSelectSheet extends StatefulWidget {
  const RefMultiSelectSheet({
    super.key,
    required this.title,
    required this.options,
    required this.initial,
    this.tumuEtiketi,
    this.tekSecim = false,
    this.maxSecim,
    this.maxUyari,
  });

  final String title;
  final List<String> options;
  final Set<String> initial;
  final String? tumuEtiketi;

  /// EN FAZLA kaç seçenek işaretlenebilir (`null` → sınırsız).
  ///
  /// ⚠ SINIR SEÇİM ANINDA UYGULANIR. Önceden kullanıcı istediği kadar
  /// işaretleyip "Tamam"a basıyor, ancak o zaman reddediliyordu —
  /// yaptığı işin tamamı boşa gidiyordu. Artık sınıra ulaşıldığında
  /// yeni işaret KABUL EDİLMEZ ve kısa bir uyarı görünür.
  final int? maxSecim;

  /// Sınıra ulaşıldığında gösterilecek uyarı metni.
  final String? maxUyari;

  /// TEK SEÇİM kipi: yalnız bir seçenek işaretli kalabilir.
  ///
  /// Hizmet ili gibi tekil alanlarda kullanılır. Açıkken "tümünü seç"
  /// satırı anlamsızdır ve gösterilmez.
  final bool tekSecim;

  @override
  State<RefMultiSelectSheet> createState() => _RefMultiSelectSheetState();
}

class _RefMultiSelectSheetState extends State<RefMultiSelectSheet> {
  late final Set<String> _secili = {...widget.initial};
  final _ara = TextEditingController();

  /// Sınır uyarısı görünür mü? — 2 saniye sonra kendiliğinden kaybolur.
  ///
  /// ⚠ Uyarı KALICI BİR METİN DEĞİLDİR. Ekranda sürekli duran bir
  /// bilgilendirme kutusu, kuralı ihlal etmeyen kullanıcıya da yer
  /// kaplar. Yalnız sınıra çarpıldığı anda görünür.
  bool _uyari = false;
  Timer? _uyariZaman;

  void _uyariGoster() {
    _uyariZaman?.cancel();
    setState(() => _uyari = true);
    _uyariZaman = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _uyari = false);
      }
    });
  }

  @override
  void dispose() {
    _uyariZaman?.cancel();
    _ara.dispose();
    super.dispose();
  }

  /// Arama YALNIZ görünümü filtreler; seçim durumu korunur.
  List<String> get _gorunen {
    // ⚠ Türkçe duyarsız: "cigli" → "Çiğli", "ÇİĞLİ" → "Çiğli".
    final q = turkceNormalize(_ara.text.trim());
    if (q.isEmpty) {
      return widget.options;
    }
    return widget.options
        .where((o) => turkceNormalize(o).contains(q))
        .toList();
  }

  bool get _tumuSecili =>
      widget.options.isNotEmpty && _secili.length == widget.options.length;

  void _tumunuDegistir() {
    setState(() {
      if (_tumuSecili) {
        _secili.clear();
      } else {
        _secili
          ..clear()
          ..addAll(widget.options);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final liste = _gorunen;
    // ⚠ PANEL EKRANIN TAMAMINI KAPLAMAZ.
    //
    // `showModalBottomSheet(isScrollControlled: true)` içeriğe göre
    // büyür; uzun listelerde panel neredeyse tam ekran oluyordu.
    // Kalan yüksekliğin en fazla %72'si kullanılır — arkadaki ekran
    // görünür kalır, panel bir "sayfa" gibi davranmaz.
    final klavye = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: klavye),
        child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height - klavye) * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık + kapat
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: refText(
                            size: RF.s18,
                            weight: RF.w700,
                            color: RC.text)),
                  ),
                  RefTap(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(RR.circle),
                    // ⚠ `ic_x.svg` KENDİ renklerini taşır (gri daire +
                    // beyaz çarpı). Renk verilirse tüm çizim tek renge
                    // boyanır ve DOLU DAİRE görünür — cihazdaki hata
                    // buydu. Bu yüzden renk GEÇİLMEZ.
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: RefSvg('assets/svg/ic_x.svg', size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // Arama
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: TextField(
                controller: _ara,
                onChanged: (_) => setState(() {}),
                style: refText(
                    size: RF.s145, weight: RF.w500, color: RC.text),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Ara...',
                  hintStyle: refText(
                      size: RF.s145,
                      weight: RF.w400,
                      color: RC.greyLight),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: RefSvg('assets/svg/ic_search.svg',
                        size: 20, color: RC.greyLight),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RR.r12),
                    borderSide: const BorderSide(color: RC.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RR.r12),
                    borderSide: const BorderSide(color: RC.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RR.r12),
                    borderSide: const BorderSide(color: RC.blue),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: RC.surface),

            // ⚠ GEÇİCİ UYARI — 2 saniye görünür, sonra kaybolur.
            if (_uyari && widget.maxUyari != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                color: const Color(0xFFFFF6E5),
                child: Row(
                  children: [
                    // ⚠ `ic_info.svg` KENDİ renklerini taşır; renk
                    // filtresi uygulanırsa tek renk lekeye dönüşür.
                    const RefSvg('assets/svg/ic_info.svg', size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.maxUyari!,
                        style: refText(
                            size: RF.s125,
                            weight: RF.w600,
                            color: const Color(0xFF8A5A0B),
                            height: RF.lh145),
                      ),
                    ),
                  ],
                ),
              ),

            // Liste
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  // "Tüm ..." satırı — aramada da görünür kalır.
                  // Tek seçim kipinde "tümünü seç" anlamsızdır.
                  if (!widget.tekSecim &&
                      widget.tumuEtiketi != null &&
                      (_ara.text.trim().isEmpty ||
                          turkceNormalize(widget.tumuEtiketi!)
                              .contains(turkceNormalize(_ara.text.trim()))))
                    RefCheckRow(
                      value: _tumuSecili,
                      label: widget.tumuEtiketi!,
                      onChanged: (_) => _tumunuDegistir(),
                    ),
                  for (final o in liste)
                    RefCheckRow(
                      value: _secili.contains(o),
                      label: o,
                      onChanged: (v) => setState(() {
                        // ⚠ TEK SEÇİM kipinde önceki seçim düşer:
                        // birden çok il aynı anda seçili olamaz.
                        if (widget.tekSecim) {
                          _secili
                            ..clear()
                            ..add(o);
                          return;
                        }
                        if (!v) {
                          _secili.remove(o);
                          return;
                        }
                        // ⚠ SINIR: işaret KABUL EDİLMEZ, uyarı çıkar.
                        final sinir = widget.maxSecim;
                        if (sinir != null && _secili.length >= sinir) {
                          _uyariGoster();
                          return;
                        }
                        _secili.add(o);
                      }),
                    ),
                  if (liste.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Sonuç bulunamadı',
                          textAlign: TextAlign.center,
                          style: refText(
                              size: RF.s14,
                              weight: RF.w500,
                              color: RC.textSoft)),
                    ),
                ],
              ),
            ),

            // Sabit TAMAM
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: RefWideButton(
                'TAMAM',
                onPressed: () => Navigator.of(context).pop(_secili),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// `.rs-body` — yarım ekran gövdesi (ikon + başlık + açıklama).
///
/// ```css
/// .rs-body{text-align:center;padding:6px 4px 2px}
/// .rs-ic{58x58;%50;#FDEBDA;margin:0 auto 12px}
/// .rs-t{16.5px/700;#16233D}
/// .rs-d{13px;#5B6472;1.5;margin-top:8px}
/// ```
///
/// Referansta Destek, Paylaş, Hesap Dondur, Hesap Sil ve "hizmet veren
/// profiliniz yok" panellerinin TAMAMI bu gövdeyi kullanır: ortalanmış
/// 58px daire ikon, başlık ve açıklama. Metinler ORTALIDIR.
class RefSheetBody extends StatelessWidget {
  const RefSheetBody({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    this.ikonZemin = const Color(0xFFFDEBDA),
    this.ikonBoyut = 26,
    this.altKisim,
  });

  final String ikon;
  final Color ikonZemin;
  final double ikonBoyut;
  final String baslik;
  final String aciklama;

  /// Düğmeler gibi gövdenin altına eklenecek içerik.
  final Widget? altKisim;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: ikonZemin, shape: BoxShape.circle),
              child: RefSvg(ikon, size: ikonBoyut),
            ),
            const SizedBox(height: 12), // .rs-ic{margin-bottom:12px}
            Text(baslik,
                textAlign: TextAlign.center,
                style:
                    refText(size: 16.5, weight: RF.w700, color: RC.text)),
            const SizedBox(height: 8), // .rs-d{margin-top:8px}
            Text(aciklama,
                textAlign: TextAlign.center,
                style: refText(
                    size: RF.s13,
                    weight: RF.w400,
                    color: RC.textSoft,
                    height: RF.lh150)),
            if (altKisim != null) ...[
              const SizedBox(height: 14),
              altKisim!,
            ],
          ],
        ),
      );
}

/// `.rs-body` içeren ONAY YARIM EKRANI — `freezeAsk` / `deleteAsk`.
///
/// ⚠ Referansta bu onaylar `AlertDialog` DEĞİL, YARIM EKRANDIR
/// (`rgOverlay`). Ana eylem düğmesi işlemin rengini taşır (dondurma
/// turuncu, silme kırmızı); altında düz "Vazgeç" bağlantısı bulunur.
///
/// `true` döner → kullanıcı onayladı. Kapatma/iptal `false` sayılır,
/// böylece çağıran taraf ek kontrol yapmadan güvenle kullanabilir.
Future<bool> refOnaySayfasi(
  BuildContext context, {
  required String title,
  required String ikon,
  required Color ikonZemin,
  required String baslik,
  required String aciklama,
  required String onayMetni,
  required Gradient onayGradyani,
}) async {
  final sonuc = await RefBottomSheet.goster<bool>(
    context,
    title: title,
    child: RefSheetBody(
      ikon: ikon,
      ikonZemin: ikonZemin,
      ikonBoyut: 30,
      baslik: baslik,
      aciklama: aciklama,
      altKisim: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // `.po-next` — işlemin rengini taşıyan ana düğme.
          ClipRRect(
            borderRadius: BorderRadius.circular(RR.r14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(true),
                child: Ink(
                  decoration: BoxDecoration(gradient: onayGradyani),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: Text(onayMetni,
                        style: refText(
                            size: RF.s16,
                            weight: RF.w700,
                            color: RC.white)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10), // `.po-homelink{margin-top:10px}`
          RefTap(
            onTap: () => Navigator.of(context).pop(false),
            borderRadius: BorderRadius.circular(RR.r8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Vazgeç',
                  style: refText(
                      size: RF.s145,
                      weight: RF.w600,
                      color: RC.textSoft)),
            ),
          ),
        ],
      ),
    ),
  );
  return sonuc ?? false;
}

/// "DİĞER" SEÇİLDİĞİNDE AÇILAN SERBEST AÇIKLAMA SAYFASI.
///
/// ⚠ NEDEN ZORUNLU
///
/// Listedeki hazır gerekçeler yönetime tek kelimeyle ulaşır; "Diğer"
/// tek başına gönderildiğinde YÖNETİM HİÇBİR ŞEY ÖĞRENMEZ. Bu yüzden
/// kullanıcıdan kısa bir açıklama istenir ve metin gerekçenin İÇİNDE
/// sunucuya taşınır.
///
/// Kullanıcıya bu metnin nereye gittiği AÇIKÇA söylenir — gizli veri
/// toplama yoktur.
///
/// Boş bırakılırsa gönderilemez; [enAz] karakterden kısa metin de
/// kabul edilmez (tek harflik "a" gibi girişler yönetime yaramaz).
/// Vazgeçilirse `null` döner ve işlem YAPILMAZ.
class RefSerbestNedenSayfasi extends StatefulWidget {
  const RefSerbestNedenSayfasi({
    super.key,
    required this.baslik,
    required this.aciklama,
    required this.ipucu,
    this.enAz = 10,
    this.enFazla = 300,
  });

  final String baslik;
  final String aciklama;
  final String ipucu;
  final int enAz;
  final int enFazla;

  @override
  State<RefSerbestNedenSayfasi> createState() =>
      _RefSerbestNedenSayfasiState();
}

class _RefSerbestNedenSayfasiState extends State<RefSerbestNedenSayfasi> {
  final _ctl = TextEditingController();
  final _odak = FocusNode();
  bool _dokunuldu = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _odak.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _odak.dispose();
    super.dispose();
  }

  String get _metin => _ctl.text.trim();
  bool get _gecerli => _metin.length >= widget.enAz;

  @override
  Widget build(BuildContext context) {
    final hata = _dokunuldu && !_gecerli
        ? 'Lütfen en az ${widget.enAz} karakter yazın'
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.aciklama,
            style: refText(
                size: RF.s135,
                weight: RF.w400,
                color: RC.textSoft,
                height: RF.lh150)),
        const SizedBox(height: 12),
        Stack(
          children: [
            RefTextField(
              controller: _ctl,
              focusNode: _odak,
              maxLines: 4,
              maxLength: widget.enFazla,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              onChanged: (_) => setState(() => _dokunuldu = true),
              hint: widget.ipucu,
              hatali: hata != null,
            ),
            Positioned(
              right: 13,
              bottom: 10,
              child: Text('${_metin.characters.length}/${widget.enFazla}',
                  style: refText(
                      size: RF.s12, weight: RF.w400, color: RC.grey)),
            ),
          ],
        ),
        if (hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(hata,
                style: refText(
                    size: RF.s125, weight: RF.w600, color: RC.danger)),
          ),
        const SizedBox(height: 14),
        RefPrimaryButton(
          'Gönder',
          onPressed: _gecerli
              ? () => Navigator.of(context).pop(_metin)
              : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// ŞİFRE GÖZÜ ÖLÇÜ STANDARDI — TÜM UYGULAMADA AYNI.
///
/// ⚠ EKRANLAR BU DEĞERLERİ EZMEZ. Göz ikonu bazı ekranlarda küçük
/// görünüyordu; ölçü ekran ekran ayarlanırsa yeniden ayrışır.
/// ⚠ ALAN İÇ YÜKSEKLİĞİ — suffix'li ve suffix'siz alanlar AYNI.
///
/// `RefFormField` kutusu 14 dp dikey dolgu + tek satır metin
/// yüksekliğinde. Suffix (göz ikonu) bu değere sabitlenir ki şifre
/// alanı telefon/e-posta alanlarından uzun görünmesin.
const double kRefAlanIcYukseklik = 22;

const double kSifreGozuIkon = 24;

/// Erişilebilirlik alt sınırı — parmak hedefi 48×48'ten küçük olamaz.
const double kSifreGozuDokunma = 48;

/// ŞİFRE GÖZÜ — BASILI TUTARAK GÖSTER
///
/// ⚠ DAVRANIŞ KURALI
///
/// Şifre normalde MASKELİDİR. Göze BASILI TUTULDUĞU SÜRECE açık
/// görünür, parmak kaldırıldığı an yeniden maskelenir. "Bir bas aç,
/// bir daha bas kapat" davranışı YOKTUR.
///
/// Neden: açık kalan şifre ekranda unutulabiliyor; kullanıcı alanı
/// doğrulamak için bir saniye bakar, sonra ekran korumasız kalır.
/// Basılı tutma, şifrenin ekranda kaldığı süreyi kullanıcının
/// parmağıyla sınırlar.
///
/// ⚠ `Listener` kullanılır, `GestureDetector` DEĞİL: parmak düğmenin
/// dışına kayarsa `onTapUp` hiç tetiklenmez ve şifre AÇIK KALIRDI.
/// `onPointerUp` ve `onPointerCancel` her koşulda gelir.
/// ARAMA TEMİZLEME DÜĞMESİ — tüm arama çubuklarında ORTAK.
///
/// ── ⚠ NİÇİN ORTAK ──
///
/// Aynı davranış beş ekranda ayrı ayrı yazılırsa biri güncellenip
/// öteki unutulur. Tek bileşen: X ikonu, ölçüsü ve dokunma alanı her
/// arama çubuğunda AYNI.
///
/// ⚠ YALNIZCA METİN VARKEN ÇİZİLİR — çağıran taraf koşulu kendisi
/// yazmaz, bileşen `controller`'a bakar.
///
/// ⚠ `ic_close` KULLANILIR, `ic_x` DEĞİL: `ic_x` çift renklidir
/// (gri daire + beyaz çarpı) ve boyandığında düz bir noktaya
/// dönüşür. `ic_close` tek renkli çizgi çarpıdır.
class RefAramaTemizle extends StatelessWidget {
  const RefAramaTemizle({
    super.key,
    required this.controller,
    required this.onTemizle,
    this.boyut = 18,
  });

  final TextEditingController controller;

  /// ⚠ Metni silmek YETMEZ: çağıran taraf ayrıca açık öneri panelini
  /// kapatmalı ve arama durumunu sıfırlamalıdır. Bu yüzden temizleme
  /// işi bileşene GÖMÜLMEDİ, çağırana bırakıldı.
  final VoidCallback onTemizle;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    // ⚠ Metin değişince yeniden çizilmeli; çağıranın `setState`ine
    // bağlı kalmaz.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, deger, __) {
        if (deger.text.isEmpty) {
          return const SizedBox.shrink();
        }
        return RefTap(
          onTap: onTemizle,
          borderRadius: BorderRadius.circular(RR.circle),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: RefSvg('assets/svg/ic_close.svg',
                size: boyut, color: RC.textSoft),
          ),
        );
      },
    );
  }
}

class RefSifreGozu extends StatelessWidget {
  const RefSifreGozu({
    super.key,
    required this.gizli,
    required this.onDegisti,
    this.boyut = kSifreGozuIkon,
    this.renk = const Color(0xFF8A94A6),
  });

  /// Şifre şu an maskeli mi?
  final bool gizli;

  /// `true` → maskele, `false` → göster.
  final ValueChanged<bool> onDegisti;

  final double boyut;
  final Color renk;

  @override
  Widget build(BuildContext context) => GestureDetector(
        // ── ⚠ JEST ARENASI: METİN MENÜSÜ AÇILMASIN ──
        //
        // `Listener` ham işaretçi olaylarını dinler ama jest
        // ARENASINA GİRMEZ. Bu yüzden ikona basılı tutulduğunda
        // altındaki `TextField` uzun basışı kendi tanıyıcısıyla
        // yakalıyor ve "Paste / Select all" seçim menüsünü açıyordu —
        // kullanıcı şifreyi görmeye çalışırken ekranda yapıştırma
        // menüsü beliriyordu.
        //
        // Boş `onLongPress` ve `onTap` işleyicileri jesti BU
        // BİLEŞENE kazandırır; alanın tanıyıcısı arenayı kaybeder ve
        // menü açılmaz. İşleyiciler kasıtlı olarak boştur: asıl iş
        // aşağıdaki `Listener`'da, ham basma/bırakma olaylarında
        // yapılır (arena kararı ham olayları engellemez).
        behavior: HitTestBehavior.opaque,
        onLongPress: () {},
        onTap: () {},
        child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDegisti(false),
        onPointerUp: (_) => onDegisti(true),
        onPointerCancel: (_) => onDegisti(true),
        child: Semantics(
          button: true,
          label: 'Şifreyi görmek için basılı tutun',
          // ⚠ DOKUNMA ALANI EN AZ 48×48.
          //
          // Eskiden 20px ikon + 10px dolgu = 40×40 idi; hem ikon küçük
          // görünüyor hem de dokunma alanı erişilebilirlik alt
          // sınırının altında kalıyordu. Ölçü BİLEŞENDE sabitlendi:
          // ekranlar tek tek değer vermez, hepsi aynı olur.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kSifreGozuDokunma,
              minHeight: kSifreGozuDokunma,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.all(
                    (kSifreGozuDokunma - kSifreGozuIkon) / 2),
                child: RefSvg(
                  gizli
                      ? 'assets/svg/ic_eyeoff.svg'
                      : 'assets/svg/ic_eye.svg',
                  size: boyut,
                  color: renk,
                ),
              ),
            ),
          ),
        ),
        ),
      );
}

/// SIRALA / FİLTRELER PANELİNDEKİ TEK SEÇENEK KARTI.
///
/// ⚠ ORTAK BİLEŞEN. Hem hizmet alan (İlanlarım) hem hizmet veren
/// (İşlerim) tarafı bunu kullanır; iki ekranın seçim panelleri
/// ayrışamaz.
class RefSecimKarti extends StatelessWidget {
  const RefSecimKarti({
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.secili,
    required this.onTap,
  });

  final String ikon;
  final String baslik;
  final String aciklama;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.r14),
        child: Container(
          // ⚠ KOMPAKT ÖLÇÜLER.
          //
          // Panel ekranın yarısını kaplıyordu. Yükseklik sınırı tek
          // başına yetmedi: asıl neden KARTLARIN büyüklüğüydü. Dolgu,
          // rozet ve punto küçültüldü — dört seçenek artık ekranın
          // çok daha az yerini tutar, okunaklılık korunur.
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: secili ? RC.blueSoft : RC.white,
            border: Border.all(
              color: secili ? RC.blue : const Color(0xFFE7EAEF),
              width: secili ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(RR.r14),
          ),
          child: Row(
            children: [
              // İkon rozeti
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: secili ? RC.blue : const Color(0xFFF2F4F7),
                  shape: BoxShape.circle,
                ),
                child: RefSvg(ikon,
                    size: 16, color: secili ? RC.white : RC.textSoft),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(baslik,
                        style: refText(
                            size: RF.s135,
                            weight: RF.w700,
                            color: secili ? RC.blue : RC.text)),
                    const SizedBox(height: 2),
                    Text(aciklama,
                        style: refText(
                            size: RF.s12,
                            weight: RF.w400,
                            color: RC.textSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ⚠ `✓` METNİ DEĞİL, gerçek seçim dairesi.
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: secili ? RC.blue : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: secili ? RC.blue : const Color(0xFFC7CEDA),
                    width: 2,
                  ),
                ),
                child: secili
                    ? const RefSvg('assets/svg/ic_checksm.svg',
                        size: 12, color: RC.white)
                    : null,
              ),
            ],
          ),
        ),
      );
}

/// `.mr-av` — 44px baş harf rozeti.
///
/// ⚠ ORTAK BİLEŞEN: hem hizmet veren (aldığı yorumlar) hem hizmet
/// alan (verdiği yorumlar) ekranı kullanır.
///
/// ```css
/// .mr-av{44x44;%50;19px/700}
/// ```
/// Referansta her yoruma sabit bir renk çifti verilir; burada ad
/// üzerinden DETERMİNİSTİK seçilir — aynı kişi her açılışta aynı
/// rengi alır, rastgelelik yoktur.
class RefBasHarfAvatar extends StatelessWidget {
  const RefBasHarfAvatar({
    required this.ad,
    this.fotoYolu = '',
    this.cap = 44,
    super.key,
  });

  final String ad;

  /// ── ⚠ KARŞI TARAFIN PROFİL FOTOĞRAFI (12 Eyl, kullanıcı bulgusu) ──
  ///
  /// BULGU: "Kullanıcılar birbirlerinin profil fotoğraflarını yüklemiş
  /// olsalar bile göremiyorlar; şu anda sadece kendi fotoğraflarını
  /// kendileri görebiliyor."
  ///
  /// KÖK NEDEN: bu bileşen YALNIZ baş harf çiziyordu. Fotoğrafı olan
  /// tek yer profil ekranıydı (`_Avatar`) ve o dosyaya özeldi. Yani
  /// karşı tarafın fotoğrafı hiçbir ekranda çizilmiyordu — veri
  /// vardı, gösterim yoktu.
  ///
  /// ⚠ BOŞSA VEYA DOSYA YOKSA BAŞ HARFE DÜŞER: eski davranış aynen
  /// korunur, hiçbir çağıran bozulmaz.
  ///
  /// ⚠ GÖSTERİM KURALI ÇAĞIRANDA: kimliğin açık olup olmadığına
  /// (iletişim açıldı mı, teklif verildi mi) bu bileşen karar VERMEZ.
  /// Maskeliyken çağıran zaten boş yol geçirir.
  final String fotoYolu;

  /// Dairenin çapı. Harf boyutu çapa oranla ölçeklenir.
  final double cap;

  static const _paletler = <(Color, Color)>[
    (Color(0xFFEAF1FB), Color(0xFF1D6BE3)),
    (Color(0xFFE9F9EF), Color(0xFF16A34A)),
    (Color(0xFFFDF4E8), Color(0xFFF5820C)),
    (Color(0xFFF3EAFB), Color(0xFF7C3AED)),
    (Color(0xFFFDEAEA), Color(0xFFE5452C)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ad.trim();
    final harf = t.isEmpty ? '?' : t[0].toUpperCase();
    final (zemin, yazi) = _paletler[t.hashCode.abs() % _paletler.length];

    final basHarf = Container(
      width: cap,
      height: cap,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: zemin, shape: BoxShape.circle),
      child: Text(harf,
          style: refText(
              size: cap * 19 / 44, weight: RF.w700, color: yazi)),
    );

    final yol = fotoYolu.trim();
    if (yol.isEmpty) {
      return basHarf;
    }
    // ⚠ DOSYA OKUNAMAZSA ÇÖKMEZ, BAŞ HARFE DÜŞER: yol eski bir
    // önbellekten gelmiş ya da kullanıcı dosyayı silmiş olabilir.
    return ClipOval(
      child: SizedBox(
        width: cap,
        height: cap,
        child: Image.file(
          File(yol),
          width: cap,
          height: cap,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => basHarf,
        ),
      ),
    );
  }
}

/// KÜÇÜK ROL ETİKETİ — "Hizmet Alan" / "Hizmet Veren".
///
/// ⚠ ORTAK BİLEŞEN. Hem İşlerim ekranının üstünde hem Profil
/// başlığında kullanılır; iki yerde farklı görünemez.
///
/// ⚠ Büyük başlık yerine geçer. İki rollü hesaplarda en sık karışan
/// bilgi "şu an hangi roldeyim" sorusudur; etiket bunu sürekli
class RefRolEtiketi extends StatelessWidget {
  const RefRolEtiketi({required this.saglayici});

  final bool saglayici;

  @override
  Widget build(BuildContext context) => Container(
        // ⚠ KÜÇÜK AMA OKUNAKLI. Rozet bir başlık değildir; ekranın
        // üstünde yer kaplamadan durumu bildirir.
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: BoxDecoration(
          color: saglayici ? const Color(0xFFEAF1FB) : RC.successSoft,
          borderRadius: BorderRadius.circular(RR.circle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RefSvg(
              saglayici
                  ? 'assets/svg/ic_wrenchp.svg'
                  : 'assets/svg/ic_pshield.svg',
              size: 13,
              color: saglayici ? RC.blue : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 6),
            Text(
              saglayici ? 'Hizmet Veren' : 'Hizmet Alan',
              style: refText(
                size: RF.s12,
                weight: RF.w700,
                color: saglayici ? RC.blue : const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      );
}

/// ── ⚠ İKİ SEÇENEKLİ, AŞAĞI AÇILIR SEÇİCİ ──
///
/// Referans: "arama çubuklarındaki gibi" — `find_provider_screen.
/// dart`daki `_HizmetAramaAlani`nin öneri panelinde olduğu gibi,
/// kutunun İÇİNDE (bottom sheet DEĞİL) aşağı doğru AÇILAN bir panel.
///
/// ⚠ MODELDEN BAĞIMSIZ TUTULDU: `ref_widgets.dart` hiçbir veri
/// modelini import ETMEZ (proje genelindeki kural) — bu yüzden
/// `IletisimTercihi` gibi belirli bir enume BAĞLANMADI; iki
/// seçeneği başlık/açıklama metni olarak alır, hangi enum değerine
/// karşılık geldiğine ÇAĞIRAN karar verir. Hem "Doğrudan Teklif
/// İste" hem normal "İlan Ver" akışı AYNI widget'ı kullanır — iki
/// ayrı seçici İCAT EDİLMEDİ.
class RefAcilirSecici extends StatefulWidget {
  const RefAcilirSecici({
    super.key,
    required this.ilkSeciliMi,
    required this.ilkBaslik,
    required this.ilkAciklama,
    required this.ikinciBaslik,
    required this.ikinciAciklama,
    required this.onSec,
  });

  /// `true` → ilk seçenek şu an seçili; `false` → ikinci.
  final bool ilkSeciliMi;
  final String ilkBaslik;
  final String ilkAciklama;
  final String ikinciBaslik;
  final String ikinciAciklama;

  /// Kullanıcı DİĞER seçeneğe dokununca çağrılır — `true` verirse
  /// ilk seçenek artık seçili demektir.
  final ValueChanged<bool> onSec;

  @override
  State<RefAcilirSecici> createState() => _RefAcilirSeciciState();
}

class _RefAcilirSeciciState extends State<RefAcilirSecici> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final baslik = widget.ilkSeciliMi ? widget.ilkBaslik : widget.ikinciBaslik;
    final aciklama =
        widget.ilkSeciliMi ? widget.ilkAciklama : widget.ikinciAciklama;
    final digerBaslik =
        widget.ilkSeciliMi ? widget.ikinciBaslik : widget.ilkBaslik;
    final digerAciklama =
        widget.ilkSeciliMi ? widget.ikinciAciklama : widget.ilkAciklama;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefTap(
          onTap: () => setState(() => _acik = !_acik),
          borderRadius: BorderRadius.circular(RR.r13),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: RC.blueSoft,
              border: Border.all(color: RC.blue),
              borderRadius: BorderRadius.circular(RR.r13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(baslik,
                          style: refText(
                              size: RF.s135,
                              weight: RF.w700,
                              color: RC.text)),
                      const SizedBox(height: 2),
                      Text(aciklama,
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: RC.textSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ⚠ Açık/kapalı — ok yönü döner, YENİ bir ikon
                // İCAT EDİLMEDİ.
                AnimatedRotation(
                  turns: _acik ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const RefSvg('assets/svg/ic_chevd.svg',
                      size: 18, color: RC.blue),
                ),
              ],
            ),
          ),
        ),
        // ⚠ AŞAĞI DOĞRU BÜYÜYEN PANEL — bottom sheet DEĞİL, kutunun
        // hemen altında INLINE. `AnimatedSize` yumuşak açılış verir.
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: !_acik
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RefTap(
                    onTap: () {
                      widget.onSec(!widget.ilkSeciliMi);
                      setState(() => _acik = false);
                    },
                    borderRadius: BorderRadius.circular(RR.r13),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: RC.white,
                        border:
                            Border.all(color: const Color(0xFFECEEF2)),
                        borderRadius: BorderRadius.circular(RR.r13),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(digerBaslik,
                              style: refText(
                                  size: RF.s135,
                                  weight: RF.w700,
                                  color: RC.text)),
                          const SizedBox(height: 2),
                          Text(digerAciklama,
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w400,
                                  color: RC.textSoft)),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
