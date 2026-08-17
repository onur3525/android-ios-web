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
    ad: 'Ev Hizmeti',
    aciklama:
        'Tesisat, elektrik, ısıtma',
    gorsel: 'assets/alanlar/ev.jpg',
    ikon: 'assets/svg/alanlar/ev.svg',
    kategoriler: [
      'Su Tesisatı', 'Doğalgaz', 'Kombi Montaj', 'Kombi Servis',
      'Isıtma Sistemleri', 'Elektrik', 'Güvenlik Sistemleri',
      'Klima Montaj ve Servis', 'Çilingir ve Kilit', 'Bahçe ve Peyzaj',
      'Ev Tekstili'
    ],
  ),
  HizmetAlani(
    ad: 'Araç Hizmeti',
    aciklama:
        'Oto bakım ve onarım',
    gorsel: 'assets/alanlar/arac.jpg',
    ikon: 'assets/svg/alanlar/arac.svg',
    kategoriler: [
      'Oto Çekici ve Yol Yardım', 'Oto Servis ve Bakım',
      'Araç Temizlik ve Detaylı Bakım'
    ],
  ),
  HizmetAlani(
    ad: 'Tamir',
    aciklama:
        'Elektronik ve beyaz eşya',
    gorsel: 'assets/alanlar/tamir.jpg',
    ikon: 'assets/svg/alanlar/tamir.svg',
    kategoriler: [
      'Beyaz Eşya Servisi', 'Elektronik Cihaz Tamiri',
      'Uydu ve Anten Sistemleri', 'İnternet ve Ağ Kurulumu',
      'Ayakkabı ve Deri İşleri', 'Terzilik ve Dikiş'
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
    ad: 'Taşıma',
    aciklama:
        'Nakliyat ve kurye',
    gorsel: 'assets/alanlar/tasima.jpg',
    ikon: 'assets/svg/alanlar/tasima.svg',
    kategoriler: [
      'Nakliyat ve Taşımacılık', 'Kurye ve Küçük Taşıma'
    ],
  ),
  HizmetAlani(
    ad: 'Kişisel Hizmet',
    aciklama:
        'Güzellik, bakım ve spor',
    gorsel: 'assets/alanlar/kisisel.jpg',
    ikon: 'assets/svg/alanlar/kisisel.svg',
    kategoriler: [
      'Güzellik ve Bakım Hizmetleri', 'Spor ve Kişisel Antrenör'
    ],
  ),
  HizmetAlani(
    ad: 'Evcil Hayvan',
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
    ad: 'Dijital Hizmet',
    aciklama:
        'Yazılım, web, tasarım',
    gorsel: 'assets/alanlar/dijital.jpg',
    ikon: 'assets/svg/alanlar/dijital.svg',
    kategoriler: [
      'Yazılım ve Web Hizmetleri', 'Grafik ve Logo Tasarım',
      'Dijital Pazarlama'
    ],
  ),
  HizmetAlani(
    ad: 'Organizasyon',
    aciklama:
        'Etkinlik ve fotoğraf',
    gorsel: 'assets/alanlar/organizasyon.jpg',
    ikon: 'assets/svg/alanlar/organizasyon.svg',
    kategoriler: [
      'Etkinlik ve Organizasyon', 'Fotoğraf Çekimi'
    ],
  ),
  HizmetAlani(
    ad: 'İnşaat & Dekorasyon',
    aciklama:
        'İnşaat ve tadilat',
    gorsel: 'assets/alanlar/insaat.jpg',
    ikon: 'assets/svg/alanlar/insaat.svg',
    kategoriler: [
      'İnşaat ve Kaba Yapı', 'Çatı Yapım ve Onarım',
      'Tadilat ve Yenileme', 'Banyo Tadilat ve Montaj',
      'Mutfak Tadilat ve Dolap', 'Boya ve Badana', 'Alçı ve Sıva İşleri',
      'Duvar Kağıdı ve Dekorasyon', 'Fayans ve Seramik Döşeme',
      'Zemin Kaplama', 'Yalıtım ve Mantolama',
      'PVC ve Alüminyum Doğrama', 'Demir Doğrama ve Kaynak',
      'Cam Balkon Sistemleri', 'Marangozluk ve Ahşap İşleri',
      'Mobilya Yapım ve Montaj', 'Kapı Montaj ve Tamir',
      'Havuz Yapım ve Bakım', 'Asansör Montaj ve Bakım'
    ],
  ),
  HizmetAlani(
    ad: 'Mühendislik & Danışmanlık',
    aciklama:
        'Proje ve danışmanlık',
    gorsel: 'assets/alanlar/muhendislik.jpg',
    ikon: 'assets/svg/alanlar/muhendislik.svg',
    kategoriler: [
      'Mühendislik ve Proje',
      // ── PROFESYONEL / OFİS HİZMETLERİ (16 Ağu) ──
      //
      // ⚠ BU BEŞİ SAHA İŞİ DEĞİL, MESLEK HİZMETİDİR ve doğal yerleri
      // bu çatıdır: çatının açıklaması zaten "Proje ve danışmanlık".
      //
      // ⚠ ALTERNATİF: ayrı bir çatı ("Kurumsal & Profesyonel") açmak.
      // O yol çatı sayısını 12→13 yapar, ana sayfa yerleşimini
      // değiştirir ve yeni bir çatı fotoğrafı + ikonu gerektirir.
      // Ürün kararı verilmediği için MEVCUT çatı kullanıldı; taşımak
      // istenirse bu beş satır yeni çatıya alınır, başka bir yere
      // dokunulmaz.
      'Avukatlık ve Hukuk',
      'Muhasebe ve Mali Müşavirlik',
      'İş Güvenliği ve İSG',
      'Marka ve Patent',
      'Sigorta'
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
  'Oto Anahtarcı': 'Araç Hizmeti',

  // Aynı makine ve kimyayla yıkanır (temizlikçi işi) ama kullanıcı
  // "araç" diye arar; aradığı yer Araç Hizmeti.
  'Araç Döşeme Yıkama': 'Araç Hizmeti',
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

/// ⚠ Bütünlük: her kategori bir çatıya bağlı OLMALI.
bool alanKapsamiTam() =>
    kKategoriAlani.length == kCategoryTree.length &&
    kCategoryTree.keys.every(kKategoriAlani.containsKey);
