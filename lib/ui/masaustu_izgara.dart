import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'olcu.dart';

/// ═══════════════════════════════════════════════════════════════
/// MASAÜSTÜ LİSTE IZGARASI
///
/// Dikey kart listelerini masaüstü web'de ÇOK KOLONLU dizer.
///
/// ## ⚠ NİÇİN `GridView` DEĞİL
///
/// `GridView` her hücreye AYNI yüksekliği dayatır
/// (`childAspectRatio`). Bu ekranlardaki kartlar değişken yüksekliktedir:
/// açıklama iki satır da olabilir beş satır da, rozet olabilir de
/// olmayabilir de. Sabit oran ya kartları keser ya da altlarında
/// devasa boşluk bırakırdı — ikisi de mevcut kart tasarımını bozardı.
///
/// `Wrap` her kartı KENDİ yüksekliğinde bırakır. Kart tasarımı,
/// renkleri, ikonları ve davranışı hiç değişmez; yalnız yan yana
/// dizilirler.
///
/// ## ⚠ MOBİL VE TABLET HİÇ DEĞİŞMEZ
///
/// İki koşul birlikte aranır: `kIsWeb` VE ≥1024 px
/// (`EkranSinifi.masaustuMu`). Sağlanmazsa çocuklar bugünkü gibi ALT
/// ALTA, aynı 10 px aralıkla dizilir — Android/iOS'ta, tablette ve dar
/// tarayıcı penceresinde tek satır kod farkı olmaz.
///
/// ⚠ EŞİK `masaustuNav` İLE AYNI: üst menü çıkan ekranda liste hâlâ
/// tek kolon kalsaydı düzen tutarsız görünürdü.
///
/// ## ⚠ KOLON SAYISI GENİŞLİKTEN TÜRETİLİR
///
/// Sabit "2 kolon" demek 1024'te kartları daraltır, 2560'ta ise boşa
/// yer bırakırdı. Kolon sayısı, kartın okunabilir en küçük genişliğine
/// (`_enAzKart`) göre hesaplanır. ⚠ 28 Eki (2. karar): üst sınır
/// KALDIRILDI — geniş monitörde ekran yarım kalmasın diye sütun eklenir.
///
/// ## ⚠ KAPSAM DIŞI
///
/// Bu yapı yalnız DİZİLİŞİ değiştirir. Boş liste, yükleniyor, hata,
/// filtre/sıralama ve kart tıklama davranışlarına DOKUNMAZ — onlar
/// çağıran ekranda, bu widget'ın dışında kalır.
/// ═══════════════════════════════════════════════════════════════
class MasaustuIzgara extends StatelessWidget {
  const MasaustuIzgara({
    super.key,
    required this.children,
    this.aralik = 10,
  });

  /// Kartlar. Sıra KORUNUR: `Wrap` soldan sağa, sonra alta dizer.
  final List<Widget> children;

  /// Kartlar arası boşluk — çağıran ekrandaki `separatorBuilder`
  /// değeriyle aynı verilmelidir ki mobil ile masaüstü aynı nefes
  /// alsın.
  final double aralik;

  /// Bir kartın altına düşmemesi gereken genişlik.
  static const double _enAzKart = 360;


  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !ekranSinifi(context).masaustuMu) {
      // ⚠ BUGÜNKÜ DAVRANIŞ: alt alta, aynı aralıkla.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: aralik),
            children[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, kisit) {
        final genislik = kisit.maxWidth;
        final kolon = masaustuKolonSayisi(genislik, aralik);
        // ⚠ TEK KOLONDA `Wrap` KURULMAZ: gereksiz katman olur ve
        // kartlar `stretch` yerine kendi genişliğine büzülebilir.
        if (kolon == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: aralik),
                children[i],
              ],
            ],
          );
        }
        final kartGenisligi = (genislik - aralik * (kolon - 1)) / kolon;
        return Wrap(
          spacing: aralik,
          runSpacing: aralik,
          children: [
            for (final c in children)
              SizedBox(width: kartGenisligi, child: c),
          ],
        );
      },
    );
  }
}

