import 'package:flutter/material.dart';
import '../domain/form_mesajlari.dart';
import '../domain/config.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/tutar_bicimi.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// Müşteri — Değerlendirme (HTML vReview): yıldızlar + yorum;
/// tek sefer, yalnız tamamlanmış işte (kurallar controller'da).
class ReviewScreen extends StatefulWidget {
  final String listingId;
  final String offerId;
  const ReviewScreen({super.key, required this.listingId, required this.offerId});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _stars = 0;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    if (_stars < 1) {
      setState(() => _error = FormMesaj.puanSec);
      return;
    }
    // ── ⚠ YORUM TAMAMEN İSTEĞE BAĞLIDIR ──
    //
    // Ürün kararı: PUAN ZORUNLU, YORUM SERBEST. Kullanıcı yalnız
    // yıldız verip gönderebilir.
    //
    final yorum = _text.text.trim();
    setState(() { _busy = true; _error = null; });
    final me = context.read<AuthController>().currentAccount!;
    final err = await context.read<ReviewController>().submit(
        listingId: widget.listingId, offerId: widget.offerId,
        actorId: me.id, stars: _stars, text: yorum);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err.message);
      return;
    }
    // ⚠ EKRANDAN ÇIKILMAZ.
    //
    // Referans `submitReviewDo()`: toast gösterilir ve AYNI ekran
    // "gönderildi" görünümüyle yeniden çizilir. Önceden `geriGit`
    // çağrılıyordu; kullanıcı değerlendirmesinin yayınlandığını
    // GÖREMİYORDU. `ReviewController` bildirim yayınladığı için
    // `done != null` olur ve alt taraf salt-okunur görünüme geçer.
    sysToastOk(context, 'Değerlendirmeniz gönderildi ✓');
  }

  // ═════════════════════════════════════════════════════════════
  // GÖRÜNÜM — referans `vReview()`
  //
  //   .rv-h3   {16.5px/700; margin:20px 1px 4px}
  //   .rv-sub2 {13px #3A4658}
  //   .rv-stars{center; gap:10px; margin-top:14px}
  //   .rv-hint {center; #8A94A6; 12.5px; margin-top:8px}
  //   .rv-opt  {500; #5B6472; 13px}
  //   .rv-tawrap + .rv-ta{min-height:150px; 1.5px #E7EAEF; r13}
  //   .rg-infobox.blue  ·  .pr-cta (geniş mavi düğme)
  //
  // Tek sefer kuralı KORUNUR: gönderilmişse salt-okunur görünüm.
  // ═════════════════════════════════════════════════════════════
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = context.watch<ReviewController>().byOffer(widget.offerId);

    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: RefScroll(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── ⚠ İKİ ÇIKIŞ YOLU: GERİ OKU + KAPAT ──
              //
              // Değerlendirme ekranına genelde teklif detayı → ilan
              // detayı → ... zinciriyle geliniyor. Yorum gönderildikten
              // sonra kullanıcı ana ekrana dönmek için o zinciri
              // TEK TEK geri almak zorunda kalıyordu.
              //
              // ⚠ GERİ OKU KALDIRILMADI: bir adım geri dönmek isteyen
              // (ör. teklifi yeniden görmek) hâlâ dönebilir. Sağdaki
              // X ise zinciri kapatıp doğrudan ana ekrana götürür.
              // İki farklı ihtiyaç, iki ayrı düğme.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // `.rv-wrap .rg-back{margin:2px 0 10px -4px}`
                  // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar).
                  const RefBackButton(),
                  RefTap(
                    // ⚠ `pushNamedAndRemoveUntil` ile TÜM yığın
                    // temizlenir: arkada duran teklif/ilan ekranları
                    // kalırsa kullanıcı ana ekrandan geri tuşuna
                    // basınca değerlendirme akışına geri düşerdi.
                    //
                    // ⚠ HEDEF `/customer/listings`: alt barın dört
                    // sekmesini (İlan Ver · İlanlarım · Bildirimler ·
                    // Profil) taşıyan ekran budur. `/home` alt bar
                    // TAŞIMAZ — oraya götürmek kullanıcıyı sekmesiz
                    // bırakırdı.
                    //
                    // ⚠ Değerlendirmeyi YALNIZ hizmet alan yapar
                    // (API sözleşmesi §14), bu yüzden rol ayrımı yok.
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/customer/listings', (r) => false),
                    borderRadius: BorderRadius.circular(RR.circle),
                    // ── ⚠ KAPAT DÜĞMESİ BELİRGİNLEŞTİRİLDİ ──
                    //
                    // Önce yalnız 20 birimlik çıplak bir çarpıydı;
                    // zemini olmadığı için düğme olduğu anlaşılmıyor,
                    // başlıkla karışıyordu.
                    //
                    // ⚠ DIŞ ÖLÇÜ DEĞİŞMEDİ: geri oku 22 ikon + 8 dolgu
                    // = 38 birim. Daire de 38 birim; satır yüksekliği
                    // ve hizalama AYNI kalır, arayüz kaymaz.
                    //
                    // ⚠ Zemin `RC.surface` — projede zaten kullanılan
                    // nötr gri; yeni renk tanımlanmadı.
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: RC.surface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      // ⚠ `ic_x` DEĞİL `ic_close`.
                      //
                      // `ic_x` ÇİFT RENKLİ: gri dolu daire + İÇİNDE
                      // beyaz çarpı. `RefSvg` rengi `srcIn` ile
                      // çizimin TAMAMINA uygular; koyu renk verilince
                      // beyaz çarpı da koyuya dönüşüyor ve geriye DÜZ
                      // BİR NOKTA kalıyordu.
                      //
                      // `ic_close` tek renkli çizgi çarpıdır
                      // (`currentColor`), boyandığında anlamını korur.
                      child: const RefSvg('assets/svg/ic_close.svg',
                          size: 18, color: RC.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // .rv-title{26px/700;-.3px}
              // ⚠ Ekran başlığı da düğmeyle AYNI: kullanıcı "Yorum Yaz"
              // düğmesine basıp "Hizmeti Değerlendir" başlıklı bir
              // ekrana düşünce doğru yere geldiğinden emin olamıyordu.
              // ⚠ BAŞLIK DURUMA GÖRE (9 Eyl): teklif detayındaki
              // "Yorum Yapıldı · Görüntüle" şeridi bu ekranı SALT
              // OKUNUR açıyor; o durumda "Yorum Yaz" başlığı yanlış.
              Text(done == null ? 'Yorum Yaz' : 'Değerlendirmen',
                  style: refText(
                      size: 26,
                      weight: RF.w700,
                      color: RC.text,
                      letterSpacing: -0.3)),
              // .rv-sub{14px;#5B6472;margin-top:7px}
              const SizedBox(height: 7),
              Text(
                  done == null
                      ? 'Aldığınız hizmet için puan ve yorumunuzu paylaşın.'
                      : 'Bu hizmet için verdiğiniz puan ve yorum.',
                  style: refText(
                      size: RF.s14, weight: RF.w400, color: RC.textSoft)),

              // .rv-prov — hizmet veren kartı
              _UstaKarti(
                listingId: widget.listingId,
                offerId: widget.offerId,
              ),

              if (done != null) ...[
                // ── .rv-done — GÖNDERİLDİ GÖRÜNÜMÜ ──
                //
                Padding(
                  padding: const EdgeInsets.fromLTRB(1, 12, 1, 7),
                  child: Text('Değerlendirmeniz',
                      style: refText(
                          size: RF.s14, weight: RF.w700, color: RC.text)),
                ),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: RC.white,
                    border: Border.all(color: RC.border),
                    borderRadius: BorderRadius.circular(RR.r15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .rv-done-head
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: _Yildiz(dolu: i <= done.stars, boyut: 20),
                            ),
                          const SizedBox(width: 6),
                          Text('${done.stars}.0',
                              style: refText(
                                  size: RF.s15,
                                  weight: RF.w700,
                                  color: RC.text)),
                          const Spacer(), // .rv-done-date{margin-left:auto}
                          Text(_tarih(done.createdAt),
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w400,
                                  color: RC.greyLight)),
                        ],
                      ),
                      // .rv-done-text (yorum yoksa italik gri)
                      const SizedBox(height: 10),
                      Text(
                        done.text.trim().isEmpty
                            ? 'Yorum eklenmedi.'
                            : done.text,
                        style: refText(
                          size: RF.s135,
                          weight: RF.w400,
                          color: done.text.trim().isEmpty
                              ? RC.greyLight
                              : const Color(0xFF3A4658),
                          height: RF.lh155,
                        ).copyWith(
                            fontStyle: done.text.trim().isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal),
                      ),
                      // ⚠ YEŞİL BİLGİ ŞERİDİ KALDIRILDI (kullanıcı
                      // isteği, 9 Eyl): "Değerlendirmeniz yayınlandı.
                      // Değiştirilemez ve silinemez."
                      //
                      // ⚠ KURAL DEĞİŞMEDİ, YALNIZ CÜMLE GİTTİ: yorum
                      // hâlâ tek sefer yazılır ve düzeltilemez —
                      // kayıt varken bu ekran form dalını HİÇ
                      // çizmez, yalnız salt okunur kartı gösterir.
                      // Kuralın kilidi cümlede değil, o dalda.
                    ],
                  ),
                ),
              ] else ...[
                // ── PUAN VER ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(1, 20, 1, 4),
                  child: Text('Puanınız',
                      style: refText(
                          size: 16.5, weight: RF.w700, color: RC.text)),
                ),
                // .rv-sub2
                Text('Hizmet kalitesini puanlayın',
                    style: refText(
                        size: RF.s13, weight: RF.w400, color: RC.textDark)),

                // .rv-stars
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++) ...[
                        if (i > 1) const SizedBox(width: 10),
                        RefTap(
                          onTap: () => setState(() => _stars = i),
                          borderRadius: BorderRadius.circular(RR.circle),
                          // ⚠ `bigStar()` referansta 42×42'dir.
                          child: _Yildiz(dolu: i <= _stars, boyut: 42),
                        ),
                      ],
                    ],
                  ),
                ),
                // .rv-hint
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '1 yıldız çok kötü, 5 yıldız mükemmel',
                    textAlign: TextAlign.center,
                    style: refText(
                        // `.rv-hint{color:#8A94A6}` = `RC.grey`
                        size: RF.s125, weight: RF.w400, color: RC.grey),
                  ),
                ),

                // .rv-h3 + .rv-opt
                Padding(
                  padding: const EdgeInsets.fromLTRB(1, 20, 1, 4),
                  child: Row(
                    children: [
                      Text('Yorumunuz',
                          style: refText(
                              size: 16.5, weight: RF.w700, color: RC.text)),
                      const SizedBox(width: 6),
                      Text('(İsteğe Bağlı)',
                          style: refText(
                              size: RF.s13,
                              weight: RF.w500,
                              color: RC.textSoft)),
                    ],
                  ),
                ),
                // .rv-tawrap + .rv-ta + .rv-cnt (sağ altta sayaç)
                Stack(
                  children: [
                    RefTextField(
                      controller: _text,
                      maxLines: 6,
                      // ⚠ SINIR 500 → 1000 (API sözleşmesi §14).
                      //
                      // Referans HTML'de `maxlength="500"` yazıyordu;
                      // nihai sözleşme "en fazla 1000 karakter" diyor.
                      // Sözleşme HTML'e ÜSTÜNDÜR (belge §31).
                      maxLength: DomainConfig.kYorumMaxKarakter,
                      // Yerleşik sayaç gizlenir; referanstaki `.rv-cnt`
                      // kutunun İÇİNDE sağ altta durur.
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              required maxLength}) =>
                          null,
                      onChanged: (_) => setState(() {}),
                      hint: 'Deneyiminizi paylaşabilirsiniz...',
                    ),
                    Positioned(
                      right: 13,
                      bottom: 10,
                      child: Text('${_text.text.characters.length}/${DomainConfig.kYorumMaxKarakter}',
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              // `.rv-cnt{color:#8A94A6}` = `RC.grey`
                              color: RC.grey)),
                    ),
                  ],
                ),

                RefInfoBox(
                  mavi: true,
                  child: Text(
                    'Verdiğiniz puan ve yorum, hizmet veren profilinde '
                    'yayınlanacaktır.',
                    style: refText(
                      size: RF.s135,
                      weight: RF.w400,
                      color: RC.textDark,
                      height: RF.lh150,
                    ),
                  ),
                ),

                // ⚠ HATA METNİ HİÇ ÇİZİLMİYORDU.
                //
                // `_error` yazılıyor ama ekranda gösterilmiyordu:
                // puan seçmeden gönderen kullanıcı "Lütfen bir puan
                // seçin" uyarısını GÖRMÜYOR, düğmenin neden işe
                // yaramadığını anlayamıyordu. Sunucudan gelen hata da
                // aynı şekilde sessizce yutuluyordu.
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s135, weight: RF.w600, color: RC.danger),
                    ),
                  ),

                // .pr-cta
                const SizedBox(height: 14),
                RefWideButton(
                  'Değerlendirmeyi Gönder',
                  busy: _busy,
                  // ── ⚠ PUAN ZORUNLU ──
                  //
                  // Yıldız seçilmeden düğme PASİFTİR: kullanıcı
                  // basıp hata almak yerine eksiği önceden görür.
                  //
                  // ⚠ `_submit` içindeki denetim KALDIRILMADI —
                  // ikinci savunma olarak duruyor.
                  //
                  // ⚠ YORUM KOŞULA GİRMEZ: boş yorumla gönderim
                  // serbesttir.
                  onPressed: _stars < 1 ? null : _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `bigStar(k, dolu)` — 42×42 yıldız (referans ölçüsü).
class _Yildiz extends StatelessWidget {
  const _Yildiz({required this.dolu, required this.boyut});

  final bool dolu;
  final double boyut;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: boyut,
        height: boyut,
        child: CustomPaint(painter: _YildizCizer(dolu: dolu)),
      );
}

