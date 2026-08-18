import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/wallet_controller.dart';
import '../data/models/wallet.dart';
import 'topup_screen.dart';
import '../data/controllers/free_right_controller.dart';
import 'widgets/hc_widgets.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';

/// Hizmet veren — Cüzdanım (HTML vWallet): kullanılabilir / blokeli /
/// toplam bakiye + ledger hareketleri ve tür filtreleri.
/// Tüm finansal veriler YALNIZ Wallet/Ledger kaynağından okunur.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

// ── ⚠ EKRAN KORUMASI AÇIK ──
//
// Bu ekranda bakiye ve işlem geçmişi görünür. Koruma açıkken ekran görüntüsü
// alınamaz ve son uygulamalar listesinde önizleme çizilmez.
class _WalletScreenState extends State<WalletScreen>
 {
  /// SEÇİLİ İŞLEM TÜRÜ — `null`: tür ayrımı yok (tüm hareketler).
  TxKind? _filter;

  /// FİLTRE UYGULANDI MI?
  ///
  /// ⚠ YATAY HAP ÇUBUĞU (`.wx-pills`) KALDIRILDI.
  ///
  /// Beş hap küçük ekrana sığmıyordu: sonuncusu ("İletişim Açma")
  /// kenardan taşıyor, kullanıcı yatay kaydırmadan onu göremiyordu.
  /// Ayrıca "Tümünü Gör" bağlantısı hem listeyi açıyor hem filtre
  /// çubuğunu getiriyordu — tek düğme iki iş yapıyordu.
  ///
  /// YENİ DAVRANIŞ: başlığın sağındaki düğme "Filtrele"dir ve
  /// uygulamanın diğer ekranlarıyla (Sırala/Filtreler) aynı yarım
  /// ekranı açar. Seçim yapılınca liste TAMAMI o türle süzülür.
  ///
  ///   `false` → ÖZET: son 5 işlem, sayaç yok
  ///   `true`  → TAM LİSTE: seçilen türe göre süzülmüş, sayaç var
  bool _filtreli = false;

  /// `txIcon(k)` — işlem türüne göre ZEMİN + İKON.
  ///
  /// ```js
  /// load    → ['#E1F5EA', IC_DL(18,'#16A34A')]
  /// block   → ['#FBE6CE', IC_LOCKO(17)]
  /// refund  → ['#E7EFFD', IC_UL(18,'#1D6BE3')]
  /// contact → ['#EFE9FD', IC_CHATP(17)]
  /// ```
  ///
  /// ⚠ KULLANIM ALANI DARALDI: bu eşleme artık YALNIZ filtre
  /// panelindeki seçenek rozetlerinde kullanılır.
  ///
  /// İşlem listesindeki daire ikon KALDIRILDI: yükleme satırında
  /// çizilen "indirme oku" kullanıcıya bir dosya indirileceğini
  /// düşündürüyordu; bu ekranda indirilecek bir şey yok. İşlemin türü
  /// başlıkta ve tutarın işaretinde/renginde zaten okunuyor.
  (String, Color, Color) _txUi(TxKind k) => switch (k) {
        TxKind.load => (
            'assets/svg/ic_dl.svg',
            const Color(0xFF16A34A),
            const Color(0xFFE1F5EA),
          ),
        TxKind.block => (
            'assets/svg/ic_locko.svg',
            const Color(0xFFF5820C),
            const Color(0xFFFBE6CE),
          ),
        TxKind.refund => (
            'assets/svg/ic_ul.svg',
            const Color(0xFF1D6BE3),
            const Color(0xFFE7EFFD),
          ),
        TxKind.contact => (
            'assets/svg/ic_chatp.svg',
            const Color(0xFF7C3AED),
            const Color(0xFFEFE9FD),
          ),
      };

  /// FİLTRE SEÇENEKLERİNİN ETİKETLERİ.
  ///
  /// ⚠ Etiketler ÇOĞULDUR ve "Tüketim" değil "İletişim Açma"dır;
  /// seçenek bir işlem türünü değil o türden İŞLEMLERİ süzer.
  String _txLabel(TxKind k) => switch (k) {
        TxKind.load => 'Yüklemeler',
        TxKind.block => 'Blokeler',
        TxKind.refund => 'İadeler',
        TxKind.contact => 'İletişim Açma',
      };

  /// Filtre panelindeki açıklama satırı — kullanıcı türün ne
  /// anlama geldiğini bilmek zorunda kalmasın.
  String _txDesc(TxKind k) => switch (k) {
        TxKind.load => 'Cüzdana eklediğiniz bakiye',
        TxKind.block => 'Teklif verirken ayrılan tutar',
        TxKind.refund => 'Kullanılmadan geri dönen bloke',
        TxKind.contact => 'İletişim açıldığında düşen tutar',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Cüzdan ve hareketler (ledger) kaynaktan yeniden okunur.
  Future<void> _refresh() => context.read<WalletController>().load();

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>().myWallet;
    if (wallet == null) {
      return Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: Column(children: [
            const Expanded(
              child: Center(child: SysState(SysKind.sessionExpired)),
            ),
          ]),
        ),
      );
    }
    // ── LİSTE ──
    //
    // ÖZET (filtre yok): yalnız son 5 işlem — cüzdan ekranı bir özet
    // sayfasıdır, yüzlerce satır kaydırmak için tasarlanmamıştır.
    // FİLTRELİ: seçilen türün TAMAMI (tür seçilmediyse tüm hareketler).
    final txs = !_filtreli
        ? wallet.txs.take(5).toList()
        : (_filter == null
            ? wallet.txs
            : wallet.txs.where((t) => t.kind == _filter).toList());

    /// Şeritte yazan uygulanmış filtre adı.
    final filtreEtiketi =
        _filter == null ? 'Tüm hareketler' : _txLabel(_filter!);

    return Scaffold(
      // AppBar KALDIRILDI — referansta yok (başlık sayfa içinde).
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: RefDetailHeader(title: 'Cüzdanım'),
          ),
          // ── `.wl-grid` — İKİ AYRI KART, YAN YANA ──
          //
          // Referansta tek mavi degrade kart YOKTUR. İki kart vardır:
          //   .wl-card.green  → Kullanılabilir Bakiye  (#EDF8F1 / #D8EEDF)
          //   .wl-card.orange → Blokeli Bakiye         (#FDF4E8 / #F7E4C8)
          //
          // `.wl-ic{42px daire}` · `.wl-l{13.5/700}` · `.wl-v{24/800;-.4px}`
          // Tutar `12,50 TL` biçimindedir: ondalık AYIRICI VİRGÜLDÜR ve
          // `TL` küçük punto (`.wl-v small{13px/700}`).
          //
          // ⚠ "Toplam" alanı referansta YOKTUR — kaldırıldı.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            // ⚠ `IntrinsicHeight` ZORUNLU — EKRAN BOŞ AÇILIYORDU.
            //
            // `Row(crossAxisAlignment: stretch)` çocuklarına TIGHT
            // yükseklik kısıtı verir; o kısıt Row'un aldığı maxHeight
            // kadardır. Bu Row bir `Column` içinde durduğu için aldığı
            // maxHeight SONSUZDUR (Column dikey yönde gevşek kısıt
            // verir).
            //
            // Sonuç: kartlara `minHeight = maxHeight = infinity`
            // gidiyor ve layout
            //   "BoxConstraints forces an infinite height"
            // ile düşüyordu. Başlık çizilmiş, altındaki her şey
            // kaybolmuştu — cüzdan ekranı boş görünüyordu.
            //
            // `IntrinsicHeight` önce çocukların DOĞAL yüksekliğini
            // ölçer, sonra `stretch` ikisini o yükseklikte eşitler.
            // Kartlar yine eşit boyda kalır (biri açıklama satırı
            // taşır, öteki taşımaz).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Expanded(
                  child: _BakiyeKarti(
                    ikon: 'assets/svg/ic_walletg.svg',
                    ikonBoyut: 22,
                    ikonZemin: const Color(0xFFD8F0E1),
                    zemin: const Color(0xFFEDF8F1),
                    cerceve: const Color(0xFFD8EEDF),
                    etiket: 'Kullanılabilir Bakiye',
                    tutar: wallet.avail,
                    tutarRengi: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 11), // .wl-grid{gap:11px}
                Expanded(
                  child: _BakiyeKarti(
                    ikon: 'assets/svg/ic_locko.svg',
                    ikonBoyut: 20,
                    ikonZemin: const Color(0xFFFBE6CE),
                    zemin: const Color(0xFFFDF4E8),
                    cerceve: const Color(0xFFF7E4C8),
                    etiket: 'Blokeli Bakiye',
                    tutar: wallet.blocked,
                    tutarRengi: const Color(0xFFF5820C),
                    aciklama:
                        'Devam eden teklifleriniz için ayrılan bakiye.',
                  ),
                  ),
                ],
              ),
            ),
          ),
          // HTML vWallet: kartın ALTINDA `.po-next` "Bakiye Yükle"
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: RefWideButton(
              'Bakiye Yükle',
              iconAsset: 'assets/svg/ic_addbox.svg',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const TopupScreen())),
            ),
          ),

          // ── ÜCRETSİZ İLETİŞİM HAKKI ──
          //
          // ⚠ PARA DEĞİLDİR: cüzdan bakiyesi, jeton veya promosyon
          // bakiyesi değildir. Bakiye kartından AYRI gösterilir.
          //
          // ⚠ HERKESE GÖSTERİLMEZ: kart yalnız ADMİNİN hak tanıdığı ve
          // hakkı HENÜZ BİTMEMİŞ hizmet verende görünür. Dolgu kartın
          // İÇİNDEDİR; kart gizlendiğinde boş bir aralık kalmasın.
          const _FreeRightCard(),

          // ── BAŞLIK + `Filtrele` DÜĞMESİ ──
          //
          // ⚠ "Tümünü Gör / Daha Az Gör" BAĞLANTISI KALDIRILDI.
          //
          // Tek bağlantı iki iş yapıyordu: listeyi açmak ve altında
          // yatay kaydırmalı hap çubuğunu getirmek. Haplar ekrana
          // sığmıyor, sonuncusu kenardan taşıyordu.
          //
          // Yerine uygulamanın geri kalanıyla AYNI desen kondu:
          // `RefPillButton` + `RefBottomSheet` (bkz. Sırala/Filtreler,
          // `jobs_screen` · `my_listings_screen`).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Text('Son İşlemler',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: HC.dark)),
                const Spacer(),
                RefPillButton(
                  iconAsset: 'assets/svg/ic_filter.svg',
                  label: 'Filtrele',
                  onTap: _filtrePaneli,
                ),
              ],
            ),
          ),

          // ── UYGULANMIŞ FİLTRE ŞERİDİ ──
          //
          // ⚠ Filtre yarım ekranda seçildiği için, kapandıktan sonra
          // kullanıcı NEYE göre süzüldüğünü göremezdi. Şerit hem
          // seçimi yazar hem tek dokunuşla temizler.
          if (_filtreli)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: RefListCount('$filtreEtiketi · ${txs.length} işlem'),
                  ),
                  const SizedBox(width: 10),
                  RefTap(
                    onTap: () => setState(() {
                      _filtreli = false;
                      _filter = null;
                    }),
                    borderRadius: BorderRadius.circular(RR.r8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const RefSvg('assets/svg/ic_close.svg',
                              size: 13, color: RC.blue),
                          const SizedBox(width: 4),
                          Text('Temizle',
                              style: refText(
                                  size: RF.s13,
                                  weight: RF.w700,
                                  color: RC.blue)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: txs.isEmpty
                ? Center(
                    // ⚠ "Bu filtrede işlem yok." metni filtre YOKKEN
                    // yanlıştı: kullanıcı hiç filtre uygulamadığı hâlde
                    // bir filtreden söz ediliyordu.
                    child: SysEmpty(
                        title: 'Cüzdan Hareketleri',
                        desc: _filtreli
                            ? 'Bu filtrede işlem yok.'
                            : 'Henüz cüzdan hareketiniz yok.'))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = txs[i];
                      // ⚠ `_txUi` ARTIK LİSTEDE KULLANILMIYOR; yalnız
                      // FİLTRE PANELİNİN rozetleri için duruyor.
                      return Container(
                        // `.wx-card{padding:11px 12px; r13; 1px #ECEEF1}`
                        padding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 12),
                        decoration: BoxDecoration(
                            color: RC.white,
                            border: Border.all(color: RC.border),
                            borderRadius: BorderRadius.circular(RR.r13)),
                        child: Row(children: [
                          // ⚠ İKON KALDIRILDI.
                          //
                          // Türe göre daire içinde bir ikon çiziliyordu;
                          // yükleme satırında bu "indirme oku"ydu ve
                          // kullanıcıya dosya indirileceğini
                          // düşündürüyordu. Bu ekranda İNDİRİLECEK
                          // BİR ŞEY YOK.
                          //
                          // İşlemin türü zaten başlıkta ve tutarın
                          // renginde/işaretinde okunuyor; ikon bilgi
                          // eklemiyordu.
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: HC.dark)),
                                  Text(t.sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5, color: HC.grey)),
                                  // ── TARİH VE SAAT ──
                                  //
                                  // ⚠ Para hareketinin NE ZAMAN olduğu
                                  // görünmeden cüzdan denetlenemez.
                                  // Biçim tek yerde: `WalletTx.zamanMetni`.
                                  //
                                  // Punto kasıtlı olarak açıklamadan da
                                  // küçük (11) ve rengi soluk: satırın
                                  // ana bilgisi başlık ve tutardır,
                                  // tarih onları bastırmamalı.
                                  const SizedBox(height: 2),
                                  Text(t.zamanMetni,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11, color: HC.grey)),
                                ]),
                          ),
                          Text('${t.amount > 0 ? '+' : ''}${t.amount} TL',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: t.amount > 0 ? HC.green : HC.dark)),
                        ]),
                      );
                    },
                  ),
                  ),
          ),
        ]),
      ),
    );
  }


  /// FİLTRE YARIM EKRANI — `Filtrele` düğmesinin formu.
  ///
  /// ⚠ ESKİ `_chip` (`.wx-pill`) YARDIMCISI KALDIRILDI: yatay
  /// kaydırmalı hap çubuğu artık çizilmiyor.
  ///
  /// Düzen uygulamanın diğer filtre panelleriyle AYNIDIR
  /// (`RefSecimKarti`: ikon rozeti + başlık + açıklama + seçim
  /// dairesi). Seçenekler ALT ALTA olduğu için hiçbiri ekran
  /// kenarından taşmaz ve beşi de tek bakışta görünür.
  ///
  /// ⚠ Sıra referanstaki gibidir: Tümü · Yüklemeler · Blokeler ·
  /// İadeler · İletişim Açma. `TxKind.values` sırası enum tanımına
  /// bağlıdır ve bu sırayla uyuşmaz — bu yüzden liste ELLE yazılır.
  ///
  /// ⚠ Seçim ANINDA uygulanır; ayrı "Uygula" düğmesi yoktur —
  /// Sırala/Filtreler panelleriyle aynı davranış.
  Future<void> _filtrePaneli() async {
    // Panel `TxKind?` döndüremez (null "kapatıldı" demektir), bu
    // yüzden sonuç dizin olarak taşınır: 0 = Tümü, 1.. = tür.
    const turler = [
      TxKind.load,
      TxKind.block,
      TxKind.refund,
      TxKind.contact,
    ];
    final secim = await RefBottomSheet.goster<int>(
      context,
      title: 'Filtrele',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RefSecimKarti(
            ikon: 'assets/svg/ic_grid.svg',
            baslik: 'Tümü',
            aciklama: 'Bütün cüzdan hareketleri',
            secili: _filtreli && _filter == null,
            onTap: () => Navigator.of(context).pop(0),
          ),
          const SizedBox(height: 6),
          for (final k in turler) ...[
            RefSecimKarti(
              ikon: _txUi(k).$1,
              baslik: _txLabel(k),
              aciklama: _txDesc(k),
              secili: _filtreli && _filter == k,
              onTap: () => Navigator.of(context).pop(turler.indexOf(k) + 1),
            ),
            if (k != turler.last) const SizedBox(height: 6),
          ],
          const SizedBox(height: 2),
        ],
      ),
    );
    if (secim == null || !mounted) {
      return;
    }
    setState(() {
      _filtreli = true;
      _filter = secim == 0 ? null : turler[secim - 1];
    });
  }
}


