import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_talebi_detay_screen.dart';

/// "TEKLİF İSTEDİKLERİM" (Aşama C) — hizmet alanın "Bul" akışından
/// gönderdiği doğrudan teklif taleplerinin BAĞIMSIZ ekranı.
///
/// ⚠ ARTIK "Bul" akışının BAŞ ekranında (`find_provider_screen.dart`)
/// da AYNI liste GÖMÜLÜ olarak gösteriliyor (bkz.
/// `TeklifIstediklerimListesi` altta) — bu bağımsız Scaffold'lu hâl
/// SİLİNMEDİ çünkü `teklif_iste_screen.dart` bir talep gönderildikten
/// SONRA hâlâ BURAYA yönlendiriyor (onay + tam liste). İki KULLANIM
/// YERİ, TEK liste mantığını (`TeklifIstediklerimListesi`) paylaşır —
/// kod tekrarı YOK.
///
/// ⚠ MEVCUT "İlanlarım" (`MyListingsScreen`) İLE KARIŞTIRILMAZ: o
/// ekran HERKESE AÇIK ilanları listeler; bu ekran yalnız belirli bir
/// hizmet verene ÖZEL gönderilen talepleri listeler. İki liste ayrı
/// kalır — `MyListingsScreen`'e DOKUNULMADI.
class TeklifIstediklerimScreen extends StatelessWidget {
  const TeklifIstediklerimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  const RefBackButton(),
                  const SizedBox(width: 8),
                  Text('Teklif İstediklerim',
                      style: refText(
                          size: RF.s18, weight: RF.w700, color: RC.text)),
                ],
              ),
            ),
            const Expanded(child: TeklifIstediklerimListesi()),
          ],
        ),
      ),
    );
  }
}

/// ── ⚠ LİSTE GÖVDESİ — HEM BAĞIMSIZ EKRANDA HEM "Bul" AKIŞININ BAŞ
/// EKRANINDA GÖMÜLÜ KULLANILIR ──
///
/// Scaffold/başlık İÇERMEZ — yalnız boş-durum metni + kart listesi.
/// `find_provider_screen.dart`, "Ara" düğmesinin ALTINDA bunu
/// DOĞRUDAN gömer; talep sayısı azsa doğal olarak kısa kalır,
/// `Column` içinde `shrinkWrap` bir `ListView` kullanılır.
class TeklifIstediklerimListesi extends StatelessWidget {
  const TeklifIstediklerimListesi({super.key, this.gomulu = false});

  /// ⚠ `true` iken bu widget kendi kaydırma alanı AÇMAZ
  /// (`shrinkWrap: true`, `NeverScrollableScrollPhysics`) — çağıran
  /// (ör. `find_provider_screen.dart`) zaten kaydırılabilir tek bir
  /// `ListView` içinde olduğu için, İÇ İÇE kaydırma çakışmaz.
  final bool gomulu;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentAccount;
    final talepler = me == null
        ? const <TeklifTalebi>[]
        : context.watch<TeklifTalebiController>().byHizmetAlan(me.id);

    if (talepler.isEmpty) {
      return gomulu
          ? const SizedBox.shrink()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Henüz kimseden teklif istemedin.\n"Bul" '
                  'üzerinden bir hizmet veren seçip teklif '
                  'isteyebilirsin.',
                  textAlign: TextAlign.center,
                  style: refText(
                      size: RF.s14, weight: RF.w400, color: RC.textSoft),
                ),
              ),
            );
    }

    return ListView.separated(
      shrinkWrap: gomulu,
      physics: gomulu ? const NeverScrollableScrollPhysics() : null,
      padding: gomulu
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: talepler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TalepKarti(talep: talepler[i]),
    );
  }
}

class _TalepKarti extends StatelessWidget {
  const _TalepKarti({required this.talep});

  final TeklifTalebi talep;

