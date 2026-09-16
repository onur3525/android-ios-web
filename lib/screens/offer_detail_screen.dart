import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/validators.dart';
import '../domain/iletisim_maskesi.dart';
import '../core/telefon_bicimi.dart';
import '../core/tutar_bicimi.dart';
import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
// ⚠ YALNIZ `Role`: fotoğraf rol bazlıdır (bkz. Account.fotografi).
import '../data/models/account.dart' show Role;
import '../data/controllers/contact_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/models/listing.dart';
import '../data/models/offer.dart';
import '../data/models/review.dart';
// ⚠ `status_ui.dart` importu KALDIRILDI (10 Eyl): bu ekranda artık
// `tl` kullanılmıyor, tutar `core/tutar_bicimi.dart`tan biçimleniyor.
import 'widgets/hc_widgets.dart';
import 'chat_screen.dart';
import 'review_screen.dart';
import '../domain/saglayici_ozeti.dart';
// ⚠ Yorum kartı ORTAK — kopya çizim yok.
import 'provider_reviews_screen.dart' show YorumKarti;
import 'widgets/puan_dagilim_satiri.dart';
import 'widgets/profil_avatari.dart';
import 'widgets/durum_seridi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';

/// Müşteri — Teklif / Teklif Veren Profili (HTML vOffer):
/// usta kartı (ad, doğrulanmış rozeti, puan), teklif tutarı+notu,
/// İletişim Bilgilerini Aç (ortak durum) ve Teklifi Seç.
class OfferDetailScreen extends StatefulWidget {
  final String offerId;
  const OfferDetailScreen({super.key, required this.offerId});
  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

// ── ⚠ EKRAN KORUMASI AÇIK ──
//
// Bu ekranda açılan iletişim bilgisi görünür. Koruma açıkken ekran görüntüsü
// alınamaz ve son uygulamalar listesinde önizleme çizilmez.
class _OfferDetailScreenState extends State<OfferDetailScreen>
 {
  bool _busyContact = false;
  bool _busySelect = false;

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
    final offerCtl = context.watch<OfferController>();
    final contactCtl = context.watch<ContactController>();
    final listingCtl = context.watch<ListingController>();
    final reviewCtl = context.watch<ReviewController>();

