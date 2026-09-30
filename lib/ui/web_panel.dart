import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'olcu.dart';
import 'panel_rotasi.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// WEB PANELİ — FORM / AYAR / İŞLEM EKRANLARININ MASAÜSTÜ KABI
///
/// ## ⚠ NİÇİN KABUKTAKİ PANEL YETMEDİ
///
/// Önceki çözüm `MaterialApp.builder` içindeydi ve `Navigator`ı
/// sarıyordu. `Navigator` ve içindeki `Scaffold` verilen alanı
/// DOLDURUR, içeriğine göre büzülmez — intrinsic yükseklikleri
/// yoktur. Bu yüzden kart yüksekliği ekranın %88'ine sabitlenmek
/// zorunda kalmış, kısa formlarda altta büyük boşluk kalmıştı.
///
/// Panel artık EKRANIN GÖVDESİNİ sarıyor. Gövde sıradan bir widget
/// ağacı olduğu için `Column(mainAxisSize: min)` ile içeriğine göre
/// büzülebiliyor.
///
/// ## ⚠ TEK BİLEŞEN, ONÜÇ EKRAN
///
/// Genişlik, başlık hizası, X konumu, kaydırma davranışı ve aksiyon
/// alanı BURADA tanımlıdır. Ekranlar yalnız `baslik`, `icerik` ve
/// `aksiyon` verir; hiçbiri kendi kart/ölçü kodunu yazmaz.
///
/// ## ⚠ MOBİLDE VE DAR TARAYICIDA ARAYA GİRMEZ
///
/// `kIsWeb` VE ≥1024 px sağlanmazsa gövde BUGÜNKÜ hâliyle döner:
/// aynı dikey akış, aynı başlık, aynı geri oku. Android/iOS — tablet
/// dahil — hiç etkilenmez.
///
/// ## ⚠ YÜKSEKLİK İÇERİĞE GÖRE
///
/// `Column(mainAxisSize: MainAxisSize.min)` kartı içeriğe göre
/// büzer. İçerik ekranı aşarsa `Flexible` devreye girer ve YALNIZ
/// içerik bölümü kaydırılır; başlık ve aksiyon sabit kalır.
///
/// ## ⚠ GERİ OKU YERİNE X
///
/// Masaüstü panelinde geri oku çizilmez (`baslikGeriOku: false`
/// davranışı çağıran ekranda değil, burada kararlaştırılır: panel
/// kendi başlığını çizer). X kartın SAĞ ÜST İÇ KÖŞESİNDE, kenardan
/// boşlukla durur — ekranın köşesine sabitlenmez.
///
/// ⚠ `ic_x.svg` KENDİ RENKLERİNİ TAŞIR: renk verilirse dolu daireye
/// dönüşür. Renk GEÇİLMEZ — "Hesabı Sil" modalındaki ile aynı kural.
///
/// ## ⚠ AKSİYON PANEL GENİŞLİĞİNDE
///
/// Düğme kartın iç dolgusuyla hizalı kalır; masaüstünde ekran boyunca
/// uzamaz. Mobilde bugünkü tam genişlik davranışı sürer.
/// ═══════════════════════════════════════════════════════════════
/// ═══════════════════════════════════════════════════════════════
/// WEB — X / ESC İLE KAPATMA (TEK KAYNAK)
///
/// Web'deki bütün kapatma düğmeleri (panel X'i, Esc, alt panel X'i)
/// buradan geçer; ayrı ayrı yazılsaydı biri düzeltilip öteki
/// unutulurdu.
///
/// ⚠ NİÇİN `maybePop` DEĞİL:
///   · `maybePop` yığındaki TEK rota ise (web'de adres çubuğundan ya da
///     yenilemeyle doğrudan açılan panel) "bubble" döner ve SESSİZCE
///     HİÇBİR ŞEY YAPMAZ — X ölü kalır.
///   · `maybePop` önce eski `willPop` zincirini BEKLER (asenkron); X'e
///     basışla kapanış arasında bir çerçeve boşluğu açar.
/// Burada kapanış EŞZAMANLIDIR: geri dönülecek rota varsa `pop`,
/// yoksa ana sayfa (`geriGit` ile aynı sözleşme).
///
/// ⚠ YALNIZ WEB DALLARINDAN ÇAĞRILIR: Android/iOS'taki kapatma
/// davranışı değişmez.
/// ═══════════════════════════════════════════════════════════════
void webKapat(BuildContext context) {
  final nav = Navigator.of(context);
  // ⚠ KATEGORİ → İLAN AKIŞI: X bir seviye değil AKIŞIN TAMAMINI kapatır
  // ve ana sayfaya döner (kullanıcı kararı). Önceki ekran için kartın
  // geri oku var. Bkz. `akisiKapat` (panel_rotasi.dart).
  if (akisRotasiMi(ModalRoute.of(context))) {
    akisiKapat(nav);
    return;
  }
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  nav.pushNamedAndRemoveUntil('/home', (_) => false);
}

