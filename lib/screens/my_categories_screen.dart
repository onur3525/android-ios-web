import 'package:flutter/material.dart';
import '../data/services/search_service.dart';
import '../domain/form_mesajlari.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/profile_controller.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';

/// HİZMET VEREN — HİZMET KATEGORİLERİM (HTML vMyCats)
///
/// Arama, çoklu seçim ve aktif/pasif kategori davranışını içerir.
///
/// ⚠ KATEGORİ TALEP ETME YOKTUR: yeni ana kategori / alt hizmet
/// tanımlamak YALNIZ ADMİN yetkisidir. Bu ekranda hizmet veren
/// yalnızca VAR OLAN hizmetler arasından seçim yapar.
///
/// PASİF KATEGORİ: Admin bir kategoriyi kapattığında kategori listeden
/// SİLİNMEZ. Daha önce seçilmişse görünür kalır ama işaretlenemez;
/// yeni seçime kapalıdır.
class MyCategoriesScreen extends StatefulWidget {
  const MyCategoriesScreen({super.key});
  @override
  State<MyCategoriesScreen> createState() => _MyCategoriesScreenState();
}

class _MyCategoriesScreenState extends State<MyCategoriesScreen> {
  final _search = TextEditingController();

  Set<String> _selected = {};
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  /// Admin tarafından kapatılmış kategoriler (backend `active:false`).
  /// Sunucu listesi okunamazsa boş kalır ve tüm kategoriler aktif sayılır.
  // Yeniden atanmaz; yalnız içeriği değişir (add/remove).
  final Set<String> _inactive = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    _selected = {...context.read<ProfileController>().categories};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Aramaya göre filtrelenmiş ana kategori → alt hizmet ağacı.
  /// ARAMA SONUÇLARI — `(alt hizmet, ana kategori)`, en fazla 6.
  ///
  /// ⚠ REFERANS DAVRANIŞI: kullanıcı yazar, altında sonuçlar çıkar;
  /// dokununca kategori DOĞRUDAN eklenir.
  ///
  /// ```js
  /// SERVICES.filter(x => norm(x.n).includes(q) && !PROV_CATS.includes(x.n))
  ///         .slice(0, 6)
  /// ```
  ///
  /// ⚠ ZATEN SEÇİLİ olanlar listelenmez; tekrar eklemek anlamsızdır.
  ///
  /// ⚠ Önceki hâlde arama bir KATEGORİ AĞACINI süzüyordu; referansta
  /// böyle bir ağaç YOKTUR ve ağaç ekranın çoğunu kaplıyordu.
  List<({String ad, String ana})> get _aramaSonuclari {
    final q = _search.text.trim();
    if (q.isEmpty) {
      return const [];
    }
    // ── ⚠ ORTAK ARAMA SERVİSİ — KESİN KURAL ──
    //
    // Bu ekran da KENDİ süzgecini yazıyordu ve yalnız katalog
    // adlarına bakıyordu; eş anlamlı sözlüğü ile alias katmanı burada
    // çalışmıyordu. Hizmet veren "ocak" ya da "kolon hattı" yazıp
    // kendi verdiği işi bulamıyordu.
    //
    // ⚠ YALNIZ ALT HİZMET satırları alınır: hizmet veren işini TEK
    // TEK seçer, ana kategori satırı seçtirilmez.
    final out = <({String ad, String ana})>[];
    for (final h in SearchService.services(q, enFazla: 60)) {
      final alt = h.subService;
      if (alt == null || _selected.contains(alt)) {
        continue;
      }
      out.add((ad: alt, ana: h.category));
      if (out.length >= 6) {
        break;
      }
    }
    return out;
  }

  bool _isInactive(String name) => _inactive.contains(name);

