import 'dart:io';
import 'widgets/ilan_no_etiketi.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/models/account.dart';
import '../data/services/search_service.dart';
import '../data/models/listing.dart';
import '../data/models/offer.dart';
import 'offer_detail_screen.dart';
import 'review_screen.dart';
import 'category_ui.dart';
import 'status_ui.dart';
import 'widgets/foto_goruntuleyici.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';

/// Müşteri — İlan Detayı (HTML vListing): ilan bilgisi, durum,
/// Gelen Teklifler listesi ve duruma göre aksiyonlar
/// (iptal/sil, işi başlat, tamamlandı, değerlendir).
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// İlan detayı ve teklifleri yeniden yüklenir (açılış + işlem sonrası).
  Future<void> _refresh() async {
    await context.read<ListingController>().loadOne(widget.listingId);
    if (!mounted) {
      return;
    }
    await context.read<OfferController>().loadForListing(widget.listingId);
  }

  Future<void> _run(BuildContext context, Future<String?> Function() op) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final err = await op();
    // State.mounted → setState güvenliği
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    // Parametre olarak gelen LOCAL context ayrıca doğrulanır.
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err);
    }
  }

  /// `DEL_REASONS` — silme gerekçeleri.
  ///
  /// ⚠ "Hizmeti aldım, ilan tamamlandı" ÇIKARILDI.
  ///
  /// Tamamlanan iş SİLİNMEZ: değerlendirme ve fatura o ilana bağlıdır,
  /// silinirse geçmiş kaybolur. Tamamlama ayrı bir akıştır; silme
  /// gerekçesi olarak sunulması kullanıcıyı yanlış yola sokuyordu.
  static const _kSilmeNedenleri = [
    'İhtiyacım kalmadı / vazgeçtim',
    'Dışarıdan biri ile anlaştım',
    'Yanlış ilan oluşturdum',
    'Gelen teklifler uygun değildi',
    'Diğer',
  ];

  /// SİLME ONAYI — yalnız soru ve iki düğme.
  ///
  /// ⚠ `hcConfirm` KULLANILMAZ: o yardımcı açıklama metnini ZORUNLU
  /// alır ve `hc_widgets.dart` dokunulmaz dosyadır. Bu ekrana özel
  /// sade pencere burada kurulur.
  Future<bool> _silOnayi(BuildContext context, {required bool acik}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          acik ? 'İlan silinsin mi?' : 'İlan iptal edilsin mi?',
          style: refText(size: RF.s17, weight: RF.w700, color: RC.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              acik ? 'Sil' : 'İptal Et',
              style: refText(
                  size: RF.s145, weight: RF.w700, color: RC.danger),
            ),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  /// `listingMenu()` — üç nokta menüsü.
  Future<void> _ilanMenusu(
      BuildContext context, Listing l, String actorId) async {
    final sil = await RefBottomSheet.goster<bool>(
      context,
      title: 'İlan Seçenekleri',
      child: RefTap(
        onTap: () => Navigator.of(context).pop(true),
        borderRadius: BorderRadius.circular(RR.r12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(children: [
            const RefSvg('assets/svg/ic_trash.svg',
                size: 18, color: RC.danger),
            const SizedBox(width: 10),
            Text(
                l.status == ListingStatus.open
                    ? 'İlanı Sil'
                    : 'İlanı İptal Et',
                style:
                    refText(size: RF.s145, weight: RF.w600, color: RC.danger)),
          ]),
        ),
      ),
    );
    // ⚠ `context.mounted` — State'in `mounted`'ı DEĞİL.
    //
    // Bu metot `BuildContext`'i PARAMETRE olarak alır; State'in
    // yaşamı ile o context'in yaşamı AYNI ŞEY DEĞİLDİR. Aşağıda
    // yine `context` kullanıldığı için doğru denetim budur.
    if (sil != true || !context.mounted) {
      return;
    }
    await _nedenSor(context, l, actorId);
  }

  /// `askDelReason()` — silme nedeni ZORUNLUDUR.
  ///
  /// ⚠ Neden yalnız kullanıcıya sorulmakla kalmaz: seçilen gerekçe
  /// silme işlemiyle birlikte YÖNETİME iletilir (denetim kaydı).
  Future<void> _nedenSor(
      BuildContext context, Listing l, String actorId) async {
    final neden = await RefBottomSheet.goster<String>(
      context,
      title: 'İlanı neden siliyorsunuz?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _kSilmeNedenleri)
            RefTap(
              onTap: () => Navigator.of(context).pop(r),
              borderRadius: BorderRadius.circular(RR.r12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(r,
                        style: refText(
                            size: RF.s145,
                            weight: RF.w500,
                            color: RC.text)),
                  ),
                  const RefSvg('assets/svg/ic_chev.svg',
                      size: 18, color: Color(0xFFD3D8E0)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (neden == null || !context.mounted) {
      return;
    }

    // ── "DİĞER" SEÇİLDİYSE AÇIKLAMA ZORUNLUDUR ──
    //
    // ⚠ Tek başına "Diğer" yönetime hiçbir bilgi taşımaz. Kullanıcıdan
    // kısa bir açıklama alınır ve gerekçenin İÇİNDE gönderilir:
    //   `Diğer: taşındığım için ihtiyacım kalmadı`
    //
    // Böylece yönetim hem hazır gerekçeleri hem serbest metni AYNI
    // alanda görür; ayrı bir alan/uç gerekmez.
    //
    // Vazgeçilirse silme YAPILMAZ — yarım kalan işlem bırakılmaz.
    var gerekce = neden;
    if (neden == 'Diğer') {
      final metin = await RefBottomSheet.goster<String>(
        context,
        title: 'Silme nedeniniz',
        child: const RefSerbestNedenSayfasi(
          baslik: 'Silme nedeniniz',
          aciklama: 'İlanı neden sildiğinizi kısaca yazın. Bu açıklama '
              'HizmetCep yönetimine iletilir ve hizmet kalitesini '
              'iyileştirmek için kullanılır.',
          ipucu: 'Örn. Taşındığım için ihtiyacım kalmadı',
        ),
      );
      if (metin == null || metin.trim().isEmpty || !context.mounted) {
        return;
      }
      gerekce = 'Diğer: ${metin.trim()}';
    }

    final acik = l.status == ListingStatus.open;
    // ⚠ ONAY PENCERESİ SADE: yalnız SORU + iki düğme.
    //
    // Eskiden gerekçe tekrar yazılıyor, ardından iki cümlelik bir
    // açıklama geliyordu. Gerekçeyi kullanıcı bir önceki adımda ZATEN
    // seçti; bloke iadesi de sistemin kendi işidir. Karar anında
    // okunacak tek şey sorudur.
    final ok = await _silOnayi(context, acik: acik);
    if (!ok || !context.mounted) {
      return;
    }
    await _run(context, () async {
      final ctl = context.read<ListingController>();
      final err = acik
          ? await ctl.delete(l.id, actorId: actorId, reason: gerekce)
          : await ctl.cancel(l.id, actorId: actorId, reason: gerekce);

      // ⚠ `context.mounted` — `mounted` TEK BAŞINA YETMEZ.
      //
      // `delete`/`cancel` bir async gap'tir. Sonrasında kullanılan
      // nesne `sysToastOk(context, ...)` ve `geriGit(context)` ile
      // PARAMETRE olarak taşınan `context`'tir; `mounted` ise bu
      // State'in yaşamını gösterir. İkisi AYNI ŞEY DEĞİLDİR:
      // State canlı kalsa bile o alt ağaç kalkmış olabilir ve
      // `geriGit` deaktive edilmiş bir Navigator'a dokunur.
      //
      // ⚠ HATA DAVRANIŞI DEĞİŞMEDİ: `err` yine `_run`'a döndürülür
      // ve hata mesajı orada gösterilir. Burada yalnız BAŞARI
      // gösterimi korunur.
      if (err == null && mounted && context.mounted) {
        // Toast'ta yalnız KISA gerekçe gösterilir; serbest metin
        // ekranda tekrarlanmaz (kullanıcı zaten kendisi yazdı).
        sysToastOk(context, 'İlanınız silindi ($neden)');
        geriGit(context);
      }
      return err?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⚠ OTURUM DÜŞERSE ÇÖKME YOK.
    //
    // Bu ekran `RoleGuard` ile SARILMAZ; `MaterialPageRoute` ile
    // doğrudan açılır. Oturum ekran açıkken düşerse (401 → logout)
    // `AuthController` bildirim yayar, `build` yeniden koşar ve
    // `currentAccount!` null denetimini patlatıp kırmızı ekran
    // üretiyordu. Artık kontrollü oturum durumu gösterilir.
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    if (me == null) {
      return const Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(child: Center(child: SysState(SysKind.sessionExpired))),
      );
    }
    final listingCtl = context.watch<ListingController>();
    final offerCtl = context.watch<OfferController>();
    final l = listingCtl.byId(widget.listingId);
    if (l == null) {
      return Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: SysEmpty(
                      title: 'İlan bulunamadı',
                      desc: 'Bu ilan silinmiş olabilir.'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final offers = offerCtl.offersForListing(l.id);

    // ── GÖRÜNÜM: referans `vListing()` ──
    //   .ld-topbar  geri + .ld-more (üç nokta)
    //   .ld-card    1px #ECEEF1; r11; padding 8px 11px; gölge soft
    //   .of-card    teklif kartı — r11; padding 7px 10px
    // ⚠ Referansta AppBar YOKTUR.
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: RefScroll(
          // `.ld-wrap{padding:calc(6px + safe-area) 12px 84px}`
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 84),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // .ld-topbar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ⚠ GERİ OKU GERİ GELDİ — HER PLATFORMDA.
                //
                // Bir tur kaldırılmıştı ("cihazın kendi geri tuşu
                // kullanılır"). iOS'ta donanım geri tuşu yok ve kenar
                // jesti de kapalı olduğu için o ekranlarda geri dönüş
                // yolu kalmıyordu. Platforma göre değiştirmek ise
                // karışıklık ürettiği için nihai karar: ok HER YERDE.
                const RefBackButton(),
                // ⚠ SİLME BURADA — alttaki tehlike düğmesi KALDIRILDI.
                // Referans `listingMenu()`: üç nokta → "İlanı Sil" →
                // neden seçimi (`askDelReason`) → silme.
                RefTap(
                  onTap: (l.status == ListingStatus.open ||
                          l.status == ListingStatus.providerSelected ||
                          l.status == ListingStatus.inProgress)
                      ? () => _ilanMenusu(context, l, me.id)
                      : null,
                  borderRadius: BorderRadius.circular(RR.circle),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: RefSvg('assets/svg/ic_dots.svg',
                        size: 22, color: RC.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── .ld-card ──
            // background:#fff; border:1px #ECEEF1; border-radius:11px;
            // padding:8px 11px; box-shadow:0 1px 5px rgba(20,40,80,.04)
            Container(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: RC.border), // #ECEEF1
                borderRadius: BorderRadius.circular(RR.r11),
                boxShadow: RS.soft6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // .ld-top{display:flex;gap:10px;align-items:flex-start}
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .ld-ic{40x40;%50;#EAF1FB} + .ld-ic svg{22px}
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: RC.blueSoft, // #EAF1FB
                          shape: BoxShape.circle,
                        ),
                        child: RefSvg(_ldIkon(l.title),
                            size: 22, color: RC.blue),
                      ),
                      const SizedBox(width: 10), // gap:10px
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // .ld-title{15.5px/700;-.2px;margin-top:1px}
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                l.title,
                                style: refText(
                                  size: 15.5,
                                  weight: RF.w700,
                                  color: RC.text,
                                  letterSpacing: RF.lsM02,
                                ),
                              ),
                            ),
                            // ⚠ İLAN NUMARASI — kolay bulunabilecek
                            // sabit yer: başlığın hemen altı, konum
                            // satırının üstü. İkincil ölçüde.
                            const SizedBox(height: 3),
                            IlanNoEtiketi(l),
                            // .ld-meta{gap:5px;#98A2B3;11.5px;margin-top:4px}
                            // .ld-meta svg{13px}
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const RefSvg('assets/svg/ic_pin.svg',
                                    size: 13, color: RC.greyLight),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    l.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: refText(
                                        size: RF.s115,
                                        weight: RF.w400,
                                        color: RC.greyLight),
                                  ),
                                ),
                                _ayrac(),
                                const RefSvg('assets/svg/ic_clock.svg',
                                    size: 13, color: RC.greyLight),
                                const SizedBox(width: 5),
                                Text(
                                  _goreliZaman(l.createdAt),
                                  style: refText(
                                      size: RF.s115,
                                      weight: RF.w400,
                                      color: RC.greyLight),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── İLAN AÇIKLAMASI ──
                  //
                  // ⚠ HTML SÖZLEŞMESİNDEN BİLİNÇLİ SAPMA (ürün kararı).
                  // Referans `.ld-desc{11.5px;#5B6472;line-height:1.45}`
                  // idi; 11,5px + Poppins Regular + gri üst üste
                  // gelince metin cihazda siliniyordu. Açıklama ilanın
                  // ASIL içeriğidir, ikincil bilgi değildir.
                  //
                  // ⚠ TEK STANDART: detay ekranları 13,5/w500/RC.text,
                  // kart ekranları 12,5/w500/RC.textSoft. Aynı içerik
                  // dört ekranda üç farklı ölçüdeydi.
                  //
                  // ⚠ AĞIRLIK w500'DÜR, w600 DEĞİL: pubspec'te yalnız
                  // Poppins 400/500/700 var. w600 istenirse Flutter
                  // gerçek dosya bulamayıp sentezler ve bulanık basar.
                  // Kilit: test/ilan_aciklama_tipografisi_test.dart
                  const SizedBox(height: 7),
                  Text(
                    l.desc,
                    style: refText(
                      size: RF.s135,
                      weight: RF.w500,
                      color: RC.text,
                      height: RF.lh155,
                    ),
                  ),

                  // ── FOTOĞRAFLAR ──
                  // Referans: `${(x.photos&&x.photos.length)?...}` —
                  // bölüm YALNIZ fotoğraf varsa çizilir.
                  // .ld-h2 style="margin:12px 0 7px" + .pl-fotos
                  if (l.photoPaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Fotoğraflar (${l.photoPaths.length})',
                        style: refText(
                            size: 14.5,
                            weight: RF.w700,
                            color: RC.text,
                            letterSpacing: RF.lsM02)),
                    const SizedBox(height: 7),
                    _Fotograflar(yollar: l.photoPaths),
                  ],

                  // stChip(x.st)
                  const SizedBox(height: 6),
                  _DurumChipi(status: l.status),
                ],
              ),
            ),
            // .ld-h2{margin:9px 2px 6px}
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text('Gelen Teklifler (${offers.length})',
                  style: refText(
                      size: 14.5,
                      weight: RF.w700,
                      color: RC.text,
                      letterSpacing: RF.lsM02)),
            ),
            const SizedBox(height: 6),
            // ── .ld-list{gap:7px} ──
            if (offers.isEmpty)
              // Referans: teklif yoksa `.cust-empty` metni; süresi
              // dolan ilanda AYRI metin gösterilir.
              _BosTeklif(suresiDoldu: l.status == ListingStatus.expired)
            else
              for (var i = 0; i < offers.length; i++) ...[
                _TeklifKarti(
                  offer: offers[i],
                  saglayici: auth.accountById(offers[i].providerId),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => OfferDetailScreen(offerId: offers[i].id),
                    ),
                  ),
                ),
                if (i != offers.length - 1) const SizedBox(height: 7),
              ],
            const SizedBox(height: 8),

            // ── Duruma göre aksiyonlar ──
            //
            // ⚠ AYRI "İŞİ BAŞLAT" ADIMI KALDIRILDI.
            //
            // Teklif seçildikten sonra iş fiilen başlamıştır; ayrıca
            // "başlat" demek fazladan bir adımdı ve unutulduğunda ilan
            // tamamlanamaz duruma düşüyordu. Artık seçim sonrası tek
            // aksiyon vardır: İŞİ TAMAMLA.
            //
            // ⚠ `inProgress` durumu HÂLÂ DESTEKLENİR: eski kayıtlar ve
            // backend bu durumu gönderebilir; o hâlde de aynı düğme
            // görünür.
            if (l.status == ListingStatus.providerSelected ||
                l.status == ListingStatus.inProgress)
              SysButton('İşi Tamamla',
                  busy: _busy,
                  onPressed: () => _run(context, () async {
                        final err =
                            await listingCtl.completeWork(l.id, actorId: me.id);
                        if (err != null) {
                          return err.message;
                        }
                        // ⚠ `context.mounted` — kapatma sırasında
                        // State canlı ama bu alt ağaç kalkmış olabilir.
                        if (!context.mounted) {
                          return null;
                        }
                        sysToastOk(context, 'İşiniz tamamlandı');

                        // ⚠ DEĞERLENDİRME EKRANI OTOMATİK AÇILIR.
                        //
                        // Kullanıcıyı "şimdi nereye?" sorusuyla baş başa
                        // bırakmamak için tamamlama sonrası doğrudan
                        // değerlendirmeye geçilir.
                        //
                        // ⚠ SEÇİLİ TEKLİF YOKSA SESSİZ GEÇİLMEZ.
                        //
                        // Önceki hâl `if (secili != null)` ile atlıyordu:
                        // kullanıcı "İşiniz tamamlandı" görüyor, ama
                        // değerlendirme ekranı hiç açılmıyordu. Ne
                        // olduğunu anlamanın yolu yoktu.
                        //
                        // Bu durum zaten OLUŞMAMALIDIR — domain katmanı
                        // `selectedOfferId` boşken `completed` geçişini
                        // reddeder (bkz. `_transition`). Buraya
                        // düşülüyorsa veri tutarsızdır ve kullanıcıya
                        // AÇIKÇA söylenir.
                        final secili = l.selectedOfferId;
                        if (secili == null || secili.isEmpty) {
                          return 'Bu ilanda seçilmiş teklif bulunamadı — '
                              'değerlendirme açılamadı. Lütfen destek '
                              'ekibiyle iletişime geçin.';
                        }
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ReviewScreen(
                                listingId: l.id, offerId: secili),
                          ),
                        );
                        return null;
                      })),
            if (l.status == ListingStatus.completed && l.selectedOfferId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SysButton('Hizmeti Değerlendir',
                    busy: false,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReviewScreen(
                                listingId: l.id,
                                offerId: l.selectedOfferId!)))),
              ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REFERANS BİLEŞENLERİ — `vListing()`
