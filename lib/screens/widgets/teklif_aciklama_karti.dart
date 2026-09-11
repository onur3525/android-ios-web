import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/ref_tokens.dart';

/// ── ⚠ TEKLİF AÇIKLAMASI KARTI — TEK ÇİZİM ──
///
/// KULLANICI İSTEĞİ (10 Eyl): "Hizmet veren teklif verirken bir
/// açıklama yazdıysa bu düz metin gibi olmamalı; bir kart içinde daha
/// şık bir düzen ve yazı ile yazılmalı. Başlık ortalanmalı. Karşı
/// tarafta da aynı görünmeli."
///
/// ⚠ ÖNCEDEN İKİ YERDE AYRI AYRI ÇİZİLİYORDU: hizmet verenin gördüğü
/// "Açıklamanız" ve hizmet alanın gördüğü "Hizmet Verenin Açıklaması"
/// — ikisi de küçük gri başlık + düz metindi, çerçevesizdi. Biri
/// değişse öteki eskide kalırdı.
///
/// ⚠ BAŞLIK METNİ DIŞARIDAN GELİR, GÖRÜNÜM BURADA: iki taraf aynı
/// şeye kendi açısından bakıyor ("Açıklamanız" / "Hizmet Verenin
/// Açıklaması"), ama KART aynı. Başlığı da sabitlemek, hizmet verene
/// kendi yazdığı metni "Hizmet Verenin Açıklaması" diye
/// okutmak olurdu.
///
/// ⚠ BAŞLIK ORTALI, METİN SOLA YASLI: başlık kısa bir etikettir,
/// ortalanınca kartın dengesini kurar. Açıklama ise birkaç cümle
/// olabilir; ortalanmış uzun metin satır başları kaydığı için zor
/// okunur.
///
/// ⚠ BOŞ AÇIKLAMADA ÇAĞRILMAZ: cevap yazmak zorunlu değildir
/// (kullanıcı kararı, 10 Eyl). Çağıran taraf metnin dolu olduğunu
/// denetler; bu kart boş bir kutu çizmez.
class TeklifAciklamaKarti extends StatelessWidget {
  const TeklifAciklamaKarti({
    super.key,
    required this.baslik,
    required this.metin,
  });

  final String baslik;
  final String metin;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: RC.white,
          borderRadius: BorderRadius.circular(RR.r14),
          border: Border.all(color: const Color(0xFFECEEF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(baslik,
                textAlign: TextAlign.center,
                style: refText(
                    size: RF.s125, weight: RF.w500, color: RC.textSoft)),
            const SizedBox(height: 7),
            Text(metin,
                style: refText(
                    size: RF.s14,
                    weight: RF.w400,
                    color: RC.text,
                    height: RF.lh155)),
          ],
        ),
      );
}