  void _toggle(String name) {
    // Pasif kategori YENİ seçime kapalıdır; zaten seçiliyse kaldırılabilir.
    if (_isInactive(name) && !_selected.contains(name)) {
      // ⚠ Bu da bir kural bildirimi — arıza değil.
      sysToastKural(context,
          'Bu hizmet kategorisi şu anda yeni seçime kapalıdır.');
      return;
    }
    // ⚠ ANA KATEGORİ SAYI SINIRI YOKTUR.
    //
    // Eskiden en fazla 2 ana kategori seçilebiliyordu. Katalog 53
    // kategoriye çıkınca sınır gerçekliğe aykırı hâle geldi; hizmet
    // veren istediği kadar ana kategori ve alt hizmet seçebilir.
    // ── ⚠ SON HİZMET KALDIRILAMAZ ──
    //
    // İŞ KURALI: hizmet verenin en az BİR kategorisi olmak zorunda.
    // Ekran kaldırmaya izin veriyordu; kullanıcı hepsini silince
    // "Seçili Hizmetlerim (0)" kalıyor ve profil hizmetsiz görünüyordu.
    //
    if (_selected.contains(name) && _selected.length == 1) {
      // ⚠ SİSTEM HATASI DEĞİL, İŞ KURALI. "Bir sorun oluştu — "
      // öneki kullanıcıya arıza varmış gibi geliyordu.
      sysToastKural(
          context,
          'En az bir hizmet kategorisi seçili olmalıdır. Bu kategoriyi '
          'kaldırmak için önce başka bir hizmet kategorisi ekleyin.');
      return;
    }
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
        // ── ⚠ EKLEDİKTEN SONRA ARAMA TEMİZLENİR ──
        //
        // Rol değiştirme ekranındaki ortak panel bunu yapıyordu, bu
        // ekran yapmıyordu. Sonuç: arama metni kalıyor, öneri listesi
        // ekranı kaplıyor ve kullanıcı SEÇTİĞİ hizmeti göremiyordu —
        // "Seçili Hizmetlerim" listenin çok altında kalıyordu.
        //
        // Temizlenince öneri listesi kapanır, seçilen çip hemen
        // görünür ve kullanıcı sıradakini yazmaya devam edebilir:
        // TEK TEK seçim, ekrandan çıkmadan.
        _search.clear();
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = FormMesaj.kategoriSec);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err =
        await context.read<ProfileController>().setCategories(_selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = err?.message;
    });
    if (err == null) {
      sysToastOk(context, 'Kategorileriniz güncellendi');
      geriGit(context);
    }
  }

  @override
  Widget build(BuildContext context) {

    // ⚠ Referansta AppBar YOKTUR; başlık sayfa içindedir.
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: const RefDetailHeader(title: 'Hizmet Kategorilerim'),
          ),
          // ⚠ TÜM İÇERİK TEK KAYDIRMADA.
          //
          // Önceki hâl arama ve başlıkları sabit tutup ağacı ayrı bir
          // `Expanded` içinde kaydırıyordu. Referansta tek sayfa
          // kaydırması vardır (`.cust-scroll`).
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              children: [
                // `.ad-sub{font-size:13px;color:#5B6472;margin-top:6px}`
                //
                // ⚠ "…veya yeni bir alt kategori ekleyin." CÜMLESİ
                // ÇIKARILDI: alt kategori ekleme yetkisi yalnız
                // admindedir, kullanıcıya olmayan bir işlem
                // vaat edilmez.
                Text(
                  'Hizmet verdiğiniz hizmet kategorilerini seçin.',
                  style: refText(
                      size: RF.s13, weight: RF.w400, color: RC.textSoft),
                ),

                // ── `.po-search` ──
                //
                // ```css
                // .po-search{gap:10px;1.7px #1D6BE3;r13;#fff;padding:13px}
                // .po-qin{14.5px/500;#16233D}
                // .po-clear{26px daire;#EEF0F4}
                // ```
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: RC.white,
                    border: Border.all(color: RC.blue, width: 1.7),
                    borderRadius: BorderRadius.circular(RR.r13),
                  ),
                  child: Row(children: [
                    const RefSvg('assets/svg/ic_search.svg',
                        size: 20, color: Color(0xFF98A2B3)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        enabled: !_saving,
                        scrollPadding:
                            const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
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
                    // `.po-clear` — yalnız yazı varken görünür.
                    if (_search.text.isNotEmpty)
                      RefTap(
                        onTap: () => setState(_search.clear),
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

                // ── `.po-row` — ARAMA SONUÇLARI ──
                //
                // ```css
                // .po-row{#F8FAFC;padding:11px 15px;alt kenarlık #EEF0F3}
                // .po-rn{14.5px/700;#16233D}
                // .po-rp{12px;#8A94A6;margin-top:2px}
                // ```
                //
                // ⚠ Dokununca kategori DOĞRUDAN eklenir; ara adım yok.
                for (final r in _aramaSonuclari)
                  RefTap(
                    onTap: _saving ? null : () => _toggle(r.ad),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 15),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                            bottom: BorderSide(color: Color(0xFFEEF0F3))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(r.ad,
                              style: refText(
                                  size: RF.s145,
                                  weight: RF.w700,
                                  color: RC.text)),
                          const SizedBox(height: 2),
                          Text(r.ana,
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w400,
                                  color: RC.grey)),
                        ],
                      ),
                    ),
                  ),

                // ── `.pf-h3` + `.pf-d` ──
                const SizedBox(height: 16),
                Text('Seçili Hizmetlerim (${_selected.length})',
                    style:
                        refText(size: RF.s16, weight: RF.w800, color: RC.text)),
                const SizedBox(height: 4),
                Text(FormMesaj.kategoriSec,
                    style: refText(
                        size: RF.s125, weight: RF.w400, color: RC.textSoft)),

                // ── `.mc-chips` ──
                //
                // ```css
                // .mc-chips{flex-wrap;gap:9px;margin-top:10px}
                // .mc-chip{gap:8px;1px #E1E5EC;r11;#fff;padding:9px 12px;13px/600}
                // ```
                const SizedBox(height: 10),
                if (_selected.isEmpty)
                  Text('Henüz hizmet seçilmedi.',
                      style: refText(
                          size: RF.s125,
                          weight: RF.w400,
                          color: RC.textSoft))
                else
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final c in _selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 9, horizontal: 12),
                          decoration: BoxDecoration(
                            color: RC.white,
                            border: Border.all(color: const Color(0xFFE1E5EC)),
                            borderRadius: BorderRadius.circular(RR.r11),
                          ),
                          child:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            // ⚠ `Flexible` — çip taşmasını önler
                            // (bkz. `kategori_secim_paneli`).
                            Flexible(
                              child: Text(c,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: refText(
                                      size: RF.s13,
                                      weight: RF.w600,
                                      color: RC.text)),
                            ),
                            const SizedBox(width: 8),
                            // `.mc-x`
                            RefTap(
                              onTap: _saving ? null : () => _toggle(c),
                              borderRadius: BorderRadius.circular(RR.circle),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: RefSvg('assets/svg/ic_close.svg',
                                    size: 14, color: RC.textSoft),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),

                // ⚠ BURADA "Hizmet Taleplerim" LİSTESİ ve "Yeni Hizmet
              ],
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(children: [
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(color: HC.red, fontSize: 13)),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: SysButton('Kaydet',
                      busy: _saving,
                      onPressed: _selected.isEmpty ? null : _save),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

}

