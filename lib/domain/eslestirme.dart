import '../core/turkce_arama.dart';
import '../data/category_tree.dart';

/// ═══════════════════════════════════════════════════════════════
/// İLAN ↔ HİZMET VEREN EŞLEŞTİRMESİ — TEK KURAL MERKEZİ
///
/// Saf fonksiyonlardır: widget, controller ve ağ bilmezler; testten
/// doğrudan çağrılırlar.
///
/// ## ⚠ KULLANICIYA HİÇBİR ŞEY SÖYLENMEZ
///
/// Aşağıdaki "yakın kategori / aile" kavramı YALNIZ İÇ İŞLEYİŞTİR.
/// Ekranda etiket, rozet, açıklama ya da soru olarak GÖRÜNMEZ;
/// hizmet verene "bu ilan yakın kategoriden geldi" denmez, ayar
/// sorulmaz. Tek görünen etki SIRALAMADIR.
///
/// ## KURAL
///
/// Bir ilanın hizmet verene düşüp düşmeyeceği ve LİSTEDEKİ ÖNCELİĞİ
/// iki kademede belirlenir:
///
///   0 · DOĞRUDAN — hizmet verenin seçtiği hizmetin kendisi
///   1 · AİLE     — seçtiği ana kategoriyle aynı aileden gelen iş
///
/// Doğrudan eşleşenler listede ÖNCE gelir; aile eşleşmeleri onların
/// ARDINA eklenir.
/// ═══════════════════════════════════════════════════════════════

/// Eşleşme yok.
const int kEslesmeYok = -1;

/// Hizmet verenin kendi seçtiği hizmet.
const int kEslesmeDogrudan = 0;

/// Aynı aileden gelen iş.
const int kEslesmeAile = 1;

/// ANA KATEGORİ AİLELERİ — birbirinin işini yapabilen kategoriler.
///
/// ⚠ NİÇİN VAR: müşteri işini hangi kategoriye yazacağını çoğu zaman
/// bilmez. Banyo tadilatı için `İnşaat`, doğalgaz için `Isıtma
/// Sistemleri` seçebilir. O ilan, işi gerçekten yapan ustaya hiç
/// düşmüyordu.
///
/// ⚠ AİLELER DAR TUTULUR. İlk taslakta `Doğrama · Kapı · Cam ·
/// Çilingir` tek aileydi; ölçümde çilingire `PVC Pencere Montajı`
/// ilanı düştüğü görüldü. Aile ikiye bölündü. Aynı gerekçeyle
/// `Zemin kaplama` ile `Yüzey & dekor` ayrıldı.
///
/// ⚠ Buradaki adlar KATALOG KİMLİKLERİDİR (`kCategoryTree`
/// anahtarları); ekranda görünen kısa adlar değil.
///
/// ⚠ Katalogdaki 54 kategorinin 41'i bir aileye girer. Kalan 13'ü
/// (Yalıtım, Çatı, Bahçe, Havuz, Asansör, Mühendislik, Yazılım,
/// Grafik, Dijital Pazarlama, Fotoğraf, Etkinlik, Evcil Hayvan,
/// Güzellik) tek başına durur — onlarda karışma sorunu yoktur ve
/// kapsamları GENİŞLEMEZ.
const List<List<String>> kKategoriAileleri = [
  [
    'Kombi Montaj',
    'Kombi Servis',
    'Isıtma Sistemleri',
    'Doğalgaz',
    'Su Tesisatı',
  ],
  [
    'Tadilat ve Yenileme',
    'Banyo Tadilat ve Montaj',
    'Mutfak Tadilat ve Dolap',
    'İnşaat ve Kaba Yapı',
  ],
  [
    'Beyaz Eşya Servisi',
    'Elektronik Cihaz Tamiri',
    'Klima Montaj ve Servis',
  ],
  [
    'Mobilya Yapım ve Montaj',
    'Marangozluk ve Ahşap İşleri',
  ],
  [
    'PVC ve Alüminyum Doğrama',
    'Demir Doğrama ve Kaynak',
    'Cam Balkon Sistemleri',
  ],
  [
    'Kapı Montaj ve Tamir',
    'Çilingir ve Kilit',
  ],
  [
    'Fayans ve Seramik Döşeme',
    'Zemin Kaplama',
  ],
  [
    'Boya ve Badana',
    'Alçı ve Sıva İşleri',
    'Duvar Kağıdı ve Dekorasyon',
  ],
  [
    'Temizlik Hizmetleri',
    'Halı Yıkama',
    'Koltuk ve Döşeme Yıkama',
    'İlaçlama ve Haşere Kontrolü',
  ],
  [
    'Nakliyat ve Taşımacılık',
    'Kurye ve Küçük Taşıma',
  ],
  [
    'Oto Çekici ve Yol Yardım',
    'Oto Servis ve Bakım',
    'Araç Temizlik ve Detaylı Bakım',
  ],
  [
    'Özel Ders',
    'Yabancı Dil Eğitimi',
    'Sürücü Eğitimi',
    'Spor ve Kişisel Antrenör',
    'Müzik Dersleri',
  ],
  [
    'Elektrik',
    'Güvenlik Sistemleri',
    'İnternet ve Ağ Kurulumu',
    'Uydu ve Anten Sistemleri',
  ],
];

