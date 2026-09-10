import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/tutar_bicimi.dart';
import '../domain/hata_mesajlari.dart';
import 'widgets/hata_gosterimi.dart';
import 'widgets/ilan_no_etiketi.dart';
import 'package:provider/provider.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/account.dart';
import '../data/models/listing.dart';
import '../data/models/teklif_talebi.dart';
import '../domain/teklif_talebi_asamasi.dart';
import '../ui/ref_tokens.dart';
import 'widgets/teklif_rozeti.dart';
import '../ui/ref_widgets.dart';
import 'listing_detail_screen.dart';
import 'nav_actions.dart';
import 'category_ui.dart';
import 'teklif_talebi_detay_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// İLANLARIM — referans `vCust()`
///
/// ```
/// <div class="cust-wrap">
///   <div class="cust-tabs">custTabsHTML()</div>
///   <div class="cust-bar">
///     <span class="cust-count">custCountText(CUST_TAB)</span>
///     <div class="cust-actions">
///       <button class="cust-pill" onclick="custSortMenu()">Sırala</button>
///       <button class="cust-pill" onclick="custFilterMenu()">Filtreler</button>
///     </div>
///   </div>
///   <div class="cust-list">custCards(CUST_TAB)</div>
/// </div>
/// custNav('ilanlarim')
/// ```
///
/// `custTabsHTML()` rol duyarlıdır:
///   provider → "Yeni işler" / "Kazandığım işler"
///   customer → "Açık işler" / "Tamamlanan işler" / "Süresi dolan işler"
/// ═══════════════════════════════════════════════════════════════

/// `SORT_OPTS` — referanstan birebir.
/// SIRALAMA SEÇENEKLERİ — `(anahtar, başlık, açıklama, ikon)`
///
/// ⚠ Metinler SADELEŞTİRİLDİ. Önceki hâl parantez içi teknik ekler
/// taşıyordu ("Teklif sayısı (çoktan aza)"); okunması yavaş ve
/// kalabalıktı. Artık her satır KISA bir başlık ve altında ne
/// yaptığını söyleyen bir açıklama taşır — kullanıcı seçmeden önce
/// sonucu bilir.
const _kSortSecenek = [
  ('new', 'En yeniler önce', 'Son eklenen ilanlarınız üstte',
      'assets/svg/ic_clock.svg'),
  ('old', 'En eskiler önce', 'İlk eklenen ilanlarınız üstte',
      'assets/svg/ic_clock.svg'),
  ('offdesc', 'En çok teklif alan', 'Teklifi bol ilanlar üstte',
      'assets/svg/ic_chat.svg'),
  ('offasc', 'En az teklif alan', 'Teklif bekleyen ilanlar üstte',
      'assets/svg/ic_chat.svg'),
];