/// ÜCRETSİZ İLETİŞİM HAKKI KARTI (Cüzdanım ekranı)
///
/// ⚠ Bu kart PARA GÖSTERMEZ. Hak; cüzdan bakiyesi, para veya jeton
/// DEĞİLDİR; nakde çevrilemez, devredilemez. Birim "adet"tir.
///
/// Yalnız Hizmet Veren görünümünde açılır — Cüzdanım ekranı zaten
/// `RoleGuard.provider` ile korunmaktadır.
///
/// ── ⚠ GÖRÜNÜRLÜK KURALI ──
///
/// Kart HER HİZMET VERENDE ÇIKMAZ. Yalnız ADMİNİN hak tanıdığı ve
/// hakkı HENÜZ TÜKENMEMİŞ hesapta çizilir:
///
///   · özet okunamadı (null)      → GİZLİ
///   · kalan hak 0 / kullanılamaz → GİZLİ (hak bitince kendiliğinden
///                                  kalkar, ayrı bir işlem gerekmez)
///   · kalan hak > 0              → GÖRÜNÜR
///
/// Yükleme sürerken de GİZLİDİR: kart önce açılıp sonra kaybolursa
/// hakkı olmayan kullanıcı bir an için hak sahibi sanır.
///
/// ⚠ "Kullanılabilir ücretsiz hakkınız bulunmuyor." METNİ KALDIRILDI —
/// hakkı olmayan kullanıcı kartı hiç görmediği için ulaşılamazdı.
class _FreeRightCard extends StatefulWidget {
  const _FreeRightCard();
  @override
  State<_FreeRightCard> createState() => _FreeRightCardState();
}

