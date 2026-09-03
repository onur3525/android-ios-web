import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_talebi_detay_screen.dart';

/// "TEKLİF İSTEDİKLERİM" (Aşama C) — hizmet alanın "Bul" akışından
/// gönderdiği doğrudan teklif taleplerinin listesi.
///
/// ⚠ MEVCUT "İlanlarım" (`MyListingsScreen`) İLE KARIŞTIRILMAZ: o
/// ekran HERKESE AÇIK ilanları listeler; bu ekran yalnız belirli bir
/// hizmet verene ÖZEL gönderilen talepleri listeler. İki liste ayrı
/// kalır — `MyListingsScreen`'e DOKUNULMADI.
class TeklifIstediklerimScreen extends StatelessWidget {
  const TeklifIstediklerimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentAccount;
    final talepler = me == null
        ? const <TeklifTalebi>[]
        : context.watch<TeklifTalebiController>().byHizmetAlan(me.id);

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
            Expanded(
              child: talepler.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Henüz kimseden teklif istemedin.\n"Bul" '
                          'üzerinden bir hizmet veren seçip teklif '
                          'isteyebilirsin.',
                          textAlign: TextAlign.center,
                          style: refText(
                              size: RF.s14,
                              weight: RF.w400,
                              color: RC.textSoft),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                      itemCount: talepler.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _TalepKarti(talep: talepler[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalepKarti extends StatelessWidget {
  const _TalepKarti({required this.talep});

  final TeklifTalebi talep;

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(talep.hizmet,
                style:
                    refText(size: RF.s145, weight: RF.w700, color: RC.text)),
            const SizedBox(height: 4),
            // ⚠ TEKLİF VERİLENE KADAR MASKELİ — hizmet veren teklif
            // verdiği an (`teklifTarihi` dolar) gerçek ad görünür.
            Row(
              children: [
                talep.teklifTarihi != null
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: FittedBox(
                            child: RefBasHarfAvatar(ad: talep.saglayiciAdi)))
                    : const RefSvg('assets/svg/ic_avlock.svg', size: 20),
                const SizedBox(width: 6),
                Text(
                    talep.teklifTarihi != null
                        ? talep.saglayiciAdi
                        : maskeliAd(talep.saglayiciAdi),
                    style: refText(
                        size: RF.s13, weight: RF.w500, color: RC.textSoft)),
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
