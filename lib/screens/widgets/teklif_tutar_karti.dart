import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/tutar_bicimi.dart';
import '../../ui/ref_tokens.dart';

/// ── ⚠ TEKLİF TUTARI KARTI — TEK ÇİZİM ──
///
/// KULLANICI İSTEĞİ (9 Eyl): "Fiyat yazan yer Teklif olarak
/// değiştirilsin. Teklif yazısı ve verilen fiyat daha belirgin,
/// modern, göze hitap edecek şekilde yapılsın."
///
/// ⚠ ÖNCEDEN İKİ YERDE AYRI AYRI ÇİZİLİYORDU: hizmet verenin
/// gönderdiği teklif ve hizmet alanın gördüğü teklif. İkisi de
/// "Fiyat" başlığı + düz metin biçimindeydi; biri değişse öteki
/// eskide kalırdı.
///
/// ⚠ "Fiyat" DEĞİL "Teklif": ekranda gösterilen şey bir fiyat
/// etiketi değil, verilmiş bir TEKLİFTİR. Alanın adı da onu söyler.
///
/// ⚠ TUTAR BİÇİMİ BURADA KURULMAZ: binlik ayracı ve "TL"
/// `core/tutar_bicimi.dart`tan gelir.
class TeklifTutarKarti extends StatelessWidget {
  const TeklifTutarKarti(this.tutar, {super.key});

  final int tutar;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          // ⚠ YENİ RENK ÜRETİLMEDİ: `RC.blueSoft` uygulamanın vurgu
          // zemini, kenarlık `RC.blue` — ikisi de palette var.
          color: RC.blueSoft,
          borderRadius: BorderRadius.circular(RR.r14),
          border: Border.all(color: RC.blue.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Teklif',
                style: refText(
                    size: RF.s125, weight: RF.w500, color: RC.blue)),
            const SizedBox(height: 2),
            // ⚠ BÜYÜK VE TEK SATIR: tutar kartın ana bilgisi. 26
            // punto w700 — pubspec'te Poppins 700 VAR, sentezlenmez.
            Text(tutarMetni(tutar),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: refText(
                    size: 26,
                    weight: RF.w700,
                    color: RC.text,
                    letterSpacing: -0.4)),
          ],
        ),
      );
}
