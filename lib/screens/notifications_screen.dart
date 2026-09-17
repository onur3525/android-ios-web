import 'package:flutter/material.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import 'teklif_talebi_sohbet_screen.dart';
import 'chat_screen.dart';
import 'job_detail_screen.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/listing_controller.dart';
import 'listing_detail_screen.dart';
import 'teklif_talebi_detay_screen.dart';
import 'widgets/hata_gosterimi.dart';
import '../domain/hata_mesajlari.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/notification_controller.dart';
import '../data/models/account.dart';
import '../data/models/notification.dart';
import '../domain/bildirim_rolu.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';

/// ═══════════════════════════════════════════════════════════════
/// BİLDİRİMLER — referans `vNotif()`
///
/// ```
/// <div class="nt-wrap">
///   <div class="nt-top">
///     <h1 class="nt-title">Bildirimler</h1>
///     <button class="nt-readall" onclick="ntReadAll()">Tümünü Okundu Yap</button>
///   </div>
///   <div class="nt-list">
///     <div class="nt-card [un]" onclick="ntRead(i)">
///       [<span class="nt-dot"></span>]
///       <div class="nt-ic" style="background:...">ntIcon(n.ic)</div>
///       <div class="nt-body">
///         <div class="nt-head"><span class="nt-t">..</span><span class="nt-tm">..</span></div>
///         <div class="nt-d">..</div>
///       </div>
///     </div>
///   </div>
/// </div>
/// custNav('bildirim')
/// ```
///
/// CSS:
///   .nt-top     { justify-content:space-between; margin-bottom:14px }
///   .nt-title   { 25px/700 #16233D; ls -.3 }
///   .nt-readall { 13.5px/700 #1D6BE3 }
///   .nt-list    { gap:10px }
///   .nt-card    { radius:14px; padding:13px 13px 13px 22px; gap:12px }
///   .nt-card.un { background:#F3F8FF }
///   .nt-dot     { left:7px; 10×10; #1D6BE3; halka rgba(29,107,227,..) }
///   .nt-ic      { 46×46; radius:12px }
///   .nt-t       { 14.5px/700 #16233D }
///   .nt-tm      { 11.5px #98A2B3 }
///   .nt-d       { 12.5px/1.5 #5B6472; margin-top:3px }
/// ═══════════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final me = context.read<AuthController>().currentAccount;
    if (me == null) {
      return;
    }
    await context.read<NotificationController>().load(me.id);
  }

  /// Bildirim tipine göre ikon ve zemin — referans `ntIcon(n.ic)` ve
  /// `style="background:${n.bg}"` karşılığı.
  (String, Color, Color) _gorunum(NotifType t) => switch (t) {
        // ⚠ Referans `ntIcon('doc')` → `IC_NDOC`. Yeni teklif bir
        // BELGE bildirimidir; sohbet ikonu `newMessage`e aittir.
        NotifType.newOffer => (
            'assets/svg/ic_ndoc.svg',
            const Color(0xFFEAF1FB),
            RC.blue
          ),
        NotifType.offerSelected => (
            'assets/svg/ic_checkc.svg',
            const Color(0xFFE9F9EF),
            RC.success
          ),
        NotifType.refund => (
            'assets/svg/ic_walletg.svg',
            const Color(0xFFE1F5EA),
            RC.success
          ),
        NotifType.contactOpened => (
            'assets/svg/ic_phone_f.svg',
            const Color(0xFFE7EFFD),
            RC.blue
          ),
        // `ntIcon('chat')` → `IC_NCHAT` (bildirim listesine özel 26px
        // sürüm; sohbet çubuğundaki `ic_chat` DEĞİL).
        NotifType.newMessage => (
            'assets/svg/ic_nchat.svg',
            const Color(0xFFEAF1FB),
            RC.blue
          ),
        NotifType.listingExpired => (
            'assets/svg/ic_clock.svg',
            const Color(0xFFF2F4F7),
            RC.grey
          ),
        // `ntIcon('shield')` → `IC_NSHIELD`.
        NotifType.accountStatus => (
            'assets/svg/ic_nshield.svg',
            const Color(0xFFE7EFFD),
            RC.blue
          ),
        NotifType.categoryRequest => (
            'assets/svg/ic_wrenchp.svg',
            const Color(0xFFF3E9FD),
            const Color(0xFF7C4DBE)
          ),
        // ⚠ Referansta duyuru MEGAFONDUR (`IC_NMEGA`), zil değil;
        // zil (`IC_NBELL`) genel hatırlatma bildirimine aittir.
        NotifType.announcement => (
            'assets/svg/ic_nmega.svg',
            const Color(0xFFFDF3E1),
            const Color(0xFFF5820C)
          ),
        // ── ⚠ "DOĞRUDAN TEKLİF İSTE" — YENİ TÜRLER ──
        //
        // `newOffer`/`offerSelected` ile AYNI görsel dilde ama ayrı
        // ikon seçimleri değil — bu akış zaten kendi ikonunu
        // (`ic_send.svg`) taşıyor, burada da tutarlılık için
        // kullanıldı.
        NotifType.teklifTalebiGeldi => (
            'assets/svg/ic_send.svg',
            const Color(0xFFE7F8EC),
            HC.green
          ),
        NotifType.teklifVerildi => (
            'assets/svg/ic_ndoc.svg',
            const Color(0xFFEAF1FB),
            RC.blue
          ),
        NotifType.teklifSecildi => (
            'assets/svg/ic_checkc.svg',
            const Color(0xFFE9F9EF),
            RC.success
          ),
        NotifType.teklifReddedildi => (
            'assets/svg/ic_close.svg',
            const Color(0xFFF2F4F7),
            RC.grey
          ),
        NotifType.teklifSuresiDoldu => (
            'assets/svg/ic_clock.svg',
            const Color(0xFFF2F4F7),
            RC.grey
          ),
        NotifType.teklifIsiTamamlandi => (
            'assets/svg/ic_shieldok.svg',
            const Color(0xFFE9F9EF),
            RC.success
          ),
        NotifType.teklifYeniMesaj => (
            'assets/svg/ic_nchat.svg',
            const Color(0xFFEAF1FB),
            RC.blue
          ),
        // `ntIcon` varsayılanı → `IC_NBELL`.
        NotifType.unknown => (
            'assets/svg/ic_nbell.svg',
            const Color(0xFFF2F4F7),
            RC.grey
          ),
      };

  /// Bildirim hedefi — mevcut yönlendirme kuralı KORUNDU.
  /// BİLDİRİMDEN İLGİLİ İÇERİĞE YÖNLENDİRME.
  ///
  /// ── ⚠ NİÇİN `refId` GEREKLİ ──
  ///
  /// Önce yalnız TÜRE bakılıyordu; "Yeni teklif aldınız" bildirimine
  /// dokunan kullanıcı Bildirimler ekranında KALIYORDU. Hangi ilana
  /// gideceği `refId`de duruyor ve okunmuyordu.
  ///
  /// ⚠ `refId` BOŞSA YERİNDE KALINIR: uydurma bir ilana yönlendirmek
  /// yerine hiçbir şey yapılmaz.
  void _openTarget(BuildContext context, NotifType t, String? refId) {
    final ilan = refId?.trim();
    final gecerli = ilan != null && ilan.isNotEmpty;

    switch (t) {
      case NotifType.announcement:
        break;
      case NotifType.accountStatus:
      case NotifType.categoryRequest:
        Navigator.pushNamed(context, '/provider/status');

      // ── HİZMET ALANIN İLANINA ──
      //
      // "Yeni teklif aldınız" ilan SAHİBİNE gider; ilan detayında
      // gelen teklifler listelenir.
      case NotifType.newOffer:
        if (gecerli) {
          Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => ListingDetailScreen(listingId: ilan)));
        }

      // ── ⚠ HİZMET VERENİN İŞ EKRANINA (12 Eyl düzeltmesi) ──
      //
      // "Teklifiniz seçildi" bildirimi HİZMET VERENE gider
      // (`mock_ports`: `userId: chosen.providerId`). Buradaki dal onu
      // `newOffer` ile aynı kutuya koyup `ListingDetailScreen`e
      // gönderiyordu — yani hizmet vereni, hizmet alanın kendi ilan
      // YÖNETİM ekranına düşürüyordu: gelen teklifler, "Teklifi Seç",
      // silme menüsü, "Yorum Yaz".
      //
      // ⚠ İKİ BİLDİRİM AYNI `refId`yi TAŞIR (ilan id'si) ama AYRI
      // TARAFA gider. Aynı `case` kutusunda toplanmaları bu farkı
      // gizliyordu.
      case NotifType.offerSelected:
        if (gecerli) {
          Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => JobDetailScreen(listingId: ilan)));
        }

      // ── ⚠ MESAJ BİLDİRİMİ DOĞRUDAN SOHBETE GİDER (12 Eyl,
      // kullanıcı isteği) ──
      //
      // "Mesaj geldi bildirimine tıklandığında direkt ilgili
      // mesajlaşma ekranına gidilmeli."
      //
      // ⚠ BURADA AYRICA BİR HATA VARDI: `newMessage` bildiriminin
      // `refId`si TEKLİF id'sidir (bkz. `mock_ports`: `refId: offerId`),
      // ilan id'si DEĞİL. Buradaki dal onu `JobDetailScreen`e
      // `listingId` olarak geçiriyordu — yani var olmayan bir ilan
      // aranıyordu. Bildirime dokunmak hiçbir yere götürmüyor ya da
      // boş ekran açıyordu.
      case NotifType.newMessage:
        if (gecerli) {
          Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(offerId: ilan)));
        }

      // ── ⚠ `contactOpened` ALICIYA GÖRE DALLANIR (12 Eyl
      // düzeltmesi) ──
      //
      // Bu bildirim KARŞI TARAFA gider ve karşı taraf HER İKİ ROL DE
      // olabilir: iletişimi hizmet veren açtıysa ilan sahibine,
      // hizmet alan açtıysa hizmet verene gider
      // (`mock_ports`: `actorId == o.providerId ? l.ownerId : o.providerId`).
      //
      // Tek bir hedefe göndermek taraflardan birini daima yanlış
      // ekrana düşürüyordu. Hedef, bildirimi AÇAN kişiye göre değil,
      // OKUYAN kişiye göre seçilir.
      //
      // ⚠ `refId` TEKLİF id'sidir; ilan id'si teklif üzerinden
      // bulunur. Teklif ya da ilan okunamazsa hiçbir yere gidilmez —
      // yanlış ekran açmaktansa bildirim sessiz kalır.
      case NotifType.contactOpened:
        if (gecerli) {
          final me = context.read<AuthController>().currentAccount;
          final teklif = context.read<OfferController>().byId(ilan);
          final l = teklif == null
              ? null
              : context.read<ListingController>().byId(teklif.listingId);
          if (me != null && l != null) {
            Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => l.ownerId == me.id
                        // Okuyan ilan sahibi → kendi ilan ekranı.
                        ? ListingDetailScreen(listingId: l.id)
                        // Okuyan hizmet veren → kendi iş ekranı.
                        : JobDetailScreen(listingId: l.id)));
          }
        }

      // ── DOĞRUDAN TEKLİF TALEBİ DETAYINA ──
      //
      // Tüm "Doğrudan Teklif İste" bildirimleri AYNI detay ekranına
      // gider; ekran ROL FARKINDA (bkz. `TeklifTalebiDetayScreen`),
      // hangi tarafa gittiğine bakılmaksızın doğru görünümü çizer.
      // ── ⚠ BUL AKIŞINDA MESAJ DA DOĞRUDAN SOHBETE (12 Eyl) ──
      //
      // Aynı kural: mesaj bildirimi mesajlaşma ekranını açar, detay
      // ekranını değil.
      //
      // ⚠ BAŞLIK ÇAĞIRANDAN GELİR (`TeklifTalebiSohbetScreen` bu
      // kararı vermez). Talep okunamazsa ekran açılmaz — uydurma bir
      // başlıkla boş sohbet açmaktansa bildirim sessiz kalır.
      case NotifType.teklifYeniMesaj:
        if (gecerli) {
          final talep =
              context.read<TeklifTalebiController>().byId(ilan);
          if (talep != null) {
            Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => TeklifTalebiSohbetScreen(
                        talepId: ilan, baslik: talep.hizmet)));
          }
        }

      case NotifType.teklifTalebiGeldi:
      case NotifType.teklifVerildi:
      case NotifType.teklifSecildi:
      case NotifType.teklifReddedildi:
      case NotifType.teklifSuresiDoldu:
      case NotifType.teklifIsiTamamlandi:
        if (gecerli) {
          Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => TeklifTalebiDetayScreen(talepId: ilan)));
        }

      case NotifType.refund:
      case NotifType.listingExpired:
      case NotifType.unknown:
        break;
    }
  }

  String _zaman(DateTime d) {
    final f = DateTime.now().difference(d);
    if (f.inMinutes < 60) {
      return '${f.inMinutes} dk';
    }
    if (f.inHours < 24) {
      return '${f.inHours} sa';
    }
    return '${f.inDays} g';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    final ctl = context.watch<NotificationController>();
    // ── ⚠ AKTİF ROLE GÖRE SÜZME (kullanıcı kuralı, 9 Eyl) ──
    //
    // "Rol değiştirince diğer rolüne ait bildirimleri görmemeli."
    //
    // Aynı kişi iki rolde de AYNI hesabı kullanır (kimlik telefon
    // ya da e-posta değil, değişmeyen `userId`), bu yüzden
    // `forUser(me.id)` iki rolün bildirimlerini birlikte döndürür.
    // Hangi türün hangi role ait olduğu `domain/bildirim_rolu.dart`
    // içinde TEK yerde tanımlı; bu ekran kendi listesini SÜZMEZ,
    // oradan geçirir.
    final rol = auth.activeRole;
    final liste = me == null
        ? const <AppNotification>[]
        : rolBildirimleri(ctl.forUser(me.id), rol);
    // ⚠ SAYI DA SÜZÜLÜR: ham sayı gösterilseydi "3 okunmamış" yazıp
    // listede hiçbiri görünmeyebilirdi.
    final okunmamis = liste.where((n) => !n.read).length;

    return RefShell(
      nav: RefBottomNav(
        activeKey: 'bildirim',
        items: custNavItems(
          context,
          saglayici: auth.activeRole == Role.provider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .nt-top{margin-bottom:14px}
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bildirimler',
                    style: refText(
                      size: RF.s25,
                      weight: RF.w700,
                      color: RC.text,
                      letterSpacing: RF.lsM03,
                    ),
                  ),
                ),
                const SizedBox(width: 10), // gap:10px
                // .nt-readall — okunmamış varken anlamlıdır.
                if (okunmamis > 0)
                  RefTap(
                    // ── ⚠ YALNIZ GÖRÜNENLER OKUNDU İŞARETLENİR ──
                    //
                    // `markAllRead(userId)` hesabın TÜM bildirimlerini
                    // okundu yapar — karşı rolünkileri de. Kullanıcı
                    // hizmet alan rolünde "Tümünü Okundu Yap"a
                    // bastığında, hiç görmediği hizmet veren
                    // bildirimleri de sessizce okunmuş sayılırdı; rol
                    // değiştirdiğinde onlardan haberi olmazdı.
                    //
                    // ⚠ BU YÜZDEN TEK TEK: ekranda görünen okunmamış
                    // bildirimler `markRead` ile işaretlenir. Liste
                    // zaten role göre süzülmüş durumda.
                    //
                    // ⚠ BACKEND İŞİ (yapılmadı): sunucuda role göre
                    // toplu işaretleyen bir uç yok. Uç eklenirse bu
                    // döngü tek çağrıya iner; davranış sözleşmesi
                    // aynı kalır.
                    onTap: () {
                      final ctl = context.read<NotificationController>();
                      for (final n in liste.where((n) => !n.read)) {
                        ctl.markRead(n.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(RR.r8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Tümünü Okundu Yap',
                        style: refText(
                            size: RF.s135, weight: RF.w700, color: RC.blue),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── ⚠ HATA YALNIZ GERÇEKTEN OLUNCA ──
          //
          // Sıra önemli: BAŞARISIZ İSTEK önce, BOŞ LİSTE sonra.
          // "Bildiriminiz yok" ile "bildirimler yüklenemedi" ayrı
          // şeylerdir; ikincisinde kullanıcı tekrar deneyebilmeli.
          if (hataGosterilsinMi(
              yukleniyor: ctl.loading,
              hata: ctl.lastError,
              veriVar: liste.isNotEmpty))
            HataTamEkran(hata: ctl.lastError!, onTekrar: _refresh)
          // .nt-list{gap:10px}
          else if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Henüz bildiriminiz yok.',
                textAlign: TextAlign.center,
                style: refText(
                    size: RF.s14, weight: RF.w400, color: RC.greyLight),
              ),
            )
          else
            for (final n in liste) ...[
              _BildirimKarti(
                bildirim: n,
                zaman: _zaman(n.createdAt),
                gorunum: _gorunum(n.type),
                onTap: () {
                  context.read<NotificationController>().markRead(n.id);
                  _openTarget(context, n.type, n.refId);
                },
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// `.nt-card` — tek bildirim.
class _BildirimKarti extends StatelessWidget {
  const _BildirimKarti({
    required this.bildirim,
    required this.zaman,
    required this.gorunum,
    required this.onTap,
  });

  final AppNotification bildirim;
  final String zaman;
  final (String, Color, Color) gorunum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (asset, zemin, renk) = gorunum;
    final okunmamis = !bildirim.read;

    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r14),
      child: Container(
        // .nt-card{padding:13px 13px 13px 22px}
        padding: const EdgeInsets.fromLTRB(22, 13, 13, 13),
        decoration: BoxDecoration(
          // .nt-card.un{background:#F3F8FF}
          color: okunmamis ? const Color(0xFFF3F8FF) : RC.white,
          borderRadius: BorderRadius.circular(RR.r14),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // .nt-ic{46×46; radius:12px}
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: zemin,
                    borderRadius: BorderRadius.circular(RR.r12),
                  ),
                  child: RefSvg(asset, size: 22, color: renk),
                ),
                const SizedBox(width: 12), // gap:12px
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // .nt-head
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              bildirim.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: refText(
                                  size: RF.s145,
                                  weight: RF.w700,
                                  color: RC.text),
                            ),
                          ),
                          const SizedBox(width: 8), // gap:8px
                          Text(
                            zaman,
                            style: refText(
                                size: RF.s115,
                                weight: RF.w400,
                                color: RC.greyLight),
                          ),
                        ],
                      ),
                      // .nt-d{margin-top:3px}
                      const SizedBox(height: 3),
                      Text(
                        bildirim.body,
                        style: refText(
                          size: RF.s125,
                          weight: RF.w400,
                          color: RC.textSoft,
                          height: RF.lh150,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // .nt-dot{left:7px; top:50%; 10×10; halka 3px}
            // Kap zaten 22px sol dolgulu olduğundan nokta -15px'te durur.
            if (okunmamis)
              Positioned(
                left: -15,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: RC.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: RC.blue.withValues(alpha: 0.18),
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
