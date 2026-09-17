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
///
/// ── ⚠ BALON HÂLİNE GETİRİLDİ (12 Eyl, kullanıcı isteği) ──
///
/// "Yeni mesaj gibi şık bir bulut içinde yazı... hemen mesaj kartı
/// içinde dışarı doğru oklu bir bulut olabilir ama kart içindeki
/// yazılar okunacak şekilde."
///
/// Düz bir yuvarlak kutuydu; artık sol alt köşesinden küçük bir
/// kuyruk çıkıyor — konuşma balonu okunuyor.
///
/// ⚠ KUYRUK KARTIN İÇERİĞİNE BİNMEZ: `Stack` ile taşırılmadı, normal
/// akışta yer kaplar. Kullanıcının şartı buydu.
class YeniMesajSeridi extends StatelessWidget {
  const YeniMesajSeridi(this.sayi, {super.key});

  final int sayi;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: RC.blueSoft,
              borderRadius: BorderRadius.circular(RR.r10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RefSvg('assets/svg/ic_chat.svg',
                    size: 13, color: RC.blue),
                const SizedBox(width: 6),
                Text(sayi == 1 ? 'Yeni mesaj' : '$sayi yeni mesaj',
                    style: refText(
                        size: RF.s115, weight: RF.w700, color: RC.blue)),
              ],
            ),
          ),
          // ── ⚠ KUYRUK: KUTUYU BULUTA ÇEVİREN ŞEY ──
          //
          // Kullanıcı isteği (12 Eyl): "dışarı doğru oklu bir bulut
          // olabilir ama kart içindeki yazılar okunacak şekilde."
          //
          // ⚠ KART İÇERİĞİNİN ÜSTÜNE BİNMEZ: kuyruk `Stack` ile
          // taşırılmadı, `Column`un normal akışında duruyor. Balon
          // kartın içinde kendi yerini kaplar; altındaki ya da
          // üstündeki hiçbir yazı örtülmez.
          //
          // ⚠ SOLA YASLI: balonun sol alt köşesinden çıkar, konuşma
          // balonlarının okunan yönüyle aynı.
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: CustomPaint(
              size: const Size(10, 5),
              painter: _KuyrukBoyaci(),
            ),
          ),
        ],
      );
}

/// Balonun sol alt köşesinden çıkan küçük üçgen.
///
/// ⚠ AYRI BİR ASSET EKLENMEDİ: tek renkli, 10x5 px'lik bir üçgen
/// için SVG dosyası açmak, renk değiştiğinde iki yerde güncelleme
/// gerektirirdi. Renk balonun zeminiyle AYNI kaynaktan okunur.
class _KuyrukBoyaci extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yol = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(yol, Paint()..color = RC.blueSoft);
  }

  // ⚠ Çizim girdiye bağlı değil: renk sabit, ölçü çağıranda.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