    Offer? o;
    for (final l in listingCtl.byOwner(me.id)) {
      for (final x in offerCtl.offersForListing(l.id)) {
        if (x.id == widget.offerId) {
          o = x;
        }
      }
    }
    if (o == null) {
      return Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: SysEmpty(
                      title: 'Teklif bulunamadı',
                      desc: 'Bu teklif kaldırılmış olabilir.'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final offer = o;
    final l = listingCtl.byId(offer.listingId)!;
    final prov = auth.accountById(offer.providerId);
    // ── ⚠ SEÇİLEN TEKLİFİN İLETİŞİMİ AÇIK SAYILIR ──
    //
    // Referans `offersFor()`: ilan tamamlandığında seçilen teklif için
    // `CONTACT_OPEN[...] = true` yazılır — yani tamamlanmış işte
    // iletişim AÇIKTIR ve "İletişimi Aç" düğmesi bir daha çıkmaz.
    //
    // Bu bir kısayol değil, kuralın kendisi: iletişim açılmadan
    // "Teklifi Seç" düğmesi zaten çizilmez, dolayısıyla seçilmiş bir
    // teklifin iletişimi tanım gereği açılmıştır.
    // ⚠ KOŞUL İLAN DURUMUNA BAĞLANMAZ.
    //
    // Önce `l.status == completed` şartı vardı; ama seçim yapılmış
    // ESKİ kayıtlarda ilan `providerSelected` ya da `inProgress`
    // kalmış olabiliyor (kural değişmeden önce üretilen veriler ve
    // backend'in gönderdiği durumlar). O ilanlarda "İletişimi Aç"
    // düğmesi yeniden çıkıyordu — oysa iletişim çoktan açılmıştı.
    //
    // Belirleyici olan tek şey SEÇİLMİŞ OLMAK: seçim ancak iletişim
    // açıkken yapılabildiği için, seçilmiş teklifin iletişimi tanım
    // gereği açıktır.
    final open = contactCtl.isOpen(offer.id) ||
        l.selectedOfferId == offer.id ||
        offer.status == OfferStatus.selected;
    final revs = reviewCtl.byProvider(offer.providerId);
    final avg = revs.isEmpty
        ? null
        : revs.map((r) => r.stars).reduce((a, b) => a + b) / revs.length;

    // ── GÖRÜNÜM: referans `vOffer()` / `.pr-*` ──
    //
    // ⚠ Referansta AppBar YOKTUR; yalnız `.rg-back` bulunur.
    // ⚠ İLETİŞİM AÇILMADAN: hizmet verenin adı ve yorum sahiplerinin
    //   adı MASKELİDİR, avatarlar KİLİTLİ çizilir.
    final reviewed = reviewCtl.byOffer(offer.id) != null;
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: RefScroll(
          // `.pr-wrap{padding:calc(6px + safe-area) 14px 22px}`
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── .pr-head ──
              // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar).
              const Align(
                alignment: Alignment.centerLeft,
                child: RefBackButton(),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── .pr-av — HİZMET VERENİN FOTOĞRAFI ──
                  //
                  // ⚠ KULLANICI BULGUSU (12 Eyl): "İlan oluşturma ile
                  // gelen tekliflerin detayında hizmet verenin
                  // fotoğrafı görünmüyor."
                  //
                  // Fotoğraf desteği bir önceki turda `SahipKarti` ve
                  // `SaglayiciOzetSatiri`ne eklenmişti; BU ekran
                  // atlanmıştı ve hâlâ yalnız baş harf çiziyordu.
                  //
                  // ⚠ YALNIZ İLETİŞİM AÇIKKEN: fotoğraf maskelemenin
                  // parçasıdır, ayrı bir kural değil. Kapalıyken
                  // büyük kilitli avatar çizilir ve fotoğraf yolu
                  // OKUNMAZ bile.
                  //
                  // ⚠ HİZMET VEREN ROLÜNÜN fotoğrafı: çift rollü
                  // hesapta kişisel profil fotoğrafı burada yanlış
                  // kimliği gösterirdi.
                  //
                  // ⚠ DOĞRULAMA ROZETİ KALDIRILDI (12 Eyl): avatarın
                  // köşesindeki kalkan-tik artık çizilmiyor. Rozet
                  // gidince üst üste bindirme de gereksiz kaldı.
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Builder(builder: (context) {
                      if (!open) {
                        return const RefSvg('assets/svg/ic_avbig_lock.svg',
                            size: 84);
                      }
                      final foto = prov?.fotografi(Role.provider) ?? '';
                      // ⚠ FOTOĞRAFA DOKUNULUNCA TAM EKRAN AÇILIR —
                      // kural `ProfilAvatari` içinde tek yerde.
                      // Fotoğraf yoksa eski baş harfli daire kalır.
                      if (foto.trim().isEmpty) {
                        return _AcikAvatar(
                            harfler: _basHarfler(prov?.name), boyut: 84);
                      }
                      return ProfilAvatari(
                          ad: prov?.name ?? '', fotoYolu: foto, cap: 84);
                    }),
                  ),
                  const SizedBox(width: 12), // gap:12px
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6), // .pr-hx
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // .pr-name{17px/700;-.2px}
                          Text(
                            _saglayiciAdi(prov?.name, acik: open),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: refText(
                                size: 17,
                                weight: RF.w700,
                                color: RC.text,
                                letterSpacing: RF.lsM02),
                          ),
                          // .pr-line{gap:5px;11.8px;#3A4658;margin-top:6px}
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // ⚠ SARI YILDIZ (kullanıcı isteği,
                              // 10 Eyl): bu ekranda mavi yıldız
                              // (`ic_starb`) kullanılıyordu;
                              // uygulamadaki bütün yıldızlar
                              // `ic_starfill` + #F5A319.
                              const RefSvg('assets/svg/ic_starfill.svg',
                                  size: 15, color: Color(0xFFF5A319)),
                              const SizedBox(width: 5),
                              Text(
                                avg == null ? '—' : avg.toStringAsFixed(1),
                                // .pr-line b{#1D6BE3;13.5px}
                                style: refText(
                                    size: RF.s135,
                                    weight: RF.w700,
                                    color: RC.blue),
                              ),
                              const SizedBox(width: 5),
                              Text('(${revs.length} yorum)',
                                  style: refText(
                                      size: 11.8,
                                      weight: RF.w400,
                                      color: const Color(0xFF3A4658))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // ── ⚠ "Onaylı Hizmet Veren" — KOŞULA BAĞLI ──
                              //
                              // Teklif kartıyla AYNI kural
                              // (`onayliHizmetVeren`); iki ekran
                              // ayrışmasın diye tek kaynaktan okunur.
                              //
                              // ⚠ Resmi kimlik doğrulaması DEĞİLDİR.
                              if (prov?.onayliHizmetVeren ?? false) ...[
                                const RefSvg('assets/svg/ic_shieldok.svg',
                                    size: 16, color: Color(0xFF3A4658)),
                                const SizedBox(width: 5),
                                Text('Onaylı Hizmet Veren',
                                    style: refText(
                                        size: 11.8,
                                        weight: RF.w400,
                                        color: const Color(0xFF3A4658))),
                              ],
                              // ⚠ Oran YALNIZ gerçek yorum varsa yazılır.
                              // ⚠ AYRAÇ KOŞULLU: rozet gizlendiğinde bu
                              // satır ayraçla BAŞLIYORDU ("· %90
                              // olumlu yorum"). Ayraç yalnız SOLUNDA
                              // bir öğe varsa çizilir.
                              if (_olumluOran(revs) != null) ...[
                                if (prov?.onayliHizmetVeren ?? false)
                                  _prAyrac(),
                                const RefSvg('assets/svg/ic_thumb.svg',
                                    size: 16, color: Color(0xFF3A4658)),
                                const SizedBox(width: 5),
                                Text('%${_olumluOran(revs)} olumlu yorum',
                                    style: refText(
                                        size: 11.8,
                                        weight: RF.w400,
                                        color: const Color(0xFF3A4658))),
                              ],
                              // ── ⚠ TAMAMLANAN İŞ SAYISI (§11) ──
                              //
                              // "Teklif seçildiği anda tamamlanan iş
                              // sayısı +1 olur." Sayı SAKLANMAZ,
                              // türetilir: hizmet verenin seçilmiş
                              // teklifi olan tamamlanmış ilanlar
                              // sayılır. Böylece seçim anında
                              // kendiliğinden artar ve saklanan sayı
                              // ile gerçek veri ayrışamaz.
                              if (_tamamlananIs(context, offer.providerId) >
                                  0) ...[
                                // ⚠ Ayraç, SOLUNDA öğe varsa çizilir.
                                if ((prov?.onayliHizmetVeren ?? false) ||
                                    _olumluOran(revs) != null)
                                  _prAyrac(),
                                Text(
                                    '${_tamamlananIs(context, offer.providerId)} iş tamamladı',
                                    style: refText(
                                        size: 11.8,
                                        weight: RF.w400,
                                        color: const Color(0xFF3A4658))),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── .pr-price{#E8F0FD;r12;center;padding:9px;margin-top:12px}
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FD),
                  borderRadius: BorderRadius.circular(RR.r12),
                ),
                child: Column(
                  children: [
                    // ⚠ "Teklif Fiyatı" → "Verilen teklif" (10 Eyl):
                    // aynı bilgi öteki ekranlarda bu adla geçiyor.
                    Text('Verilen teklif',
                        style: refText(
                            size: 13, weight: RF.w500, color: RC.blue)),
                    const SizedBox(height: 1),
                    // ⚠ TUTAR ORTAK BİÇİMDEN (10 Eyl): `tl()` "₺5000"
                    // yazıyordu; uygulamanın her yerinde binlik
                    // ayracı ve "TL" `core/tutar_bicimi.dart`tan.
                    Text(tutarMetni(offer.amount),
                        style: refText(
                            size: 24,
                            weight: RF.w800,
                            color: RC.blue,
                            letterSpacing: -0.5)),
                  ],
                ),
              ),

              // ── Hizmet Verenin Teklifi ──
              //
              // ⚠ "Usta" DEĞİL: katalog artık özel ders, yazılım ve
              // oto servis gibi alanları da kapsıyor; matematik
              // öğretmeni "usta" değildir.
              _prBaslik('Hizmet Verenin Teklifi'),
              // .of-quote
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(RR.r8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: RefSvg('assets/svg/ic_quote.svg', size: 15),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      // ── ⚠ İLETİŞİM KAPALIYKEN MASKELİ ──
                      //
                      // Hizmet veren de teklif notuna telefon/adres
                      // yazarak bedelli adımı atlatabilir. Maskeleme
                      // İKİ YÖNDE de uygulanır.
                      //
                      // ⚠ Mevcut `open` bayrağı kullanılır; yeni
                      // iletişim mekanizması kurulmadı.
                      child: Text(
                          gorunenMetin(offer.note, iletisimAcik: open),
                          style: refText(
                              size: 11,
                              weight: RF.w400,
                              color: const Color(0xFF3A4658),
                              height: RF.lh140)),
                    ),
                  ],
                ),
              ),
              // .pr-time{gap:7px;#5B6472;12.5px;margin-top:10px}
              const SizedBox(height: 10),
              Row(
                children: [
                  const RefSvg('assets/svg/ic_clock.svg',
                      size: 15, color: RC.textSoft),
                  const SizedBox(width: 7),
                  Text(_prGoreliZaman(offer.createdAt),
                      style: refText(
                          size: RF.s125,
                          weight: RF.w400,
                          color: RC.textSoft)),
                ],
              ),

