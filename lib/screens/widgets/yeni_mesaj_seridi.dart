import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';

/// ── ⚠ YENİ MESAJ ŞERİDİ — TEK ÇİZİM ──
///
/// KULLANICI İSTEĞİ (9 Eyl): "Gelen mesajları iki tarafta da bu
/// kartlar üzerinde yeni mesajın geldiğini gösteren bir yazı vb. bir
/// şey olmalı."
///
/// Üç listede birden kullanılır: hizmet alanın "Teklif İstediklerim"
/// kartı, hizmet verenin "Teklif İstekleri" ve "Kazandığım"
/// kartları. Metin ve renk burada tanımlıdır.
///
/// ⚠ SAYI YOKSA ÇİZİLMEZ: çağıran `sayi > 0` kapısını uygular; bu
/// bileşen sıfır için boş kutu döndürmez, hiç çağrılmaz.
///
/// ⚠ ROZET DEĞİL ŞERİT: alt bardaki kırmızı sayı rozeti "ilgi
/// bekleyen" anlamı taşıyor. Buradaki bilgi kart içinde ve
/// bağlamıyla birlikte okunuyor, o yüzden metinli bir şerit —
/// kullanıcı "yazı vb. bir şey" dedi.
class YeniMesajSeridi extends StatelessWidget {
  const YeniMesajSeridi(this.sayi, {super.key});

  final int sayi;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: RC.blueSoft,
          borderRadius: BorderRadius.circular(RR.r8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RefSvg('assets/svg/ic_chat.svg', size: 13, color: RC.blue),
            const SizedBox(width: 6),
            Text(
                sayi == 1 ? 'Yeni mesaj' : '$sayi yeni mesaj',
                style: refText(
                    size: RF.s115, weight: RF.w700, color: RC.blue)),
          ],
        ),
      );
}
