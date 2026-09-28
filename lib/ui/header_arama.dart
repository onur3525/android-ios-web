import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/services/search_service.dart';
import '../screens/home_screen.dart' show hizmetSecildi;
import 'ref_tokens.dart';
import 'ref_widgets.dart';
import 'web_oneri_dokunusu.dart';

/// ═══════════════════════════════════════════════════════════════
/// HEADER ARAMASI — MASAÜSTÜ WEB
///
/// ## ⚠ `InlineSearchBox`IN KOPYASI DEĞİL, KARDEŞİ
///
/// Ana sayfadaki kutu (başlık + alt yazı + altta açılan geniş panel)
/// bir SAYFA BİLEŞENİDİR; header'a sığmaz. Burada dar bir alan ve
/// üstte duran bir katman gerekiyor.
///
/// ⚠ ARAMA MOTORU AYNI: ikisi de `SearchService.services` çağırır.
/// İkinci bir arama mantığı yazılmadı.
///
/// ⚠ YÖNLENDİRME AYNI: seçim `hizmetSecildi` ile yapılır — ana
/// sayfanın ve Tüm Kategoriler ekranının kullandığı yol. Çıkar
/// çatışması kuralı (hizmet verenin kendi alanında ilan açamaması)
/// o fonksiyonun içinde; ikinci bir yol yazmak kuralı bir kopyada
/// unutmak olurdu.
///
/// ## ⚠ ÖNERİ KATMANI `OverlayEntry` İLE
///
/// Panel header'ın altına düşer. Widget ağacının içinde çizilseydi
/// header'ın yüksekliği ve `ClipRect`i tarafından KESİLİRDİ.
/// `Overlay` sayfanın en üstünde durur, hiçbir şey kesmez.
///
/// ## ⚠ KAPANMA YOLLARI
///
///   · Esc                → klavye
///   · Dışarı tıklama     → katmanın altındaki saydam engel
///   · Öneri seçimi       → seçimden sonra
///   · Odak kaybı         → başka alana geçince
///
/// Dördü de aynı `_kapat`a gider; ayrı yollar olsaydı biri
/// düzeltilip öteki unutulurdu.
///
/// ## ⚠ ENTER
///
/// İlk öneriyi seçer. Web'de Enter'ın "ara" demesi beklenir; öneri
/// yoksa hiçbir şey yapmaz — boş bir sonuç sayfasına gitmez, çünkü
/// uygulamada öyle bir sayfa yok ve uydurulmadı.
/// ═══════════════════════════════════════════════════════════════
class HeaderArama extends StatefulWidget {
  const HeaderArama({super.key, this.genislik = 420});

  /// Kutunun genişliği — header laptop genişliğinde daraltır.
  final double genislik;

  @override
  State<HeaderArama> createState() => _HeaderAramaState();
}

class _HeaderAramaState extends State<HeaderArama> {
  final _kontrol = TextEditingController();
  final _odak = FocusNode();
  final _baglanti = LayerLink();

  OverlayEntry? _katman;
  List<SearchHit> _oneriler = const [];

  @override
  void initState() {
    super.initState();
    _odak.addListener(() {
      if (!_odak.hasFocus) {
        _kapat();
      }
    });
  }

  @override
  void dispose() {
    _kapat();
    _kontrol.dispose();
    _odak.dispose();
    super.dispose();
  }

  void _yaz(String q) {
    final metin = q.trim();
    if (metin.length < 2) {
      // ⚠ TEK HARFTE ARAMA YAPILMAZ: yüzlerce sonuç döner ve panel
      // işe yaramaz hâle gelir. Ana sayfadaki kutuyla aynı eşik.
      _oneriler = const [];
      _kapat();
      return;
    }
    _oneriler = SearchService.services(metin, enFazla: 12);
    if (_oneriler.isEmpty) {
      _kapat();
      return;
    }
    _ac();
  }

  void _ac() {
    _katman?.remove();
    _katman = OverlayEntry(builder: _katmanCiz);
    // ⚠ KÖK OVERLAY (bkz. `inline_search_box`): kabuk katmanları
    // araya girmesin, işaretçi olayları panele ulaşsın.
    Overlay.of(context, rootOverlay: true).insert(_katman!);
  }

  void _kapat() {
    _katman?.remove();
    _katman = null;
  }

  void _sec(SearchHit h) {
    // ⚠ TEK SEFER: `onPointerDown` ve `onTap` art arda gelebilir.
    if (_oneriler.isEmpty) {
      return;
    }
    _kapat();
    _kontrol.clear();
    _oneriler = const [];
    _odak.unfocus();
    // ⚠ ORTAK YÖNLENDİRME — bkz. sınıf notu.
    hizmetSecildi(context, h.category, h.subService);
  }

