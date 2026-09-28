import 'category_tree.dart';

/// ═══════════════════════════════════════════════════════════════
/// HİZMET ADI ALIASLARI — ARAMA ÇÖZÜMLEME KATMANI
///
/// ## BU DOSYA KATALOG DEĞİLDİR
///
/// ⚠ Buradaki hiçbir ad yeni ana kategori ya da yeni alt hizmet
/// DEĞİLDİR. `kCategoryTree` 63 ana kategori / 640 alt hizmet olarak
/// AYNEN kalır; alias sayısı hiçbir sayaca, ızgaraya, ikon listesine
/// veya kart sayısına girmez.
///
/// Alias, kullanıcının YAZDIĞI addır. İşin sonunda mutlaka MEVCUT bir
/// kategoriye ve — güvenliyse — MEVCUT bir kanonik alt hizmete çözülür.
///
/// ## İKİ TÜR VARDIR VE BİRBİRİNİN YERİNE GEÇMEZ
///
/// · HİZMET ALIASI — alternatif ad, mevcut bir kanonik alt hizmetin
///   güvenli eş anlamlısıdır. "Laptop Tamiri" → `Bilgisayar Tamiri`.
///   Seçilince kullanıcı kanonik adı yazmış gibi davranılır.
///
/// · KATEGORİ NİYETİ ALIASI — alternatif ad o ana kategoriye aittir
///   ama 251 kanonik hizmetten hiçbirine dürüstçe EŞİT DEĞİLDİR.
///   "Nişan Organizasyonu" → `Etkinlik ve Organizasyon` kategorisi;
///   yeni hizmet üretilmez.
///
/// ⚠ KATEGORİ NİYETİ ALIASI ASLA YAKIN BİR ALT HİZMETE ZORLANMAZ.
/// Zorlanırsa arama ve ilan eşleştirmesinde SESSİZ VERİ BOZULMASI
/// olur: kullanıcı bir şey arar, sistem başka bir şey kaydeder.
///
/// ## KAYNAK
///
/// Alias listesi ürün ekibinin 13 Ağustos 2026 tarihli entegrasyon
/// belgesinden gelir (572 satır). Koda 570 kayıt girmiştir; ikisi
/// ("Beyaz Eşya Servisi") ZATEN ANA KATEGORİ ADIDIR,
/// belgenin kendi kuralı gereği ikinci kayıt açılmamıştır.
///
/// Belgedeki kategori adları eski kısa adlardır ("Temizlik",
/// "Oto Temizlik"); buraya KODDAKİ güncel adlarla yazılmıştır.
/// Belge "Halı ve Döşeme Yıkama"yı tek kategori sayıyordu; katalogda
/// ikiye bölündüğü için hedefler doğru yarıya bağlanmıştır.
/// ═══════════════════════════════════════════════════════════════

enum AliasTuru { hizmet, kategoriNiyeti }

class ServiceAlias {
  /// Kullanıcının gördüğü/yazdığı alternatif ad.
  final String etiket;

  /// MUTLAKA mevcut bir ana kategori (`kCategoryTree` anahtarı).
  final String kategori;

  /// Hizmet aliasında ZORUNLU, kategori niyetinde `null`.
  final String? kanonikHizmet;

  final AliasTuru tur;

  const ServiceAlias(this.etiket, this.kategori, String this.kanonikHizmet)
      : tur = AliasTuru.hizmet;

  const ServiceAlias.kategoriNiyeti(this.etiket, this.kategori)
      : kanonikHizmet = null,
        tur = AliasTuru.kategoriNiyeti;

  bool get hizmetAliasi => tur == AliasTuru.hizmet;
}

/// ALIAS NORMALİZASYONU — Türkçe duyarlı.
///
/// ⚠ `toLowerCase()` TEK BAŞINA YANLIŞTIR: Dart'ta 'I'.toLowerCase()
/// 'i' verir, oysa Türkçede 'I' küçüğü 'ı'dır. Önce İ→i ve I→ı
/// dönüşümü yapılır, sonra küçültülür.
///
/// Ayrıca tire/noktalama sadeleşir ve çoklu boşluk teke iner:
/// "Laptop  Tamiri", "laptop-tamiri", "LAPTOP TAMİRİ" aynı anahtara
/// düşer. UI'da kullanıcıya DAİMA düzgün yazım gösterilir.
String aliasNormalize(String s) {
  final k = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final b = StringBuffer();
  var bosluk = false;
  for (final r in k.runes) {
    final c = String.fromCharCode(r);
    final harf = RegExp(r'[0-9a-zçğıöşü]').hasMatch(c);
    if (harf) {
      if (bosluk && b.isNotEmpty) {
        b.write(' ');
      }
      bosluk = false;
      b.write(c);
    } else {
      bosluk = true;
    }
  }
  return b.toString();
}

