// HİZMET ALANI EKRANI — BİR ÇATININ KATEGORİLERİ
//
// ⚠ ÇATI KATEGORİ DEĞİLDİR. Bu ekran yeni bir katalog seviyesi
// göstermez; yalnız o çatıya bağlı MEVCUT kategorileri listeler.
// Kullanıcı bir kategoriye dokununca zaten var olan kategori
// ekranına gider — akış değişmez.
//
// ⚠ Kategori adları katalogla BİREBİR aynı kimliktir; ekranda
// `kategoriEtiketi` ile kısaltılmış hâli görünür ama dokunma
// kimliği taşır.

import 'package:flutter/material.dart';

import '../data/category_tree.dart';
// ⚠ `kSubServices` burada tanımlı (kCategoryTree'nin takma adı).
import '../data/izmir.dart';
import '../data/hizmet_alanlari.dart';
import '../data/services/search_service.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'category_screen.dart';
import 'category_ui.dart';
import '../ui/panel_rotasi.dart';
import '../ui/web_panel.dart';

class HizmetAlaniScreen extends StatefulWidget {
  const HizmetAlaniScreen({super.key, required this.alan});

  final HizmetAlani alan;

  @override
  State<HizmetAlaniScreen> createState() => _HizmetAlaniScreenState();
}

class _HizmetAlaniScreenState extends State<HizmetAlaniScreen> {
  final _ara = TextEditingController();
  String _sorgu = '';

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  /// ── ⚠ ARAMA YALNIZ BU ÇATININ İÇİNDE ──
  ///
  /// Ortak arama servisi TÜM katalogu tarar; burada sonuçlar bu
  /// çatıya bağlı kategorilere DARALTILIR. Kullanıcı "Ev Hizmeti"
  /// ekranında "parke" yazınca araç ya da eğitim kategorisi
  /// görmemeli.
  ///
  /// ⚠ HİZMET ADIYLA da bulunur: "kolon hattı" yazan kullanıcı
  /// Doğalgaz kategorisini görür, çünkü o hizmet oraya bağlıdır.
  /// Kategori adını ezberlemek zorunda kalmaz.
  /// ⚠ ÇATININ GERÇEK KAPSAMI — kategori listesi YETMEZ.
  ///
  /// Hizmet düzeyinde istisna var: bir kategori bu çatıda olmasa da
  /// içindeki bir hizmet buraya yönlenmiş olabilir (Oto Anahtarcı),
  /// ya da bu çatıdaki bir kategorinin bir hizmeti başka çatıya
  /// gitmiş olabilir (Araç Döşeme Yıkama). Kapsam merkezi
  /// `alanHizmetleri` ile çözülür.
  late final List<({String kategori, String hizmet})> _kapsam =
      alanHizmetleri(widget.alan.ad);

  /// Bu çatıda GÖRÜNECEK kategoriler (sıra: çatının kendi sırası,
  /// sonra istisna ile gelenler).
  late final List<String> _kategoriler = () {
    final varOlan = _kapsam.map((e) => e.kategori).toSet();
    final out = [
      for (final c in widget.alan.kategoriler)
        if (varOlan.contains(c)) c
    ];
    for (final e in _kapsam) {
      if (!out.contains(e.kategori)) {
        out.add(e.kategori);
      }
    }
    return out;
  }();

  List<String> get _sonuc {
    final q = _sorgu.trim();
    if (q.isEmpty) {
      return _kategoriler;
    }
    // ⚠ Ortak arama servisi TÜM katalogu tarar; sonuç bu çatının
    // GERÇEK kapsamına daraltılır — kategori adına göre değil,
    // hizmet-çatı çözümüne göre.
    final izin = {for (final e in _kapsam) '${e.kategori}|${e.hizmet}'};
    final out = <String>[];
    for (final h in SearchService.services(q, enFazla: 400)) {
      final alt = h.subService;
      final uygun = alt == null
          // Kategori satırı: kategorinin bu çatıda hizmeti varsa.
          ? _kategoriler.contains(h.category)
          : izin.contains('${h.category}|$alt');
      if (uygun && !out.contains(h.category)) {
        out.add(h.category);
      }
    }
    return out;
  }