class _FreeRightCardState extends State<_FreeRightCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FreeRightController>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctl = context.watch<FreeRightController>();
    final ozet = ctl.summary;
    final kalan = ozet?.remainingRights ?? 0;

    // ── ⚠ GÖRÜNÜRLÜK KAPISI ──
    //
    // Kart HER HİZMET VERENDE ÇIKMAZ. Admin hak tanımadıysa, özet
    // okunamadıysa veya kalan hak TÜKENDİYSE hiç çizilmez — hak
    // bitince bölüm KENDİLİĞİNDEN kalkar, ayrı bir işlem gerekmez.
    //
    // Yükleme sürerken de gizlidir: kart bir an açılıp sonra
    // kaybolursa hakkı olmayan kullanıcı hak sahibi olduğunu sanır.
    if (ctl.loading || ozet == null || kalan <= 0 || !ozet.hasUsableRight) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      // ⚠ KENAR BOŞLUĞU KARTIN İÇİNDEDİR (dış `Padding` yerine
      // `margin`): kart gizlendiğinde boş bir aralık kalmaz.
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HC.border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // ⚠ Hediye ikonu BEYAZ şekillerden oluşur; referansta MAVİ
          // zemin üzerinde gösterilir (`.po-gift{background:#1D6BE3}`).
          // Açık zeminde maviye boyanırsa görünmez olur.
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: RC.blue, borderRadius: BorderRadius.circular(10)),
            child: const RefSvg('assets/svg/ic_gift.svg',
                size: 19, color: RC.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Ücretsiz İletişim Hakkım',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: HC.dark)),
          ),
          // ⚠ Yükleme çarkı ve "hakkınız bulunmuyor" dalı KALDIRILDI:
          // kart bu noktada yalnız hakkı OLAN kullanıcıda çizilir.
          Text(kalan.toString(),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: HC.blue)),
        ]),
        const SizedBox(height: 8),
        Text('Kalan hakkınız: $kalan',
            style: const TextStyle(fontSize: 12.5, color: HC.grey)),
        if (ozet.nextExpiryAt != null) ...[
          const SizedBox(height: 2),
          Text(
              'Geçerlilik: '
              '${ozet.nextExpiryAt!.day.toString().padLeft(2, '0')}.'
              '${ozet.nextExpiryAt!.month.toString().padLeft(2, '0')}.'
              '${ozet.nextExpiryAt!.year} tarihine kadar',
              style: const TextStyle(fontSize: 12, color: HC.grey)),
        ],
        const SizedBox(height: 8),
        const InfoBox(
          child: Text(
              'Bu hak para, bakiye veya jeton değildir. '
              'Cüzdan bakiyenizi etkilemez, nakde çevrilemez ve '
              'başka bir kullanıcıya devredilemez.'),
        ),
      ]),
    );
  }
}