/// `FILT_OPTS` — referanstan birebir.
const _kFiltreSecenek = [
  ('all', 'Tüm ilanlar', 'Hiçbir filtre uygulanmaz',
      'assets/svg/ic_clip.svg'),
  ('has', 'Teklif alanlar', 'En az bir teklif gelmiş ilanlar',
      'assets/svg/ic_checkc.svg'),
  ('none', 'Teklif bekleyenler', 'Henüz teklif gelmemiş ilanlar',
      'assets/svg/ic_clock.svg'),
];

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  int _tab = 0;
  String _sort = 'new';
  String _filtre = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Açılış yüklemesi — iş mantığı korunur.
  Future<void> _refresh() async {
    final me = context.read<AuthController>().currentAccount;
    if (me == null) {
      return;
    }
    await context.read<ListingController>().loadMine(me.id);
    if (!mounted) {
      return;
    }
    await context.read<OfferController>().loadMine();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final saglayici = auth.activeRole == Role.provider;
    final me = auth.currentAccount;
    final offerCtl = context.watch<OfferController>();
    // ⚠ Hata durumu için denetleyicinin KENDİSİ gerekir; `byOwner`
    // yalnız listeyi döner, yükleme/hata bilgisini taşımaz.
    final ilanCtl = context.watch<ListingController>();

    final tumu = me == null ? <Listing>[] : ilanCtl.byOwner(me.id);

    // ── ⚠ "BUL" ÜZERİNDEN KABUL EDİLEN TEKLİFLER — "TAMAMLANAN
    // İŞLER" SEKMESİNE, NORMAL İLANLARLA TEK LİSTEDE ──
    //
    // Bu ekranın kendi kuralıyla TUTARLI: "Tamamlanan işler" burada
    // "iş gerçekten bitti" değil, "teklifi seçildi/kesinleşti"
    // anlamına gelir (bkz. `l.isTamamlanmisIs` yorumu). `TeklifTalebi`
    // için AYNI eşik: `secildi` veya `tamamlandi` durumundaki HER
    // talep buraya girer.
    //
    // ⚠ İKİ FARKLI MODEL (`Listing` / `TeklifTalebi`) TEK EKRANDA
    // BİRLEŞTİRİLDİ: `ListingController`/`OfferController` DEĞİŞMEDİ,
    // yalnız RENDER aşamasında iki kaynak birleştirilip TARİHE göre
    // yeniden sıralanır — `_sort`/`_filtre` (teklif sayısına dayalı)
    // yalnız `Listing` tarafına uygulanmaya devam eder, çünkü doğrudan
    // talepte "teklif sayısı" kavramı YOKTUR (her biri zaten TEK
    // kabul edilmiş tekliftir).
    final kabulEdilenTalepler = (!saglayici && me != null && _tab == 1)
        ? context
            .watch<TeklifTalebiController>()
            .byHizmetAlan(me.id)
            // ⚠ Kural doğruydu ama BURADA yazılıydı; dört listeden
            // yalnız biri doğru olunca sapma görünmez kalıyordu.
            // Artık aşama kuralı tek kaynaktan geliyor.
            .where((t) => talepKazanildiMi(t.durum))
            .toList()
        : const <TeklifTalebi>[];

    // Sekme süzgeci — mevcut iş kuralı korundu.
    var liste = tumu.where((l) => switch (_tab) {
          // ⚠ TEKLİF SEÇİLİNCE İLAN AÇIK SEKMESİNDEN ÇIKAR.
          //
          // Referans akış: bir teklif seçildiği anda ilan `done`
          // grubuna geçer (`submitReviewDo`: `x.st='done'`). Açık
          // sekmesi YALNIZ hâlâ teklif kabul eden ilanları gösterir.
          // ── ⚠ SEKME FİLTRELERİ (§24) ──
          //
          // Açık işler: YAŞAYAN ve henüz teklif seçilmemiş ilanlar.
          // Teklif seçilince ilan buradan çıkar ama durumu ACTIVE
          // KALIR — tamamlanmışlık ayrı alandır.
          0 => l.status == ListingStatus.active && !l.isTamamlanmisIs,
          // Tamamlanan işler: seçilmiş teklifi olan HER ilan.
          // ⚠ Yaşam durumuna BAKILMAZ: sonradan silinmiş ya da admin
          // tarafından kaldırılmış olsa da iş tamamlanmıştır.
          1 => l.isTamamlanmisIs,
          // Süresi dolanlar: tamamlanmamış ve süresi geçmiş ilanlar.
          _ => l.status == ListingStatus.expired && !l.isTamamlanmisIs,
        }).toList();

    int teklif(Listing l) => offerCtl.offersForListing(l.id).length;

    // FILT_OPTS
    liste = liste.where((l) => switch (_filtre) {
          'has' => teklif(l) > 0,
          'none' => teklif(l) == 0,
          _ => true,
        }).toList();

    // SORT_OPTS
    liste.sort((a, b) => switch (_sort) {
          'old' => a.createdAt.compareTo(b.createdAt),
          'offdesc' => teklif(b).compareTo(teklif(a)),
          'offasc' => teklif(a).compareTo(teklif(b)),
          _ => b.createdAt.compareTo(a.createdAt), // 'new'
        });

    return RefShell(
      nav: RefBottomNav(
        activeKey: 'ilanlarim',
        items: custNavItems(context, saglayici: saglayici),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .cust-tabs — rol duyarlı
          RefSegmentTabs(
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
            items: saglayici
                ? const [
                    (asset: 'assets/svg/ic_plane.svg', label: 'Yeni işler'),
                    (
                      asset: 'assets/svg/ic_checkc.svg',
                      label: 'Kazandığım işler'
                    ),
                  ]
                // ⚠ ETİKETLER KISALTILDI: "… ilanlar" → "… işler".
                //
                // Üç sekme tek satıra sığmıyordu; "Tamamlanan ila…" ve
                // "Süresi Dolan ilanl…" kesiliyor, kullanıcı hangi
                // sekmede olduğunu okuyamıyordu.
                : const [
                    (asset: 'assets/svg/ic_plane.svg', label: 'Açık işler'),
                    (
                      asset: 'assets/svg/ic_checkc.svg',
                      label: 'Tamamlanan işler'
                    ),
                    (
                      asset: 'assets/svg/ic_clock.svg',
                      label: 'Süresi dolan işler'
                    ),
                  ],
          ),

          // .cust-bar
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // custCountText: rows.length + ' ilan bulundu'
                Expanded(
                    child: RefListCount(
                        '${liste.length + kabulEdilenTalepler.length} ilan '
                        'bulundu')),
                const SizedBox(width: 10),
                // .cust-actions{gap:8px}
                RefPillButton(
                  iconAsset: 'assets/svg/ic_sort.svg',
                  label: 'Sırala',
                  onTap: _siralaMenu,
                ),
                const SizedBox(width: 8),
                RefPillButton(
                  iconAsset: 'assets/svg/ic_filter.svg',
                  label: 'Filtreler',
                  onTap: _filtreMenu,
                ),
              ],
            ),
          ),

          // .cust-list{display:flex;flex-direction:column;gap:8px}
          //
          // ⚠ `gap` YALNIZ KARTLAR ARASINDA çalışır; son karttan sonra
          // boşluk BIRAKMAZ. Ayırıcı bu yüzden son öğede atlanır.
          // ── ⚠ HATA YALNIZ GERÇEKTEN OLUNCA ──
          //
          // Sıra önemli: önce BAŞARISIZ İSTEK, sonra BOŞ LİSTE.
          // Boş liste bir hata değildir — istek başarıyla döndü ve
          // kullanıcının ilanı yok demektir.
          //
          // ⚠ `hataGosterilsinMi` üç koşulu birden arar: yükleme
          // bitmiş, gerçek bir hata var ve ekranda gösterilecek veri
          // yok. Mock modda istek atılmadığı için hata da oluşmaz,
          // dolayısıyla bu blok hiç çizilmez.
          if (hataGosterilsinMi(
              yukleniyor: ilanCtl.loading,
              hata: ilanCtl.lastError,
              veriVar: liste.isNotEmpty || kabulEdilenTalepler.isNotEmpty))
            HataTamEkran(
              hata: ilanCtl.lastError!,
              onTekrar: _refresh,
            )
          else if (liste.isEmpty && kabulEdilenTalepler.isEmpty)
            const _BosListe()
          else ...[
            // ⚠ İKİ KAYNAK, TARİHE GÖRE TEK LİSTEDE BİRLEŞTİRİLDİ —
            // `Listing.createdAt` / `TeklifTalebi.teklifTarihi`, en
            // yeni üstte. `_sort`/`_filtre` yalnız `liste` (Listing)
            // tarafına uygulanmış olarak buraya gelir; birleşik sıra
            // yalnız tarihtir (bkz. yukarıdaki not).
            for (final oge in [
              ...liste.map((l) => (listing: l, talep: null as TeklifTalebi?)),
              ...kabulEdilenTalepler
                  .map((t) => (listing: null as Listing?, talep: t)),
            ]..sort((a, b) {
                final ta = a.listing?.createdAt ??
                    a.talep!.teklifTarihi ??
                    DateTime(2000);
                final tb = b.listing?.createdAt ??
                    b.talep!.teklifTarihi ??
                    DateTime(2000);
                return tb.compareTo(ta);
              }))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: oge.listing != null
                    ? _IlanKarti(
                        listing: oge.listing!,
                        teklifSayisi: teklif(oge.listing!),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ListingDetailScreen(
                                listingId: oge.listing!.id),
                          ),
                        ),
                      )
                    : _TeklifTalebiIsKarti(
                        talep: oge.talep!,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => TeklifTalebiDetayScreen(
                                talepId: oge.talep!.id),
                          ),
                        ),
                      ),
              ),
          ],
        ],
      ),
    );
  }

  /// Referans `custSortMenu()` → `rgOverlay('Sırala', ...)`
  Future<void> _siralaMenu() => _secimSheet(
        baslik: 'Sırala',
        secenekler: _kSortSecenek,
        secili: _sort,
        onSec: (v) => setState(() => _sort = v),
      );

  /// Referans `custFilterMenu()` → `rgOverlay('Filtreler', ...)`
  Future<void> _filtreMenu() => _secimSheet(
        baslik: 'Filtreler',
        secenekler: _kFiltreSecenek,
        secili: _filtre,
        onSec: (v) => setState(() => _filtre = v),
      );

  /// SEÇİM YARIM EKRANI — Sırala / Filtreler
  ///
  /// ⚠ TASARIM KARARI
  ///
  /// Önceki hâl düz bir metin listesiydi; seçili satır yalnız `✓`
  /// karakteriyle işaretleniyordu ve satırlar birbirinden ayrışmıyordu.
  /// Yeni düzen her seçeneği KART olarak çizer:
  ///
  ///   [ikon]  Başlık                                   (◉)
  ///           Açıklama
  ///
  ///   • Seçili kart: açık mavi zemin + mavi kenarlık
  ///   • İkon rozeti: seçilide mavi dolu, diğerlerinde açık gri
  ///   • Sağda gerçek bir SEÇİM DAİRESİ (`✓` metni değil)
  ///
  /// Böylece dokunulabilir alan büyür, seçili durum bir bakışta
  /// okunur ve panel kurumsal bir görünüm kazanır.
  Future<void> _secimSheet({
    required String baslik,
    required List<(String, String, String, String)> secenekler,
    required String secili,
    required ValueChanged<String> onSec,
  }) async {
    final v = await RefBottomSheet.goster<String>(
      context,
      title: baslik,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in secenekler) ...[
            RefSecimKarti(
              ikon: o.$4,
              baslik: o.$2,
              aciklama: o.$3,
              secili: o.$1 == secili,
              onTap: () => Navigator.of(context).pop(o.$1),
            ),
            // Kompakt panel: kartlar arası boşluk da daraltıldı.
            if (o != secenekler.last) const SizedBox(height: 6),
          ],
          const SizedBox(height: 2),
        ],
      ),
    );
    if (v != null) {
      onSec(v);
    }
  }
}

