import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/account.dart';
import '../data/models/teklif_talebi.dart';
import '../domain/teklif_talebi_asamasi.dart';
import 'widgets/yeni_mesaj_seridi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_talebi_detay_screen.dart';

/// "TEKLİF İSTEKLERİ" — hizmet verene "Bul" akışından doğrudan
/// gönderilen taleplerin liste GÖVDESİ.
///
/// ⚠ ARTIK KENDİ BAŞINA BİR EKRAN DEĞİL: bu içerik `JobsScreen`
/// ("İşlerim") içine ÜÇÜNCÜ SEKME olarak gömülür (bkz.
/// `jobs_screen.dart`) — konteyner ekran DEĞİŞMEDİ (ürün kararı).
/// Bu yüzden `Scaffold`/geri düğmesi/başlık İÇERMEZ; yalnız gövde.
///
/// ⚠ ARAMA ÇUBUĞU / "Ara" DÜĞMESİ YOK (ürün kararı) — bu ekranda
/// yalnız gelen teklif istekleri kartları listelenir; karta
/// girilip teklif verilir. Önceden "Hizmet Veren Bul" ekranıyla
/// aynı görsel dilde bir arama alanı vardı, KALDIRILDI.
///
/// ⚠ MEVCUT "İşlerim" (`JobsScreen`) İLE KARIŞTIRILMAZ: o ekran
/// HERKESE AÇIK ilanları listeler; bu liste yalnız belirli bu
/// hizmet verene ÖZEL gönderilen talepleri gösterir.
class TeklifIstekleriListesi extends StatelessWidget {
  const TeklifIstekleriListesi({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    // ⚠ DÜZELTİLDİ — kullanıcı bulgusu: hizmet alan teklifi
    // SEÇTİĞİNDE (`secildi`) talep bu listede KALMAYA devam
    // ediyordu; artık "Kazandığım" bölümüne TAŞINIYOR (bkz.
    // `jobs_screen.dart`), bu yüzden burada GÖSTERİLMEZ.
    final talepler = me == null
        ? const <TeklifTalebi>[]
        : context
            .watch<TeklifTalebiController>()
            .bySaglayici(me.id)
            // ── ⚠ YALNIZ SÜREN TALEPLER (kullanıcı kuralı, 9 Eyl) ──
            //
            // ÖNCEDEN `!= secildi` idi. Ama seçim anında akış
            // `secToVer` ardından `tamamla` çağırıyor, yani durum
            // `tamamlandi` oluyordu — kart bu listede KALIYORDU.
            // Tek bir durumu dışlamak yetmez; aşama kuralı tek
            // yerden gelir.
            .where((t) => talepSurenMi(t.durum))
            .toList();

    if (talepler.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz doğrudan bir teklif talebiniz yok.',
            textAlign: TextAlign.center,
            style: refText(size: RF.s14, weight: RF.w400, color: RC.textSoft),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: talepler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TalepKarti(
        talep: talepler[i],
        hizmetAlan: auth.accountById(talepler[i].hizmetAlanId),
      ),
    );
  }
}

class _TalepKarti extends StatelessWidget {
  const _TalepKarti({required this.talep, required this.hizmetAlan});

  final TeklifTalebi talep;

  /// ⚠ NULL OLABİLİR: hesap silinmiş/bulunamıyor olabilir — bu
  /// durumda istatistikler ve ad "bilinmiyor" gösterilir, ekran
  /// ÇÖKMEZ.
  final Account? hizmetAlan;

  @override
  Widget build(BuildContext context) {
    final acik = talep.teklifTarihi != null;
    final hizmetAlanAdi = hizmetAlan?.name ?? 'Hizmet Alan';
    final (metin, renk) = _durumGoster(talep.durum);

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FOTOĞRAF — TEKLİF VERİLENE KADAR BUZLU ──
            acik
                ? RefBasHarfAvatar(ad: hizmetAlanAdi)
                : const RefSvg('assets/svg/ic_avlock.svg', size: 44),
            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AD SOYAD — MASKELİ ──
                  Text(acik ? hizmetAlanAdi : maskeliAd(hizmetAlanAdi),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s145, weight: RF.w700, color: RC.text)),
                  const SizedBox(height: 3),

