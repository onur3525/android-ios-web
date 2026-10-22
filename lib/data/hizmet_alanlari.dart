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
    this.fotoUrl,
  });

  final String ad;
  final String aciklama;
  final String gorsel;
  final String ikon;

  /// ⚠ MEVCUT kategori adları — `kCategoryTree` anahtarları.
  final List<String> kategoriler;

  /// Admin panelinden yüklenen fotoğrafın TAM adresi (yalnız API modu);
  /// yoksa `null` ve kart paket fotoğrafını ([gorsel]) çizer.
  final String? fotoUrl;

  /// Kalıcı kimlik: paket görselinin adı (`assets/alanlar/ev.jpg` → `ev`).
  /// Sunucudaki çatı kaydı (`roofs[].key`) bu anahtarla eşleşir; ad
  /// admin panelinden değişebildiği için kimlik olarak ad KULLANILMAZ.
  String get anahtar {
    final dosya = gorsel.split('/').last;
    final nokta = dosya.lastIndexOf('.');
    return nokta < 0 ? dosya : dosya.substring(0, nokta);
  }
}

/// ── ⚠ ÇATILAR SUNUCUDAN (22 Eki, kullanıcı kararı) ──
///
/// Çatının ADI, AÇIKLAMASI, FOTOĞRAFI ve KATEGORİLERİ admin panelinden
/// yönetilir; uygulama bunları `GET /categories` yanıtındaki `roofs`
/// alanından okur ([sunucuAlanlariniAyarla]). Sunucu verisi yoksa ya da
/// alınamazsa aşağıdaki GÖMÜLÜ liste aynen kullanılır — bugünkü görünüm
/// değişmez. Uygulamanın tanımadığı (paketinde görseli olmayan) çatı
/// anahtarı yok sayılır.
List<HizmetAlani> get kHizmetAlanlari => _sunucuAlanlari ?? kGomuluHizmetAlanlari;

List<HizmetAlani>? _sunucuAlanlari;

/// Admin'den yüklenen çatı fotoğrafı: YALNIZ bu kalıp kabul edilir ve API
/// sunucusunun kendi kökenine çözülür (kategori fotoğraflarıyla aynı kural).
final RegExp _sunucuCatiFotoKalibi =
    RegExp(r'^/api/v1/categories/photo/katalog/kategori/[0-9a-f-]{36}\.(jpg|png|webp)$');

/// Sunucu yanıtındaki `roofs` listesini uygular. Liste yoksa/bozuksa
/// gömülü liste devrede kalır.
void sunucuAlanlariniAyarla(Object? roofs, {required String apiKoku}) {
  if (roofs is! List) {
    return;
  }
  final sunucu = <String, Map<dynamic, dynamic>>{
    for (final r in roofs.whereType<Map<dynamic, dynamic>>())
      if (r['key'] is String) r['key'] as String: r,
  };
  if (sunucu.isEmpty) {
    return;
  }
  final out = <HizmetAlani>[];
  for (final g in kGomuluHizmetAlanlari) {
    final r = sunucu[g.anahtar];
    if (r == null) {
      out.add(g);
      continue;
    }
    final ad = r['name'];
    final aciklama = r['description'];
    final kategoriler = r['categories'];
    final foto = r['photoUrl'];
    out.add(HizmetAlani(
      ad: ad is String && ad.trim().isNotEmpty ? ad : g.ad,
      aciklama: aciklama is String ? aciklama : g.aciklama,
      gorsel: g.gorsel,
      ikon: g.ikon,
      kategoriler: kategoriler is List
          ? kategoriler.whereType<String>().toList()
          : g.kategoriler,
      fotoUrl: foto is String && _sunucuCatiFotoKalibi.hasMatch(foto)
          ? '$apiKoku$foto'
          : null,
    ));
  }
  _sunucuAlanlari = out;
  _kategoriAlani = _esle(out);
}

/// Yalnız testler: sunucu çatılarını kaldırır (gömülü listeye döner).
void sunucuAlanlariniSifirla() {
  _sunucuAlanlari = null;
  _kategoriAlani = _esle(kGomuluHizmetAlanlari);
}