/// `.cust-card` — ilan kartı.
///
/// ```css
/// .cust-card{background:#fff;border:1px solid #ECEEF1;border-radius:12px;
///   padding:9px 12px 9px;box-shadow:0 1px 6px rgba(20,40,80,.04)}
/// .cc-title{15px/700 #16233D; ls -.2}
/// .cc-meta {11.5px #98A2B3; gap:5px; margin-top:3px}
/// .cc-desc {12px/1.45 #5B6472; margin-top:4px}
/// ```
class _IlanKarti extends StatelessWidget {
  const _IlanKarti({
    required this.listing,
    required this.teklifSayisi,
    required this.onTap,
  });

  final Listing listing;
  final int teklifSayisi;
  final VoidCallback onTap;

  /// Referansta `x.time` biçimli göreli zamandır.
  String get _zaman {
    final f = DateTime.now().difference(listing.createdAt);
    if (f.inMinutes < 60) {
      return '${f.inMinutes} dk önce';
    }
    if (f.inHours < 24) {
      return '${f.inHours} saat önce';
    }
    return '${f.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border), // #ECEEF1
          borderRadius: BorderRadius.circular(RR.r12),
          boxShadow: RS.soft6, // 0 1px 6px rgba(20,40,80,.04)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // .cc-head
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⚠ KATEGORİ SATIRI — kullanıcı ilana GİRMEDEN
                      // hangi işle ilgili olduğunu anlamalı
                      // (bkz. category_ui.kategoriAdi).
                      if (kategoriAdi(listing.title) != null)
                        Text(
                          kategoriAdi(listing.title)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: refText(
                            size: RF.s11,
                            weight: RF.w500,
                            color: RC.textSoft,
                            letterSpacing: RF.lsM01,
                          ),
                        ),
                      Text(
                        listing.title,
                        style: refText(
                          size: RF.s15,
                          weight: RF.w700,
                          color: RC.text,
                          letterSpacing: RF.lsM02,
                        ),
                      ),
                      // ⚠ İLAN NUMARASI ÖNİZLEMEDE GÖSTERİLMEZ.
                      //
                      // Ürün kuralı: numara YALNIZ detay ekranında,
                      // sağ üst köşede. Liste kartında yer kaplıyor ve
                      // kullanıcı kartları BAŞLIĞA göre tarıyor.
                    ],
                  ),
                ),
                const SizedBox(width: 10), // gap:10px
                // ⚠ ÖLÇÜ CSS'TEN GELİR, HTML ÇAĞRISINDAN DEĞİL.
                // `IC_CHEV('#16233D',20)` 20px ile çağrılır ama
                // `.cc-chev svg{width:16px;height:16px}` bunu EZER.
                // Cihazda görünen boyut 16px'tir.
                const Padding(
                  padding: EdgeInsets.only(top: 1), // .cc-chev{margin-top:1px}
                  child:
                      RefSvg('assets/svg/ic_chev.svg', size: 16, color: RC.text),
                ),
              ],
            ),

            // .cc-meta{margin-top:3px}
            const SizedBox(height: 3),
            Row(
              children: [
                // ⚠ `.cc-meta svg{width:13px;height:13px}` — HTML
                // `IC_PIN(...,17)` ile çağırsa da CSS 13px'e indirir.
                const RefSvg('assets/svg/ic_pin.svg',
                    size: 13, color: RC.greyLight),
                const SizedBox(width: 5), // gap:5px
                Flexible(
                  child: Text(
                    listing.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s115, weight: RF.w400, color: RC.greyLight),
                  ),
                ),
                // .cc-sep{color:#D3D8E0;margin:0 1px}
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '|',
                    style: refText(
                        size: RF.s115,
                        weight: RF.w400,
                        color: const Color(0xFFD3D8E0)),
                  ),
                ),
                // ⚠ `.cc-meta svg{13px}` — `IC_CLOCK(16)` çağrısını EZER.
                const RefSvg('assets/svg/ic_clock.svg',
                    size: 13, color: RC.greyLight),
                const SizedBox(width: 5),
                Text(
                  _zaman,
                  style: refText(
                      size: RF.s115, weight: RF.w400, color: RC.greyLight),
                ),
              ],
            ),

            // .cc-desc{margin-top:4px}
            // ⚠ Kart standardı: 12,5/w500/RC.textSoft. Detay
            // ekranlarından bir tık küçük ve gri — kartta başlık önde
            // kalmalı — ama Regular değil Medium, çünkü asıl silinen
            // buydu. Bkz. ilan_aciklama_tipografisi_test.
            const SizedBox(height: 5),
            Text(
              listing.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: refText(
                size: RF.s125,
                weight: RF.w500,
                color: RC.textSoft,
                height: RF.lh145,
              ),
            ),

            // custBadge(x.offers)
            const SizedBox(height: 6), // .cc-badge{margin-top:6px}
            TeklifRozeti(sayi: teklifSayisi),
          ],
        ),
      ),
    );
  }
}

