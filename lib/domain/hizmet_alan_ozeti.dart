import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import 'kullanici_konumu.dart';

/// ── ⚠ HİZMET ALAN ÖZETİ — TEK KAYNAK ──
///
/// KULLANICI İSTEĞİ (9 Eyl): "İlan Kazandığım ekranına taşındığında
/// hizmet alan kart yapısı buraya olduğu gibi taşınmalı — hizmet
/// alanın bilgileri vb."
///
/// ⚠ SORUN: hizmet alanın kim olduğu, nerede oturduğu, kaç iş
/// tamamlattığı ve ne zamandır üye olduğu YALNIZ talep detay
/// ekranında hesaplanıyordu; hesaplama o dosyanın PRIVATE
/// fonksiyonlarındaydı. "Kazandığım" listesindeki kart bu bilgilerin
/// hiçbirini göstermiyordu — hizmet veren, kazandığı işin kime ait
/// olduğunu ancak detaya girerek görebiliyordu.
///
/// Hesaplama buraya taşındı; iki yüzey de aynı sayıyı üretir.
///
/// ⚠ HİZMET ALAN ≠ HİZMET VEREN: burada PUAN ve YORUM YOKTUR.
/// Değerlendirme yalnız hizmet verene yapılır (ilan sahibi
/// değerlendirir, tersi yoktur). `saglayici_ozeti.dart` ile
/// karıştırılmamalıdır — iki taraf farklı alanlar taşır.
typedef HizmetAlanOzeti = ({
  String id,
  String adSoyad,

  /// `null` = adres girilmemiş. Satır çizilmez; yaklaşık bir konum
  /// UYDURULMAZ.
  String? konum,
  int tamamlananIs,

  /// "Eylül 2026'ten beri üye" — `null` ise hesap okunamamıştır.
  String? uyelikMetni,
});

/// TAMAMLANAN İŞ — İKİ AKIŞ TOPLANIR.
///
/// ⚠ Hizmet alanın geçmişi hem normal "İlan Ver" akışındaki
/// tamamlanmış ilanlardan hem "Bul" akışındaki tamamlanmış
/// taleplerden oluşur. Yalnız biri sayılsaydı sayı olduğundan küçük
/// görünürdü.
int hizmetAlanTamamlananIs(BuildContext c, String hizmetAlanId) {
  final ilanSayisi = c
      .read<ListingController>()
      .all
      .where((l) => l.ownerId == hizmetAlanId && l.isTamamlanmisIs)
      .length;
  final talepSayisi = c
      .read<TeklifTalebiController>()
      .byHizmetAlan(hizmetAlanId)
      .where((t) => t.durum == TeklifTalebiDurumu.tamamlandi)
      .length;
  return ilanSayisi + talepSayisi;
}

/// ⚠ "Ocak 2025'ten beri üye" — `intl` paketi PROJEDE HİÇ
/// kullanılmıyor; yeni bağımlılık eklemek yerine sabit bir Türkçe ay
/// adları listesiyle biçimlendirilir.
const _kAyAdlari = <String>[
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String uyelikTarihiMetni(DateTime tarih) =>
    "${_kAyAdlari[tarih.month - 1]} ${tarih.year}'ten beri üye";

/// Hizmet alanın özeti.
///
/// [adGoster] çağıranın maskeleme kararına göre hazırladığı addır:
/// teklif verilene kadar iki taraf birbirine maskelidir, bu kural
/// çağıranda kalır (bkz. `TeklifTalebi` maskeleme notu).
HizmetAlanOzeti hizmetAlanOzeti(
  BuildContext context, {
  required String id,
  required String adGoster,
}) {
  final hesap = context.read<AuthController>().accountById(id);
  final adres = hesap?.address;
  return (
    id: id,
    adSoyad: adGoster,
    // ⚠ BİÇİM TEK YERDE (`konumMetni`): elle kurulan metin, aynı
    // kişiyi başka kartta başka biçimde gösteriyordu.
    // ⚠ MAHALLE DÂHİL (kullanıcı bulgusu, 9 Eyl): "Doğrudan teklif
    // isteği kartlarında hizmet alanın mahalle bilgisi eksik."
    //
    // Hizmet veren işin NEREDE olduğunu bilmek zorunda; ilçe tek
    // başına yetmiyor. İlan tabanlı kartlar zaten mahalleyi
    // gösteriyordu (`kullaniciKonumu(..., mahalleDahil: true)`), bu
    // özet göstermiyordu — aynı ekranda iki farklı ayrıntı düzeyi
    // vardı.
    //
    // ⚠ BİÇİM YİNE TEK KAYNAKTAN: `konumMetni`. Mahalle girilmemişse
    // satır kendiliğinden ilçe/il olarak kalır.
    konum: konumMetni(adres, mahalleDahil: true),
    tamamlananIs: hizmetAlanTamamlananIs(context, id),
    uyelikMetni:
        hesap == null ? null : uyelikTarihiMetni(hesap.kayitTarihi),
  );
}
