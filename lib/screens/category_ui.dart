/// KATEGORİ GÖRSELLERİ — TEK MERKEZ
///
/// İKİ AYRI GÖRSEL KAYNAĞI VARDIR, KARIŞTIRILMAZ:
///
/// 1. SVG ikon (`assets/svg/categories/<slug>.svg`) — 53/53 kategori.
///    Uygulamanın HER yerinde kullanılan varsayılan görseldir.
/// 2. FOTOĞRAF (`assets/categories/<slug>.jpg`) — 53/53 kategori.
///    ⚠ YALNIZCA İLAN VERME EKRANINDAKİ kategori ızgarasında görünür
///    (kayıtlı `/customer/new-listing` ve kayıtsız `/listing/new`,
///    ortak `CreateListingScreen`). Fotoğrafı çizen TEK bileşen
///    `KategoriKarti`'dır.
///
/// Bu dosyadaki [CategoryBadge] fotoğraf ÇİZMEZ; ilan verme dışındaki
/// ekranlarda kullanılır ve daima SVG ikon gösterir. Görsel bulunamazsa
/// uygulama ÇÖKMEZ: ikon + marka rengi zeminine düşülür.
library;

import 'package:flutter/material.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import '../data/category_tree.dart';
import '../data/services/search_service.dart';


/// Kategori adı → asset slug'ı.
///
/// Türkçe karakterler sadeleştirilir ve boşluklar kaldırılır; böylece
/// dosya adları platformlar arası güvenli olur (ör. "Doğalgaz" →
/// "dogalgaz"). Bilinmeyen kategori için de kararlı bir slug üretilir.
String categorySlug(String category) {
  const tr = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
    'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'I': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final ch in category.trim().split('')) {
    final mapped = tr[ch] ?? ch.toLowerCase();
    if (RegExp(r'[a-z0-9]').hasMatch(mapped)) {
      buf.write(mapped);
    }
  }
  return buf.toString();
}

/// Fotoğrafı bulunan kategorilerin slug kümesi.
///
/// ⚠ ELLE YAZILMAZ: `kCategoryImage`'tan türetilir. Bugün 53/53
/// kategorinin fotoğrafı vardır; eski 7'lik sabit liste KALDIRILMIŞTIR.
Set<String> get kCategoryAssetSlugs =>
    kCategoryImage.keys.map(categorySlug).toSet();

/// Kategori FOTOĞRAFININ asset yolu; kayıt yoksa null.
///
/// ⚠ ÇAĞRI YERİ SINIRLIDIR: bu fotoğraf yalnız ilan verme ekranındaki
/// kategori ızgarasında çizilir (`KategoriKarti`). Başka bir ekrana
/// fotoğraf koymak için buradan okuma YAPILMAZ — o ekranlarda
/// `categoryIcon` / `CategoryBadge` (SVG) kullanılır.
String? categoryAsset(String category) => kCategoryImage[category];

