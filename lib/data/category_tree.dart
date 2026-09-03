/// HİZMET KATALOĞU — 158 KATEGORİ · 1448 HİZMET (24 ÇATI)
///
/// ═══════════════════════════════════════════════════════════════
///  ⚠ BU DOSYA KATALOGUN OTORİTESİ DEĞİLDİR — YALNIZCA CACHE'TİR
/// ═══════════════════════════════════════════════════════════════
///
/// NİHAİ KARAR: katalogun tek otoritatif kaynağı BACKEND'dir.
/// Kanonik uç `GET /categories`; Android, iOS ve Web aynı ucu
/// kullanır ve platforma özel katalog TUTULMAZ.
///
///     Admin Paneli → Backend → GET /categories → Android · iOS · Web
///
/// ⚠ NEDEN: kategori ve hizmetler admin panelinden yönetiliyor.
/// Listeyi uygulamaya gömülü OTORİTE saymak, admin yönetimini
/// etkisiz kılar — yeni bir kategori için uygulama sürümü
/// yayınlamak gerekirdi.
///
/// ⚠ BU DOSYANIN GÖREVİ: performans ve çevrimdışı kullanım için
/// yerel kopya sağlamak. Sunucudan güncel katalog geldiğinde ONUN
/// verisi esas alınır; buradaki liste backend'in YERİNE GEÇMEZ.
///
/// ⚠ İSTEMCİ KATEGORİ KİMLİĞİ ÜRETMEZ: addan kimlik türetme, tahmin
/// etme veya yeniden numaralandırma YAPILMAZ. Sunucunun verdiği
/// gerçek değerler kullanılır.
///
/// ⚠ MEVCUT DURUM (dürüst tespit): istemci bu ucu HENÜZ ÇAĞIRMIYOR
/// ve katalog pratikte buradan okunuyor. Karar sözleşme düzeyinde
/// kesinleşti; sunucudan besleme AYRI BİR İŞ olarak duruyor.
///
/// ⚠ BU SAYILAR TESTLE BAĞLIDIR. `test/katalog_yapisi_test.dart`
/// gerçek sayımı doğrular, `test/yorum_sayi_tutarliligi_test.dart` ise
/// BU SATIRDAKİ sayının gerçek sayımla aynı olmasını zorunlu kılar.
/// Kataloğu büyütürken başlığı güncellemek isteğe bağlı değildir.
///
/// Büyüme çizgisi: 34/165 (eski HTML ağacı) + 42/150 (ürün ekibi
/// listesi) birleşiminden 53/248 · 54/251 ("Halı ve Döşeme Yıkama"
/// ikiye bölündü) · 55 ("Kombi Servisi" → "Kombi Montaj" + "Kombi
/// Servis") · 459 hizmet (onaylı öneri listesindeki AYRI İŞ olanlar
/// gerçek hizmet oldu) · 439 (tekrar eden kayıtlar temizlendi) ·
/// 63/640 (hizmet lideri yapısı + profesyonel hizmetler).
///
/// ⚠ KATALOG ARTIK HTML REFERANSINDAN BAĞIMSIZDIR.
///
/// `hizmetcep-v66-final__1_.html` UI/UX, ekran yapısı, navigasyon,
/// metinler ve tasarım dili için REFERANS OLMAYA DEVAM EDER. İstisna
/// YALNIZ kategori/alt hizmet verisi ve kategoriye bağlı ikonlardır.
///
/// ⚠ AYRI TUTULAN BENZER HİZMETLER: `Gardırop Montajı` ≠ `Gardırop
/// Yapımı`, `TV Ünitesi Montajı` ≠ `TV Ünitesi Yapımı`. Montaj hazır
/// ürünün kurulumu, yapım imalattır — farklı hizmet veren, farklı
/// fiyat.
///
library;

