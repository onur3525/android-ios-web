import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/arama_izi.dart';
import '../../data/category_tree.dart';
import '../../data/services/search_service.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../../ui/web_oneri_dokunusu.dart';

/// ANA SAYFA ARAMA KUTUSU — AYRI SAYFAYA YÖNLENDİRMEZ
///
/// ⚠ Önceki davranış: kutuya dokunulduğunda `SearchScreen` açılıyordu.
/// Yeni davranış: kutu YERİNDE yazılabilir hale gelir ve eşleşmeler
/// AŞAĞI DOĞRU açılan liste olarak gösterilir. Sayfa DEĞİŞMEZ.
///
/// Veri kaynağı `SearchService.services()`; o da `kHomeCategories` ve
/// `kSubServices` üzerinden çalışır. Admin/backend yeni ana veya alt
/// kategori eklediğinde öneriler KENDİLİĞİNDEN genişler — bu bileşende
/// sabit liste YOKTUR.
class InlineSearchBox extends StatefulWidget {
  const InlineSearchBox({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSecim,
    this.webDavranisi = kIsWeb,
  });

  final String title;
  final String subtitle;

  /// Kullanıcı bir öneriye dokundu: (ana kategori, alt hizmet?).
  final void Function(String category, String? subService) onSecim;

  /// ── ⚠ WEB DAVRANIŞI ANAHTARI ──
  ///
  /// Varsayılanı `kIsWeb`: Android/iOS'ta `false`, web'de `true`.
  /// Uygulamadaki çağrılar bu parametreyi VERMEZ; yani mobil
  /// davranış hiçbir koşulda değişmez.
  ///
  /// Parametre yalnız TEST içindir: `kIsWeb` derleme sabiti olduğu
  /// için web dalı VM testinde başka türlü açılamıyordu.
  final bool webDavranisi;

  @override
  State<InlineSearchBox> createState() => _InlineSearchBoxState();
}

class _InlineSearchBoxState extends State<InlineSearchBox> {
  final _controller = TextEditingController();
  final _odak = FocusNode();

  /// Kutu yazma moduna geçti mi? (dokunulmadan önce referans görünümü)
  bool _acik = false;

  List<SearchHit> _oneriler = const [];

  /// ── ⚠ YALNIZ BU SATIR YENİDEN ÇİZİLİR ──
  ///
  /// "Sonuç bulunamadı" satırı kutunun İÇİNDE duruyor ve öneri
  /// listesine bağlı. `setState` kaldırıldığı için bu satırın kendi
  /// bildirimi olmalı; aksi hâlde yazı ekranda takılı kalırdı.
  ///
  /// ⚠ `ValueNotifier` yalnız kendisini dinleyen widget'ı çizer,
  /// ağacın tamamını değil.
  final ValueNotifier<bool> _sonucYok = ValueNotifier<bool>(false);

  /// ── ⚠ ÖNERİ PANELİ SAYFAYI İTMEZ ──
  ///
  /// Panel eskiden kutunun ALTINDAKİ `Column` çocuğuydu: açıldıkça
  /// altındaki kartlar aşağı kayıyor, kapanınca geri zıplıyordu.
  /// Kullanıcı yazdıkça sayfa oynuyordu.
  ///
  /// Panel artık uygulamanın OVERLAY katmanında çiziliyor ve kutuya
  /// `LayerLink` ile bağlı: kutu nereye giderse panel onu izler.
  ///
  /// ⚠ AYRI PENCERE DEĞİL. Overlay aynı sayfanın üstündeki katman;
  /// yeni bir route ya da diyalog AÇILMAZ, geri tuşu davranışı
  /// değişmez.
  final LayerLink _bag = LayerLink();
  OverlayEntry? _panel;

  /// ⚠ YALNIZ WEB: sayfa içi öneri panelinin tetikleyicisi (bkz. `_ara`).
  /// Mobilde dinleyicisi yoktur.
  final ValueNotifier<List<SearchHit>> _webListe =
      ValueNotifier<List<SearchHit>>(const []);