/// KATEGORİ İKONU — TEK KAYNAK.
///
/// ⚠ SLUG TAHMİNİNE GÜVENİLMEZ.
///
/// Önceki sürüm `categorySlug()` çıktısıyla eşleşme yapıyordu ve
/// üç kategori sessizce fallback'e düşmüştü: `categorySlug` boşluğu
/// ATAR, alt çizgi EKLEMEZ ("Su Tesisatı" → "sutesisati"). Bu harita
/// artık KATEGORİ ADIYLA doğrudan eşleşir — ara dönüşüm yoktur.
///
/// ⚠ 53 KATEGORİNİN TAMAMI BURADA. Hiçbiri fallback'e düşmez; test
/// bunu kilitler. Yeni kategori eklendiğinde buraya da eklenmelidir.
///
/// ⚠ AYNI KATEGORİ HER EKRANDA AYNI İKONU KULLANIR: ana ekran, Tüm
/// Kategoriler, kayıt, rol değiştirme ve ilan oluşturma hepsi bu
/// haritadan okur.
const Map<String, String> kKategoriIkonu = {
  'Temizlik Hizmetleri':
      'assets/svg/categories/temizlik.svg',
  'Halı Yıkama':
      'assets/svg/categories/hali_yikama.svg',
  // ⚠ AYNI SVG İKİ KATEGORİDE: döşeme yıkama için ayrı çizim yok.
  // İkonlar tek renkli çizgi ikonlardır; ayrı bir çizim üretilene
  // kadar aynı ikon kullanılır — kart fotoğrafları zaten farklıdır.
  'Koltuk ve Döşeme Yıkama':
      'assets/svg/categories/hali_yikama.svg',
  'İlaçlama ve Haşere Kontrolü':
      'assets/svg/categories/ilaclama.svg',
  'Su Tesisatı':
      'assets/svg/categories/su_tesisati.svg',
  'Doğalgaz':
      'assets/svg/categories/dogalgaz.svg',
  // ⚠ İki kombi kategorisi aynı ikonu paylaşır (onaylı istisna).
  'Kombi Montaj':
      'assets/svg/categories/kombi.svg',
  'Kombi Servis':
      'assets/svg/categories/kombi.svg',
  'Isıtma Sistemleri':
      'assets/svg/categories/isitma.svg',
  'Elektrik':
      'assets/svg/categories/elektrik.svg',
  'Güvenlik Sistemleri':
      'assets/svg/categories/guvenlik.svg',
  'Klima Montaj ve Servis':
      'assets/svg/categories/klima.svg',
  'Beyaz Eşya Servisi':
      'assets/svg/categories/beyaz_esya.svg',
  'Elektronik Cihaz Tamiri':
      'assets/svg/categories/elektronik.svg',
  'Uydu ve Anten Sistemleri':
      'assets/svg/categories/uydu.svg',
  'İnternet ve Ağ Kurulumu':
      'assets/svg/categories/internet.svg',
  'Boya ve Badana':
      'assets/svg/categories/boya.svg',
  'Alçı ve Sıva İşleri':
      'assets/svg/categories/alci.svg',
  'Duvar Kağıdı ve Dekorasyon':
      'assets/svg/categories/duvar_kagidi.svg',
  'Tadilat ve Yenileme':
      'assets/svg/categories/tadilat.svg',
  'Banyo Tadilat ve Montaj':
      'assets/svg/categories/banyo.svg',
  'Mutfak Tadilat ve Dolap':
      'assets/svg/categories/mutfak.svg',
  'İnşaat ve Kaba Yapı':
      'assets/svg/categories/insaat.svg',
  'Fayans ve Seramik Döşeme':
      'assets/svg/categories/seramik.svg',
  'Zemin Kaplama':
      'assets/svg/categories/zemin.svg',
  'Yalıtım ve Mantolama':
      'assets/svg/categories/yalitim.svg',
  'Çatı Yapım ve Onarım':
      'assets/svg/categories/cati.svg',
  'Mobilya Yapım ve Montaj':
      'assets/svg/categories/mobilya.svg',
  'Marangozluk ve Ahşap İşleri':
      'assets/svg/categories/marangoz.svg',
  'Kapı Montaj ve Tamir':
      'assets/svg/categories/kapi.svg',
  'Cam Balkon Sistemleri':
      'assets/svg/categories/cam.svg',
  'PVC ve Alüminyum Doğrama':
      'assets/svg/categories/pvc.svg',
  'Demir Doğrama ve Kaynak':
      'assets/svg/categories/demir.svg',
  'Çilingir ve Kilit':
      'assets/svg/categories/cilingir.svg',
  'Bahçe ve Peyzaj':
      'assets/svg/categories/bahce.svg',
  'Havuz Yapım ve Bakım':
      'assets/svg/categories/havuz.svg',
  'Nakliyat ve Taşımacılık':
      'assets/svg/categories/nakliyat.svg',
  'Kurye ve Küçük Taşıma':
      'assets/svg/categories/kurye.svg',
  'Asansör Montaj ve Bakım':
      'assets/svg/categories/asansor.svg',
  'Mühendislik ve Proje':
      'assets/svg/categories/muhendislik.svg',
  'Oto Çekici ve Yol Yardım':
      'assets/svg/categories/oto_yardim.svg',
  'Oto Servis ve Bakım':
      'assets/svg/categories/oto_servis.svg',
  'Araç Temizlik ve Detaylı Bakım':
      'assets/svg/categories/oto_temizlik.svg',
  'Özel Ders':
      'assets/svg/categories/ozel_ders.svg',
  'Yabancı Dil Eğitimi':
      'assets/svg/categories/yabanci_dil.svg',
  'Sürücü Eğitimi':
      'assets/svg/categories/surucu.svg',
  'Spor ve Kişisel Antrenör':
      'assets/svg/categories/spor.svg',
  'Müzik Dersleri':
      'assets/svg/categories/muzik.svg',
  'Yazılım ve Web Hizmetleri':
      'assets/svg/categories/yazilim.svg',
  'Grafik ve Logo Tasarım':
      'assets/svg/categories/tasarim.svg',
  'Dijital Pazarlama':
      'assets/svg/categories/pazarlama.svg',
  'Fotoğraf Çekimi':
      'assets/svg/categories/fotograf.svg',
  'Etkinlik ve Organizasyon':
      'assets/svg/categories/organizasyon.svg',
  'Evcil Hayvan Hizmetleri':
      'assets/svg/categories/evcil_hayvan.svg',
  'Güzellik ve Bakım Hizmetleri':
      'assets/svg/categories/guzellik.svg',

  // ⚠ HİZMET LİDERİ YAPISIYLA AÇILAN ÜÇ KATEGORİ (14 Ağu).
  'Ayakkabı ve Deri İşleri':
      'assets/svg/categories/ayakkabi_deri.svg',
  'Terzilik ve Dikiş':
      'assets/svg/categories/terzilik.svg',
  'Ev Tekstili':
      'assets/svg/categories/ev_tekstili.svg',

  // ── PROFESYONEL / OFİS HİZMETLERİ (16 Ağu) ──
  //
  // ⚠ Beşi de AYRI çizim; paylaşım yok. Ortak dil korundu:
  // 24×24 kutu, tek renk #1D6BE3, çizgi kalınlığı 1.7 (ince
  // ayrıntılarda 1.4-1.6), raster yok.
  'Avukatlık ve Hukuk':
      'assets/svg/categories/hukuk.svg',
  'Muhasebe ve Mali Müşavirlik':
      'assets/svg/categories/muhasebe.svg',
  'İş Güvenliği ve İSG':
      'assets/svg/categories/is_guvenligi.svg',
  'Marka ve Patent':
      'assets/svg/categories/marka_patent.svg',
  'Sigorta':
      'assets/svg/categories/sigorta.svg',
};