/// ── ⚠ GÖMÜLÜ KATALOG — YEDEK VE İLK AÇILIŞ TOHUMU ──
///
/// Bu sabit artık DOĞRUDAN OKUNMAZ. Uygulamanın katalog erişimi
/// `kCategoryTree` üzerinden olur ve o, çalışma zamanında AKTİF
/// katalogu döndürür:
///
///   · sunucudan katalog geldiyse   → SUNUCU verisi
///   · henüz gelmediyse / hata varsa → bu gömülü liste
///
/// ⚠ ADI DEĞİŞTİ ama içeriği aynı. `kCategoryTree` adı korundu ki
/// katalogu okuyan on iki dosya ve testler DEĞİŞMEDEN sunucu
/// verisine geçsin — tek noktadan kaynak değişimi, on iki dosyayı
/// tek tek elden geçirmekten çok daha güvenli.
const Map<String, List<String>> kGomuluKatalog = {
  'Bahçe ve Peyzaj': [
    'Çim Halı / Suni Çim', 'Suni Çim Montajı', 'Suni Çim Serme',
    'Suni Çim Sökme', 'Bahçe Düzenleme', 'Çim Ekimi', 'Çim Serme',
    'Ağaç Budama', 'Ağaç Kesimi', 'Ağaç Dikimi', 'Bitki Dikimi',
    'Çiçek Dikimi', 'Bitki Hastalığı Tedavisi', 'Bahçe Bakımı',
    'Çim Biçme', 'Budama Sonrası Atık Temizliği', 'Bahçe Toprak Düzenleme',
    'Toprak Gübreleme', 'Otomatik Sulama Sistemi',
    'Otomatik Sulama Montajı', 'Bahçe Sulama Sistemi Bakımı',
    'Bahçe Drenajı', 'Bahçe Aydınlatma',
    'Bahçe Aydınlatma Sistemi Montajı', 'Bahçe Duvarı ve Çit',
    'Bahçe Çit Montajı', 'Bahçe Kapısı Montajı', 'Sera Kurulumu',
    'Peyzaj Tasarımı', 'Yağmur Suyu Toplama Sistemi',
    'Yağmur Suyu Depolama Sistemi', 'Drenaj Pompası Montajı'
  ],
  'Havuz Yapım ve Bakım': [
    'Havuz Yapımı', 'Havuz Bakımı', 'Havuz Kimyasal Dengeleme',
    'Havuz Tamiri', 'Havuz Su Kaçağı Onarımı', 'Havuz Kışa Hazırlık',
    'Havuz Açılış Bakımı', 'Havuz Kapatma Bakımı', 'Havuz Filtre Bakımı',
    'Havuz Filtresi Değişimi', 'Havuz Pompa Bakımı',
    'Havuz Pompa Değişimi', 'Havuz Motoru Tamiri',
    'Havuz Ekipmanları Montajı', 'Havuz Aydınlatma Tamiri',
    'Havuz Derz Yenileme', 'Havuz Kaplama Yenileme',
    'Havuz Isıtma Sistemi', 'Havuz Isı Pompası Montajı',
    'Havuz Otomasyon Sistemi', 'Havuz Kapak Sistemi'
  ],
  'Su Tesisatı': [
    'Su Tesisatçısı', 'Sıhhi Tesisat', 'Su Kaçağı Tespiti',
    'Kameralı Su Kaçağı Tespiti', 'Termal Kamera ile Su Kaçağı Tespiti',
    'Su Kaçağı Onarımı', 'Alt Kata Su Sızıntısı Onarımı',
    'Tıkanıklık Açma', 'Gider Açma', 'Musluk Montajı', 'Batarya Değişimi',
    'Klozet Montajı', 'Klozet Tamiri', 'Klozet İç Takım Değişimi',
    'Gömme Rezervuar Tamiri', 'Gömme Rezervuar Montajı', 'Sifon Tamiri',
    'Sifon Değişimi', 'Lavabo Montajı', 'Lavabo Tamiri', 'Vana Değişimi',
    'Su Sayacı Değişimi', 'Su Basıncı Problemi', 'Su Deposu Temizliği',
    'Tesisat Tamiri', 'Su Arıtma Servisi', 'Duş Bataryası Montajı',
    'Hidrofor Montajı', 'Hidrofor Bakımı', 'Hidrofor Tamiri',
    'Hidrofor Basınç Tankı Değişimi', 'Pissu Tesisatı',
    'Lavabo Su Akıtıyor', 'Klozet Su Kaçırıyor',
    'Alaturka Tuvaleti Alafrangaya Çevirme',
    'Gömme Rezervuar İç Takım Değişimi', 'Gömme Rezervuar Değişimi',
    'Batarya Montajı'
  ],
  'Doğalgaz': [
    'Doğalgaz Tesisatı', 'Doğalgaz İç Tesisatı', 'Doğalgaz Kolon Hattı',
    'Doğalgaz Kaçak Kontrolü', 'Doğalgaz Kaçak Tespiti',
    'Doğalgaz Kaçak Onarımı', 'Doğalgaz Boru Hattı Tadilatı',
    'Doğalgaz Tesisat Kontrolü', 'Doğalgaz Tesisat Uygunluk Kontrolü',
    'Doğalgaz Tesisat Sızdırmazlık Testi', 'Doğalgaz Tesisat Yenileme',
    'Doğalgaz Hat Tadilatı', 'Doğalgaz Ocak Bağlantısı',
    'Doğalgaz Ocak Dönüşümü', 'Doğalgaz Sobası Montajı', 'Kombi Montajı',
    'Kombi Değişimi', 'Kombi Yeri Değişimi', 'Kombi Baca Montajı',
    'Doğalgaz Projesi'
  ],
  'Kombi Servis': [
    'Kombi Tamiri', 'Kombi Bakımı', 'Kombi Arıza Tespiti',
    'Kombi Petek Isınmama Arızası', 'Kombi Su Basıncı Sorunu',
    'Kombi Su Kaçağı Tamiri', 'Kombi Eşanjör Temizliği',
    'Kombi Fan Değişimi', 'Kombi Pompa Değişimi', 'Kombi Sensör Değişimi',
    'Kombi Kart Tamiri', 'Kombi Baca Kontrolü', 'Kombi Baca Temizliği',
    'Kombi Yoğuşma Gideri Temizliği'
  ],
  'Isıtma Sistemleri': [
    'Petek Temizliği', 'Petek Montajı', 'Petek Havası Alma',
    'Petek Vana Değişimi', 'Termostatik Vana Montajı', 'Yerden Isıtma',
    'Yerden Isıtma Bakımı', 'Yerden Isıtma Tamiri',
    'Yerden Isıtma Kaçak Tespiti', 'Kalorifer Tesisatı',
    'Kalorifer Tesisatı Tamiri', 'Kalorifer Tesisatı Yenileme',
    'Merkezi Isıtma Sistemi Bakımı', 'Merkezi Isıtma Sistemi Tamiri',
    'Şofben Tamiri', 'Şofben Montajı', 'Termosifon Tamiri',
    'Termosifon Montajı', 'Radyatör Vana Değişimi',
    'Kalorifer Kazanı Bakımı', 'Oda Termostatı Montajı', 'Boyler Montajı',
    'Boyler Bakımı', 'Isı Pompası Montajı', 'Isı Pompası Bakımı',
    'Isı Pompası Tamiri', 'Petek Borusu Tesisatı'
  ],
  'Elektrik': [
    'Elektrikçi', 'Elektrik Arıza', 'Elektrik Tesisatı',
    'Ev Elektrik Tesisatı', 'Elektrik Tesisatı Yenileme',
    'Elektrik Kaçağı Tespiti', 'Priz Montajı', 'Priz Değişimi',
    'Anahtar Montajı', 'Anahtar Değişimi', 'Ampul Değişimi',
    'LED Aydınlatma Montajı', 'Sensörlü Aydınlatma Montajı',
    'Avize Montajı', 'Sigorta Panosu Montajı', 'Sigorta Değişimi',
    'Elektrik Panosu Yenileme', 'Aydınlatma Sistemleri',
    'Aydınlatma Otomasyonu', 'Kaçak Akım Rölesi Montajı',
    'Topraklama Ölçümü', 'Spot Aydınlatma Montajı',
    'Elektrik Kablo Çekimi', 'Elektrikli Panjur Montajı', 'Zil Montajı',
    'Kapı Zili Tamiri', 'Elektrikli Araç Şarj İstasyonu Montajı',
    'Wallbox Montajı'
  ],
  'Güvenlik Sistemleri': [
    'Kamera Sistemi Kurulumu', 'IP Kamera Sistemi',
    'Analog Kamera Sistemi', 'Kamera Montajı', 'Kamera Sökme',
    'Kamera Bakımı', 'Kamera Arıza Tamiri', 'Kamera Bakım ve Onarımı',
    'Alarm Sistemi Kurulumu', 'Hırsız Alarmı', 'Yangın Alarm Sistemi',
    'Yangın Algılama Sistemi', 'Gaz Alarm Sistemi',
    'Su Baskını Alarm Sistemi', 'Görüntülü Diafon', 'Diafon Tamiri',
    'Akıllı Ev Güvenlik Sistemi', 'Apartman Güvenlik Sistemi',
    'Kartlı Geçiş Sistemi', 'Parmak İzi Geçiş Sistemi',
    'Yüz Tanıma Sistemi', 'Turnike Sistemi', 'Otopark Bariyer Sistemi',
    'Otomatik Kapı Sistemi', 'Güvenlik Sistemi Uzaktan İzleme',
    'İnterkom/Diafon Montajı'
  ],
  'Klima Montaj ve Servis': [
    'Klima Montajı', 'Klima Bakımı', 'Klima Tamiri', 'Klima Temizliği',
    'Klima Gaz Dolumu', 'Klima Gaz Kaçağı Tespiti', 'Klima Sökme',
    'Klima Sökme-Takma', 'Klima Dış Ünite Montajı',
    'Klima İç Ünite Montajı', 'Klima Yer Değişimi', 'Klima Drenaj Hattı',
    'Klima Elektrik Bağlantısı', 'Multi Klima Sistemi Montajı',
    'VRF Klima Sistemi Bakımı'
  ],
  'Çilingir ve Kilit': [
    'Kapı Açma', 'Ev Kapısı Açma', 'Çelik Kapı Açma', 'Kilit Değişimi',
    'Kilit Tamiri', 'Silindir Değişimi', 'Barel Değişimi',
    'Kapı Kolu Değişimi', 'Akıllı Kilit Montajı', 'Şifreli Kilit Montajı',
    'Elektrikli Kilit Montajı', 'Manyetik Kilit Montajı',
    'Kapı Otomatiği Montajı', 'Panik Bar Montajı', 'Kapı Kilidi Bakımı',
    'Akıllı Kilit', 'Şifreli Kilit'
  ],
  'Uydu ve Anten Sistemleri': [
    'Uydu Kurulumu', 'Uydu Anteni Montajı', 'Uydu Anteni Ayarı',
    'Uydu Sinyal Sorunu', 'Uydu Kanal Ayarlama', 'Uydu Sinyal Ölçümü',
    'LNB Değişimi', 'Uydu Kablosu Çekme', 'Merkezi Uydu Sistemi',
    'Merkezi Uydu Sistemi Arızası', 'Merkezi Uydu Sistemi Yenileme',
    'TV Sinyal Dağıtım Sistemi', 'TV Anteni Montajı'
  ],
  'İnternet ve Ağ Kurulumu': [
    'İnternet Kurulumu', 'İnternet Nakli', 'İnternet Arıza / Hat Sorunu',
    'Modem Kurulumu', 'Wi-Fi Kurulumu', 'Wi-Fi Sinyal Güçlendirme',
    'Wi-Fi Mesh Sistem Kurulumu', 'Wi-Fi Access Point Kurulumu',
    'Wi-Fi Ölü Nokta Çözümü', 'Ev İçi Ağ Kurulumu', 'Router Kurulumu',
    'Mesh Wi-Fi Kurulumu', 'CAT6 Kablo Çekimi', 'Ethernet Prizi Montajı',
    'İnternet Kablosu Çekme', 'Fiber Kablo Çekimi',
    'Fiber Optik Sonlandırma', 'Fiber Optik Arıza Tespiti',
    'Network Kablo Testi', 'İnternet Arıza Tespiti'
  ],
  'Güneş Enerjisi Sistemleri': [
    'Ev Tipi Güneş Enerjisi Sistemi', 'Çatı Güneş Enerjisi Sistemi',
    'Güneş Paneli Montajı', 'Güneş Paneli Bakımı',
    'Güneş Paneli Temizliği', 'Güneş Paneli Arıza Tespiti',
    'Güneş Paneli Değişimi', 'On-Grid Güneş Enerjisi Sistemi',
    'Off-Grid Güneş Enerjisi Sistemi', 'Hibrit Güneş Enerjisi Sistemi',
    'Güneş Enerjisi Batarya Sistemi', 'Enerji Depolama Sistemi',
    'İnverter Montajı', 'Güneş Enerjisi Sistem Bakımı',
    'Güneş Enerjisi Sistem İzleme'
  ],
  'Oto Çekici ve Yol Yardım': [
    'Oto Çekici', 'Yol Yardım', 'Akü Takviye', 'Kilitli Araç Açma',
    'Lastik Yol Yardımı'
  ],
  'Oto Servis ve Bakım': [
    'Oto Elektrik', 'Oto Klima', 'Fren Balata Değişimi',
    'Periyodik Araç Bakımı', 'Motor Yağı Değişimi', 'Akü Değişimi',
    'Araç Klima Gaz Dolumu', 'Fren Bakımı', 'Bilgisayarlı Arıza Tespiti',
    'Triger Seti Değişimi', 'Yağ ve Filtre Değişimi', 'Şanzıman Bakımı'
  ],
  'Araç Temizlik ve Detaylı Bakım': [
    'Araç Detaylı Temizlik', 'Araç Koltuk Yıkama', 'Oto Yıkama',
    'Pasta ve Cila', 'Motor Yıkama', 'Yerinde Oto Yıkama',
    'Seramik Kaplama', 'Far Temizleme ve Parlatma', 'Araç Döşeme Yıkama'
  ],
  'Oto Ekspertiz': [
    'Oto Ekspertiz', 'Mobil Oto Ekspertiz'
  ],
  'Kaporta ve Boya': [
    'Kaporta Onarımı', 'Boya Onarımı', 'Mini Onarım', 'Göçük Düzeltme'
  ],
  'Lastik ve Jant Hizmetleri': [
    'Lastik Değişimi', 'Lastik Tamiri', 'Rot Balans Ayarı', 'Jant Onarımı'
  ],
  'Oto Görsel & Koruma Hizmetleri': [
    'Araç Kaplama', 'Oto Cam Filmi', 'Oto Boya Koruma', 'Oto Modifiye'
  ],
  'Oto Bakım & Servis': [
    'Mobil Lastik Hizmeti'
  ],
  'Beyaz Eşya Servisi': [
    'Buzdolabı Tamiri', 'Çamaşır Makinesi Tamiri',
    'Bulaşık Makinesi Tamiri', 'Kurutma Makinesi Tamiri', 'Fırın Tamiri',
    'Aspiratör Tamiri', 'Ankastre Cihaz Montajı', 'Davlumbaz Tamiri',
    'Su Sebili Tamiri', 'Mikrodalga Fırın Tamiri',
    'Derin Dondurucu Tamiri', 'Buzdolabı Bakımı',
    'Çamaşır Makinesi Bakımı', 'Bulaşık Makinesi Bakımı'
  ],
  'Elektronik Cihaz Tamiri': [
    'Televizyon Tamiri', 'Bilgisayar Tamiri', 'Telefon Tamiri',
    'Tablet Tamiri', 'Oyun Konsolu Tamiri', 'Telefon Ekran Değişimi',
    'Telefon Batarya Değişimi', 'Bilgisayar Format ve Kurulum',
    'Veri Kurtarma', 'Projeksiyon Tamiri', 'Saat Tamiri', 'Yazıcı Tamiri',
    'Monitör Tamiri', 'Ses Sistemi Tamiri', 'Hoparlör Tamiri',
    'Projeksiyon Kurulumu', 'Akıllı Saat Tamiri', 'Drone Tamiri'
  ],
  'Küçük Ev Aletleri': [
    'Küçük Ev Aletleri Tamiri', 'Kahve Makinesi Tamiri',
    'Elektrikli Süpürge Tamiri'
  ],
  'Temizlik Hizmetleri': [
    'Ev Temizliği', 'Boş Ev Temizliği', 'Ofis Temizliği',
    'İnşaat Sonrası Temizlik', 'Derin Temizlik', 'Taşınma Temizliği',
    'Cam Temizliği', 'Cam Silme', 'Ütü Hizmeti', 'Merdiven Temizliği',
    'Buharlı Ev Temizliği', 'Apartman / Ortak Alan Temizliği',
    'Buzdolabı İçi Temizliği', 'Fırın İçi Temizliği',
    'Dolap İçi Temizliği', 'Taşınma Öncesi Temizlik', 'Dükkan Temizliği'
  ],
  'Halı Yıkama': [
    'Kilim Yıkama', 'Yolluk Yıkama', 'Halı Leke Çıkarma',
    'Yerinde Halı Yıkama', 'Bambu Halı Yıkama', 'Ofis Halı Yıkama'
  ],
  'Koltuk ve Döşeme Yıkama': [
    'Koltuk Yıkama', 'Yatak Yıkama', 'Sandalye Yıkama', 'Halıfleks Yıkama'
  ],
  'İlaçlama ve Haşere Kontrolü': [
    'Ev İlaçlama', 'Böcek İlaçlama', 'Haşere İlaçlama', 'Kene İlaçlama',
    'Fare Mücadelesi', 'Tahtakurusu İlaçlama', 'Karınca İlaçlama',
    'Güve İlaçlama', 'Sinek ve Sivrisinek İlaçlama', 'Pire İlaçlama',
    'İşyeri İlaçlama'
  ],
  'Kuru Temizleme': [
    'Kuru Temizleme', 'Kıyafet Kuru Temizleme', 'Perde Kuru Temizleme',
    'Perde Yıkama', 'Stor Perde Temizliği'
  ],
  'Zemin ve Yüzey Temizliği': [
    'Mermer Cilalama', 'Mermer Silim', 'Zemin Cilalama'
  ],
  'Nakliyat ve Taşımacılık': [
    'Evden Eve Nakliyat', 'Şehirler Arası Nakliyat', 'Ofis Taşıma',
    'Parça Eşya Taşıma', 'Asansörlü Nakliyat', 'Piyano Taşıma',
    'Asansörlü Taşıma', 'Sigortalı Nakliyat', 'Şehir İçi Nakliyat',
    'Minivan Nakliye', 'Yük Taşıma', 'Koli Taşıma', 'Koltuk Taşıma',
    'Buzdolabı Taşıma', 'Çeyiz Taşıma', 'Paletli Yük Taşıma',
    'Motosiklet Taşıma', 'Araç Taşıma', 'Uluslararası Nakliyat'
  ],
  'Depolama Hizmetleri': [
    'Eşya Depolama', 'Mini Depo', 'Ticari Eşya Depolama', 'Arşiv Depolama'
  ],
  'Kurye ve Küçük Taşıma': [
    'Moto Kurye', 'Paket Taşıma', 'Küçük Nakliye', 'Aynı Gün Kurye',
    'Arabalı Kurye', 'Acil Kurye', 'Evrak Kurye'
  ],
  'Personel ve Öğrenci Servisi': [
    'Personel Servisi', 'Fabrika Personel Servisi',
    'İş Yeri Personel Servisi', 'Öğrenci Servisi', 'Okul Servisi',
    'Servis Aracı Kiralama'
  ],
  'Depolama & Lojistik': [
    'Antrepo'
  ],
  'Güzellik ve Bakım Hizmetleri': [
    'Makyaj', 'Manikür Pedikür', 'Saç Tasarımı', 'Gelin Saçı ve Makyajı',
    'Kalıcı Oje', 'Ağda ve Epilasyon', 'Cilt Bakımı', 'Evde Kuaför'
  ],
  'Masaj ve Wellness': [
    'Masaj', 'Evde Masaj', 'Spa Bakımı'
  ],
  'Spor': [
    'Personal Trainer', 'Pilates', 'Yoga', 'Yüzme Dersi',
    'Fitness Özel Ders', 'Tenis Dersi', 'Voleybol Dersi', 'Kiralık Kaleci',
    'Evde Fitness Antrenörü', 'Beslenme ve Antrenman Programı'
  ],
  'Kişisel Gelişim ve Koçluk': [
    'Yaşam Koçu'
  ],
  'Evcil Hayvan Hizmetleri': [
    'Köpek Gezdirme', 'Evcil Hayvan Bakımı', 'Pet Kuaför',
    'Evde Hayvan Bakıcılığı', 'Köpek Eğitimi', 'Evcil Hayvan Taşıma',
    'Pet Oteli ve Pansiyon', 'Pet Kreş Hizmeti', 'Kedi Bakımı',
    'Kedi Gezdirme', 'Evcil Hayvan Gezdirme', 'Evcil Hayvan Bakıcısı',
    'Evde Evcil Hayvan Bakımı', 'Evcil Hayvan Eğitimi'
  ],
  'Özel Ders': [
    'Matematik Özel Ders', 'Fizik Özel Ders', 'Fen Bilimleri Özel Ders',
    'İlkokul Özel Ders', 'Kimya Özel Ders', 'Biyoloji Özel Ders',
    'Türkçe ve Edebiyat Özel Ders', 'Geometri Özel Ders', 'LGS Hazırlık',
    'YKS Hazırlık', 'Okuma Yazma Özel Ders', 'Sınav Koçluğu'
  ],
  'Yabancı Dil Eğitimi': [
    'İngilizce Özel Ders', 'Almanca Özel Ders', 'Fransızca Özel Ders',
    'Online İngilizce Dersi', 'İspanyolca Özel Ders', 'Rusça Özel Ders',
    'IELTS ve TOEFL Hazırlık', 'İş İngilizcesi', 'İtalyanca Özel Ders',
    'Yabancılara Türkçe Öğretimi'
  ],
  'Sürücü Eğitimi': [
    'Direksiyon Dersi', 'İleri Sürüş Eğitimi', 'Park Etme Eğitimi',
    'Motosiklet Direksiyon Dersi'
  ],
  'Müzik Dersleri': [
    'Piyano Dersi', 'Gitar Dersi', 'Keman Dersi', 'Şan Dersi',
    'Bağlama Dersi', 'Davul ve Perküsyon Dersi', 'Ud ve Kanun Dersi',
    'Flüt Dersi', 'Ukulele Dersi', 'Elektronik Piyano Dersi'
  ],
  'Kodlama ve Yazılım Eğitimi': [
    'Çocuklar İçin Kodlama', 'Python Eğitimi', 'Web Geliştirme Eğitimi'
  ],
  'Teknik ve Hobi Eğitimleri': [
    'Drone Eğitimi'
  ],
  'Yazılım ve Web Hizmetleri': [
    'Web Sitesi Yapımı', 'Mobil Uygulama Geliştirme',
    'E-Ticaret Sitesi Yapımı', 'WordPress Site Kurulumu',
    'Web Sitesi Bakımı', 'SEO Uyumlu Site Kurulumu',
    'Yazılım Danışmanlığı', 'Veri Tabanı Kurulumu', 'API Entegrasyonu',
    'Mobil Uygulama Bakımı', 'Web Uygulama Geliştirme'
  ],
  'Grafik ve Logo Tasarım': [
    'Logo Tasarımı', 'Grafik Tasarım', 'Kurumsal Kimlik Tasarımı',
    'Sosyal Medya Görsel Tasarımı', 'Katalog ve Broşür Tasarımı',
    'Ambalaj Tasarımı'
  ],
  'Dijital Pazarlama': [
    'Sosyal Medya Yönetimi', 'Google Reklam Yönetimi', 'SEO Hizmeti',
    'Meta Reklam Yönetimi', 'İçerik Üretimi',
    'E-Ticaret Pazaryeri Yönetimi'
  ],
  'Video ve Animasyon': [
    'Video Montajı', 'Reels ve Kısa Video Montajı', 'Motion Graphics',
    '2D Animasyon'
  ],
  'Müzik & Ses Prodüksiyonu': [
    'Müzik Prodüksiyon', 'Ses Kayıt', 'Şarkı Aranje', 'Mix & Mastering',
    'Jingle Yapımı', 'Müzik Yapımı'
  ],
  'Dijital Pazarlama & Reklam': [
    'Influencer Marketing', 'Mobil Reklamcılık', 'Reklam Ajansı'
  ],
  'Video, Ses & Animasyon': [
    'Seslendirme & Dublaj', 'Seslendirme', 'Dublaj'
  ],
  'Etkinlik ve Organizasyon': [
    'Masa & Sandalye Kiralama', 'Palyaço', 'Doğum Günü Organizasyonu',
    'Düğün Organizasyonu', 'Balon ve Süsleme',
    'Kına ve Nişan Organizasyonu', 'Kurumsal Etkinlik Organizasyonu',
    'Ses ve Işık Sistemi Kiralama'
  ],
  'Fotoğraf Çekimi': [
    'Drone Çekimi', 'Ürün Fotoğraf Çekimi', 'Kurumsal Fotoğraf Çekimi',
    'Düğün ve Nişan Fotoğrafçısı', 'Bebek ve Aile Çekimi',
    'Video Çekim ve Kurgu'
  ],
  'Catering ve İkram': [
    'Catering Hizmeti', 'Kokteyl İkram Hizmeti', 'Etkinlik Yemek Servisi',
    'Yaprak Sarma Yapımı'
  ],
  'Etkinlik Personeli': [
    'Garson', 'Servis Personeli', 'Host / Hostes', 'Karşılama Personeli',
    'Komi', 'Barmen / Bar Servis Personeli', 'Etkinlik Görevlisi',
    'Etkinlik Kurulum Personeli', 'Etkinlik Söküm Personeli'
  ],
  'Müzik & Eğlence': [
    'Orkestra', 'Solist', 'Canlı Müzik', 'Müzik Grubu', 'DJ',
    'Fasıl Ekibi', 'Davul Zurna', 'Bando Takımı', 'Mehter Takımı',
    'Dansöz', 'Dansçı', 'Dans Ekibi', 'Dans Gösterisi'
  ],
  'Fuar & Stand Hizmetleri': [
    'Stand Kurulumu', 'Fuar Standı Tasarımı', 'Fuar Standı Montajı',
    'Fuar Standı Sökümü'
  ],
  'İnşaat ve Kaba Yapı': [
    'Duvar Ustası', 'İnşaat Kalıp Ustası', 'Beton Kalıp Ustası',
    'İnşaat Demir Ustası', 'Demir Bağlama Ustası', 'İnşaat Demir Döşeme',
    'Kaba İnşaat', 'Anahtar Teslim İnşaat', 'Duvar Örme', 'Yıkım İşleri',
    'Moloz Taşıma', 'Şap Atma', 'Kolon Güçlendirme'
  ],
  'Çatı Yapım ve Onarım': [
    'Çatı Tamiri', 'Çatı Yapımı', 'Çatı İzolasyonu', 'Çatı Aktarma',
    'Oluk Montajı', 'Kiremit Değişimi', 'Kiremit Aktarma',
    'Oluk Temizliği', 'Çatı Kaçak Onarımı', 'Çelik Çatı İmalatı',
    'Çatı Oluk Bakımı', 'Çatı Kiremit Tamiri'
  ],
  'Tadilat ve Yenileme': [
    'Ev Tadilatı', 'Daire Tadilatı', 'Ofis Tadilatı', 'Dükkan Tadilatı',
    'Anahtar Teslim Tadilat', 'Kiralık Daire Tadilatı', 'Villa Tadilatı',
    'Bina Yenileme', 'Konut Tadilatı', 'Bina Restorasyonu'
  ],
  'Banyo Tadilat ve Montaj': [
    'Banyo Tadilatı', 'Duşakabin Montajı', 'Banyo Dolabı Montajı',
    'Duş Teknesi Montajı', 'Küvet Montajı', 'Klozet Değişimi',
    'Banyo Fayans Yenileme', 'Duşakabin Tamiri', 'Duşakabin Değişimi'
  ],
  'Mutfak Tadilat ve Dolap': [
    'Mutfak Tadilatı', 'Mutfak Dolabı Yapımı', 'Mutfak Dolabı Tamiri',
    'Mutfak Tezgahı Montajı', 'Hazır Mutfak', 'Mutfak Dolabı Montajı',
    'Mutfak Dolabı Kapak Değişimi', 'Granit Tezgah Montajı',
    'Evye Montajı', 'Mutfak Tezgahı Yapımı'
  ],
  'Boya ve Badana': [
    'Boya Badana', 'İç Cephe Boya', 'Dış Cephe Boyama', 'Dekoratif Boya',
    'Kapı Boyama', 'Tavan Boyama', 'Silinebilir Boya Uygulaması',
    'Mobilya Boyama', 'Cephe Boya Onarımı', 'Boya Öncesi Hazırlık'
  ],
  'Alçı ve Sıva İşleri': [
    'Alçıpan', 'Alçı Sıva', 'Kartonpiyer', 'Asma Tavan Yapımı',
    'Saten Alçı Uygulaması', 'Sıva Tamiri'
  ],
  'Duvar Kağıdı ve Dekorasyon': [
    'Çıta Uygulaması', 'Dekoratif Duvar Çıtası', 'MDF Çıta Uygulaması',
    'PVC Çıta Uygulaması', 'Duvar Kağıdı Uygulama', 'Duvar Paneli',
    '3D Duvar Kaplama', 'Poster Duvar Kağıdı', 'Duvar Kağıdı Sökme',
    'Akustik Panel Montajı'
  ],
  'Fayans ve Seramik Döşeme': [
    'Fayans Döşeme', 'Seramik Döşeme', 'Fayans Tamiri', 'Mermer Döşeme',
    'Granit Uygulama', 'Derz Yenileme', 'Silikon Uygulaması',
    'Mermer Eşik Montajı', 'Dış Cephe Seramik'
  ],
  'Zemin Kaplama': [
    'Parke Döşeme', 'Parke Tamiri', 'Halıfleks Uygulama', 'PVC Zemin',
    'Epoksi Zemin Kaplama', 'Parke Zımpara ve Cila', 'Süpürgelik Montajı',
    'Vinil Zemin Uygulaması', 'Zemin Şap Düzeltme', 'Laminat Parke Döşeme'
  ],
  'Yalıtım ve Mantolama': [
    'Su Yalıtımı', 'Isı Yalıtımı', 'Mantolama', 'Ses Yalıtımı',
    'Teras İzolasyonu', 'Balkon Su Yalıtımı', 'Çatı Su Yalıtımı',
    'Rutubet ve Küf Onarımı', 'Pencere Ses Yalıtımı',
    'Ses İzolasyonu Uygulaması', 'Teras Su Yalıtımı'
  ],
  'PVC ve Alüminyum Doğrama': [
    'PVC Pencere Montajı', 'PVC Pencere Tamiri', 'PVC Kapı',
    'Alüminyum Doğrama', 'Sineklik Montajı', 'Panjur Sistemleri',
    'Pencere Ayarı ve Fitil Değişimi', 'Pileli Sineklik Montajı',
    'Otomatik Panjur Montajı', 'Alüminyum Cephe Kaplama',
    'Pencere Sineklik Montajı'
  ],
  'Demir Doğrama ve Kaynak': [
    'Demir Doğrama İşleri', 'Ferforje', 'Kaynakçı', 'Korkuluk Montajı',
    'Çelik Konstrüksiyon', 'Balkon Korkuluğu Montajı',
    'Merdiven Korkuluğu', 'Demir Kapı İmalatı', 'Yerinde Kaynak İşi'
  ],
  'Marangozluk ve Ahşap İşleri': [
    'Özel Mobilya Yapımı', 'Ahşap Raf Yapımı', 'Ahşap Masa Yapımı',
    'Ahşap Merdiven', 'Ahşap Pergola', 'Masa ve Sandalye Tamiri',
    'Vernik ve Cila', 'Ahşap Deck Uygulaması', 'Ahşap Kapı Onarımı',
    'Ölçüye Özel Dolap', 'Ahşap Restorasyon'
  ],
  'Mobilya Yapım ve Montaj': [
    'Mobilya Montajı', 'Mobilya Tamiri', 'Mobilya İmalatı',
    'Gardırop Yapımı', 'Gardırop Montajı', 'TV Ünitesi Yapımı',
    'TV Ünitesi Montajı', 'Vestiyer Yapımı', 'Hazır Mobilya Kurulumu',
    'Yatak Odası Takımı Montajı', 'Raf ve Kitaplık Montajı',
    'Mobilya Sökme ve Taşıma', 'İç Kapı Montajı', 'İç Kapı İmalatı',
    'Kapı Tamiri', 'Kapı Menteşe Ayarı', 'Sürgülü Kapı Montajı',
    'Korniş Montajı'
  ],
  'Asansör Montaj ve Bakım': [
    'Asansör Bakımı', 'Asansör Tamiri', 'Asansör Montajı',
    'Asansör Kabin Yenileme', 'Asansör Kapı Tamiri'
  ],
  'Havalandırma Sistemleri': [
    'Havalandırma Sistemleri', 'Havalandırma Kanalı Montajı',
    'Davlumbaz Havalandırma Montajı'
  ],
  'Çelik Yapı & Prefabrik Yapılar': [
    'Çelik Ev Yapımı', 'Anahtar Teslim Prefabrik Ev',
    'Prefabrik Ev Yapımı', 'Prefabrik Ev Montajı', 'Çelik Ev Montajı',
    'Konteyner Yapımı', 'Konteyner Ev', 'Konteyner Ofis',
    'Konteyner Montajı', 'Konteyner Demontajı', 'Konteyner Taşıma',
    'Konteyner Tadilatı', 'Yangın Merdiveni'
  ],
  'Pergola & Gölgelendirme Sistemleri': [
    'Alüminyum Pergola', 'Pergola Montajı', 'Pergola Kapatma',
    'Pergola Tamiri', 'Tente', 'Mafsallı Tente', 'Otomatik Tente',
    'Balkon Tentesi', 'Tente Tamiri', 'Tente Kumaş Değişimi',
    'Kış Bahçesi Sistemleri', 'Çardak & Kamelya'
  ],
  'Cam Film ve Kış Bahçesi': [
    'Cam Filmi Uygulama', 'Güneş Kontrol Cam Filmi', 'Güvenlik Cam Filmi',
    'Dekoratif Cam Filmi', 'Cam Filmi Sökme', 'Kış Bahçesi Yapımı',
    'Kış Bahçesi Cam Sistemi', 'Kış Bahçesi Kapatma',
    'Kış Bahçesi Bakım ve Tadilat'
  ],
  'Cam ve Ayna Hizmetleri': [
    'Cam Balkon', 'Cam Değişimi', 'Ayna Montajı', 'Duş Camı Montajı',
    'Isıcam Değişimi', 'Kırık Cam Değişimi', 'Giyotin Cam Montajı'
  ],
  'Kapı Sistemleri': [
    'Çelik Kapı İmalatı', 'Çelik Kapı Değişimi',
    'Çelik Kapı Kilit Değişimi', 'Çelik Kapı Kasa Değişimi',
    'Çelik Kapı Montajı', 'Çelik Kapı Tamiri', 'Fotoselli Otomatik Kapı',
    'Garaj Kapı Sistemleri'
  ],
  'Kepenk Sistemleri': [
    'Otomatik Kepenk', 'Otomatik Kepenk Montajı', 'Otomatik Kepenk Tamiri',
    'Otomatik Kepenk Servisi', 'Garaj Kepengi'
  ],
  'Endüstriyel Yapı & Kurulum': [
    'Fabrika Kurulumu', 'Fabrika Montajı', 'Endüstriyel Makine Montajı',
    'Üretim Tesisi Kurulumu'
  ],
  'Cam & Alüminyum': [
    'Cam Tavan Sistemleri', 'Lamine Cam', 'Masa Camı İmalatı',
    'Ofis Cam Bölme', 'Dekoratif Ayna Yapımı'
  ],
  'Zemin & Beton': [
    'Baskı Beton', 'Hazır Beton', 'İnşaat Temeli'
  ],
  'Sauna, Hamam & Spa': [
    'Sauna Yapımı', 'Hamam Yapımı', 'Jakuzi', 'Spa Yapımı'
  ],
  'Jeneratör Servisi': [
    'Jeneratör Servisi', 'Jeneratör Bakımı', 'Jeneratör Arıza Onarımı',
    'Jeneratör Montajı', 'Jeneratör Devreye Alma'
  ],
  'Kompresör ve Basınçlı Hava Sistemleri': [
    'Kompresör Servisi', 'Kompresör Bakımı', 'Kompresör Tamiri',
    'Kompresör Montajı', 'Basınçlı Hava Sistemi Kurulumu',
    'Basınçlı Hava Hattı Bakımı'
  ],
  'Endüstriyel Makine ve Ekipman Servisi': [
    'Endüstriyel Makine Bakımı', 'Endüstriyel Makine Arıza Tespiti',
    'Endüstriyel Makine Tamiri', 'Makine Kurulum ve Devreye Alma',
    'Pompa Servisi', 'Endüstriyel Yıkama Makinesi Servisi'
  ],
  'Endüstriyel Otomasyon ve Kontrol': [
    'PLC Programlama', 'PLC Arıza ve Bakım', 'Otomasyon Panosu Yapımı',
    'Otomasyon Panosu Revizyonu', 'Frekans İnverteri Kurulumu',
    'Endüstriyel Otomasyon Devreye Alma'
  ],
  'Ayakkabı ve Deri İşleri': [
    'Ayakkabı Tamiri', 'Bot Tamiri', 'Çizme Tamiri',
    'Spor Ayakkabı Tamiri', 'Sneaker Tamiri', 'Ayakkabı Boyama',
    'Ayakkabı Temizleme', 'Ayakkabı Bakımı', 'Ayakkabı Restorasyonu',
    'Ayakkabı Yapımı', 'Çanta Tamiri', 'Çanta Yapımı', 'Çanta Temizleme',
    'Çanta Boyama', 'Çanta Restorasyonu', 'Deri Tamiri',
    'Deri Ürün Yapımı', 'Deri Boyama', 'Deri Temizleme', 'Deri Bakımı',
    'Deri Restorasyonu', 'Kemer Tamiri', 'Kemer Yapımı', 'Cüzdan Tamiri',
    'Cüzdan Yapımı', 'Çanta Fermuar Değişimi', 'Deri/Süet Temizliği',
    'Deri/Süet Boyama', 'Deri Ceket Tadilatı', 'Valiz Tekerlek Değişimi'
  ],
  'Ev Tekstili': [
    'Yorgan Dikimi', 'Yorgan Yapımı', 'Yorgan Yenileme',
    'Yorgan İçi Değişimi', 'Yatak Yenileme', 'Yatak Dolgusu Yenileme',
    'Yatak Tamiri', 'Halı Tamiri', 'Halı Dokuma', 'Halı Restorasyonu',
    'Halı Saçak Yenileme', 'Halı Overlok', 'Kilim Tamiri', 'Kilim Dokuma',
    'Kilim Restorasyonu', 'Kırlent Dikimi', 'Masa Örtüsü Dikimi',
    'Nevresim Dikimi', 'Battaniye Dikimi', 'Perde Montajı ve Sökümü'
  ],
  'Perde Hizmetleri': [
    'Perde Dikimi', 'Perde Tadilatı', 'Perde Temizleme',
    'Perde Ölçüsü Alma', 'Perde Montajı', 'Stor Perde', 'Fon Perde Dikimi'
  ],
  'Örgü ve Triko': [
    'Triko Tamiri', 'Triko Yapımı', 'Triko Yenileme', 'Triko Tadilatı',
    'Örgü Yapımı', 'Kazak Örme', 'Hırka Örme', 'Bebek Örgüsü',
    'Örgü Kıyafet Tamiri'
  ],
  'Nakış ve Tekstil İşleme': [
    'Nakış', 'El Nakışı', 'Bilgisayarlı Nakış', 'Logo Nakışı',
    'Kişiye Özel Nakış', 'Monogram', 'Tekstil İşleme', 'Piko', 'İlik Açma'
  ],
  'Kumaş ve Tekstil İşleme': [
    'Kumaş Dokuma', 'Kumaş Kesimi', 'Kumaş Tamiri', 'Kumaş Baskı',
    'Kumaş Boyama'
  ],
  'Terzilik ve Dikim': [
    'Fason Dikim', 'Seri Dikim', 'Numune Dikimi', 'Kalıp Hazırlama',
    'Özel Ölçü Kalıp Hazırlama', 'Overlok Hizmeti', 'Reçme Hizmeti',
    'Tekstil Ütüleme', 'Tekstil Paketleme', 'Kişiye Özel Kıyafet Dikimi',
    'Gelinlik Dikimi', 'Abiye Dikimi', 'Damatlık Dikimi',
    'Üniforma Dikimi', 'Kostüm Dikimi', 'Fermuar Değişimi',
    'Düğme Değişimi', 'Astar Yenileme'
  ],
  'Mimari Proje': [
    'Mimari Proje', 'Ruhsat Projesi', 'Röleve Projesi',
    'Restorasyon Projesi', 'İç Mekân Projesi', 'Vaziyet Planı',
    '3D Mimari Modelleme'
  ],
  'Statik ve Yapı Projeleri': [
    'Statik Proje', 'Çelik Yapı Projesi', 'Betonarme Yapı Projesi',
    'Yapı Statiği Hesabı', 'Taşıyıcı Sistem Analizi',
    'Güçlendirme Projesi', 'Deprem Performans Analizi',
    'Yapı Hasar Tespiti'
  ],
  'Elektrik Projeleri': [
    'Elektrik Projesi', 'Elektrik Tesisat Projesi', 'Aydınlatma Projesi',
    'Topraklama Projesi', 'Paratoner Projesi', 'Yangın Algılama Projesi'
  ],
  'Mekanik Projeler': [
    'Mekanik Tesisat Projesi', 'Isıtma Projesi', 'Sıhhi Tesisat Projesi',
    'Havalandırma Projesi', 'Klima Projesi', 'Yangın Tesisatı Projesi'
  ],
  'Harita ve Ölçüm': [
    'Harita Ölçümü ve Aplikasyon', 'Plankote', 'Halihazır Harita',
    'Kotlu Kroki', 'Parsel Ölçümü', 'İmar Uygulaması', 'Arazi Ölçümü'
  ],
  'Zemin ve Jeoteknik': [
    'Zemin Etüdü', 'Jeolojik Etüt', 'Jeoteknik Etüt', 'Zemin Sondajı',
    'Zemin Analizi'
  ],
  'Enerji ve Yapı Belgelendirme': [
    'Enerji Kimlik Belgesi', 'Enerji Performans Analizi'
  ],
  'Proje Danışmanlığı': [
    'Proje Yönetimi', 'Teknik Şartname Hazırlama', 'Metraj ve Keşif',
    'Yaklaşık Maliyet Hesabı', 'Proje Kontrol ve Teknik Danışmanlık'
  ],
  'Yapı Denetim': [
    'Yapı Denetim Hizmeti', 'Yapı Denetim Proje Kontrolü',
    'İnşaat Kontrolü', 'Hakediş Kontrolü',
    'Beton ve Yapı Malzemesi Kontrolü'
  ],
  'Avukatlık ve Hukuk': [
    'Hukuki Danışmanlık', 'Dava Danışmanlığı', 'Dava Takibi',
    'İcra Takibi', 'Alacak Takibi', 'Sözleşme Hazırlama',
    'Sözleşme İnceleme', 'İş Hukuku Danışmanlığı',
    'İşçi Hakları Danışmanlığı', 'İşveren Hukuku Danışmanlığı',
    'Kira Hukuku', 'Gayrimenkul Hukuku', 'Aile Hukuku', 'Boşanma Davası',
    'Miras Hukuku', 'Tüketici Hukuku', 'Ceza Hukuku', 'Ticaret Hukuku',
    'Şirketler Hukuku', 'Vergi Hukuku', 'Bilişim Hukuku',
    'KVKK Danışmanlığı', 'İş Kazası Hukuku', 'Tazminat Davaları',
    'Arabuluculuk', 'Marka ve Patent Hukuku', 'Fikri Mülkiyet Hukuku',
    'Hukuki Belge Hazırlama', 'Hukuki Belge İnceleme',
    'İş Hukuku Uyuşmazlıkları', 'İcra ve İflas Hukuku',
    'Tüketici Uyuşmazlıkları', 'Gayrimenkul ve Kira Uyuşmazlıkları',
    'Miras ve Veraset İşlemleri', 'Aile ve Boşanma Hukuku',
    'Ceza Hukuku Danışmanlığı', 'Ticaret ve Şirketler Hukuku',
    'Arabuluculuk Hizmeti'
  ],
  'Muhasebe ve Mali Müşavirlik': [
    'Ön Muhasebe', 'Genel Muhasebe', 'Mali Müşavirlik',
    'Vergi Danışmanlığı', 'Vergi Beyannamesi Hazırlama', 'KDV Beyannamesi',
    'Gelir Vergisi İşlemleri', 'Kurumlar Vergisi İşlemleri',
    'Geçici Vergi İşlemleri', 'E-Fatura İşlemleri', 'E-Arşiv İşlemleri',
    'E-Defter İşlemleri', 'SGK İşlemleri', 'Bordro Hazırlama',
    'Personel Özlük İşlemleri', 'Şirket Kuruluş İşlemleri',
    'Şahıs Şirketi Kuruluşu', 'Limited Şirket Kuruluşu',
    'Anonim Şirket Kuruluşu', 'Şirket Kapanış İşlemleri',
    'Vergi Mükellefiyeti İşlemleri', 'Muhasebe Kayıt İşlemleri',
    'Finansal Raporlama', 'Maliyet Analizi', 'Muhasebe Danışmanlığı',
    'Mali Denetim Danışmanlığı', 'Şirket Kuruluş Danışmanlığı',
    'E-Fatura ve E-Arşiv Danışmanlığı', 'Bordro ve Özlük Hizmetleri',
    'Mali Müşavirlik Danışmanlığı', 'Vergi Uyuşmazlık Danışmanlığı'
  ],
  'İş Güvenliği ve İSG': [
    'İş Güvenliği Uzmanlığı', 'İSG Danışmanlığı', 'Risk Değerlendirmesi',
    'İş Yeri Risk Analizi', 'Acil Durum Eylem Planı',
    'Acil Durum Planı Hazırlama', 'Acil Durum Tatbikatı', 'İSG Eğitimleri',
    'Çalışan İş Güvenliği Eğitimi', 'İşe Giriş İSG Eğitimi',
    'Yangın Eğitimi', 'Tahliye Eğitimi', 'İş Kazası İnceleme',
    'İş Kazası Raporlama', 'İSG Saha Denetimi', 'İSG Dokümantasyonu',
    'İSG Kurul Danışmanlığı', 'İş Hijyeni Danışmanlığı',
    'Periyodik Kontrol Organizasyonu', 'Risk Analizi Güncelleme',
    'İSG Mevzuat Danışmanlığı', 'OSGB Hizmetleri',
    'İSG Risk Değerlendirmesi', 'İş Yeri İSG Denetimi'
  ],
  'Marka ve Patent': [
    'Marka Araştırması', 'Marka Başvurusu', 'Marka Tescili',
    'Marka Yenileme', 'Marka Devir İşlemleri', 'Marka İtiraz İşlemleri',
    'Marka İzleme', 'Marka Koruma Danışmanlığı', 'Patent Araştırması',
    'Patent Başvurusu', 'Patent Tescili', 'Faydalı Model Başvurusu',
    'Faydalı Model Tescili', 'Tasarım Tescili',
    'Endüstriyel Tasarım Başvurusu', 'Patent Yenileme',
    'Patent Devir İşlemleri', 'Patent İtiraz İşlemleri',
    'Fikri Mülkiyet Danışmanlığı', 'Telif Hakkı Danışmanlığı',
    'Lisanslama Danışmanlığı', 'Marka İtirazı'
  ],
  'Sigorta': [
    'Sigorta Danışmanlığı', 'Sigorta Poliçesi Karşılaştırma',
    'Konut Sigortası', 'DASK', 'İşyeri Sigortası',
    'Ticari İşletme Sigortası', 'Kasko', 'Trafik Sigortası',
    'Sağlık Sigortası', 'Tamamlayıcı Sağlık Sigortası',
    'Özel Sağlık Sigortası', 'Hayat Sigortası', 'Ferdi Kaza Sigortası',
    'Seyahat Sigortası', 'İşveren Sorumluluk Sigortası',
    'Mesleki Sorumluluk Sigortası', 'Nakliyat Sigortası',
    'Yangın Sigortası', 'Tarım Sigortası', 'Makine Kırılması Sigortası',
    'Elektronik Cihaz Sigortası', 'Sigorta Hasar Danışmanlığı',
    'Hasar Dosyası Takibi', 'Poliçe Yenileme',
    'Kurumsal Sigorta Danışmanlığı'
  ],
  'Ofis & İş Yeri Hizmetleri': [
    'Hazır Ofis', 'Sanal Ofis', 'E-Ofis', 'Toplantı Odası Kiralama',
    'Paylaşımlı Ofis', 'Sekreterya Hizmeti', 'Çağrı Karşılama Hizmeti'
  ],
  'Dış Ticaret & Gümrük': [
    'Gümrük Müşaviri', 'Gümrük Danışmanlığı', 'İthalat İşlemleri',
    'İhracat İşlemleri', 'Gümrük İşlemleri Danışmanlığı'
  ],
  'Teşvik & Hibe Danışmanlığı': [
    'KOSGEB Danışmanlığı', 'Teşvik Danışmanlığı', 'Hibe Danışmanlığı',
    'Yatırım Teşvik Danışmanlığı', 'Devlet Destekleri Danışmanlığı'
  ],
  'Hasta Bakımı': [
    'Günlük Hasta Bakımı', 'Yatılı Hasta Bakımı', 'Hasta Öz Bakım',
    'Hasta Beslenme', 'Hasta Hijyen ve Banyo',
    'Hasta Giyinme ve Günlük Yaşam', 'Hasta Mobilizasyon'
  ],
  'Yaşlı Bakımı': [
    'Günlük Yaşlı Bakımı', 'Yatılı Yaşlı Bakımı', 'Yaşlı Öz Bakım',
    'Yaşlı Beslenme', 'Yaşlı Hijyen ve Banyo',
    'Yaşlı Giyinme ve Günlük Yaşam', 'Yaşlı Gezdirme',
    'Alzheimer ve Demans Bakımı', 'Yaşlı Refakat',
    'Yaşlı Alışveriş Refakati', 'Yaşlı Randevu Refakati',
    'Yaşlı Sosyal Aktivite Refakati'
  ],
  'Evde Hasta Bakımı': [
    'Evde Günlük Hasta Bakımı', 'Evde Hasta Öz Bakım',
    'Evde Hasta Beslenme', 'Evde Hasta Hijyen ve Banyo',
    'Evde Hasta Giyinme', 'Evde Hasta Mobilizasyon', 'Evde Hasta Refakati',
    'Evde Hasta Günlük Yaşam Yardımı', 'Evde Hasta Alışveriş Yardımı',
    'Evde Hasta Sosyal Refakati'
  ],
  'Evde Yaşlı Bakımı': [
    'Evde Günlük Yaşlı Bakımı', 'Evde Yaşlı Öz Bakım',
    'Evde Yaşlı Beslenme', 'Evde Yaşlı Hijyen ve Banyo',
    'Evde Yaşlı Giyinme', 'Evde Yaşlı Mobilizasyon', 'Evde Yaşlı Refakati',
    'Evde Alzheimer ve Demans Bakımı', 'Evde Yaşlı Günlük Yaşam Yardımı',
    'Evde Yaşlı Alışveriş Yardımı', 'Evde Yaşlı Sosyal Refakati'
  ],
  'Hastane Refakatçisi': [
    'Hastane Hasta Refakati', 'Hastane Yaşlı Refakati',
    'Hastane Gece Refakati', 'Hastane Gündüz Refakati',
    'Hastane Yatılı Refakat', 'Hastane Taburculuk Refakati'
  ],
  'Evde Refakat': [
    'Gece Evde Refakat', 'Gündüz Evde Refakat', 'Yatılı Evde Refakat',
    'Randevu ve Hastane Gidiş Refakati', 'Alışveriş Refakati',
    'Günlük İşlere Refakat', 'Sosyal Aktivite Refakati'
  ],
  'Günlük Yaşam Desteği': [
    'Kişisel Bakım', 'Banyo ve Hijyen', 'Giyinme ve Soyunma',
    'Beslenme ve Yemek', 'Ev İçinde Günlük Yaşam Yardımı',
    'Alışveriş ve Temel İhtiyaç Yardımı',
    'Yürüyüş ve Sosyal Aktivite Refakati',
    'Randevu ve Günlük İşlere Refakat'
  ],
  'Geleneksel ve Tamamlayıcı Sağlık Uygulamaları': [
    'Kupa Uygulaması (Hacamat)', 'Sülük Uygulaması (Hirudoterapi)',
    'Akupunktur Uygulaması', 'Apiterapi Uygulaması',
    'Fitoterapi Uygulaması', 'Larva (Maggot) Uygulaması',
    'Osteopati Uygulaması', 'Müzikterapi Uygulaması',
    'Refleksoloji Uygulaması', 'Hipnoz Uygulaması', 'Homeopati Uygulaması',
    'Mezoterapi Uygulaması', 'Ozon Uygulaması', 'Proloterapi Uygulaması',
    'Kayropraktik Uygulaması'
  ],
  'Tarım Danışmanlığı': [
    'Tarım Danışmanlığı', 'Ziraat Danışmanlığı',
    'Tarımsal Sulama Danışmanlığı'
  ],
  'Tarla ve Bahçe İşleri': [
    'Tarla Sürme', 'Toprak Hazırlama', 'Ekim Hizmeti', 'Hasat Hizmeti',
    'Budama', 'Aşılama', 'Ot Biçme', 'Çapalama', 'Meyve Toplama'
  ],
  'Tarımsal Sulama': [
    'Tarımsal Sulama Sistemi Kurulumu', 'Tarımsal Sulama Sistemi Bakımı',
    'Damla Sulama Sistemi', 'Yağmurlama Sulama Sistemi'
  ],
  'Bitki Koruma ve İlaçlama': [
    'Tarım İlaçlama', 'Bitki Hastalıkları ve Zararlılarıyla Mücadele',
    'Zirai İlaçlama', 'Sera İlaçlama'
  ],
  'Hayvancılık Hizmetleri': [
    'Büyükbaş Hayvancılık Danışmanlığı',
    'Küçükbaş Hayvancılık Danışmanlığı'
  ],
  'Veteriner Hizmetleri': [
    'Veteriner Hekim', 'Evde Veteriner Hizmeti', 'Hayvan Aşılama',
    'Hayvan Sağlığı Danışmanlığı'
  ],
  'Tur Organizasyon': [
    'Tur Organizasyonu', 'Günübirlik Tur', 'Kültür Turu', 'Doğa Turu',
    'Tekne Turu', 'Özel Tur Organizasyonu', 'Balık Turu'
  ],
  'Konaklama': [
    'Otel Rezervasyonu', 'Pansiyon Rezervasyonu', 'Villa Kiralama',
    'Günlük Ev Kiralama', 'Bungalov Kiralama', 'Apart Konaklama'
  ],
  'Transfer ve Ulaşım': [
    'Havalimanı Transferi', 'VIP Transfer', 'Şoförlü Araç Hizmeti',
    'Turizm Transferi', 'Özel Araç Tahsisi'
  ],
  'Seyahat Danışmanlığı': [
    'Seyahat Planlama', 'Tatil Planlama', 'Yurtiçi Tatil Organizasyonu',
    'Yurtdışı Tatil Organizasyonu'
  ],
  'Rehberlik': [
    'Profesyonel Turist Rehberi', 'Özel Tur Rehberi', 'Şehir Turu Rehberi',
    'Müze ve Kültür Turu Rehberi'
  ],
  'Vize & Seyahat İşlemleri': [
    'Vize Danışmanı', 'Vize Başvurusu', 'Vize Evrak Hazırlama',
    'Vize Randevu İşlemleri'
  ],
  'Emlak Danışmanlığı': [
    'Konut Alım Satım Danışmanlığı', 'Konut Kiralama Danışmanlığı',
    'İşyeri Alım Satım Danışmanlığı', 'İşyeri Kiralama Danışmanlığı',
    'Arsa Alım Satım Danışmanlığı', 'Gayrimenkul Danışmanlığı',
    'Emlak Değerleme Danışmanlığı'
  ],
  'Site ve Apartman Yönetimi': [
    'Site Yönetimi', 'Apartman Yönetimi', 'Profesyonel Apartman Yönetimi',
    'Profesyonel Site Yönetimi', 'Aidat Yönetimi',
    'Site Yönetim Danışmanlığı'
  ],
  'Gayrimenkul Hizmetleri': [
    'Emlak Drone Çekimi', 'Gayrimenkul Kiralama Yönetimi',
    'Kiralık Ev Yönetimi', 'Gayrimenkul İlan Yönetimi',
    'Gayrimenkul Fotoğraf Çekimi', 'Gayrimenkul Video Çekimi'
  ],
  'Özel Güvenlik': [
    'Özel Güvenlik Hizmeti', 'Site Özel Güvenlik', 'İşyeri Özel Güvenlik',
    'Etkinlik Özel Güvenlik', 'Organizasyon Güvenliği'
  ],
  'Yakın Koruma': [
    'Yakın Koruma', 'Kişisel Koruma', 'Etkinlik Yakın Koruma'
  ],
  'Güvenlik Personeli': [
    'Güvenlik Görevlisi', 'Gece Güvenliği', 'Gündüz Güvenliği',
    'Özel Etkinlik Güvenliği'
  ],
  'Kartvizit & Kurumsal Baskı': [
    'Kartvizit Baskı', 'Antetli Kağıt Baskı', 'Zarf Baskı', 'Fatura Baskı',
    'İrsaliye Baskı', 'Kaşe Yapımı'
  ],
  'Broşür & Tanıtım Baskıları': [
    'Broşür Baskı', 'El İlanı Baskı', 'Flyer Baskı', 'Katalog Baskı',
    'Afiş Baskı', 'Poster Baskı'
  ],
  'Davetiye & Özel Gün Baskıları': [
    'Davetiye Baskı', 'Düğün Davetiyesi Baskı', 'Nişan Davetiyesi Baskı',
    'Doğum Günü Davetiyesi Baskı'
  ],
  'Etiket & Ambalaj Baskıları': [
    'Etiket Baskı', 'Sticker Baskı', 'Ürün Etiketi Baskı', 'Ambalaj Baskı',
    'Kutu Baskı', 'Poşet Baskı'
  ],
  'Promosyon Baskıları': [
    'Magnet Baskı', 'Takvim Baskı', 'Bloknot Baskı', 'Ajanda Baskı',
    'Promosyon Ürün Baskısı'
  ],
  'Kitap & Yayın Baskıları': [
    'Kitap Baskı', 'Dergi Baskı', 'Tez Baskı', 'Ciltleme'
  ],
  '3D Baskı & Üretim': [
    '3D Baskı', '3D PLA Baskı', '3D ABS Baskı', '3D PETG Baskı',
    '3D Prototip Baskı', 'Kişiye Özel 3D Baskı', '3D Modelden Baskı',
    '3D Yedek Parça Baskı'
  ],
  'Tabela & Reklam Uygulamaları': [
    'Tabela', 'Işıklı Tabela', 'Kutu Harf Tabela', 'Kompozit Tabela',
    'Branda Tabela', 'Tabela Montajı'
  ],
  'Geri Dönüşüm Hizmetleri': [
    'Tekstil Geri Dönüşüm', 'Plastik Geri Dönüşüm',
    'Kağıt ve Karton Geri Dönüşüm', 'Metal Geri Dönüşüm',
    'Elektronik Atık Geri Dönüşüm', 'Ahşap Geri Dönüşüm',
    'Tekstil Atık Toplama', 'Plastik Atık Toplama',
    'Atık Ayrıştırma ve Sınıflandırma', 'Cam Geri Dönüşüm'
  ],
  'Bebek Bakımı': [
    'Bebek Bakıcısı', 'Saatlik Bebek Bakımı', 'Gündüzlü Bebek Bakıcısı',
    'Yatılı Bebek Bakıcısı', 'Yenidoğan Bebek Bakımı', 'İkiz Bebek Bakımı'
  ],
  'Çocuk Bakımı': [
    'Çocuk Bakıcısı', 'Saatlik Çocuk Bakımı', 'Gündüzlü Çocuk Bakıcısı',
    'Yatılı Çocuk Bakıcısı', 'Çocuk Bakımı ve Ev Yardımcısı',
    'Okul Sonrası Çocuk Bakımı'
  ],
  'Oyun & Gelişim Desteği': [
    'Oyun Ablası / Oyun Abisi', 'Çocuk Etkinlik ve Oyun Desteği',
    'Ebeveynli Oyun Grubu'
  ],
  'Çocuk Refakat ve Destek': [
    'Okul Gidiş-Geliş Refakati', 'Çocuk Etkinlik Refakati',
    'Çocuk Gezi Refakati', 'Gölge Öğretmen'
  ],
  'Çiçekçilik': [
    'Çiçekçi', 'Buket Hazırlama', 'Çiçek Aranjmanı', 'Çelenk Hazırlama',
    'Özel Gün Çiçekleri', 'Açılış Çiçekleri', 'Düğün Çiçekleri',
    'Çiçek Gönderme'
  ],
  'Asistanlık & Günlük Destek': [
    'Günlük Asistan', 'Kişisel Asistan', 'Özel Asistan', 'Sanal Asistan',
    'Yönetici Asistanı', 'Randevu ve Takvim Yönetimi',
    'Evrak ve Dosya Takibi', 'Günlük İş Takibi', 'Veri Girişi'
  ],
  'Dedektiflik & Araştırma': [
    'Özel Dedektif', 'Kişi Araştırması', 'Adres Tespiti',
    'Kayıp Kişi Araştırması', 'Ticari Araştırma', 'Saha Araştırması',
    'Delil Toplama'
  ],
  'Araştırma & Saha Hizmetleri': [
    'Pazar Araştırması', 'Piyasa Araştırması', 'Gizli Müşteri', 'Anket',
    'Anketör Hizmeti', 'Müşteri Memnuniyeti Araştırması',
    'Müşteri Deneyimi Araştırması', 'Rakip Araştırması',
    'Ürün Araştırması'
  ],
  'Günlük Eleman & Personel Desteği': [
    'Günlük Eleman', 'Günlük Yardımcı Eleman', 'Geçici Personel',
    'Kısa Süreli Personel', 'İş Gücü Desteği', 'Depo Yardımcı Personeli',
    'Yükleme / Boşaltma Personeli', 'Genel Yardımcı Personel'
  ],
};