class WebPanel extends StatelessWidget {
  const WebPanel({
    super.key,
    this.baslik,
    required this.icerik,
    this.panelIcerik,
    this.altYazi,
    this.aksiyon,
    this.enFazla = IcerikGenisligi.form,
  });

  /// Panel başlığı — masaüstünde kartın içinde ORTALANIR.
  ///
  /// ⚠ İSTEĞE BAĞLI: ekran kendi `RefPageTitle`ını göstermeye devam
  /// ediyorsa boş bırakılır; o başlık zaten ortalanmıştır ve geri oku
  /// panelde merkezî olarak gizlenir (bkz. `RefPageTitle`). Böylece
  /// bağlama tek satırlık bir sarmalamaya iner ve ekranlarda
  /// "başlığı gizle" koşulu yazmaya gerek kalmaz.
  final String? baslik;

  /// Ekranın kendi gövdesi.
  ///
  /// ⚠ MOBİLDE OLDUĞU GİBİ DÖNER: çağıran ekran, bugün ne çiziyorsa
  /// onu verir; panel mobilde araya girmez.
  final Widget icerik;

  /// Panelde çizilecek SADE gövde.
  ///
  /// ── ⚠ NİÇİN AYRI ──
  ///
  /// Ekranların tam gövdesi `SafeArea > Column > Expanded > RefScroll`
  /// biçimindedir. `Expanded` ALANI DOLDURUR; panel onu sardığında
  /// kart içeriğe göre büzülemez ve altta kocaman boşluk kalır —
  /// Oysa modal, içeriği kadar kısa olmalıdır.
  ///
  /// Bu alan verilirse panel gövdenin kendisini değil, SADECE FORMU
  /// çizer: `Expanded` yok, dolayısıyla kart içerik kadar yüksek olur
  /// ve uzun formda yalnız bu bölüm kayar.
  ///
  /// ⚠ MOBİLİ ETKİLEMEZ: panel dışında bu alan hiç okunmaz; ekran
  /// bugünkü gövdesini aynen çizmeye devam eder.
  ///
  /// ⚠ VERİLMEZSE eski davranış sürer (tam gövde, %85 sınırlı).
  /// Ekranlar tek tek bağlanabilir; hepsi bir anda değişmek zorunda
  /// değil.
  final Widget? panelIcerik;

  /// Başlık altı açıklama (varsa).
  final String? altYazi;

  /// Ana aksiyon (Kaydet / Devam Et / Gönder …).
  ///
  /// ⚠ AYRI ALAN: kaydırılan içeriğin içinde kalsaydı uzun formda
  /// düğme ekranın dışına kayardı.
  final Widget? aksiyon;

  /// Panel genişliği. Varsayılan, tasarım sistemindeki form ölçüsü.
  final double enFazla;