              // ── İletişim Bilgileri (.pr-cgrid) ──
              _prBaslik('İletişim Bilgileri'),
              // ⚠ `IntrinsicHeight` ZORUNLU — bkz. `wallet_screen`.
              //
              // `Row(stretch)` çocuklarına TIGHT yükseklik verir; bu
              // Row bir `Column` içinde olduğu için aldığı maxHeight
              // SONSUZDUR ve layout
              //   "BoxConstraints forces an infinite height"
              // ile düşer. `IntrinsicHeight` önce doğal yüksekliği
              // ölçer, `stretch` sonra iki kutuyu eşitler.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Expanded(
                    child: _IletisimKutusu(
                      ikon: 'assets/svg/ic_phone_f.svg',
                      etiket: 'Telefon',
                      // ⚠ Kapalıyken numara MASKELİ.
                      deger: open
                          ? _telefonGoster(prov?.phone)
                          : '05** *** ** **',
                      kilitli: !open,
                      // Referans: `<a href="tel:...">` — açıkken numara
                      // TIKLANABİLİR ve altı çizilidir.
                      altiCizili: open,
                      onTap: open ? () => _telefonAra(context, prov?.phone) : null,
                    ),
                  ),
                  const SizedBox(width: 11), // gap:11px
                  Expanded(
                    child: _IletisimKutusu(
                      ikon: 'assets/svg/ic_chat.svg',
                      etiket: 'Mesajlaşma',
                      deger: open
                          ? 'Mesaj yaz'
                          : 'Mesaj göndermek için iletişimi açın',
                      kilitli: !open,
                      kucukDeger: !open,
                      onTap: open
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ChatScreen(offerId: offer.id),
                                ),
                              )
                          : null,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Puan dağılımı (.pr-rating) ──
              _PuanKarti(reviews: revs, ortalama: avg),

              // ── Müşteri Yorumları (.pr-revlist) ──
              _prBaslik('Hizmet Alan Yorumları'),
              if (revs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Text('Henüz yorum yapılmamış.',
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s135,
                          weight: RF.w400,
                          color: RC.greyLight)),
                )
              else
                // ── ⚠ ORTAK YORUM KARTI (kullanıcı isteği, 10 Eyl) ──
                //
                // "Hizmet alan yorum kartı tamamen teklif al
                // ekranlarındaki gibi olmalı."
                //
                // Bu ekran kendi `_YorumSatiri`ni çiziyordu ve yeni
                // kuralların HİÇBİRİNİ almamıştı: profil fotoğrafı
                // vardı, ad TAM SOYADIYLA yazıyordu, yıldızların
                // yanında "5 puan" duruyordu, uzun yorumda aç/kapa
                // yoktu.
                //
                // ⚠ ARTIK `YorumKarti`: fotoğraf yok, "Gönül B.",
                // sağ üstte tarih, adın altında hizmet, altında
                // yıldızlar, altında yorum metni, uzun yorumda
                // Devamını oku / Daha az göster.
                //
                // ⚠ DIŞ ÇERÇEVE KALDIRILDI: kartların kendi çerçevesi
                // var; ikisi üst üste binince çift kenarlık
                // görünüyordu.
                Column(
                  children: [
                    for (var i = 0; i < revs.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                        child: YorumKarti(
                          review: revs[i],
                          yazarAdi:
                              auth.accountById(revs[i].authorId)?.name,
                        ),
                      ),
                  ],
                ),

              // ── CTA (.pr-cta + .pr-free) ──
              if (!open) ...[
                const SizedBox(height: 13),
                RefPrimaryButton(
                  'İletişimi Aç',
                  iconAsset: 'assets/svg/ic_lockw.svg',
                  busy: _busyContact,
                  // ⚠ Kapanmış teklifte iletişim AÇILAMAZ. Eski değer
                  // `cancelled` idi; nihai sözleşmede kapanış iki
                  // durumdur: `expired` (süre) ve `closed` (sistemsel).
                  onPressed: (offer.status == OfferStatus.closed ||
                          offer.status == OfferStatus.expired)
                      ? null
                      : () async {
                          if (_busyContact) {
                            return;
                          }
                          setState(() => _busyContact = true);
                          // ⚠ `context.mounted` — İLETİŞİM AÇMA PARA
                          // HAREKETİ İÇERİR. İşlem sunucuda tamamlanmış
                          // olabilir; kullanıcı bu sırada ekranı
                          // kapatırsa State canlı kalsa bile bu alt
                          // ağaç kalkmış olur ve toast çökme üretir.
                          //
                          // ⚠ İŞLEM SIRASI DEĞİŞMEDİ: `openShared`
                          // zaten çağrıldı; burada yalnız SONUCU
                          // gösterme güvenliği sağlanır.
                          final err = await context
                              .read<ContactController>()
                              .openShared(offer.id, actorId: me.id);
                          if (!context.mounted) {
                            return;
                          }
                          setState(() => _busyContact = false);
                          if (err != null) {
                            sysToastErr(context, SysKind.genericError,
                                extra: err.message);
                          } else {
                            sysToastOk(
                                context, 'İletişim iki taraf için açıldı');
                          }
                        },
                ),
                // ⚠ İŞ KURALI: müşteri ÖDEMEZ. İletişim bedeli hizmet
                // verenin teklif blokesinden TEK SEFER tüketilir.
                const DurumSeridi('İletişimi açmak ücretsizdir.'),
              // ⚠ SEÇİM YAPILMIŞ İLANDA "Teklifi Seç" ÇIKMAZ (§22).
              // İlan `active` kalsa bile seçilmiş teklifi varsa iş
              // tamamlanmıştır; ikinci seçim yapılamaz.
              ] else if (l.status == ListingStatus.active &&
                  !l.isTamamlanmisIs &&
                  offer.status == OfferStatus.active) ...[
                const SizedBox(height: 13),
                RefPrimaryButton(
                  'Teklifi Seç',
                  // ── ⚠ İKON DEĞİŞTİ: `ic_checkw` → `ic_check_line` ──
                  //
                  // `ic_checkw` ÇİFT RENKLİ: beyaz dolu daire + İÇİNDE
                  // mavi tik. Düğme ikonları `RefSvg`'ye `RC.white`
                  // ile veriliyor ve `srcIn` harmanı çizimin TAMAMINI
                  // tek renge boyuyor — mavi tik de beyaza dönüşünce
                  // geriye düz beyaz bir daire kalıyordu. Kullanıcının
                  // "anlamsız nokta" dediği şey buydu.
                  //
                  // Yeni ikon TEK RENKLİ çizgi tiktir; boyandığında
                  // anlamını korur.
                  //
                  // ⚠ `ic_checkw` SİLİNMEDİ: giriş ekranındaki "Beni
                  // Hatırla" kutusu onu RENK VERMEDEN kullanıyor ve
                  // orada çift renk DOĞRU görünüyor.
                  iconAsset: 'assets/svg/ic_check_line.svg',
                  busy: _busySelect,
                  // ── ⚠ SEÇİM VE YORUM AYRI ADIMLAR (ürün kararı) ──
                  //
                  // Referans prototipinde "Teklifi Seç" doğrudan
                  // değerlendirme panelini açıyordu (`openReview`).
                  // Ürün kararı bunu ikiye ayırdı: önce SEÇİM yapılır,
                  // yorum SONRA ve DİLENDİĞİ ZAMAN yazılır.
                  //
                  // ⚠ Bu düğme yalnız İLETİŞİM AÇIKKEN çizilir (üstteki
                  // `if (!open)` dalı). Yani iletişimi açılmamış bir
                  // teklif SEÇİLEMEZ.
                  onPressed: () async {
                    setState(() => _busySelect = true);
                    final err = await context
                        .read<OfferController>()
                        .selectOffer(
                            listingId: l.id,
                            offerId: offer.id,
                            actorId: me.id);
                    if (!mounted) {
                      return;
                    }
                    setState(() => _busySelect = false);
                    if (!context.mounted) {
                      return;
                    }
                    if (err != null) {
                      sysToastErr(context, SysKind.genericError,
                          extra: err.message);
                      return;
                    }
                    // ⚠ EKRAN KAPANMAZ: düğme yerinde "Yorum Yaz"a
                    // dönüşür, kullanıcı dilediği zaman yazar.
                    sysToastOk(context,
                        'Teklif seçildi — hizmet veren ile çalışmaya başlayabilirsiniz');
                  },
                ),
              ] else if (offer.status == OfferStatus.selected) ...[
                // ── AYNI DÜĞME, DEĞİŞEN GÖREV ──
                //
                // ⚠ Referans `vOffer()`: `.pr-cta` TEK bir yuvadır.
                // Teklif seçildikten sonra "Teklifi Seç" düğmesi ORTADAN
                // KALKMAZ, YERİNE DEĞERLENDİRME düğmesi gelir. Ayrı bir
                // düğme eklenmez, başka ekran değişmez.
                //
                // Değerlendirilmişse metin "Değerlendirme"ye döner ve
                // altındaki şeritte durum yazar (referanstaki
                // `reviewed ? ... : ...` dalı).
                const SizedBox(height: 13),
                // ── ⚠ YORUM YAPILDIYSA DÜĞME HİÇ ÇİZİLMEZ ──
                //
                // Eskiden düğme kalıyor ama tıklanamıyordu ("Değerlendirme
                // Yapıldı"). Ürün kararı: düğme YERİNDE DURMASIN, yerinde
                // yalnız durum yazısı kalsın. Tıklanamaz bir düğme
                // kullanıcıya hâlâ yapılacak bir iş varmış izlenimi
                // veriyordu.
                if (!reviewed)
                RefPrimaryButton(
                  'Yorum Yaz',
                  iconAsset: 'assets/svg/ic_starw.svg',
                  // ⚠ YORUM BİR KEZDİR: gönderildikten sonra bu dal
                  // hiç çizilmez (`if (!reviewed)`), yerinde yalnız
                  // durum yazısı kalır. Hizmet alan yorumunu sonradan
                  // silemez, düzeltemez, yeniden puanlayamaz.
                  //
                  // ⚠ Düğme yalnız SEÇİLMİŞ teklifte görünür
                  // (`offer.status == OfferStatus.selected` dalı) ve
                  // seçim ancak iletişim açıkken yapılabildiği için
                  // zincir tamdır: iletişim → seçim → yorum.
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ReviewScreen(listingId: l.id, offerId: offer.id),
                    ),
                  ),
                ),
                // ── ⚠ "Teklif seçildi" ŞERİDİ (12 Eyl, kullanıcı
                // isteği) ──
                //
                // "Teklif Seç düğmesine basıldığında düğmenin altında
                // şık bir 'Teklif seçildi' yazısı yazılsın."
                //
                // Seçim yapıldığında yalnız BİR ANLIK bildirim
                // çıkıyordu; kapandıktan sonra ekranda seçimin
                // yapıldığını söyleyen hiçbir kalıcı iz kalmıyordu.
                // Kullanıcı geri gelip "seçtim mi, seçmedim mi?" diye
                // bakıyordu. Düğmenin "Teklifi Seç"ten "Yorum Yaz"a
                // dönmesi bunu dolaylı anlatıyordu, doğrudan değil.
                //
                // ⚠ YALNIZ YORUM YAPILMADAN ÖNCE: yorum yazıldıktan
                // sonra yerini "Yorum yapıldı" şeridi alır. İki yeşil
                // şerit alt alta durmaz — sonuncusu neredeyse hep
                // geçerli olandır.
                //
                // ⚠ AYNI ŞERİT BİLEŞENİ: renk, ikon ve ölçü
                // `_UcretsizSerit` içinde tek yerde. "Yorum yapıldı"
                // ile birebir aynı görünür.
                //
                // ⚠ EYLEM SATIRI YOK: bu bir DURUM bildirimi,
                // gidilecek bir yer göstermiyor.
                if (!reviewed) const DurumSeridi('Teklif seçildi'),
                if (reviewed)
                  // ── ⚠ ŞERİT ARTIK DOKUNULABİLİR (kullanıcı isteği,
                  // 9 Eyl) ──
                  //
                  // Önceden yalnız puanı yazan ÖLÜ bir şeritti; yazdığı
                  // yoruma dönmenin hiçbir yolu yoktu. Şimdi dokununca
                  // `ReviewScreen` açılıyor — o ekran, kayıt varsa form
                  // yerine SALT OKUNUR "Değerlendirmeniz" kartını
                  // çiziyor (puan, metin, tarih + "değiştirilemez ve
                  // silinemez" notu). Yeni bir görüntüleme ekranı
                  // YAZILMADI.
                  //
                  // ⚠ KAPSAM: açılan kart YALNIZ BU TEKLİFE ait yorumu
                  // gösterir (`byOffer(offer.id)`), hizmet verenin
                  // öteki yorumlarını DEĞİL — kullanıcı kuralı: "sadece
                  // ilgili ilan için yapılmış yorum ve puan".
                  //
                  // ⚠ YORUM YİNE DEĞİŞTİRİLEMEZ: ekran yorum varken
                  // form dalını hiç çizmez, bu yol salt görüntülemedir.
                  RefTap(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ReviewScreen(listingId: l.id, offerId: offer.id),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(RR.r9),
                    // ── ⚠ PUAN ŞERİTTE YAZMAZ (12 Eyl, kullanıcı
                    // isteği) ──
                    //
                    // "Kaç puan verdiği burada yazmamalı."
                    //
                    // Puan zaten dokunulunca açılan ekranda, kendi
                    // bağlamında duruyor. Şeritte tekrar etmesi hem
                    // gereksizdi hem de satırı bir durum bildirimi
                    // olmaktan çıkarıp kalabalıklaştırıyordu.
                    child: const DurumSeridi('Yorum yapıldı',
                        aksiyon: 'Görüntüle'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REFERANS BİLEŞENLERİ — `vOffer()` / `.pr-*`
// ═══════════════════════════════════════════════════════════════

/// `.pr-h3{14px/700;margin:12px 1px 7px}`
Widget _prBaslik(String metin) => Padding(
      padding: const EdgeInsets.fromLTRB(1, 12, 1, 7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(metin,
            style: refText(size: RF.s14, weight: RF.w700, color: RC.text)),
      ),
    );

/// `.of-sep{color:#D3D8E0;margin:0 3px}`
Widget _prAyrac() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('|', style: TextStyle(color: Color(0xFFD3D8E0))),
    );

String _prGoreliZaman(DateTime t) {
  final f = DateTime.now().difference(t);
  if (f.inMinutes < 60) {
    return '${f.inMinutes} dk önce';
  }
  if (f.inHours < 24) {
    return '${f.inHours} saat önce';
  }
  if (f.inDays < 30) {
    return '${f.inDays} gün önce';
  }
  return '${(f.inDays / 30).floor()} ay önce';
}

/// Baş harfler — açık avatarda kullanılır (`avInitials`).
String _basHarfler(String? tamAd) {
  final t = (tamAd ?? '').trim();
  if (t.isEmpty) {
    return '?';
  }
  return t
      .split(RegExp(r'\s+'))
      .where((k) => k.isNotEmpty)
      .map((k) => k[0])
      .take(2)
      .join()
      .toUpperCase();
}

/// İLETİŞİM AÇILMADAN AD MASKELENİR: `E*** K*****`.
String _saglayiciAdi(String? tamAd, {required bool acik}) {
  final t = (tamAd ?? '').trim();
  if (t.isEmpty) {
    return 'Hizmet Veren';
  }
  if (acik) {
    return t;
  }
  return t
      .split(RegExp(r'\s+'))
      .map((k) => k.isEmpty ? k : '${k[0]}${'*' * (k.length - 1)}')
      .join(' ');
}

/// Yorum sahibi maskesi: `A*** Y.` — ad maskeli, soyadın baş harfi.
String _yorumcuAdi(String? tamAd, {required bool acik}) {
  final t = (tamAd ?? '').trim();
  if (t.isEmpty) {
    return 'Hizmet Alan';
  }
  final p = t.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
  if (acik) {
    return t;
  }
  final ad = p.first;
  final maskeli = '${ad[0]}${'*' * (ad.length - 1)}';
  return p.length > 1 ? '$maskeli ${p[1][0]}.' : maskeli;
}

/// `%N olumlu yorum` — 4 ve 5 yıldızlı yorumların oranı.
/// Yorum yoksa `null` döner ve satır HİÇ çizilmez (uydurma yüzde yok).
/// Hizmet verenin TAMAMLANAN İŞ sayısı (API sözleşmesi §11).
///
/// ⚠ TÜRETİLİR, SAKLANMAZ: seçilmiş teklifi bu hizmet verene ait olan
/// ve tamamlanmış ilanlar sayılır. Saklanan bir sayaç, iptal/silme
/// durumlarında gerçek veriyle ayrışırdı.
int _tamamlananIs(BuildContext c, String providerId) =>
    tamamlananIsSayisi(c, providerId);

int? _olumluOran(List<Review> revs) {
  if (revs.isEmpty) {
    return null;
  }
  return (revs.where((r) => r.stars >= 4).length * 100 / revs.length).round();
}

/// `IC_AVBIG_OPEN` / `IC_AVOPEN` — mavi degrade daire + baş harfler.
class _AcikAvatar extends StatelessWidget {
  const _AcikAvatar({required this.harfler, required this.boyut});

  final String harfler;
  final double boyut;

  @override
  Widget build(BuildContext context) => Container(
        width: boyut,
        height: boyut,
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
                size: boyut * .35, weight: RF.w700, color: RC.white)),
      );
}

