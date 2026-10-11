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
const Map<String, String> kKategoriIkonu = {
  // ⚠ ÖLÜ KAYITLAR TEMİZLENDİ: yeni katalogda bulunmayan altı eski
  // kategori (Kombi Montaj, Cam Balkon Sistemleri vb.) tabloda
  // kalmıştı; hiç eşleşmiyorlardı.
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
  // ⚠ Tek kombi kategorisi (ayrı "Kombi Montaj" kilitli katalogda yok).
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
  'Araç ve Ekipman Kiralama':
      'assets/svg/categories/arac_kiralama.svg',
  'Kurye ve Küçük Taşıma':
      'assets/svg/categories/kurye.svg',
  'Asansör Montaj ve Bakım':
      'assets/svg/categories/asansor.svg',
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

  // ── ⚠ YENİ KATALOG (24 ÇATI · 160 KATEGORİ) ──
  //
  // Tablo 63 kayıtlıydı ve 15 çatılı eski katalog dönemine aitti;
  // yeni kataloğun 103 kategorisi eşleşmiyor ve hepsi VARSAYILAN
  // `ic_build.svg`ye düşüyordu — listelerde aynı simge tekrar
  // ediyor, hiçbir şeyi ayırt etmiyordu.
  //
  // ⚠ İKON PAYLAŞIMI YALNIZ ONAYLI GRUPLARDA (11 Eki).
  //
  // Aynı çatı ekranında yan yana duran kategoriler ayırt edilebilmeli;
  // bu yüzden 64 kategoriye kendi konusunu gösteren AYRI çizim
  // eklendi (aynı aile: 24×24, tek renk #1D6BE3, çizgi 1.7, dolgu
  // yok). Ortak kullanım yalnız aynı konunun BAŞKA çatıdaki karşılığı
  // için kalır (müzik, yazılım, dil, eğitim, bina, kalkan, klima,
  // tören, halı/koltuk) ve test bu listeyi kilitler
  // (`ana_ekran_kategoriler_test` → `_onayliPaylasim`).
  'Oto Ekspertiz': 'assets/svg/categories/oto_ekspertiz.svg',
  'Kaporta ve Boya': 'assets/svg/categories/kaporta_boya.svg',
  'Lastik ve Jant Hizmetleri': 'assets/svg/categories/lastik_jant.svg',
  'Oto Görsel & Koruma Hizmetleri': 'assets/svg/categories/oto_koruma.svg',
  'Güneş Enerjisi Sistemleri': 'assets/svg/categories/gunes_enerjisi.svg',
  'Jeneratör Servisi': 'assets/svg/categories/elektrik.svg',
  'Kompresör ve Basınçlı Hava Sistemleri': 'assets/svg/categories/kompresor.svg',
  'Endüstriyel Otomasyon ve Kontrol': 'assets/svg/categories/otomasyon.svg',
  'Endüstriyel Makine ve Ekipman Servisi': 'assets/svg/categories/endustriyel_makine.svg',
  'Havalandırma Sistemleri': 'assets/svg/categories/klima.svg',
  'Küçük Ev Aletleri': 'assets/svg/categories/kucuk_ev_aletleri.svg',
  'Kuru Temizleme': 'assets/svg/categories/kuru_temizleme.svg',
  'Zemin ve Yüzey Temizliği': 'assets/svg/categories/zemin_temizligi.svg',
  'Depolama Hizmetleri': 'assets/svg/categories/depolama.svg',
  'Personel ve Öğrenci Servisi': 'assets/svg/categories/servis_araci.svg',
  'Masaj ve Wellness': 'assets/svg/categories/masaj.svg',
  'Spor': 'assets/svg/categories/spor.svg',
  'Sauna, Hamam & Spa': 'assets/svg/categories/sauna.svg',
  'Kişisel Gelişim ve Koçluk': 'assets/svg/categories/ozel_ders.svg',
  'Teknik ve Hobi Eğitimleri': 'assets/svg/categories/hobi_egitim.svg',
  'Kodlama ve Yazılım Eğitimi': 'assets/svg/categories/yazilim.svg',
  'Video ve Animasyon': 'assets/svg/categories/video_animasyon.svg',
  'Video, Ses & Animasyon': 'assets/svg/categories/video_ses.svg',
  'Müzik & Ses Prodüksiyonu': 'assets/svg/categories/muzik.svg',
  'Müzik & Eğlence': 'assets/svg/categories/muzik.svg',
  'Catering ve İkram': 'assets/svg/categories/catering.svg',
  'Etkinlik Personeli': 'assets/svg/categories/etkinlik_personeli.svg',
  'Fuar & Stand Hizmetleri': 'assets/svg/categories/fuar_stand.svg',
  'Çelik Yapı & Prefabrik Yapılar': 'assets/svg/categories/celik_yapi.svg',
  'Endüstriyel Yapı & Kurulum': 'assets/svg/categories/endustriyel_yapi.svg',
  'Pergola & Gölgelendirme Sistemleri': 'assets/svg/categories/pergola.svg',
  'Kepenk Sistemleri': 'assets/svg/categories/kepenk.svg',
  'Kapı Sistemleri': 'assets/svg/categories/kapi.svg',
  'Cam Film ve Kış Bahçesi': 'assets/svg/categories/kis_bahcesi.svg',
  'Cam ve Ayna Hizmetleri': 'assets/svg/categories/cam.svg',
  'Cam & Alüminyum': 'assets/svg/categories/cam_aluminyum.svg',
  'Zemin & Beton': 'assets/svg/categories/beton.svg',
  'Perde Hizmetleri': 'assets/svg/categories/perde.svg',
  'Örgü ve Triko': 'assets/svg/categories/orgu.svg',
  'Nakış ve Tekstil İşleme': 'assets/svg/categories/nakis.svg',
  'Kumaş ve Tekstil İşleme': 'assets/svg/categories/kumas.svg',
  'Terzilik ve Dikim': 'assets/svg/categories/terzilik.svg',
  'Mimari Proje': 'assets/svg/categories/muhendislik.svg',
  'Statik ve Yapı Projeleri': 'assets/svg/categories/statik.svg',
  'Mekanik Projeler': 'assets/svg/categories/mekanik_proje.svg',
  'Proje Danışmanlığı': 'assets/svg/categories/proje_danismanligi.svg',
  'Yapı Denetim': 'assets/svg/categories/yapi_denetim.svg',
  'Harita ve Ölçüm': 'assets/svg/categories/harita_olcum.svg',
  'Elektrik Projeleri': 'assets/svg/categories/elektrik.svg',
  'Zemin ve Jeoteknik': 'assets/svg/categories/jeoteknik.svg',
  'Enerji ve Yapı Belgelendirme': 'assets/svg/categories/enerji_belgesi.svg',
  'Ofis & İş Yeri Hizmetleri': 'assets/svg/categories/ofis.svg',
  'Dış Ticaret & Gümrük': 'assets/svg/categories/dis_ticaret.svg',
  // ⚠ Onaylı paylaşım: dil teması, "Yabancı Dil Eğitimi" ile AYNI
  // (farklı çatı).
  'Tercüme ve Çeviri Hizmetleri': 'assets/svg/categories/yabanci_dil.svg',
  'Teşvik & Hibe Danışmanlığı': 'assets/svg/categories/tesvik_hibe.svg',
  // ⚠ Emlak Danışmanlığı onaylı paylaşımla `insaat.svg` kullanır
  // (bina teması, farklı çatı); aynı çatıdaki diğer ikisi kendi
  // ikonlarını aldı.
  'Emlak Danışmanlığı': 'assets/svg/categories/insaat.svg',
  'Site ve Apartman Yönetimi': 'assets/svg/categories/site_yonetimi.svg',
  'Gayrimenkul Hizmetleri': 'assets/svg/categories/gayrimenkul.svg',
  'Özel Güvenlik': 'assets/svg/categories/guvenlik.svg',
  'Yakın Koruma': 'assets/svg/categories/yakin_koruma.svg',
  'Güvenlik Personeli': 'assets/svg/categories/guvenlik_personeli.svg',
  'Hasta Bakımı': 'assets/svg/categories/saglik_bakim.svg',
  'Yaşlı Bakımı': 'assets/svg/categories/yasli_bakimi.svg',
  'Evde Hasta Bakımı': 'assets/svg/categories/evde_hasta.svg',
  'Evde Yaşlı Bakımı': 'assets/svg/categories/evde_yasli.svg',
  'Hastane Refakatçisi': 'assets/svg/categories/refakat.svg',
  'Evde Refakat': 'assets/svg/categories/evde_refakat.svg',
  'Günlük Yaşam Desteği': 'assets/svg/categories/gunluk_yasam.svg',
  'Geleneksel ve Tamamlayıcı Sağlık Uygulamaları': 'assets/svg/categories/saglik_geleneksel.svg',
  'Psikolojik Danışmanlık ve Terapi': 'assets/svg/categories/psikoloji.svg',
  'Diyetisyen ve Beslenme Danışmanlığı': 'assets/svg/categories/diyetisyen.svg',
  'Fizyoterapi ve Rehabilitasyon': 'assets/svg/categories/fizyoterapi.svg',
  'Evde Hemşirelik Hizmetleri': 'assets/svg/categories/hemsirelik.svg',
  'Tarım Danışmanlığı': 'assets/svg/categories/tarim.svg',
  'Tarla ve Bahçe İşleri': 'assets/svg/categories/tarla.svg',
  'Tarımsal Sulama': 'assets/svg/categories/sulama.svg',
  'Bitki Koruma ve İlaçlama': 'assets/svg/categories/bitki_koruma.svg',
  'Hayvancılık Hizmetleri': 'assets/svg/categories/hayvancilik.svg',
  'Veteriner Hizmetleri': 'assets/svg/categories/veteriner.svg',
  'Tur Organizasyon': 'assets/svg/categories/tur.svg',
  'Konaklama': 'assets/svg/categories/konaklama.svg',
  'Transfer ve Ulaşım': 'assets/svg/categories/transfer.svg',
  'Seyahat Danışmanlığı': 'assets/svg/categories/seyahat.svg',
  'Rehberlik': 'assets/svg/categories/rehberlik.svg',
  'Vize & Seyahat İşlemleri': 'assets/svg/categories/vize.svg',
  'Kartvizit & Kurumsal Baskı': 'assets/svg/categories/matbaa_kartvizit.svg',
  'Broşür & Tanıtım Baskıları': 'assets/svg/categories/brosur.svg',
  'Davetiye & Özel Gün Baskıları': 'assets/svg/categories/matbaa_davetiye.svg',
  'Etiket & Ambalaj Baskıları': 'assets/svg/categories/matbaa_etiket.svg',
  'Promosyon Baskıları': 'assets/svg/categories/promosyon.svg',
  'Kitap & Yayın Baskıları': 'assets/svg/categories/matbaa_brosur.svg',
  '3D Baskı & Üretim': 'assets/svg/categories/matbaa_3d.svg',
  'Tabela & Reklam Uygulamaları': 'assets/svg/categories/matbaa_tabela.svg',
  'Geri Dönüşüm Hizmetleri': 'assets/svg/categories/geri_donusum.svg',
  'Bebek Bakımı': 'assets/svg/categories/cocuk_bakim.svg',
  'Çocuk Bakımı': 'assets/svg/categories/cocuk_bakimi.svg',
  'Oyun & Gelişim Desteği': 'assets/svg/categories/cocuk_oyun.svg',
  'Çocuk Refakat ve Destek': 'assets/svg/categories/cocuk_refakat.svg',
  'Çiçekçilik': 'assets/svg/categories/cicekci.svg',
  'Asistanlık & Günlük Destek': 'assets/svg/categories/asistan.svg',
  'Dedektiflik & Araştırma': 'assets/svg/categories/dedektif.svg',
  'Araştırma & Saha Hizmetleri': 'assets/svg/categories/saha_arastirma.svg',
  'Günlük Eleman & Personel Desteği': 'assets/svg/categories/gunluk_eleman.svg',
  'Bileme ve Keskinleştirme Hizmetleri':
      'assets/svg/categories/bileme.svg',
  // ⚠ Nikah/Kur'an/İlahi onaylı paylaşımla organizasyon, özel ders ve
  // müzik ikonlarını kullanır (farklı çatı); Mevlüt kendi ikonunu aldı.
  'Nikah ve Tören Hizmetleri': 'assets/svg/categories/organizasyon.svg',
  'Mevlüt ve Dua Programları': 'assets/svg/categories/mevlut_dua.svg',
  'Kur\'an-ı Kerim Eğitimi': 'assets/svg/categories/ozel_ders.svg',
  'İlahi ve Dini Musiki': 'assets/svg/categories/muzik.svg',
};

