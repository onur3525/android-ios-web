import 'dart:async';
import 'package:flutter/material.dart';
// `context.read<T>()` bu paketin BuildContext eklentisidir.
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../domain/cikar_catismasi.dart';
import '../data/models/account.dart';
import '../data/controllers/auth_controller.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'role_select_screen.dart';
import 'widgets/inline_search_box.dart';
import 'create_listing_screen.dart';
import 'prelogin_listing_route.dart';
import '../data/hizmet_alanlari.dart';
import 'hizmet_alani_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// ANA SAYFA — referans `vHome()` karşılığı
///
/// Kaynak: `hizmetcep-uygulama-son-kod.html`
///
/// ```
/// <div class="scroll">
///   <div class="home">
///     <div class="hd"> LOGO(42) WORDMARK(23) ... IC_PROFILE </div>
///     <div class="slogan">Güvenilir profesyoneller, anında hizmet</div>
///     <button class="search"> ... </button>
///     <div class="rc rc-b"> ART_HOUSE · sq-b · h2 · p · rcbtn · tags </div>
///     <div class="rc rc-o"> ART_TOOLS · sq-o · h2 · p · rcbtn · tags </div>
///     <div class="card"> shield · h3 · desc · 7 kategori </div>
///     <div class="card trust"> 3 güven özelliği </div>
///     <div class="promo"> h4 · p · ART_PHONE </div>
///   </div>
/// </div>
/// ```
///
/// CSS:
///   .home   { padding: 0 15px 24px }
///   .hd     { display:flex; justify-content:space-between; padding-top:29px }
///   .hd-l   { display:flex; align-items:center; gap:4px }
///   .slogan { 15px/700 #16233D; margin-top:9px; letter-spacing:-.2px }
///
/// ⚠ Material ikon KULLANILMAZ — referans SVG'leri `flutter_svg` ile.
/// ═══════════════════════════════════════════════════════════════

/// HIZLI ERİŞİM KATEGORİLERİ — 12 kart, 2 satır × 6 sütun.
///
/// ⚠ BU LİSTE KATALOG SINIRI DEĞİLDİR.
///
/// Katalogda 54 ana kategori vardır; ana ekran sade kalsın diye
/// yalnız 12'si burada gösterilir. Kalanına kullanıcı ARAMA ve
/// TÜM KATEGORİLER ekranından ulaşır.
///
/// ⚠ SEÇİM KATALOĞUN GENİŞLİĞİNİ GÖSTERİR.
///
/// Liste yalnız ev/tadilat hizmetlerinden oluşsaydı kullanıcı
/// uygulamayı bir "usta bulma" aracı sanır, otomotiv · eğitim ·
/// yazılım · güzellik · organizasyon alanlarının varlığını hiç
/// fark etmezdi. Bu yüzden her alandan en az bir kategori var.
///
/// ⚠ ANA EKRANDAN ÇIKARILANLAR SİLİNMEDİ: `İlaçlama`, `Doğalgaz`,
/// `Kombi`, `Boya`, `Mobilya` katalogda duruyor ve Tüm Kategoriler
/// ile aramadan erişilebilir.
///
/// ⚠ `label` alanı KATALOGDAKİ ANA KATEGORİ ADIYLA BİREBİR aynı
/// olmalıdır; `_hizmetSecildi` bu adla kategori arar. Eşleşmezse kart
/// boş sonuç açar. Test bunu denetler.
/// HIZLI ERİŞİM KATEGORİLERİ — 12 kart, sade ikon.
///
/// ⚠ FOTOĞRAF KULLANILMAZ.
///
/// Bir tur denendi: ana sayfa kataloğun tamamını (53 kart) ilan
/// ekranıyla aynı fotoğraflı kartlarla gösteriyordu. Sonuç kötüydü —
/// sayfa 18 satır kaydırma uzunluğuna çıkıyor, 33 fotoğraf ile 20
/// çizim ikon yan yana düşüp görsel bütünlük bozuluyordu.
///
/// Ana sayfa bir VİTRİNDİR, katalog değil: sade, tek renk, hızlı
/// taranan ikonlar. Katalogun tamamına "Tüm Kategoriler" ve arama
/// üzerinden ulaşılır.
///
/// ⚠ BU LİSTE KATALOG SINIRI DEĞİLDİR — 53 kategorinin hepsi
/// erişilebilir kalır.
///



/// `.trust` — `grid-template-columns: repeat(3,1fr)`
const List<({String asset, Color? color, String title, String desc})> _kTrust = [
  (
    asset: 'assets/svg/ic_shield.svg',
    color: RC.blue,
    title: 'Güvenli Hizmet Alımı',
    desc: 'Gerçek kullanıcı yorumları ve puanlamalarla doğru profesyoneli seçin.',
  ),
  (
    asset: 'assets/svg/ic_star_g.svg',
    color: null, // SVG kendi rengini taşır
    title: 'Memnun Kullanıcı Deneyimi',
    desc: 'Binlerce memnun kullanıcı deneyimiyle hizmet kalitesini güvence altına alın.',
  ),
  (
    asset: 'assets/svg/ic_bolt_o.svg',
    color: null,
    title: 'Hızlı Teklif Sistemi',
    desc: 'İlanınızı yayınlayın, dakikalar içinde teklifler gelsin.',
  ),
];

/// ARAMA/KATEGORİ SEÇİMİ — DOSYA SEVİYESİ
///
/// ⚠ Hem `HomeScreen` hem `_CategoryItem` bu yönlendiriciyi
/// kullanır. Sınıf metodu olarak kalırsa `_CategoryItem`
/// erişemez (`undefined_method`).

/// ARAMA ÖNERİSİNDEN HİZMET SEÇİLDİ
///
/// ⚠ `category_screen` ile AYNI rol sözleşmesi:
///   • müşteri rolü VAR   → korumalı ilan formu
///   • yalnız sağlayıcı   → public taslak formu
///   • oturum YOK         → public taslak formu
/// Rol seçim ekranı ("Nasıl Başlamak İstersiniz?") AÇILMAZ.
/// DIŞARIDAN ÇAĞRI — Tüm Kategoriler ekranı için.
///
/// ⚠ Aynı akış paylaşılır. Tüm Kategoriler ekranı kendi seçim mantığını
/// kurmuş olsaydı iki yerde iki farklı davranış doğar, biri düzeltilip
/// öteki unutulurdu.
void hizmetSecildiDisaridan(
        BuildContext context, String kategori, String? altHizmet) =>
    _hizmetSecildi(context, kategori, altHizmet);