  void _enter() {
    if (_oneriler.isNotEmpty) {
      _sec(_oneriler.first);
    }
  }

  Widget _katmanCiz(BuildContext _) => Stack(
        children: [
          // ⚠ DIŞARI TIKLAMA ENGELİ: tüm sayfayı kaplar ama görünmez.
          // Panelin kendisi bunun ÜSTÜNDE çizilir.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _kapat();
                _odak.unfocus();
              },
            ),
          ),
          CompositedTransformFollower(
            link: _baglanti,
            showWhenUnlinked: false,
            // ⚠ KUTUNUN HEMEN ALTINA: 6 px boşluk.
            offset: const Offset(0, 46),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: RC.white,
                elevation: 8,
                shadowColor: const Color(0x1A16233D),
                borderRadius: BorderRadius.circular(RR.r12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: widget.genislik,
                  child: ConstrainedBox(
                    // ⚠ UZUN LİSTE PANELİ EKRANDAN TAŞIRMASIN.
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _oneriler.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, thickness: 1, color: Color(0xFFF2F4F7)),
                      // ⚠ AYNI KÖK NEDEN (bkz. `inline_search_box`):
                      // fare basıldığı anda metin alanı odağı kaybeder,
                      // odak dinleyicisi paneli kaldırır ve satır
                      // silinir; `onTap` hiç çalışamaz. Seçim
                      // `onPointerDown` ile, satır daha ayaktayken
                      // yapılır.
                      //
                      // ⚠ `onTap` KORUNDU: klavyeyle gezip Enter'a
                      // basan kullanıcı için tek yol.
                      //
                      // ⚠ SEÇİM ARTIK `WebOneriDokunusu` İLE (ana sayfa
                      // kutusunun web yoluyla TEK KAYNAK): parmak/fare
                      // kalkınca ve hareket `kTouchSlop` altındaysa.
                      // İşaretçinin kalkış olayı basıldığı andaki isabet
                      // yoluna gittiği için panel odak kaybıyla
                      // kaldırılsa bile seçim tamamlanır.
                      //
                      // ⚠ ÖNERİ ÇİZİM ANINDA YAKALANIR: `_sec` listeyi
                      // boşaltır; aynı dokunuşta satırın `onTap`ı da
                      // gelirse `_oneriler[i]` boş listede RangeError
                      // atardı. Yakalanan `h` ile `_sec` tek-sefer
                      // korumasına ulaşır ve sessizce döner.
                      itemBuilder: (_, i) {
                        final h = _oneriler[i];
                        return WebOneriDokunusu(
                          onSec: () => _sec(h),
                          child: _OneriSatiri(
                            hit: h,
                            onTap: () => _sec(h),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
        link: _baglanti,
        child: SizedBox(
          width: widget.genislik,
          height: 40,
          // ⚠ ESC İLE KAPANIR — panelle aynı kural.
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _kapat();
                _odak.unfocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _kontrol,
              focusNode: _odak,
              onChanged: _yaz,
              onSubmitted: (_) => _enter(),
              textInputAction: TextInputAction.search,
              style: refText(size: RF.s135, weight: RF.w500, color: RC.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Hangi hizmete ihtiyacınız var?',
                hintStyle:
                    refText(size: RF.s135, weight: RF.w400, color: RC.textSoft),
                filled: true,
                fillColor: RC.pageBg,
                prefixIcon: const Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: RefSvg('assets/svg/ic_search.svg',
                      size: 18, color: RC.textSoft),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RR.r12),
                  borderSide: const BorderSide(color: RC.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RR.r12),
                  borderSide: const BorderSide(color: RC.border),
                ),
                // ⚠ ODAKTA BELİRGİN KENARLIK: klavye kullanıcısı
                // nerede olduğunu görmeli.
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RR.r12),
                  borderSide: const BorderSide(color: RC.blue, width: 1.4),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Panel içindeki tek öneri satırı.
class _OneriSatiri extends StatelessWidget {
  const _OneriSatiri({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ⚠ ALIAS YALNIZ GÖSTERİM: seçim akışına giden değerler daima
    // `category` ve `subService` (bkz. `SearchHit` notu).
    final baslik = hit.subService ?? hit.category;
    final alt = hit.aliasEtiketi != null
        ? '${hit.category} · ${hit.aliasEtiketi}'
        : hit.category;
    return RefTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const RefSvg('assets/svg/ic_search.svg',
                size: 16, color: RC.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s135, weight: RF.w600, color: RC.text)),
                  Text(alt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s12, weight: RF.w400, color: RC.textSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
