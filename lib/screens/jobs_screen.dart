import 'package:flutter/material.dart';
import '../domain/hata_mesajlari.dart';
import 'widgets/hata_gosterimi.dart';
import 'widgets/ilan_no_etiketi.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/models/listing.dart';
import '../data/models/offer.dart';
import 'job_detail_screen.dart';
import 'status_ui.dart';
import 'widgets/hc_widgets.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import 'nav_actions.dart';
import '../domain/config.dart';
import '../domain/eslestirme.dart';
import '../data/controllers/incelenen_ilan_controller.dart';

/// Hizmet veren — İŞLERİM / KAZANDIĞIM sekmeleri (HTML vCust provider).
///
/// ⚠ Sekmeler üstteki segment kutusundan ALT BARA taşındı; adları da
/// "Uygun İşler / Tekliflerim" değil "İşlerim / Kazandığım"dır. Ekran
/// metinleri bu adları kullanmalıdır — kullanıcı olmayan bir sekmeye
/// yönlendirilmemelidir.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, this.kazandigim = false});

  /// ⚠ SEKMELER ALT NAVİGASYONA TAŞINDI.
  ///
  /// Üstteki "Yeni işler / Kazandığım işler" segment sekmesi
  /// KALDIRILDI; iki liste artık alt barın iki ayrı sekmesidir.
  /// Bu bayrak hangi listenin açılacağını söyler.
  final bool kazandigim;
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  /// ÜST SEKME — yalnız `/provider/jobs` ekranında anlamlıdır.
  ///
  /// `true`  → Yeni işler
  /// `false` → Teklif verdiklerim
  ///
  /// ⚠ `/provider/won` ekranında segment çizilmez; orada bu değer
  /// `false` kalır ve liste `widget.kazandigim` ile belirlenir.
  late bool _jobsTab = !widget.kazandigim;

  /// SIRALAMA — hizmet alan tarafıyla AYNI kart düzeni, sağlayıcıya
  /// uygun ölçütler.
  String _sort = 'new';
  String _filtre = 'all';

  /// Kazandığım sekmesinin sıralaması — bkz. `myOffers` notu.
  String _kazSort = 'yeni';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Uygun işler ve kendi tekliflerim yeniden yüklenir.
  /// Sırala paneli — müşteri tarafıyla AYNI kart düzeni.
  Future<void> _siralaMenu() => _secimSheet(
        baslik: 'Sırala',
        // ⚠ SEÇENEKLER SEKMEYE GÖRE DEĞİŞİR.
        //
        // Sekmeler alt bardan üst segmente taşındığı için ölçüt artık
        // `widget.kazandigim` yerine `_jobsTab` ile belirlenir; aksi
        // hâlde kullanıcı sekme değiştirse bile eski panel açılırdı.
        secenekler: _jobsTab ? _kIsSiralama : _kKazandigimSiralama,
        secili: _jobsTab ? _sort : _kazSort,
        onSec: (v) => setState(() {
          if (_jobsTab) {
            _sort = v;
          } else {
            _kazSort = v;
          }
        }),
      );

  /// Filtreler paneli.
  Future<void> _filtreMenu() => _secimSheet(
        baslik: 'Filtreler',
        secenekler: _kIsFiltre,
        secili: _filtre,
        onSec: (v) => setState(() => _filtre = v),
      );

  /// Seçim yarım ekranı — kart düzeni `my_listings_screen` ile aynıdır:
  /// ikon rozeti + başlık + açıklama + seçim dairesi.
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

  Future<void> _refresh() async {
    await context.read<ListingController>().loadAvailable();
    if (!mounted) {
      return;
    }
    await context.read<OfferController>().loadMine();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentAccount!;
    final listingCtl = context.watch<ListingController>();
    final offerCtl = context.watch<OfferController>();
    final incelenenCtl = context.watch<IncelenenIlanController>();

    // ── UYGUN İŞLER ──
    //
    // İş kuralı:
    //   1) İlan, sağlayıcının SEÇTİĞİ KATEGORİDE olmalı.
    //   2) Normalde HİZMET VERDİĞİ İLÇELERDEKİ ilanlar düşer.
    //   3) ⚠ OTOMATİK GENİŞLEME: seçili ilçelerde, seçili kategoride
    //      1 SAATTEN UZUN süredir yeni ilan düşmediyse kapsam
    //      İL GENELİNE genişler. Sağlayıcı boş ekranla beklemez.
    //
    // Kategori veya bölge seçimi HENÜZ YAPILMAMIŞSA o kısıt
    // uygulanmaz (onboarding tamamlanmadan ekran boş kalmasın).
    bool acikVeBaskasinin(Listing l) =>
        l.status == ListingStatus.open && l.ownerId != me.id;

    /// BÖLGE EŞLEŞMESİ
    ///
    /// İlan konumu "Mahalle, İlçe / İl" biçimindedir; sağlayıcının
    /// seçtiği ilçelerden biri geçiyorsa eşleşir.
    ///
    /// ⚠ Bölge seçimi HENÜZ YAPILMAMIŞSA kısıt uygulanmaz.
    bool ilceUygun(Listing l) =>
        me.serviceDistricts.isEmpty ||
        me.serviceDistricts.any((ilce) => l.location.contains(ilce));

    /// KATEGORİ EŞLEŞMESİ — kural `lib/domain/eslestirme.dart`
    ///
    /// ⚠ EKRAN KENDİ KURALINI YAZMAZ. Aynı kural backend'de de
    /// bulunacağı için tek bir saf fonksiyonda tutulur; ekran yalnız
    /// çağırır.
    ///
    /// İki kademe vardır:
    ///   0 · DOĞRUDAN — hizmet verenin seçtiği hizmetin kendisi
    ///   1 · AİLE     — seçtiği ana kategoriyle aynı aileden gelen iş
    ///
    /// ⚠ KULLANICIYA HİÇBİR ŞEY GÖSTERİLMEZ: kademe yalnız SIRALAMAYI
    /// belirler. Ekranda etiket, rozet, açıklama ya da ayar YOKTUR.
    ///
    /// ⚠ Seçim yapılmamışsa kısıt uygulanmaz (onboarding).
    int oncelik(Listing l) => eslesmeOnceligi(me.categories, l.title);
    bool kategoriUygun(Listing l) => oncelik(l) != kEslesmeYok;

    // Kategoriye uyan tüm açık ilanlar (il geneli).
    final kategoriUyanlar =
        listingCtl.all.where((l) => acikVeBaskasinin(l) && kategoriUygun(l));

    // Seçili ilçelerdeki ilanlar.
    final ilceIcindekiler = kategoriUyanlar.where(ilceUygun).toList();

    // Son 1 saatte seçili ilçelerde yeni ilan var mı?
    final esik = DateTime.now().subtract(DomainConfig.areaExpandAfter);
    final sonSaatteIlanVar =
        ilceIcindekiler.any((l) => l.createdAt.isAfter(esik));

    // ⚠ GENİŞLEME: son 1 saatte ilçe içinde yeni ilan yoksa il geneli.
    final genislet = !sonSaatteIlanVar;
    var jobs = (genislet ? kategoriUyanlar.toList() : ilceIcindekiler);

    // ── FİLTRE ──
    //
    // ⚠ Sağlayıcıya ANLAMLI ölçütler: teklif verdiklerim / vermedikler
    // ve yalnız kendi ilçelerim. Müşteri tarafındaki ölçütlerin burada
    // karşılığı yoktur, kopyalanmadı.
    final teklifVerdiklerim = offerCtl
        .offersByProvider(me.id)
        .where((o) => o.status != OfferStatus.cancelled)
        .map((o) => o.listingId)
        .toSet();
    jobs = switch (_filtre) {
      'mine' => jobs.where((l) => teklifVerdiklerim.contains(l.id)).toList(),
      'new' => jobs.where((l) => !teklifVerdiklerim.contains(l.id)).toList(),
      'near' => jobs.where(ilceUygun).toList(),
      _ => jobs,
    };

    // ── SIRALAMA ──
    // ⚠ `yeni` ve `teklifsiz` ÖNCE GRUPLAR, SONRA tarihe göre sıralar.
    //
    // Tek ölçüt yeterli değildir: aynı gruptaki işler arasında da bir
    // düzen gerekir, yoksa liste her yeniden çizimde farklı sırada
    // görünebilir.
    // ⚠ Yukarıdaki `esik` (bölge genişletme) ile AYNI değeri kullanır
    // ama farklı amaca hizmet eder; ayrı adla tutulur ki biri
    // değişince diğeri sessizce kaymasın.
    final yeniEsigi = DateTime.now().subtract(DomainConfig.areaExpandAfter);
    int grupYeni(Listing l) => l.createdAt.isAfter(yeniEsigi) ? 0 : 1;
    int grupTeklifsiz(Listing l) =>
        offerCtl.offersForListing(l.id).isEmpty ? 0 : 1;

    /// Kullanıcının seçtiği ölçüte göre karşılaştırma.
    /// ⚠ Ölçüt mantığı DEĞİŞMEDİ; yalnız ayrı bir işleve alındı ki
    /// öncelik anahtarı onun ÜSTÜNDE uygulanabilsin.
    int olcuteGore(Listing a, Listing b) => switch (_sort) {
          'yeni' => grupYeni(a) != grupYeni(b)
              ? grupYeni(a).compareTo(grupYeni(b))
              : b.createdAt.compareTo(a.createdAt),
          'teklifsiz' => grupTeklifsiz(a) != grupTeklifsiz(b)
              ? grupTeklifsiz(a).compareTo(grupTeklifsiz(b))
              : b.createdAt.compareTo(a.createdAt),
          'old' => a.createdAt.compareTo(b.createdAt),
          'offasc' => offerCtl
              .offersForListing(a.id)
              .length
              .compareTo(offerCtl.offersForListing(b.id).length),
          'offdesc' => offerCtl
              .offersForListing(b.id)
              .length
              .compareTo(offerCtl.offersForListing(a.id).length),
          _ => b.createdAt.compareTo(a.createdAt),
        };

    // ── ⚠ ÖNCELİK BİRİNCİL ANAHTARDIR ──
    //
    // Hizmet verenin KENDİ SEÇTİĞİ kategorilerden gelen ilanlar her
    // zaman önce gelir; aile üzerinden düşen işler onların ARDINA
    // eklenir. Kullanıcının seçtiği sıralama ölçütü bu iki grubun
    // İÇİNDE uygulanır — gruplar birbirine karışmaz.
    //
    // ⚠ Bu ayrım kullanıcıya GÖSTERİLMEZ: başlık, etiket ya da
    // ayırıcı çizgi yoktur, yalnız sıra değişir.
    jobs.sort((a, b) {
      final oa = oncelik(a);
      final ob = oncelik(b);
      return oa != ob ? oa.compareTo(ob) : olcuteGore(a, b);
    });

    // ⚠ SEÇİLMEYEN TEKLİF LİSTEDEN KALKAR.
    //
    // Müşteri bir teklifi seçtiğinde diğerleri iptal edilir ve
    // (iletişimi açılmamışsa) blokeleri iade edilir. O ilan artık bu
    // hizmet vereni ilgilendirmez; ekranından KALDIRILIR.
    // ── TEKLİF LİSTESİ — EKRANA GÖRE AYRI ──
    //
    // ⚠ ÜÇ LİSTE ÜÇ AYRI ŞEYDİR:
    //   • Yeni işler          → henüz teklif VERİLMEMİŞ açık ilanlar
    //   • Teklif verdiklerim  → teklif verilmiş, CEVAP BEKLEYEN işler
    //   • Kazandığım          → müşterinin SEÇTİĞİ işler
    //
    // `/provider/won` ekranı yalnız SEÇİLENLERİ gösterir; `/provider/jobs`
    // içindeki "Teklif verdiklerim" sekmesi ise BEKLEYENLERİ. Aynı
    // listeyi paylaşsalardı bekleyen teklifler hiçbir yerde
    // görünmezdi.
    final myOffers = offerCtl
        .offersByProvider(me.id)
        .where((o) => widget.kazandigim
            ? o.status == OfferStatus.selected
            : o.status == OfferStatus.active)
        .toList();

    // ── SIRALAMA ──
    //
    // ⚠ AYRI DURUM (`_kazSort`). Bu listenin ölçütleri "Yeni işler"
    // sekmesininkilerden farklıdır; tek değişkeni paylaşsalardı bir
    // sekmede yapılan seçim diğerini de bozardı.
    myOffers.sort((a, b) => switch (_kazSort) {
          'eski' => a.createdAt.compareTo(b.createdAt),
          'yuksek' => b.amount.compareTo(a.amount),
          'dusuk' => a.amount.compareTo(b.amount),
          _ => b.createdAt.compareTo(a.createdAt),
        });

    // ⚠ ALT NAVİGASYON EKLENDİ.
    //
    // Sağlayıcının ana ekranı düz `Scaffold` kullanıyordu ve referans
    // `custNav()` alt barı HİÇ ÇİZİLMİYORDU. Diğer ekranlarla aynı
    // Bar rol duyarlıdır: sağlayıcıda "İlan Ver" sekmesi gösterilmez.
    // ⚠ `RefShell` KULLANILMAZ.
    //
    // `RefShell` içeriği `RefScroll` (kaydırılabilir) içine koyar.
    // Bu ekranın gövdesinde `Expanded` + `ListView` vardır; kaydırma
    // içinde `Expanded` yükseklik ALAMAZ, Column çöker ve ekran boş
    // kalır (alt bar yukarı kayar).
    //
    // Bu yüzden `Scaffold.bottomNavigationBar` kullanılır: liste kendi
    // kaydırmasını yönetir, alt bar sabit altta kalır.
    return Scaffold(
      backgroundColor: RC.pageBg,
      bottomNavigationBar: RefBottomNav(
        // Hangi listedeysek o sekme etkin görünür.
        activeKey: widget.kazandigim ? 'kazandigim' : 'ilanlarim',
        items: custNavItems(context, saglayici: true),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // ── `.cust-tabs` — İKİ SEKME ──
          //
          // ⚠ Hizmet alan ekranıyla AYNI bileşen (`RefSegmentTabs`) ve
          // aynı ölçüler kullanılır; iki taraf ayrışamaz.
          //
          // Sekmeler alt bardan buraya taşındı: "Yeni işler" ve
          // "Teklif verdiklerim" aynı listenin iki görünümüdür,
          // ayrı alt bar sekmesi olmaları gezinmeyi bölüyordu.
          // ⚠ SEGMENT YALNIZ `/provider/jobs` EKRANINDA.
          //
          // `/provider/won` (Kazandığım) ayrı bir ekrandır ve tek liste
          // gösterir; orada sekme çubuğu çizmek kullanıcıya olmayan bir
          // seçim sunardı.
          if (!widget.kazandigim)
            RefSegmentTabs(
              selected: _jobsTab ? 0 : 1,
              onChanged: (i) => setState(() => _jobsTab = i == 0),
              items: const [
                (asset: 'assets/svg/ic_plane.svg', label: 'Yeni işler'),
                (
                  asset: 'assets/svg/ic_checkc.svg',
                  label: 'Teklif verdiklerim'
                ),
              ],
            ),

          // ── `.cust-bar` — sayı + araçlar ──
          //
          // ⚠ ROL ETİKETİ KALDIRILDI: yalnız Profil ekranında kalır.
          // Her ekranda tekrarlanması yer kaplıyordu.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: RefListCount(
                      '${_jobsTab ? jobs.length : myOffers.length} ilan bulundu'),
                ),
                const SizedBox(width: 10),
                RefPillButton(
                  iconAsset: 'assets/svg/ic_sort.svg',
                  label: 'Sırala',
                  onTap: _siralaMenu,
                ),
                // ⚠ TEKLİF VERDİKLERİM SEKMESİNDE FİLTRE YOKTUR.
                //
                // O liste kısadır; filtre kutusu kullanıldığından çok
                // yer kaplardı. Sıralama işi görüyor.
                if (_jobsTab) ...[
                  const SizedBox(width: 8),
                  RefPillButton(
                    iconAsset: 'assets/svg/ic_filter.svg',
                    label: 'Filtreler',
                    onTap: _filtreMenu,
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            // Liste ekranı: aşağı çekerek yenileme (her iki sekme için).
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: HC.blue,
              child: _jobsTab
                // ── ⚠ HATA YALNIZ GERÇEKTEN OLUNCA ──
                //
                // "Uygun iş yok" ile "işler yüklenemedi" ayrı
                // şeylerdir. Birincisinde bekleyecek, ikincisinde
                // tekrar deneyecek.
                ? (hataGosterilsinMi(
                        yukleniyor: listingCtl.loading,
                        hata: listingCtl.lastError,
                        veriVar: jobs.isNotEmpty)
                    ? _pullable(HataTamEkran(
                        hata: listingCtl.lastError!, onTekrar: _refresh))
                    : jobs.isEmpty
                    ? _pullable(const SysEmpty(
                            title: 'Şu anda uygun iş yok',
                            desc: 'Yeni ilanlar yayınlandıkça burada listelenecek.'))
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        // ⚠ Kapsam genişlemesi SİSTEM İÇİDİR.
                        // Kullanıcıya bilgi satırı/uyarı GÖSTERİLMEZ;
                        // liste sessizce genişler.
                        itemCount: jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final l = jobs[i];
                          final mine = offerCtl.myOfferFor(l.id, me.id);
                          return _jobCard(context, l,
                              incelendi: incelenenCtl.incelendiMi(l.id),
                              teklifAdedi:
                                  offerCtl.offersForListing(l.id).length,
                              trailing: mine != null
                                  ? const StatusChip('Teklif Verildi', HC.blue)
                                  : RefSvg('assets/svg/ic_chev.svg', size: 20, color: RC.greyLight));
                        }))
                : (myOffers.isEmpty
                    // ⚠ BOŞ DURUM METNİ EKRANA GÖRE DEĞİŞİR.
                    //
                    // İki liste ayrı şeydir: `/provider/won` kazanılan
                    // işleri, "Teklif verdiklerim" sekmesi cevap
                    // bekleyenleri gösterir. Tek metin ikisini de
                    // anlatamaz.
                    ? _pullable(widget.kazandigim
                        ? const SysEmpty(
                            title: 'Kazandığınız iş yok',
                            desc: 'Teklifleriniz kabul edildiğinde burada '
                                'listelenir.')
                        : const SysEmpty(
                            title: 'Bekleyen teklifiniz yok',
                            desc: 'Yeni işler sekmesinden ilanlara teklif '
                                'verebilirsiniz.'))
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: myOffers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final o = myOffers[i];
                          final l = listingCtl.byId(o.listingId);
                          final (label, color) = offerStatusUi(o.status);
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: l == null
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => JobDetailScreen(
                                              listingId: l.id))),
                              child: Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                    border: Border.all(color: HC.border),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(l?.title ?? 'İlan kaldırıldı',
                                              style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: HC.dark)),
                                          const SizedBox(height: 3),
                                          Text(l?.location ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12, color: HC.grey)),
                                        ]),
                                  ),
                                  Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(tl(o.amount),
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: HC.dark)),
                                        StatusChip(label, color),
                                      ]),
                                ]),
                              ),
                            ),
                          );
                        })),
            ),
          ),
        ]),
      ),
    );
  }

  /// Boş durumda da aşağı çekerek yenileme çalışsın diye kaydırılabilir
  /// bir kabuk; görünüm aynı kalır (dikeyde ortalanmış).
  Widget _pullable(Widget child) => LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(child: child),
          ),
        ),
      );

  /// İlan kartı.
  ///
  /// ⚠ İNCELENMEMİŞ ilan: KALIN yazı + KALIN çerçeve.
  ///    İNCELENMİŞ ilan : normal yazı + ince çerçeve.
  /// Ayrıca rozet/nokta gibi bir işaret GÖSTERİLMEZ; fark yalnız
  /// yazı ve çerçeve kalınlığındadır.
  Widget _jobCard(BuildContext context, Listing l,
          {required Widget trailing,
          bool incelendi = false,
          int teklifAdedi = 0}) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => JobDetailScreen(listingId: l.id))),
          child: Container(
            padding: const EdgeInsets.all(13),
            // ── OKUNMAMIŞ İLAN YEŞİL VE KALIN ──
            //
            // ⚠ Okunmamış ilan MAVİ çerçeveliydi; mavi uygulamanın her
            // yerinde kullanılan ana renk olduğu için "yeni" anlamı
            // taşımıyordu. Yeşil bu ekranda başka hiçbir yerde
            // kullanılmaz — bakışta ayırt edilir.
            //
            // Fark YALNIZ RENKTE değil: okunmamışta çerçeve kalın,
            // başlık ve konum daha koyu/kalın. Okunduktan sonra
            // tamamı inceltilip griye döner.
            decoration: BoxDecoration(
                border: Border.all(
                    color: incelendi ? HC.border : _kYeniRenk,
                    width: incelendi ? 1 : 2),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight:
                              incelendi ? FontWeight.w600 : FontWeight.w800,
                          color: incelendi ? HC.dark : _kYeniKoyu)),
                  // ⚠ İkincil bilgi — başlığın altında, küçük.
                  const SizedBox(height: 2),
                  IlanNoEtiketi(l),
                  const SizedBox(height: 3),
                  Text(l.location,
                      style: TextStyle(
                          fontSize: 12,
                          // Okunmamışta konum da bir tık kalın.
                          fontWeight:
                              incelendi ? FontWeight.w400 : FontWeight.w600,
                          color: incelendi ? HC.grey : _kYeniKoyu)),
                  // ── TEKLİF SAYISI ──
                  // Referans `.cc-badge`: "Henüz teklif verilmedi" /
                  // "N teklif verildi". Sağlayıcı, ilana kaç kişinin
                  // teklif verdiğini görür.
                  const SizedBox(height: 7),
                  _TeklifRozeti(adet: teklifAdedi),
                  const SizedBox(height: 5),
                  // ⚠ Kart standardı: 12,5/w500. Burası tek yerde ham
                  // `TextStyle` kullanıyordu, `refText`'e çekildi.
                  // Okunmuş/okunmamış ayrımı KORUNDU: okunmamışta
                  // açıklama okunur koyulukta, okununca soluk grileşir.
                  Text(l.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s125,
                          weight: RF.w500,
                          color: incelendi ? RC.grey : RC.textSoft,
                          height: RF.lh145)),
                ]),
              ),
              const SizedBox(width: 8),
              trailing,
            ]),
          ),
        ),
      );
}


