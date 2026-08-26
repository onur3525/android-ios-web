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
      'Bahçe ve Peyzaj', 'Havuz Yapım ve Bakım', 'Su Tesisatı',
      'Doğalgaz', 'Kombi Servis', 'Isıtma Sistemleri', 'Elektrik',
      'Güvenlik Sistemleri', 'Klima Montaj ve Servis',
      'Çilingir ve Kilit', 'Uydu ve Anten Sistemleri',
      'İnternet ve Ağ Kurulumu', 'Güneş Enerjisi Sistemleri'
    ],
  ),
  HizmetAlani(
    ad: 'Araç Hizmetleri',
    aciklama:
        'Oto bakım ve yol yardım',
    gorsel: 'assets/alanlar/arac.jpg',
    ikon: 'assets/svg/alanlar/arac.svg',
    kategoriler: [
      'Oto Çekici ve Yol Yardım', 'Oto Servis ve Bakım',
      'Araç Temizlik ve Detaylı Bakım', 'Oto Ekspertiz',
      'Kaporta ve Boya', 'Lastik ve Jant Hizmetleri',
      'Oto Görsel & Koruma Hizmetleri', 'Oto Bakım & Servis'
    ],
  ),
  HizmetAlani(
    ad: 'Beyaz Eşya & Elektronik',
    aciklama:
        'Beyaz eşya ve cihaz',
    gorsel: 'assets/alanlar/tamir.jpg',
    ikon: 'assets/svg/alanlar/tamir.svg',
    kategoriler: [
      'Beyaz Eşya Servisi', 'Elektronik Cihaz Tamiri',
      'Küçük Ev Aletleri'
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
      'İlaçlama ve Haşere Kontrolü', 'Kuru Temizleme',
      'Zemin ve Yüzey Temizliği'
    ],
  ),
  HizmetAlani(
    ad: 'Taşıma & Nakliyat',
    aciklama:
        'Nakliyat ve kurye',
    gorsel: 'assets/alanlar/tasima.jpg',
    ikon: 'assets/svg/alanlar/tasima.svg',
    kategoriler: [
      'Nakliyat ve Taşımacılık', 'Depolama Hizmetleri',
      'Kurye ve Küçük Taşıma', 'Personel ve Öğrenci Servisi',
      'Depolama & Lojistik'
    ],
  ),
  HizmetAlani(
    ad: 'Güzellik & Bakım & Spor',
    aciklama:
        'Güzellik, bakım ve spor',
    gorsel: 'assets/alanlar/kisisel.jpg',
    ikon: 'assets/svg/alanlar/kisisel.svg',
    kategoriler: [
      'Güzellik ve Bakım Hizmetleri', 'Masaj ve Wellness', 'Spor',
      'Kişisel Gelişim ve Koçluk'
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
      'Müzik Dersleri', 'Kodlama ve Yazılım Eğitimi',
      'Teknik ve Hobi Eğitimleri'
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
      'Dijital Pazarlama', 'Video ve Animasyon',
      'Müzik & Ses Prodüksiyonu', 'Dijital Pazarlama & Reklam',
      'Video, Ses & Animasyon'
    ],
  ),
  HizmetAlani(
    ad: 'Organizasyon & Etkinlik',
    aciklama:
        'Etkinlik ve fotoğraf',
    gorsel: 'assets/alanlar/organizasyon.jpg',
    ikon: 'assets/svg/alanlar/organizasyon.svg',
    kategoriler: [
      'Etkinlik ve Organizasyon', 'Fotoğraf Çekimi',
      'Catering ve İkram', 'Etkinlik Personeli', 'Müzik & Eğlence',
      'Fuar & Stand Hizmetleri'
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
      'Mutfak Tadilat ve Dolap', 'Boya ve Badana',
      'Alçı ve Sıva İşleri', 'Duvar Kağıdı ve Dekorasyon',
      'Fayans ve Seramik Döşeme', 'Zemin Kaplama',
      'Yalıtım ve Mantolama', 'PVC ve Alüminyum Doğrama',
      'Demir Doğrama ve Kaynak', 'Marangozluk ve Ahşap İşleri',
      'Mobilya Yapım ve Montaj', 'Asansör Montaj ve Bakım',
      'Havalandırma Sistemleri', 'Çelik Yapı & Prefabrik Yapılar',
      'Pergola & Gölgelendirme Sistemleri', 'Cam Film ve Kış Bahçesi',
      'Cam ve Ayna Hizmetleri', 'Kapı Sistemleri', 'Kepenk Sistemleri',
      'Endüstriyel Yapı & Kurulum', 'Cam & Alüminyum',
      'Kapı & Pencere', 'Pergola & Gölgelendirme', 'Zemin & Beton',
      'Sauna, Hamam & Spa'
    ],
  ),
  HizmetAlani(
    ad: 'Teknik Hizmetler',
    aciklama:
        'Tesisat ve elektrik',
    gorsel: 'assets/alanlar/teknik.jpg',
    ikon: 'assets/svg/alanlar/teknik.svg',
    kategoriler: [
      'Jeneratör Servisi', 'Kompresör ve Basınçlı Hava Sistemleri',
      'Endüstriyel Makine ve Ekipman Servisi',
      'Endüstriyel Otomasyon ve Kontrol'
    ],
  ),
  HizmetAlani(
    ad: 'Giyim & Tekstil',
    aciklama:
        'Terzilik ve tekstil',
    gorsel: 'assets/alanlar/giyim.jpg',
    ikon: 'assets/svg/alanlar/giyim.svg',
    kategoriler: [
      'Ayakkabı ve Deri İşleri', 'Ev Tekstili', 'Perde Hizmetleri',
      'Örgü ve Triko', 'Nakış ve Tekstil İşleme',
      'Kumaş ve Tekstil İşleme', 'Terzilik ve Dikim'
    ],
  ),
  HizmetAlani(
    ad: 'Mühendislik & Proje',
    aciklama:
        'Proje ve mühendislik',
    gorsel: 'assets/alanlar/muhendislik.jpg',
    ikon: 'assets/svg/alanlar/muhendislik.svg',
    kategoriler: [
      'Mimari Proje', 'Statik ve Yapı Projeleri', 'Elektrik Projeleri',
      'Mekanik Projeler', 'Harita ve Ölçüm', 'Zemin ve Jeoteknik',
      'Enerji ve Yapı Belgelendirme', 'Proje Danışmanlığı',
      'Yapı Denetim'
    ],
  ),
  HizmetAlani(
    ad: 'Hukuk & Finans',
    aciklama:
        'Hukuk ve muhasebe',
    gorsel: 'assets/alanlar/hukuk.jpg',
    ikon: 'assets/svg/alanlar/hukuk.svg',
    kategoriler: [
      'Avukatlık ve Hukuk', 'Muhasebe ve Mali Müşavirlik',
      'İş Güvenliği ve İSG', 'Marka ve Patent', 'Sigorta',
      'Ofis & İş Yeri Hizmetleri', 'Dış Ticaret & Gümrük',
      'Teşvik & Hibe Danışmanlığı'
    ],
  ),
  HizmetAlani(
    ad: 'Sağlık Hizmetleri',
    aciklama:
        'Bakım ve destek',
    gorsel: 'assets/alanlar/saglik.jpg',
    ikon: 'assets/svg/alanlar/saglik.svg',
    kategoriler: [
      'Hasta Bakımı', 'Yaşlı Bakımı', 'Evde Hasta Bakımı',
      'Evde Yaşlı Bakımı', 'Hastane Refakatçisi', 'Evde Refakat',
      'Günlük Yaşam Desteği',
      'Geleneksel ve Tamamlayıcı Sağlık Uygulamaları'
    ],
  ),
  HizmetAlani(
    ad: 'Tarım & Hayvancılık',
    aciklama:
        'Tarım ve hayvancılık',
    gorsel: 'assets/alanlar/tarim.jpg',
    ikon: 'assets/svg/alanlar/tarim.svg',
    kategoriler: [
      'Tarım Danışmanlığı', 'Tarla ve Bahçe İşleri', 'Tarımsal Sulama',
      'Bitki Koruma ve İlaçlama', 'Hayvancılık Hizmetleri',
      'Veteriner Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Turizm & Konaklama',
    aciklama:
        'Turizm ve konaklama',
    gorsel: 'assets/alanlar/turizm.jpg',
    ikon: 'assets/svg/alanlar/turizm.svg',
    kategoriler: [
      'Tur Organizasyon', 'Konaklama', 'Transfer ve Ulaşım',
      'Seyahat Danışmanlığı', 'Rehberlik', 'Vize & Seyahat İşlemleri'
    ],
  ),
  HizmetAlani(
    ad: 'Gayrimenkul & Emlak',
    aciklama:
        'Emlak ve danışmanlık',
    gorsel: 'assets/alanlar/emlak.jpg',
    ikon: 'assets/svg/alanlar/emlak.svg',
    kategoriler: [
      'Emlak Danışmanlığı', 'Site ve Apartman Yönetimi',
      'Gayrimenkul Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Özel Güvenlik & Koruma',
    aciklama:
        'Güvenlik ve koruma',
    gorsel: 'assets/alanlar/guvenlik.jpg',
    ikon: 'assets/svg/alanlar/guvenlik.svg',
    kategoriler: [
      'Özel Güvenlik', 'Yakın Koruma', 'Güvenlik Personeli'
    ],
  ),
  HizmetAlani(
    ad: 'Matbaa & Baskı',
    aciklama:
        'Matbaa ve baskı',
    gorsel: 'assets/alanlar/matbaa.jpg',
    ikon: 'assets/svg/alanlar/matbaa.svg',
    kategoriler: [
      'Kartvizit & Kurumsal Baskı', 'Broşür & Tanıtım Baskıları',
      'Davetiye & Özel Gün Baskıları', 'Etiket & Ambalaj Baskıları',
      'Promosyon Baskıları', 'Kitap & Yayın Baskıları',
      '3D Baskı & Üretim', 'Tabela & Reklam Uygulamaları'
    ],
  ),
  HizmetAlani(
    ad: 'Geri Dönüşüm & Atık Yönetimi',
    aciklama:
        'Geri dönüşüm ve atık',
    gorsel: 'assets/alanlar/geridonusum.jpg',
    ikon: 'assets/svg/alanlar/geridonusum.svg',
    kategoriler: [
      'Geri Dönüşüm Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Çocuk & Bebek Bakımı',
    aciklama:
        'Çocuk ve bebek bakımı',
    gorsel: 'assets/alanlar/cocuk.jpg',
    ikon: 'assets/svg/alanlar/cocuk.svg',
    kategoriler: [
      'Bebek Bakımı', 'Çocuk Bakımı', 'Oyun & Gelişim Desteği',
      'Çocuk Refakat ve Destek'
    ],
  ),
  HizmetAlani(
    ad: 'Diğer Hizmetler',
    aciklama:
        'Diğer hizmetler',
    gorsel: 'assets/alanlar/diger.jpg',
    ikon: 'assets/svg/alanlar/diger.svg',
    kategoriler: [
      'Çiçekçilik', 'Asistanlık & Günlük Destek',
      'Dedektiflik & Araştırma', 'Araştırma & Saha Hizmetleri',
      'Günlük Eleman & Personel Desteği'
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