/// ── ⚠ KATALOG KAYNAĞI — TEK GEÇİT ──
///
/// Katalogun otoritesi BACKEND'dir (`GET /categories`). Bu sınıf,
/// sunucudan gelen katalogu tutar ve uygulamanın tamamı buradan
/// okur.
///
/// ⚠ NEDEN SINGLETON: katalog on iki dosyadan ve tüm ekranlardan
/// okunuyor. Her birine ayrı ayrı controller geçirmek yerine tek
class KatalogKaynagi {
  KatalogKaynagi._();
  static final KatalogKaynagi i = KatalogKaynagi._();

  Map<String, List<String>>? _sunucu;

  /// Sunucudan katalog alındı mı?
  bool get sunucudanGeldi => _sunucu != null;

  /// AKTİF katalog: sunucu verisi varsa o, yoksa gömülü liste.
  ///
  /// ⚠ YEREL LİSTE SUNUCUNUN ÜZERİNE YAZAMAZ. Sıra tek yönlüdür:
  /// sunucu geldiğinde onun verisi esas alınır ve bir daha gömülü
  /// listeye DÜŞÜLMEZ.
  Map<String, List<String>> get aktif => _sunucu ?? kGomuluKatalog;

  /// Sunucudan gelen katalogu yerleştirir.
  ///
  /// ⚠ BOŞ KATALOG KABUL EDİLMEZ. Sunucu geçici bir hata yüzünden
  /// boş liste dönerse uygulama kategorisiz kalırdı; böyle bir yanıt
  /// yok sayılır ve önceki katalog korunur.
  ///
  /// ⚠ PASİF KAYITLAR ÇAĞIRAN TARAFTA SÜZÜLÜR (bkz. `CategoryApi`):
  /// buraya yalnız SEÇİLEBİLİR kategoriler gelir.
  void guncelle(Map<String, List<String>> gelen) {
    if (gelen.isEmpty) {
      return;
    }
    _sunucu = {
      for (final e in gelen.entries)
        if (e.value.isNotEmpty) e.key: List.unmodifiable(e.value),
    };
  }