void _hizmetSecildi(
    BuildContext context, String kategori, String? altHizmet) {
  final auth = context.read<AuthController>();

  // ── ⚠ ÇIKAR ÇATIŞMASI: EN ERKEN NOKTA ──
  //
  // Hizmet verenin KENDİ alanında ilan açması yasaktır. Bu yol
  // (ana sayfa hızlı erişim · arama önerisi · Tüm Kategoriler) ilan
  // formunu doğrudan SEÇİLİ kategoriyle açar; kural burada
  // uygulanmazsa kullanıcı formu açar, doldurur ve ancak yayınlarken
  // reddedilirdi.
  //
  // Kural TEK KAYNAKTAN gelir: `lib/domain/cikar_catismasi.dart`.
  final me = auth.currentAccount;
  if (me != null) {
    final catisan = catisanKategori(
        saglayiciSecimleri: me.categories,
        ilanBasligi: altHizmet ?? kategori);
    if (catisan != null) {
      sysToastErr(context, SysKind.genericError,
          extra: catismaMesaji(catisan));
      return;
    }
  }

  void publicForma() => Navigator.pushNamed(
        context,
        PreLoginListingRoute.name,
        arguments: PreLoginListingArgs(
            category: kategori, subService: altHizmet),
      );

  if (!auth.loggedIn) {
    publicForma();
    return;
  }

  final acc = auth.currentAccount;
  if (acc?.roles.contains(Role.customer) ?? false) {
    if (auth.activeRole != Role.customer) {
      unawaited(auth.switchRole(Role.customer));
    }
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CreateListingScreen(
                  initialCategory: kategori,
                  initialSubService: altHizmet,
                )));
    return;
  }

  publicForma();
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // body{background:#FFFFFF} · .page{background:#fff}
      backgroundColor: RC.pageBg,
      // ── SAFE AREA: GÖRSEL KABUL BEKLİYOR ──
      //
      // Referans bulgusu (koddan doğrulandı):
      //   `.page{position:absolute;inset:0}` → safe-area katmanı YOK
      //   `.hd{padding-top:29px}`            → DÜZ değer, calc() YOK
      //   Diğer ekranlar `calc(Npx + env(safe-area-inset-top))` kullanır.
      //   CSS yorumu: "Referans 853×1844px" → 29px viewport üstünden.
      //
      // ⚠ SORUN: Referans tarayıcıda durum çubuğu yoktur. Gerçek cihazda
      // 29px'i olduğu gibi uygulamak içeriği çentiğin ALTINA sokar.
      //
      // ⚠ Bu yüzden burada kullanılan değer BİREBİR REFERANS DEĞİLDİR.
      // Geçici formül `max(29, safeTop)` uygulanır (aşağıda `_Header`).
      // Kesin değer, APK gerçek cihazda referans HTML ile yan yana
      // karşılaştırıldıktan sonra belirlenecektir.
      // ── ⚠ ÜST GÜVENLİ ALAN AÇIK ──
      //
      // `top: false` iken kaydırma alanı durum çubuğunun ALTINDAN
      // başlıyordu: sayfa kaydırılınca turuncu rol kartı saatin ve
      // pil göstergesinin üstüne biniyordu.
      //
      // ⚠ Sabit bir yükseklik VARSAYILMAZ; `SafeArea` cihazın gerçek
      // `MediaQuery` değerini uygular (çentik, delik, kavisli köşe).
      // `_Header` içindeki `max(29, safeTop)` formülü de korunuyor:
      // güvenli alan burada tüketildiği için orada `safeTop` sıfıra
      // düşer ve referanstaki 29 birim geçerli olur.
      body: SafeArea(
        bottom: false,
        // .scroll{flex:1;overflow-y:auto;scrollbar-width:none}
        child: RefScroll(
          // .home{padding:0 15px 24px}
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 9), // .slogan{margin-top:9px}
              _slogan(),
              const SizedBox(height: 12), // .search{margin-top:12px}
              // ⚠ AYRI SAYFAYA YÖNLENDİRME YOK.
              //
              // Kutuya dokunulunca YERİNDE yazılabilir hale gelir ve
              // eşleşmeler aşağı doğru açılan listede gösterilir.
              // Öneriler `SearchService` üzerinden `kHomeCategories` +
              // `kSubServices`'ten gelir; admin yeni kategori eklerse
              // liste kendiliğinden genişler.
              InlineSearchBox(
                title: 'Hangi hizmete ihtiyacınız var?',
                subtitle:
                    'Örnek: Kombi Bakımı, Elektrik Arızası, Boya Badana, Klima Montajı',
                onSecim: (kategori, altHizmet) =>
                    _hizmetSecildi(context, kategori, altHizmet),
              ),

              // ── Rol kartları ──
              // Referansta bu kartlar oturumdan bağımsız GÖRÜNÜR.
              // Girişli kullanıcıda dokunuş kayıt yerine ilgili akışa gider.
              const SizedBox(height: 17), // .rc{margin-top:17px}
              _RoleCard(
                // .rc-b{background:#E7F0FD}
                background: const Color(0xFFE7F0FD),
                art: 'assets/art/art_house.png',
                squareGradient: RG.blueSquare,
                squareShadow: RS.blueSquare,
                squareIcon: 'assets/svg/ic_home_w.svg',
                title: 'Hizmet\nAlmak İstiyorum',
                // .rc-b h2{color:#0F2E6B}
                titleColor: const Color(0xFF0F2E6B),
                desc: 'Ücretsiz hesap oluşturun,\nilanınızı yayınlayın ve\nteklif alın.',
                ctaIcon: 'assets/svg/ic_person.svg',
                ctaIconColor: RC.blue,
                ctaLabel: 'Hizmet Alan Olarak Başla',
                tags: 'Ücretsiz kayıt  •  Ücretsiz ilan',
                // .rc-b .tags{color:#1D6BE3}
                tagsColor: RC.blue,
                onTap: () => _openCustomer(context),
              ),
              const SizedBox(height: 17),
              _RoleCard(
                // .rc-o{background:#FCEDE0}
                background: const Color(0xFFFCEDE0),
                art: 'assets/art/art_tools.png',
                squareGradient: RG.orangeSquare,
                squareShadow: RS.orangeSquare,
                squareIcon: 'assets/svg/ic_worker_w.svg',
                title: 'Hizmet\nVermek İstiyorum',
                // .rc-o h2{color:#6B3A0A}
                titleColor: const Color(0xFF6B3A0A),
                desc: 'Hesap oluşturun, iş ilanlarını\ngörüntüleyin ve yeni\nişler kazanın.',
                ctaIcon: 'assets/svg/ic_person.svg',
                ctaIconColor: const Color(0xFFF5820C),
                ctaLabel: 'Hizmet Veren Olarak Başla',
                tags: 'Hızlı kayıt  •  Yeni işler  •  Kazanç',
                // .rc-o .tags{color:#F5820C}
                tagsColor: const Color(0xFFF5820C),
                onTap: () => _openProvider(context),
              ),

              // ── Neler bulabilirsiniz + 7 kategori ──
              const SizedBox(height: 16), // .card{margin-top:16px}
              const _CategoryCard(),

              // ── Güven kartı (3 özellik) ──
              const SizedBox(height: 16),
              const _TrustCard(),

              // ── Promosyon kartı ──
              const SizedBox(height: 16), // .promo{margin-top:16px}
              const _PromoCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// `.slogan{font-size:15px;font-weight:700;color:#16233D;
  ///   margin-top:9px;letter-spacing:-.2px}`
  Widget _slogan() => Text(
        'Güvenilir profesyoneller, anında hizmet',
        style: refText(
          size: RF.s15,
          weight: RF.w700,
          color: RC.text,
          letterSpacing: RF.lsM02,
        ),
      );

  /// Referans: `data-act="register" data-arg="customer"`
  ///
  /// ⚠ KOŞULSUZ kayıt akışı. HTML işleyicisi:
  /// ```js
  /// if (a === 'register') openRegister(g);   // g = 'customer'
  /// ```
  /// Oturum durumuna bakılmaz; referansta `loggedIn` kontrolü YOKTUR.
  void _openCustomer(BuildContext context) =>
      RoleSelectScreen.startRegister(context, Role.customer);

  /// Referans: `data-act="register" data-arg="provider"` → KOŞULSUZ.
  void _openProvider(BuildContext context) =>
      RoleSelectScreen.startRegister(context, Role.provider);
}