/// Referans SVG yolu:
/// `M12 2.6l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.5l-5.9 3.1 1.2-6.5L2.5 9.5l6.6-.9z`
/// dolu → fill #F5A319 · boş → yalnız 1.4px kontur.
class _YildizCizer extends CustomPainter {
  const _YildizCizer({required this.dolu});

  final bool dolu;
  static const _renk = Color(0xFFF5A319);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final p = Path()
      ..moveTo(12 * k, 2.6 * k)
      ..relativeLineTo(2.9 * k, 6 * k)
      ..relativeLineTo(6.6 * k, 0.9 * k)
      ..relativeLineTo(-4.8 * k, 4.6 * k)
      ..relativeLineTo(1.2 * k, 6.5 * k)
      ..lineTo(12 * k, 17.5 * k)
      ..relativeLineTo(-5.9 * k, 3.1 * k)
      ..relativeLineTo(1.2 * k, -6.5 * k)
      ..lineTo(2.5 * k, 9.5 * k)
      ..relativeLineTo(6.6 * k, -0.9 * k)
      ..close();
    if (dolu) {
      canvas.drawPath(p, Paint()..color = _renk);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = _renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * k,
    );
  }

  @override
  bool shouldRepaint(_YildizCizer old) => old.dolu != dolu;
}

