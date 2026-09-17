import 'package:flutter/material.dart';

import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// DURUM ŞERİDİ — YEŞİL ZEMİN, TİK, İSTEĞE BAĞLI EYLEM
///
/// ⚠ KULLANICI İSTEĞİ (12 Eyl): "Bul ile seçilen ilanlarda da teklif
/// seçilince, ilan oluşturma ekranındaki yazının aynısı — 'Teklif
/// seçildi' — yazılsın. Yorum yapılınca da '✓ Yorum yapıldı
/// Görüntüle' aynı şekilde uygulanmalı."
///
/// ## NİÇİN ORTAK
///
/// Şerit `offer_detail_screen` içinde `_UcretsizSerit` adıyla
/// PRIVATE duruyordu; Dart'ta başka dosya onu göremez. Bul akışının
/// detay ekranı bu yüzden aynı bilgiyi kendi biçiminde yazıyordu:
/// yeşil "Teklif Seçildi" düz metni, mavi "Yorum yapıldı" yazısı —
/// zemin yok, tik yok, ok yok.
///
/// ⚠ İKİ AKIŞ ARTIK BİREBİR AYNI ŞERİDİ ÇİZER. Üçüncü bir akış
/// eklenirse görünümü kendiliğinden alır.
/// ═══════════════════════════════════════════════════════════════
/// `.pr-free` — yeşil bilgi şeridi (buton altı).
class DurumSeridi extends StatelessWidget {
  const DurumSeridi(this.metin, {this.aksiyon});

  final String metin;

  /// ── ⚠ İKİNCİ SATIR — DOKUNULABİLİRLİĞİ ANLATIR ──
  ///
  /// KULLANICI İSTEĞİ (12 Eyl): "Görüntüle altta kalacak ve dokunarak
  /// ilgili ekrana gideceğini hissettiren bir görüntüle yazılmalı."
  ///
  /// ⚠ ÖNCEDEN TEK SATIRDI ve eylem, durumun içine nokta ile
  /// iliştirilmişti: "Yorum Yapıldı (5 puan) · Görüntüle". Okuyan
  /// kişi bunun bir bilgi mi yoksa düğme mi olduğunu anlamıyordu —
  /// yeşil bir durum şeridi gibi duruyordu.
  ///
  /// ⚠ KONUM DEĞİŞTİ (12 Eyl): kısa süre ALT SATIRDA çizildi, sonra
  /// kullanıcı isteğiyle durumun YANINA alındı. Şerit iki satıra
  /// çıkınca gereğinden çok yer kaplıyordu.
  ///
  /// Altı çizili, daha kalın ve yanında ok ile çizilir; düğme
  /// olduğunu bu üç işaret anlatır, satırın konumu değil.
  ///
  /// ⚠ `null` ise şerit eskisi gibi tek satır kalır — "İletişimi
  /// açmak ücretsizdir." satırı bundan etkilenmez.
  final String? aksiyon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F9EF),
              borderRadius: BorderRadius.circular(RR.r9),
            ),
            // ── ⚠ TEK SATIR: DURUM + EYLEM YAN YANA (12 Eyl,
            // kullanıcı isteği) ──
            //
            // Eylem kısa süre ALT SATIRDA çizildi; şerit iki satıra
            // çıkınca gereğinden çok yer kaplıyor ve ortalanmış
            // hâliyle bir düğme bloğu gibi duruyordu. Kullanıcı
            // "yan yana yazalım" dedi.
            //
            // ⚠ AYRIM YİNE KORUNUYOR: eylem altı çizili, daha kalın
            // ve yanında ok var. Tıklanabilirliği anlatan işaretler
            // satırın konumundan değil, bu üç işaretten geliyor —
            // yan yana olması onu yeniden "durum metninin parçası"
            // hâline getirmez.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RefSvg('assets/svg/ic_okgreen.svg', size: 15),
                const SizedBox(width: 7), // gap:7px
                Flexible(
                  child: Text(metin,
                      style: refText(
                          size: RF.s125,
                          weight: RF.w600,
                          color: const Color(0xFF16A34A))),
                ),
                if (aksiyon != null) ...[
                  const SizedBox(width: 8),
                  Text(aksiyon!,
                      style: refText(
                          size: RF.s125,
                          weight: RF.w700,
                          color: const Color(0xFF16A34A),
                          decoration: TextDecoration.underline)),
                  const SizedBox(width: 4),
                  const RefSvg('assets/svg/ic_chev.svg',
                      size: 14, color: Color(0xFF16A34A)),
                ],
              ],
            ),
          ),
        ),
      );
}
