import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
  });

  final String title;
  final String subtitle;

  /// Kullanıcı bir öneriye dokundu: (ana kategori, alt hizmet?).
  final void Function(String category, String? subService) onSecim;

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

  /// Kutunun genişliği — panel onunla aynı genişlikte olmalı.
  double _genislik = 0;

  @override
  void initState() {
    super.initState();
    _odak.addListener(() {
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
      if (kIsWeb) {
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
    // ⚠ MOBİL DEĞİŞMEZ: `kIsWeb` false iken bu satır hiç çalışmaz.
    if (kIsWeb) {
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
  /// ⚠ YALNIZ DEBUG: `kDebugMode` dışında hiç çalışmaz, üretim
  /// paketine çıktı sızmaz.
  ///
  /// ⚠ SORUN BULUNUNCA KALDIRILACAK.
  void _iz(String adim, SearchHit h) {
    if (kDebugMode) {
      debugPrint('$adim → ${h.category} / ${h.subService ?? "-"}');
    }
  }

  void _sec(SearchHit h) {
    _iz('SEARCH_RESULT_SEC', h);
    // ⚠ TEK SEFER: `onPointerDown` ve `onTap` aynı dokunuşta
    // art arda gelebilir. İkinci çağrı yok sayılır.
    if (_oneriler.isEmpty) {
      if (kDebugMode) {
        debugPrint('SEARCH_RESULT_SEC_ATLANDI (liste boş)');
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
    if (kIsWeb) {
      _webListe.value = const [];
    }
    _iz('SEARCH_RESULT_CALLBACK', h);
    widget.onSecim(h.category, h.subService);
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
            if (kDebugMode) {
              debugPrint('SEARCH_PANEL_POINTER_DOWN → ${e.localPosition}');
            }
          },
          child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxHeight: ekran * 0.55),
            decoration: BoxDecoration(
              color: RC.white,
              border: Border.all(color: const Color(0xFFECEEF2)),
              borderRadius: BorderRadius.circular(RR.r13),
              boxShadow: RS.card,
            ),
            child: ListView.separated(
              shrinkWrap: true,
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
                // ⚠ MOBİL AĞAÇ BİREBİR AYNI: `kIsWeb` false iken
                // `Listener` aynı `onPointerDown` ile döner, sarmalayıcı
                // eklenmez.
                final satir = Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: kIsWeb
                      ? null
                      : (_) {
                          _iz('SEARCH_RESULT_POINTER_DOWN', h);
                          _sec(h);
                        },
                  child: RefTap(
                  // Her satır AYRI dokunma hedefidir.
                  onTap: () {
                    _iz('SEARCH_RESULT_TAP', h);
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
                if (kIsWeb) {
                  return WebOneriDokunusu(
                    onSec: () {
                      _iz('SEARCH_RESULT_WEB_UP', h);
                      _sec(h);
                    },
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

  @override
  Widget build(BuildContext context) {
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
      child: Column(
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
              // ⚠ `TextFieldTapRegion`: X metin alanının dokunma bölgesine
              // alınır; aksi hâlde web'de X'e basmak önce odağı düşürüp
              // kutuyu kapatıyor, X'in dokunuşu tamamlanamıyordu.
              //
              // ⚠ MOBİL DEĞİŞMEZ: `else` dalı önceki koşulun ve düğmenin
              // BİREBİR aynısıdır.
              if (kIsWeb)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, deger, __) => deger.text.isNotEmpty
                      ? TextFieldTapRegion(child: _temizleDugmesi())
                      : const SizedBox.shrink(),
                )
              else if (_controller.text.isNotEmpty)
                _temizleDugmesi(),
            ],
          ),
        ),

        // ⚠ WEB'DE PANEL BURADA: sayfanın kendi ağacında, kutunun
        // hemen altında. Mobilde bu dal hiç çalışmaz (overlay
        // kullanılır) ve sayfa düzeni değişmez.
        //
        // ⚠ `TextFieldTapRegion`: panel, metin alanının dokunma
        // bölgesine DAHİL edilir. Flutter web'de metin alanı dışına
        // yapılan dokunuş (dokunmatik dahil) odağı düşürüyor; panel
        // bölge dışında sayıldığı için satıra dokunmak odağı
        // kaybettirip paneli kaldırıyordu. Artık satıra dokunmak
        // "dışarı dokunma" sayılmaz.
        //
        // ⚠ `ValueListenableBuilder`: panel `_webListe` değiştikçe
        // yeniden çizilir (bkz. `_ara`); kutunun geri kalanı çizilmez.
        if (kIsWeb)
          ValueListenableBuilder<List<SearchHit>>(
            valueListenable: _webListe,
            builder: (context, liste, _) => liste.isEmpty
                ? const SizedBox.shrink()
                : TextFieldTapRegion(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _panelGovdesi(context),
                    ),
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
      ),
    );
  }
}