  /// ⚠ YALNIZ TESTLER İÇİN: sunucu verisini geri alır.
  void sifirla() => _sunucu = null;
}

/// ANA KATEGORİ → ALT HİZMETLER (aktif kaynak).
///
/// ⚠ Sabit DEĞİL, GETTER'dır: sunucudan katalog geldiğinde bu
/// getter'ı okuyan her yer kendiliğinden yeni veriyi görür.
Map<String, List<String>> get kCategoryTree => KatalogKaynagi.i.aktif;



/// Ana kategori adları (ağaç sırasıyla).
List<String> get kTreeCategories => kCategoryTree.keys.toList(growable: false);

// ═══════════════════════════════════════════════════════════════
// KATEGORİ KARTLARI — GÖRÜNÜRLÜK VE ETİKET
//
// ⚠ BURADAKİ HİÇBİR KURAL KATALOĞU DEĞİŞTİRMEZ.
//
// `kCategoryTree` anahtarları KATALOG KİMLİĞİDİR: arama, teklif,
// hizmet veren kategori seçimi, admin ve backend hep bu adı kullanır.
// Aşağıdakiler yalnız KART IZGARASINDA ne görüneceğini belirler.
// ═══════════════════════════════════════════════════════════════

/// KART IZGARASINDA GÖSTERİLMEYEN kategoriler.
///
/// ⚠ SİLİNMİŞ DEĞİLLERDİR. Katalogda dururlar; arama, hizmet veren
/// kategori seçimi ve mevcut ilanlar etkilenmez. Yalnız ilan verme
/// ızgarasında kart olarak ÇİZİLMEZLER.
///
/// GEREKÇE: her biri kendinden daha genel bir kategoriyle aynı aileden
/// gelir ve kullanıcıyı kartlar arasında tereddütte bırakıyordu:
///   · `Isıtma Sistemleri`       → `Kombi Servis` ile aynı aile
///   · `Banyo Tadilat ve Montaj` → `Tadilat ve Yenileme` kapsıyor
///   · `Mutfak Tadilat ve Dolap` → `Tadilat ve Yenileme` kapsıyor
///   · `Koltuk ve Döşeme Yıkama` → kart yerine ALT HİZMETLERİYLE
///     görünür: Koltuk Yıkama · Yatak Yıkama · Perde Yıkama ·
///     Stor Perde Temizliği
///
/// ⚠ Alt hizmetleri ARAMADAN bulunmaya devam eder ("koltuk yıkama"
/// veya "banyo tadilatı" yazan kullanıcı sonucu görür) ve hizmet
/// veren KATEGORİ SEÇİM panelinde de listelenir.
const Set<String> kKartDisiKategoriler = {
  'Isıtma Sistemleri',
  'Banyo Tadilat ve Montaj',
  'Mutfak Tadilat ve Dolap',
  'Koltuk ve Döşeme Yıkama',
};