/// `.pr-cbox` — telefon / mesajlaşma kutusu.
///
/// ```css
/// .pr-cbox{gap:8px;1px #ECEEF1;r11;padding:9px;#fff}
/// .pr-cic{34x34;%50;#EAF1FB;#1D6BE3}  .pr-cic svg{17px}
/// .pr-cl{12px;#5B6472}  .pr-cv{14px/700}  .pr-cv2{11px/500;1.35}
/// .pr-clock{30x30;%50;#EEF0F4}
/// ```
class _IletisimKutusu extends StatelessWidget {
  const _IletisimKutusu({
    required this.ikon,
    required this.etiket,
    required this.deger,
    required this.kilitli,
    this.kucukDeger = false,
    this.altiCizili = false,
    this.onTap,
  });

  final String ikon;
  final String etiket;
  final String deger;
  final bool kilitli;
  final bool kucukDeger;

  /// Referansta telefon bir `<a href="tel:">` bağlantısıdır; tarayıcı
  /// varsayılanı gereği etiket ve numara ALTI ÇİZİLİ görünür.
  final bool altiCizili;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kutu = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r11),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: RC.blueSoft,
              shape: BoxShape.circle,
            ),
            child: RefSvg(ikon, size: 17, color: RC.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(etiket,
                    style: refText(
                        size: RF.s12,
                        weight: RF.w400,
                        color: RC.textSoft,
                        decoration:
                            altiCizili ? TextDecoration.underline : null)),
                const SizedBox(height: 2),
                Text(
                  deger,
                  maxLines: kucukDeger ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: kucukDeger
                      ? refText(
                          size: 11,
                          weight: RF.w500,
                          color: RC.text,
                          height: 1.35)
                      : refText(
                          size: RF.s14,
                          weight: RF.w700,
                          color: RC.text,
                          decoration: altiCizili
                              ? TextDecoration.underline
                              : null),
                ),
              ],
            ),
          ),
          if (kilitli) ...[
            const SizedBox(width: 6),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF0F4),
                shape: BoxShape.circle,
              ),
              child: const RefSvg('assets/svg/ic_locksm.svg', size: 17),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return kutu;
    }
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r11),
      child: kutu,
    );
  }
}

