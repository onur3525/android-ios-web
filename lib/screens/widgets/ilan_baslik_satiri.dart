import 'package:flutter/material.dart';

import '../../data/category_tree.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import '../category_ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// İLAN BAŞLIK SATIRI — KATEGORİ İKONU + KATEGORİ + BAŞLIK
///
/// ## NİÇİN AYRI BİR BİLEŞEN
///
/// Aynı satır iki detay ekranında da çiziliyordu: müşteri tarafında
/// `listing_detail_screen`, hizmet veren tarafında
/// `job_detail_screen`. İki kopya ÜÇ AYRI YERDE ayrıştı ve her
/// ayrışma ayrı bir kullanıcı bulgusu oldu:
///
///   1. HİZA. İlan numarası bu sütunun İÇİNDE duruyordu; numara
///      satırı kategori ve başlığı AŞAĞI itiyor, 40 px'lik ikon
///      yukarıda yalnız kalıyordu. `job_detail` 10 Eyl'de
///      düzeltildi, `listing_detail` AYNI HÂLDE KALDI ve kullanıcı
///      12 Eyl'de yeniden bildirdi: "kategori başlıkları aşağıda
///      kalmış, ikonun yanına alınmalı".
///   2. İKON KAYNAĞI. `listing_detail` başlıktan katalog araması
///      yapan zengin bir çözücü kullanıyordu; `job_detail` ise
///      `categoryIcon(baslik)` çağırıyordu. `categoryIcon`
///      KATEGORİ ADIYLA anahtarlanmış bir harita okur; ona HİZMET
///      ADI verilince eşleşme olmaz ve her ilanda genel yedek ikon
///      çizilirdi.
///   3. DİKEY HİZA DEĞERİ. Biri `start`, öteki `center`.
///
/// ⚠ BU YÜZDEN KURAL ARTIK TEK YERDE. Ekranlar kendi satırını
/// YAZMAZ; bu bileşeni çağırır. Yeni bir detay ekranı eklendiğinde
/// aynı hizayı ve aynı ikonu kendiliğinden alır.
///
/// ## İLAN NUMARASI BURAYA GİRMEZ
///
/// ⚠ Numara bu satırın DEĞİL, kartın sorunudur: `IlanNoEtiketi`
/// kartın tam genişliğinde AYRI BİR SATIR olarak, bu bileşenden
/// ÖNCE çizilir. Sütunun içine alınırsa 1 numaralı arıza geri gelir.
/// ═══════════════════════════════════════════════════════════════
class IlanBaslikSatiri extends StatelessWidget {
  const IlanBaslikSatiri({
    super.key,
    required this.baslik,
    this.meta,
    this.trailing,
  });

  /// İlan başlığı (hizmet adı).
  final String baslik;

  /// Başlığın altına çizilen ikincil satır (konum, zaman vb.).
  ///
  /// ⚠ İSTEĞE BAĞLI: `job_detail` bu satırı GÖSTERMEZ — aynı bilgi o
  /// ekranda "İlan Detayı" bölümünde zaten var ve tekrar ediyordu.
  final Widget? meta;