/// TEKLİF SAYISI ROZETİ — referans `.cc-badge`
///
/// ```css
/// .cc-badge{display:inline-flex;gap:6px;padding:4px 9px;
///           border-radius:8px;font-size:11.5px;font-weight:600}
/// ```
///
/// Sağlayıcı, ilana kaç kişinin teklif verdiğini görür:
///   • 0 teklif → gri  "Henüz teklif verilmedi"
///   • 1-3      → mavi "N teklif verildi"
///   • 4+       → turuncu (rekabet yüksek)
class _TeklifRozeti extends StatelessWidget {
  const _TeklifRozeti({required this.adet});

  final int adet;

  @override
  Widget build(BuildContext context) {
    final (zemin, yazi) = switch (adet) {
      0 => (const Color(0xFFF2F4F7), const Color(0xFF667085)),
      < 4 => (RC.blueSoft, RC.blue),
      _ => (const Color(0xFFFFF4E5), const Color(0xFFF5820C)),
    };
    final metin = adet == 0 ? 'Henüz teklif verilmedi' : '$adet teklif verildi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        RefSvg('assets/svg/ic_chat.svg', size: 14, color: yazi),
        const SizedBox(width: 6),
        Text(metin,
            style: refText(size: 11.5, weight: RF.w600, color: yazi)),
      ]),
    );
  }
}


