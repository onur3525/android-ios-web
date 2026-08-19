import '../arama_es_anlamlilari.dart';
import '../service_aliases.dart';
import '../izmir.dart';
// ⚠ `kLiderHizmetler` buradan gelir — skorlamada lider avansı için.
import '../category_tree.dart';
import '../models/listing.dart';

class SearchHit {
  final String category;     // eşleşen ana kategori
  final String? subService;  // eşleşen alt hizmet (varsa)

  /// ALIAS SONUCU İSE kullanıcının aradığı alternatif ad.
  ///
  /// ⚠ Bu alan yalnız GÖSTERİM içindir. Seçim akışına giden değerler
  /// daima `category` ve `subService`'tir — yani mevcut katalog
  /// kimlikleri. Alias metni backend'e kategori/hizmet kimliği olarak
  /// GÖNDERİLMEZ.
  final String? aliasEtiketi;

  /// Alias KATEGORİ NİYETİ mi?
  ///
  /// true ise `subService` bilinçli olarak `null`'dır: alternatif ad
  /// mevcut hizmetlerden hiçbirine dürüstçe eşit değildir, kategori
  /// seçilir ve hizmet UYDURULMAZ.
  final bool kategoriNiyeti;

  const SearchHit(this.category,
      [this.subService, this.aliasEtiketi, this.kategoriNiyeti = false]);

  /// Satırda görünen ad — alias varsa kullanıcının yazdığı addır.
  String get label => aliasEtiketi ?? subService ?? category;
}

/// Arama — kategori adı, alt hizmet adı, ilan başlığı ve açıklamasında
/// Türkçe küçük/büyük harf duyarsız arar. Saf fonksiyonlar: unit-testli.
abstract final class SearchService {
  /// ── ⚠ NORMALLEŞTİRME ÖNBELLEKLİ ──
  ///
  /// Kullanıcı arama kutusuna her harf yazdığında katalog baştan sona
  /// taranıyor: 63 kategori + 640 hizmet + 2531 terim + 543 alias,
  /// toplam ~3300 kayıt. Önbelleksiz hâlde HER KAYIT İÇİN, HER TUŞTA
  /// iki `replaceAll` ve bir `toLowerCase` çalışıyordu.
  ///
  /// Katalog adları SABİTTİR; aynı metnin normalleştirilmiş hâli bir
  /// kez hesaplanıp saklanır. Kullanıcı "kombi" yazarken beş tuşun
  /// beşinde de aynı 3300 dönüşüm tekrarlanıyordu.
  ///
  /// ⚠ SONUÇ DEĞİŞMEZ: aynı girdi için aynı çıktı döner; yalnız
  /// tekrar eden hesap atlanır.
  ///
  /// ⚠ Sözlük SINIRSIZ BÜYÜMEZ: anahtarlar katalogdan gelir ve
  /// sayıları sabittir. Kullanıcı sorguları da eklenir ama sorgu
  /// başına tek kayıt olur; sınır aşılırsa temizlenir.
  static final Map<String, String> _foldCache = {};

  /// Önbellek üst sınırı — katalog ~3300 kayıt, kalanı sorgulardır.
  static const int _kFoldCacheSiniri = 6000;

  static String _fold(String s) {
    final hazir = _foldCache[s];
    if (hazir != null) {
      return hazir;
    }
    final sonuc =
        s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    if (_foldCache.length >= _kFoldCacheSiniri) {
      // ⚠ Sınır aşıldıysa tamamı boşaltılır: katalog kayıtları bir
      // sonraki aramada yeniden dolar, sızıntı olmaz.
      _foldCache.clear();
    }
    _foldCache[s] = sonuc;
    return sonuc;
  }

  static bool _match(String hay, String q) => _fold(hay).contains(_fold(q));

