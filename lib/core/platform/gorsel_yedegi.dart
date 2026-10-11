import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ── ⚠ AÇILAMAYAN FOTOĞRAF İÇİN VARSAYILAN YEDEK (11 Eki) ──
///
/// KULLANICI BULGUSU: talep detayındaki fotoğraf şeridinde, açılamayan
/// fotoğrafın yerinde Flutter'ın ham hata kutusu ("HTTP request failed,
/// statusCode: 0, blob:…") görünüyordu. `yerelGorsel` çağıranların bir
/// kısmı `hataYedegi` vermiyordu; o durumda `errorBuilder` hiç
/// kurulmuyordu (debug'da kırmızı çizgili kutu, release'te boş alan).
///
/// Artık `hataYedegi` verilmediğinde bu NÖTR yer tutucu çizilir: açık
/// gri zemin + galeri simgesi. Kendi yedeğini veren ekranlar (ilan
/// detayı, tam ekran görüntüleyici, sohbet) AYNEN kendi yedeğini çizer.
///
/// ⚠ TEK YER: web ve mobil köprüsü bu fonksiyonu kullanır; ekranlar
/// kendi kopyasını yazmaz.
Widget varsayilanGorselYedegi(BuildContext context) => LayoutBuilder(
      builder: (context, kutu) {
        final kisa = [
          if (kutu.maxWidth.isFinite) kutu.maxWidth,
          if (kutu.maxHeight.isFinite) kutu.maxHeight,
        ];
        final boy = kisa.isEmpty
            ? 24.0
            : (kisa.reduce((a, b) => a < b ? a : b) * 0.4).clamp(14.0, 44.0);
        return Semantics(
          label: 'Fotoğraf açılamadı',
          child: ColoredBox(
            color: const Color(0xFFF1F4F9),
            child: Center(
              child: SvgPicture.asset(
                'assets/svg/ic_gallery.svg',
                width: boy,
                height: boy,
                colorFilter: const ColorFilter.mode(
                    Color(0xFF8A94A6), BlendMode.srcIn),
              ),
            ),
          ),
        );
      },
    );
