// HATA GÖSTERİMİ — ORTAK BİLEŞEN
//
// ⚠ METİN BURADA YAZILMAZ. Cümleler `domain/hata_mesajlari.dart`
// içinden gelir; bu dosya yalnız ÇİZER.
//
// ⚠ GEREKSİZ GÖSTERİM YASAK. Bileşen kendi başına karar vermez;
// çağıran ekran `hataGosterilsinMi()` ile sorar. Yükleme sürerken ya
// da ekranda veri varken hata basılmaz.

import 'package:flutter/material.dart';

import '../../domain/failures.dart';
import '../../domain/hata_mesajlari.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// Gösterilecek veri olmadığında ekranın ortasında çizilir.
///
/// ⚠ Boş liste için KULLANILMAZ — o durumda \"kayıt yok\" mesajı
/// gösterilir. Bu bileşen yalnız BAŞARISIZ İSTEK sonrası çizilir.
class HataTamEkran extends StatelessWidget {
  const HataTamEkran({super.key, required this.hata, this.onTekrar});

  final DomainError hata;

  /// Yeniden deneme geri çağrısı.
  ///
  /// ⚠ `null` verilirse düğme ÇİZİLMEZ. Hata bilgisi zaten eylem
  /// önermiyorsa (sunucu hatası gibi) düğme yine çizilmez.
  final VoidCallback? onTekrar;

  @override
  Widget build(BuildContext context) {
    final bilgi = hataBilgisi(hata);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── ⚠ RENK FİLTRESİ UYGULANAN İKON KULLANILMAZ ──
          //
          // `ic_info.svg` dolu daire + beyaz simgeden oluşur; üstüne
          // renk basılınca simge kaybolur ve ikon tek renk LEKEYE
          // döner. Sistem ikonu kullanılıyor: hem renklendirilebilir
          // hem her durumda okunur.
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F4F8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.error_outline_rounded,
                size: 24, color: RC.textSoft),
          ),
          const SizedBox(height: 12),
          Text(
            bilgi.baslik,
            textAlign: TextAlign.center,
            style: refText(size: RF.s145, weight: RF.w700, color: RC.text),
          ),
          if (bilgi.aciklama.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bilgi.aciklama,
              textAlign: TextAlign.center,
              style: refText(
                  size: RF.s125,
                  weight: RF.w400,
                  color: RC.textSoft,
                  height: RF.lh145),
            ),
          ],
          // ⚠ Düğme YALNIZ gerçekten yapılabilecek bir şey varsa.
          if (bilgi.denenebilir && onTekrar != null) ...[
            const SizedBox(height: 16),
            RefTap(
              onTap: onTekrar!,
              borderRadius: BorderRadius.circular(RR.r10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: RC.blue,
                  borderRadius: BorderRadius.circular(RR.r10),
                ),
                child: Text(bilgi.eylem!,
                    style: refText(
                        size: RF.s13, weight: RF.w700, color: RC.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ekranda veri varken kullanılan ince satır.
///
/// ⚠ Kullanıcının okumakta olduğu içeriği KAPATMAZ; yalnız üstte bir
/// satır olarak durur ve yeniden deneme sunar.
class HataSatiri extends StatelessWidget {
  const HataSatiri({super.key, required this.hata, this.onTekrar});

  final DomainError hata;
  final VoidCallback? onTekrar;

  @override
  Widget build(BuildContext context) {
    final bilgi = hataBilgisi(hata);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(RR.r10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(bilgi.baslik,
                style: refText(
                    size: RF.s125, weight: RF.w500, color: RC.danger)),
          ),
          if (bilgi.denenebilir && onTekrar != null)
            RefTap(
              onTap: onTekrar!,
              borderRadius: BorderRadius.circular(RR.r8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(bilgi.eylem!,
                    style: refText(
                        size: RF.s125, weight: RF.w700, color: RC.danger)),
              ),
            ),
        ],
      ),
    );
  }
}