/// ⚠ KOPYA ROZET KALDIRILDI (9 Eyl): metin ve renk artık
/// `widgets/teklif_rozeti.dart` içinde TEK yerde tanımlı. Bu dosyada
/// ayrı bir kopya vardı ve "Henüz" düzeltmesi yalnız `jobs_screen`e
/// uygulandığı için burada eski metin kalmıştı.

/// `.cust-empty{text-align:center;color:#98A2B3;font-size:14px;padding:40px 0}`
class _BosListe extends StatelessWidget {
  const _BosListe();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Bu sekmede gösterilecek ilan yok.',
          textAlign: TextAlign.center,
          style: refText(
              size: RF.s14, weight: RF.w400, color: RC.greyLight),
        ),
      );
}

/// ── ⚠ "BUL" ÜZERİNDEN KABUL EDİLEN TEKLİF — `_IlanKarti` İLE AYNI
/// GÖRSEL DİL (çerçeve, gölge, başlık+ok, meta satırı) ──
///
/// `_IlanKarti`'nin BİREBİR AYNISI DEĞİL çünkü `TeklifTalebi`nin
/// alanları farklıdır (kategori/başlık yerine hizmet+hizmet veren
/// adı; ilan konumu yerine fiyat). Görsel çerçeve — kutu, gölge,
/// tipografi ölçüleri — KORUNDU; yeni bir kart dili İCAT EDİLMEDİ.
class _TeklifTalebiIsKarti extends StatelessWidget {
  const _TeklifTalebiIsKarti({required this.talep, required this.onTap});