// ═══════════════════════════════════════════════════════════════

/// `.of-sep{color:#D3D8E0;margin:0 3px}` + kapsayıcı `gap`
Widget _ayrac() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('|',
          style: refText(
              size: RF.s115,
              weight: RF.w400,
              color: const Color(0xFFD3D8E0))),
    );

/// Referans `x.time` — göreli zaman.
String _goreliZaman(DateTime t) {
  final f = DateTime.now().difference(t);
  if (f.inMinutes < 60) {
    return '${f.inMinutes} dk önce';
  }
  if (f.inHours < 24) {
    return '${f.inHours} saat önce';
  }
  return '${f.inDays} gün önce';
}

/// Referans `ldIcon(title)` — başlıktan kategori ikonu bulur.
///
/// HTML önce hizmet kataloğunda tam/kısmi ad arar, bulamazsa anahtar
/// kelime tablosuna düşer, o da tutmazsa genel alet ikonunu döner.
String _ldIkon(String baslik) {
  final hits = SearchService.services(baslik);
  if (hits.isNotEmpty) {
    return categoryIcon(hits.first.category);
  }
  const kelimeler = {
    'elektrik': 'Elektrik',
    'kombi': 'Doğalgaz',
    'doğalgaz': 'Doğalgaz',
    'petek': 'Doğalgaz',
    'musluk': 'Tesisat',
    'tesisat': 'Tesisat',
    'temizl': 'Temizlik',
    'boya': 'Boya',
    'badana': 'Boya',
    'fayans': 'Fayans ve Seramik',
    'bahçe': 'Bahçe ve Peyzaj',
    'duvar': 'Duvar Kağıdı ve Dekorasyon',
  };
  final t = baslik.toLowerCase();
  for (final e in kelimeler.entries) {
    if (t.contains(e.key)) {
      return categoryIcon(e.value);
    }
  }
  // HTML: `IC_TOOLB(24)`
  return 'assets/svg/ic_toolb.svg';
}