/// Kart ızgarasında çizilecek kategoriler (katalog − kart dışı).
List<String> get kKartKategorileri =>
    kTreeCategories.where((c) => !kKartDisiKategoriler.contains(c)).toList();

/// ELLE VERİLMİŞ KISA ADLAR.
///
/// Katalog kimliği uzun ve tanımlayıcıdır; kartta okunması gereken ad
/// kısadır. Bu harita YALNIZ GÖRÜNEN metni değiştirir.
/// ── LİDER HİZMETLER ──
///
/// ⚠ ÜRÜN ADI KATEGORİ OLMAZ. Her ailede kullanıcının en doğal
/// arayacağı iş LİDERDİR ve arama sonucunda öne çıkar:
///
///   "ayakkabı" → Ayakkabı Tamiri     "perde" → Perde Dikimi
///   "çanta"    → Çanta Tamiri        "halı"  → Halı Tamiri
///   "deri"     → Deri Tamiri         "kilim" → Kilim Tamiri
///
/// ⚠ Bu küme YALNIZ SIRALAMAYI etkiler. Kataloğa ayrı bir seviye
/// eklemez, hiçbir sayaca girmez; liderin altındaki işler de
/// aranabilir ve ilan açarken seçilebilir.
const Set<String> kLiderHizmetler = {
  'Ayakkabı Tamiri', 'Çanta Tamiri', 'Deri Tamiri', 'Kemer Tamiri',
  'Cüzdan Tamiri', 'Yorgan Dikimi', 'Yatak Yenileme', 'Örgü Yapımı',
  'Triko Tamiri', 'Nakış', 'Tekstil İşleme', 'Halı Tamiri',
  'Kilim Tamiri', 'Kumaş Dokuma', 'Perde Dikimi', 'Fason Dikim',
  'Kalıp Hazırlama', 'Overlok Hizmeti', 'Reçme Hizmeti',
  'Tekstil Ütüleme', 'Tekstil Paketleme',
};

