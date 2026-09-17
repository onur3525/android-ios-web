import 'package:flutter/material.dart';

import '../../data/category_tree.dart';
import '../../data/services/search_service.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

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
      _panel = OverlayEntry(builder: _panelYap);
      Overlay.of(context).insert(_panel!);
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

    _paneliTazele();
  }

  void _ac() {
    setState(() => _acik = true);
    // Klavye kutunun kendisine gelir; sayfa DEĞİŞMEZ.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _odak.requestFocus());
  }

  void _sec(SearchHit h) {
    _odak.unfocus();
    _paneliKaldir();
    setState(() {
      _acik = false;
      _controller.clear();
      _oneriler = const [];
      _sonucYok.value = false;
    });
    widget.onSecim(h.category, h.subService);
  }

  /// Overlay'de çizilen öneri paneli.
  ///
  /// ⚠ Kutuya `CompositedTransformFollower` ile bağlıdır; kutunun
  /// SOL ALT köşesine yapışır. Kutu kaydıkça panel de kayar.
  ///
  /// ⚠ Yükseklik ekranın yarısına kadar; taşan kısım KAYDIRILIR.
  Widget _panelYap(BuildContext overlayContext) {
    final ekran = MediaQuery.of(overlayContext).size.height;
    return Positioned(
      width: _genislik,
      child: CompositedTransformFollower(
        link: _bag,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
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
                return RefTap(
                  // Her satır AYRI dokunma hedefidir.
                  onTap: () => _sec(h),
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
                );
              },
            ),
          ),
        ),
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
              if (_controller.text.isNotEmpty)
                RefTap(
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
                ),
            ],
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