/// Kategori → ailesindeki kategoriler (kendisi dâhil).
Map<String, Set<String>> get kAileHaritasi {
  final m = <String, Set<String>>{};
  for (final aile in kKategoriAileleri) {
    for (final c in aile) {
      m[c] = aile.toSet();
    }
  }
  return m;
}

/// Verilen adın ANA kategorisi. Ad zaten ana kategoriyse kendisi,
/// alt hizmetse bağlı olduğu ana kategori, katalogda yoksa kendisi.
String anaKategoriAdi(String ad) {
  if (kCategoryTree.containsKey(ad)) {
    return ad;
  }
  for (final e in kCategoryTree.entries) {
    if (e.value.contains(ad)) {
      return e.key;
    }
  }
  return ad;
}

/// Ad katalogda bir ANA kategori mi?
bool anaKategoriMi(String ad) => kCategoryTree.containsKey(ad);

/// ── KADEME 0 — DOĞRUDAN EŞLEŞME ──
///
/// ⚠ İKİ YÖNLÜDÜR. Eski kural yalnız ilanı ana kategoriye çıkarıyor,
/// hizmet verenin seçimini çıkarmıyordu: usta `Ev Temizliği` seçmiş,
/// müşteri `Temizlik Hizmetleri` yazmışsa ilan HİÇ düşmüyordu.
/// Ölçüm: 251 alt hizmetin 250'si kendi ana kategorisiyle verilmiş
/// ilanı görmüyordu.
///
/// Kural:
///   · adlar aynıysa eşleşir, veya
///   · aynı ANA kategoriye bağlılarsa ve TARAFLARDAN BİRİ ana
///     kategori seçmişse eşleşir.
///
/// ⚠ İKİ FARKLI ALT HİZMET BİRBİRİNE AÇILMAZ: `Buzdolabı Tamiri`
/// seçen usta `Fırın Tamiri` ilanını görmez. Aksi hâlde belirli bir
/// hizmeti seçmenin anlamı kalmazdı.
bool dogrudanEslesir(String secim, String ilanBasligi) {
  final s = turkceNormalize(secim);
  final i = turkceNormalize(ilanBasligi);
  if (s.isEmpty || i.isEmpty) {
    return false;
  }
  if (s == i) {
    return true;
  }
  if (turkceNormalize(anaKategoriAdi(secim)) !=
      turkceNormalize(anaKategoriAdi(ilanBasligi))) {
    return false;
  }
  return anaKategoriMi(secim) || anaKategoriMi(ilanBasligi);
}

/// ── KADEME 1 — AİLE EŞLEŞMESİ ──
///
/// ⚠ YALNIZ ANA KATEGORİ SEÇENE UYGULANIR.
///
/// Ölçüm: aile bağı her seçimde açılırsa bir hizmet verenin gördüğü
/// başlık sayısı ortalama 1,8'den 19,4'e çıkıyor — `Buzdolabı Tamiri`
/// seçen ustaya 30 ayrı başlığın ilanı düşüyordu. Ana kategori
/// şartıyla ortalama 4,6'da kalıyor.
///
/// Böylece seçim bir TERCİHE dönüşür:
///   · geniş kategori seçtin → aileden de iş alırsın
///   · belirli hizmeti seçtin → yalnız onu alırsın
bool aileEslesir(String secim, String ilanBasligi) {
  if (!anaKategoriMi(secim)) {
    return false;
  }
  final aile = kAileHaritasi[secim];
  if (aile == null) {
    return false;
  }
  return aile.contains(anaKategoriAdi(ilanBasligi));
}

/// İLANIN ÖNCELİĞİ — [kEslesmeDogrudan], [kEslesmeAile] veya
/// [kEslesmeYok].
///
/// [secimler] hizmet verenin seçtiği kategori/alt hizmet adlarıdır.
///
/// ⚠ SEÇİM YAPILMAMIŞSA kısıt uygulanmaz: onboarding tamamlanmadan
/// ekran boş kalmasın diye her ilan DOĞRUDAN sayılır.
int eslesmeOnceligi(Iterable<String> secimler, String ilanBasligi) {
  if (secimler.isEmpty) {
    return kEslesmeDogrudan;
  }
  var aileVar = false;
  for (final s in secimler) {
    if (dogrudanEslesir(s, ilanBasligi)) {
      return kEslesmeDogrudan;
    }
    if (!aileVar && aileEslesir(s, ilanBasligi)) {
      aileVar = true;
    }
  }
  return aileVar ? kEslesmeAile : kEslesmeYok;
}

/// İlan hizmet verene düşer mi?
bool ilanUygun(Iterable<String> secimler, String ilanBasligi) =>
    eslesmeOnceligi(secimler, ilanBasligi) != kEslesmeYok;