// ⚠ `_AracButonu` KALDIRILDI.
//
// Araç çubuğu hizmet alan ekranıyla aynı bileşenlere geçti
// (`RefListCount` + `RefPillButton`); bu yerel kopya artık
// çağrılmıyordu.


/// SAĞLAYICI SIRALAMA SEÇENEKLERİ — `(anahtar, başlık, açıklama, ikon)`
///
/// Müşteri tarafıyla AYNI kart düzeni kullanılır; ölçütler sağlayıcıya
/// göre yazılmıştır.
/// OKUNMAMIŞ İLAN RENGİ — çerçeve.
///
/// ⚠ Yeşil bu ekranda BAŞKA HİÇBİR YERDE kullanılmaz; "yeni" anlamı
/// böyle ayırt edilir. Mavi ana renk olduğu için bu işi göremiyordu.
const Color _kYeniRenk = Color(0xFF16A34A);

/// Okunmamış ilanın metin rengi — çerçeveyle aynı aileden, koyu.
const Color _kYeniKoyu = Color(0xFF0F7A38);

const _kIsSiralama = [
  ('new', 'En yeniler önce', 'Yeni yayınlanan işler üstte',
      'assets/svg/ic_clock.svg'),
  // ⚠ BUNLAR FİLTRE DEĞİL SIRALAMADIR.
  //
  // İlanı LİSTEDEN ÇIKARMAZLAR, yalnız üste taşırlar. Filtre olsaydı
  // kullanıcı diğer işleri hiç göremezdi; sıralamada ise öncelik
  // verilir, gerisi altta durur.
  ('yeni', 'Yeni ilanlar önce', 'Son 1 saatte yayınlananlar üstte',
      'assets/svg/ic_plane.svg'),
  ('teklifsiz', 'Teklif verilmeyenler önce',
      'Henüz hiç teklif almamış işler üstte', 'assets/svg/ic_chat.svg'),
  ('old', 'En eskiler önce', 'Uzun süredir bekleyen işler üstte',
      'assets/svg/ic_clock.svg'),
  ('offasc', 'En az teklif alan', 'Rekabetin düşük olduğu işler üstte',
      'assets/svg/ic_chat.svg'),
  ('offdesc', 'En çok teklif alan', 'Teklifi bol işler üstte',
      'assets/svg/ic_chat.svg'),
];