const Map<String, String> _kKisaAd = {
  'Mobilya Yapım ve Montaj': 'Mobilya',
  // ⚠ 'Cam ve Balkon Sistemleri' kısaltması KALKTI — kategorinin
  // gerçek adı artık 'Cam Balkon'.
  'İlaçlama ve Haşere Kontrolü': 'İlaçlama',
  // ⚠ 'Elektrik Tesisat ve Arıza' birleşik adı KALKTI. Kategori adı
  // 'Elektrik'; tesisat ve arıza AYRI HİZMET olarak zaten duruyor.
  // Kısaltma da gereksiz: kategori adı hizmet adıyla çakışmasın.
  'Klima Montaj ve Servis': 'Klima Servisi',
  'Duvar Kağıdı ve Dekorasyon': 'Duvar Kağıdı',
  // ⚠ "Yenileme" yerine "Dekorasyon": kart artık dekorasyon işlerinin
  // de adresi olarak okunuyor (Duvar Kağıdı kartı kısaldığı için
  'Tadilat ve Yenileme': 'Tadilat & Dekorasyon',
  'İnşaat ve Kaba Yapı': 'İnşaat',
  'Çilingir ve Kilit': 'Çilingir',
  'Kurye ve Küçük Taşıma': 'Kurye',
};

