import 'package:flutter/material.dart';

import '../../ui/ref_tokens.dart';

/// ═══════════════════════════════════════════════════════════════
/// YANLIŞ TARAF KAPISI — SESSİZ GERİ DÖNÜŞ
///
/// ⚠ KULLANICI KURALI (12 Eyl): "Bu ekranı kimsenin görmesini
/// istemiyorum, yazıyı kaldır. Birbirinin ekranını görmemesi için
/// gerekli tüm önlemi al ama yazı gösterme."
///
/// ## NE YAPAR
///
/// Karşı tarafa ait bir ekrana düşüldüğünde HİÇBİR ŞEY ÇİZMEZ ve
/// sayfayı kapatır. Kullanıcı geldiği yerde kalır.
///
/// ⚠ ÖNCE METİNLİ BİR BOŞ DURUM GÖSTERİYORDU ("Bu ekran size ait
/// değil"). Kullanıcı kararı: o yazı hiç görünmesin. Engelleme
/// duruyor, yalnız GÖRÜNÜRLÜĞÜ kalktı.
///
/// ## NİÇİN `Navigator.pop` DEĞİL `maybePop`
///
/// ⚠ SAYFA EN ALTTAKİ OLABİLİR: bildirimden değil de bir sekmeden
/// gelinmişse kapatılacak bir sayfa yoktur. `pop` orada yığını boşaltıp
/// siyah ekran bırakırdı; `maybePop` kapatamıyorsa hiçbir şey yapmaz.
///
/// ## NİÇİN İLK KAREDEN SONRA
///
/// ⚠ `build` İÇİNDE GEZİNİLMEZ: Flutter, ağaç kurulurken yapılan
/// `Navigator` çağrısında hata atar. Kapatma ilk kare çizildikten
/// sonra yapılır; o tek karede de metin değil BOŞ ZEMİN görünür.
///
/// ## NİÇİN BU YALNIZCA İKİNCİ SAVUNMA HATTI
///
/// ⚠ ASIL ÖNLEM YÖNLENDİRMEDEDİR: bildirimler doğru tarafın ekranına
/// gider (bkz. `notifications_screen._openTarget`). Burası, ileride
/// yanlış bir `Navigator.push` eklenirse karşı tarafın görünümünün
/// çizilmesini engeller.
///
/// ⚠ BU BİR YETKİ DENETİMİ DEĞİL: gerçek yetki sunucudadır
/// (`selectOffer` → `UnauthorizedError`). Gerçek backend de aynı
/// denetimi yapmalıdır.
/// ═══════════════════════════════════════════════════════════════
class YanlisTarafKapisi extends StatefulWidget {
  const YanlisTarafKapisi({super.key});

  @override
  State<YanlisTarafKapisi> createState() => _YanlisTarafKapisiState();
}

class _YanlisTarafKapisiState extends State<YanlisTarafKapisi> {
  @override
  void initState() {
    super.initState();
    // ⚠ TEK SEFER: `initState` sayfa ömründe bir kez koşar; `build`
    // her yeniden çizimde koşardı ve arka arkaya kapatma denemesi
    // üretirdi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  // ⚠ BOŞ ZEMİN, METİN YOK: kapanana kadar geçen tek karede bile
  // kullanıcı bir uyarı okumaz.
  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: RC.pageBg, body: SizedBox.shrink());
}