/// Kategori ikonu — bilinmeyen ad için teknik güvenlik ağı.
///
/// ⚠ `ic_build` YALNIZ teknik fallback'tir: katalogdaki 53 kategoriden
/// hiçbiri buraya düşmez. Yalnız silinmiş/yeniden adlandırılmış bir ad
/// elde kalırsa UI çökmesin diye durur.
String categoryIcon(String c) =>
    _sunucuIkonu[c] ?? kKategoriIkonu[c] ?? 'assets/svg/ic_build.svg';

/// ── ⚠ ADMİN PANELİNDEN İKON (yalnız API modu) ──
///
/// Sunucu kataloğu (`GET /categories`) kategori başına `icon` taşıyabilir.
/// YALNIZ uygulama paketinde ZATEN bulunan ikonlar kabul edilir (gömülü
/// eşlemedeki dosyalar); bilinmeyen yol yok sayılır → uygulama hiçbir
/// zaman olmayan bir dosyayı çizmeye çalışmaz. Böylece admin'in eklediği
/// YENİ kategoriye de mevcut ikonlardan biri atanabilir.
final Map<String, String> _sunucuIkonu = {};

/// ── ⚠ ADMİN PANELİNDEN KATEGORİ FOTOĞRAFI (yalnız API modu) ──
///
/// Sunucu kataloğu admin'in yüklediği fotoğrafı göreli yol olarak verir
/// (`/api/v1/categories/photo/katalog/kategori/<uuid>.jpg`). YALNIZ bu
/// kalıp kabul edilir (başka adres/yol yok sayılır) ve API sunucusunun
/// kendi kökenine çözülür; depo özel kalır, görsel API üzerinden gelir.
/// Sunucu fotoğrafı yoksa [categoryPhotoUrl] null döner ve çağıran mevcut
/// paket fotoğrafına ([categoryAsset]) düşer — 166 kategorinin bugünkü
/// görünümü değişmez.
final Map<String, String> _sunucuFoto = {};
final RegExp _sunucuFotoKalibi =
    RegExp(r'^/api/v1/categories/photo/katalog/kategori/[0-9a-f-]{36}\.(jpg|png|webp)$');