/// ⚠ TEK KAYNAK. Ekranlar kendi alias listesini yazmaz, bunu çağırır.
const List<ServiceAlias> kServiceAliases = [
  ServiceAlias('Ofis ve İşyeri Temizliği', 'Temizlik Hizmetleri', 'Ofis Temizliği'),
  ServiceAlias('İşyeri Temizliği', 'Temizlik Hizmetleri', 'Ofis Temizliği'),
  ServiceAlias('Dükkan Temizliği', 'Temizlik Hizmetleri', 'Ofis Temizliği'),
  ServiceAlias('Taşınma Öncesi Temizlik', 'Temizlik Hizmetleri', 'Taşınma Temizliği'),
  ServiceAlias('Taşınma Sonrası Temizlik', 'Temizlik Hizmetleri', 'Taşınma Temizliği'),
  ServiceAlias('Tadilat Sonrası Temizlik', 'Temizlik Hizmetleri', 'İnşaat Sonrası Temizlik'),
  ServiceAlias('Buharlı Ev Temizliği', 'Temizlik Hizmetleri', 'Ev Temizliği'),
  ServiceAlias('Günlük Ev Temizliği', 'Temizlik Hizmetleri', 'Ev Temizliği'),
  ServiceAlias('Ev Cam Silme', 'Temizlik Hizmetleri', 'Cam Temizliği'),
  ServiceAlias('Dış Cephe Cam Temizliği', 'Temizlik Hizmetleri', 'Cam Temizliği'),
  ServiceAlias.kategoriNiyeti('Apartman Temizliği', 'Temizlik Hizmetleri'),
  ServiceAlias.kategoriNiyeti('Bina Temizliği', 'Temizlik Hizmetleri'),
  ServiceAlias.kategoriNiyeti('Apartman Merdiven Temizliği', 'Temizlik Hizmetleri'),

  // ── Halı Yıkama ──
  ServiceAlias('Halı Yıkama Temizleme', 'Halı Yıkama', 'Yerinde Halı Yıkama'),
  ServiceAlias('Evde Halı Yıkama', 'Halı Yıkama', 'Yerinde Halı Yıkama'),
  ServiceAlias('Ofis Halı Yıkama', 'Halı Yıkama', 'Yerinde Halı Yıkama'),

  // ── Koltuk ve Döşeme Yıkama ──
  ServiceAlias('Koltuk Yıkama Temizleme', 'Koltuk ve Döşeme Yıkama', 'Koltuk Yıkama'),
  ServiceAlias('Evde Koltuk Yıkama', 'Koltuk ve Döşeme Yıkama', 'Koltuk Yıkama'),
  ServiceAlias('Koltuk Temizleme', 'Koltuk ve Döşeme Yıkama', 'Koltuk Yıkama'),
  ServiceAlias('Yatak Temizliği', 'Koltuk ve Döşeme Yıkama', 'Yatak Yıkama'),
  ServiceAlias('Yatak Yıkama Temizleme', 'Koltuk ve Döşeme Yıkama', 'Yatak Yıkama'),
  ServiceAlias('Tül Perde Yıkama', 'Koltuk ve Döşeme Yıkama', 'Perde Yıkama'),
  ServiceAlias('Zebra Perde Yıkama', 'Koltuk ve Döşeme Yıkama', 'Stor Perde Temizliği'),
  ServiceAlias('Stor Perde Yıkama Temizleme', 'Koltuk ve Döşeme Yıkama', 'Stor Perde Temizliği'),
  ServiceAlias('Yerinde Stor Perde Yıkama', 'Koltuk ve Döşeme Yıkama', 'Stor Perde Temizliği'),

  // ── İlaçlama ve Haşere Kontrolü ──
  ServiceAlias('Hamam Böceği İlaçlama', 'İlaçlama ve Haşere Kontrolü', 'Böcek İlaçlama'),
  ServiceAlias('Yatak Böceği İlaçlama', 'İlaçlama ve Haşere Kontrolü', 'Tahtakurusu İlaçlama'),
  ServiceAlias('Tahta Kurusu İlaçlama', 'İlaçlama ve Haşere Kontrolü', 'Tahtakurusu İlaçlama'),
  ServiceAlias('Fare İlaçlama', 'İlaçlama ve Haşere Kontrolü', 'Fare Mücadelesi'),
  ServiceAlias('Kemirgen Mücadelesi', 'İlaçlama ve Haşere Kontrolü', 'Fare Mücadelesi'),
  ServiceAlias('Genel İlaçlama', 'İlaçlama ve Haşere Kontrolü', 'Haşere İlaçlama'),
  ServiceAlias('Genel Haşere Kontrolü', 'İlaçlama ve Haşere Kontrolü', 'Haşere İlaçlama'),
  ServiceAlias('Toz Böceği İlaçlama', 'İlaçlama ve Haşere Kontrolü', 'Böcek İlaçlama'),
  ServiceAlias.kategoriNiyeti('Akrep İlaçlama', 'İlaçlama ve Haşere Kontrolü'),
  ServiceAlias.kategoriNiyeti('Sinek İlaçlama', 'İlaçlama ve Haşere Kontrolü'),

  // ── Su Tesisatı ──
  ServiceAlias('Tesisatçı', 'Su Tesisatı', 'Su Tesisatçısı'),
  ServiceAlias('Su Tesisatı Döşeme', 'Su Tesisatı', 'Sıhhi Tesisat'),
  ServiceAlias('Temiz Su Tesisatı', 'Su Tesisatı', 'Sıhhi Tesisat'),
  ServiceAlias('Pis Su Tesisatı', 'Su Tesisatı', 'Sıhhi Tesisat'),
  ServiceAlias('Kaçak Su Tespiti', 'Su Tesisatı', 'Su Kaçağı Tespiti'),
  ServiceAlias('Tuvalet Tıkanıklığı Açma', 'Su Tesisatı', 'Tıkanıklık Açma'),
  ServiceAlias('Lavabo Tıkanıklığı Açma', 'Su Tesisatı', 'Tıkanıklık Açma'),
  ServiceAlias('Mutfak Gideri Açma', 'Su Tesisatı', 'Gider Açma'),
  ServiceAlias('Batarya Montajı', 'Su Tesisatı', 'Musluk Montajı'),
  ServiceAlias('Musluk Batarya Değişimi', 'Su Tesisatı', 'Musluk Montajı'),
  ServiceAlias('Su Deposu Yıkama', 'Su Tesisatı', 'Su Deposu Temizliği'),
  ServiceAlias('Musluk Tamiri', 'Su Tesisatı', 'Tesisat Tamiri'),
  ServiceAlias('Batarya Tamiri', 'Su Tesisatı', 'Tesisat Tamiri'),
  ServiceAlias('Klozet Tamiri', 'Su Tesisatı', 'Tesisat Tamiri'),
  ServiceAlias('Gömme Rezervuar Tamiri', 'Su Tesisatı', 'Tesisat Tamiri'),
  ServiceAlias('Kalorifer Tesisatı', 'Su Tesisatı', 'Petek Borusu Tesisatı'),
  ServiceAlias('Radyatör Tesisatı', 'Su Tesisatı', 'Petek Borusu Tesisatı'),
  ServiceAlias('Su Arıtma Cihazı Servisi', 'Su Tesisatı', 'Su Arıtma Servisi'),

  // ── Doğalgaz ──
  // ⚠ 'Doğalgaz İç Tesisatı' ARTIK GERÇEK HİZMET — alias kaydı
  ServiceAlias('Doğalgaz Kolon Tesisatı', 'Doğalgaz', 'Doğalgaz Kolon Hattı'),
  ServiceAlias('Bina Ana Kolon Doğalgaz Hattı', 'Doğalgaz', 'Doğalgaz Kolon Hattı'),
  ServiceAlias('Doğalgaz Ocak Hattı', 'Doğalgaz', 'Doğalgaz İç Tesisatı'),
  ServiceAlias('Doğalgaz Proje Çizimi', 'Doğalgaz', 'Doğalgaz Projesi'),
  ServiceAlias('Gaz Açma', 'Doğalgaz', 'Doğalgaz Projesi'),
  ServiceAlias('Doğalgaz Gaz Açılışı', 'Doğalgaz', 'Doğalgaz Projesi'),
  // ⚠ Tespit artık AYRI hizmet; alias oraya bağlanır.
  ServiceAlias('Gaz Kaçak Tespiti', 'Doğalgaz', 'Doğalgaz Kaçak Tespiti'),
  ServiceAlias('Doğalgaz Boru Değişimi', 'Doğalgaz', 'Doğalgaz Boru Hattı Tadilatı'),
  ServiceAlias('Doğalgaz Hat Tadilatı', 'Doğalgaz', 'Doğalgaz Boru Hattı Tadilatı'),

  // ── Kombi (Montaj + Servis) ──
  ServiceAlias('Kombi Arıza', 'Kombi Servis', 'Kombi Tamiri'),
  ServiceAlias('Kombi Onarım', 'Kombi Servis', 'Kombi Tamiri'),
  ServiceAlias('Kombi Servis Tamiri', 'Kombi Servis', 'Kombi Tamiri'),
  ServiceAlias('Kombi Temizleme', 'Kombi Servis', 'Kombi Bakımı'),
  ServiceAlias('Periyodik Kombi Bakımı', 'Kombi Servis', 'Kombi Bakımı'),
  ServiceAlias('Kombi Sökme Takma', 'Kombi Montaj', 'Kombi Montajı'),
  ServiceAlias('Kombi Yeri Değiştirme', 'Kombi Montaj', 'Kombi Montajı'),
  ServiceAlias('Kombi Yenileme', 'Kombi Montaj', 'Kombi Değişimi'),

  // ── Isıtma Sistemleri ──
  ServiceAlias('Radyatör Petek Temizliği', 'Isıtma Sistemleri', 'Petek Temizliği'),
  ServiceAlias('Radyatör Petek Montajı', 'Isıtma Sistemleri', 'Petek Montajı'),
  ServiceAlias('Panel Radyatör Montajı', 'Isıtma Sistemleri', 'Petek Montajı'),
  ServiceAlias('Yerden Isıtma Sistemi', 'Isıtma Sistemleri', 'Yerden Isıtma'),
  ServiceAlias('Yerden Isıtma Tamiri', 'Isıtma Sistemleri', 'Yerden Isıtma'),
  ServiceAlias('Yerden Isıtma Bakımı', 'Isıtma Sistemleri', 'Yerden Isıtma'),
  ServiceAlias('Yerden Isıtma Temizliği', 'Isıtma Sistemleri', 'Yerden Isıtma'),
  ServiceAlias('Tüplü Şofben Tamiri', 'Isıtma Sistemleri', 'Şofben Tamiri'),
  ServiceAlias('Elektrikli Şofben Tamiri', 'Isıtma Sistemleri', 'Şofben Tamiri'),
  ServiceAlias('Termosifon Servisi', 'Isıtma Sistemleri', 'Termosifon Tamiri'),
  ServiceAlias.kategoriNiyeti('Merkezi Isıtma Sistemi', 'Isıtma Sistemleri'),

  // ── Elektrik ──
  ServiceAlias('Elektrik Montaj', 'Elektrik', 'Elektrik Tesisatı'),
  ServiceAlias('Elektrik Tamiri', 'Elektrik', 'Elektrik Arıza'),
  ServiceAlias('Elektrik Hattı Çekme', 'Elektrik', 'Elektrik Tesisatı'),
  ServiceAlias('Kablo Hattı Çekme', 'Elektrik', 'Elektrik Tesisatı'),
  ServiceAlias('Daire Elektrik Tesisatı', 'Elektrik', 'Elektrik Tesisatı'),
  ServiceAlias('Elektrik Tesisatı Yenileme', 'Elektrik', 'Elektrik Tesisatı'),
  ServiceAlias('Priz Değişimi', 'Elektrik', 'Priz Montajı'),
  ServiceAlias('Işık Anahtarı Montajı', 'Elektrik', 'Anahtar Montajı'),
  ServiceAlias('Anahtar Değişimi', 'Elektrik', 'Anahtar Montajı'),
  ServiceAlias('Avize Takma', 'Elektrik', 'Avize Montajı'),
  ServiceAlias('Lamba Montajı', 'Elektrik', 'Aydınlatma Sistemleri'),
  ServiceAlias('LED Aydınlatma Montajı', 'Elektrik', 'Aydınlatma Sistemleri'),
  ServiceAlias('Elektrik Panosu Montajı', 'Elektrik', 'Sigorta Panosu Montajı'),
  ServiceAlias('Pano Revizyonu', 'Elektrik', 'Elektrik Panosu Yenileme'),
  ServiceAlias.kategoriNiyeti('Topraklama Ölçümü', 'Elektrik'),

  // ── Güvenlik Sistemleri ──
  ServiceAlias('Güvenlik Kamerası Kurulumu', 'Güvenlik Sistemleri', 'Kamera Sistemi Kurulumu'),
  ServiceAlias('Güvenlik Kamera Montajı', 'Güvenlik Sistemleri', 'Kamera Sistemi Kurulumu'),
  ServiceAlias('Kamera Montajı', 'Güvenlik Sistemleri', 'Kamera Sistemi Kurulumu'),
  ServiceAlias('Kamera Sistemleri', 'Güvenlik Sistemleri', 'Kamera Sistemi Kurulumu'),
  ServiceAlias('CCTV Sistemleri', 'Güvenlik Sistemleri', 'Kamera Sistemi Kurulumu'),
  ServiceAlias('Kablosuz Alarm Sistemi', 'Güvenlik Sistemleri', 'Alarm Sistemi Kurulumu'),
  ServiceAlias('Ev Alarm Sistemleri', 'Güvenlik Sistemleri', 'Alarm Sistemi Kurulumu'),
  ServiceAlias('Alarm Güvenlik Sistemi', 'Güvenlik Sistemleri', 'Alarm Sistemi Kurulumu'),
  ServiceAlias('Görüntülü Diafon', 'Güvenlik Sistemleri', 'Görüntülü Diafon Montajı'),
  ServiceAlias('Diafon Sistemleri', 'Güvenlik Sistemleri', 'Görüntülü Diafon Montajı'),
  ServiceAlias('Akıllı Kapı Kilidi', 'Güvenlik Sistemleri', 'Akıllı Kilit'),
  ServiceAlias('Yangın Alarm Sistemi', 'Güvenlik Sistemleri', 'Yangın Algılama'),

  // ── Klima Montaj ve Servis ──
  ServiceAlias('Klima Sökme', 'Klima Montaj ve Servis', 'Klima Montajı'),
  ServiceAlias('Klima Yeri Değiştirme', 'Klima Montaj ve Servis', 'Klima Montajı'),
  ServiceAlias('Klima Soğutmuyor', 'Klima Montaj ve Servis', 'Klima Tamiri'),
  ServiceAlias('Klima Periyodik Bakım', 'Klima Montaj ve Servis', 'Klima Bakımı'),
  ServiceAlias('Klima Yıkama', 'Klima Montaj ve Servis', 'Klima Temizliği'),
  ServiceAlias('Merkezi Klima', 'Klima Montaj ve Servis', 'VRF Sistemleri'),
  ServiceAlias('VRV Klima Servisi', 'Klima Montaj ve Servis', 'VRF Sistemleri'),
  ServiceAlias('VRF Klima Servisi', 'Klima Montaj ve Servis', 'VRF Sistemleri'),
  ServiceAlias.kategoriNiyeti('Klima Servisi', 'Klima Montaj ve Servis'),

  // ── Beyaz Eşya Servisi ──
  ServiceAlias('Buzdolabı Servisi', 'Beyaz Eşya Servisi', 'Buzdolabı Tamiri'),
  ServiceAlias('Çamaşır Makinesi Servisi', 'Beyaz Eşya Servisi', 'Çamaşır Makinesi Tamiri'),
  ServiceAlias('Bulaşık Makinesi Servisi', 'Beyaz Eşya Servisi', 'Bulaşık Makinesi Tamiri'),
  ServiceAlias('Kurutma Makinesi Servisi', 'Beyaz Eşya Servisi', 'Kurutma Makinesi Tamiri'),
  ServiceAlias('Fırın Servisi', 'Beyaz Eşya Servisi', 'Fırın Tamiri'),
  ServiceAlias.kategoriNiyeti('Beyaz Eşya Tamiri', 'Beyaz Eşya Servisi'),

  // ── Elektronik Cihaz Tamiri ──
  ServiceAlias('Laptop Tamiri', 'Elektronik Cihaz Tamiri', 'Bilgisayar Tamiri'),
  ServiceAlias('Laptop Bakımı', 'Elektronik Cihaz Tamiri', 'Bilgisayar Tamiri'),
  ServiceAlias('Masaüstü Bilgisayar Tamiri', 'Elektronik Cihaz Tamiri', 'Bilgisayar Tamiri'),
  ServiceAlias('Televizyon Ekran Tamiri', 'Elektronik Cihaz Tamiri', 'Televizyon Tamiri'),
  ServiceAlias('TV Tamiri', 'Elektronik Cihaz Tamiri', 'Televizyon Tamiri'),
  ServiceAlias('Cep Telefonu Tamiri', 'Elektronik Cihaz Tamiri', 'Telefon Tamiri'),
  ServiceAlias('iPad Tablet Tamiri', 'Elektronik Cihaz Tamiri', 'Tablet Tamiri'),
  ServiceAlias('Playstation Tamiri', 'Elektronik Cihaz Tamiri', 'Oyun Konsolu Tamiri'),
  ServiceAlias('Xbox Tamiri', 'Elektronik Cihaz Tamiri', 'Oyun Konsolu Tamiri'),

  // ── Uydu ve Anten Sistemleri ──
  ServiceAlias('Çanak Anten Montajı', 'Uydu ve Anten Sistemleri', 'Uydu Anteni Kurulumu'),
  ServiceAlias('Uydu Montajı', 'Uydu ve Anten Sistemleri', 'Uydu Anteni Kurulumu'),
  ServiceAlias('Uydu Kurulumu', 'Uydu ve Anten Sistemleri', 'Uydu Anteni Kurulumu'),
  ServiceAlias('Uydu Ayarlama', 'Uydu ve Anten Sistemleri', 'Çanak Anten Ayarı'),
  ServiceAlias('Kanal Ayarlama', 'Uydu ve Anten Sistemleri', 'Çanak Anten Ayarı'),
  ServiceAlias('Çanak Ayarı', 'Uydu ve Anten Sistemleri', 'Çanak Anten Ayarı'),
  ServiceAlias('Merkezi Sistem Uydu', 'Uydu ve Anten Sistemleri', 'Merkezi Uydu Sistemi'),
  ServiceAlias('Merkezi Uydu Kurulumu', 'Uydu ve Anten Sistemleri', 'Merkezi Uydu Sistemi'),
  ServiceAlias('TV Kurulumu', 'Uydu ve Anten Sistemleri', 'Televizyon Duvar Montajı'),
  ServiceAlias('Televizyon Duvara Montaj', 'Uydu ve Anten Sistemleri', 'Televizyon Duvar Montajı'),
  ServiceAlias('TV Duvar Askı Montajı', 'Uydu ve Anten Sistemleri', 'Televizyon Duvar Montajı'),

  // ── İnternet ve Ağ Kurulumu ──
  ServiceAlias('İnternet Kurulum', 'İnternet ve Ağ Kurulumu', 'Modem Kurulumu'),
  ServiceAlias('Modem Kurulum', 'İnternet ve Ağ Kurulumu', 'Modem Kurulumu'),
  ServiceAlias('Router Kurulumu', 'İnternet ve Ağ Kurulumu', 'Modem Kurulumu'),
  ServiceAlias('İnternet Kablosu Çekme', 'İnternet ve Ağ Kurulumu', 'Ağ Kablolama'),
  ServiceAlias('İnternet Hattı Çekme', 'İnternet ve Ağ Kurulumu', 'Ağ Kablolama'),
  ServiceAlias('İnternet Tesisatı', 'İnternet ve Ağ Kurulumu', 'Ağ Kablolama'),
  ServiceAlias('Network Kablolama', 'İnternet ve Ağ Kurulumu', 'Ağ Kablolama'),
  ServiceAlias('Data Kablolama', 'İnternet ve Ağ Kurulumu', 'Ağ Kablolama'),
  ServiceAlias('WiFi Destek', 'İnternet ve Ağ Kurulumu', 'Wifi Güçlendirme'),
  ServiceAlias('WiFi Sinyal Güçlendirme', 'İnternet ve Ağ Kurulumu', 'Wifi Güçlendirme'),
  ServiceAlias('Modem Çekim Alanı Güçlendirme', 'İnternet ve Ağ Kurulumu', 'Wifi Güçlendirme'),
  ServiceAlias('Akıllı Ev Otomasyonu', 'İnternet ve Ağ Kurulumu', 'Akıllı Ev Sistemleri'),

  // ── Boya ve Badana ──
  ServiceAlias('Boyacı', 'Boya ve Badana', 'Boya Badana'),
  ServiceAlias('Boya Badana Ustası', 'Boya ve Badana', 'Boya Badana'),
  ServiceAlias('İç Cephe Boyama', 'Boya ve Badana', 'İç Cephe Boya'),
  ServiceAlias('Dış Cephe Boya', 'Boya ve Badana', 'Dış Cephe Boyama'),
  ServiceAlias('Dekoratif Boyama', 'Boya ve Badana', 'Dekoratif Boya'),
  ServiceAlias('Panel Kapı Boyama', 'Boya ve Badana', 'Kapı Boyama'),
  ServiceAlias('Ahşap Kapı Boyama', 'Boya ve Badana', 'Kapı Boyama'),

  // ── Alçı ve Sıva İşleri ──
  ServiceAlias('Alçıpan Ustası', 'Alçı ve Sıva İşleri', 'Alçıpan'),
  ServiceAlias('Alçıpan Asma Tavan', 'Alçı ve Sıva İşleri', 'Alçıpan'),
  ServiceAlias('Saten Alçı', 'Alçı ve Sıva İşleri', 'Alçı Sıva'),
  ServiceAlias('Sıva Alçı', 'Alçı ve Sıva İşleri', 'Alçı Sıva'),
  ServiceAlias('Kartonpiyer Ustası', 'Alçı ve Sıva İşleri', 'Kartonpiyer'),
  ServiceAlias.kategoriNiyeti('Alçı Tavan', 'Alçı ve Sıva İşleri'),

  // ── Duvar Kağıdı ve Dekorasyon ──
  ServiceAlias('Duvar Kağıdı Kaplama', 'Duvar Kağıdı ve Dekorasyon', 'Duvar Kağıdı Uygulama'),
  ServiceAlias('Duvar Kağıdı Döşeme', 'Duvar Kağıdı ve Dekorasyon', 'Duvar Kağıdı Uygulama'),
  ServiceAlias('TV Arkası Panel', 'Duvar Kağıdı ve Dekorasyon', 'Duvar Paneli'),
  ServiceAlias('MDF Duvar Paneli', 'Duvar Kağıdı ve Dekorasyon', 'Duvar Paneli'),
  ServiceAlias('PVC Duvar Paneli', 'Duvar Kağıdı ve Dekorasyon', 'Duvar Paneli'),
  ServiceAlias('3D Duvar Paneli', 'Duvar Kağıdı ve Dekorasyon', '3D Duvar Kaplama'),
  ServiceAlias('Dekoratif Duvar Kaplama', 'Duvar Kağıdı ve Dekorasyon', '3D Duvar Kaplama'),
  ServiceAlias('Poster Duvar Kağıdı Uygulama', 'Duvar Kağıdı ve Dekorasyon', 'Poster Duvar Kağıdı'),
  ServiceAlias.kategoriNiyeti('Duvar Dekorasyon', 'Duvar Kağıdı ve Dekorasyon'),

  // ── Tadilat ve Yenileme ──
  ServiceAlias('Mağaza Tadilat', 'Tadilat ve Yenileme', 'Dükkan Tadilatı'),
  ServiceAlias('İşyeri Tadilat', 'Tadilat ve Yenileme', 'Dükkan Tadilatı'),
  ServiceAlias('Komple Tadilat', 'Tadilat ve Yenileme', 'Anahtar Teslim Tadilat'),
  ServiceAlias('Anahtar Teslimi Tadilat', 'Tadilat ve Yenileme', 'Anahtar Teslim Tadilat'),
  ServiceAlias('Ev Yenileme', 'Tadilat ve Yenileme', 'Ev Tadilatı'),
  ServiceAlias('Daire Yenileme', 'Tadilat ve Yenileme', 'Daire Tadilatı'),
  ServiceAlias('Ofis Yenileme', 'Tadilat ve Yenileme', 'Ofis Tadilatı'),
  ServiceAlias.kategoriNiyeti('Otel Tadilatı', 'Tadilat ve Yenileme'),
  ServiceAlias.kategoriNiyeti('Fabrika Tadilatı', 'Tadilat ve Yenileme'),
  ServiceAlias.kategoriNiyeti('Klinik Tadilatı', 'Tadilat ve Yenileme'),

  // ── Banyo Tadilat ve Montaj ──
  ServiceAlias('Duşa Kabin', 'Banyo Tadilat ve Montaj', 'Duşakabin Montajı'),
  ServiceAlias('Duşa Kabin Montajı', 'Banyo Tadilat ve Montaj', 'Duşakabin Montajı'),
  ServiceAlias('Lavabo Kurulumu', 'Banyo Tadilat ve Montaj', 'Lavabo Montajı'),
  ServiceAlias('Banyo Dolabı Kurulumu', 'Banyo Tadilat ve Montaj', 'Banyo Dolabı Montajı'),
  ServiceAlias('Komple Banyo Yenileme', 'Banyo Tadilat ve Montaj', 'Banyo Tadilatı'),
  ServiceAlias.kategoriNiyeti('Jakuzi Montajı', 'Banyo Tadilat ve Montaj'),
  ServiceAlias.kategoriNiyeti('Banyo Aksesuar Montajı', 'Banyo Tadilat ve Montaj'),
  ServiceAlias.kategoriNiyeti('Vitrifiye Montajı', 'Banyo Tadilat ve Montaj'),

  // ── Mutfak Tadilat ve Dolap ──
  ServiceAlias('Mutfak Dolabı', 'Mutfak Tadilat ve Dolap', 'Mutfak Dolabı Yapımı'),
  ServiceAlias('Mutfak Dolabı Kaplama', 'Mutfak Tadilat ve Dolap', 'Mutfak Dolabı Tamiri'),
  ServiceAlias('Mutfak Dolabı Kapak Değiştirme', 'Mutfak Tadilat ve Dolap', 'Mutfak Dolabı Tamiri'),
  ServiceAlias('Hazır Mutfak Dolabı Montajı', 'Mutfak Tadilat ve Dolap', 'Hazır Mutfak'),
  ServiceAlias('Komple Mutfak Yenileme', 'Mutfak Tadilat ve Dolap', 'Mutfak Tadilatı'),
  ServiceAlias.kategoriNiyeti('Mutfak Tezgahı', 'Mutfak Tadilat ve Dolap'),
  ServiceAlias.kategoriNiyeti('Mutfak Tezgahı Yapımı', 'Mutfak Tadilat ve Dolap'),
  ServiceAlias.kategoriNiyeti('Granit Mutfak Tezgahı', 'Mutfak Tadilat ve Dolap'),
  ServiceAlias.kategoriNiyeti('Mermer Mutfak Tezgahı', 'Mutfak Tadilat ve Dolap'),

  // ── İnşaat ve Kaba Yapı ──
  ServiceAlias('İnşaat Taahhüt', 'İnşaat ve Kaba Yapı', 'Kaba İnşaat'),
  ServiceAlias('Temel Atma', 'İnşaat ve Kaba Yapı', 'Kaba İnşaat'),
  ServiceAlias('Beton Dökme', 'İnşaat ve Kaba Yapı', 'Şap Atma'),
  ServiceAlias('Şap Dökümü', 'İnşaat ve Kaba Yapı', 'Şap Atma'),
  ServiceAlias('Duvar Ustası', 'İnşaat ve Kaba Yapı', 'Duvar Örme'),
  ServiceAlias('Ytong Duvar', 'İnşaat ve Kaba Yapı', 'Duvar Örme'),
  ServiceAlias('Yıkım', 'İnşaat ve Kaba Yapı', 'Yıkım İşleri'),
  ServiceAlias('Bina Yıkımı', 'İnşaat ve Kaba Yapı', 'Yıkım İşleri'),
  ServiceAlias('Anahtar Teslim Bina Yapımı', 'İnşaat ve Kaba Yapı', 'Anahtar Teslim İnşaat'),

  // ── Fayans ve Seramik Döşeme ──
  ServiceAlias('Karo Fayans Döşeme', 'Fayans ve Seramik Döşeme', 'Fayans Döşeme'),
  ServiceAlias('Fayans Ustası', 'Fayans ve Seramik Döşeme', 'Fayans Döşeme'),
  ServiceAlias('Seramik Ustası', 'Fayans ve Seramik Döşeme', 'Seramik Döşeme'),
  ServiceAlias('Fayans Onarımı', 'Fayans ve Seramik Döşeme', 'Fayans Tamiri'),
  ServiceAlias('Derz Dolgu', 'Fayans ve Seramik Döşeme', 'Derz Yenileme'),
  ServiceAlias('Derz Temizleme', 'Fayans ve Seramik Döşeme', 'Derz Yenileme'),
  ServiceAlias('Granit Döşeme', 'Fayans ve Seramik Döşeme', 'Granit Uygulama'),
  ServiceAlias('Mermer Uygulama', 'Fayans ve Seramik Döşeme', 'Mermer Döşeme'),
  ServiceAlias('Mermer Kaplama', 'Fayans ve Seramik Döşeme', 'Mermer Döşeme'),

  // ── Zemin Kaplama ──
  ServiceAlias('Parke Laminat Döşeme', 'Zemin Kaplama', 'Parke Döşeme'),
  ServiceAlias('Laminat Parke', 'Zemin Kaplama', 'Parke Döşeme'),
  ServiceAlias('Parke Ustası', 'Zemin Kaplama', 'Parke Döşeme'),
  ServiceAlias('Parke Onarımı', 'Zemin Kaplama', 'Parke Tamiri'),
  ServiceAlias('Halıfleks Döşeme', 'Zemin Kaplama', 'Halıfleks Uygulama'),
  ServiceAlias('Halı Kaplama', 'Zemin Kaplama', 'Halıfleks Uygulama'),
  ServiceAlias('PVC Zemin Kaplama', 'Zemin Kaplama', 'PVC Zemin'),
  ServiceAlias('Vinil Zemin Kaplama', 'Zemin Kaplama', 'PVC Zemin'),
  ServiceAlias('LVT Zemin Kaplama', 'Zemin Kaplama', 'PVC Zemin'),
  ServiceAlias('SPC Zemin Kaplama', 'Zemin Kaplama', 'PVC Zemin'),
  ServiceAlias('Epoksi Zemin', 'Zemin Kaplama', 'Epoksi Zemin Kaplama'),
  ServiceAlias.kategoriNiyeti('Parke Sistre Cila', 'Zemin Kaplama'),

  // ── Yalıtım ve Mantolama ──
  ServiceAlias('Dış Cephe Mantolama', 'Yalıtım ve Mantolama', 'Mantolama'),
  ServiceAlias('İç Cephe Mantolama', 'Yalıtım ve Mantolama', 'Mantolama'),
  ServiceAlias('Teras Su Yalıtımı', 'Yalıtım ve Mantolama', 'Teras İzolasyonu'),
  ServiceAlias('Bodrum Su Yalıtımı', 'Yalıtım ve Mantolama', 'Su Yalıtımı'),
  ServiceAlias('Zemin Su Yalıtımı', 'Yalıtım ve Mantolama', 'Su Yalıtımı'),
  ServiceAlias('Membran Döşeme', 'Yalıtım ve Mantolama', 'Su Yalıtımı'),
  ServiceAlias('Polyurea Su Yalıtımı', 'Yalıtım ve Mantolama', 'Su Yalıtımı'),
  ServiceAlias('Duvar Ses Yalıtımı', 'Yalıtım ve Mantolama', 'Ses Yalıtımı'),
  ServiceAlias('Tavan Ses Yalıtımı', 'Yalıtım ve Mantolama', 'Ses Yalıtımı'),
  ServiceAlias('Zemin Ses Yalıtımı', 'Yalıtım ve Mantolama', 'Ses Yalıtımı'),
  ServiceAlias('Stüdyo Ses Yalıtımı', 'Yalıtım ve Mantolama', 'Ses Yalıtımı'),
  ServiceAlias('Dış Cephe Isı Yalıtımı', 'Yalıtım ve Mantolama', 'Isı Yalıtımı'),

  // ── Çatı Yapım ve Onarım ──
  ServiceAlias('Kiremit Çatı Tamiri', 'Çatı Yapım ve Onarım', 'Çatı Tamiri'),
  ServiceAlias('Çatı Tadilatı', 'Çatı Yapım ve Onarım', 'Çatı Tamiri'),
  ServiceAlias('Çatı Onarımı', 'Çatı Yapım ve Onarım', 'Çatı Tamiri'),
  ServiceAlias('Yeni Çatı Yapımı', 'Çatı Yapım ve Onarım', 'Çatı Yapımı'),
  ServiceAlias('Membran Çatı', 'Çatı Yapım ve Onarım', 'Çatı İzolasyonu'),
  ServiceAlias('Çatı Su İzolasyonu', 'Çatı Yapım ve Onarım', 'Çatı İzolasyonu'),
  ServiceAlias('Çatı Yenileme Aktarma', 'Çatı Yapım ve Onarım', 'Çatı Aktarma'),
  ServiceAlias('Kırık Kiremit Değişimi', 'Çatı Yapım ve Onarım', 'Kiremit Değişimi'),
  ServiceAlias.kategoriNiyeti('Çatı Oluk Değişimi', 'Çatı Yapım ve Onarım'),
  ServiceAlias.kategoriNiyeti('Oluk Tamiri', 'Çatı Yapım ve Onarım'),

  // ── Mobilya Yapım ve Montaj ──
  ServiceAlias('IKEA Montaj', 'Mobilya Yapım ve Montaj', 'Mobilya Montajı'),
  ServiceAlias('Demonte Mobilya Montajı', 'Mobilya Yapım ve Montaj', 'Mobilya Montajı'),
  ServiceAlias('Mobilya Sökme Kurulum', 'Mobilya Yapım ve Montaj', 'Mobilya Montajı'),
  ServiceAlias('Dolap Tamiri', 'Mobilya Yapım ve Montaj', 'Mobilya Tamiri'),
  ServiceAlias('Gardrop Tamiri', 'Mobilya Yapım ve Montaj', 'Mobilya Tamiri'),
  ServiceAlias('Gardrop Kurulumu', 'Mobilya Yapım ve Montaj', 'Gardırop Montajı'),
  ServiceAlias('Dolap Montajı', 'Mobilya Yapım ve Montaj', 'Gardırop Montajı'),
  ServiceAlias('Sürgülü Dolap Montajı', 'Mobilya Yapım ve Montaj', 'Gardırop Montajı'),
  ServiceAlias('TV Ünitesi Kurulumu', 'Mobilya Yapım ve Montaj', 'TV Ünitesi Montajı'),
  ServiceAlias('Özel Mobilya İmalatı', 'Mobilya Yapım ve Montaj', 'Mobilya İmalatı'),
  ServiceAlias.kategoriNiyeti('Vestiyer Montajı', 'Mobilya Yapım ve Montaj'),

  // ── Marangozluk ve Ahşap İşleri ──
  ServiceAlias('Ahşap Veranda', 'Marangozluk ve Ahşap İşleri', 'Ahşap Pergola'),
  ServiceAlias('Pergole', 'Marangozluk ve Ahşap İşleri', 'Ahşap Pergola'),
  ServiceAlias('Ahşap Masa', 'Marangozluk ve Ahşap İşleri', 'Ahşap Masa Yapımı'),
  ServiceAlias('Ahşap Raf', 'Marangozluk ve Ahşap İşleri', 'Ahşap Raf Yapımı'),
  ServiceAlias('Ahşap Merdiven Yapımı', 'Marangozluk ve Ahşap İşleri', 'Ahşap Merdiven'),
  ServiceAlias('Mobilya Cilalama', 'Marangozluk ve Ahşap İşleri', 'Vernik ve Cila'),
  ServiceAlias('Ahşap Cila', 'Marangozluk ve Ahşap İşleri', 'Vernik ve Cila'),
  ServiceAlias.kategoriNiyeti('Marangoz', 'Marangozluk ve Ahşap İşleri'),
  ServiceAlias.kategoriNiyeti('Ahşap Dekorasyon', 'Marangozluk ve Ahşap İşleri'),

  // ── Kapı Montaj ve Tamir ──
  ServiceAlias('Amerikan Kapı Montajı', 'Kapı Montaj ve Tamir', 'İç Kapı Montajı'),
  ServiceAlias('Lake Kapı Montajı', 'Kapı Montaj ve Tamir', 'İç Kapı Montajı'),
  ServiceAlias('Melamin Kapı Montajı', 'Kapı Montaj ve Tamir', 'İç Kapı Montajı'),
  ServiceAlias('Ahşap Kapı Montajı', 'Kapı Montaj ve Tamir', 'İç Kapı Montajı'),
  ServiceAlias('Amerikan Panel Kapı Yapımı', 'Kapı Montaj ve Tamir', 'İç Kapı İmalatı'),
  ServiceAlias('Ahşap Kapı Tamiri', 'Kapı Montaj ve Tamir', 'Kapı Tamiri'),
  ServiceAlias('İç Kapı Tamiri', 'Kapı Montaj ve Tamir', 'Kapı Tamiri'),
  ServiceAlias('Çelik Kapı Kurulumu', 'Kapı Montaj ve Tamir', 'Çelik Kapı Montajı'),
  ServiceAlias('Çelik Kapı Onarımı', 'Kapı Montaj ve Tamir', 'Çelik Kapı Tamiri'),

  // ── Cam Balkon ──
  ServiceAlias('Katlanır Cam Balkon', 'Cam Balkon Sistemleri', 'Cam Balkon'),
  ServiceAlias('Sürgülü Cam Balkon', 'Cam Balkon Sistemleri', 'Cam Balkon'),
  ServiceAlias('Balkon Camla Kapatma', 'Cam Balkon Sistemleri', 'Cam Balkon'),
  ServiceAlias('Cam Balkon Cam Değişimi', 'Cam Balkon Sistemleri', 'Cam Değişimi'),
  ServiceAlias('Kırık Cam Tamiri', 'Cam Balkon Sistemleri', 'Cam Değişimi'),
  ServiceAlias('Çift Cam Tamiri', 'Cam Balkon Sistemleri', 'Cam Değişimi'),
  ServiceAlias('Ayna Asma', 'Cam Balkon Sistemleri', 'Ayna Montajı'),
  ServiceAlias.kategoriNiyeti('Duşakabin Cam Değişimi', 'Cam Balkon Sistemleri'),
  ServiceAlias.kategoriNiyeti('Duşakabin Cam Tamiri', 'Cam Balkon Sistemleri'),
  ServiceAlias.kategoriNiyeti('Vitrin Camı', 'Cam Balkon Sistemleri'),
  ServiceAlias.kategoriNiyeti('Cam Montajı', 'Cam Balkon Sistemleri'),
  ServiceAlias.kategoriNiyeti('Cam İmalatı', 'Cam Balkon Sistemleri'),

  // ── PVC ve Alüminyum Doğrama ──
  ServiceAlias('Pimapen Tamiri', 'PVC ve Alüminyum Doğrama', 'PVC Pencere Tamiri'),
  ServiceAlias('Pencere Kapı Pimapen Tamiri', 'PVC ve Alüminyum Doğrama', 'PVC Pencere Tamiri'),
  ServiceAlias('Pimapen Montaj', 'PVC ve Alüminyum Doğrama', 'PVC Pencere Montajı'),
  ServiceAlias('PVC Pencere Yapımı', 'PVC ve Alüminyum Doğrama', 'PVC Pencere Montajı'),
  ServiceAlias('PVC Doğrama', 'PVC ve Alüminyum Doğrama', 'PVC Pencere Montajı'),
  ServiceAlias('Plise Sineklik', 'PVC ve Alüminyum Doğrama', 'Sineklik Montajı'),
  ServiceAlias('Menteşeli Sineklik', 'PVC ve Alüminyum Doğrama', 'Sineklik Montajı'),
  ServiceAlias('Akordiyon Sineklik', 'PVC ve Alüminyum Doğrama', 'Sineklik Montajı'),
  ServiceAlias('Motorlu Panjur', 'PVC ve Alüminyum Doğrama', 'Panjur Sistemleri'),
  ServiceAlias('Otomatik Panjur', 'PVC ve Alüminyum Doğrama', 'Panjur Sistemleri'),
  ServiceAlias('Panjur Tamiri', 'PVC ve Alüminyum Doğrama', 'Panjur Sistemleri'),
  ServiceAlias('Alüminyum Pencere Doğrama', 'PVC ve Alüminyum Doğrama', 'Alüminyum Doğrama'),

  // ── Demir Doğrama ve Kaynak ──
  ServiceAlias('Demir Kaynak', 'Demir Doğrama ve Kaynak', 'Kaynakçı'),
  ServiceAlias('Çelik Kaynak', 'Demir Doğrama ve Kaynak', 'Kaynakçı'),
  ServiceAlias('Gazaltı Kaynak', 'Demir Doğrama ve Kaynak', 'Kaynakçı'),
  ServiceAlias('Krom Kaynak', 'Demir Doğrama ve Kaynak', 'Kaynakçı'),
  ServiceAlias('Kaynak Ustası', 'Demir Doğrama ve Kaynak', 'Kaynakçı'),
  ServiceAlias('Ferforje Korkuluk', 'Demir Doğrama ve Kaynak', 'Ferforje'),
  ServiceAlias('Demir Korkuluk', 'Demir Doğrama ve Kaynak', 'Korkuluk Montajı'),
  ServiceAlias('Çelik Konstrüksiyon İmalatı', 'Demir Doğrama ve Kaynak', 'Çelik Konstrüksiyon'),
  ServiceAlias('Demir Doğrama Ustası', 'Demir Doğrama ve Kaynak', 'Demir Doğrama İşleri'),

  // ── Çilingir ve Kilit ──
  ServiceAlias('Kilit Açma', 'Çilingir ve Kilit', 'Kapı Açma'),
  ServiceAlias('Kapı Kilidi Açma', 'Çilingir ve Kilit', 'Kapı Açma'),
  ServiceAlias('Çelik Kapı Açma', 'Çilingir ve Kilit', 'Kapı Açma'),
  ServiceAlias('Kilit Değiştirme', 'Çilingir ve Kilit', 'Kilit Değişimi'),
  ServiceAlias('Çelik Kapı Kilit Değiştirme', 'Çilingir ve Kilit', 'Kilit Değişimi'),
  ServiceAlias('Barel Değiştirme', 'Çilingir ve Kilit', 'Barel Değişimi'),
  ServiceAlias('Silindir Değişimi', 'Çilingir ve Kilit', 'Barel Değişimi'),
  ServiceAlias('Oto Anahtar', 'Çilingir ve Kilit', 'Oto Anahtarcı'),
  ServiceAlias('Oto Çilingir', 'Çilingir ve Kilit', 'Oto Anahtarcı'),
  ServiceAlias('Araç Anahtarı', 'Çilingir ve Kilit', 'Oto Anahtarcı'),
  ServiceAlias.kategoriNiyeti('Çilingir', 'Çilingir ve Kilit'),
  ServiceAlias.kategoriNiyeti('Anahtarcı', 'Çilingir ve Kilit'),

  // ── Bahçe ve Peyzaj ──
  ServiceAlias('Peyzaj', 'Bahçe ve Peyzaj', 'Bahçe Düzenleme'),
  ServiceAlias('Bahçe Peyzaj', 'Bahçe ve Peyzaj', 'Bahçe Düzenleme'),
  ServiceAlias('Peyzaj Düzenleme', 'Bahçe ve Peyzaj', 'Bahçe Düzenleme'),
  ServiceAlias('Hazır Rulo Çim', 'Bahçe ve Peyzaj', 'Çim Serme'),
  ServiceAlias('Serme Çim', 'Bahçe ve Peyzaj', 'Çim Serme'),
  ServiceAlias('Tohum Çim', 'Bahçe ve Peyzaj', 'Çim Ekimi'),
  ServiceAlias('Çim Tohumu Ekimi', 'Bahçe ve Peyzaj', 'Çim Ekimi'),
  ServiceAlias('Bahçıvan', 'Bahçe ve Peyzaj', 'Bahçe Bakımı'),
  ServiceAlias('Bahçe Temizliği', 'Bahçe ve Peyzaj', 'Bahçe Bakımı'),
  ServiceAlias('Yabani Ot Temizleme', 'Bahçe ve Peyzaj', 'Bahçe Bakımı'),
  ServiceAlias('Çim Bakımı', 'Bahçe ve Peyzaj', 'Bahçe Bakımı'),
  ServiceAlias('Bahçe Sulama Sistemleri', 'Bahçe ve Peyzaj', 'Otomatik Sulama Sistemi'),
  ServiceAlias('Çim Sulama Sistemleri', 'Bahçe ve Peyzaj', 'Otomatik Sulama Sistemi'),
  ServiceAlias.kategoriNiyeti('Ağaç Kesme', 'Bahçe ve Peyzaj'),

  // ── Havuz Yapım ve Bakım ──
  ServiceAlias('Havuz Temizliği', 'Havuz Yapım ve Bakım', 'Havuz Bakımı'),
  ServiceAlias('Havuz Bakım ve Temizliği', 'Havuz Yapım ve Bakım', 'Havuz Bakımı'),
  ServiceAlias('Havuz Kimyasalları', 'Havuz Yapım ve Bakım', 'Havuz Kimyasal Dengeleme'),
  ServiceAlias('Havuz Kimyasal Bakımı', 'Havuz Yapım ve Bakım', 'Havuz Kimyasal Dengeleme'),
  ServiceAlias('Havuz Tadilatı', 'Havuz Yapım ve Bakım', 'Havuz Tamiri'),
  ServiceAlias('Havuz Onarımı', 'Havuz Yapım ve Bakım', 'Havuz Tamiri'),
  ServiceAlias('Mekanik Havuz Tamiri', 'Havuz Yapım ve Bakım', 'Havuz Tamiri'),
  ServiceAlias('Yüzme Havuzu Yapımı', 'Havuz Yapım ve Bakım', 'Havuz Yapımı'),

  // ── Nakliyat ve Taşımacılık ──
  ServiceAlias('Eşya Taşıma', 'Nakliyat ve Taşımacılık', 'Parça Eşya Taşıma'),
  ServiceAlias('Koltuk Taşıma', 'Nakliyat ve Taşımacılık', 'Parça Eşya Taşıma'),
  ServiceAlias('Yük Taşıma', 'Nakliyat ve Taşımacılık', 'Parça Eşya Taşıma'),
  ServiceAlias('Buzdolabı Taşıma', 'Nakliyat ve Taşımacılık', 'Parça Eşya Taşıma'),
  ServiceAlias('Çamaşır Makinesi Taşıma', 'Nakliyat ve Taşımacılık', 'Parça Eşya Taşıma'),
  ServiceAlias('Ev Taşıma', 'Nakliyat ve Taşımacılık', 'Evden Eve Nakliyat'),
  ServiceAlias('Ofis Nakliyesi', 'Nakliyat ve Taşımacılık', 'Ofis Taşıma'),
  ServiceAlias('Asansörlü Ev Taşıma', 'Nakliyat ve Taşımacılık', 'Asansörlü Nakliyat'),
  ServiceAlias('Depolama', 'Nakliyat ve Taşımacılık', 'Eşya Depolama'),
  ServiceAlias.kategoriNiyeti('Nakliye', 'Nakliyat ve Taşımacılık'),
  ServiceAlias.kategoriNiyeti('Şehirler Arası Parça Eşya Taşıma', 'Nakliyat ve Taşımacılık'),
  ServiceAlias.kategoriNiyeti('Şehir İçi Nakliyat', 'Nakliyat ve Taşımacılık'),
  ServiceAlias.kategoriNiyeti('Hamal', 'Nakliyat ve Taşımacılık'),

  // ── Kurye ve Küçük Taşıma ──
  ServiceAlias('Motosiklet Kargo', 'Kurye ve Küçük Taşıma', 'Moto Kurye'),
  ServiceAlias('MotoKurye', 'Kurye ve Küçük Taşıma', 'Moto Kurye'),
  ServiceAlias('Aynı Gün Paket Teslimi', 'Kurye ve Küçük Taşıma', 'Paket Taşıma'),
  ServiceAlias('Koli Taşıma', 'Kurye ve Küçük Taşıma', 'Paket Taşıma'),
  ServiceAlias('Paket Teslimatı', 'Kurye ve Küçük Taşıma', 'Paket Taşıma'),
  ServiceAlias('Minivan Nakliye', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),
  ServiceAlias('Kamyonet Nakliye', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),
  ServiceAlias('Panelvan Nakliye', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),
  ServiceAlias('Doblo Nakliye', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),
  ServiceAlias('Kısa Mesafe Nakliye', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),
  ServiceAlias('Araçlı Kurye', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),
  ServiceAlias('Şehir İçi Kargo', 'Kurye ve Küçük Taşıma', 'Küçük Nakliye'),

  // ── Asansör Montaj ve Bakım ──
  ServiceAlias('Asansör Revizyonu', 'Asansör Montaj ve Bakım', 'Asansör Tamiri'),
  ServiceAlias('Asansör Modernizasyonu', 'Asansör Montaj ve Bakım', 'Asansör Tamiri'),
  ServiceAlias('Yük Asansörü Bakımı', 'Asansör Montaj ve Bakım', 'Asansör Bakımı'),
  ServiceAlias('Asansör Periyodik Bakım', 'Asansör Montaj ve Bakım', 'Asansör Bakımı'),
  ServiceAlias('Asansör Kurulumu', 'Asansör Montaj ve Bakım', 'Asansör Montajı'),
  ServiceAlias.kategoriNiyeti('Asansör Servisi', 'Asansör Montaj ve Bakım'),

  // ── Mühendislik ve Proje ──
  ServiceAlias('Statik Proje Çizimi', 'Mühendislik ve Proje', 'Statik Proje'),
  ServiceAlias('Mimari Proje Çizimi', 'Mühendislik ve Proje', 'Mimari Proje'),
  ServiceAlias('Elektrik Tesisat Projesi', 'Mühendislik ve Proje', 'Elektrik Projesi'),
  ServiceAlias('Elektrik Proje Çizimi', 'Mühendislik ve Proje', 'Elektrik Projesi'),
  ServiceAlias('Mekanik Proje', 'Mühendislik ve Proje', 'Mekanik Tesisat Projesi'),
  ServiceAlias('Mekanik Proje Çizimi', 'Mühendislik ve Proje', 'Mekanik Tesisat Projesi'),
  ServiceAlias('Zemin Etüdü Raporu', 'Mühendislik ve Proje', 'Zemin Etüdü'),
  ServiceAlias('Enerji Kimlik Belgesi Raporu', 'Mühendislik ve Proje', 'Enerji Kimlik Belgesi'),
  ServiceAlias.kategoriNiyeti('İnşaat Proje Çizimi', 'Mühendislik ve Proje'),

  // ── Oto Çekici ve Yol Yardım ──
  ServiceAlias('Çekici Hizmeti', 'Oto Çekici ve Yol Yardım', 'Oto Çekici'),
  ServiceAlias('Araç Çekici', 'Oto Çekici ve Yol Yardım', 'Oto Çekici'),
  ServiceAlias('Oto Kurtarma', 'Oto Çekici ve Yol Yardım', 'Oto Çekici'),
  ServiceAlias('Acil Yol Yardım', 'Oto Çekici ve Yol Yardım', 'Yol Yardım'),
  ServiceAlias('7/24 Yol Yardım', 'Oto Çekici ve Yol Yardım', 'Yol Yardım'),
  ServiceAlias('Akü Takviyesi', 'Oto Çekici ve Yol Yardım', 'Akü Takviye'),
  ServiceAlias('Akü Yol Yardımı', 'Oto Çekici ve Yol Yardım', 'Akü Takviye'),

  // ── Oto Servis ve Bakım ──
  ServiceAlias('Yağ Değişimi', 'Oto Servis ve Bakım', 'Periyodik Araç Bakımı'),
  ServiceAlias('Yağ Filtre Değişimi', 'Oto Servis ve Bakım', 'Periyodik Araç Bakımı'),
  ServiceAlias('Periyodik Bakım', 'Oto Servis ve Bakım', 'Periyodik Araç Bakımı'),
  ServiceAlias('Araç Periyodik Bakım', 'Oto Servis ve Bakım', 'Periyodik Araç Bakımı'),
  ServiceAlias('Oto Klima Bakımı', 'Oto Servis ve Bakım', 'Oto Klima'),
  ServiceAlias('Araç Klima Servisi', 'Oto Servis ve Bakım', 'Oto Klima'),
  ServiceAlias('Araç Elektrik', 'Oto Servis ve Bakım', 'Oto Elektrik'),
  ServiceAlias('Fren Balata', 'Oto Servis ve Bakım', 'Fren Balata Değişimi'),
  ServiceAlias('Balata Değişimi', 'Oto Servis ve Bakım', 'Fren Balata Değişimi'),
  ServiceAlias.kategoriNiyeti('Oto Tamir', 'Oto Servis ve Bakım'),
  ServiceAlias.kategoriNiyeti('Mekanik Araç Tamiri', 'Oto Servis ve Bakım'),

  // ── Araç Temizlik ve Detaylı Bakım ──
  ServiceAlias('Oto Detaylı Temizlik', 'Araç Temizlik ve Detaylı Bakım', 'Araç Detaylı Temizlik'),
  ServiceAlias('Detaylı İç Temizlik', 'Araç Temizlik ve Detaylı Bakım', 'Araç Detaylı Temizlik'),
  ServiceAlias('Araç İç Detaylı Temizlik', 'Araç Temizlik ve Detaylı Bakım', 'Araç Detaylı Temizlik'),
  ServiceAlias('İç Dış Oto Yıkama', 'Araç Temizlik ve Detaylı Bakım', 'Oto Yıkama'),
  ServiceAlias('Araç Yıkama', 'Araç Temizlik ve Detaylı Bakım', 'Oto Yıkama'),
  ServiceAlias('Oto Koltuk Yıkama', 'Araç Temizlik ve Detaylı Bakım', 'Araç Koltuk Yıkama'),
  ServiceAlias.kategoriNiyeti('VIP Araç Yıkama', 'Araç Temizlik ve Detaylı Bakım'),
  ServiceAlias.kategoriNiyeti('Pasta Cila', 'Araç Temizlik ve Detaylı Bakım'),
  ServiceAlias.kategoriNiyeti('Seramik Kaplama', 'Araç Temizlik ve Detaylı Bakım'),

  // ── Özel Ders ──
  ServiceAlias('Ortaokul Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('Lise Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('LGS Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('YKS Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('TYT Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('İlkokul Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('Üniversite Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('DGS Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('Online Matematik Özel Ders', 'Özel Ders', 'Matematik Özel Ders'),
  ServiceAlias('Online Fizik Özel Ders', 'Özel Ders', 'Fizik Özel Ders'),
  ServiceAlias('Üniversite Fizik Özel Ders', 'Özel Ders', 'Fizik Özel Ders'),
  ServiceAlias('AP Fizik Özel Ders', 'Özel Ders', 'Fizik Özel Ders'),
  ServiceAlias('IB Fizik Özel Ders', 'Özel Ders', 'Fizik Özel Ders'),
  ServiceAlias('Online Fen Bilimleri Özel Ders', 'Özel Ders', 'Fen Bilimleri Özel Ders'),
  ServiceAlias('Online İlkokul Özel Ders', 'Özel Ders', 'İlkokul Özel Ders'),
  ServiceAlias('Sınıf Öğretmeni Özel Ders', 'Özel Ders', 'İlkokul Özel Ders'),

  // ── Yabancı Dil Eğitimi ──
  ServiceAlias('Online İngilizce Özel Ders', 'Yabancı Dil Eğitimi', 'Online İngilizce Dersi'),
  ServiceAlias('Konuşma İngilizcesi Özel Ders', 'Yabancı Dil Eğitimi', 'İngilizce Özel Ders'),
  ServiceAlias('İngilizce Konuşma Dersi', 'Yabancı Dil Eğitimi', 'İngilizce Özel Ders'),
  ServiceAlias('Online Almanca Özel Ders', 'Yabancı Dil Eğitimi', 'Almanca Özel Ders'),
  ServiceAlias('Online Fransızca Özel Ders', 'Yabancı Dil Eğitimi', 'Fransızca Özel Ders'),
  ServiceAlias.kategoriNiyeti('Online Yabancı Dil Dersi', 'Yabancı Dil Eğitimi'),

  // ── Sürücü Eğitimi ──
  ServiceAlias('Direksiyon Eğitimi', 'Sürücü Eğitimi', 'Direksiyon Dersi'),
  ServiceAlias('Sürücü Direksiyon Eğitimi', 'Sürücü Eğitimi', 'Direksiyon Dersi'),
  ServiceAlias('Otomatik Vites Direksiyon Dersi', 'Sürücü Eğitimi', 'Direksiyon Dersi'),
  ServiceAlias('Manuel Vites Direksiyon Dersi', 'Sürücü Eğitimi', 'Direksiyon Dersi'),
  ServiceAlias('Defansif Sürüş', 'Sürücü Eğitimi', 'İleri Sürüş Eğitimi'),
  ServiceAlias('İleri Sürüş Teknikleri', 'Sürücü Eğitimi', 'İleri Sürüş Eğitimi'),
  ServiceAlias.kategoriNiyeti('Ehliyet Kursu', 'Sürücü Eğitimi'),
  ServiceAlias.kategoriNiyeti('Sürücü Kursu', 'Sürücü Eğitimi'),
  ServiceAlias.kategoriNiyeti('Motosiklet Eğitimi', 'Sürücü Eğitimi'),

  // ── Spor ve Kişisel Antrenör ──
  ServiceAlias('Personal Trainer', 'Spor ve Kişisel Antrenör', 'Fitness Özel Ders'),
  ServiceAlias('Spor Koçu', 'Spor ve Kişisel Antrenör', 'Fitness Özel Ders'),
  ServiceAlias('Online Personal Trainer', 'Spor ve Kişisel Antrenör', 'Fitness Özel Ders'),
  ServiceAlias('Online Fitness Dersi', 'Spor ve Kişisel Antrenör', 'Fitness Özel Ders'),
  ServiceAlias('Reformer Pilates', 'Spor ve Kişisel Antrenör', 'Pilates Dersi'),
  ServiceAlias('Grup Reformer Pilates', 'Spor ve Kişisel Antrenör', 'Pilates Dersi'),
  ServiceAlias('Online Pilates', 'Spor ve Kişisel Antrenör', 'Pilates Dersi'),
  ServiceAlias('Mat Pilates', 'Spor ve Kişisel Antrenör', 'Pilates Dersi'),
  ServiceAlias('Yetişkin Yüzme Dersi', 'Spor ve Kişisel Antrenör', 'Yüzme Dersi'),
  ServiceAlias('Çocuk Yüzme Dersi', 'Spor ve Kişisel Antrenör', 'Yüzme Dersi'),
  ServiceAlias('Tenis Kursu', 'Spor ve Kişisel Antrenör', 'Tenis Dersi'),
  ServiceAlias('Tenis Grup Dersi', 'Spor ve Kişisel Antrenör', 'Tenis Dersi'),

  // ── Müzik Dersleri ──
  ServiceAlias('Çocuk Piyano Dersi', 'Müzik Dersleri', 'Piyano Dersi'),
  ServiceAlias('Online Piyano Dersi', 'Müzik Dersleri', 'Piyano Dersi'),
  ServiceAlias('Online Gitar Dersi', 'Müzik Dersleri', 'Gitar Dersi'),
  ServiceAlias('Online Keman Dersi', 'Müzik Dersleri', 'Keman Dersi'),
  ServiceAlias('Vokal Dersi', 'Müzik Dersleri', 'Şan Dersi'),
  ServiceAlias('Ses Eğitimi', 'Müzik Dersleri', 'Şan Dersi'),
  ServiceAlias('Online Şan Dersi', 'Müzik Dersleri', 'Şan Dersi'),
  ServiceAlias.kategoriNiyeti('Org Dersi', 'Müzik Dersleri'),
  ServiceAlias.kategoriNiyeti('Saz Dersi', 'Müzik Dersleri'),

  // ── Yazılım ve Web Hizmetleri ──
  ServiceAlias('WordPress Site Kurma', 'Yazılım ve Web Hizmetleri', 'WordPress Site Kurulumu'),
  ServiceAlias('WordPress Hizmetleri', 'Yazılım ve Web Hizmetleri', 'WordPress Site Kurulumu'),
  ServiceAlias('Web Tasarım', 'Yazılım ve Web Hizmetleri', 'Web Sitesi Yapımı'),
  ServiceAlias('Web Tasarım ve Programlama', 'Yazılım ve Web Hizmetleri', 'Web Sitesi Yapımı'),
  ServiceAlias('Kurumsal Web Sitesi', 'Yazılım ve Web Hizmetleri', 'Web Sitesi Yapımı'),
  ServiceAlias('Web Sitesi Geliştirme', 'Yazılım ve Web Hizmetleri', 'Web Sitesi Yapımı'),
  ServiceAlias('E Ticaret Sitesi', 'Yazılım ve Web Hizmetleri', 'E-Ticaret Sitesi Yapımı'),
  ServiceAlias('E-Ticaret Site Geliştirme', 'Yazılım ve Web Hizmetleri', 'E-Ticaret Sitesi Yapımı'),
  ServiceAlias('Android Uygulama Geliştirme', 'Yazılım ve Web Hizmetleri', 'Mobil Uygulama Geliştirme'),
  ServiceAlias('iOS Uygulama Geliştirme', 'Yazılım ve Web Hizmetleri', 'Mobil Uygulama Geliştirme'),
  ServiceAlias('Mobil App Geliştirme', 'Yazılım ve Web Hizmetleri', 'Mobil Uygulama Geliştirme'),

  // ── Grafik ve Logo Tasarım ──
  ServiceAlias('Logo Tasarım', 'Grafik ve Logo Tasarım', 'Logo Tasarımı'),
  ServiceAlias('Kurumsal Logo Tasarımı', 'Grafik ve Logo Tasarım', 'Logo Tasarımı'),
  ServiceAlias('Afiş Tasarımı', 'Grafik ve Logo Tasarım', 'Grafik Tasarım'),
  ServiceAlias('Poster Tasarımı', 'Grafik ve Logo Tasarım', 'Grafik Tasarım'),
  ServiceAlias('Broşür Tasarımı', 'Grafik ve Logo Tasarım', 'Grafik Tasarım'),
  ServiceAlias('Marka Kimliği', 'Grafik ve Logo Tasarım', 'Kurumsal Kimlik Tasarımı'),
  ServiceAlias('Kurumsal Kimlik', 'Grafik ve Logo Tasarım', 'Kurumsal Kimlik Tasarımı'),

  // ── Dijital Pazarlama ──
  ServiceAlias('Google Ads', 'Dijital Pazarlama', 'Google Reklam Yönetimi'),
  ServiceAlias('Google Ads Uzmanı', 'Dijital Pazarlama', 'Google Reklam Yönetimi'),
  ServiceAlias('Google Ads Reklam Yönetimi', 'Dijital Pazarlama', 'Google Reklam Yönetimi'),
  ServiceAlias('SEM', 'Dijital Pazarlama', 'Google Reklam Yönetimi'),
  ServiceAlias('Sosyal Medya Yönetimi ve Danışmanlığı', 'Dijital Pazarlama', 'Sosyal Medya Yönetimi'),
  ServiceAlias('Sosyal Medya Uzmanı', 'Dijital Pazarlama', 'Sosyal Medya Yönetimi'),
  ServiceAlias('SEO', 'Dijital Pazarlama', 'SEO Hizmeti'),
  ServiceAlias('SEO Uzmanı', 'Dijital Pazarlama', 'SEO Hizmeti'),
  ServiceAlias.kategoriNiyeti('Instagram Reklam Yönetimi', 'Dijital Pazarlama'),
  ServiceAlias.kategoriNiyeti('Facebook Reklam Yönetimi', 'Dijital Pazarlama'),

  // ── Fotoğraf Çekimi ──
  ServiceAlias('Ürün Fotoğrafçısı', 'Fotoğraf Çekimi', 'Ürün Fotoğraf Çekimi'),
  ServiceAlias('E-Ticaret Ürün Çekimi', 'Fotoğraf Çekimi', 'Ürün Fotoğraf Çekimi'),
  ServiceAlias('Katalog Ürün Çekimi', 'Fotoğraf Çekimi', 'Ürün Fotoğraf Çekimi'),
  ServiceAlias('Kurumsal Fotoğraf', 'Fotoğraf Çekimi', 'Kurumsal Fotoğraf Çekimi'),
  ServiceAlias('İşyeri Fotoğraf Çekimi', 'Fotoğraf Çekimi', 'Kurumsal Fotoğraf Çekimi'),
  ServiceAlias('Marka Fotoğraf Çekimi', 'Fotoğraf Çekimi', 'Kurumsal Fotoğraf Çekimi'),
  ServiceAlias.kategoriNiyeti('Portre Fotoğraf Çekimi', 'Fotoğraf Çekimi'),
  ServiceAlias.kategoriNiyeti('Kişisel Fotoğraf Çekimi', 'Fotoğraf Çekimi'),

  // ── Etkinlik ve Organizasyon ──
  ServiceAlias('Doğum Günü Süsleme', 'Etkinlik ve Organizasyon', 'Doğum Günü Organizasyonu'),
  ServiceAlias('Doğum Günü Parti Organizasyonu', 'Etkinlik ve Organizasyon', 'Doğum Günü Organizasyonu'),
  ServiceAlias('Düğün Süsleme', 'Etkinlik ve Organizasyon', 'Düğün Organizasyonu'),
  ServiceAlias('Düğün Planlama', 'Etkinlik ve Organizasyon', 'Düğün Organizasyonu'),
  ServiceAlias.kategoriNiyeti('Nişan Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Söz Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Nikah Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Kına Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Sünnet Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Evlilik Teklifi Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Baby Shower Organizasyonu', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Balon Süsleme', 'Etkinlik ve Organizasyon'),
  ServiceAlias.kategoriNiyeti('Catering', 'Etkinlik ve Organizasyon'),

  // ── Evcil Hayvan Hizmetleri ──
  ServiceAlias('Evde Köpek Bakımı', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Kedi Bakımı', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Evde Kedi Bakımı', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Köpek Oteli', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Kedi Oteli', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Hayvan Oteli', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Köpek Pansiyonu', 'Evcil Hayvan Hizmetleri', 'Evcil Hayvan Bakımı'),
  ServiceAlias('Köpek Yürütme', 'Evcil Hayvan Hizmetleri', 'Köpek Gezdirme'),

  // ── Güzellik ve Bakım Hizmetleri ──
  ServiceAlias('Gelin Makyajı', 'Güzellik ve Bakım Hizmetleri', 'Makyaj'),
  ServiceAlias('Profesyonel Makyaj', 'Güzellik ve Bakım Hizmetleri', 'Makyaj'),
  ServiceAlias('Düğün Makyajı', 'Güzellik ve Bakım Hizmetleri', 'Makyaj'),
  ServiceAlias('Özel Gün Makyajı', 'Güzellik ve Bakım Hizmetleri', 'Makyaj'),
  ServiceAlias('Porselen Makyaj', 'Güzellik ve Bakım Hizmetleri', 'Makyaj'),
  ServiceAlias('Protez Tırnak', 'Güzellik ve Bakım Hizmetleri', 'Manikür Pedikür'),
  ServiceAlias('Nail Art', 'Güzellik ve Bakım Hizmetleri', 'Manikür Pedikür'),
  ServiceAlias('Jel Tırnak', 'Güzellik ve Bakım Hizmetleri', 'Manikür Pedikür'),
  ServiceAlias('Gelin Saçı', 'Güzellik ve Bakım Hizmetleri', 'Saç Tasarımı'),
  ServiceAlias('Gelin Başı', 'Güzellik ve Bakım Hizmetleri', 'Saç Tasarımı'),
  ServiceAlias('Nişan Saçı', 'Güzellik ve Bakım Hizmetleri', 'Saç Tasarımı'),
  ServiceAlias.kategoriNiyeti('Gelin Saç Makyaj', 'Güzellik ve Bakım Hizmetleri'),
  ServiceAlias.kategoriNiyeti('Nişan Saç Makyaj', 'Güzellik ve Bakım Hizmetleri'),
  ServiceAlias.kategoriNiyeti('Epilasyon', 'Güzellik ve Bakım Hizmetleri'),
  ServiceAlias.kategoriNiyeti('Erkek Epilasyon', 'Güzellik ve Bakım Hizmetleri'),
];

/// Normalize edilmiş etiket → alias.
///
/// ⚠ ÇAKIŞMA SESSİZCE ÇÖZÜLMEZ. Aynı normalize etiket iki farklı
/// hedefe bağlıysa test düşer (`service_alias_test.dart`); burada
/// "son yazan kazanır" davranışı olsaydı yanlış hedef sessizce
/// yerleşirdi.
final Map<String, ServiceAlias> kAliasDizini = {
  for (final a in kServiceAliases) aliasNormalize(a.etiket): a,
};

/// Tam ad eşleşmesiyle alias bulur; yoksa `null`.
///
/// ⚠ Etiket ZATEN kanonik bir ad ise alias döndürülmez: katalog
/// aramasının kendisi o adı bulur, ikinci bir kayıt gereksizdir.
ServiceAlias? aliasBul(String sorgu) {
  final n = aliasNormalize(sorgu);
  if (n.isEmpty) {
    return null;
  }
  return kAliasDizini[n];
}

/// Sorguyla eşleşen aliaslar — arama için.
///
/// [tamOnce] true iken tam eşleşme listenin başında döner.
List<ServiceAlias> aliasAra(String sorgu) {
  final n = aliasNormalize(sorgu);
  if (n.isEmpty) {
    return const [];
  }
  final tam = <ServiceAlias>[];
  final bas = <ServiceAlias>[];
  final ic = <ServiceAlias>[];
  for (final a in kServiceAliases) {
    final na = aliasNormalize(a.etiket);
    if (na == n) {
      tam.add(a);
    } else if (na.startsWith(n)) {
      bas.add(a);
    } else if (na.contains(n)) {
      ic.add(a);
    }
  }
  return [...tam, ...bas, ...ic];
}

/// Alias kataloğa gerçekten oturuyor mu? (test ve geliştirme kolaylığı)
///
/// Dönen liste BOŞ olmalıdır; dolu dönerse alias yanlış bir kategoriye
/// ya da var olmayan bir hizmete bağlanmış demektir.
List<String> aliasTutarsizliklari() {
  final hata = <String>[];
  for (final a in kServiceAliases) {
    final altlar = kCategoryTree[a.kategori];
    if (altlar == null) {
      hata.add('${a.etiket}: kategori yok (${a.kategori})');
      continue;
    }
    if (a.hizmetAliasi) {
      if (!altlar.contains(a.kanonikHizmet)) {
        hata.add('${a.etiket}: hedef bu kategoride yok '
            '(${a.kanonikHizmet} / ${a.kategori})');
      }
    } else if (a.kanonikHizmet != null) {
      hata.add('${a.etiket}: kategori niyetinde hedef olamaz');
    }
  }
  return hata;
}