/// `.pr-rating` — ortalama + yıldız dağılımı.
class _PuanKarti extends StatelessWidget {
  const _PuanKarti({required this.reviews, required this.ortalama});

  final List<Review> reviews;
  final double? ortalama;

  @override
  Widget build(BuildContext context) {
    // `distRows()` — 5'ten 1'e yüzdeler. GERÇEK yorumlardan hesaplanır.
    final toplam = reviews.length;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // .pr-rleft
          Container(
            padding: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              border: Border(
                  right: BorderSide(color: Color(0xFFEFF1F4))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ortalama == null ? '—' : ortalama!.toStringAsFixed(1),
                    style: refText(
                        size: 26, weight: RF.w800, color: RC.text)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 2), // gap:2px
                        // ⚠ SARI YILDIZ (10 Eyl): dolu da boş da aynı
                        // renkte; boş yıldız `ic_starempty` zaten
                        // konturlu.
                        child: RefSvg(
                          (ortalama ?? 0) >= i - 0.5
                              ? 'assets/svg/ic_starfill.svg'
                              : 'assets/svg/ic_starempty.svg',
                          size: 17,
                          color: const Color(0xFFF5A319),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('($toplam yorum)',
                    style: refText(
                        size: RF.s115,
                        weight: RF.w400,
                        color: RC.textSoft)),
              ],
            ),
          ),
          const SizedBox(width: 11), // gap:11px
          // .pr-rright
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── ⚠ ORTAK DAĞILIM SATIRI (kullanıcı isteği,
                // 10 Eyl) ──
                //
                // "% değil, kaç kişi kaç yıldız verdiyse karşısına
                // yazılacak; teklif al ekranlarındaki aynı mantıkta
                // olmalı."
                //
                // ⚠ YÜZDE YANILTICIYDI: tek yorumu olan için "%100"
                // yazıyordu — sayı büyük görünüyor ama arkasında bir
                // kişi var.
                //
                // ⚠ ÇUBUK DA DÜZELDİ: burada `heightFactor`
                // verilmediği için dolgu HİÇ görünmüyordu; ortak
                // bileşende düzeltildi.
                for (var yildiz = 5; yildiz >= 1; yildiz--) ...[
                  PuanDagilimSatiri(
                    yildiz: yildiz,
                    adet: reviews.where((r) => r.stars == yildiz).length,
                    toplam: toplam,
                  ),
                  if (yildiz != 1) const SizedBox(height: 6), // gap:6px
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ⚠ `_DagilimSatiri` KALDIRILDI (10 Eyl): dağılım satırı artık
/// `widgets/puan_dagilim_satiri.dart` içinde TEK yerde. Bu kopya
/// yüzde yazıyor, mavi dolgu kullanıyor ve `heightFactor` vermediği
/// için çubuğu hiç doldurmuyordu.

/// ⚠ `_YorumSatiri` KALDIRILDI (10 Eyl): yorum kartı artık ortak
/// `YorumKarti` bileşeni. Bu kopya profil fotoğrafı çiziyor, adı tam
/// soyadıyla yazıyor, yıldızların yanına "N puan" koyuyor ve uzun
/// yorumda aç/kapa sunmuyordu.


// ⚠ `_UcretsizSerit` ORTAK BİLEŞENE TAŞINDI (12 Eyl):
// `widgets/durum_seridi.dart` içindeki `DurumSeridi`. Bul akışının
// detay ekranı da aynı şeridi çiziyor; private kaldığı sürece o
// ekran onu göremiyor ve kendi kopyasını yazıyordu.


/// Referans `OFFER_PHONE.open` biçimi: `0532 123 45 67`.
///
/// Modelde numara 10 hane (baştaki `0` yok) saklanır; gösterimde
/// başına `0` eklenip 4-3-2-2 gruplanır.
String _telefonGoster(String? ham) {
  final d = Validators.phoneLocal(ham ?? '');
  if (d.isEmpty) {
    return '—';
  }
  // ⚠ TEK KURAL KAYNAĞI — bkz. `profile_screen` notu.
  return TelefonBicimlendirici.gruplu(d);
}

/// `<a href="tel:...">` karşılığı — telefon uygulamasını açar.
Future<void> _telefonAra(BuildContext context, String? ham) async {
  final d = Validators.phoneLocal(ham ?? '');
  if (d.isEmpty) {
    return;
  }
  final uri = Uri.parse('tel:$d');
  final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
  // ⚠ Sahte başarı YOK: arama uygulaması açılamazsa kullanıcı uyarılır.
  if (!acildi && context.mounted) {
    sysToastErr(context, SysKind.genericError,
        extra: 'Arama uygulaması açılamadı');
  }
}
