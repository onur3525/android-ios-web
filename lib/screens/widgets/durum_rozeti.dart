import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/ref_tokens.dart';

/// ── ⚠ BEKLEME METNİ — TEK KAYNAK ──
///
/// Aynı durum iki ekranda iki farklı cümleyle anlatılıyordu:
/// listede "Teklif bekleniyor", talep detayında "Hizmet verenin
/// teklifi bekleniyor." Kullanıcının kesin kuralı gereği metin tek
/// yerde tanımlanır.
const String kTeklifBekleniyorMetni = 'Teklif bekleniyor';

/// ── ⚠ DURUM ROZETİ — BEKLERKEN CANLI ──
///
/// KULLANICI İSTEĞİ (9 Eyl): "'Teklif bekleniyor' yazısı çok gelişi
/// güzel konulmuş, daha orantılı olmalı. Ve teklif bekliyor canlı
/// hissi vermeli — 'Teklif bekliyor ...' şeklinde, noktalar sırayla
/// yanıp sönebilir."
///
/// ⚠ NOKTALAR METNE EKLENMEZ, AYRI ÇİZİLİR: metnin sonuna nokta
/// eklemek her karede metni yeniden ölçtürür ve rozetin genişliği
/// oynar — "gelişigüzel" görüntünün bir sebebi de buydu. Üç nokta
/// SABİT yer kaplar, yalnız saydamlıkları değişir. Rozet hiç
/// zıplamaz.
///
/// ⚠ YALNIZ BEKLEYEN DURUMDA ANİMASYON: "Teklif geldi" ya da "İş
/// tamamlandı" gibi SONUÇLANMIŞ durumlarda nokta çizilmez; sürekli
/// oynayan bir öğe, bitmiş bir işi bitmemiş gibi gösterirdi.
///
/// ⚠ TEK `AnimationController`: üç nokta tek bir denetleyiciden
/// beslenir, her nokta zaman ekseninde kaydırılmış bir dilime bakar.
/// Nokta başına ayrı denetleyici, listede kart sayısı kadar
/// çoğalırdı.
class DurumRozeti extends StatelessWidget {
  const DurumRozeti({
    super.key,
    required this.metin,
    required this.renk,
    this.bekliyor = false,
  });

  final String metin;
  final Color renk;

  /// `true` ise metnin sağında sırayla yanıp sönen üç nokta çizilir.
  final bool bekliyor;

  @override
  Widget build(BuildContext context) => Container(
        // ⚠ ÖLÇÜ KÜÇÜLTÜLDÜ (9→8 / 4→3.5 dolgu, 11,5→11 punto):
        // rozet kartın içinde adla aynı ağırlıkta durmamalı; bilgi
        // ikincil, ad birincil.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RR.r8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // ⚠ NOKTALAR SATIRIN ALTINA HİZALANIR (kullanıcı isteği,
          // 10 Eyl): ortada duruyorlardı ve "Teklif bekleniyor..."
          // izlenimi vermiyorlardı. Talep detayındaki geniş kutu ile
          // AYNI kural.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(metin,
                style:
                    refText(size: RF.s11, weight: RF.w700, color: renk)),
            if (bekliyor) ...[
              const SizedBox(width: 3),
              // ⚠ ALT DOLGU: `end` hizası noktaları metin kutusunun
              // EN altına, yani alt uzantı (descender) hizasına
              // indirir; 2 px yukarı alınca yazının TABAN çizgisine
              // oturur. Kutuda 3 px, burada 2 px — nokta çapı ve
              // punto daha küçük.
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: BekleyenNoktalar(renk: renk),
              ),
            ],
          ],
        ),
      );
}

/// ── ⚠ BEKLEYEN NOKTALAR — TEK ANİMASYON ──
///
/// Metnin sağında sırayla parlayan üç nokta: 1 → 2 → 3 → baştan.
///
/// ⚠ AYRI BİLEŞEN OLMASININ SEBEBİ: aynı "bekliyor" hissi hem
/// listedeki küçük rozette hem talep detayındaki geniş kutuda
/// gerekiyor. İki yerde ayrı yazılsaydı biri güncellenip öteki
/// eskide kalırdı — kullanıcının kesin kuralı bunu yasaklıyor.
///
/// ⚠ TEK `AnimationController`: üç nokta tek denetleyiciden beslenir,
/// her nokta zaman ekseninde kaydırılmış bir dilime bakar. Nokta
/// başına ayrı denetleyici, listede kart sayısı kadar çoğalırdı.
///
/// ⚠ SABİT YER KAPLAR: noktalar metne KARAKTER olarak eklenmez
/// ("Bekleniyor." → "Bekleniyor..."), çünkü o zaman metin her karede
/// yeniden ölçülür ve kutu genişliği oynar.
class BekleyenNoktalar extends StatefulWidget {
  const BekleyenNoktalar({super.key, required this.renk, this.cap = 3});

  final Color renk;

  /// Nokta çapı — küçük rozette 3, geniş kutuda daha büyük.
  final double cap;

  @override
  State<BekleyenNoktalar> createState() => _BekleyenNoktalarState();
}

class _BekleyenNoktalarState extends State<BekleyenNoktalar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// [t] 0..1 arası döngü konumu, [i] nokta sırası.
  ///
  /// ⚠ TAM SÖNMEZ (taban 0,25): noktalar tamamen kaybolsaydı kutunun
  /// içi boşalıp doluyormuş gibi görünürdü. Amaç dikkat çekmek değil,
  /// "sürüyor" hissi vermek.
  double _saydamlik(double t, int i) {
    final kaydirilmis = (t - i / 3) % 1.0;
    final parlaklik = kaydirilmis < 0.33 ? 1.0 - (kaydirilmis / 0.33) : 0.0;
    return 0.25 + 0.75 * parlaklik;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(left: widget.cap / 2),
                child: Opacity(
                  opacity: _saydamlik(_ctrl.value, i),
                  child: Container(
                    width: widget.cap,
                    height: widget.cap,
                    decoration: BoxDecoration(
                      color: widget.renk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