  /// ── ÇOK KELİMELİ ARAMA ──
  ///
  /// ⚠ Sorgu KELİMELERE BÖLÜNÜR ve hepsinin bulunması aranır.
  ///
  /// Önceden sorgu TEK PARÇA aranıyordu: "kombi bakım" yazan kullanıcı
  /// sıfır sonuç alıyordu, çünkü katalogdaki ad "Kombi Bakımı"dır ve
  /// tam metin eşleşmiyordu. Kullanıcı insan gibi yazar; motor da
  /// öyle aramalıdır.
  ///
  /// Tek harflik parçalar atlanır ("ve", "ile" gibi bağlaçların tek
  /// harfe düşen hâlleri gürültü yaratıyordu).
  static bool _tumKelimeler(String hay, String q) {
    final h = _fold(hay);
    // ⚠ Sorgu parçaları KAYIT BAŞINA değil, SORGU BAŞINA hesaplanır.
    //
    // Eskiden bu satır her kayıt için yeniden çalışıyordu: 3300
    // kayıtta 3300 kez bölme ve süzme. Sorgu tüm tarama boyunca aynı
    // olduğu için sonucu saklamak yeterli.
    final parcalar = _sorguParcalari(q);
    if (parcalar.isEmpty) {
      return h.contains(_fold(q));
    }
    return parcalar.every(h.contains);
  }

  /// Son sorgunun kelimeleri — tarama boyunca değişmez.
  static String? _sonSorgu;
  static List<String> _sonParcalar = const [];

  static List<String> _sorguParcalari(String q) {
    if (_sonSorgu == q) {
      return _sonParcalar;
    }
    _sonSorgu = q;
    _sonParcalar =
        _fold(q).split(' ').where((p) => p.length > 1).toList(growable: false);
    return _sonParcalar;
  }

  /// KATEGORİ ESKİ ADLARI — arama aliası.
  ///
  /// ⚠ Anahtar YENİ ad, değer ESKİ kısa addır. Yalnız arama içindir;
  /// katalogda ve UI'da yeni ad geçerlidir.
  static const Map<String, String> _eskiKategoriAdi = {
  'Temizlik Hizmetleri': 'Temizlik',
  'İlaçlama ve Haşere Kontrolü': 'İlaçlama',
  'Doğalgaz': 'Doğalgaz',
  // ⚠ Kategori ikiye ayrıldıktan sonra da eski kısa ad ARANABİLİR
  // kalır: kullanıcı "kombi" yazınca iki kategoriyi de bulmalı.
  'Kombi Montaj': 'Kombi',
  'Kombi Servis': 'Kombi',
  'Isıtma Sistemleri': 'Isıtma',
  'Elektrik': 'Elektrik',
  'Klima Montaj ve Servis': 'Klima',
  'Beyaz Eşya Servisi': 'Beyaz Eşya',
  'Elektronik Cihaz Tamiri': 'Elektronik Tamiri',
  'Uydu ve Anten Sistemleri': 'Uydu ve Görüntü Sistemleri',
  'İnternet ve Ağ Kurulumu': 'İnternet ve Ağ',
  'Boya ve Badana': 'Boya',
  'Alçı ve Sıva İşleri': 'Alçı',
  'Tadilat ve Yenileme': 'Tadilat',
  'Banyo Tadilat ve Montaj': 'Banyo',
  'Mutfak Tadilat ve Dolap': 'Mutfak',
  'İnşaat ve Kaba Yapı': 'İnşaat',
  'Fayans ve Seramik Döşeme': 'Seramik',
  'Zemin Kaplama': 'Zemin',
  'Yalıtım ve Mantolama': 'Yalıtım',
  'Çatı Yapım ve Onarım': 'Çatı',
  'Mobilya Yapım ve Montaj': 'Mobilya',
  'Marangozluk ve Ahşap İşleri': 'Marangozluk',
  'Kapı Montaj ve Tamir': 'Kapı',
  'Cam Balkon Sistemleri': 'Cam İşleri',
  'PVC ve Alüminyum Doğrama': 'PVC Pencere',
  'Demir Doğrama ve Kaynak': 'Demir Doğrama',
  'Çilingir ve Kilit': 'Anahtar ve Çilingir',
  'Bahçe ve Peyzaj': 'Bahçe',
  'Havuz Yapım ve Bakım': 'Havuz',
  'Nakliyat ve Taşımacılık': 'Nakliyat',
  'Kurye ve Küçük Taşıma': 'Kurye ve Taşıma',
  'Asansör Montaj ve Bakım': 'Asansör',
  'Mühendislik ve Proje': 'Mühendislik',
  'Oto Çekici ve Yol Yardım': 'Oto Yardım',
  'Oto Servis ve Bakım': 'Oto Servis',
  'Araç Temizlik ve Detaylı Bakım': 'Oto Temizlik',
  'Yabancı Dil Eğitimi': 'Yabancı Dil',
  'Spor ve Kişisel Antrenör': 'Spor',
  'Müzik Dersleri': 'Müzik',
  'Yazılım ve Web Hizmetleri': 'Yazılım',
  'Grafik ve Logo Tasarım': 'Tasarım',
  'Fotoğraf Çekimi': 'Fotoğraf',
  'Etkinlik ve Organizasyon': 'Organizasyon',
  'Evcil Hayvan Hizmetleri': 'Evcil Hayvan',
  'Güzellik ve Bakım Hizmetleri': 'Güzellik',
  };