  /// Bu bağlamda panel çizilir mi?
  ///
  /// ── ⚠ GENİŞLİK EŞİĞİ KALDIRILDI (19 Eyl, kullanıcı kararı) ──
  ///
  /// Önceden `kIsWeb && masaustuMu` idi; mobil web'de panel hiç
  /// çıkmıyor, form ekranı tam sayfa açılıyordu. YANLIŞTI: gerçek web
  /// siteleri telefonda da giriş/kayıt formunu
  /// ortalanmış KART olarak gösterir — kenarlarda boşluk, yuvarlak
  /// köşe, arkada karartılmış sayfa, sağ üstte X.
  ///
  /// Panel biçimi EKRAN GENİŞLİĞİNE değil, İÇERİĞİN TÜRÜNE bağlıdır:
  /// kısa bir form her genişlikte karttır. Dar ekranda kart sayfanın
  /// büyük kısmını kaplar ama yine de karttır.
  ///
  /// ⚠ ANDROID/iOS KİLİTLİ: `kIsWeb` koşulu DURUYOR. Uygulamalarda
  /// form ekranları bugünkü gibi tam sayfa açılır; oraya
  /// dokunulmadı.
  static bool panelMi(BuildContext context) {
    if (!kIsWeb) {
      return false;
    }
    // ── ⚠ KARAR ROTANIN KENDİSİNDE ──
    //
    // Önce yalnız `kIsWeb` bakılıyordu; bu, paneli TÜM web
    // ekranlarına uyguluyordu. `RefPage` gibi ortak iskeletler beş
    // ekran tarafından kullanılıyor ve yalnız biri (rol seçimi)
    // paneldir — ötekiler tam sayfa kalmalı.
    //
    // `panelRotasi` panel rotalarını `opaque: false` ile kurar; başka
    // hiçbir rota saydam değildir. Yani "saydam rota" ile "panel"
    // aynı şeydir ve ayrı bir liste tutmaya gerek yok — iki listenin
    // ayrışma riski de böylece ortadan kalkar.
    //
    // ⚠ BURADA `ModalRoute.of` ÇALIŞIR: panel Navigator'ın ALTINDA
    // çizilir. Kabukta (builder) çalışmazdı.
    final rota = ModalRoute.of(context);
    return rota != null && !rota.opaque;
  }

