// HİZMET ALANLARI — ANA SAYFA ÇATI KATMANI
//
// ⚠ BUNLAR ANA KATEGORİ DEĞİLDİR.
//
// Gerçek katalog (`kCategoryTree`) DEĞİŞMEZ: 63 kategori, 640 hizmet
// aynen durur. Bu dosya yalnız ANA SAYFADA gösterilen çatı/kısayol
// katmanını tanımlar. Hiçbir sayaca, ızgaraya, aramaya girmez.
//
// ⚠ ON İKİ ÇATI (15 Ağu, ürün kararı). Önceki on çatılı yapıda
// Ev Hizmeti 264 hizmetle katalogun yarısını taşıyordu; İnşaat &
// Dekorasyon, Evcil Hayvan ve Mühendislik & Danışmanlık ayrıldı.
//
// ⚠ HİZMET DÜZEYİNDE İSTİSNA VAR (yeni).
//
// Eskiden bir hizmetin çatısı ZORUNLU olarak kategorisinin çatısıydı.
// Bu yetmedi: "Oto Anahtarcı" Çilingir kategorisinde ama kullanıcı
// onu Araç Hizmeti altında arar. Kategori varsayılan çatısını korur,
// tek tek hizmetler `kHizmetCatiIstisnasi` ile başka çatıya gider.
//
// ⚠ İSTİSNA AZ OLMALI. Her istisna kategori-çatı ilişkisini zayıflatır;
// listeye eklemeden önce "kategorinin tamamı mı yanlış yerde?" diye
// sorulmalı.

import 'category_tree.dart';

/// Bir çatı alanı: ad, açıklama ve VARSAYILAN kategorileri.
class HizmetAlani {
  const HizmetAlani({
    required this.ad,
    required this.aciklama,
    required this.gorsel,
    required this.ikon,
    required this.kategoriler,
  });

  final String ad;
  final String aciklama;
  final String gorsel;
  final String ikon;

  /// ⚠ MEVCUT kategori adları — `kCategoryTree` anahtarları.
  final List<String> kategoriler;
}