  /// Sorgu kategorinin ESKİ adıyla eşleşiyor mu?
  static bool _eskiAdEslesti(String kategori, String q) {
    final eski = _eskiKategoriAdi[kategori];
    return eski != null && _tumKelimeler(eski, q);
  }

  /// ── EŞ ANLAMLI EŞLEŞMESİ ──
  ///
  /// ⚠ Kullanıcı hizmet adını değil DERDİNİ yazar: "gaz kaçağı",
  /// "kapıda kaldım", "kombi yanmıyor". Bu terimler katalogda geçmez;
  /// `kAramaEsAnlamlilari` onları hizmete bağlar.
  ///
  /// Eşleşme İKİ YÖNLÜDÜR:
  ///   • terim sorguyu içerir   → "kaçak" → "su kaçağı"
  ///   • sorgu terimi içerir    → "gaz kaçağı var" → "gaz kaçağı"
  ///
  /// Tek yönlü olsaydı kullanıcının fazladan yazdığı kelime ("var",
  /// "acil") eşleşmeyi bozardı.
  static bool _esAnlamliEslesti(String hizmet, String q) {
    final terimler = kAramaEsAnlamlilari[hizmet];
    if (terimler == null) {
      return false;
    }
    final nq = _fold(q);
    for (final t in terimler) {
      final nt = _fold(t);
      if (nt.contains(nq) || _tumKelimeler(nt, q) || nq.contains(nt)) {
        return true;
      }
    }
    return false;
  }

