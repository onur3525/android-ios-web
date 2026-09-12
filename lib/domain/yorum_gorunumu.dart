import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/listing_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/review.dart';

/// ── ⚠ YORUM KARTI GÖRÜNÜM KURALLARI — TEK KAYNAK ──
///
/// KULLANICI KURALLARI (9 Eyl):
///   • Profil fotoğrafı olmayacak.
///   • Ad "Gönül B." biçiminde — SOYAD HİÇBİR ŞEKİLDE görünmeyecek.
///   • Kartın sağ üstünde gün.ay.yıl biçiminde yorum tarihi.
///   • Adın altında, alınan HİZMETİN adı.
///   • Uzun yorumda "Göster" / "Küçült" ile kart açılıp kapanacak.

/// "Gönül Bütün" → "Gönül B."
///
/// ⚠ `maskeliAd` İLE KARIŞTIRILMAZ: o, kimliği GİZLER ("G**** B****")
/// ve teklif verilmeden önce kullanılır. Bu ise yayınlanmış bir
/// yorumun yazarını KISALTIR — ad açık, soyad yalnız baş harf.
///
/// ⚠ SOYAD SIZDIRILMAZ: yalnız ilk harf + nokta yazılır; ikiden fazla
/// kelimede de SON kelime soyad sayılır ve aradakiler atılır
/// ("Ayşe Nur Yılmaz" → "Ayşe Nur Y.").
///
/// Tek kelimelik adda soyad yoktur, olduğu gibi döner.
String kisaYazarAdi(String tamAd) {
  final parcalar =
      tamAd.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parcalar.isEmpty) {
    return 'Hizmet Alan';
  }
  if (parcalar.length == 1) {
    return parcalar.first;
  }
  final soyad = parcalar.removeLast();
  // ⚠ `substring` YETERLİ: `characters` paketi pubspec'te doğrudan
  // TANIMLI DEĞİL (Flutter üzerinden geçişli gelir) ve onu import
  // etmek `depend_on_referenced_packages` uyarısı üretirdi. Türkçe
  // adlarda birleşik grafem yoktur; ilk kod birimi ilk harftir.
  return '${parcalar.join(' ')} ${soyad.substring(0, 1)}.';
}

/// 10.09.2026
///
/// ⚠ Gün ve ay İKİ HANEYE tamamlanır; "1.9.2026" gibi düzensiz
/// genişlikler kart hizasını bozuyordu.
///
/// ⚠ ADI `yorumTarihi` İDİ, DEĞİŞTİRİLDİ (12 Eyl): işlev yoruma özel
/// değil, genel bir tarih biçimlendiricisi. Talep tarihi de bu biçimi
/// kullanınca ad yanıltıcı hâle geldi — "yorum" adını taşıyan bir
/// fonksiyonu ilan/talep tarihinde görmek, ikinci bir biçimlendirici
/// yazma isteği doğurur.
String kisaTarih(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}.'
    '${t.month.toString().padLeft(2, '0')}.'
    '${t.year}';

/// Yorumun hangi hizmet için yazıldığı.
///
/// ⚠ `Review` MODELİNE ALAN EKLENMEDİ: hizmet adı zaten ilanın ya da
/// talebin kendisinde duruyor. Modele kopya bir alan eklemek, geçmiş
/// kayıtlarda boş kalması ve iki kaynağın ayrışması demekti.
///
/// İki akış vardır (bkz. `Review` model notu): `talepId` dolu ise
/// "Bul" akışı, `listingId` dolu ise normal ilan akışı.
///
/// ⚠ BULUNAMAZSA `null` DÖNER: satır çizilmez, hizmet adı UYDURULMAZ.
String? yorumHizmetAdi(BuildContext context, Review r) {
  final talepId = r.talepId;
  if (talepId != null) {
    return context.read<TeklifTalebiController>().byId(talepId)?.hizmet;
  }
  final listingId = r.listingId;
  if (listingId == null) {
    return null;
  }
  return context.read<ListingController>().byId(listingId)?.title;
}

/// Bu yorum "uzun" mu — kart kapalı açılsın mı?
///
/// ⚠ KARAKTER SAYISI KULLANILIR, ÖLÇÜM DEĞİL: metnin gerçekten kaç
/// satır kapladığı ancak yerleşim sırasında bilinir; `TextPainter` ile
/// ölçmek kartı her karede yeniden hesaplatırdı. Sabit bir eşik hem
/// öngörülebilir hem test edilebilir.
///
/// Eşik, kapalı hâldeki üç satıra yaklaşık denk gelir.
const int kUzunYorumEsigi = 140;

bool uzunYorumMu(String metin) => metin.trim().length > kUzunYorumEsigi;