/// Kaydırılabilir liste — masaüstünde ızgara, mobilde bugünkü liste.
///
/// ## ⚠ NİÇİN AYRI BİR YARDIMCI
///
/// Liste ekranları `ListView.separated` kullanıyor: hem kaydırmayı hem
/// aralığı hem dolguyu o yönetiyor. Her çağrı yerinde "masaüstüyse
/// şunu, değilse bunu" diye dallanmak aynı kodu ekran ekran
/// kopyalamak olurdu.
///
/// Bu yardımcı o dallanmayı TEK YERDE yapar; çağıran ekranda
/// `ListView.separated` yerine tek satır değişir.
///
/// ⚠ DAVRANIŞ MOBİLDE BİREBİR AYNI: aynı `physics`, aynı `padding`,
/// aynı `separatorBuilder` aralığı, aynı `itemBuilder`. Mobil yolda
/// gerçekten `ListView.separated` döner — taklidi değil, kendisi.
///
/// ⚠ MASAÜSTÜNDE KAYDIRMA KORUNUR: aynı `physics` ve aynı `padding`;
/// "aşağı çekip yenile" davranışı çalışmaya devam eder.
///
/// ## ⚠ MASAÜSTÜ DE TEMBEL ÇİZİLİR (28 Eki, kullanıcı kararı)
///
/// Önceden masaüstünde BÜTÜN kartlar tek seferde çiziliyordu
/// (`SingleChildScrollView` + `Wrap`): 500 ilan = 500 kart. Artık ızgara
/// SATIR SATIR `ListView` ile kurulur: yalnız ekranda görünen satırlar
/// (ve kaydırma akıcı olsun diye hemen altındaki kısa pay) çizilir;
/// kaydırdıkça sıradakiler çizilir, ekrandan çıkanlar bırakılır.
///
/// GÖRÜNÜM `MasaustuIzgara` İLE AYNI: kolon sayısı aynı kuraldan
/// (`masaustuKolonSayisi`), kartlar eşit genişlikte, satırdaki kartlar
/// ÜSTTEN hizalı ve her kart KENDİ yüksekliğinde (`Wrap` gibi); yatay ve
/// dikey aralık `aralik`. Son satır eksikse kartlar soldan dizilir.
class MasaustuListe extends StatelessWidget {
  const MasaustuListe({
    super.key,
    required this.adet,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.aralik = 10,
  });

  final int adet;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final double aralik;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !ekranSinifi(context).masaustuMu) {
      return ListView.separated(
        physics: physics,
        padding: padding,
        itemCount: adet,
        separatorBuilder: (_, __) => SizedBox(height: aralik),
        itemBuilder: itemBuilder,
      );
    }
    return LayoutBuilder(
      builder: (context, kisit) {
        final yatayDolgu =
            padding.resolve(Directionality.of(context)).horizontal;
        final kolon = masaustuKolonSayisi(kisit.maxWidth - yatayDolgu, aralik);
        final satirSayisi = (adet + kolon - 1) ~/ kolon;
        return ListView.separated(
          physics: physics,
          padding: padding,
          itemCount: satirSayisi,
          separatorBuilder: (_, __) => SizedBox(height: aralik),
          itemBuilder: (context, satir) {
            if (kolon == 1) {
              return itemBuilder(context, satir);
            }
            final ilk = satir * kolon;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < kolon; k++) ...[
                  if (k > 0) SizedBox(width: aralik),
                  Expanded(
                    child: ilk + k < adet
                        ? itemBuilder(context, ilk + k)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Masaüstü ızgarasının kolon sayısı — `MasaustuIzgara` ve `MasaustuListe`
/// için TEK KAYNAK.
int masaustuKolonSayisi(double genislik, double aralik) {
  var kolon = ((genislik + aralik) /
          (MasaustuIzgara._enAzKart + aralik))
      .floor();
  // ⚠ ÜST SINIR YOK (28 Eki, 2. karar): ekran genişledikçe sütun eklenir;
  // kartlar en az 360 px kalır, büyümez.
  return kolon < 1 ? 1 : kolon;
}