/// KATEGORİNİN EKRANDA GÖRÜNEN ADI.
///
/// İki kural:
///   1. Elle kısaltılmış adlar (`_kKisaAd`) doğrudan uygulanır.
///   2. Kalanlarda bağlaç kısaltılır: boşluklu `ve` yerine `&`.
///      Koltuk ve Döşeme Yıkama → Koltuk & Döşeme Yıkama
///
/// ⚠ KİMLİK DEĞİL ETİKET. Dönen değer `kCategoryTree` anahtarı
/// DEĞİLDİR; arama, seçim ve gönderim hep gerçek adı taşır.
///
/// ⚠ Kelime içindeki `ve` korunur: yalnız iki yanı BOŞLUKLU bağlaç
/// değiştirilir; `Yenileme` gibi adlar bozulmaz.
///
/// ⚠ YALNIZ ANA KATEGORİLERE UYGULANIR. Verilen ad katalogda bir ana
/// kategori değilse (alt hizmet ya da serbest metin) OLDUĞU GİBİ
/// döner: `Petek ve Kalorifer Tesisatı` gibi hizmet adları
/// kısaltılmaz. Böylece fonksiyon her yerde güvenle çağrılabilir.
String kategoriEtiketi(String kategori) {
  if (!kCategoryTree.containsKey(kategori)) {
    return kategori;
  }
  return _kKisaAd[kategori] ?? kategori.replaceAll(' ve ', ' & ');
}

/// Tüm alt hizmetler, ana kategorisiyle birlikte.
///
/// Arama önerilerinde `Ana > Alt` kırılımı için kullanılır.
List<({String category, String service})> get kTreeServices => [
      for (final e in kCategoryTree.entries)
        for (final s in e.value) (category: e.key, service: s),
    ];