/// `stChip(st)` — ilan durumu rozeti.
///
/// ```css
/// .ld-chip{gap:5px;margin-top:6px;padding:3px 9px;r7;10.5px/600}
/// .ld-chip .ld-dot{8x8;%50}
/// .ld-chip.open{#E9F9EF / #16A34A}  .ld-dot{#22C55E}
/// .ld-chip.done{#EAF1FB / #1D6BE3}  .ld-dot{#1D6BE3}
/// .ld-chip.exp {#F2F4F7 / #6B7683}  .ld-dot{#98A2B3}
/// ```
class _DurumChipi extends StatelessWidget {
  const _DurumChipi({required this.status});

  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, nokta, metin) = switch (status) {
      ListingStatus.completed => (
          const Color(0xFFEAF1FB),
          const Color(0xFF1D6BE3),
          const Color(0xFF1D6BE3),
          'Tamamlandı',
        ),
      ListingStatus.expired || ListingStatus.cancelled => (
          const Color(0xFFF2F4F7),
          const Color(0xFF6B7683),
          const Color(0xFF98A2B3),
          'Süresi Doldu',
        ),
      _ => (
          const Color(0xFFE9F9EF),
          const Color(0xFF16A34A),
          const Color(0xFF22C55E),
          'Açık İlan',
        ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(RR.r7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: nokta, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5), // gap:5px
            Text(metin,
                style: refText(size: 10.5, weight: RF.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// `.pl-fotos{grid;repeat(4,1fr);gap:8px}` + `.plf{r10;4/3;1px #EEF0F3}`
class _Fotograflar extends StatelessWidget {
  const _Fotograflar({required this.yollar});

  final List<String> yollar;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 4 / 3, // .plf{aspect-ratio:4/3}
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (final (i, y) in yollar.indexed)
            // ⚠ FOTOĞRAFA DOKUNULUNCA TAM EKRAN AÇILIR.
            // Aynı görüntüleyici hizmet veren tarafında da kullanılır.
            RefTap(
              onTap: () => FotoGoruntuleyici.ac(context,
                  yollar: yollar, baslangic: i),
              borderRadius: BorderRadius.circular(RR.r10),
              child: ClipRRect(
              borderRadius: BorderRadius.circular(RR.r10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFEEF0F3)),
                  borderRadius: BorderRadius.circular(RR.r10),
                ),
                // ⚠ Yalnız CİHAZ yolu; sunucu referansı ayrı çözülür.
                child: Image.file(
                  File(y),
                  fit: BoxFit.cover, // .plf img{object-fit:cover}
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFF1F4F9),
                    child: Center(
                      child: RefSvg('assets/svg/ic_camg.svg', size: 18),
                    ),
                  ),
                ),
              ),
              ),
            ),
        ],
      );
}