  /// Web dalı mı? (bkz. `InlineSearchBox.webDavranisi`)
  bool get _web => widget.webDavranisi;

  /// ── ⚠ YALNIZ WEB: KUTUYA ÖZGÜ DOKUNMA GRUBU ──
  ///
  /// Metin alanı, X düğmesi ve öneri paneli TEK grup. Grubun içine
  /// (satır, satır arası boşluk, kutunun kendisi) dokunmak paneli
  /// KAPATMAZ; yalnız grubun DIŞINA dokunmak kapatır.
  ///
  /// ⚠ Paylaşılan `EditableText` grubu kullanılmadı: o grup sayfadaki
  /// TÜM metin alanlarını kapsar; başka bir alana dokunmak "içeride"
  /// sayılırdı.
  final Object _grup = Object();

  /// Ölçüm: web panelinin genel dikdörtgeni (yalnız ARAMA_IZ açıkken
  /// panele bağlanır).
  final GlobalKey _izPanelAnahtari = GlobalKey();

  /// Kutunun genişliği — panel onunla aynı genişlikte olmalı.
  double _genislik = 0;

  @override
  void initState() {
    super.initState();
    if (kAramaIzi) {
      aramaIzi('SEARCH_WEB_BRANCH', '_web=$_web kIsWeb=$kIsWeb');
    }
    _odak.addListener(() {
      if (kAramaIzi && !_odak.hasFocus) {
        aramaIzi('SEARCH_RESULT_FOCUS_LOST', '_acik=$_acik _web=$_web');
      }
      // ── ⚠ WEB'DE ODAK KAYBI PANELİ KAPATMAZ ──
      //
      // Web'de metin alanının odağını tarayıcı/motor da düşürebiliyor
      // (gizli giriş kutusunun odak kaybı). Panel odağa bağlı olduğu
      // sürece bu, parmak satırdan kalkmadan paneli kaldırıp seçimi
      // kaçırtabiliyordu. Web'de panel YALNIZ şu yollarla kapanır:
      // seçim (`_sec`) · X · grup dışına dokunma · Escape
      // (hepsi `_webKapat` ya da `_sec` üzerinden).
      //
      // ⚠ MOBİL DEĞİŞMEZ: aşağıdaki gövde Android/iOS'ta aynen çalışır.
      if (_web) {
        return;
      }
      if (!_odak.hasFocus) {
        // ── ⚠ DIŞARI DOKUNMA = YALNIZCA PANELİ KAPAT ──
        //
        // Eski koşul `&& _controller.text.trim().isEmpty` idi: metin
        // varken odak gitse bile panel AÇIK KALIYORDU. Kullanıcı
        // yanlışlıkla başlığa dokunduğunda öneri listesi ekranda
        // asılı duruyordu.
        //
        // ⚠ METİN SİLİNMEZ. Burada `_controller.clear()` ÇAĞRILMAZ;
        // yalnız overlay kaldırılır ve kutu kapalı duruma döner.
        // Kullanıcı tekrar dokunduğunda yazdığı metin yerinde olur ve
        // kaldığı yerden devam eder. Metin YALNIZCA X ile temizlenir.
        _paneliKaldir();
        if (_acik) {
          setState(() => _acik = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _sonucYok.dispose();
    _webListe.dispose();
    // ⚠ Overlay girdisi widget'tan BAĞIMSIZ yaşar; kaldırılmazsa
    // ekran değişince panel ekranda asılı kalır.
    _paneliKaldir();
    _controller.dispose();
    _odak.dispose();
    super.dispose();
  }

  void _paneliKaldir() {
    _panel?.remove();
    _panel = null;
  }

  /// Panel gerekiyorsa gösterir, gerekmiyorsa kaldırır.
  void _paneliTazele() {
    if (_oneriler.isEmpty) {
      _paneliKaldir();
      return;
    }
    final kutu = context.findRenderObject() as RenderBox?;
    if (kutu != null) {
      _genislik = kutu.size.width;
    }
    if (_panel == null) {
      // ── ⚠ WEB'DE OVERLAY KULLANILMAZ ──
      //
      // Panel `Overlay` + `CompositedTransformFollower` ile
      // çiziliyordu: widget ağacın TEPESİNDE duruyor, görsel olarak
      // kutunun altına DÖNÜŞÜMLE taşınıyor. Mobilde sorunsuz. Web'de
      // ise panel GÖRÜNÜYOR ama tıklama hiçbir zaman satıra
      // ulaşmıyordu.
      //
      // Web'de panel artık kutunun HEMEN ALTINA, sayfanın kendi
      // ağacına çiziliyor (bkz. `build`). Dönüşüm yok, overlay yok,
      // hit-test sınırı yok — kategori kartları neden çalışıyorsa
      // aynı sebeple çalışır.
      //
      // ⚠ MOBİL DEĞİŞMEZ: orada overlay yolu aynen sürer; sayfa
      // itilmez, panel içeriğin üstünde durur.
      if (_web) {
        return;
      }
      _panel = OverlayEntry(builder: _panelYap);
      // ── ⚠ KÖK OVERLAY'E EKLENİR ──
      //
      // `Overlay.of(context)` EN YAKIN overlay'i verir. Mobilde bu
      // uygulamanın tek overlay'idir ve sorun çıkmaz.
      //
      // Web'de ise `GlobalWebKabugu` araya katmanlar koyuyor
      // (`MerkezliIcerik` genişlik kısıtı, kenar çubuğu için `Row`).
      // Panel bu katmanların İÇİNDE bir overlay'e düştüğünde
      // GÖRÜNÜYOR ama işaretçi olayları ona ulaşmıyor: panel
      // `CompositedTransformFollower` ile kutunun altına TAŞINIYOR ve
      // taşındığı yer, içinde bulunduğu katmanın yerleşim
      // sınırlarının DIŞINA çıkıyor. Flutter hit-test'i yerleşim
      // sınırını aşan bölgeyi o katmandan geçirmiyor.
      //
      // `rootOverlay: true` paneli uygulamanın EN ÜST overlay'ine
      // koyar — kabuk katmanlarının hiçbiri araya girmez.
      //
      // ⚠ MOBİLDE DEĞİŞMEZ: orada zaten tek overlay var; en yakın ile
      // kök aynı şey.
      Overlay.of(context, rootOverlay: true).insert(_panel!);
    } else {
      _panel!.markNeedsBuild();
    }
  }

  void _ara(String q) {
    // ── ⚠ TUŞ BAŞINA TAM EKRAN YENİDEN ÇİZİM YOK ──
    //
    // Eskiden her harfte `setState` çağrılıyordu: arama kutusunun
    // bulunduğu AĞACIN TAMAMI yeniden çiziliyordu. Öneriler ise
    // kutuda değil, `Overlay` içinde çiziliyor — yani bu yeniden
    // çizimin sonuca hiçbir katkısı yoktu, yalnız kare süresini
    // uzatıyordu ve tuşlar geriden geliyordu.
    //
    // ⚠ Sonuçlar yalnız PANELİ tazeler; kutunun kendisi değişmez.
    _oneriler = SearchService.services(q, enFazla: 200);
    _sonucYok.value = _oneriler.isEmpty && q.trim().isNotEmpty;

    // ── ⚠ YALNIZ WEB: PANEL BİLDİRİMİ ──
    //
    // Web'de panel overlay'de DEĞİL, bu widget'ın `build()`ında
    // çiziliyor ve `_ara` `setState` çağırmıyor (tuş başına yeniden
    // çizim yasağı, testle kilitli). Bu yüzden ekrandaki satırlar
    // güncel `_oneriler` ile senkron kalmıyordu; liste ancak klavye
    // ya da pencere boyu değişince tesadüfen tazeleniyordu.
    //
    // Bildirim YALNIZ web panelini yeniden çizer.
    //
    // ⚠ MOBİL DEĞİŞMEZ: `_web` false iken bu satır hiç çalışmaz.
    if (_web) {
      _webListe.value = _oneriler;
    }

    _paneliTazele();
  }

  void _ac() {
    setState(() => _acik = true);
    // Klavye kutunun kendisine gelir; sayfa DEĞİŞMEZ.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _odak.requestFocus());
  }

  /// ── ⚠ GEÇİCİ TEŞHİS GÜNLÜĞÜ ──
  ///
  /// Web'de arama sonucuna tıklanınca hiçbir şey olmuyor ve olay
  /// zincirinin NEREDE koptuğu koddan okunarak bulunamadı. Bu
  /// satırlar tarayıcı konsoluna basar; hangi adıma kadar
  /// gelindiği görülür.
  ///
  /// ⚠ YALNIZ `--dart-define=ARAMA_IZ=true` İLE: bayrak yoksa hiçbir
  /// şey yazmaz (bkz. `lib/core/arama_izi.dart`). Release derlemede de
  /// ölçüm yapılabilsin diye `kDebugMode`a bağlı DEĞİL.
  ///
  /// ⚠ SORUN BULUNUNCA KALDIRILACAK.
  void _iz(String adim, SearchHit h, [String ek = '']) {
    if (!kAramaIzi) {
      return;
    }
    final hedef = '→ ${h.category} / ${h.subService ?? "-"}';
    aramaIzi(adim, ek.isEmpty ? hedef : '$hedef $ek');
  }

  void _sec(SearchHit h) {
    if (kAramaIzi) {
      _iz('SEARCH_RESULT_SEC', h, 'liste=${_oneriler.length}');
    }
    // ⚠ TEK SEFER: `onPointerDown` ve `onTap` aynı dokunuşta
    // art arda gelebilir. İkinci çağrı yok sayılır.
    if (_oneriler.isEmpty) {
      if (kAramaIzi) {
        aramaIzi('SEARCH_RESULT_SEC', 'ATLANDI (liste boş — tek-sefer koruması)');
      }
      return;
    }
    _odak.unfocus();
    _paneliKaldir();
    setState(() {
      _acik = false;
      _controller.clear();
      _oneriler = const [];
      _sonucYok.value = false;
    });
    if (_web) {
      _webListe.value = const [];
    }
    if (kAramaIzi) {
      _iz('SEARCH_RESULT_CALLBACK', h);
    }
    widget.onSecim(h.category, h.subService);
  }

  /// ── ⚠ YALNIZ WEB: TEK KAPATMA YOLU ──
  ///
  /// Grup dışına dokunma ve Escape buradan geçer. Metin ve sonuçlar
  /// SİLİNMEZ: kullanıcı kutuya tekrar dokunduğunda kaldığı yerden
  /// devam eder (mobildeki odak kaybı davranışıyla aynı sözleşme).
  /// Metni silen tek yol X'tir.
  void _webKapat() {
    if (!mounted) {
      return;
    }
    _odak.unfocus();
    if (_acik) {
      setState(() => _acik = false);
    }
  }

  /// Overlay'de çizilen öneri paneli.
  ///
  /// ⚠ Kutuya `CompositedTransformFollower` ile bağlıdır; kutunun
  /// SOL ALT köşesine yapışır. Kutu kaydıkça panel de kayar.
  ///
  /// ⚠ Yükseklik ekranın yarısına kadar; taşan kısım KAYDIRILIR.
  Widget _panelYap(BuildContext overlayContext) {
    // ⚠ Yükseklik sınırı gövdede hesaplanıyor (_panelGovdesi).
    return Positioned(
      width: _genislik,
      child: CompositedTransformFollower(
        link: _bag,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        // ── ⚠ HİT-TEST ÖLÇÜMÜ ──
        //
        // Panelin EN DIŞINA bir `Listener` konur. Tarayıcıda panelin
        // herhangi bir yerine tıklandığında bu tetiklenir.
        //
        //   · Bu çalışıyor, satırdaki çalışmıyorsa  → sorun SATIRDA
        //   · Bu da çalışmıyorsa                    → sorun ÜST
        //     KATMANDA: panel görünüyor ama işaretçi olayları hiç
        //     ulaşmıyor (overlay / transform / hit-test sınırı).
        //
        // ⚠ OLAYI YUTMAZ: `translucent` ile alttaki satırlar da
        // olayı almaya devam eder; ölçüm davranışı değiştirmez.
        child: _panelGovdesi(overlayContext),
      ),
    );
  }

  /// Panel gövdesi — TEK KAYNAK.
  ///
  /// ⚠ İKİ YOL DA BUNU ÇİZER: mobilde overlay, web'de sayfa ağacı.
  /// Kopyalansaydı biri düzeltilip öteki unutulurdu.
  Widget _panelGovdesi(BuildContext context) {
    final ekran = MediaQuery.of(context).size.height;
    return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (kAramaIzi) {
              aramaIzi('SEARCH_PANEL_POINTER_DOWN',
                  'genel=${izNokta(e.position)} yerel=${izNokta(e.localPosition)}');
            }
          },
          child: Material(
          color: Colors.transparent,
          child: Container(
            // ── ⚠ WEB: YÜKSEKLİK SINIRI YOK, TEK KAYDIRICI SAYFA ──
            //
            // %55 sınırı tarayıcıda (adres/alt çubuk ekranı kısaltıyor)
            // yaklaşık 62 px'lik bir iç kaydırma bırakıyordu: sürüklemeyi
            // iç liste kazanıyor, kısa mesafede durup dış sayfaya
            // devretmiyordu; klavyenin altında kalan satırlara
            // ulaşılamıyordu. Web'de sonuçlar sayfanın parçasıdır ve
            // TÜM kaydırmayı `RefScroll` yapar.
            //
            // ⚠ MOBİL DEĞİŞMEZ: sınır Android/iOS'ta aynen durur.
            constraints:
                _web ? null : BoxConstraints(maxHeight: ekran * 0.55),
            decoration: BoxDecoration(
              color: RC.white,
              border: Border.all(color: const Color(0xFFECEEF2)),
              borderRadius: BorderRadius.circular(RR.r13),
              boxShadow: RS.card,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              // ⚠ WEB: iç liste kaydırmaz; sürükleme sayfaya kalır
              // (arenada iç–dış yarışı olmaz). Mobilde varsayılan fizik.
              physics: _web ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _oneriler.length,
              // ⚠ AYIRICI GÖRÜNMEZ.
              //
              // Kategori ile alt hizmet arasında ÇİZGİ ÇİZİLMEZ; satırlar
              // yine ayrıdır ve her biri KENDİ BAŞINA tıklanabilir, ama
              // kullanıcı aradaki sınırı görmez. Yükseklik 1px'te
              // bırakılır ki satır aralığı bozulmasın.
              separatorBuilder: (_, __) => const SizedBox(height: 1),
              itemBuilder: (_, i) {
                final h = _oneriler[i];
                // ── ⚠ WEB'DE SEÇİM `onPointerDown` İLE ──
                //
                // ## KÖK NEDEN
                //
                // Odak dinleyicisi (`initState`), metin alanı odağı
                // kaybedince paneli KALDIRIYOR. Tarayıcıda öneri
                // satırına tıklandığında sıra şu:
                //
                //   1. Fare düğmesi basılır → metin alanı odağı KAYBEDER
                //   2. Odak dinleyicisi `_paneliKaldir()` çağırır
                //   3. Satır ağaçtan SİLİNİR
                //   4. Fare düğmesi bırakılır → `onTap` ARTIK YOK
                //
                // Tıklama hiç tamamlanmıyor, bu yüzden "hiçbir şey
                // olmuyordu". Dokunmatikte sıralama farklı olduğu için
                // mobilde sorun görünmüyordu.
                //
                // `Listener.onPointerDown` 1. adımda, yani satır daha
                // ayaktayken çalışır. Seçim orada yapılır.
                //
                // ⚠ ÇİFT TETİKLEME YOK: `_sec` paneli kaldırıp listeyi
                // boşaltıyor; `onTap` artık ulaşamaz. Yine de `RefTap`
                // KORUNDU — imleç, hover ve klavye odağı ondan geliyor,
                // klavyeyle Enter'a basan kullanıcı için `onTap` tek
                // yol.
                //
                // ⚠ MOBİL DEĞİŞMEZ: dokunmatikte `onPointerDown` da
                // parmağın değdiği anda çalışır; seçim aynı satırda
                // aynı sonucu verir.
                //
                // ── ⚠ WEB'DE SEÇİM `WebOneriDokunusu` İLE ──
                //
                // Web'de `onPointerDown` seçimi KAPALI (null): telefon
                // tarayıcısında listeyi kaydırmaya başlamak satırı
                // seçiyordu. Web'de seçim, parmak/fare kalktığında ve
                // hareket `kTouchSlop` altında kaldıysa yapılır (bkz.
                // `lib/ui/web_oneri_dokunusu.dart`).
                //
                // ⚠ MOBİL AĞAÇ BİREBİR AYNI: `_web` false iken
                // `Listener` aynı `onPointerDown` ile döner, sarmalayıcı
                // eklenmez.
                final satir = Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _web
                      ? null
                      : (_) {
                          if (kAramaIzi) {
                            _iz('SEARCH_RESULT_POINTER_DOWN', h, 'yol=mobil');
                          }
                          _sec(h);
                        },
                  child: RefTap(
                  // Her satır AYRI dokunma hedefidir.
                  onTap: () {
                    if (kAramaIzi) {
                      _iz('SEARCH_RESULT_INKWELL_TAP', h);
                    }
                    _sec(h);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    // ⚠ ALT BAŞLIK GÖSTERİLMEZ.
                    //
                    // Alt hizmetin ana kategorisi (`h.category`) ARKA
                    // PLANDA kullanılmaya devam eder — seçim yapıldığında
                    // `_sec(h)` kategori + alt hizmet ikilisini olduğu gibi
                    // taşır. Kullanıcıya yalnız aranan başlık gösterilir.
                    //
                    child: Text(kategoriEtiketi(h.label),
                        style: refText(
                            size: RF.s145,
                            weight: RF.w600,
                            color: RC.text)),
                  ),
                  ),
                );
                if (_web) {
                  return WebOneriDokunusu(
                    onSec: () {
                      if (kAramaIzi) {
                        _iz('SEARCH_RESULT_WEB_UP', h, 'WebOneriDokunusu→_sec');
                      }
                      _sec(h);
                    },
                    izEtiketi:
                        kAramaIzi ? '${h.subService ?? h.category}' : null,
                    child: satir,
                  );
                }
                return satir;
              },
            ),
          ),
        ),
        );
  }

  /// X düğmesi — TEK KAYNAK (mobil ve web aynı düğmeyi çizer).
  Widget _temizleDugmesi() {
    return RefTap(
      // ── ⚠ X = TEMİZLE + KAPAT + SIFIRLA ──
      //
      // Önce yalnız metin siliniyordu; overlay paneli AÇIK
      // kalıyordu. Artık panel de kaldırılır ve kutu
      // başlangıç durumuna döner.
      //
      // ⚠ İKON VE TASARIM DEĞİŞMEDİ — yalnız davranış.
      onTap: () {
        _controller.clear();
        _ara('');
        _paneliKaldir();
        _odak.unfocus();
        setState(() {
          _acik = false;
          _oneriler = const [];
          _sonucYok.value = false;
        });
      },
      borderRadius: BorderRadius.circular(RR.circle),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: RefSvg('assets/svg/ic_x.svg', size: 20),
      ),
    );
  }

  /// Ölçüm: kapalı kutunun altına şerit ekler (açık kutuda şerit
  /// kutunun kendi sütununda). ⚠ Bayrak kapalıyken `_ciz`in sonucu
  /// OLDUĞU GİBİ döner — ağaç değişmez.
  @override
  Widget build(BuildContext context) {
    final govde = _ciz(context);
    if (_acik) {
      return govde;
    }
    return _izSeridiEkle(govde);
  }

  Widget _ciz(BuildContext context) {
    // ── KAPALI: referans görünümü korunur ──
    if (!_acik) {
      return RefSearchBox(
        title: widget.title,
        subtitle: widget.subtitle,
        onTap: _ac,
      );
    }

    // ── AÇIK: aynı kutu yazılabilir, panel ÜSTTE çizilir ──
    //
    // ⚠ Column artık YALNIZ kutuyu ve "sonuç bulunamadı" satırını
    // taşır. Öneri paneli overlay'de; bu yüzden sayfa itilmiyor.
    return CompositedTransformTarget(
      link: _bag,
      child: _webSarmala(Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
              const RefSvg('assets/svg/ic_search.svg',
                  size: 23, color: Color(0xFFA8ADB4)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _odak,
                  // ⚠ WEB: metin alanı kutuya özgü gruba girer; panele
                  // ya da X'e dokunmak alanın "dışı" sayılmaz ve odağı
                  // düşürmez. Mobilde varsayılan grup (`EditableText`).
                  groupId: _web ? _grup : EditableText,
                  onChanged: _ara,
                  textInputAction: TextInputAction.search,
                  style: refText(
                      size: 14.5, weight: RF.w500, color: RC.text),
                  // ⚠ İKİNCİ MAVİ ÇERÇEVE KÖK NEDENİ
                  //
                  // Global `inputDecorationTheme` odaklanmada mavi
                  // odak çerçevesi (1.4px mavi outline) ve
                  // `filled: true` uygular. Yalnız `border:` vermek
                  // BUNU EZMEZ — durum border'ları temadan gelmeye
                  // devam eder ve dış kutunun İÇİNDE ikinci bir
                  // çerçeve çizilir.
                  //
                  // Bu yüzden TÜM durum border'ları açıkça kapatılır
                  // ve dolgu devre dışı bırakılır; görünen tek kutu
                  // dıştaki `Container`'dır.
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: widget.title,
                    hintStyle: refText(
                        size: 14.5,
                        weight: RF.w400,
                        color: const Color(0xFF9AA0A6)),
                  ),
                ),
              ),
              // ── ⚠ WEB: X DÜĞMESİ METNİ KENDİSİ DİNLER ──
              //
              // Web'de `_ara` `setState` çağırmadığı için X, metin
              // yazıldığında belirmiyordu. Burada denetleyicinin kendisi
              // dinlenir; yalnız bu düğme yeniden çizilir.
              //
              // ⚠ X, `_webSarmala`daki kutu grubunun içinde: web'de X'e
              // basmak "dışarı dokunma" sayılmaz, dokunuş tamamlanır.
              //
              // ⚠ MOBİL DEĞİŞMEZ: `else` dalı önceki koşulun ve düğmenin
              // BİREBİR aynısıdır.
              if (_web)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, deger, __) => deger.text.isNotEmpty
                      ? _temizleDugmesi()
                      : const SizedBox.shrink(),
                )
              else if (_controller.text.isNotEmpty)
                _temizleDugmesi(),
            ],
          ),
        ),

        // Ölçüm şeridi: kutunun HEMEN altında (bayrak kapalıyken yok).
        if (kAramaIzi && _web) const AramaIziSeridi(),

        // ⚠ WEB'DE PANEL BURADA: sayfanın kendi ağacında, kutunun
        // hemen altında. Mobilde bu dal hiç çalışmaz (overlay
        // kullanılır) ve sayfa düzeni değişmez.
        //
        // ⚠ Panel `_webSarmala`daki kutu grubunun içinde: satıra ya da
        // satır arası boşluğa dokunmak "dışarı dokunma" sayılmaz ve
        // paneli kapatmaz. Odak düşse bile panel kapanmaz (bkz. odak
        // dinleyicisi); seçim parmak kalkınca tamamlanır.
        //
        // ⚠ `ValueListenableBuilder`: panel `_webListe` değiştikçe
        // yeniden çizilir (bkz. `_ara`); kutunun geri kalanı çizilmez.
        if (_web)
          ValueListenableBuilder<List<SearchHit>>(
            valueListenable: _webListe,
            builder: (context, liste, _) => liste.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    // Ölçüm: panelin genel dikdörtgeni için anahtar
                    // (bayrak kapalıyken anahtar YOK — ağaç aynı).
                    key: kAramaIzi ? _izPanelAnahtari : null,
                    padding: const EdgeInsets.only(top: 6),
                    child: _panelGovdesi(context),
                  ),
          ),

        // Yazı var ama eşleşme yok.
        ValueListenableBuilder<bool>(
          valueListenable: _sonucYok,
          builder: (_, yok, __) => yok
              ? Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Text('Sonuç bulunamadı',
                      style: refText(
                          size: RF.s135,
                          weight: RF.w400,
                          color: RC.textSoft)),
                )
              : const SizedBox.shrink(),
        ),
      ],
      )),
    );
  }

  /// Ölçüm şeridi (kapalı kutu için). ⚠ Bayrak kapalıysa ya da mobilde
  /// çocuk OLDUĞU GİBİ döner — ağaca düğüm eklenmez.
  Widget _izSeridiEkle(Widget cocuk) {
    if (!(kAramaIzi && _web)) {
      return cocuk;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [cocuk, const AramaIziSeridi()],
    );
  }

  /// ── ⚠ YALNIZ WEB: KAPANMA KURALI SARMALAYICISI ──
  ///
  /// Açık kutunun TAMAMI (metin alanı + X + panel + "sonuç yok")
  /// `_grup` dokunma bölgesidir:
  ///   · grubun İÇİNE dokunmak paneli kapatmaz,
  ///   · grubun DIŞINA dokunmak `_webKapat` ile kapatır,
  ///   · Escape `_webKapat` ile kapatır.
  ///
  /// ⚠ MOBİL DEĞİŞMEZ: `_web` false iken çocuk OLDUĞU GİBİ döner;
  /// mobil ağaçta tek bir düğüm bile eklenmez.
  Widget _webSarmala(Widget cocuk) {
    if (!_web) {
      return cocuk;
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (kAramaIzi) {
            aramaIzi('SEARCH_PANEL_CLOSE_OUTSIDE', 'neden=Escape');
          }
          _webKapat();
        },
      },
      child: TapRegion(
        groupId: _grup,
        onTapOutside: (e) {
          if (kAramaIzi) {
            final panel = izGenelRect(_izPanelAnahtari.currentContext);
            final grup = izGenelRect(context);
            aramaIzi(
                'SEARCH_PANEL_CLOSE_OUTSIDE',
                'neden=onTapOutside id=${e.pointer} tur=${e.kind.name} '
                    'genel=${izNokta(e.position)} '
                    'panel=${izRect(panel)} '
                    'inside=${panel?.contains(e.position) ?? false} '
                    'kutu+panel=${izRect(grup)} '
                    'insideKutu=${grup?.contains(e.position) ?? false}');
          }
          _webKapat();
        },
        child: cocuk,
      ),
    );
  }
}