/// `.hd{display:flex;align-items:center;justify-content:space-between;
///   padding-top:29px}`
/// `.hd-l{display:flex;align-items:center;gap:4px}`
/// `.hd-r{background:none;border:none;display:flex;padding:4px;
///   margin:-4px;border-radius:50%}`
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    // ⚠ GEÇİCİ FORMÜL — GÖRSEL KABUL BEKLİYOR
    //
    // Referans değeri: `.hd{padding-top:29px}` (düz, viewport üstünden).
    // Burada uygulanan: `max(29, safeTop)`.
    //
    // Neden birebir değil: referans tarayıcıda durum çubuğu yoktur.
    // 29px doğrudan uygulanırsa içerik çentik/durum çubuğu altında kalır.
    // `max` seçildi çünkü toplama (`29 + safeTop`) referanstan HER ZAMAN
    // sapar; `max` ise safeTop ≤ 29 olan cihazlarda referans değerini
    // AYNEN verir, yalnız daha büyük çentiklerde zorunlu olarak büyür.
    //
    // ⚠ Bu değerin doğruluğu gerçek cihazda referans HTML ile
    // karşılaştırılarak kesinleşecektir. Şu an "referansla aynı"
    // İDDİA EDİLMEMEKTEDİR.
    final safeTop = MediaQuery.paddingOf(context).top;
    const refHeaderTop = 29.0; // .hd{padding-top:29px}
    final topPad = safeTop > refHeaderTop ? safeTop : refHeaderTop;

    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // .hd-l — ${LOGO(42)}${WORDMARK(23)}  gap:4px
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LOGO(42) → en/boy 148/182
              const Image(
                image: AssetImage('assets/logo/logo_mark.png'),
                width: 42 * 148 / 182,
                height: 42,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: 4), // gap:4px
              // WORDMARK(23) → en/boy 318/76
              const Image(
                image: AssetImage('assets/logo/wordmark.png'),
                width: 23 * 318 / 76,
                height: 23,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),

          // .hd-r — HTML: <button ... onclick="openLogin()">PROFILE</button>
          //
          // ⚠ KOŞULSUZ. Referansta oturum durumuna göre ikon veya hedef
          // DEĞİŞMEZ; bildirim düğmesi Home'da YOKTUR. Oturum durumuna
          // bağlı yardımcı mantık eklemek navigasyon sözleşmesini bozar.
          RefTap(
            onTap: () => Navigator.pushNamed(context, '/login'),
            borderRadius: BorderRadius.circular(RR.circle),
            child: const Padding(
              padding: EdgeInsets.all(4), // padding:4px
              child: RefSvg('assets/svg/ic_profile.svg', size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.rc{position:relative;border-radius:16px;margin-top:17px;
///   padding:16px 16px 15px;display:flex;flex-direction:column;
///   align-items:flex-start;overflow:hidden}`
/// `.rc .art{position:absolute;right:2px;top:20px;width:158px;z-index:0}`
/// `.rc h2{font-size:16px;font-weight:700;line-height:19px;
///   letter-spacing:-.4px;margin-top:12px}`
/// `.rc p{font-size:11.6px;line-height:14.5px;color:#3E4C61;
///   letter-spacing:-.2px;margin-top:8px}`
/// `.tags{font-size:10px;font-weight:700;letter-spacing:-.2px;
///   margin-top:9px}`
class _RoleCard extends StatelessWidget {
  const _RoleCard({ 
    required this.background,
    required this.art,
    required this.squareGradient,
    required this.squareShadow,
    required this.squareIcon,
    required this.title,
    required this.titleColor,
    required this.desc,
    required this.ctaIcon,
    required this.ctaIconColor,
    required this.ctaLabel,
    required this.tags,
    required this.tagsColor,
    required this.onTap,
  });

  final Color background;
  final String art;
  final LinearGradient squareGradient;
  final List<BoxShadow> squareShadow;
  final String squareIcon;
  final String title;
  final Color titleColor;
  final String desc;
  final String ctaIcon;
  final Color ctaIconColor;
  final String ctaLabel;
  final String tags;
  final Color tagsColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // .rc{border-radius:16px;overflow:hidden}
      borderRadius: BorderRadius.circular(RR.r16),
      child: RefTap(
        onTap: onTap,
        child: Container(
          color: background,
          child: Stack(
            children: [
              // .rc .art{position:absolute;right:2px;top:20px;width:158px}
              Positioned(
                right: 2,
                top: 20,
                width: 158,
                child: Image(
                  image: AssetImage(art),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              // .rc{padding:16px 16px 15px;align-items:flex-start}
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // .sq{29×29; radius 9}
                    RefGradientSquare(
                      gradient: squareGradient,
                      shadow: squareShadow,
                      child: RefSvg(squareIcon, size: 19, color: RC.white),
                    ),
                    const SizedBox(height: 12), // .rc h2{margin-top:12px}
                    Text(
                      title,
                      style: refText(
                        size: RF.s16,
                        weight: RF.w700,
                        color: titleColor,
                        letterSpacing: RF.lsM04,
                      ).copyWith(height: 19 / 16), // line-height:19px
                    ),
                    const SizedBox(height: 8), // .rc p{margin-top:8px}
                    Text(
                      desc,
                      style: refText(
                        size: 11.6,
                        weight: RF.w400,
                        color: const Color(0xFF3E4C61),
                        letterSpacing: RF.lsM02,
                      ).copyWith(height: 14.5 / 11.6), // line-height:14.5px
                    ),
                    const SizedBox(height: 12),
                    RefWhiteCta(
                      iconAsset: ctaIcon,
                      iconColor: ctaIconColor,
                      label: ctaLabel,
                    ),
                    const SizedBox(height: 9), // .tags{margin-top:9px}
                    Text(
                      tags,
                      style: refText(
                        size: RF.s10,
                        weight: RF.w700,
                        color: tagsColor,
                        letterSpacing: RF.lsM02,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.card` + `.card .top` + `.shield` + `.cats`
///
/// `.card .top{display:flex;gap:13px;align-items:flex-start;padding:0 5px}`
/// `.shield{width:54px;height:54px;border-radius:50%;background:#E8F0FD}`
/// `.card h3{font-size:16px;font-weight:700;color:#1D6BE3;
///   letter-spacing:-.4px;line-height:1.3}`
/// `.card .desc{font-size:13px;line-height:1.5;color:#3A4658;
///   margin-top:5px;letter-spacing:-.1px}`
/// `.cats{display:grid;grid-template-columns:repeat(7,1fr);
///   margin-top:16px;gap:0}`
class _CategoryCard extends StatelessWidget {
  const _CategoryCard();

  @override
  Widget build(BuildContext context) {
    return RefCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .card .top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5), // padding:0 5px
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // .shield
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F0FD),
                    shape: BoxShape.circle,
                  ),
                  child: const RefSvg('assets/svg/ic_shield.svg',
                      size: 29, color: RC.blue),
                ),
                const SizedBox(width: 13), // gap:13px
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "HizmetCep'te Neler Bulabilirsiniz?",
                        style: refText(
                          size: RF.s16,
                          weight: RF.w700,
                          color: RC.blue,
                          height: RF.lh130,
                          letterSpacing: RF.lsM04,
                        ),
                      ),
                      const SizedBox(height: 5), // margin-top:5px
                      Text(
                        'Tesisat, elektrik, doğalgaz, temizlik, boya, tadilat, '
                        'mühendislik ve birçok farklı hizmet kategorisine tek '
                        'uygulamadan ulaşabilirsiniz.',
                        style: refText(
                          size: RF.s13,
                          weight: RF.w400,
                          color: RC.textDark,
                          height: RF.lh150,
                          letterSpacing: RF.lsM01,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // ── ⚠ HİZMET ALANLARI PANELİ ──
          //
          const HizmetAlanlariPaneli(),

        ],
      ),
    );
  }
}

/// ── HİZMET ALANLARI PANELİ ──
///
/// ⚠ PANEL SABİT, İÇİ KAYAR.
///
/// Ana sayfa zaten dikey kaydırılıyor. Panel de sayfayla birlikte
/// kaysaydı on çatı ekranı uzatır, altındaki güven şeridi ve
/// "Tüm Kategoriler" bağlantısı aşağı itilirdi. Bu yüzden panelin
/// yüksekliği SINIRLI ve çatı listesi kendi kaydırıcısına sahip.
///
/// ⚠ İÇ İÇE KAYDIRMA: dıştaki sayfa dikey, içteki liste de dikey.
/// Bu normalde çakışır; `physics` açıkça verilerek içteki listenin
/// kendi hareketini yönetmesi sağlanır.
/// ⚠ SINIF AÇIK (private değil): ölçü sabitleri ve
/// `panelYuksekligi`/`kartYuksekligi` hesapları TESTTEN OKUNUYOR.
/// Test ölçtüğü değeri hesaplananla karşılaştırabilsin diye erişime
/// açık; dışarıdan başka bir ekranda kullanılmaz.
class HizmetAlanlariPaneli extends StatefulWidget {
  const HizmetAlanlariPaneli({super.key});

  // ── ⚠ PANEL ÖLÇÜLERİ — GÖZ KARARI KATSAYI YOK ──
  //
  // Önceki hâl `196 * 3 * 0.53` diyordu. 196 uydurma bir kart
  // yüksekliği, 0,53 ise onu ekrana sığdırmak için elle bulunmuş bir
  // katsayıydı. Cihaz genişliği veya yazı ölçeği değişince üçüncü
  // satır kırpılıyordu.
  //
  // Yükseklik artık KARTIN KENDİ PARÇALARINDAN toplanıyor:
  //   fotoğraf  = sütun genişliği / en-boy oranı
  //   üst dolgu + başlık satırı + ara boşluk
  //   + 3 satır açıklama + alt dolgu
  // Sütun genişliği `LayoutBuilder` ile ÖLÇÜLÜR, tahmin edilmez.

  /// Sütun sayısı — 3×3 düzeni.
  static const int kSutun = 3;

  /// ── ⚠ PANEL KAYMAZ, HEPSİ GÖRÜNÜR (ürün kararı) ──
  ///
  /// Eskiden üç satır görünüyor, kalan üçe panelin içi kaydırılarak
  /// ulaşılıyordu. İç kaydırma kaldırıldı: on iki kart DÖRT SATIR
  /// hâlinde birden çiziliyor, gerekiyorsa SAYFA kayıyor.
  ///
  /// ⚠ Satır sayısı sabit değil, çatı sayısından türer: yeni bir çatı
  /// eklenirse satır kendiliğinden artar.
  static int get kGorunenSatir =>
      (kHizmetAlanlari.length + kSutun - 1) ~/ kSutun;

  /// Sütunlar arası boşluk.
  static const double kSutunAraligi = 8;

  /// Satırlar arası boşluk.
  static const double kSatirAraligi = 10;

  /// Kart fotoğrafının en-boy oranı.
  static const double kFotoOrani = 1.5;

  /// Kart metin bloğunun yatay dolgusu.
  ///
  /// ⚠ 8 → 6: dar ekranda başlığa 4 birim daha yer açar.
  static const double kMetinYanDolgu = 6;

  /// ── ⚠ DAR EKRANDA PUNTO KÜÇÜLÜR ──
  ///
  /// "Organizasyon" ve "Mühendislik" tek kelime; satır sonundan
  /// bölünemez. 390 birimlik ekranda sığıyor ama 360 ve altında
  /// taşıp üç noktayla kesiliyordu.
  ///
  /// ⚠ Kesme yerine ÖLÇEKLEME: punto sütun genişliğiyle orantılı
  /// küçülür. Referans genişlik 106,7 (390 birimlik ekran); alt
  /// sınır 0,80 — bunun altında okunabilirlik bozulur.
  ///
  /// ⚠ YÜKSEKLİK HESABI DA AYNI ORANI KULLANIR; ikisi ayrışırsa
  /// kart taşar.
  static const double kReferansSutun = 106.7;
  /// ⚠ 0,78 — 320 birimlik en dar ekranda "Organizasyon" kelimesinin
  /// sığdığı değer. Poppins metrikleriyle ÖLÇÜLDÜ, tahmin edilmedi.
  static const double kEnKucukOran = 0.78;

  static double puntoOrani(double sutunGenisligi) {
    final o = sutunGenisligi / kReferansSutun;
    if (o >= 1) {
      return 1;
    }
    return o < kEnKucukOran ? kEnKucukOran : o;
  }

  /// Kart metin bloğunun dikey dolguları ve ara boşluğu.
  static const double kMetinUstDolgu = 8;
  static const double kMetinAltDolgu = 10;
  /// ⚠ 5 → 3: başlık ile açıklama arası fazla açıktı; iki metin tek
  /// blok gibi okunmalı.
  static const double kBaslikAltiBosluk = 3;

  /// Başlık en fazla kaç satır çizilir.
  ///
  /// ⚠ İKİ SATIR (15 Ağu, ürün kararı). "Kişisel Hizmet",
  /// "İnşaat & Dekorasyon", "Mühendislik & Danışmanlık" tek satıra
  /// sığmıyordu ve üç noktayla kesiliyordu. Ad KISALTILMADI — kart
  /// başlığa iki satır ayırıyor.
  ///
  /// ⚠ ORTAK YÜKSEKLİK: kısa adlı kartlar da iki satırlık alanı
  /// ayırır; 12 kartın tamamı aynı ölçüde kalır.
  static const int kBaslikSatiri = 2;

  /// (eski not) Üç sütunda kart ~110 birim; uzun adlar tek
  /// satıra sığmıyor ve punto okunmaz hâle gelmeden sığdırılamıyor.
  /// Kartta iki satırlık KISA ad gösterilir.
  ///
  /// ⚠ VERİ ADI DEĞİŞMEZ: çatı ekranında, eşleştirmede ve testlerde
  /// gerçek ad kullanılır. Bu yalnız kartın etiketi.
  /// ── ⚠ KARTTA GÖRÜNEN KISA ETİKET ──
  ///
  /// Üç sütunda kart en dar cihazda ~97 dp; yan dolgu düşünce metne
  /// ~85 dp kalıyor ve 12.5 puntoda satır başına ancak ~13 karakter
  /// sığıyor. Başlık iki satırla sınırlı olduğu için uzun adlar üç
  /// nokta ile kesiliyordu.
  ///
  /// ⚠ İKİ İŞ BİRDEN YAPAR:
  ///   1. UZUN ADI KISALTIR — "Beyaz Eşya & Elektronik Servis" iki
  ///      satıra sığmıyordu.
  ///   2. KIRMA NOKTASINI SABİTLER — sığan adlarda bile Flitter'ın
  ///      seçtiği kırılma yeri tesadüfe kalmasın. Ekran görüntüsünde
  ///      "Hukuk," / "Finans & Kur…" diye bölünüyordu; `\n` ile nerede
  ///      bölüneceği kesinleşir.
  ///
  /// ⚠ SÖZLÜKTEKİ HER ANAHTAR GERÇEK BİR ÇATI ADI OLMALIDIR.
  /// Paket A'da adlar değişince eski `'Mühendislik & Danışmanlık'`
  /// kaydı ÖLÜ kalmıştı — hiç eşleşmiyordu ve kimse fark etmemişti.
  /// Test artık bunu yakalar.
  ///
  /// ⚠ PUNTO VE KART ÖLÇÜSÜ DEĞİŞMEZ: on beş kart aynı yükseklikte
  /// ve aynı puntoda kalır; değişen yalnız yazılan metin.
  static const Map<String, String> kKartEtiketi = {
    // ⚠ 24 ÇATI (yeni katalog). Ölü kayıt bırakılmaz: çatı adı
    // değişince buradaki anahtar da değişmeli — test denetler.
    'İnşaat & Dekorasyon': 'İnşaat\nDekorasyon',
    'Mühendislik & Proje': 'Mühendislik\n& Proje',
    'Organizasyon & Etkinlik': 'Organizasyon\n& Etkinlik',
    'Evcil Hayvan Hizmetleri': 'Evcil Hayvan\nHizmetleri',
    'Beyaz Eşya & Elektronik': 'Beyaz Eşya\nElektronik',
    'Hukuk & Finans': 'Hukuk &\nFinans',
    'Güzellik & Bakım & Spor': 'Güzellik &\nBakım',
    'Geri Dönüşüm & Atık Yönetimi': 'Geri Dönüşüm\n& Atık',
    'Özel Güvenlik & Koruma': 'Özel Güvenlik\n& Koruma',
    'Çocuk & Bebek Bakımı': 'Çocuk &\nBebek Bakımı',
    'Gayrimenkul & Emlak': 'Gayrimenkul\n& Emlak',
    'Tarım & Hayvancılık': 'Tarım &\nHayvancılık',
    'Turizm & Konaklama': 'Turizm &\nKonaklama',
  };

  /// Kartta yazılacak etiket — kısaltması yoksa gerçek ad.
  static String kartEtiketi(String ad) => kKartEtiketi[ad] ?? ad;

  /// Başlık ve açıklama satır yükseklikleri (punto × satır çarpanı).
  ///
  /// ⚠ İKON KALKINCA HESAP GERÇEKLE ÖRTÜŞTÜ. Başlık satırı eskiden
  /// bir `Row` içindeydi ve yanındaki 18 birimlik ikon satırı
  /// yükseltiyordu; formül ise yalnız punto × çarpan (≈15) sayıyordu,
  /// yani kart gerçekte hesaplanandan ~3 birim uzundu. Artık başlık
  /// düz metin: ölçülen yükseklik ile hesap birebir aynı.
  static const double kBaslikPunto = RF.s125;
  static const double kBaslikSatirCarpani = 1.2;
  static const double kAciklamaPunto = RF.s105;
  static const double kAciklamaSatirCarpani = RF.lh140;

  /// Açıklama en fazla kaç satır çizilir.
  ///
  /// ⚠ 3 → 2: açıklamalar kısaltıldı, üçüncü satır boş kalıp kartı
  /// gereksiz uzatıyordu.
  static const int kAciklamaSatiri = 2;

  /// ── ⚠ KART ÇERÇEVESİ HESABA KATILIR ──
  ///
  /// Kart bir `Border.all(width: 1)` taşıyor. Çerçeve, içerik
  /// kutusunun DIŞINDA değil İÇİNDE yer kaplar: üstten ve alttan
  /// 1'er birim. Hesaba konmayınca kart 2 birim taşıyordu
  /// ("RenderFlex overflowed by 1.6 pixels").
  static const double kCerceveKalinligi = 1;

  /// TEK KARTIN yüksekliği.
  ///
  /// ⚠ Yazı ölçeği PUNTOYA uygulanır, yüksekliğe değil — Android 14+
  /// doğrusal olmayan ölçekleme yaptığı için yüksekliği ölçeklemek
  /// eksik yer ayırır (rol kartlarında aynı hata yaşandı).
  static double kartYuksekligi(double sutunGenisligi, TextScaler olcek) {
    final oran = puntoOrani(sutunGenisligi);
    return
        // ⚠ Fotoğraf, çerçevenin İÇİNDEKİ genişliğe göre ölçülür.
        (sutunGenisligi - kCerceveKalinligi * 2) / kFotoOrani +
            kMetinUstDolgu +
            _satirYuksekligi(olcek, kBaslikPunto * oran, kBaslikSatirCarpani) *
                kBaslikSatiri +
            kBaslikAltiBosluk +
            _satirYuksekligi(
                    olcek, kAciklamaPunto * oran, kAciklamaSatirCarpani) *
                kAciklamaSatiri +
            kMetinAltDolgu +
            kCerceveKalinligi * 2;
  }

  /// ── ⚠ SATIR YÜKSEKLİĞİ YUKARI YUVARLANIR ──
  ///
  /// Flutter'ın paragraf düzeni her satırı TAM PİKSELE tamamlar.
  /// Açıklama satırı 10,5 × 1,4 = 14,7 birim ama çizilirken 15
  /// oluyor; üç satırda 0,9 birim fark birikiyor ve kart tam o kadar
  /// taşıyordu ("overflowed by 0.900 pixels").
  ///
  /// Hesap gerçeği izlesin diye satır yüksekliği yukarı yuvarlanır.
  /// Başlığa ayrılan sabit alan.
  static double baslikAlani(TextScaler olcek, double oran) =>
      _satirYuksekligi(olcek, kBaslikPunto * oran, kBaslikSatirCarpani) *
      kBaslikSatiri;

  /// Açıklamaya ayrılan sabit alan.
  static double aciklamaAlani(TextScaler olcek, double oran) =>
      _satirYuksekligi(olcek, kAciklamaPunto * oran, kAciklamaSatirCarpani) *
      kAciklamaSatiri;

  static double _satirYuksekligi(
          TextScaler olcek, double punto, double carpan) =>
      (olcek.scale(punto) * carpan).ceilToDouble();

  /// PANELİN görünen yüksekliği — tam 3 satır + aralarındaki boşluk.
  static double panelYuksekligi(double sutunGenisligi, TextScaler olcek) =>
      kartYuksekligi(sutunGenisligi, olcek) * kGorunenSatir +
      kSatirAraligi * (kGorunenSatir - 1);

  @override
  State<HizmetAlanlariPaneli> createState() => _HizmetAlanlariPaneliState();
}

class _HizmetAlanlariPaneliState extends State<HizmetAlanlariPaneli> {
  // ── ⚠ KENDİ KAYDIRMA DENETLEYİCİSİ ──
  //
  // `Scrollbar(thumbVisibility: true)` bir `ScrollController` ZORUNLU
  // kılar; verilmezse `PrimaryScrollController`'ı arar ve bulamayınca
  // çalışma anında düşer:
  //   "A ScrollController is required when Scrollbar.thumbVisibility
  //    is true"
  //
  // ⚠ ANA SAYFANIN denetleyicisi KULLANILAMAZ: panel sayfadan ayrı
  // kaymalı. Ayrı denetleyici bu ayrımı da garanti eder.
  final ScrollController _kaydirici = ScrollController();

  // ⚠ KISA TAKMA ADLAR — tek kaynak yine sınıf sabitleri.
  static const int _kSutun = HizmetAlanlariPaneli.kSutun;
  static const double _kSutunAraligi = HizmetAlanlariPaneli.kSutunAraligi;
  static const double _kSatirAraligi = HizmetAlanlariPaneli.kSatirAraligi;

  @override
  void dispose() {
    _kaydirici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final olcek = MediaQuery.textScalerOf(context);
    final satirSayisi =
        (kHizmetAlanlari.length + _kSutun - 1) ~/ _kSutun;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: const Color(0xFFECEEF2)),
        borderRadius: BorderRadius.circular(RR.r14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hizmet Kategorileri',
              style:
                  refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 10),
          // ⚠ SÜTUN GENİŞLİĞİ ÖLÇÜLÜR: panelin iç genişliğinden
          // sütun aralıkları düşülüp üçe bölünür.
          LayoutBuilder(
            builder: (context, kisit) {
              final sutunGenisligi =
                  (kisit.maxWidth - _kSutunAraligi * (_kSutun - 1)) / _kSutun;
              final kartY = HizmetAlanlariPaneli.kartYuksekligi(
                  sutunGenisligi, olcek);
              return SizedBox(
                height: HizmetAlanlariPaneli.panelYuksekligi(
                    sutunGenisligi, olcek),
                // ── ⚠ PANEL KAYMAZ, GÖRÜNÜR ÇUBUK YOK ──
                //
                // Liste kendi içinde kaydırılamaz: 12 kart dört satır
                // hâlinde birden çizilir. Uzunsa SAYFA kayar.
                child: ListView.builder(
                    controller: _kaydirici,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: satirSayisi,
                    // ⚠ `itemExtent` KULLANILMAZ.
                    //
                    // Sabit uzantı her satıra aralık eklerdi: içerik
                    // 4 kart + 4 aralık olur, panel ise 4 kart + 3
                    // aralık — son satır 10 birim KIRPILIRDI.
                    // Satır yüksekliğini kartın kendisi belirler,
                    // aralık yalnız satır ARALARINA konur.
                    itemBuilder: (_, satir) => Padding(
                      padding: EdgeInsets.only(
                          bottom:
                              satir == satirSayisi - 1 ? 0 : _kSatirAraligi),
                      child: SizedBox(
                        height: kartY,
                        child: Row(
                          children: [
                            for (var s = 0; s < _kSutun; s++) ...[
                              if (s > 0)
                                const SizedBox(width: _kSutunAraligi),
                              Expanded(
                                child: satir * _kSutun + s <
                                        kHizmetAlanlari.length
                                    ? _AlanKarti(
                                        alan: kHizmetAlanlari[
                                            satir * _kSutun + s])
                                    // ⚠ Son satır eksik kalırsa hizalama
                                    // bozulmasın diye boş yer tutucu.
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }
}

/// Tek çatı kartı — fotoğraf, başlık, açıklama.
class _AlanKarti extends StatelessWidget {
  const _AlanKarti({required this.alan});

  final HizmetAlani alan;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, kisit) => _govde(context, kisit.maxWidth),
      );

  Widget _govde(BuildContext context, double genislik) {
    // ⚠ ORAN PANELLE AYNI KAYNAKTAN: kart kendi genişliğini ölçer,
    // punto ve yükseklik hesabı aynı oranı kullanır.
    final oran = HizmetAlanlariPaneli.puntoOrani(genislik);
    final olcek = MediaQuery.textScalerOf(context);
    return RefTap(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => HizmetAlaniScreen(alan: alan),
        ),
      ),
      borderRadius: BorderRadius.circular(RR.r12),
      child: Container(
        // ⚠ ÖLÇÜM ANAHTARI: testin gerçek kart kutusunu bulması için.
        key: ValueKey('cati-karti-${alan.ad}'),
        decoration: BoxDecoration(
          color: RC.white,
          // ⚠ Kalınlık hesapla ORTAK sabitten; ikisi ayrışırsa kart
          // taşar.
          border: Border.all(
              color: const Color(0xFFECEEF2),
              width: HizmetAlanlariPaneli.kCerceveKalinligi),
          borderRadius: BorderRadius.circular(RR.r12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          // ⚠ Metinler ORTALI: başlık iki satıra çıktığında sola
          // yaslı hâli düzensiz görünüyordu.
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠ ÖLÇÜLER PANELLE ORTAK SABİTTEN. Kart burada başka bir
            // oran/dolgu kullanırsa panel yüksekliği hesabı tutmaz ve
            // üçüncü satır kırpılır.
            AspectRatio(
              aspectRatio: HizmetAlanlariPaneli.kFotoOrani,
              // ⚠ ESNETME YOK: BoxFit.cover kontrollü kırpar,
              // BoxFit.fill geometriyi bozardı.
              child: Image.asset(alan.gorsel, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  HizmetAlanlariPaneli.kMetinYanDolgu,
                  HizmetAlanlariPaneli.kMetinUstDolgu,
                  HizmetAlanlariPaneli.kMetinYanDolgu,
                  HizmetAlanlariPaneli.kMetinAltDolgu),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: HizmetAlanlariPaneli.baslikAlani(olcek, oran),
                    width: double.infinity,
                    // ⚠ DİKEY ORTALI: tek satırlık başlıklar da aynı
                    // kutuyu kullanır, yukarı yapışmaz.
                    child: Center(
                      child: Text(
                          HizmetAlanlariPaneli.kartEtiketi(alan.ad),
                          maxLines: HizmetAlanlariPaneli.kBaslikSatiri,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: refText(
                              size: HizmetAlanlariPaneli.kBaslikPunto * oran,
                              weight: RF.w600,
                              color: RC.text,
                              height: HizmetAlanlariPaneli
                                  .kBaslikSatirCarpani)),
                    ),
                  ),
                  const SizedBox(
                      height: HizmetAlanlariPaneli.kBaslikAltiBosluk),
                  // ⚠ Açıklama da SABİT alanda; başlıktan belirgin
                  // şekilde hafif (w400) ve küçük.
                  SizedBox(
                    height: HizmetAlanlariPaneli.aciklamaAlani(olcek, oran),
                    width: double.infinity,
                    child: Text(
                      alan.aciklama,
                      maxLines: HizmetAlanlariPaneli.kAciklamaSatiri,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: refText(
                          size: HizmetAlanlariPaneli.kAciklamaPunto * oran,
                          weight: RF.w500,
                          color: RC.textSoft,
                          height:
                              HizmetAlanlariPaneli.kAciklamaSatirCarpani),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.card.trust{display:grid;grid-template-columns:repeat(3,1fr);
///   padding:15px 4px}`
/// `.tc{display:flex;gap:8px;padding:0 7px;align-items:flex-start}`
/// `.tc b{font-size:10.5px;font-weight:700;color:#16233D;
///   line-height:1.3;letter-spacing:-.2px}`
/// `.tc i{font-size:8.5px;font-style:normal;color:#6C7889;
///   margin-top:4px;line-height:1.45}`
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  /// ⚠ BAŞLIK sabit alanda, AÇIKLAMA değil.
  ///
  /// Başlıklar farklı uzunlukta ("Memnun Kullanıcı Deneyimi" dar
  /// sütunda üç satır, ötekiler iki); ortak alan olmasaydı üç sütunun
  /// açıklamaları FARKLI HİZADAN başlardı. Bu yüzden başlık alanı
  /// KALIR.
  ///
  static const int _kBaslikSatiri = 3;

  /// ⚠ Satır yüksekliği YUKARI YUVARLANIR: Flutter paragraf düzeni
  /// her satırı tam piksele tamamlar; yuvarlanmazsa toplam eksik
  /// hesaplanır ve içerik taşar.
  static double _satir(TextScaler o, double punto, double carpan) =>
      (o.scale(punto) * carpan).ceilToDouble();

  static double _baslikAlani(BuildContext c) =>
      _satir(MediaQuery.textScalerOf(c), RF.s105, RF.lh130) * _kBaslikSatiri;

  @override
  Widget build(BuildContext context) {
    return RefCard(
      // .card.trust{padding:15px 4px}
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in _kTrust)
            Expanded(
              child: Padding(
                // .tc{padding:0 7px}
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RefSvg(t.asset, size: 23, color: t.color),
                    const SizedBox(width: 8), // gap:8px
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── ⚠ BAŞLIĞA ORTAK SABİT ALAN ──
                          //
                          // Üç sütunun başlıkları farklı uzunlukta:
                          // "Memnun Kullanıcı Deneyimi" dar sütunda
                          // ÜÇ satıra çıkıyor, ötekiler iki satırda
                          // kalıyordu. Açıklamalar farklı hizalardan
                          // başlıyor ve en uzun sütun kart dışına
                          // taşıyordu.
                          //
                          // ⚠ Ortak alan EN UZUN başlığa göre; metin
                          // küçültülmedi, font hafifletilmedi.
                          SizedBox(
                            height: _baslikAlani(context),
                            width: double.infinity,
                            child: Text(
                              t.title,
                              maxLines: _kBaslikSatiri,
                              style: refText(
                                size: RF.s105,
                                weight: RF.w700,
                                color: RC.text,
                                height: RF.lh130,
                                letterSpacing: RF.lsM02,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4), // margin-top:4px
                          // ⚠ SABİT YÜKSEKLİK VE `maxLines` YOK —
                          // metin tam sığar, sonu kesilmez.
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              t.desc,
                              style: refText(
                                size: 8.5,
                                weight: RF.w400,
                                color: const Color(0xFF6C7889),
                                height: RF.lh145,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.promo{display:flex;align-items:center;border-radius:16px;
///   padding:22px 16px;margin-top:16px;overflow:hidden;
///   background:linear-gradient(135deg,#1E63E0,#1340BE)}`
/// `.pt{flex:1;position:relative;z-index:2}`
/// `.promo h4{font-size:20px;font-weight:700;color:#fff;
///   line-height:1.25;letter-spacing:-.5px}`
/// `.promo p{font-size:13px;color:rgba(255,255,255,.92);
///   margin-top:9px;line-height:1.5;letter-spacing:-.1px}`
/// `.art-p{flex-shrink:0;width:112px;margin-right:-4px;z-index:2}`
class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RR.r16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: const BoxDecoration(gradient: RG.promo),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // .pt{flex:1}
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İhtiyacınız olan\nhizmete en hızlı yol!',
                    style: refText(
                      size: RF.s20,
                      weight: RF.w700,
                      color: RC.white,
                      height: RF.lh125,
                      letterSpacing: RF.lsM05,
                    ),
                  ),
                  const SizedBox(height: 9), // margin-top:9px
                  Text(
                    'Doğru profesyonel, doğru fiyat,\ngüvenli hizmet.',
                    style: refText(
                      size: RF.s13,
                      weight: RF.w400,
                      // rgba(255,255,255,.92)
                      color: RC.white.withValues(alpha: 0.92),
                      height: RF.lh150,
                      letterSpacing: RF.lsM01,
                    ),
                  ),
                ],
              ),
            ),
            // .art-p{width:112px;margin-right:-4px}
            Transform.translate(
              offset: const Offset(4, 0), // margin-right:-4px
              child: const SizedBox(
                width: 112,
                child: RefSvgFlexible('assets/svg/art_phone.svg', width: 112),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