                  // ── İSTEDİĞİ HİZMET ──
                  Text(talep.hizmet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s13, weight: RF.w500, color: RC.textSoft)),
                  const SizedBox(height: 6),

                  // ── KAÇ İŞ BİTİRDİĞİ ──
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_briefcase.svg',
                          size: 13, color: Color(0xFF5B6472)),
                      const SizedBox(width: 5),
                      Text(
                          '${_tamamlananIs(context, talep.hizmetAlanId)} iş '
                          'tamamladı',
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: const Color(0xFF5B6472))),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // ── KAÇ YILDIR ÜYE ──
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_clock.svg',
                          size: 13, color: Color(0xFF98A2B3)),
                      const SizedBox(width: 5),
                      Text(_uyelikSuresi(hizmetAlan?.kayitTarihi),
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: const Color(0xFF98A2B3))),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ⚠ DURUM VE YENİ MESAJ YAN YANA: ikisi de kartın
                  // "şu an ne oluyor" bilgisi. Alt alta konsaydı kart
                  // uzar, liste seyrekleşirdi.
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(RR.r13),
                        ),
                        child: Text(metin,
                            style: refText(
                                size: RF.s12, weight: RF.w700, color: renk)),
                      ),
                      // ── ⚠ YENİ MESAJ (kullanıcı isteği, 9 Eyl) ──
                      //
                      // ⚠ İZLEYEN BU EKRANDA DAİMA HİZMET VERENDİR;
                      // okunmamış sayısı ONUN gözünden hesaplanır.
                      // Sayım `okunmamisMesajSayisi` ile TEK yerde.
                      if (okunmamisMesajSayisi(talep, talep.saglayiciId) >
                          0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: YeniMesajSeridi(okunmamisMesajSayisi(
                              talep, talep.saglayiciId)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠ HİZMET ALANIN kaç işi tamamlandı — `offer_detail_screen.dart`
  /// içindeki `_tamamlananIs` (PROVIDER için) ile AYNI mantık, yalnız
  /// yön TERS: burada ilan SAHİBİNİN (`ownerId`) kaç ilanı
  /// tamamlanmış sayılıyor.
  int _tamamlananIs(BuildContext c, String hizmetAlanId) {
    final ilanlar = c.read<ListingController>().all;
    return ilanlar
        .where((l) => l.ownerId == hizmetAlanId && l.isTamamlanmisIs)
        .length;
  }

  /// ⚠ GERÇEK KAYIT TARİHİNDEN — uydurma bir süre DEĞİLDİR.
  String _uyelikSuresi(DateTime? kayitTarihi) {
    if (kayitTarihi == null) {
      return 'Üyelik süresi bilinmiyor';
    }
    final yil = DateTime.now().difference(kayitTarihi).inDays ~/ 365;
    if (yil < 1) {
      return 'Yeni üye';
    }
    return '$yil yıldır üye';
  }

  (String, Color) _durumGoster(TeklifTalebiDurumu d) => switch (d) {
        TeklifTalebiDurumu.beklemede => ('Yanıt bekliyor', RC.blue),
        TeklifTalebiDurumu.teklifGeldi => ('Teklif verildi', HC.green),
        TeklifTalebiDurumu.secildi => ('İş aktif', HC.green),
        TeklifTalebiDurumu.reddedildi => ('Reddedildi', HC.grey),
        TeklifTalebiDurumu.suresiDoldu => ('Süresi doldu', HC.grey),
        TeklifTalebiDurumu.tamamlandi => ('İş tamamlandı', RC.blue),
      };
}
