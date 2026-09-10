import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/saglayici_ozeti.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../job_detail_screen.dart' show maskeliAd;

/// ── ⚠ HİZMET VEREN BİLGİ SATIRI — TEK ÇİZİM ──
///
/// "Sonuçlar" listesindeki kart ile "Teklif İste" ekranının üst
/// kartı AYNI dört satırı gösterir: maskeli ad · puan + yorum sayısı
/// · tamamlanan iş · konum.
///
/// ⚠ ÖNCEDEN İKİ AYRI KOPYA VARDI ve ayrışmışlardı (puanın boş hâli,
/// konum seçimi). Kopya çizim silindi; her iki ekran da bu bileşeni
/// çağırır, veri `SaglayiciOzeti` ile gelir. Bir alan değişince iki
/// kartta AYNI ANDA değişir — kullanıcının koyduğu kural budur.
///
/// ⚠ ÖLÇÜ VE RENKLER DEĞİŞMEDİ: avatar 46, ad 14,5/w700, puan
/// 12,5/w700, yorum 12/w400, alt satırlar 12/w400 (#5B6472 ve
/// #98A2B3), yıldız #F5A319.
class SaglayiciOzetSatiri extends StatelessWidget {
  const SaglayiciOzetSatiri(this.ozet, {super.key, this.maskeli = true});

  final SaglayiciOzeti ozet;

  /// Kimlik gizli mi?
  ///
  /// ⚠ VARSAYILAN GİZLİ: teklif verilmeden önce hizmet verenin adı
  /// maskelidir. İletişim açıldıktan sonra çağıran `maskeli: false`
  /// geçer; ad tam yazılır ve kilitli avatar yerine baş harf avatarı
  /// çizilir.
  ///
  /// ⚠ İSTATİSTİKLER İKİ DURUMDA DA GÖSTERİLİR: puan, yorum sayısı,
  /// tamamlanan iş ve konum kimlik maskeliyken de görünür — maskelenen
  /// yalnız KİMLİKTİR.
  final bool maskeli;

  @override
  Widget build(BuildContext context) {
    final konum = ozet.ilce == null
        ? null
        : (ozet.il == null || ozet.il!.isEmpty
            ? ozet.ilce!
            : '${ozet.ilce} / ${ozet.il}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ⚠ Kimliği gizli avatarı: hazır `ic_avlock.svg`.
        if (maskeli)
          const RefSvg('assets/svg/ic_avlock.svg', size: 46)
        else
          SizedBox(
            width: 46,
            height: 46,
            child: FittedBox(child: RefBasHarfAvatar(ad: ozet.adSoyad)),
          ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⚠ `maskeliAd` — tek maskeleme kuralı.
              Text(maskeli ? maskeliAd(ozet.adSoyad) : ozet.adSoyad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: refText(
                      size: RF.s145, weight: RF.w700, color: RC.text)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const RefSvg('assets/svg/ic_starfill.svg',
                      size: 14, color: Color(0xFFF5A319)),
                  const SizedBox(width: 4),
                  // ⚠ HİÇ YORUM YOKSA "—", "0.0" DEĞİL: sıfır puan
                  // kötü değerlendirilmiş demektir; burada henüz
                  // değerlendirme yoktur. İki ekranda da aynı.
                  Text(
                      ozet.puan == null
                          ? '—'
                          : ozet.puan!.toStringAsFixed(1),
                      style: refText(
                          size: RF.s125, weight: RF.w700, color: RC.text)),
                  const SizedBox(width: 4),
                  Text('(${ozet.yorumSayisi} yorum)',
                      style: refText(
                          size: RF.s12,
                          weight: RF.w400,
                          color: RC.textSoft)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const RefSvg('assets/svg/ic_briefcase.svg',
                      size: 13, color: Color(0xFF5B6472)),
                  const SizedBox(width: 5),
                  Text('${ozet.tamamlananIs} iş tamamladı',
                      style: refText(
                          size: RF.s12,
                          weight: RF.w400,
                          color: const Color(0xFF5B6472))),
                ],
              ),
              if (konum != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const RefSvg('assets/svg/ic_pin.svg',
                        size: 14, color: Color(0xFF98A2B3)),
                    const SizedBox(width: 5),
                    Text(konum,
                        style: refText(
                            size: RF.s12,
                            weight: RF.w400,
                            color: const Color(0xFF98A2B3))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