/// Teklif yoksa gösterilen metin — `.cust-empty`.
class _BosTeklif extends StatelessWidget {
  const _BosTeklif({required this.suresiDoldu});

  final bool suresiDoldu;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          suresiDoldu
              ? 'Süresi dolan ilanlarda teklifler görüntülenmez.'
              : 'Bu ilana henüz teklif verilmedi.',
          textAlign: TextAlign.center,
          style:
              refText(size: RF.s14, weight: RF.w400, color: RC.greyLight),
        ),
      );
}

/// `.of-card` — tek teklif kartı.
///
/// ```css
/// .of-card{#fff;1px #ECEEF1;r11;padding:7px 10px;
///          box-shadow:0 1px 5px rgba(20,40,80,.04)}
/// .of-head{gap:9px;align-items:flex-start}
/// .of-av{%50;overflow:hidden}                    /* 36px */
/// .of-name{13.5px/700;#16233D;letter-spacing:.2px}
/// .of-sub{gap:4px;11px;#5B6472}  .of-sub b{#1D6BE3;11.5px}
/// .of-right{text-align:right}
/// .of-price{14.5px/800;-.2px}   .of-pl{10px/600;#1D6BE3;margin-top:2px}
/// .of-quote{#F5F7FA;r8;padding:6px 9px;margin-top:5px;11px/1.4;#3A4658}
/// .of-meta{gap:4px;margin-top:5px;10px;#5B6472}  .of-meta svg{13px}
/// .of-unl{#E9F9EF;#16A34A;9.5px/700;r6;padding:2px 6px}
/// ```
class _TeklifKarti extends StatelessWidget {
  const _TeklifKarti({
    required this.offer,
    required this.saglayici,
    required this.onTap,
  });