/// KATEGORİ GÖRSELLERİ — referans HTML `PC_PHOTO` / `PC_IC`
///
/// Fotoğrafı olan kategoriler `assets/categories/*.jpg|png`,
/// olmayanlar `assets/svg/cat/*.svg` çizgi ikonu kullanır
/// (HTML'deki `pcPhoto()` davranışı).
const Map<String, String> kCategoryImage = {
  // ⚠ FOTOĞRAF İSTEĞE BAĞLIDIR — GÖRSEL KAYNAĞI SVG'DİR.
  //
  // Kategori kartının TEMEL görseli `kKategoriIkonu` SVG'sidir;
  // burası yalnız fotoğrafı ÜRETİLMİŞ kategoriler için zengin görsel
  // sağlar. Kayıt yoksa `categoryAsset` null döner ve kart SVG ile
  // çizilir — kart HİÇBİR ZAMAN boş kalmaz.
  //
  // ⚠ Anahtarlar YENİ kategori adlarıyla hizalıdır; eski adlarda
  // kalmış kayıt hiçbir kategoriyle eşleşmez ve görseli ölü olur.
  'Temizlik Hizmetleri':
      'assets/categories/temizlik.jpg',
  'Halı Yıkama':
      'assets/categories/hali_yikama.jpg',
  // ⚠ Eski dosya adı korundu: görsel zaten KOLTUK yıkamayı gösteriyor
  // ve bölünmeden sonra doğru kategoriye denk geliyor.
  'Koltuk ve Döşeme Yıkama':
      'assets/categories/hali_ve_koltuk_yikama.jpg',
  'İlaçlama ve Haşere Kontrolü':
      'assets/categories/ilaclama.jpg',
  'Su Tesisatı':
      'assets/categories/tesisat.jpg',
  'Doğalgaz':
      'assets/categories/dogalgaz.jpg',
  'Isıtma Sistemleri':
      'assets/categories/isitma_sistemleri_servisi.jpg',
  'Elektrik':
      'assets/categories/elektrik.jpg',
  'Güvenlik Sistemleri':
      'assets/categories/guvenlik_sistemleri.jpg',
  'Klima Montaj ve Servis':
      'assets/categories/klima_ve_havalandirma.jpg',
  'Beyaz Eşya Servisi':
      'assets/categories/beyaz_esya_tamiri.jpg',
  'Elektronik Cihaz Tamiri':
      'assets/categories/elektronik_tamiri.jpg',
  'Uydu ve Anten Sistemleri':
      'assets/categories/uydu_ve_goruntu_sistemleri.jpg',
  'İnternet ve Ağ Kurulumu':
      'assets/categories/internet_ve_ag.jpg',
  'Boya ve Badana':
      'assets/categories/boya.jpg',
  'Duvar Kağıdı ve Dekorasyon':
      'assets/categories/duvar_kagidi_ve_dekorasyon.jpg',
  'Tadilat ve Yenileme':
      'assets/categories/tadilat.jpg',
  'Mutfak Tadilat ve Dolap':
      'assets/categories/mutfak_ve_banyo.jpg',
  'İnşaat ve Kaba Yapı':
      'assets/categories/insaat.jpg',
  'Fayans ve Seramik Döşeme':
      'assets/categories/fayans_ve_seramik.jpg',
  'Zemin Kaplama':
      'assets/categories/zemin_kaplama.jpg',
  'Yalıtım ve Mantolama':
      'assets/categories/yalitim.jpg',
  'Çatı Yapım ve Onarım':
      'assets/categories/cati.jpg',
  'Mobilya Yapım ve Montaj':
      'assets/categories/mobilya.jpg',
  'Marangozluk ve Ahşap İşleri':
      'assets/categories/marangoz.jpg',
  'Cam Balkon Sistemleri':
      'assets/categories/cam_ve_balkon.jpg',
  'PVC ve Alüminyum Doğrama':
      'assets/categories/pvc_ve_dograma.jpg',
  'Demir Doğrama ve Kaynak':
      'assets/categories/demir_ve_kaynak.jpg',
  'Çilingir ve Kilit':
      'assets/categories/anahtar_ve_cilingir.jpg',
  'Bahçe ve Peyzaj':
      'assets/categories/bahce_ve_peyzaj.jpg',
  'Havuz Yapım ve Bakım':
      'assets/categories/havuz.jpg',
  'Nakliyat ve Taşımacılık':
      'assets/categories/nakliyat.jpg',
  'Kurye ve Küçük Taşıma':
      'assets/categories/kurye_ve_tasima.jpg',
  'Asansör Montaj ve Bakım':
      'assets/categories/asansor.jpg',
  // ⚠ `Mühendislik ve Proje` GERİ EKLENDİ.
  //
  // Eski `muhendislik.png` bozuktu (yalnız gri degrade) ve haritadan
  // çıkarılmıştı. Yerine gerçek fotoğraf üretildi: `muhendislik.jpg`
  // (teknik çizim üzerinde kalem tutan eller).
  // ⚠ İKİ KOMBİ KATEGORİSİ AYNI FOTOĞRAFI KULLANIR.
  //
  // Ayrı çizim/fotoğraf üretilmedi: ikisi de aynı cihazın işi.
  // Halı/Koltuk Yıkama ayrımında da aynı istisna uygulanmıştı.
  'Kombi Montaj':
      'assets/categories/kombi.jpg',
  'Kombi Servis':
      'assets/categories/kombi.jpg',
  'Alçı ve Sıva İşleri':
      'assets/categories/alci.jpg',
  'Kapı Montaj ve Tamir':
      'assets/categories/kapi.jpg',
  'Oto Çekici ve Yol Yardım':
      'assets/categories/oto_yardim.jpg',
  'Banyo Tadilat ve Montaj':
      'assets/categories/banyo.jpg',
  'Oto Servis ve Bakım':
      'assets/categories/oto_servis.jpg',
  'Araç Temizlik ve Detaylı Bakım':
      'assets/categories/oto_temizlik.jpg',
  'Mühendislik ve Proje':
      'assets/categories/muhendislik.jpg',
  'Özel Ders':
      'assets/categories/ozel_ders.jpg',
  'Yabancı Dil Eğitimi':
      'assets/categories/yabanci_dil.jpg',
  // ⚠ SON 10 KATEGORİ — harita bu turda 43 → 53 oldu.
  //
  // Artık 53 kategorinin TAMAMINDA fotoğraf vardır; SVG katmanı
  // KALDIRILMADI, yalnız yedeğe düştü (dosya bozulursa errorBuilder
  // hâlâ `categoryIcon` ile çizer).
  'Sürücü Eğitimi':
      'assets/categories/surucu.jpg',
  'Spor ve Kişisel Antrenör':
      'assets/categories/spor.jpg',
  'Müzik Dersleri':
      'assets/categories/muzik.jpg',
  'Yazılım ve Web Hizmetleri':
      'assets/categories/yazilim.jpg',
  'Grafik ve Logo Tasarım':
      'assets/categories/tasarim.jpg',
  'Dijital Pazarlama':
      'assets/categories/pazarlama.jpg',
  'Fotoğraf Çekimi':
      'assets/categories/fotograf.jpg',
  'Etkinlik ve Organizasyon':
      'assets/categories/organizasyon.jpg',
  'Evcil Hayvan Hizmetleri':
      'assets/categories/evcil_hayvan.jpg',
  'Güzellik ve Bakım Hizmetleri':
      'assets/categories/guzellik.jpg',

  // ⚠ GEÇİCİ GÖRSEL — GERÇEK FOTOĞRAFLA DEĞİŞTİRİLECEK.
  //
  // Bu üç kategori 14 Ağu'da açıldı; elimizde konuya ait fotoğraf
  // YOKTU. Diğer kategoriler gerçek fotoğraf kullanıyor, bunlar
  // desenli yer tutucu. Fotoğraflar gelince YALNIZ dosyalar
  'Ayakkabı ve Deri İşleri':
      'assets/categories/ayakkabi_deri.jpg',
  'Terzilik ve Dikiş':
      'assets/categories/terzilik.jpg',
  'Ev Tekstili':
      'assets/categories/ev_tekstili.jpg',

  // ── PROFESYONEL / OFİS HİZMETLERİ (16 Ağu) ──
  //
  // ⚠ BU BEŞ GÖRSEL SOYUT DESENDİR, FOTOĞRAF DEĞİL.
  //
  // "Avukatlık" ya da "Sigorta" için anlamlı bir fotoğraf bu ortamda
  // üretilemez; üretilse yapay dururdu. Onun yerine kategori rengiyle
  // uyumlu geometrik desen üretildi. Teknik ölçüt sağlanıyor
  // (240×240, <12 KB, düz renk değil) ama GÖRSEL KALİTE geçicidir —
  'Avukatlık ve Hukuk': 'assets/categories/hukuk.jpg',
  'Muhasebe ve Mali Müşavirlik': 'assets/categories/muhasebe.jpg',
  'İş Güvenliği ve İSG': 'assets/categories/is_guvenligi.jpg',
  'Marka ve Patent': 'assets/categories/marka_patent.jpg',
  'Sigorta': 'assets/categories/sigorta.jpg',
};



/// Kategori görseli SVG mi?
bool kCategoryImageIsSvg(String kategori) =>
    (kCategoryImage[kategori] ?? '').endsWith('.svg');

// ═══════════════════════════════════════════════════════════════
// HİZMET VEREN KATEGORİ KURALLARI
// ═══════════════════════════════════════════════════════════════

/// Verilen adın ait olduğu ANA KATEGORİ.
///
/// Ad zaten bir ana kategoriyse kendisi döner. Alt hizmetse bağlı
/// olduğu ana kategori döner. Ağaçta yoksa `null`.
String? anaKategoriBul(String ad) {
  for (final e in kCategoryTree.entries) {
    if (e.key == ad) {
      return e.key;
    }
    if (e.value.contains(ad)) {
      return e.key;
    }
  }
  return null;
}

/// Seçim kümesindeki BENZERSİZ ana kategoriler.
///
/// Hem ana kategori hem alt hizmet aynı kümede tutulduğu için sayım
/// bu yardımcıyla yapılır; `secim.length` ana kategori sayısı DEĞİLDİR.
Set<String> anaKategorileri(Iterable<String> secim) {
  final out = <String>{};
  for (final s in secim) {
    final ana = anaKategoriBul(s);
    if (ana != null) {
      out.add(ana);
    }
  }
  return out;
}

/// [ad] seçime EKLENEBİLİR mi?
///
/// ⚠ ARTIK HER ZAMAN `true`. Ana kategori sayı sınırı kaldırıldı
/// (bkz. yukarıdaki not). İşlev KORUNDU çünkü üç ekran onu çağırıyor;
/// ileride başka bir kural (ör. onay bekleyen kategori) gerekirse
/// eklenecek yer burasıdır.
bool anaKategoriEklenebilir(Iterable<String> mevcut, String ad) => true;