  /// ── ⚠ ARAMA SONUCU HİZMET DÜZEYİNDEDİR ──
  ///
  /// Eskiden sonuç KATEGORİ adına indirgeniyordu: kullanıcı "Garson"
  /// yazınca "Etkinlik Personeli" kategorisi çıkıyor, sonra o
  /// kategoriye girip listeden "Garson"u ikinci kez bulması
  /// gerekiyordu.
  ///
  /// Artık aranan hizmetin KENDİSİ listelenir; dokununca kategori
  /// ekranı o hizmet SEÇİLİ açılır ve ilan akışı doğrudan başlar.
  ///
  /// ⚠ ÇATI SINIRI KORUNUR: `izin` kümesi hizmet-çatı çözümünden
  /// gelir. Organizasyon çatısındayken "Kombi" arayan sonuç almaz.
  ///
  /// ⚠ TEKRAR ELENİR: aynı hizmet iki kez listelenmez.
  List<({String kategori, String hizmet})> get _hizmetSonucu {
    final q = _sorgu.trim();
    if (q.isEmpty) {
      return const [];
    }
    final izin = {for (final e in _kapsam) '${e.kategori}|${e.hizmet}'};
    final out = <({String kategori, String hizmet})>[];
    final gorulen = <String>{};
    for (final h in SearchService.services(q, enFazla: 400)) {
      final alt = h.subService;
      // ⚠ YALNIZ HİZMET SATIRI: kategori eşleşmeleri burada
      // listelenmez, onlar kategori listesinde zaten var.
      if (alt == null) {
        continue;
      }
      final anahtar = '${h.category}|$alt';
      if (!izin.contains(anahtar) || !gorulen.add(anahtar)) {
        continue;
      }
      out.add((kategori: h.category, hizmet: alt));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final kategoriler = _sonuc;
    final hizmetler = _hizmetSonucu;
    return RefPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠ WEB PANELİNDE GERİ OKU GÖRÜNÜR (akış içi): X akışın
          // tamamını kapatır, bir önceki ekrana dönmek bu okla. Sıradan
          // `RefBackButton` panelde kendini gizlediği için `akisIci`
          // kullanılır. Mobilde `panelMi` hep false → önceki düğme aynen.
          Align(
            alignment: Alignment.centerLeft,
            child: WebPanel.panelMi(context)
                ? RefBackButton.akisIci(
                    onTap: () => Navigator.of(context).pop())
                : RefBackButton(onTap: () => Navigator.of(context).pop()),
          ),
          const SizedBox(height: 6),
          RefPageTitle(widget.alan.ad, geriDugmesi: false),
          RefSubtitle(widget.alan.aciklama),
          const SizedBox(height: 14),

          // ── ⚠ ARAMA — ANA EKRANDAKİ ÇUBUKLA AYNI GÖRÜNÜM ──
          //
          // Soru metni ("Hangi hizmete ihtiyacınız var?") ÜSTTE ayrı
          // bir başlık değil, kutunun İÇİNDE yer tutucu olarak durur;
          // solda büyüteç vardır.
          //
          // ⚠ ÖLÇÜLER REFERANSTAN BİREBİR ALINDI (`InlineSearchBox`):
          //   yükseklik 53 · yan dolgu 11 · kenarlık #ECEEF2
          //   büyüteç `ic_search.svg` 23 birim, renk #A8ADB4
          //   yer tutucu 14,5 / w400 / #9AA0A6 (silik)
          //   yazılan metin 14,5 / w500 / RC.text
          // İki ekranın arama çubuğu ayrışmasın diye değerler
          // uydurulmadı, referanstan okundu.
          Container(
            height: 53,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: RC.white,
              border: Border.all(color: const Color(0xFFECEEF2)),
              borderRadius: BorderRadius.circular(RR.r13),
            ),
            child: Row(
              children: [
                const RefSvg('assets/svg/ic_search.svg',
                    size: 23, color: Color(0xFFA8ADB4)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ara,
                    onChanged: (v) => setState(() => _sorgu = v),
                    style: refText(
                        size: 14.5, weight: RF.w500, color: RC.text),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      // ⚠ DÖRT KENARLIK DA KAPATILIR: dış kutunun
                      // içinde ikinci bir çerçeve çizilmesin.
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Hangi hizmete ihtiyacınız var?',
                      hintStyle: refText(
                          size: 14.5,
                          weight: RF.w400,
                          color: const Color(0xFF9AA0A6)),
                    ),
                  ),
                ),
                // ⚠ ORTAK TEMİZLEME DÜĞMESİ — yalnız metin varken
                // çizilir. Bu ekranda açılır panel YOKTUR; yalnız
                // metin ve sorgu sıfırlanır.
                RefAramaTemizle(
                  controller: _ara,
                  onTemizle: () => setState(() {
                    _ara.clear();
                    _sorgu = '';
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── KATEGORİ SATIRLARI ──
          //
          // ⚠ Kart değil SATIR: bir çatının altında otuza kadar
          // kategori olabiliyor (Ev Hizmeti). Fotoğraflı kart o
          // sayıda ekranı boğar; satır hızlı taranır.
          // ── ⚠ ARAMA VARKEN HİZMETLER LİSTELENİR ──
          //
          // Kullanıcı yazı yazdığında aradığı HİZMET doğrudan çıkar;
          // kategoriye girip ikinci kez aramaz.
          //
          // ⚠ ARAMA BOŞKEN HİÇBİR ŞEY DEĞİŞMEZ: aşağıdaki kategori
          // listesi eskisi gibi çizilir.
          if (hizmetler.isNotEmpty) ...[
            for (var i = 0; i < hizmetler.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _HizmetSonucSatiri(
                hizmet: hizmetler[i].hizmet,
                kategori: hizmetler[i].kategori,
                alan: widget.alan.ad,
              ),
            ],
            const SizedBox(height: 14),
          ],

          if (kategoriler.isEmpty && hizmetler.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Sonuç bulunamadı',
                  textAlign: TextAlign.center,
                  style: refText(
                      size: RF.s135, weight: RF.w400, color: RC.textSoft)),
            )
          else
            for (var i = 0; i < kategoriler.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
                _KategoriSatiri(
                  kategori: kategoriler[i], alan: widget.alan.ad),
            ],
        ],
      ),
    );
  }
}

