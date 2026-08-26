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

  @override
  Widget build(BuildContext context) {
    final kategoriler = _sonuc;
    return RefPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RefBackButton(onTap: () => Navigator.of(context).pop()),
          ),
          const SizedBox(height: 6),
          RefPageTitle(widget.alan.ad, geriDugmesi: false),
          RefSubtitle(widget.alan.aciklama),
          const SizedBox(height: 14),

          // ── ARAMA ──
          //
          // ⚠ Metin ilan formundakiyle AYNI: kullanıcı aynı soruyu
          // iki farklı cümleyle duymasın.
          RefTextField(
            controller: _ara,
            hint: 'Hangi hizmete ihtiyacınız var?',
            onChanged: (v) => setState(() => _sorgu = v),
            // ⚠ ORTAK TEMİZLEME DÜĞMESİ — yalnız metin varken çizilir.
            // Bu ekranda açılır panel YOKTUR (sonuçlar sayfa içinde
            // listelenir), bu yüzden kapatılacak bir panel de yok:
            // yalnız metin ve sorgu sıfırlanır.
            suffix: RefAramaTemizle(
              controller: _ara,
              onTemizle: () => setState(() {
                _ara.clear();
                _sorgu = '';
              }),
            ),
          ),
          const SizedBox(height: 14),

          // ── KATEGORİ SATIRLARI ──
          //
          // ⚠ Kart değil SATIR: bir çatının altında otuza kadar
          // kategori olabiliyor (Ev Hizmeti). Fotoğraflı kart o
          // sayıda ekranı boğar; satır hızlı taranır.
          if (kategoriler.isEmpty)
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
        MaterialPageRoute<void>(
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