  /// Satırın sağ ucuna eklenen öğe (rozet vb.).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      // ⚠ DİKEY ORTALI — `start` DEĞİL.
      //
      // `start` ile 40 px'lik ikon, iki-üç satırlık metin bloğunun
      // tepesine yapışır ve yukarıda yalnız kalır. Kullanıcının iki
      // kez bildirdiği görüntü budur.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IlanKategoriIkonu(baslik),
        const SizedBox(width: 10), // gap:10px
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── ⚠ ÜST KATEGORİ ADI YAZILMAZ (12 Eyl, ürün kararı) ──
              //
              // Bir tur kartlarda ve detaylarda hizmet adının ÜSTÜNE
              // kategori yazılıyordu ("Doğalgaz" / "Doğalgaz Kaçak
              // Kontrolü"). Kullanıcı kararı: YALNIZ SEÇİLEN HİZMET
              // görünür. Ayırt ediciliği artık KATEGORİ İKONU taşır.
              //
              // ⚠ GERİ EKLENMEZ: kural `test/ilan_kategori_satiri_test`
              // ile tüm yüzeylerde kilitlidir.
              // .ld-title{15.5px/700;-.2px;margin-top:1px}
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  baslik,
                  style: refText(
                    size: 15.5,
                    weight: RF.w700,
                    color: RC.text,
                    letterSpacing: RF.lsM02,
                  ),
                ),
              ),
              // .ld-meta{margin-top:4px}
              if (meta != null) ...[
                const SizedBox(height: 4),
                meta!,
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// KATEGORİ İKONU — DAİRE İÇİNDE, TEK BİLEŞEN
///
/// ⚠ KARTLARDA DA KULLANILIR. Üst kategori adı yazılmadığı için
/// ilanın hangi alana ait olduğunu artık İKON taşır; bu yüzden ikon
/// yalnız detay ekranlarının değil, kartların da parçasıdır.
///
/// ⚠ ÖLÇÜ PARAMETRİK: detayda 40/22, kartta daha küçük. Renk, biçim
/// ve ikon çözümü DEĞİŞMEZ — ekranlar kendi dairesini çizmez.
/// ═══════════════════════════════════════════════════════════════
class IlanKategoriIkonu extends StatelessWidget {
  const IlanKategoriIkonu(this.baslik, {super.key, this.cap = 40});

  /// İlan başlığı (hizmet adı).
  final String baslik;

  /// Dairenin çapı. İkon, çapın %55'i olarak çizilir (40 → 22).
  final double cap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cap,
      height: cap,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: RC.blueSoft, // #EAF1FB
        shape: BoxShape.circle,
      ),
      child: RefSvg(ilanIkonu(baslik), size: cap * 0.55, color: RC.blue),
    );
  }
}

/// ── ⚠ İLAN İKONU — TEK ÇÖZÜCÜ ──
///
/// Referans `ldIcon(title)`: önce hizmet kataloğunda ad aranır,
/// bulunamazsa anahtar kelime tablosuna düşülür, o da tutmazsa genel
/// alet ikonu döner.
///
/// ⚠ `categoryIcon` DOĞRUDAN ÇAĞRILMAZ: o harita KATEGORİ ADIYLA
/// anahtarlanmıştır. Ona başlık ("Doğalgaz Kaçak Kontrolü") verilirse
/// eşleşme olmaz ve her ilan genel yedek ikonu çizer. Başlıktan
/// kategoriye geçiş burada yapılır.
String ilanIkonu(String baslik) {
  final t = baslik.trim();
  // Başlığın KENDİSİ bir kategori olabilir (kullanıcı ana kategori
  // seçtiyse). `kategoriAdi` bu durumda `null` döner — ikon için
  // aranan cevap ise kategorinin ta kendisidir.
  if (kCategoryTree.containsKey(t)) {
    return categoryIcon(t);
  }
  // ⚠ AYNI ÇÖZÜM YOLU: kategori adı ile ikon aynı fonksiyondan
  // türer. İki ayrı arama mantığı tutulursa biri değişip öteki
  // kalabilir.
  final kategori = kategoriAdi(t);
  if (kategori != null) {
    return categoryIcon(kategori);
  }
  const kelimeler = {
    'elektrik': 'Elektrik',
    'kombi': 'Doğalgaz',
    'doğalgaz': 'Doğalgaz',
    'petek': 'Doğalgaz',
    'musluk': 'Su Tesisatı',
    'tesisat': 'Su Tesisatı',
    'temizl': 'Temizlik Hizmetleri',
    'boya': 'Boya ve Badana',
    'badana': 'Boya ve Badana',
    'fayans': 'Fayans ve Seramik Döşeme',
    'bahçe': 'Bahçe ve Peyzaj',
    'duvar': 'Duvar Kağıdı ve Dekorasyon',
  };
  final k = t.toLowerCase();
  for (final e in kelimeler.entries) {
    if (k.contains(e.key)) {
      return categoryIcon(e.value);
    }
  }
  // HTML: `IC_TOOLB(24)`
  return 'assets/svg/ic_toolb.svg';
}