  final TeklifTalebi talep;
  final VoidCallback onTap;

  String get _zaman {
    final baz = talep.teklifTarihi;
    if (baz == null) return '';
    final f = DateTime.now().difference(baz);
    if (f.inMinutes < 60) return '${f.inMinutes} dk önce';
    if (f.inHours < 24) return '${f.inHours} saat önce';
    return '${f.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border),
          borderRadius: BorderRadius.circular(RR.r12),
          boxShadow: RS.soft6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⚠ "BUL" kökenli olduğu AYIRT EDİLEBİLİR
                      // olsun diye küçük bir etiket satırı — normal
                      // ilanlardan farkı kullanıcıya belli olsun.
                      Text('Doğrudan Teklif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: refText(
                            size: RF.s11,
                            weight: RF.w500,
                            color: RC.textSoft,
                            letterSpacing: RF.lsM01,
                          )),
                      Text(
                        talep.hizmet,
                        style: refText(
                          size: RF.s15,
                          weight: RF.w700,
                          color: RC.text,
                          letterSpacing: RF.lsM02,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: RefSvg('assets/svg/ic_chev.svg',
                      size: 16, color: RC.text),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const RefSvg('assets/svg/ic_avlock.svg',
                    size: 13, color: RC.greyLight),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    talep.saglayiciAdi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s115, weight: RF.w400, color: RC.greyLight),
                  ),
                ),
                if (_zaman.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('|',
                        style: refText(
                            size: RF.s115,
                            weight: RF.w400,
                            color: const Color(0xFFD3D8E0))),
                  ),
                  Text(_zaman,
                      style: refText(
                          size: RF.s115,
                          weight: RF.w400,
                          color: RC.greyLight)),
                ],
              ],
            ),
            if (talep.teklifFiyati != null) ...[
              const SizedBox(height: 6),
              Text(tutarMetni(talep.teklifFiyati!),
                  style: refText(
                      size: RF.s135, weight: RF.w700, color: HC.green)),
            ],
          ],
        ),
      ),
    );
  }
}