void sunucuFotograflariniAyarla(Map<String, String> fotograflar, {required String apiKoku}) {
  _sunucuFoto
    ..clear()
    ..addEntries(fotograflar.entries
        .where((e) => _sunucuFotoKalibi.hasMatch(e.value))
        .map((e) => MapEntry(e.key, '$apiKoku${e.value}')));
}

/// Admin'den yüklenmiş sunucu fotoğrafının tam adresi; yoksa null.
String? categoryPhotoUrl(String category) => _sunucuFoto[category];

void sunucuIkonlariniAyarla(Map<String, String> ikonlar) {
  final paketteki = kKategoriIkonu.values.toSet();
  _sunucuIkonu
    ..clear()
    ..addEntries(ikonlar.entries.where((e) => paketteki.contains(e.value)));
}

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
    final svg = RefSvg(categoryIcon(category), size: size * .5, color: RC.blue);
    // ⚠ SUNUCU FOTOĞRAFI → SVG YEDEĞİ (kullanıcı onayı, 3 Eki — Seçenek 1).
    // Yalnız admin'den yüklenmiş sunucu fotoğrafı (API modu; güvenli yol
    // denetimi `categoryPhotoUrl`'de). Yoksa / yüklenirken / hata olursa
    // bugünkü SVG AYNEN. Kutu ölçüsü, rengi ve köşesi değişmez. Paket
    // fotoğrafı (`categoryAsset`) burada KULLANILMAZ.
    final foto = categoryPhotoUrl(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: const Color(0xFFEFF4FD), borderRadius: radius),
      child: foto == null
          ? svg
          : ClipRRect(
              borderRadius: radius,
              child: Image.network(
                foto,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Web: CORS engelinde tarayıcının <img> öğesine düşer.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                // İlk kare gelene kadar SVG (önbellekteyse anında fotoğraf).
                frameBuilder: (_, child, kare, esZamanli) =>
                    esZamanli || kare != null ? child : svg,
                errorBuilder: (_, __, ___) => svg,
              ),
            ),
    );
  }
}

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
