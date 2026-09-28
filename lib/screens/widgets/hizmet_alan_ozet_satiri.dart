import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/hizmet_alan_ozeti.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// ── ⚠ HİZMET ALAN BİLGİ SATIRI — TEK ÇİZİM ──
///
/// Kullanıcı isteği (9 Eyl): "Kazandığım" listesindeki kart da hizmet
/// alanın bilgilerini taşısın.
///
/// ⚠ ÖNCEDEN BU BİLGİLER YALNIZ DETAY EKRANINDAYDI; liste kartında
/// hizmet adı, "Doğrudan Teklif İsteği", tutar ve "Seçildi"den başka
/// bir şey yoktu. Hizmet veren, kazandığı işin kime ait olduğunu
/// ancak detaya girerek görebiliyordu.
///
/// [maskeli] kimliğin gizli olup olmadığını söyler — teklif verilene
/// kadar iki taraf birbirine maskelidir. Maskelenen YALNIZ kimliktir;
/// konum ve geçmiş iki durumda da gösterilir.
///
/// ⚠ PUAN/YORUM YOKTUR: değerlendirme yalnız hizmet verene yapılır.
/// Buraya yıldız eklenmesi, olmayan bir veriyi varmış gibi gösterirdi.
class HizmetAlanOzetSatiri extends StatelessWidget {
  const HizmetAlanOzetSatiri(this.ozet, {super.key, this.maskeli = true});

  final HizmetAlanOzeti ozet;
  final bool maskeli;

  // ── ⚠ PROFİL FOTOĞRAFI KALDIRILDI (kullanıcı isteği, 10 Eyl) ──
  //
  // Solda 38 px'lik avatar (maskeliyken kilit ikonu, açıkken baş
  // harf) çiziliyordu. Kaldırıldı; yazılar kartın sol kenarından
  // başlıyor.
  //
  // ⚠ `maskeli` PARAMETRESİ KALDI: adın maskelenip maskelenmeyeceğini
  // hâlâ o belirliyor. Yalnız avatar gitti, kimlik kuralı DEĞİL.
  //
  // ⚠ TEK BİLEŞEN, İKİ KART: bu satırı "Kazandığım" ekranındaki iki
  // kart türü de kullanıyor; ikisinde birden avatar kalkar.
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ozet.adSoyad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s14, weight: RF.w700, color: RC.text)),
                if (ozet.konum != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_pin.svg',
                          size: 13, color: Color(0xFF98A2B3)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(ozet.konum!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: refText(
                                size: RF.s115,
                                weight: RF.w400,
                                color: const Color(0xFF98A2B3))),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    // ⚠ ÇANTA: "iş tamamladı" satırlarının ortak ikonu.
                    const RefSvg('assets/svg/ic_briefcase.svg',
                        size: 13, color: Color(0xFF5B6472)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                          ozet.uyelikMetni == null
                              ? '${ozet.tamamlananIs} iş tamamladı'
                              : '${ozet.tamamlananIs} iş tamamladı  •  '
                                  '${ozet.uyelikMetni}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: refText(
                              size: RF.s115,
                              weight: RF.w400,
                              color: const Color(0xFF5B6472))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