  @override
  Widget build(BuildContext context) {
    final (metin, renk) = _durumGoster(talep.durum);
    // ⚠ EKLENDİ — kullanıcı bulgusu: bu kart yalnız maskeli ad
    // gösteriyordu. `teklif_iste_screen.dart`/`teklif_talebi_detay_
    // screen.dart`daki AYNI hizmet veren kartı (puan, yorum sayısı,
    // tamamlanan iş, konum) — istatistikler kimlik maskeliyken bile
    // gösterilir, o ekranlardaki AYNI ilke.
    final acik = talep.teklifTarihi != null;
    final reviews = context.watch<ReviewController>();
    final puan = reviews.averageOf(talep.saglayiciId);
    final yorumlar = reviews.byProvider(talep.saglayiciId);
    final tamamlanan = _tamamlananIsGercek(context, talep.saglayiciId);
    final hesap =
        context.read<AuthController>().accountById(talep.saglayiciId);
    final konum = hesap == null || hesap.serviceDistricts.isEmpty
        ? null
        : '${hesap.serviceDistricts.first} / ${hesap.address?.city ?? ''}';
    return RefTap(
      onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
              builder: (_) => TeklifTalebiDetayScreen(talepId: talep.id))),
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: const Color(0xFFECEEF2)),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(talep.hizmet,
                style:
                    refText(size: RF.s145, weight: RF.w700, color: RC.text)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                acik
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: FittedBox(
                            child: RefBasHarfAvatar(ad: talep.saglayiciAdi)))
                    : const RefSvg('assets/svg/ic_avlock.svg', size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acik ? talep.saglayiciAdi : maskeliAd(talep.saglayiciAdi),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: refText(
                              size: RF.s14, weight: RF.w700, color: RC.text)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const RefSvg('assets/svg/ic_starfill.svg',
                              size: 13, color: Color(0xFFF5A319)),
                          const SizedBox(width: 4),
                          Text(puan == null ? '—' : puan.toStringAsFixed(1),
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w700,
                                  color: RC.text)),
                          const SizedBox(width: 4),
                          Text('(${yorumlar.length} yorum)',
                              style: refText(
                                  size: RF.s115,
                                  weight: RF.w400,
                                  color: RC.textSoft)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const RefSvg('assets/svg/ic_briefcase.svg',
                              size: 12, color: Color(0xFF5B6472)),
                          const SizedBox(width: 4),
                          Text('$tamamlanan iş tamamladı',
                              style: refText(
                                  size: RF.s115,
                                  weight: RF.w400,
                                  color: const Color(0xFF5B6472))),
                        ],
                      ),
                      if (konum != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const RefSvg('assets/svg/ic_pin.svg',
                                size: 13, color: Color(0xFF98A2B3)),
                            const SizedBox(width: 4),
                            Text(konum,
                                style: refText(
                                    size: RF.s115,
                                    weight: RF.w400,
                                    color: const Color(0xFF98A2B3))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(RR.r13),
              ),
              child: Text(metin,
                  style: refText(size: RF.s12, weight: RF.w700, color: renk)),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _durumGoster(TeklifTalebiDurumu d) => switch (d) {
        TeklifTalebiDurumu.beklemede => ('Teklif bekleniyor', RC.blue),
        TeklifTalebiDurumu.teklifGeldi => ('Teklif geldi', HC.green),
        TeklifTalebiDurumu.secildi => ('İş aktif', HC.green),
        TeklifTalebiDurumu.reddedildi => ('Reddedildi', HC.grey),
        TeklifTalebiDurumu.suresiDoldu => ('Süresi doldu', HC.grey),
        TeklifTalebiDurumu.tamamlandi => ('İş tamamlandı', RC.blue),
      };
}

/// ⚠ `teklif_iste_screen.dart`/`teklif_talebi_detay_screen.dart`daki
/// AYNI hesaplama — üçüncü bir kopya değil, bu dosyalar birbirinden
/// PRIVATE (import edilemez) olduğu için AYNI mantık burada da
/// tekrarlanıyor.
int _tamamlananIsGercek(BuildContext c, String providerId) {
  final ilanlar = c.read<ListingController>().all;
  final teklifler = c.read<OfferController>();
  var n = 0;
  for (final l in ilanlar) {
    if (!l.isTamamlanmisIs) {
      continue;
    }
    final secili = teklifler
        .offersForListing(l.id)
        .where((o) => o.id == l.selectedOfferId);
    if (secili.isNotEmpty && secili.first.providerId == providerId) {
      n++;
    }
  }
  return n;
}