/// Kategori ikonu — bilinmeyen ad için teknik güvenlik ağı.
///
/// ⚠ `ic_build` YALNIZ teknik fallback'tir: katalogdaki 53 kategoriden
/// hiçbiri buraya düşmez. Yalnız silinmiş/yeniden adlandırılmış bir ad
/// elde kalırsa UI çökmesin diye durur.
String categoryIcon(String c) =>
    kKategoriIkonu[c] ?? 'assets/svg/ic_build.svg';

/// Küçük kare kategori rozeti (liste/başlık kullanımı).
///
/// ⚠ FOTOĞRAF ÇİZMEZ — YALNIZ SVG.
///
/// İŞ KURALI: kategori fotoğrafı (`assets/categories/*.jpg`) YALNIZCA
/// ilan verme ekranındaki kategori ızgarasında görünür. Bu rozet ilan
/// verme dışındaki ekranlarda (kategori detayı vb.) kullanılır ve
/// oralarda fotoğraf İSTENMEZ; bu yüzden `categoryAsset` burada
/// OKUNMAZ. Fotoğraflı kart için tek bileşen: `KategoriKarti`.
class CategoryBadge extends StatelessWidget {
  final String category;
  final double size;
  const CategoryBadge(this.category, {super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .26);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: const Color(0xFFEFF4FD), borderRadius: radius),
      child: RefSvg(categoryIcon(category), size: size * .5, color: RC.blue),
    );
  }
}

