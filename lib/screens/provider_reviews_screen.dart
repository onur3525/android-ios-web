import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/models/review.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// BİR HİZMET VERENİN ALDIĞI YORUMLAR — HERKESE AÇIK, SALT-OKUNUR.
///
/// ⚠ MEVCUT `MyReviewsScreen` İLE KARIŞTIRILMAZ: o ekran parametre
/// ALMAZ, HER ZAMAN giriş yapmış hizmet verenin KENDİ yorumlarını
/// gösterir (üç yerde `currentAccount`a sıkı bağlı). Bu ekran ise
/// BAŞKA BİR hesabın (`providerId`) yorumlarını, herhangi bir
/// kullanıcı ("Bul" akışında teklif bekleyen bir hizmet alan gibi)
/// görüntüleyebilsin diye AYRI kuruldu — `MyReviewsScreen`e
/// DOKUNULMADI.
///
/// ⚠ Aynı `ReviewController.byProvider` kaynağını okur — ayrı bir
/// veri yolu İCAT EDİLMEDİ.
class ProviderReviewsScreen extends StatelessWidget {
  const ProviderReviewsScreen({
    super.key,
    required this.providerId,
    required this.providerAdi,
  });

  final String providerId;
  final String providerAdi;

  @override
  Widget build(BuildContext context) {
    final reviews = context.watch<ReviewController>();
    final yorumlar = reviews.byProvider(providerId);
    final ortalama = reviews.averageOf(providerId);
    final auth = context.watch<AuthController>();

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
                  Expanded(
                    child: Text('$providerAdi — Yorumlar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s18, weight: RF.w700, color: RC.text)),
                  ),
                ],
              ),
            ),
            if (ortalama != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: RefSvg(
                            i <= ortalama.round()
                                ? 'assets/svg/ic_starfill.svg'
                                : 'assets/svg/ic_starempty.svg',
                            size: 16,
                            color: const Color(0xFFF5A319)),
                      ),
                    const SizedBox(width: 6),
                    Text('$ortalama · ${yorumlar.length} değerlendirme',
                        style: refText(
                            size: RF.s135,
                            weight: RF.w600,
                            color: RC.textSoft)),
                  ],
                ),
              ),
            Expanded(
              child: yorumlar.isEmpty
                  ? Center(
                      child: Text('Bu hizmet veren için henüz yorum yok.',
                          style: refText(
                              size: RF.s14,
                              weight: RF.w400,
                              color: RC.textSoft)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                      itemCount: yorumlar.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = yorumlar[i];
                        final yazar = auth.accountById(r.authorId);
                        return _YorumKarti(review: r, yazarAdi: yazar?.name);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YorumKarti extends StatelessWidget {
  const _YorumKarti({required this.review, required this.yazarAdi});

  final Review review;
  final String? yazarAdi;

  @override
  Widget build(BuildContext context) {
    final ad = (yazarAdi == null || yazarAdi!.isEmpty)
        ? 'Hizmet Alan'
        : yazarAdi!;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: RC.border),
        borderRadius: BorderRadius.circular(RR.r14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RefBasHarfAvatar(ad: ad),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ad,
                        style: refText(
                            size: RF.s14, weight: RF.w700, color: RC.text)),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          RefSvg(
                              i <= review.stars
                                  ? 'assets/svg/ic_starfill.svg'
                                  : 'assets/svg/ic_starempty.svg',
                              size: 12,
                              color: const Color(0xFFF5A319)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.text,
                style: refText(
                    size: RF.s135, weight: RF.w400, color: RC.text)),
          ],
        ],
      ),
    );
  }
}
