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
  // ── ⚠ İKİ KAYNAĞIN BÜYÜĞÜ (kullanıcı bulgusu, 9 Eyl) ──
  //
  // BULGU: "Yeni hesap açan bir hizmet alan, hizmet verenin güncel iş
  // bitirme sayısını kartlarda göremiyor."
  //
  // KÖK NEDEN: sayı YALNIZ türetiliyordu — izleyenin görebildiği
  // ilan ve teklifler taranıyordu. Yeni açılmış bir hesabın hiç
  // ilanı yoktur, dolayısıyla sonuç DAİMA 0 çıkıyordu. Bir kişinin
  // geçmişi, ona BAKAN kişinin verisinden hesaplanamaz.
  //
  // Artık hizmet verenin KENDİ hesabında bir sayaç duruyor
  // (`Account.tamamlananIs`); iş tamamlandığında oraya yazılıyor.
  //
  // ⚠ TÜRETİM KALDIRILMADI, BÜYÜĞÜ ALINIYOR: sayacın işlenmediği
  // eski kayıtlarda ilan sahibi kendi doğru sayısını görmeye devam
  // eder. Toplama DEĞİL karşılaştırma yapıldığı için mükerrer sayım
  // imkânsızdır.
  //
  // ⚠ SON SÖZ SUNUCUNUNDUR: gerçek backend bu sayıyı yanıtta
  // döndürmelidir; buradaki sayaç yerel köprüdür.
  final saklanan =
      context.read<AuthController>().accountById(saglayiciId)?.tamamlananIs ??
          0;

  final ilanlar = context.read<ListingController>().all;
  final teklifler = context.read<OfferController>();
  var turetilen = 0;
  for (final l in ilanlar) {
    if (!l.isTamamlanmisIs) {
      continue;
    }
    final secili =
        teklifler.offersForListing(l.id).where((o) => o.id == l.selectedOfferId);
    if (secili.isNotEmpty && secili.first.providerId == saglayiciId) {
      turetilen++;
    }
  }
  return saklanan > turetilen ? saklanan : turetilen;
}

/// Gerçek bir hesabın özetini üretir.
///
/// ── ⚠ KONUM = HESABIN KENDİ ADRESİ (kullanıcı bulgusu, 9 Eyl) ──
///
/// BULGU: "Hizmet veren hesabı açtım ve adres bilgilerim, hizmet alan
/// usta bul ekranında FARKLI adres bilgisi olarak görünüyor."
///
/// SEBEP: kart, hesabın adresini değil HİZMET VERDİĞİ BÖLGELERİ
/// (`serviceDistricts`) gösteriyordu; üstelik müşterinin ilçesi o
/// kümede varsa onu tercih ediyordu. Yani Aliağa'da oturup Karşıyaka'ya
/// da hizmet veren biri, Karşıyaka'daki müşteriye "Karşıyaka" olarak
/// görünüyordu. Kullanıcının girdiği adres ekranda hiç yer almıyordu.
///
/// Artık konum `address` alanından — kullanıcının KENDİ girdiği
/// il/ilçe — okunur. Adres değişince kart da değişir.
///
/// ⚠ SIRALAMA AYRI BİR ŞEYDİR ve DEĞİŞMEDİ: "bu hizmet vereni bana
/// göster" kararı hâlâ `serviceDistricts` ile verilir (bkz.
/// `sonuclar_screen`). Eşleştirme hizmet bölgesine, GÖSTERİLEN bilgi
/// adrese bakar. İkisini aynı alana bağlamak, kullanıcının şikâyet
/// ettiği yanlış adresi üretiyordu.
///
/// ⚠ ADRES EKSİKSE `null` döner ve konum satırı HİÇ ÇİZİLMEZ —
/// hizmet bölgesinden yaklaşık bir adres UYDURULMAZ.
SaglayiciOzeti? gercekSaglayiciOzeti(
  BuildContext context, {
  required String id,
  String? ilYedegi,
}) {
  final hesap = context.read<AuthController>().accountById(id);
  if (hesap == null) {
    return null;
  }
  final reviews = context.watch<ReviewController>();
  // ⚠ BİÇİM TEK YERDE: `domain/kullanici_konumu.dart`. Ekranlar ya
  // da özetler kendi metnini kurarsa aynı kişi kartlar arasında
  // "Karşıyaka / İzmir" ve "Örnekköy, Karşıyaka / İzmir" diye iki
  // farklı biçimde görünür — kullanıcının bildirdiği sapma buydu.
  final adres = hesap.address;
  final ilce = (adres == null || adres.district.isEmpty) ? null : adres.district;
  final il = adres?.city;
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
