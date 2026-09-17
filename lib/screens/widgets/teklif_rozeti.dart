import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/ref_tokens.dart';

/// ── ⚠ TEKLİF ROZETİ — TEK KAYNAK ──
///
/// KULLANICI KURALI (9 Eyl, kesin kural olarak konuldu): "Sana tek tek
/// ekran düzelttirmek istemiyorum. Mantık her yerde birbirine bağlı
/// olmalı. Burada teklif gelmedi yazısı nasılsa diğer yerlerde de aynı
/// olmalı."
///
/// ⚠ BU KURALIN NEDEN KONDUĞU — ÖLÇÜLEN SAPMA: aynı rozet İKİ ayrı
/// dosyada AYRI AYRI yazılmıştı (`my_listings_screen` ve
/// `jobs_screen`, ikisinde de `_TeklifRozeti` adıyla). Daha önce
/// "Henüz" sözcüğünün kaldırılması istendiğinde yalnız `jobs_screen`
/// düzeltilmiş, `my_listings_screen` "Henüz teklif verilmedi" olarak
/// KALMIŞTI. İki kopya olduğu sürece bu yeniden olur.
///
/// Metin ve renk artık YALNIZ burada tanımlıdır.
///
/// ── METİN SÖZLEŞMESİ ──
///   • 0 teklif  → "Teklif verilmedi"  ("Henüz" YOK)
///   • 1+ teklif → "N teklif verildi"
///
/// ── RENK SÖZLEŞMESİ ──
///   • 0    → gri     (dikkat çekmez)
///   • 1-3  → mavi    (normal)
///   • 4+   → turuncu (rekabet yüksek)
///
/// ⚠ İKON KALDIRILDI (kullanıcı isteği): rozetin solundaki
/// `ic_chat.svg` konuşma balonu çizilmiyor. Rozet zaten metnin
/// kendisini söylüyordu; ikon "mesaj var" gibi yanlış bir anlam
/// taşıyordu.
String teklifEtiketi(int sayi) =>
    sayi == 0 ? 'Teklif verilmedi' : '$sayi teklif verildi';

class TeklifRozeti extends StatelessWidget {
  const TeklifRozeti({super.key, required this.sayi});

  final int sayi;

  @override
  Widget build(BuildContext context) {
    final (zemin, yazi) = switch (sayi) {
      0 => (const Color(0xFFF2F4F7), const Color(0xFF667085)),
      < 4 => (RC.blueSoft, RC.blue),
      _ => (const Color(0xFFFFF4E5), const Color(0xFFF5820C)),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: BorderRadius.circular(RR.r8),
        ),
        // ⚠ `Row` ve `mainAxisSize.min` KORUNDU: ikon gitti ama rozetin
        // genişliği yine içeriğe göre daralır, şerit hâline gelmez.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(teklifEtiketi(sayi),
                style: refText(size: RF.s115, weight: RF.w600, color: yazi)),
          ],
        ),
      ),
    );
  }
}