  final Offer offer;
  final Account? saglayici;
  final VoidCallback onTap;

  /// Referansta iletişim açılınca AD SOYAD, açılmadan MASKELİ ad görünür.
  String _ad() {
    final tam = saglayici?.name.trim() ?? '';
    if (tam.isEmpty) {
      return 'Hizmet Veren';
    }
    if (offer.escrowConsumed) {
      return tam;
    }
    // `E*** K*****` — her kelimenin ilk harfi kalır.
    return tam
        .split(RegExp(r'\s+'))
        .map((k) => k.isEmpty ? k : '${k[0]}${'*' * (k.length - 1)}')
        .join(' ');
  }

  /// Açık avatarda baş harfler (`avInitials`).
  String _basHarfler() {
    final tam = saglayici?.name.trim() ?? '';
    if (tam.isEmpty) {
      return '?';
    }
    return tam
        .split(RegExp(r'\s+'))
        .where((k) => k.isNotEmpty)
        .map((k) => k[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = context.watch<ReviewController>();
    final acik = offer.escrowConsumed;
    final liste = reviews.byProvider(offer.providerId);
    final ortalama = reviews.averageOf(offer.providerId);
    // `%98 olumlu yorum` — 4 ve 5 yıldızlı yorumların oranı.
    final olumlu = liste.isEmpty
        ? null
        : (liste.where((r) => r.stars >= 4).length * 100 / liste.length)
            .round();

    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r11),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: RC.border),
          borderRadius: BorderRadius.circular(RR.r11),
          boxShadow: RS.soft6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // .of-head
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // .of-av — 36px; kilitli/açık
                SizedBox(
                  width: 36,
                  height: 36,
                  child: acik
                      ? DecoratedBox(
                          // `IC_AVOPEN` — mavi degrade daire + baş harfler.
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2E7BE0), Color(0xFF1A4FC4)],
                            ),
                          ),
                          child: Center(
                            child: Text(_basHarfler(),
                                style: refText(
                                    size: 13,
                                    weight: RF.w700,
                                    color: RC.white)),
                          ),
                        )
                      : const RefSvg('assets/svg/ic_avlock.svg', size: 36),
                ),
                const SizedBox(width: 9), // gap:9px
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .of-name (+ .of-unl)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _ad(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: refText(
                                  size: RF.s135,
                                  weight: RF.w700,
                                  color: RC.text,
                                  letterSpacing: 0.2),
                            ),
                          ),
                          if (acik) ...[
                            const SizedBox(width: 6), // .of-unl{margin-left:6px}
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 2, horizontal: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F9EF),
                                borderRadius: BorderRadius.circular(RR.r6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const RefSvg('assets/svg/ic_shieldok.svg',
                                      size: 12, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 3), // gap:3px
                                  Text('İletişim Açıldı',
                                      style: refText(
                                          size: 9.5,
                                          weight: RF.w700,
                                          color: const Color(0xFF16A34A))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      // .of-sub — puan + yorum sayısı
                      const SizedBox(height: 2), // margin-top:2px
                      Row(
                        children: [
                          const RefSvg('assets/svg/ic_starb.svg', size: 12),
                          const SizedBox(width: 4), // gap:4px
                          Text(
                            ortalama == null
                                ? '—'
                                : ortalama.toStringAsFixed(1),
                            style: refText(
                                size: RF.s115,
                                weight: RF.w700,
                                color: RC.blue),
                          ),
                          const SizedBox(width: 4),
                          Text('(${liste.length})',
                              style: refText(
                                  size: 11,
                                  weight: RF.w400,
                                  color: RC.textSoft)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                // .of-right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(tl(offer.amount),
                        style: refText(
                            size: 14.5,
                            weight: RF.w800,
                            color: RC.text,
                            letterSpacing: RF.lsM02)),
                    const SizedBox(height: 2), // .of-pl{margin-top:2px}
                    Text('Teklif Fiyatı',
                        style: refText(
                            size: 10, weight: RF.w600, color: RC.blue)),
                  ],
                ),
              ],
            ),

            // .of-quote — teklif notu
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(RR.r8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    // .of-quote svg{margin-top:2px}
                    padding: EdgeInsets.only(top: 2),
                    child: RefSvg('assets/svg/ic_quote.svg', size: 15),
                  ),
                  const SizedBox(width: 6), // gap:6px
                  Expanded(
                    child: Text(
                      offer.note,
                      style: refText(
                          size: 11,
                          weight: RF.w400,
                          color: const Color(0xFF3A4658),
                          height: RF.lh140),
                    ),
                  ),
                ],
              ),
            ),

            // .of-meta — zaman | kimlik | olumlu yorum
            const SizedBox(height: 5),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const RefSvg('assets/svg/ic_clock.svg',
                    size: 13, color: RC.textSoft),
                const SizedBox(width: 4),
                Text(_goreliZaman(offer.createdAt),
                    style: refText(
                        size: 10, weight: RF.w400, color: RC.textSoft)),
                _ayrac(),
                const RefSvg('assets/svg/ic_shieldok.svg',
                    size: 13, color: RC.textSoft),
                const SizedBox(width: 4),
                Text('Kimlik Doğrulandı',
                    style: refText(
                        size: 10, weight: RF.w400, color: RC.textSoft)),
                // ⚠ Oran YALNIZ gerçek yorum varsa yazılır; veri yoksa
                // referanstaki gibi uydurma bir yüzde GÖSTERİLMEZ.
                if (olumlu != null) ...[
                  _ayrac(),
                  const RefSvg('assets/svg/ic_thumb.svg',
                      size: 13, color: RC.textSoft),
                  const SizedBox(width: 4),
                  Text('%$olumlu olumlu yorum',
                      style: refText(
                          size: 10, weight: RF.w400, color: RC.textSoft)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
