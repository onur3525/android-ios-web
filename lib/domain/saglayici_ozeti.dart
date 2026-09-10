import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';

/// ── ⚠ HİZMET VEREN ÖZETİ — TEK KAYNAK ──
///
/// KULLANICI KURALI (9 Eyl): "Bu kartlar ayrı ayrı değerlere,
/// bilgilere sahip olamaz. Bir iş tamamladıysa iş tamamlama, yorum
/// aldıysa yorum, puan aldıysa puan, adres değiştiyse adres, isim
/// değiştiyse isim — bilgileri tüm bu kartlarda AYNI ANDA
/// değişmeli."
///
/// ⚠ ÖLÇÜLEN SAPMA: aynı hesap için "Sonuçlar" kartı ile "Teklif
/// İste" ekranındaki kart FARKLI değerler gösterebiliyordu:
///
///   1. PUAN — Sonuçlar `averageOf(...) ?? 0` yapıp `0.0` yazıyordu;
///      Teklif İste `null` ise `—` yazıyordu. Hiç yorumu olmayan
///      hizmet veren bir ekranda "0.0", ötekinde "—" görünüyordu.
///
///   2. KONUM — Sonuçlar, hizmet verenin bölgeleri arasında
///      MÜŞTERİNİN ilçesi varsa onu gösteriyordu; Teklif İste her
///      zaman `serviceDistricts.first`i gösteriyordu. Aynı kişi
///      "Karşıyaka / İzmir" ve "Aliağa / İzmir" olarak görünüyordu.
///      (Teklif İste'deki yorum "iki ekran da aynı kaynağı okuyor"
///      diyordu — kaynak aynıydı, SEÇİM KURALI değildi.)
///
///   3. MOCK KAYITLAR — Sonuçlar listesindeki kurgusal hizmet
///      verenler dizinden gelen sabit değerleri (ör. 5.0 / 126 yorum
///      / 140 iş) gösteriyordu; "Teklif İste" ise o id'yi gerçek
///      hesap sanıp denetleyicilerden okuyor, hepsini 0 buluyordu.
///
/// Bu dosya o üç kuralı TEK YERE topluyor. İki ekran da buradan
/// okur; biri değişince öteki kendiliğinden değişir.
///
/// ⚠ HESAPLANAN DEĞER SAKLANMAZ: puan, yorum sayısı ve tamamlanan iş
/// her okumada denetleyicilerden ÜRETİLİR. Bir yerde saklansaydı
/// "aynı anda değişme" kuralı ilk kaçırılan güncellemede bozulurdu.
typedef SaglayiciOzeti = ({
  String id,
  String adSoyad,

  /// ⚠ `null` = HİÇ YORUM YOK. `0` DEĞİLDİR: sıfır puan "kötü
  /// değerlendirilmiş" demektir, oysa burada henüz değerlendirme
  /// yapılmamıştır. İki durum ayrı gösterilir.
  double? puan,
  int yorumSayisi,
  int tamamlananIs,

  /// ⚠ `null` = konum bilinmiyor; satır HİÇ ÇİZİLMEZ, "belirtilmemiş"
  /// gibi bir yer tutucu gösterilmez.
  String? ilce,
  String? il,
});

/// TAMAMLANAN İŞ SAYISI — TEK TANIM.
///
/// ⚠ Bu mantık daha önce `offer_detail_screen`, `sonuclar_screen` ve
/// `teklif_iste_screen` içinde AYRI AYRI yazılmıştı ("private olduğu
/// için yeniden yazıldı" notuyla). Üç kopya, üçünden biri
/// değiştiğinde sessizce ayrışır — kullanıcının şikâyet ettiği
/// sapmanın tam kaynağı budur.
///
/// Sayım kuralı: tamamlanmış ilanlar arasında, SEÇİLİ teklifi bu
/// hizmet verene ait olanlar.
int tamamlananIsSayisi(BuildContext context, String saglayiciId) {
  final ilanlar = context.read<ListingController>().all;
  final teklifler = context.read<OfferController>();
  var n = 0;
  for (final l in ilanlar) {
    if (!l.isTamamlanmisIs) {
      continue;
    }
    final secili =
        teklifler.offersForListing(l.id).where((o) => o.id == l.selectedOfferId);
    if (secili.isNotEmpty && secili.first.providerId == saglayiciId) {
      n++;
    }
  }
  return n;
}

/// Gerçek bir hesabın özetini üretir.
///
/// [musteriIlcesi] verilirse ve hizmet veren o ilçeye hizmet
/// veriyorsa konum olarak O gösterilir — "buraya hizmet veriyor"
/// bilgisi, listedeki ilk bölgeden daha anlamlıdır. Kural TEK
/// yerdedir; iki ekran da aynı sonucu alır.
SaglayiciOzeti? gercekSaglayiciOzeti(
  BuildContext context, {
  required String id,
  String? musteriIlcesi,
  String? ilYedegi,
}) {
  final hesap = context.read<AuthController>().accountById(id);
  if (hesap == null) {
    return null;
  }
  final reviews = context.watch<ReviewController>();
  final bolgeler = hesap.serviceDistricts;
  final ilce = bolgeler.isEmpty
      ? null
      : (musteriIlcesi != null && bolgeler.contains(musteriIlcesi)
          ? musteriIlcesi
          : bolgeler.first);
  final il = hesap.address?.city;
  return (
    id: hesap.id,
    adSoyad: hesap.name,
    puan: reviews.averageOf(id),
    yorumSayisi: reviews.byProvider(id).length,
    tamamlananIs: tamamlananIsSayisi(context, id),
    ilce: ilce,
    il: (il == null || il.isEmpty) ? ilYedegi : il,
  );
}