/// `.rv-done-date` — referansta "Bugün"; burada göreli tarih.
String _tarih(DateTime t) {
  final f = DateTime.now().difference(t);
  if (f.inHours < 24) {
    return 'Bugün';
  }
  if (f.inDays < 7) {
    return '${f.inDays} gün önce';
  }
  if (f.inDays < 30) {
    return '${(f.inDays / 7).floor()} hafta önce';
  }
  return '${(f.inDays / 30).floor()} ay önce';
}

/// `.rv-prov` — değerlendirilen hizmet veren kartı.
///
/// ```css
/// .rv-prov{gap:15px;#fff;1px #ECEEF1;r16;padding:16px;margin-top:16px;
///          box-shadow:0 2px 10px rgba(20,40,80,.04)}
/// .rv-pname{19px/700}   .pr-line{gap:5px;11.8px;#3A4658}
/// .rv-price{700;14px}
/// ```
///
/// ⚠ İletişim bu aşamada MUTLAKA açıktır (değerlendirme yalnız
/// tamamlanmış işte yapılır), bu yüzden ad ve avatar MASKELENMEZ.
class _UstaKarti extends StatelessWidget {
  const _UstaKarti({required this.listingId, required this.offerId});

  final String listingId;
  final String offerId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final offers = context.watch<OfferController>().offersForListing(listingId);
    final offer = offers.where((o) => o.id == offerId).firstOrNull;
    final listing = context.watch<ListingController>().byId(listingId);
    if (offer == null || listing == null) {
      return const SizedBox.shrink();
    }
    final prov = auth.accountById(offer.providerId);
    final reviews = context.watch<ReviewController>();
    final revs = reviews.byProvider(offer.providerId);
    final avg = reviews.averageOf(offer.providerId);
    final ad = (prov?.name ?? '').trim();
    final harfler = ad.isEmpty
        ? '?'
        : ad
            .split(RegExp(r'\s+'))
            .where((k) => k.isNotEmpty)
            .map((k) => k[0])
            .take(2)
            .join()
            .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r16),
        boxShadow: RS.soft6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .pr-av + .pr-vb
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E7BE0), Color(0xFF1A4FC4)],
                      ),
                    ),
                    child: Text(harfler,
                        style: refText(
                            size: 32, weight: RF.w700, color: RC.white)),
                  ),
                ),
                const Positioned(
                  right: -2,
                  bottom: 2,
                  child: RefSvg('assets/svg/ic_vbadge.svg', size: 26),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15), // gap:15px
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2), // .rv-px
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad.isEmpty ? 'Hizmet Veren' : ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: 19, weight: RF.w700, color: RC.text)),
                  const SizedBox(height: 6),
                  // puan + yorum sayısı
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_starb.svg', size: 15),
                      const SizedBox(width: 5),
                      Text(avg == null ? '—' : avg.toStringAsFixed(1),
                          style: refText(
                              size: RF.s135,
                              weight: RF.w700,
                              color: RC.blue)),
                      const SizedBox(width: 5),
                      Text('(${revs.length} yorum)',
                          style: refText(
                              size: 11.8,
                              weight: RF.w400,
                              color: const Color(0xFF3A4658))),
                    ],
                  ),
                  // hizmet başlığı
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_toolb.svg', size: 19),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: refText(
                                size: 11.8,
                                weight: RF.w400,
                                color: const Color(0xFF3A4658))),
                      ),
                    ],
                  ),
                  // teklif tutarı
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_tag.svg', size: 19),
                      const SizedBox(width: 5),
                      // ⚠ AYNI KUSUR BURADA DA VARDI: `tl()` "₺6000"
                      // yazıyordu. Tutar biçimi tek kaynaktan.
                      Text(tutarMetni(offer.amount),
                          style: refText(
                              size: RF.s14, weight: RF.w700, color: RC.text)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