/// KAZANDIĞIM SEKMESİ — SIRALAMA SEÇENEKLERİ.
///
/// ⚠ "Teklif" değil "iş" dili kullanılır: bu listedeki kayıtlar
/// müşterinin ONAYLADIĞI, yani alınmış işlerdir.
const _kKazandigimSiralama = [
  ('yeni', 'Yeniden - eskiye', 'Son alınan işler üstte',
      'assets/svg/ic_clock.svg'),
  ('eski', 'Eskiden - yeniye', 'İlk alınan işler üstte',
      'assets/svg/ic_clock.svg'),
  ('yuksek', 'Teklif tutarı yüksek olan', 'Yüksek tutarlı işler üstte',
      'assets/svg/ic_walletg.svg'),
  ('dusuk', 'Teklif tutarı düşük olan', 'Düşük tutarlı işler üstte',
      'assets/svg/ic_walletg.svg'),
];

const _kIsFiltre = [
  ('all', 'Tüm işler', 'Hiçbir filtre uygulanmaz',
      'assets/svg/ic_clip.svg'),
  ('new', 'Teklif vermediklerim', 'Henüz teklif vermediğiniz işler',
      'assets/svg/ic_clock.svg'),
  ('mine', 'Teklif verdiklerim', 'Teklif verdiğiniz işler',
      'assets/svg/ic_checkc.svg'),
  ('near', 'Yalnız bölgemdekiler', 'Hizmet ilçelerinizdeki işler',
      'assets/svg/ic_ppin.svg'),
];