/// ⚠ `CategoryCover` KALDIRILDI.
///
/// Geniş fotoğraflı kapak bileşeniydi ve HİÇBİR EKRANDA
/// kullanılmıyordu. Kategori fotoğrafı artık yalnız ilan verme
/// ızgarasında (`KategoriKarti`) çizildiği için, ölü fotoğraf
/// bileşeninin kodda kalması yanlışlıkla yeniden kullanılma riski
/// taşıyordu. Kapak gerekirse SVG rozetiyle (`CategoryBadge`)
/// yapılmalıdır.

/// ── ⚠ İLAN BAŞLIĞINDAN KATEGORİ ADI ──
///
/// İlan kartlarında ve detay ekranlarında hizmet adının ÜSTÜNDE
/// gösterilir. Sebep: hizmet adı tek başına AYIRT ETMİYOR.
/// "Sözleşme İnceleme" başlığını gören kullanıcı bunun hukuk işi mi,
/// tesisat mı, elektrik mi olduğunu anlayamıyordu.
///
/// ⚠ ÇATI DEĞİL KATEGORİ gösterilir. "Sözleşme İnceleme" için çatı
/// "Mühendislik & Danışmanlık"tır ve hiçbir şeyi ayırt etmez;
/// ayırt eden ad "Avukatlık ve Hukuk"tur.
///
/// ⚠ KATEGORİ İLANDA SAKLANMIYOR: `Listing` modelinde kategori alanı
/// yok, yalnız `title` var. Ad katalogda geriye aranarak bulunuyor —
/// ikon seçimi de bugün aynı yolu kullanıyor (`_ldIkon`), yani yeni
/// bir kırılganlık EKLENMİYOR, var olan yol paylaşılıyor.
///
/// ⚠ Bulunamazsa `null` döner ve çağıran taraf satırı HİÇ ÇİZMEZ —
/// boş bir etiket ya da "Diğer" gibi uydurma bir ad gösterilmez.
///
/// ⚠ Başlık zaten kategori adının kendisiyse (kullanıcı ana kategori
/// seçtiyse) `null` döner: aynı ad iki kez alt alta yazılmaz.
String? kategoriAdi(String baslik) {
  final t = baslik.trim();
  if (t.isEmpty) {
    return null;
  }
  if (kCategoryTree.containsKey(t)) {
    return null; // başlığın kendisi kategori
  }
  // ── ⚠ ÖNCE KESİN EŞLEŞME ──
  //
  // Eskiden doğrudan `SearchService.services(t).first.category`
  // okunuyordu. Arama SIRALAMA yapar: alias, kısmi eşleşme ve
  // kategori niyeti aynı listeye girer, dolayısıyla ilk vuruş her
  // zaman ARANAN HİZMETİN kendisi olmayabilir — yanlış kategori
  // yazılabilirdi.
  //
  // Katalogda birebir aynı adı taşıyan hizmet varsa kategorisi
  // TARTIŞMASIZDIR; önce ona bakılır.
  for (final h in kTreeServices) {
    if (h.service == t) {
      return h.category == t ? null : h.category;
    }
  }

  // ── SONRA ARAMA ──
  //
  // Başlık katalogda birebir yoksa (kullanıcı düzenlemiş olabilir)
  // arama son çare olarak denenir.
  final vurus = SearchService.services(t);
  if (vurus.isEmpty) {
    return null;
  }
  final ad = vurus.first.category;
  return ad == t ? null : ad;
}
