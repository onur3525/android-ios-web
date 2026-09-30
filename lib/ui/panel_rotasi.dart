import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


/// ═══════════════════════════════════════════════════════════════
/// PANEL ROTASI — WEB'DE ARKA PLAN GÖRÜNÜR KALIR
///
/// ## ⚠ NİÇİN ROTA SEVİYESİNDE
///
/// Flutter'da bir route VARSAYILAN OLARAK OPAKTIR: altındaki sayfa
/// çizilmez bile. `WebPanel` kartı ortada dursa da arkasında boş bir
/// zemin vardı, önceki sayfa değil.
///
/// Saydamlık route'un DOĞDUĞU YERDE verilen bir özelliktir
/// (`opaque: false`); panelin içinden sonradan açılamaz. Bu yüzden
/// kural buraya, rota üretimine taşındı.
///
/// ## ⚠ MOBİL VE ANDROID/iOS AYNEN KORUNUR
///
/// `kIsWeb` değilse ya da ekran dar ise düpedüz `MaterialPageRoute`
/// döner — yani bugünkü rota, bugünkü geçiş animasyonu (iOS'ta
/// Cupertino kaydırma, Android'de `HizliGecis`). Kilitli baseline'a
/// dokunulmaz.
///
/// ## ⚠ GEZİNME DAVRANIŞI DEĞİŞMEZ
///
/// Rota yine sıradan bir sayfa rotasıdır: tarayıcı geri tuşu, URL,
/// derin bağlantı ve `Navigator.pop` aynen çalışır. Değişen yalnız
/// ALTTAKİ sayfanın çizilip çizilmediği ve geçiş animasyonu.
///
/// ⚠ PERDEYE DOKUNUNCA KAPANMAZ (`barrierDismissible: false`): bu bir
/// diyalog değil, sayfa. Form doldururken yanlışlıkla dışarı
/// dokunmak veriyi kaybettirmemeli. Kapatma X ve Esc ile.
/// ═══════════════════════════════════════════════════════════════
Route<T> panelRotasi<T>({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  if (!_masaustuWeb()) {
    return MaterialPageRoute<T>(settings: settings, builder: builder);
  }
  return PageRouteBuilder<T>(
    settings: settings,
    // ⚠ ASIL MESELE BU SATIR: alttaki sayfa çizilmeye devam eder.
    opaque: false,
    barrierDismissible: false,
    // ⚠ KARARTMA HAFİF: arka plan görünsün ama öne çıkmasın.
    // ⚠ KARARTMA DA HAFİFLETİLDİ: bulanıklık azalınca karartmanın
    // ağır kalması arka planı gri bir lekeye çeviriyordu.
    barrierColor: const Color(0x3D101828),
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) {
      // ⚠ BULANIKLIK ANİMASYONLA GELİR: aniden başlayan bir blur
      // sıçrama gibi görünür.
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: t,
        child: AnimatedBuilder(
          animation: t,
          builder: (context, ic) => BackdropFilter(
            // ⚠ BULANIKLIK HAFİF (2.5): 6 birimde arka plan okunmaz
            // hâle geliyor ve kenarlarda yayılma ("bozulma") görünüyordu.
            // Amaç arkayı gizlemek değil, GERİYE İTMEK — sayfa hâlâ
            // tanınabilmeli.
            filter: ImageFilter.blur(
              sigmaX: 2.5 * t.value,
              sigmaY: 2.5 * t.value,
            ),
            child: ic,
          ),
          child: child,
        ),
      );
    },
  );
}

/// Web mi?
///
/// ── ⚠ GENİŞLİK EŞİĞİ KALDIRILDI (19 Eyl, kullanıcı kararı) ──
///
/// Önceden ≥1024 px aranıyordu. `WebPanel` artık her web genişliğinde
/// kart çiziyor; rota opak kalsaydı kart boş bir zeminin üstünde
/// durur ve karartılmış arka plan hiç görünmezdi. İki kuralın aynı
/// anda değişmesi ŞART.
///
/// ⚠ `BuildContext` YOK: `onGenerateRoute` bir bağlam vermez. Artık
/// genişliğe bakılmadığı için `PlatformDispatcher` okumasına da gerek
/// kalmadı — pencere yeniden boyutlandırıldığında saydamlığın
/// değişmemesi sorunu da böylece ortadan kalktı.
///
/// ⚠ ANDROID/iOS KİLİTLİ: `kIsWeb` değilse düpedüz
/// `MaterialPageRoute` döner.
bool _masaustuWeb() => kIsWeb;

/// ═══════════════════════════════════════════════════════════════
/// AKIŞ ROTASI — KATEGORİ → HİZMET → İLAN OLUŞTURMA (TEK KAYNAK)
///
/// Kullanıcı kararı: ana sayfadaki kategori (çatı) kartlarından
/// başlayan akış ve ilan oluşturma ekranları web'de GİRİŞ EKRANI GİBİ
/// panel olarak açılır — tam ekran değil. Bu akıştaki bütün
/// geçişler buradan geçer; biri düz sayfa, öteki panel kalıp
/// ayrışmasın.
///
/// ⚠ MOBİL KİLİTLİ: web değilse bugünkü `MaterialPageRoute`un
/// KENDİSİ döner (aynı `settings`, aynı geçiş). Android/iOS'ta hiçbir
/// şey değişmez.
///
/// Panelin görünümü ekranların kendi `WebPanel` / `RefPage`
/// sarmalayıcısından gelir; `panelMi` saydam rotayı görünce kartı
/// çizer.
/// ═══════════════════════════════════════════════════════════════
Route<T> akisRotasi<T>({
  RouteSettings? settings,
  required WidgetBuilder builder,
}) {
  if (!kIsWeb) {
    return MaterialPageRoute<T>(settings: settings, builder: builder);
  }
  return panelRotasi<T>(
    settings: settings ?? const RouteSettings(),
    builder: builder,
  );
}