const List<HizmetAlani> kHizmetAlanlari = [
  HizmetAlani(
    ad: 'Ev & Yaşam',
    aciklama:
        'Bahçe, havuz ve ev işleri',
    gorsel: 'assets/alanlar/ev.jpg',
    ikon: 'assets/svg/alanlar/ev.svg',
    kategoriler: [
      'Bahçe ve Peyzaj', 'Havuz Yapım ve Bakım'
    ],
  ),
  HizmetAlani(
    ad: 'Araç Hizmetleri',
    aciklama:
        'Oto bakım ve yol yardım',
    gorsel: 'assets/alanlar/arac.jpg',
    ikon: 'assets/svg/alanlar/arac.svg',
    kategoriler: [
      'Oto Servis ve Bakım', 'Araç Temizlik ve Detaylı Bakım',
      'Oto Çekici ve Yol Yardım'
    ],
  ),
  HizmetAlani(
    ad: 'Beyaz Eşya & Elektronik Servis',
    aciklama:
        'Beyaz eşya ve cihaz tamiri',
    gorsel: 'assets/alanlar/tamir.jpg',
    ikon: 'assets/svg/alanlar/tamir.svg',
    kategoriler: [
      'Beyaz Eşya Servisi', 'Elektronik Cihaz Tamiri'
    ],
  ),
  HizmetAlani(
    ad: 'Temizlik',
    aciklama:
        'Ev, ofis ve halı yıkama',
    gorsel: 'assets/alanlar/temizlik.jpg',
    ikon: 'assets/svg/alanlar/temizlik.svg',
    kategoriler: [
      'Temizlik Hizmetleri', 'Halı Yıkama', 'Koltuk ve Döşeme Yıkama',
      'İlaçlama ve Haşere Kontrolü'
    ],
  ),
  HizmetAlani(
    ad: 'Taşıma & Nakliyat',
    aciklama:
        'Nakliyat ve kurye',
    gorsel: 'assets/alanlar/tasima.jpg',
    ikon: 'assets/svg/alanlar/tasima.svg',
    kategoriler: [
      'Nakliyat ve Taşımacılık', 'Kurye ve Küçük Taşıma'
    ],
  ),
  HizmetAlani(
    ad: 'Güzellik & Kişisel Bakım',
    aciklama:
        'Güzellik, bakım ve spor',
    gorsel: 'assets/alanlar/kisisel.jpg',
    ikon: 'assets/svg/alanlar/kisisel.svg',
    kategoriler: [
      'Güzellik ve Bakım Hizmetleri', 'Spor ve Kişisel Antrenör'
    ],
  ),
  HizmetAlani(
    ad: 'Evcil Hayvan Hizmetleri',
    aciklama:
        'Pet bakım ve kuaför',
    gorsel: 'assets/alanlar/evcil.jpg',
    ikon: 'assets/svg/alanlar/evcil.svg',
    kategoriler: [
      'Evcil Hayvan Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Eğitim',
    aciklama:
        'Özel ders, dil, müzik',
    gorsel: 'assets/alanlar/egitim.jpg',
    ikon: 'assets/svg/alanlar/egitim.svg',
    kategoriler: [
      'Özel Ders', 'Yabancı Dil Eğitimi', 'Sürücü Eğitimi',
      'Müzik Dersleri'
    ],
  ),
  HizmetAlani(
    ad: 'Dijital Hizmetler',
    aciklama:
        'Yazılım, web, tasarım',
    gorsel: 'assets/alanlar/dijital.jpg',
    ikon: 'assets/svg/alanlar/dijital.svg',
    kategoriler: [
      'Yazılım ve Web Hizmetleri', 'Grafik ve Logo Tasarım',
      'Dijital Pazarlama', 'Fotoğraf Çekimi'
    ],
  ),
  HizmetAlani(
    ad: 'Organizasyon & Etkinlik',
    aciklama:
        'Etkinlik ve fotoğraf',
    gorsel: 'assets/alanlar/organizasyon.jpg',
    ikon: 'assets/svg/alanlar/organizasyon.svg',
    kategoriler: [
      'Etkinlik ve Organizasyon'
    ],
  ),
  HizmetAlani(
    ad: 'İnşaat & Dekorasyon',
    aciklama:
        'İnşaat ve tadilat',
    gorsel: 'assets/alanlar/insaat.jpg',
    ikon: 'assets/svg/alanlar/insaat.svg',
    kategoriler: [
      'Mutfak Tadilat ve Dolap', 'Banyo Tadilat ve Montaj',
      'Boya ve Badana', 'Zemin Kaplama', 'Çatı Yapım ve Onarım',
      'İnşaat ve Kaba Yapı', 'Tadilat ve Yenileme',
      'Alçı ve Sıva İşleri', 'Duvar Kağıdı ve Dekorasyon',
      'Fayans ve Seramik Döşeme', 'Yalıtım ve Mantolama',
      'PVC ve Alüminyum Doğrama', 'Demir Doğrama ve Kaynak',
      'Cam Balkon Sistemleri', 'Marangozluk ve Ahşap İşleri',
      'Mobilya Yapım ve Montaj', 'Kapı Montaj ve Tamir'
    ],
  ),
  HizmetAlani(
    ad: 'Teknik Hizmetler',
    aciklama:
        'Tesisat ve elektrik',
    gorsel: 'assets/alanlar/teknik.jpg',
    ikon: 'assets/svg/alanlar/teknik.svg',
    kategoriler: [
      'Su Tesisatı', 'Doğalgaz', 'Kombi Servis', 'Isıtma Sistemleri',
      'Elektrik', 'Güvenlik Sistemleri', 'Klima Montaj ve Servis',
      'Çilingir ve Kilit', 'Uydu ve Anten Sistemleri',
      'İnternet ve Ağ Kurulumu',
      'Kombi Montaj',
      'Asansör Montaj ve Bakım'
    ],
  ),
  HizmetAlani(
    ad: 'Giyim & Tekstil',
    aciklama:
        'Terzilik ve ev tekstili',
    gorsel: 'assets/alanlar/giyim.jpg',
    ikon: 'assets/svg/alanlar/giyim.svg',
    kategoriler: [
      'Terzilik ve Dikiş', 'Ayakkabı ve Deri İşleri', 'Ev Tekstili'
    ],
  ),
  HizmetAlani(
    ad: 'Mühendislik & Proje',
    aciklama:
        'Proje ve mühendislik',
    gorsel: 'assets/alanlar/muhendislik.jpg',
    ikon: 'assets/svg/alanlar/muhendislik.svg',
    kategoriler: [
      'Mühendislik ve Proje'
    ],
  ),
  HizmetAlani(
    ad: 'Hukuk, Finans & Kurumsal',
    aciklama:
        'Hukuk ve muhasebe',
    gorsel: 'assets/alanlar/hukuk.jpg',
    ikon: 'assets/svg/alanlar/hukuk.svg',
    kategoriler: [
      'Avukatlık ve Hukuk', 'Muhasebe ve Mali Müşavirlik', 'Sigorta',
      'İş Güvenliği ve İSG', 'Marka ve Patent'
    ],
  ),
];

/// ── HİZMET DÜZEYİNDE ÇATI İSTİSNASI ──
///
/// Anahtar: `kCategoryTree` içindeki BİR HİZMET adı.
/// Değer: o hizmetin görüneceği çatı — kategorisinin çatısı DEĞİL.
///
/// ⚠ GEREKÇE her madde için ayrı yazılır; gerekçesiz istisna eklenmez.
const Map<String, String> kHizmetCatiIstisnasi = {
  // Mesleği çilingir ama kullanıcı aracın yanında kalmışken
  // Araç Hizmeti çatısına bakar.
  // ⚠ ÇATI ADI GÜNCELLENDİ: Paket A'da "Araç Hizmeti" →
  // "Araç Hizmetleri" oldu; bu iki istisna eski adı işaret ettiği
  // için HİÇBİR çatıya eşleşmiyordu — sessizce etkisiz kalmışlardı.
  'Oto Anahtarcı': 'Araç Hizmetleri',

  // Aynı makine ve kimyayla yıkanır (temizlikçi işi) ama kullanıcı
  // "araç" diye arar; aradığı yer Araç Hizmeti.
  'Araç Döşeme Yıkama': 'Araç Hizmetleri',
};

/// Kategori → VARSAYILAN çatı.
final Map<String, String> kKategoriAlani = {
  for (final a in kHizmetAlanlari)
    for (final c in a.kategoriler) c: a.ad,
};

/// Bir hizmetin çatısı: istisna varsa o, yoksa kategorisinin çatısı.
///
/// ⚠ TEK KAYNAK. Ekranlar kendi kuralını yazmaz; çatı sorusu buradan
/// sorulur, yoksa istisnalar sessizce atlanır.
String? hizmetAlani(String kategori, String? hizmet) =>
    (hizmet != null ? kHizmetCatiIstisnasi[hizmet] : null) ??
    kKategoriAlani[kategori];

/// Bir çatının altında GERÇEKTEN görünen hizmetler.
///
/// ⚠ Kategori listesini okumak YETMEZ: istisna ile giren hizmetler
/// eklenir, çıkan hizmetler düşülür.
List<({String kategori, String hizmet})> alanHizmetleri(String alan) {
  final out = <({String kategori, String hizmet})>[];
  for (final e in kCategoryTree.entries) {
    for (final h in e.value) {
      if (hizmetAlani(e.key, h) == alan) {
        out.add((kategori: e.key, hizmet: h));
      }
    }
  }
  return out;
}

/// ── ⚠ ÇATISIZ KATEGORİLER (sunucudan gelenler) ──
///
/// Çatı eşlemesi (`kKategoriAlani`) uygulamaya gömülüdür: hangi
/// kategorinin hangi çatıda görüneceği bir YERLEŞİM kararıdır ve
/// sunucudan gelmez.
///
/// Admin YENİ bir kategori eklerse o kategori hiçbir çatıya bağlı
/// olmaz. Bu bir hata değildir ve uygulamayı KIRMAZ:
///   · kategori aramada ve "Tüm Kategoriler"de görünür,
///   · ilan verme akışında seçilebilir,
///   · yalnız ana sayfadaki ÇATI kısayolunda listelenmez.
///
/// ⚠ ALTERNATİF DAHA KÖTÜYDÜ: bilinmeyen kategoriyi rastgele bir
/// çatıya atamak, kullanıcıya yanlış yerde gösterirdi. Kategori
/// çatıya bağlanana kadar kısayoldan erişilemez ama ARAMADAN
/// erişilebilir — veri kaybı yoktur.
///
/// ⚠ AÇIK KONU: yeni kategorinin çatısı, ikonu ve fotoğrafı
/// uygulamada tanımlı olmadığı için sürüm gerektirir. Kalıcı çözüm
/// bu üçünün de sunucudan gelmesidir; ürün kararı bekliyor.
List<String> catisizKategoriler() =>
    kCategoryTree.keys.where((c) => !kKategoriAlani.containsKey(c)).toList();

/// ⚠ Bütünlük: GÖMÜLÜ katalogun her kategorisi bir çatıya bağlı
/// OLMALI. Sunucudan gelen yeni kategoriler bu denetimin dışındadır
/// (bkz. `catisizKategoriler`).
bool alanKapsamiTam() =>
    kKategoriAlani.length == kGomuluKatalog.length &&
    kGomuluKatalog.keys.every(kKategoriAlani.containsKey);