  /// Bu widget bir panelin İÇİNDE mi çiziliyor?
  ///
  /// ── ⚠ `panelMi` İLE KARIŞTIRILMAMALI ──
  ///
  /// `panelMi` yalnız "masaüstü web mi" der; ekranın panel olup
  /// olmadığını bilmez. Normal bir web sayfası da masaüstündedir.
  /// Geri okunu `panelMi` ile gizlemek, liste ve detay sayfalarındaki
  /// gezinmeyi de koparırdı.
  ///
  /// Bu yöntem gerçekten panel ağacının içinde olup olmadığını söyler.
  static bool icerdeMi(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelKapsami>() != null;

  @override
  Widget build(BuildContext context) {
    if (!panelMi(context)) {
      return icerik;
    }
    // ── ⚠ KATEGORİ → İLAN AKIŞINDA SABİT PANEL BOYU ──
    final ustSinir = MediaQuery.sizeOf(context).height * 0.85;
    final rota = ModalRoute.of(context);
    final akisRota = akisRotasiMi(rota) ? rota : null;
    final akisBoyu =
        akisRota == null ? null : _AkisBoyu.sabit(akisRota);
    // ── ⚠ ESC İLE KAPANIR ──
    //
    // Web'de bir pencere açıkken Esc'e basmak refleks davranıştır.
    // Panel bir ROUTE değil, sayfanın gövdesi; bu yüzden Flutter'ın
    // modal rotalar için sağladığı Esc davranışı buraya
    // ULAŞMIYORDU.
    //
    // ⚠ X İLE AYNI YOL: ikisi de `webKapat` çağırır. Ayrı kapatma
    // mantıkları olsaydı biri düzeltilip öteki unutulurdu.
    //
    // ⚠ `autofocus` VERİLMEZ: panelin kendisi odağı çalarsa
    // içerideki ilk form alanına yazmak için fazladan bir tıklama
    // gerekirdi. `Focus` yalnız tuşu dinler.
    //
    // ⚠ YALNIZ MASAÜSTÜ WEB: bu gövde zaten `panelMi` kapısının
    // arkasında; mobilde hiç çalışmaz.
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          webKapat(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
      child: Padding(
        // ⚠ KENARLARA YAPIŞMASIN: kart her genişlikte nefes alsın.
        //
        // ⚠ DAR EKRANDA DAHA AZ BOŞLUK: telefonda 24/16 px fazla yer
        // yer; kart içeriği sıkışır. Genişlik küçüldükçe dolgu da
        // küçülür.
        padding: EdgeInsets.symmetric(
          vertical: ekranSinifi(context).masaustuMu ? 24 : 12,
          horizontal: ekranSinifi(context).masaustuMu ? 16 : 10,
        ),
        child: ConstrainedBox(
          // ── ⚠ YÜKSEKLİK SINIRI ŞART ──
          //
          // Kart "içeriğe göre büzülsün" diye `mainAxisSize.min`
          // kullanıyordu. Ama sardığı gövdeler `Column` içinde
          // `Expanded` taşıyor (`SafeArea > Column > Expanded >
          // RefScroll`). `Expanded` SINIRLI yükseklik ister; büzülen
          // bir `Column` ise sınır vermez. İkisi çelişince kart BOŞ
          // çiziliyordu — telefonda görülen boş dikey şerit buydu.
          //
          // Üst sınır verilince `Expanded` çalışacağı alanı bulur ve
          // içerik çizilir.
          //
          // ⚠ TAM SAYFA DEĞİL: %85 ile sınırlı, üstte ve altta sayfa
          // görünür kalır — modal davranışının gereği.
          constraints: BoxConstraints(
            maxWidth: enFazla,
            // ⚠ AKIŞTA SABİT BOY: kategori → hizmet → ilan akışının
            // bütün panelleri ilk panelin boyunda kalır (bkz. `_AkisBoyu`).
            minHeight: akisBoyu == null
                ? 0
                : (akisBoyu < ustSinir ? akisBoyu : ustSinir),
            // ⚠ ÜST SINIR: uzun formda kart ekranı taşırmasın. Sade
            // gövde verildiğinde kart bu sınıra KADAR içerik kadar
            // yüksek olur; verilmediğinde sınıra dayanır.
            maxHeight: akisBoyu == null
                ? ustSinir
                : (akisBoyu < ustSinir ? akisBoyu : ustSinir),
          ),
          child: _BoyOlcer(
            // Akışın ilk paneli doğal boyunu bir kez bildirir; sonraki
            // paneller o boyu kullanır. Akış dışında ölçüm yapılmaz.
            onBoy: akisRota != null && akisBoyu == null
                ? (h) => _AkisBoyu.olc(akisRota, h)
                : null,
            child: Material(
            color: RC.white,
            elevation: 8,
            shadowColor: const Color(0x1A16233D),
            borderRadius: BorderRadius.circular(RR.r14),
            clipBehavior: Clip.antiAlias,
            child: _PanelKapsami(
              child: Column(
              // ⚠ İÇERİĞE GÖRE YÜKSEKLİK.
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠ BAŞLIK ŞERİDİ YALNIZ BAŞLIK VERİLDİYSE: ekran
                // kendi başlığını çiziyorsa çift başlık olmaz. X her
                // iki durumda da çizilir.
                if (baslik != null)
                  _Baslik(baslik: baslik!, altYazi: altYazi)
                else
                  const _SadeceKapat(),
                // ⚠ İÇERİK KENDİ KAYDIRMASINI YÖNETİR.
                //
                // Burada `SingleChildScrollView` VARDI ve gövdeye
                // SINIRSIZ yükseklik veriyordu — `Expanded` orada
                // çalışamaz. Ekranlar zaten kendi `RefScroll` /
                // `SingleChildScrollView` katmanını taşıyor; ikinci
                // bir kaydırma hem gereksiz hem iç içe kaydırma
                // sorunu demekti.
                // ⚠ SADE GÖVDE VARSA KAYDIRILIR, YOKSA OLDUĞU GİBİ.
                //
                // Sade gövdede `Expanded` yoktur; `SingleChildScrollView`
                // ona sınırsız yükseklik verir ve `Column(min)` içeriğe
                // göre büzülür — istenen davranış bu.
                //
                // Tam gövdede `Expanded` var; kaydırma katmanı eklemek
                // onu kırardı, bu yüzden doğrudan çizilir.
                Flexible(
                  child: panelIcerik != null
                      // ⚠ ALT BOŞLUK ÜSTLE DENGELİ: 4 px'te son kart
                      // kartın kenarına yapışık duruyordu. Başlık
                      // şeridinin altındaki boşlukla aynı ölçüde
                      // nefes bırakılır.
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: panelIcerik,
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                          child: icerik,
                        ),
                ),
                if (aksiyon != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: aksiyon,
                  ),
              ],
            ),
            ),
          )),
        ),
      ),
      ),
    );
  }
}