/// ARAMA SONUCU — TEK HİZMET SATIRI.
///
/// ⚠ KATEGORİ SATIRINDAN FARKLI: burada hizmetin KENDİSİ başlıktır;
/// altında hangi kategoriye ait olduğu yazar, böylece kullanıcı
/// sonucun nereden geldiğini görür.
///
/// ⚠ DOKUNUNCA HİZMET SEÇİLİ AÇILIR: kategori ekranına `onSecili`
/// ile gidilir, kullanıcı listede ikinci kez aramaz ve doğrudan
/// ilan oluşturabilir.
class _HizmetSonucSatiri extends StatelessWidget {
  const _HizmetSonucSatiri({
    required this.hizmet,
    required this.kategori,
    required this.alan,
  });

  final String hizmet;
  final String kategori;
  final String alan;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: () => Navigator.push<void>(
        context,
        akisRotasi<void>(
          // ⚠ WEB'DE PANEL; mobilde aynı sayfa rotası.
          // ⚠ ÇATI BAĞLAMI TAŞINIR (mevcut kural) ve hizmet SEÇİLİ
          // gelir.
          builder: (_) => CategoryScreen(
            category: kategori,
            alan: alan,
            onSecili: hizmet,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hizmet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s145, weight: RF.w600, color: RC.text)),
                  const SizedBox(height: 2),
                  // ⚠ Kategori adı İKİNCİL: kullanıcı hizmeti arıyor,
                  // kategori yalnız bağlam bilgisi.
                  Text(kategori,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s12,
                          weight: RF.w400,
                          color: RC.textSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const RefSvg('assets/svg/ic_chev.svg',
                size: 15, color: RC.textSoft),
          ],
        ),
      ),
    );
  }
}

class _KategoriSatiri extends StatelessWidget {
  const _KategoriSatiri({required this.kategori, required this.alan});

  /// ⚠ KATALOG KİMLİĞİ — `kCategoryTree` anahtarı.
  final String kategori;

  /// Bu satırın açılacağı çatı bağlamı.
  final String alan;

  @override
  Widget build(BuildContext context) {
    // ⚠ Örnek hizmetler de ÇATI SÜZGECİNDEN geçer; kullanıcı bu
    // çatıda göremeyeceği bir hizmeti önizlemede görmemeli.
    final altlar = [
      for (final h in kSubServices[kategori] ?? const <String>[])
        if (hizmetAlani(kategori, h) == alan) h
    ];
    return RefTap(
      onTap: () => Navigator.push<void>(
        context,
        akisRotasi<void>(
          // ⚠ WEB'DE PANEL; mobilde aynı sayfa rotası.
          // ⚠ ÇATI BAĞLAMI TAŞINIR: kategori ekranı yalnız bu çatıya
          // ait hizmetleri gösterir.
          builder: (_) => CategoryScreen(category: kategori, alan: alan),
        ),
      ),
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: const Color(0xFFECEEF2)),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Row(
          children: [
            RefSvg(categoryIcon(kategori), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kategoriEtiketi(kategori),
                    style: refText(
                        size: RF.s14, weight: RF.w700, color: RC.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // ⚠ İlk üç hizmet ÖRNEKTİR, sınır değil.
                    altlar.take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s12, weight: RF.w400, color: RC.textSoft),
                  ),
                ],
              ),
            ),
            const RefSvg('assets/svg/ic_chev.svg', size: 15, color: RC.textSoft),
          ],
        ),
      ),
    );
  }
}