  /// Kategori + alt hizmet eşleşmeleri.
  ///
  /// ⚠ KATEGORİ EŞLEŞİRSE ALT HİZMETLERİNİN TAMAMI LİSTELENİR.
  ///
  /// Önceden yalnız ADI sorguyu içeren kayıtlar dönüyordu: "doğalgaz"
  /// yazan kullanıcı `Doğalgaz` + `Doğalgaz Tesisatı` + `Doğalgaz
  /// Projesi` görüyor, ama aynı kategorinin altındaki `Kombi Montajı`,
  /// `Kombi Bakımı`, `Petek Temizliği` GÖRÜNMÜYORDU — oysa hepsi o
  /// kategorinin hizmetleri.
  ///
  /// Artık iki yoldan biri yeterlidir:
  ///   • alt hizmetin ADI sorguyla eşleşir, VEYA
  ///   • bağlı olduğu ANA KATEGORİ sorguyla eşleşir.
  ///
  /// Her kayıt AYRI bir `SearchHit`'tir; liste tek tek tıklanabilir.
  /// Kaynak tek: `kCategoryTree`. Kataloğa yeni bir kategori ya da alt
  /// hizmet girdiğinde arama onu KENDİLİĞİNDEN gösterir — burada
  /// gömülü liste YOKTUR.
  static List<SearchHit> services(String q, {int enFazla = 40}) {
    final t = q.trim();
    if (t.isEmpty) {
      return const [];
    }
    // ── ⚠ ÖNCE İLGİ DÜZEYİNE GÖRE SIRALA, SONRA KES ──
    //
    // ÖNCEKİ DAVRANIŞ DOĞRU SONUCU GİZLİYORDU.
    //
    // Sonuçlar KATALOG SIRASINDA toplanıp 40'ta kesiliyordu. "te"
    // araması buna örnek: katalogda `te` ile BAŞLAYAN 8 hizmet var
    // (`Temizlik`, `Telefon Tamiri`, `Tenis Dersi`…) ama ilk 40'a
    // yalnız 3'ü giriyordu. 9-12. sıralarda `Halı Yıkama` gibi
    // EŞ ANLAMLI eşleşmeler oturuyor, `Telefon Tamiri` ise listeye
    // hiç giremiyordu.
    //
    // Kısacası: zayıf eşleşme güçlü eşleşmeyi dışarı itiyordu.
    //
    // ÇÖZÜM: her sonuca bir SKOR verilir, önce skora göre sıralanır,
    // kesme EN SONDA yapılır. Aynı skorlu sonuçlar katalog sırasını
    // korur (kararlı sıralama) — liste her tuşta zıplamaz.
    // ⚠ SINIR ARTIK ÇAĞIRANA AİT (`enFazla`).
    //
    // Varsayılan 40'tır ve ana sayfadaki açılır öneri kutusu için
    // doğrudur: orada 320 piksellik bir alana sonuç sığar. Ama TAM
    // EKRAN listelerde (Tüm Kategoriler) kesme yanlış olur; o ekran
    // sınırı yükseltir ve kullanıcı tüm eşleşmeleri kaydırarak görür.
    final nq = _fold(t);

    /// İlgi düzeyi — KÜÇÜK sayı DAHA ÖNCE gelir.
    ///
    /// ⚠ KANONİK AD DAİMA ALIASTAN ÖNCE GELİR. Alias arama kolaylığı
    /// içindir; katalogdaki gerçek ad tam eşleşiyorsa onu geriye
    /// itmek kullanıcıyı şaşırtır.
    ///
    ///   0 · kanonik tam eşleşme   "klima bakımı" → Klima Bakımı
    ///   1 · ALIAS tam eşleşme     "laptop tamiri" → Bilgisayar Tamiri
    ///   2 · kanonik başlangıç     "te"           → Telefon Tamiri
    ///   3 · ALIAS başlangıç       "kalıcı o"     → Manikür Pedikür
    ///   4 · kanonik ad içinde     "tamir"        → Buzdolabı Tamiri
    ///   5 · ALIAS ad içinde
    ///   6 · eş anlamlı            "gaz kaçağı"   → Doğalgaz Kaçak Kontrolü
    ///   7 · kategori üzerinden    "doğalgaz"     → altındaki tüm hizmetler
    ///
    /// Sınır (`enFazla`) BU SIRALAMADAN SONRA uygulanır; alias eklemek
    /// tam eşleşmeyi listenin dışına itmez.
    int skor(String ad, {required bool kategoriUzerinden}) {
      final na = _fold(ad);
      // ── ⚠ LİDER HİZMET AYNI SKORDA ÖNE GEÇER ──
      //
      // Ürün adıyla arayan kullanıcı o ailenin ANA İŞİNİ görmeli:
      //   "ayakkabı" → Ayakkabı Tamiri (kategori satırı değil)
      //   "perde"    → Perde Dikimi   (Perde Yıkama değil)
      //   "kilim"    → Kilim Tamiri   (Kilim Yıkama değil)
      //
      // Bu adlar aynı skoru alıyordu ve sıra KATALOG DİZİLİŞİNE
      // kalıyordu — hangi hizmetin daha üstte yazıldığı belirliyordu.
      // Lider olanlar yarım kademe öne alınır.
      //
      // ⚠ KADEME ATLAMAZ: tam eşleşme (0) hâlâ başlangıç
      // eşleşmesinden (2) önce gelir. Lider yalnız KENDİ kademesinde
      // öne çıkar, zayıf eşleşmeyi güçlünün önüne geçirmez.
      final lider = !kategoriUzerinden && kLiderHizmetler.contains(ad);
      final avans = lider ? 1 : 0;
      if (na == nq) {
        return 0;
      }
      if (na.startsWith(nq)) {
        return 2 - avans;
      }
      if (na.contains(nq)) {
        return 4 - avans;
      }
      return kategoriUzerinden ? 7 : 6;
    }

    /// Alias skoru — kanonik karşılığının bir kademe ARDINDA.
    int aliasSkor(String etiket) {
      final na = aliasNormalize(etiket);
      final an = aliasNormalize(t);
      if (na == an) {
        return 1;
      }
      if (na.startsWith(an)) {
        return 3;
      }
      return 5;
    }

    final skorlu = <({SearchHit hit, int skor, int sira})>[];
    var sira = 0;

    for (final c in kHomeCategories) {
      // ⚠ ESKİ KISA AD DA EŞLEŞİR.
      //
      // Kategori adları anlamlı hâle getirilirken uzadı: "Kombi" →
      // "Kombi" → "Kombi Servis", "Yazılım" → "Yazılım ve Web Hizmetleri".
      // Kullanıcı hâlâ eski kısa adı yazar; alias olmasaydı "kombi"
      // yalnız alt hizmetleri bulur, KATEGORİYİ bulamazdı.
      final kategoriEslesti =
          _tumKelimeler(c, t) || _eskiAdEslesti(c, t);
      if (kategoriEslesti) {
        skorlu.add((
          hit: SearchHit(c),
          skor: skor(c, kategoriUzerinden: false),
          sira: sira++,
        ));
      }
      for (final s in kSubServices[c] ?? const <String>[]) {
        // ⚠ ÜÇ YOLDAN BİRİ YETER:
        //   1. ana kategori eşleşti  → altındakilerin tamamı gelir
        //   2. alt hizmet adı eşleşti
        //   3. EŞ ANLAMLI terim eşleşti ("gaz kaçağı" → Doğalgaz Tesisatı)
        final adEslesti = _tumKelimeler(s, t);
        final esAnlamli = !adEslesti && _esAnlamliEslesti(s, t);
        if (!kategoriEslesti && !adEslesti && !esAnlamli) {
          continue;
        }
        skorlu.add((
          hit: SearchHit(c, s),
          // Ad eşleşmesi kategori eşleşmesinden GÜÇLÜDÜR: kategori
          // eşleştiği için gelen hizmet en sona düşer.
          skor: adEslesti
              ? skor(s, kategoriUzerinden: false)
              : (esAnlamli ? 6 : 7),
          sira: sira++,
        ));
      }
    }

    // ── ALIAS EŞLEŞMELERİ ──
    //
    // ⚠ ALIAS KATALOĞA GİRMEZ, ARAMAYA GİRER. Kullanıcı "Laptop
    // Tamiri" yazar; katalogda o ad yoktur ama `Bilgisayar Tamiri"
    // vardır. Alias satırı kullanıcının yazdığı adı gösterir, seçim
    // ise MEVCUT kategori/hizmet kimliğini taşır.
    //
    // Aynı hedefe iki yoldan varılmışsa (hem kanonik ad hem alias
    // eşleşti) alias satırı EKLENMEZ — liste kendini tekrar etmez.
    final varOlan = {
      for (final e in skorlu) '${e.hit.category}|${e.hit.subService ?? ''}',
    };
    for (final a in aliasAra(t)) {
      final anahtar = '${a.kategori}|${a.kanonikHizmet ?? ''}';
      if (varOlan.contains(anahtar)) {
        continue;
      }
      varOlan.add(anahtar);
      skorlu.add((
        hit: SearchHit(
            a.kategori, a.kanonikHizmet, a.etiket, !a.hizmetAliasi),
        skor: aliasSkor(a.etiket),
        sira: sira++,
      ));
    }

    // Kararlı sıralama: skor eşitse KATALOG SIRASI korunur.
    skorlu.sort((a, b) =>
        a.skor != b.skor ? a.skor.compareTo(b.skor) : a.sira.compareTo(b.sira));

    // ⚠ KESME EN SONDA. Katalog 251 hizmet içeriyor; tek harflik sorgu
    // 269 sonuç döndürüyordu ve hepsi `shrinkWrap: true` bir
    // `ListView`'e giriyordu — 320px kutuda 6 satır görünürken.
    return [
      for (final e in skorlu.take(enFazla)) e.hit,
    ];
  }

  /// Açık ilanlarda başlık + açıklama eşleşmesi.
  static List<Listing> listings(Iterable<Listing> all, String q) {
    final t = q.trim();
    if (t.isEmpty) {
      return const [];
    }
    return all
        .where((l) =>
            l.status == ListingStatus.active &&
            (_match(l.title, t) || _match(l.desc, t)))
        .toList();
  }
}
