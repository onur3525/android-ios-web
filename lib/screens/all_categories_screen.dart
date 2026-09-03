import 'package:flutter/material.dart';

import '../data/category_tree.dart';
import '../data/services/search_service.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'category_ui.dart';
import 'home_screen.dart' show hizmetSecildiDisaridan;

/// TÜM KATEGORİLER — 54 ana kategorinin tamamı.
///
/// ⚠ NİÇİN VAR: ana ekranda yalnız 12 hızlı erişim kartı gösterilir.
/// Bu ekran olmasaydı kalan 41 kategori YALNIZ arama ile bulunabilir,
/// göz gezdirerek keşfedilemezdi.
///
/// ⚠ YENİ MİMARİ KURULMADI. Ekran mevcut tasarım diline uyar:
/// `RefDetailHeader` başlık, `RefTap` satırlar, aynı tipografi. Kart
/// düzeni Hizmet Kategorilerim ekranındaki `.po-row` ile aynıdır.
///
/// Dokunulan kategori ana ekrandaki kartla AYNI akışa girer
/// (`hizmetSecildiDisaridan`) — iki yerde iki farklı davranış olmaz.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final _ara = TextEditingController();

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  /// GÖRÜNEN SATIRLAR.
  ///
  /// ⚠ ARAMA ARTIK ALT HİZMETLERİ DE LİSTELER.
  ///
  /// Önceden yalnız ANA KATEGORİLER süzülüyordu: "kombi" yazan
  /// kullanıcı tek bir `Kombi Servis` satırı görüyor, o kategorinin
  /// altındaki `Kombi Montajı`, `Kombi Bakımı`, `Petek Temizliği`
  /// satırlarını GÖREMİYORDU. Oysa aradığı çoğu zaman alt hizmetin
  /// kendisidir.
  ///
  /// Kural artık ana sayfadaki arama çubuğuyla AYNI kaynaktan gelir
  /// (`SearchService.services`): kategori adı, alt hizmet adı ve eş
  /// anlamlı terimler eşleşir; bir ANA KATEGORİ eşleşirse altındaki
  /// TÜM hizmetler ayrı satır olarak listelenir.
  ///
  /// ⚠ SONUÇ SINIRI YÜKSELTİLDİ. Ana sayfadaki kutu 40 sonuçta keser
  /// çünkü küçük bir açılır alandır. Burası TAM EKRAN liste; kesme
  /// kullanıcıdan sonuç saklar. Katalog 53 + 251 kayıt olduğu için
  /// üst sınır güvenli bir tavan olarak verilir.
  List<SearchHit> get _gorunen {
    final q = _ara.text.trim();
    if (q.isEmpty) {
      // Arama yokken ekran KATALOĞU gezdirir: 54 ana kategori.
      return [for (final c in kTreeCategories) SearchHit(c)];
    }
    return SearchService.services(q, enFazla: 400);
  }

  @override
  Widget build(BuildContext context) {
    final liste = _gorunen;
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: RefDetailHeader(title: 'Tüm Kategoriler'),
          ),

          // `.po-search` — Hizmet Kategorilerim ekranıyla aynı kutu.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: const Color(0xFFE1E5EC)),
                borderRadius: BorderRadius.circular(RR.r13),
              ),
              child: Row(children: [
                const RefSvg('assets/svg/ic_search.svg',
                    size: 19, color: Color(0xFF98A2B3)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ara,
                    style: refText(
                        size: RF.s145, weight: RF.w500, color: RC.text),
                    decoration: InputDecoration(
                      isDense: true,
                      // ⚠ DÖRT KENARLIK DA KAPATILIR.
                      //
                      // `border: InputBorder.none` TEK BAŞINA YETMEZ: tema
                      // `inputDecorationTheme` içinde `enabledBorder` ve
                      // `focusedBorder` AYRI tanımlıdır ve `border`'ı ezer.
                      // Alan odaklanınca dış kutunun İÇİNDE ikinci bir mavi
                      // çerçeve çiziliyordu.
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 13),
                      hintText: 'Kategori ara...',
                      hintStyle: refText(
                          size: RF.s145,
                          weight: RF.w500,
                          color: const Color(0xFF98A2B3)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_ara.text.isNotEmpty)
                  RefTap(
                    onTap: () => setState(_ara.clear),
                    borderRadius: BorderRadius.circular(RR.circle),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF0F4),
                        shape: BoxShape.circle,
                      ),
                      child: const RefSvg('assets/svg/ic_close.svg',
                          size: 13, color: RC.textSoft),
                    ),
                  ),
              ]),
            ),
          ),

          const SizedBox(height: 2),

          Expanded(
            child: liste.isEmpty
                ? const Center(
                    child: SysStateBenzeri(
                      baslik: 'Sonuç bulunamadı',
                      aciklama: 'Farklı bir arama deneyiniz.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final h = liste[i];
                      // ⚠ Alt hizmet satırında da KATEGORİ İKONU kullanılır:
                      // alt hizmetlerin ayrı ikonu yoktur, bağlı olduğu
                      // kategorinin ikonu doğru görseldir.
                      final c = h.category;
                      return RefTap(
                        onTap: () => hizmetSecildiDisaridan(
                            context, h.category, h.subService),
                        borderRadius: BorderRadius.circular(RR.r13),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: RC.white,
                            border: Border.all(color: RC.border),
                            borderRadius: BorderRadius.circular(RR.r13),
                          ),
                          child: Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF3FA),
                                borderRadius: BorderRadius.circular(RR.r10),
                              ),
                              child: RefSvg(categoryIcon(c),
                                  size: 20, color: RC.blue),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(kategoriEtiketi(h.label),
                                      style: refText(
                                          size: RF.s145,
                                          weight: RF.w700,
                                          color: RC.text)),
                                ],
                              ),
                            ),
                            const RefSvg('assets/svg/ic_chev.svg',
                                size: 16, color: Color(0xFFD3D8E0)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Basit boş durum — bu ekrana özel, `SysState` bağımlılığı olmadan.
class SysStateBenzeri extends StatelessWidget {
  const SysStateBenzeri({
    super.key,
    required this.baslik,
    required this.aciklama,
  });

  final String baslik;
  final String aciklama;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(baslik,
              style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 6),
          Text(aciklama,
              style:
                  refText(size: RF.s135, weight: RF.w400, color: RC.textSoft)),
        ],
      );
}
