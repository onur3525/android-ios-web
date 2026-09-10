import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/models/review.dart';
import '../domain/yorum_gorunumu.dart';
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
                        return YorumKarti(review: r, yazarAdi: yazar?.name);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── ⚠ GENEL (PUBLIC) — `teklif_iste_screen.dart`da da kullanılır ──
///
/// Önceden bu dosyaya özeldi (`_YorumKarti`); "Teklif İste" ekranında
/// hizmet verenin SON 5 yorumunu göstermek için de AYNI kart
/// gerektiği için genele açıldı — ikinci bir kart tasarımı İCAT
/// EDİLMEDİ.
/// ── ⚠ YORUM KARTI (kullanıcı kuralları, 9 Eyl) ──
///
/// Yapı:
///
///     Gönül B.                                    10.09.2026
///     Doğalgaz Tesisatı
///     ★★★★★
///     Çok iyi iş çıkardılar
///                                                      Göster
///
/// ⚠ DEĞİŞENLER VE NEDENLERİ:
///   • PROFİL FOTOĞRAFI KALDIRILDI — `RefBasHarfAvatar` çiziliyordu.
///   • AD KISALTILDI — "Gönül Bütün" değil "Gönül B."; soyad hiçbir
///     şekilde görünmez (`kisaYazarAdi`).
///   • TARİH sağ üst köşeye eklendi (gün.ay.yıl).
///   • ALINAN HİZMET adın altına eklendi; yorumun neye dair olduğu
///     kartta görünmüyordu.
///   • UZUN YORUM kartı büyütmesin diye kapalı açılır; "Göster" /
///     "Küçült" ile açılıp kapanır.
///
/// ⚠ KURALLAR BURADA DEĞİL `domain/yorum_gorunumu.dart`TA: ad
/// kısaltma, tarih biçimi, hizmet adı çözümü ve uzunluk eşiği tek
/// yerde tanımlı. Kart yalnız çizer.
///
/// ⚠ TEK KART, ÜÇ EKRAN: bu bileşen `provider_reviews_screen`,
/// `teklif_iste_screen` ve `teklif_talebi_detay_screen` tarafından
/// kullanılır — biri değişince üçü birden değişir.
class YorumKarti extends StatefulWidget {
  const YorumKarti({super.key, required this.review, required this.yazarAdi});

  final Review review;
  final String? yazarAdi;

  @override
  State<YorumKarti> createState() => _YorumKartiState();
}

class _YorumKartiState extends State<YorumKarti> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final ad = (widget.yazarAdi == null || widget.yazarAdi!.trim().isEmpty)
        ? 'Hizmet Alan'
        : kisaYazarAdi(widget.yazarAdi!);
    final hizmet = yorumHizmetAdi(context, r);
    final metin = r.text.trim();
    final uzun = uzunYorumMu(metin);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s14, weight: RF.w700, color: RC.text)),
              ),
              const SizedBox(width: 8),
              // ⚠ TARİH SAĞ ÜSTTE: ad uzasa bile kırpılan AD olur,
              // tarih yerinde kalır.
              Text(yorumTarihi(r.createdAt),
                  style: refText(
                      size: RF.s115, weight: RF.w400, color: RC.textMuted)),
            ],
          ),
          // ⚠ HİZMET ADI BULUNAMAZSA SATIR ÇİZİLMEZ — uydurulmaz.
          if (hizmet != null) ...[
            const SizedBox(height: 2),
            Text(hizmet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: refText(
                    size: RF.s12, weight: RF.w400, color: RC.textSoft)),
          ],
          const SizedBox(height: 5),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                RefSvg(
                    i <= r.stars
                        ? 'assets/svg/ic_starfill.svg'
                        : 'assets/svg/ic_starempty.svg',
                    size: 13,
                    color: const Color(0xFFF5A319)),
            ],
          ),
          if (metin.isNotEmpty) ...[
            const SizedBox(height: 8),
            // ⚠ KAPALIYKEN ÜÇ SATIR: kart yüksekliği sabit kalır,
            // liste düzeni bozulmaz. Açıkken sınır YOKTUR.
            Text(metin,
                maxLines: (uzun && !_acik) ? 3 : null,
                overflow: (uzun && !_acik)
                    ? TextOverflow.ellipsis
                    : TextOverflow.clip,
                style: refText(
                    size: RF.s135, weight: RF.w400, color: RC.text)),
            // ⚠ DÜĞME YALNIZ UZUN YORUMDA: kısa yorumda "Göster"
            // göstermek anlamsız bir dokunma hedefi bırakırdı.
            if (uzun)
              Align(
                alignment: Alignment.centerRight,
                child: RefTap(
                  onTap: () => setState(() => _acik = !_acik),
                  borderRadius: BorderRadius.circular(RR.r8),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 8),
                    child: Text(_acik ? 'Küçült' : 'Göster',
                        style: refText(
                            size: RF.s125,
                            weight: RF.w700,
                            color: RC.blue)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
