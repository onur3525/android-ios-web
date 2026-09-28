import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// ── ⚠ PUAN DAĞILIM SATIRI — TEK KAYNAK ──
///
/// KULLANICI BULGUSU (10 Eyl): "Gelen teklif kartlarına girildiğinde
/// yorum grafiği tutarsız ve yıldız verme oranları %'li olarak
/// görünüyor. Burada % değil, kaç kişi kaç yıldız verdiyse karşısına
/// yazılacak. Teklif al ekranlarındaki aynı mantıkta olmalı."
///
/// ⚠ ÖLÇÜLEN İKİ SAPMA — AYNI GRAFİK, İKİ AYRI UYGULAMA:
///
///   • "Genel Puanım" ekranı ADET yazıyordu, dolgu turuncuydu, oran
///     doğrudan uygulanıyordu (0 → boş).
///   • Teklif detayı YÜZDE yazıyordu, dolgu maviydi ve `heightFactor`
///     verilmediği için çubuk HİÇ dolmuyordu — kullanıcının
///     "tutarsız" dediği şey buydu.
///
/// ⚠ YÜZDE YANILTICIYDI: tek yorumu olan bir hizmet veren için "%100"
/// yazıyordu; sayı büyük görünüyor ama arkasında bir kişi var. Adet
/// ham gerçeği söyler.
///
/// ⚠ `heightFactor` ŞART: `FractionallySizedBox` yalnız `widthFactor`
/// ile çocuğa GEVŞEK yükseklik geçirir; `ColoredBox`un kendi ölçüsü
/// olmadığı için yüksekliği sıfır kalır ve dolgu hiçbir oranda
/// görünmez.
///
/// ⚠ TABAN DOLGU YOK: 0 oy → çubuk TAMAMEN boş. Eskiden en az %3
/// dolduruluyordu ve hiç oy almamış yıldız da "az da olsa puan var"
/// gibi görünüyordu.
///
/// ⚠ YILDIZ SARI: uygulamadaki bütün yıldızlar `#F5A319`. Teklif
/// detayında mavi yıldız (`ic_starb`) kullanılıyordu.
class PuanDagilimSatiri extends StatelessWidget {
  const PuanDagilimSatiri({
    super.key,
    required this.yildiz,
    required this.adet,
    required this.toplam,
  });

  final int yildiz;
  final int adet;

  /// Toplam değerlendirme sayısı.
  ///
  /// ⚠ SIFIRA BÖLME KORUMASI: hiç değerlendirme yokken `adet / toplam`
  /// NaN üretir ve `FractionallySizedBox` çöker.
  final int toplam;

  @override
  Widget build(BuildContext context) {
    final oran = toplam == 0 ? 0.0 : adet / toplam;
    return Row(
      children: [
        SizedBox(
          width: 8,
          child: Text('$yildiz',
              textAlign: TextAlign.right,
              style: refText(size: RF.s12, weight: RF.w700, color: RC.text)),
        ),
        const SizedBox(width: 6),
        const RefSvg('assets/svg/ic_starfill.svg',
            size: 13, color: Color(0xFFF5A319)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: [
                  const Positioned.fill(
                      child: ColoredBox(color: Color(0xFFEDF0F4))),
                  FractionallySizedBox(
                    widthFactor: oran,
                    heightFactor: 1,
                    child: const ColoredBox(color: Color(0xFFF5A319)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          // ⚠ ADET, YÜZDE DEĞİL.
          child: Text('$adet',
              textAlign: TextAlign.right,
              style: refText(size: RF.s12, weight: RF.w600, color: RC.text)),
        ),
      ],
    );
  }
}