/// Panel ağacını işaretler.
///
/// ⚠ VERİ TAŞIMAZ, YALNIZ VARLIK BİLDİRİR: `RefBackButton` gibi ortak
/// bileşenler "bir panelin içinde miyim" sorusunu buradan sorar.
/// Alternatifi her ekrana "panelde miyim" bayrağı geçirmekti; on üç
/// ekranda on üç ayrı unutma fırsatı demekti.
/// ═══════════════════════════════════════════════════════════════
/// AKIŞ PANEL BOYU — kategori → hizmet → ilan akışında TEK BOY
///
/// Kullanıcı kararı: kategori kartına basınca açılan panel ne
/// boyuttaysa, içindeki kategoriye/hizmete basınca açılan paneller de
/// AYNI boyda kalır; hizmet çoksa kart büyümez, içerik kayar.
///
/// Akışın İLK paneli (sahip) ilk çiziminde doğal boyunu bildirir; bu
/// boy saklanır ve hem sahibin sonraki çizimlerinde (arama yazınca
/// kart küçülmesin) hem akışın sonraki panellerinde kullanılır. Sahip
/// rota kapanınca (`isActive` false) boy unutulur; yeni akış yeni boy
/// ölçer.
///
/// ⚠ YALNIZ WEB PANELİ: bu kod `panelMi` kapısının arkasında; mobilde
/// hiç çalışmaz.
/// ═══════════════════════════════════════════════════════════════
class _AkisBoyu {
  static Route<dynamic>? _sahip;
  static double? _boy;

  /// Bu akış paneli sabit boy almalı mı? `null` → doğal boy (ölçülecek).
  static double? sabit(Route<dynamic> rota) {
    final sahip = _sahip;
    if (sahip == null || !sahip.isActive) {
      _sahip = rota;
      _boy = null;
      return null;
    }
    return _boy;
  }

  static void olc(Route<dynamic> rota, double boy) {
    if (identical(rota, _sahip) && _boy == null && boy > 0) {
      _boy = boy;
    }
  }
}

/// Çocuğunun yerleşim sonrası yüksekliğini bildirir (yalnız ölçüm;
/// çizimi ve isabeti değiştirmez).
class _BoyOlcer extends SingleChildRenderObjectWidget {
  const _BoyOlcer({required this.onBoy, required super.child});

  final void Function(double)? onBoy;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBoyOlcer(onBoy);

  @override
  void updateRenderObject(BuildContext context, _RenderBoyOlcer r) {
    r.onBoy = onBoy;
  }
}

class _RenderBoyOlcer extends RenderProxyBox {
  _RenderBoyOlcer(this.onBoy);

  void Function(double)? onBoy;

  @override
  void performLayout() {
    super.performLayout();
    onBoy?.call(size.height);
  }
}

class _PanelKapsami extends InheritedWidget {
  const _PanelKapsami({required super.child});

  @override
  bool updateShouldNotify(_PanelKapsami eski) => false;
}

/// Panelin başlık şeridi — ortalanmış başlık + sağ üstte X.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.baslik, this.altYazi});

  final String baslik;
  final String? altYazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Stack(
          children: [
            // ⚠ BAŞLIK TAM ORTADA: X ile aynı satırda `Row` içinde
            // olsaydı, X'in genişliği kadar sola kayardı.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    baslik,
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s18, weight: RF.w700, color: RC.text),
                  ),
                  if (altYazi != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      altYazi!,
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s13, weight: RF.w400, color: RC.textSoft),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              // ⚠ BURADA `Navigator.of(context)` ÇALIŞIR: panel artık
              // Navigator'ın ALTINDA, ekranın gövdesinde. Kabuktaki
              // eski çözümde bu mümkün değildi.
              child: RefTap(
                onTap: () => webKapat(context),
                borderRadius: BorderRadius.circular(RR.circle),
                // ⚠ YAZISIZ İKON: masaüstünde ne yaptığını söylemeli.
                ipucu: 'Kapat',
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: RefSvg('assets/svg/ic_x.svg', size: 22),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Başlıksız panelde yalnız X şeridi.
///
/// ⚠ AYNI KONUM: başlık şeridindeki X ile aynı kenar boşluğu ve aynı
/// ikon; iki durum arasında X yer değiştirmez.
class _SadeceKapat extends StatelessWidget {
  const _SadeceKapat();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: RefTap(
            onTap: () => webKapat(context),
            borderRadius: BorderRadius.circular(RR.circle),
            ipucu: 'Kapat',
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: RefSvg('assets/svg/ic_x.svg', size: 22),
            ),
          ),
        ),
      );
}
