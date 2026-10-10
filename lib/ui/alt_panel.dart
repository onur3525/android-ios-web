import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'olcu.dart';
import 'ref_tokens.dart';

/// ═══════════════════════════════════════════════════════════════
/// ALTTAN PANEL — MASAÜSTÜNDE ORTALANMIŞ
///
/// `showModalBottomSheet` yerine geçer. Mobilde ve dar tarayıcıda
/// AYNI çağrıyı yapar; masaüstü web'de paneli ekranın ortasına alır
/// ve genişliğini sınırlar.
///
/// ## ⚠ NİÇİN GEREKLİ
///
/// `RefBottomSheet` zaten masaüstünde ortalanıyordu, ama onu
/// kullanmayan on doğrudan `showModalBottomSheet` çağrısı vardı
/// (kategori seçimi, ilçe seçimi, adres formu, kayıt adımları). O
/// paneller 1920 px'lik bir ekranda alttan tam genişlikte çıkıyor ve
/// masaüstünde yanlış duruyordu.
///
/// ## ⚠ NASIL ORTALANIR
///
/// `showModalBottomSheet` `constraints` parametresi alır; genişlik
/// sınırı verildiğinde panel YATAYDA ORTALANIR. Ayrıca `shape` ile
/// dört köşe yuvarlatılır — alttan çıkan panelde yalnız üst köşeler
/// yuvarlaktır, ortada duran bir pencerede dördü de olmalıdır.
///
/// ⚠ YENİ PANEL SİSTEMİ DEĞİL: çağrı yine Flutter'ın kendi
/// `showModalBottomSheet`i. Değişen yalnız kısıt ve köşe.
///
/// ⚠ MOBİLDE HİÇBİR ŞEY DEĞİŞMEZ: `kIsWeb` ve ≥1024 px sağlanmazsa
/// çağıranın verdiği `shape` ve kısıtlar aynen geçer.
///
/// ⚠ EŞİK ÖTEKİ WEB YAPILARIYLA AYNI (`masaustuMu`): biri ortada
/// dururken öteki altta kalsaydı sayfa tutarsız görünürdü.
///
/// ⚠ 560 px TASARIM SİSTEMİNDEN: form genişliğiyle aynı; bu
/// panellerin içeriği de form ve seçim listeleridir.
Future<T?> altPanelGoster<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  BoxConstraints? constraints,
}) {
  // ── ⚠ WEB'DE ORTADA AÇILIR, ALTTAN DEĞİL ──
  //
  // `showModalBottomSheet` panelleri DAİMA ekranın altına yapıştırır.
  // Mobil uygulamada doğru kalıptır; web'de değil — kullanıcı sayfanın
  // ortasında bir seçim penceresi bekler. Kayıt formu zaten ortada bir
  // kart olarak duruyordu, il seçici onun ALTINDA, ekranın dibinde
  // açılınca iki katman birbirinden kopuk görünüyordu.
  //
  // ⚠ GENİŞLİK EŞİĞİ YOK: `WebPanel` ile aynı karar — panel biçimi
  // ekran genişliğine değil, ortamın türüne bağlıdır. Dar web'de de
  // ortada açılır.
  //
  // ⚠ MOBİL UYGULAMA AYNEN KALIR: `kIsWeb` değilse aşağıdaki
  // `showModalBottomSheet` çağrılır; alttan açılan panel, sürükleme
  // çubuğu ve davranışı değişmez.
  if (kIsWeb) {
    return showDialog<T>(
      context: context,
      // ⚠ DIŞARI TIKLAMA KAPATIR: seçim penceresidir, form değil.
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: backgroundColor ?? RC.white,
        clipBehavior: Clip.antiAlias,
        // ⚠ DÖRT KÖŞE YUVARLAK: alttan açılan panelde yalnız üst iki
        // köşe yuvarlaktır; ortada duran bir pencerede dördü de.
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          // ⚠ AYNI ÖLÇÜLER: genişlik tasarım sisteminden, yükseklik
          // ekranın %70'i — alttan açılan panelle aynı denge.
          constraints: BoxConstraints(
            maxWidth: IcerikGenisligi.form,
            maxHeight: MediaQuery.sizeOf(context).height * 0.70,
          ),
          child: builder(c),
        ),
      ),
    );
  }

  final masaustu = kIsWeb && ekranSinifi(context).masaustuMu;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: masaustu
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          )
        : shape,
    // ── ⚠ YÜKSEKLİK SINIRI: LİSTE EKRANI DOLDURMASIN ──
    //
    // Kategori ve ilçe seçicileri uzun listelerdir (İzmir'de 30
    // ilçe, yüzlerce alt hizmet). `isScrollControlled: true` ile
    // panel içeriği kadar uzuyor ve neredeyse tüm ekranı kaplıyordu;
    // kullanıcı nerede olduğunu kaybediyor, "Kaydet" düğmesine
    // ulaşmak için uzun uzun kaydırıyordu.
    //
    // ⚠ EKRANIN %70'İ: yaklaşık on beş satır görünür, gerisi panelin
    // KENDİ İÇİNDE kayar. Üstte sayfa görünür kalır, panelin bir
    // katman olduğu anlaşılır.
    //
    // ⚠ ORANDIR, SABİT PİKSEL DEĞİL: küçük telefonda da geniş
    // masaüstünde de aynı dengeyi verir.
    //
    // ⚠ ÇAĞIRANIN KISITI ÖNCELİKLİ: `constraints` verilmişse ona
    // dokunulmaz; bu yalnız VARSAYILAN.
    constraints: constraints ??
        BoxConstraints(
          maxWidth: masaustu ? IcerikGenisligi.form : double.infinity,
          maxHeight: MediaQuery.sizeOf(context).height * 0.70,
        ),
    builder: builder,
  );
}
