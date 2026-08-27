import 'package:flutter/material.dart';
import '../domain/form_mesajlari.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/profile_controller.dart';
import '../data/controllers/region_controller.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import '../core/geri.dart';

/// HİZMET VEREN — HİZMET BÖLGELERİM (HTML vMyAreas)
///
/// İŞ KURALI:
///  • Hizmet veren şehir ve ilçeleri seçer.
///  • "Tüm ilçelere hizmet veriyorum" seçeneği desteklenir.
///  • MAHALLE BAZLI hizmet dağıtımı YOKTUR — bu ekranda mahalle seçimi
///    bilerek bulunmaz (mahalle yalnız müşterinin adresinde kullanılır).
class MyAreasScreen extends StatefulWidget {
  const MyAreasScreen({super.key});
  @override
  State<MyAreasScreen> createState() => _MyAreasScreenState();
}

class _MyAreasScreenState extends State<MyAreasScreen> {
  final _search = TextEditingController();
  Set<String> _selected = {};
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    // Mevcut kayıtlar yüklenir.
    _selected = {...context.read<ProfileController>().districts};
    // ⚠ İL ARTIK SEÇİLEBİLİR (Rol Değiştir sayfasıyla AYNI kural).
    //
    // Bu ekran ili salt okunur gösteriyordu; Rol Değiştir sayfasında
    // ise il seçilebiliyordu. İki ekran aynı bilgiyi farklı kuralla
    // yönetiyordu — biri güncellenince diğeri geride kalıyordu.
    final r = context.read<RegionController>();
    _il = r.soleCityName ?? r.cityName;
  }

  /// Hizmet verilen İL — TEK seçim. Değişirse ilçeler temizlenir.
  String? _il;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Tüm ilçeler seçili mi?
  /// GETTER build sırasında da callback'ten de çağrılabilir → read kullanılır.
  bool get _allSelected =>
      _selected.length ==
      context.read<RegionController>().districtsOf(_il).length;

  List<String> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      // ⚠ SEÇİLİ İLİN ilçeleri; varsayılan ilin değil.
      return context.read<RegionController>().districtsOf(_il);
    }
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    return context
        .read<RegionController>()
        .districtsOf(_il)
        .where((d) => norm(d).contains(norm(q)))
        .toList();
  }

  /// İL SEÇİMİ — Rol Değiştir sayfasıyla AYNI kural.
  ///
  /// Tek il seçilebilir; il değişirse seçili ilçeler TEMİZLENİR
  /// (başka ilin ilçesi listede kalamaz).
  /// İL SEÇİMİ — DOKUNMATİK LİSTE.
  ///
  /// ⚠ ONAY DÜĞMESİ VE İŞARET KUTUSU YOKTUR.
  ///
  /// Yalnız BİR il seçilebilir; kutucuk işaretleyip sonra "Tamam"
  /// demek fazladan bir adımdı. Dokunulan il seçilir ve panel kapanır.
  ///
  /// Seçili il satırında mavi onay işareti gösterilir — bu bir kutucuk
  /// değil, hangisinin geçerli olduğunu belirten göstergedir.
  Future<void> _ilSec() async {
    final rc = context.read<RegionController>();
    final iller = rc.cityNames;
    if (iller.isEmpty) {
      return;
    }
    final yeni = await RefBottomSheet.goster<String>(
      context,
      title: 'Hizmet Verilen İl',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final il in iller)
            RefTap(
              // ⚠ PASİF İL SEÇİLEMEZ: veri var ama hizmete kapalı.
              // Dokunulunca bilgilendirilir, seçim yapılmaz.
              onTap: () => rc.sehirAktif(il)
                  ? Navigator.of(context).pop(il)
                  : sysToastKural(
                      context,
                      '$il henüz hizmete açılmadı. '
                      "$il'da hizmet vermeye başladığımızda "
                      'sizi haberdar edelim.'),
              borderRadius: BorderRadius.circular(RR.r10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 13, horizontal: 4),
                child: Row(children: [
                  Expanded(
                    // ── ⚠ AD VE DURUM AYNI SATIRDA ──
                    //
                    // "İstanbul — Yakında" biçimi. Alt satır DEĞİL:
                    // tek kelimelik bir ibare için ikinci satır
                    // açmak listeyi gereksiz uzatıyordu.
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(il,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: refText(
                                  size: RF.s145,
                                  weight: il == _il ? RF.w700 : RF.w500,
                                  // ⚠ PASİF İL SOLUK: seçilemeyeceği
                                  // dokunmadan önce anlaşılsın.
                                  color: rc.sehirAktif(il)
                                      ? RC.text
                                      : RC.greyLight)),
                        ),
                        // ── ⚠ YALNIZ PASİF İLDE "Yakında" ──
                        //
                        // Aktif ilin yanında hiçbir şey yazmaz;
                        // `sehirDurumu` orada `null` döner.
                        //
                        // ⚠ KOŞULSUZ GÖSTERİLİR: kullanıcı hangi ilin
                        // henüz açılmadığını görmeli. Bir il aktif
                        // edildiği an ibare KENDİLİĞİNDEN kalkar.
                        if (rc.sehirDurumu(il) != null) ...[
                          const SizedBox(width: 8),
                          Text('— ${rc.sehirDurumu(il)}',
                              style: refText(
                                  size: RF.s125,
                                  weight: RF.w500,
                                  color: RC.greyLight)),
                        ],
                      ],
                    ),
                  ),
                  if (il == _il)
                    const RefSvg('assets/svg/ic_checkc.svg',
                        size: 20, color: RC.blue),
                ]),
              ),
            ),
        ],
      ),
    );
    if (yeni == null || !mounted || yeni == _il) {
      return;
    }
    // ⚠ İl değişince ilçe seçimi SIFIRLANIR: başka ilin ilçeleri
    // geçersizdir.
    setState(() {
      _il = yeni;
      _selected = {};
    });
  }

  void _toggle(String d) {
    setState(() {
      if (_selected.contains(d)) {
        _selected.remove(d);
      } else {
        _selected.add(d);
      }
      _error = null;
    });
  }

  void _selectAll() => setState(() {
        // CALLBACK: watch kullanılamaz.
        _selected = {...context.read<RegionController>().districts};
        _error = null;
      });

  void _clearAll() => setState(() {
        _selected.clear();
        _error = null;
      });

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = FormMesaj.bolgeSec);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await context.read<ProfileController>().setDistricts(_selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = err?.message;
    });
    if (err == null) {
      sysToastOk(context, 'Hizmet bölgeleriniz güncellendi');
      geriGit(context);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: HC.bg,
      // AppBar KALDIRILDI — referansta yok (başlık sayfa içinde).
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: RefDetailHeader(title: 'Hizmet Bölgelerim'),
          ),
                const Text('Hizmet vermek istediğiniz il ve ilçeleri seçin.',
                    style: TextStyle(fontSize: 13, height: 1.5, color: HC.grey)),
                const SizedBox(height: 14),
          // ── `.ad-card` — İL SEÇİMİ ──
          //
          // ⚠ HTML'de bölümler KART içindedir: başlık (`.ad-h3`),
          // altında açılır düğme (`.ad-drop`) ve "tümü" satırı
          // (`.ma-all`). Önceki hâlde başlık ve değer TEK SATIRA
          // sıkıştırılmıştı; kart yoktu, başlık hiyerarşisi kaybolmuştu.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdCard(
                  baslik: 'İl Seçimi',
                  children: [
                    // `.ad-drop`
                    RefTap(
                      onTap: _saving ? null : _ilSec,
                      borderRadius: BorderRadius.circular(RR.r12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 13),
                        decoration: BoxDecoration(
                          color: RC.white,
                          border: Border.all(
                              color: const Color(0xFFE1E5EC), width: 1.4),
                          borderRadius: BorderRadius.circular(RR.r12),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(_il ?? 'Seçiniz',
                                style: refText(
                                    size: RF.s145,
                                    weight: RF.w400,
                                    color: RC.text)),
                          ),
                          const RefSvg('assets/svg/ic_chev.svg',
                              size: 18, color: RC.textSoft),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // `.ma-row.ma-all` — alt kenarlık YOK, kalın metin.
                    RefTap(
                      onTap: _saving
                          ? null
                          : (_allSelected ? _clearAll : _selectAll),
                      borderRadius: BorderRadius.circular(RR.r10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 3),
                        child: Row(children: [
                          RefCheckBox(value: _allSelected),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text('Tüm İlçelere Hizmet Veriyorum',
                                style: refText(
                                    size: RF.s14,
                                    weight: RF.w600,
                                    color: RC.text)),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),

                // ── `.ad-card` — İLÇELER ──
                _AdCard(
                  baslik: 'İlçeler',
                  children: [
                    // `.po-search`
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 2),
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
                            controller: _search,
                            enabled: !_saving,
                            scrollPadding: const EdgeInsets.only(
                                bottom: kAlanKaydirmaPayi),
                            style: refText(
                                size: RF.s145,
                                weight: RF.w500,
                                color: RC.text),
                            decoration: InputDecoration(
                              isDense: true,
                              // ⚠ DÖRT KENARLIK DA KAPATILIR — tema `enabledBorder`
                              // ve `focusedBorder` AYRI tanımlıdır ve `border`'ı ezer;
                              // dış kutunun İÇİNDE ikinci çerçeve çiziliyordu.
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: 'İlçe ara...',
                              hintStyle: refText(
                                  size: RF.s145,
                                  weight: RF.w500,
                                  color: const Color(0xFF98A2B3)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        // ── ⚠ TEMİZLEME DÜĞMESİ ──
                        //
                        // Yanlış yazılan aramayı tek tek silmek yerine
                        // tek dokunuşla temizler. Yalnız metin varken
                        // çizilir (bileşen kendisi denetler).
                        RefAramaTemizle(
                          controller: _search,
                          onTemizle: () => setState(_search.clear),
                        ),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── `.ma-list` — İLÇE LİSTESİ ──
          //
          // ⚠ Liste, İLÇELER KARTININ İÇİNDE görünür: kart kenarlığı
          // listeyi sarar. Önceki hâlde kart bitiyor, araya bir ayırıcı
          // konuyor ve liste sayfanın kalanına yayılıyordu — HTML'deki
          // `max-height:330px` sınırlı kutu görüntüsü kayboluyordu.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: RC.white,
                  border: Border.all(color: RC.border),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(RR.r15)),
                ),
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
                child: _visible.isEmpty
                ? const Center(
                    child: SysState(SysKind.empty,
                        title: 'İlçe bulunamadı',
                        desc: 'Farklı bir arama deneyin.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _visible.length,
                    // `.ma-row{border-bottom:1px solid #F2F4F7}`
                    // `.ma-row:last-child{border-bottom:none}`
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF2F4F7)),
                    itemBuilder: (_, i) {
                      final d = _visible[i];
                      final sel = _selected.contains(d);
                      return RefCheckRow(
                        value: sel,
                        label: d,
                        onChanged: _saving ? null : (_) => _toggle(d),
                      );
                    },
                  ),
              ),
            ),
          ),

          // ── Kaydet ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
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
                const SizedBox(height: 6),
                const Text(
                  'Hizmet dağıtımı ilçe bazlıdır; mahalle seçimi yapılmaz.',
                  style: TextStyle(fontSize: 11.5, color: HC.lightGrey),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// `.ad-card` — beyaz kart + `.ad-h3` başlık.
///
/// ```css
/// .ad-card{#fff;1px #ECEEF1;r15;padding:15px;margin-top:14px}
/// .ad-h3{16px/700;#16233D}
/// ```
///
/// ⚠ HTML'de her bölüm bu kartla sarılır. Önceki hâlde kart yoktu;
/// başlık ve içerik tek satıra sıkışıyor, bölüm hiyerarşisi
/// kayboluyordu.
class _AdCard extends StatelessWidget {
  const _AdCard({required this.baslik, required this.children});

  final String baslik;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border),
          borderRadius: BorderRadius.circular(RR.r15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik,
                style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}