const List<HizmetAlani> kGomuluHizmetAlanlari = [
  HizmetAlani(
    ad: 'Ev & Yaşam',
    aciklama:
        'Tesisatçı, Elektrikçi',
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
        'Oto Tamiri, Lastikçi',
    gorsel: 'assets/alanlar/arac.jpg',
    ikon: 'assets/svg/alanlar/arac.svg',
    kategoriler: [
      'Oto Çekici ve Yol Yardım', 'Oto Servis ve Bakım',
      'Araç Temizlik ve Detaylı Bakım', 'Oto Ekspertiz',
      'Kaporta ve Boya', 'Lastik ve Jant Hizmetleri',
      'Oto Görsel & Koruma Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Beyaz Eşya & Elektronik',
    aciklama:
        'Buzdolabı, Televizyon',
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
        'Ev Temizliği, Halı Yıkama',
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
        'Evden Eve, Kurye',
    gorsel: 'assets/alanlar/tasima.jpg',
    ikon: 'assets/svg/alanlar/tasima.svg',
    kategoriler: [
      'Nakliyat ve Taşımacılık', 'Depolama Hizmetleri',
      'Kurye ve Küçük Taşıma', 'Personel ve Öğrenci Servisi',
      'Araç ve Ekipman Kiralama'
    ],
  ),
  HizmetAlani(
    // ⚠ AD GÜNCELLENDİ: "Güzellik & Bakım & Spor" → içine "Kişisel
    // Gelişim ve Koçluk" kategorisi eklendiğinde (yaşam koçluğu)
    // eski ad bunu TEMSİL ETMİYORDU — güzellik/bakım/spor ile
    // koçluğun ilgisi yok. Kategori TAŞINMADI (referans bütünlüğü
    // için), yalnız çatı adı içeriği doğru yansıtacak şekilde
    // GENİŞLETİLDİ.
    ad: 'Güzellik, Bakım, Spor & Kişisel Gelişim',
    aciklama:
        'Kuaför, Masaj, Spor',
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
        'Pet Kuaför, Bakıcılık',
    gorsel: 'assets/alanlar/evcil.jpg',
    ikon: 'assets/svg/alanlar/evcil.svg',
    kategoriler: [
      'Evcil Hayvan Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Eğitim',
    aciklama:
        'Özel Ders, Yabancı Dil',
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
        'Web Sitesi, Logo, SEO',
    gorsel: 'assets/alanlar/dijital.jpg',
    ikon: 'assets/svg/alanlar/dijital.svg',
    kategoriler: [
      'Yazılım ve Web Hizmetleri', 'Grafik ve Logo Tasarım',
      'Dijital Pazarlama', 'Video ve Animasyon',
      'Müzik & Ses Prodüksiyonu',
      'Video, Ses & Animasyon'
    ],
  ),
  HizmetAlani(
    ad: 'Organizasyon & Etkinlik',
    aciklama:
        'Düğün, Fotoğrafçı',
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
        'Tadilat, Boya, Fayans',
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
      'Zemin & Beton',
      'Sauna, Hamam & Spa'
    ],
  ),
  HizmetAlani(
    ad: 'Teknik Hizmetler',
    aciklama:
        'Jeneratör, Otomasyon',
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
        'Terzi, Perde, Ayakkabı',
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
        'Mimari Proje, Harita Ölçüm',
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
    // ⚠ AD GÜNCELLENDİ: "Hukuk & Finans" → "Tercüme ve Çeviri
    // Hizmetleri" ile "Ofis & İş Yeri Hizmetleri" gibi kategoriler
    // saf hukuk/finans değil, daha geniş PROFESYONEL DANIŞMANLIK
    // hizmetleri — eski ad bunları tam temsil etmiyordu.
    ad: 'Hukuk, Finans & Danışmanlık',
    aciklama:
        'Avukat, Muhasebe',
    gorsel: 'assets/alanlar/hukuk.jpg',
    ikon: 'assets/svg/alanlar/hukuk.svg',
    kategoriler: [
      'Avukatlık ve Hukuk', 'Muhasebe ve Mali Müşavirlik',
      'İş Güvenliği ve İSG', 'Marka ve Patent', 'Sigorta',
      'Ofis & İş Yeri Hizmetleri', 'Dış Ticaret & Gümrük',
      'Teşvik & Hibe Danışmanlığı', 'Tercüme ve Çeviri Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Sağlık Hizmetleri',
    aciklama:
        'Hasta Bakıcı, Hemşire',
    gorsel: 'assets/alanlar/saglik.jpg',
    ikon: 'assets/svg/alanlar/saglik.svg',
    kategoriler: [
      'Hasta Bakımı', 'Yaşlı Bakımı', 'Evde Hasta Bakımı',
      'Evde Yaşlı Bakımı', 'Hastane Refakatçisi', 'Evde Refakat',
      'Günlük Yaşam Desteği',
      'Geleneksel ve Tamamlayıcı Sağlık Uygulamaları',
      'Psikolojik Danışmanlık ve Terapi',
      'Diyetisyen ve Beslenme Danışmanlığı',
      'Fizyoterapi ve Rehabilitasyon', 'Evde Hemşirelik Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Tarım & Hayvancılık',
    aciklama:
        'Veteriner, Tarım',
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
        'Tur Rehberi, Transfer',
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
        'Emlak, Site Yönetimi',
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
        'Güvenlik, Yakın Koruma',
    gorsel: 'assets/alanlar/guvenlik.jpg',
    ikon: 'assets/svg/alanlar/guvenlik.svg',
    kategoriler: [
      'Özel Güvenlik', 'Yakın Koruma', 'Güvenlik Personeli'
    ],
  ),
  HizmetAlani(
    ad: 'Matbaa & Baskı',
    aciklama:
        'Kartvizit, Davetiye',
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
        'Hurda Alımı, Atık Toplama',
    gorsel: 'assets/alanlar/geridonusum.jpg',
    ikon: 'assets/svg/alanlar/geridonusum.svg',
    kategoriler: [
      'Geri Dönüşüm Hizmetleri'
    ],
  ),
  HizmetAlani(
    ad: 'Çocuk & Bebek Bakımı',
    aciklama:
        'Bebek Bakıcı, Oyun Ablası',
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
        'Çiçekçi, Dedektif',
    gorsel: 'assets/alanlar/diger.jpg',
    ikon: 'assets/svg/alanlar/diger.svg',
    kategoriler: [
      'Çiçekçilik', 'Asistanlık & Günlük Destek',
      'Dedektiflik & Araştırma', 'Araştırma & Saha Hizmetleri',
      'Günlük Eleman & Personel Desteği',
      // ⚠ PAZAR ARAŞTIRMASIYLA EKLENDİ (kullanıcı onayıyla) —
      // aktif ve talep gören ("İmam Nikahı Kıyma": yılda 2.463 talep,
      // "Mevlüt Okuma": yalnız İzmir'de 100 hizmet veren) ama
      // katalogda hiç olmayan dini hizmetler. Ayrı bir çatı AÇILMADI
      // (kullanıcı kararı) — mevcut "Diğer Hizmetler" çatısına
      // eklendi.
      'Nikah ve Tören Hizmetleri', 'Mevlüt ve Dua Programları',
      'Kur\'an-ı Kerim Eğitimi', 'İlahi ve Dini Musiki',
      'Bileme ve Keskinleştirme Hizmetleri'
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
  // ⚠ 'Oto Anahtarcı' İSTİSNASI KALDIRILDI: hizmet kilitli katalogda
  // (166/1587) artık YOK; kayıt hiçbir hizmete denk gelmeyen ölü bir
  // satırdı. Katalog o hizmeti geri alırsa istisna da geri eklenir.
  //
  // ⚠ ÇATI ADI GÜNCELLENDİ: Paket A'da "Araç Hizmeti" →
  // "Araç Hizmetleri" oldu.

  // Aynı makine ve kimyayla yıkanır (temizlikçi işi) ama kullanıcı
  // "araç" diye arar; aradığı yer Araç Hizmeti.
  'Araç Döşeme Yıkama': 'Araç Hizmetleri',
};

/// Kategori → VARSAYILAN çatı (etkin çatı listesinden; sunucu verisi
/// gelince yeniden kurulur).
Map<String, String> get kKategoriAlani => _kategoriAlani;

Map<String, String> _kategoriAlani = _esle(kGomuluHizmetAlanlari);

Map<String, String> _esle(List<HizmetAlani> alanlar) => {
      for (final a in alanlar)
        for (final c in a.kategoriler) c: a.ad,
    };

/// İstisna listesindeki çatı adı GÖMÜLÜ addır; çatı admin panelinden
/// yeniden adlandırılmışsa güncel adı anahtar üzerinden bulunur.
String _guncelCatiAdi(String gomuluAd) {
  for (final g in kGomuluHizmetAlanlari) {
    if (g.ad == gomuluAd) {
      for (final a in kHizmetAlanlari) {
        if (a.anahtar == g.anahtar) {
          return a.ad;
        }
      }
    }
  }
  return gomuluAd;
}

/// Bir hizmetin çatısı: istisna varsa o, yoksa kategorisinin çatısı.
///
/// ⚠ TEK KAYNAK. Ekranlar kendi kuralını yazmaz; çatı sorusu buradan
/// sorulur, yoksa istisnalar sessizce atlanır.
String? hizmetAlani(String kategori, String? hizmet) {
  final istisna = hizmet != null ? kHizmetCatiIstisnasi[hizmet] : null;
  return istisna != null ? _guncelCatiAdi(istisna) : kKategoriAlani[kategori];
}

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
bool alanKapsamiTam() {
  final gomulu = _esle(kGomuluHizmetAlanlari);
  return gomulu.length == kGomuluKatalog.length &&
      kGomuluKatalog.keys.every(gomulu.containsKey);
}