/// `.wl-card` — tek bakiye kartı.
///
/// ```css
/// .wl-card{border-radius:15px;padding:14px 13px}
/// .wl-ic{42x42;%50;margin-bottom:12px}
/// .wl-l{13.5px/700;#16233D}
/// .wl-v{24px/800;margin-top:6px;letter-spacing:-.4px}
/// .wl-v small{13px/700}
/// .wl-d{11px;#5B6472;1.4;margin-top:7px}
/// ```
class _BakiyeKarti extends StatelessWidget {
  const _BakiyeKarti({
    required this.ikon,
    required this.ikonBoyut,
    required this.ikonZemin,
    required this.zemin,
    required this.cerceve,
    required this.etiket,
    required this.tutar,
    required this.tutarRengi,
    this.aciklama,
  });

  final String ikon;
  final double ikonBoyut;
  final Color ikonZemin;
  final Color zemin;
  final Color cerceve;
  final String etiket;
  final int tutar;
  final Color tutarRengi;
  final String? aciklama;

  /// `WALLET.avail.toFixed(2).replace('.', ',')` — iki basamak, virgüllü.
  String get _tutarMetni =>
      tutar.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 13),
        decoration: BoxDecoration(
          color: zemin,
          border: Border.all(color: cerceve),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ikonZemin, shape: BoxShape.circle),
              child: RefSvg(ikon, size: ikonBoyut),
            ),
            const SizedBox(height: 12),
            Text(etiket,
                style: refText(
                    size: RF.s135, weight: RF.w700, color: RC.text)),
            const SizedBox(height: 6),
            // ⚠ `TL` KÜÇÜK PUNTODUR (`.wl-v small`).
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: _tutarMetni,
                  style: refText(
                      size: 24,
                      weight: RF.w800,
                      color: tutarRengi,
                      letterSpacing: -0.4),
                ),
                TextSpan(
                  text: ' TL',
                  style: refText(
                      size: 13, weight: RF.w700, color: tutarRengi),
                ),
              ]),
            ),
            if (aciklama != null) ...[
              const SizedBox(height: 7),
              Text(aciklama!,
                  style: refText(
                      size: 11,
                      weight: RF.w400,
                      color: RC.textSoft,
                      height: RF.lh140)),
            ],
          ],
        ),
      );
}
