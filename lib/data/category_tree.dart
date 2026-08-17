/// HİZMET KATALOĞU — 63 ANA KATEGORİ · 640 ALT HİZMET
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
/// ⚠ ANA SAYFADAKİ HIZLI ERİŞİM SATIRI KALDIRILDI (15 Ağu). Yerine
/// ÇATI katmanı geldi (`hizmet_alanlari.dart`): Ana Sayfa → Çatı →
/// Kategori → Hizmet. Çatı bir KATEGORİ DEĞİLDİR, yalnız kısayol
/// yüzeyidir ve hiçbir sayaca girmez. Kullanıcı 63 kategorinin
/// tamamına Tüm Kategoriler ekranından ve aramadan ulaşır.
///
/// ## ⚠ İŞ KURALI — YENİ ALT HİZMET EKLENDİĞİNDE
///
/// Bu ağaca yeni bir alt hizmet girdiğinde `arama_es_anlamlilari.dart`
/// dosyasına da o hizmetin ARAMA TERİMLERİ eklenmelidir.
///
/// Sebep: kullanıcı hizmet adını değil DERDİNİ yazar — "gaz kaçağı",
/// "kapıda kaldım", "kombi yanmıyor". Terim eklenmezse hizmet yalnız
/// tam adıyla aranabilir ve pratikte görünmez kalır.
///
/// Terim seçimi ve örnekler için `kAramaEsAnlamlilari` belgesine
/// bakınız.
library;

/// Ana kategori → alt hizmetler.
const Map<String, List<String>> kCategoryTree = {
  'Temizlik Hizmetleri': [
    'Ev Temizliği', 'Boş Ev Temizliği', 'Ofis Temizliği',
    'İnşaat Sonrası Temizlik', 'Derin Temizlik', 'Taşınma Temizliği',
    'Cam Temizliği', 'Cam Silme', 'Ütü Hizmeti', 'Merdiven Temizliği',
    'Buhar Makinesiyle Temizlik'
  ],
  // ⚠ "Halı ve Döşeme Yıkama" İKİYE BÖLÜNDÜ.
  //
  // Tek kategori iki ayrı işi barındırıyordu: halı yıkama (halı
  // fabrikaya/atölyeye gider) ile döşeme yıkama (usta eve gelir,
  // koltuk-yatak-perde yerinde temizlenir). Farklı ekipman, farklı
  // fiyat, çoğu zaman farklı usta.
  //
  // Alt hizmetler AYNEN korundu, yalnız iki başlığa dağıtıldı; yeni
  // alt hizmet UYDURULMADI.
  // ⚠ 'Halı Yıkama' HİZMETİ KALDIRILDI — kategori adı zaten bu.
  //
  // Aynı ad hem kategori hem hizmet olunca aramada iki satır
  // çıkıyordu. Genel halı yıkama isteği kategori satırından
  // karşılanır; buradaki kayıtlar işin TÜRLERİdir.
  'Halı Yıkama': [
    'Kilim Yıkama', 'Yolluk Yıkama',
    'Halı Leke Çıkarma', 'Yerinde Halı Yıkama'
  ],
  'Koltuk ve Döşeme Yıkama': [
    'Koltuk Yıkama', 'Yatak Yıkama', 'Perde Yıkama', 'Stor Perde Temizliği',
    'Sandalye Yıkama',
    'Halıfleks Yıkama',
    'Araç Döşeme Yıkama',
  ],
  'İlaçlama ve Haşere Kontrolü': [
    'Ev İlaçlama', 'Böcek İlaçlama', 'Haşere İlaçlama',
    'Kene İlaçlama', 'Fare Mücadelesi', 'Tahtakurusu İlaçlama',
    'Karınca İlaçlama', 'Güve İlaçlama',
    'Sinek ve Sivrisinek İlaçlama', 'Pire İlaçlama', 'İşyeri İlaçlama'
  ],
  'Su Tesisatı': [
    'Su Tesisatçısı', 'Sıhhi Tesisat', 'Su Kaçağı Tespiti',
    'Tıkanıklık Açma', 'Gider Açma', 'Musluk Montajı',
    'Klozet Montajı', 'Su Deposu Temizliği', 'Tesisat Tamiri',
    'Su Arıtma Servisi',
    'Petek Borusu Tesisatı', 'Duş Bataryası Montajı',
    'Hidrofor Montajı', 'Pissu Tesisatı'
  ],
  // ⚠ DOĞALGAZ GENİŞLETİLDİ (14 Ağu, ürün kararı) — 4 → 8 hizmet.
  //
  // Kategori adı 'Doğalgaz Tesisatı ve Proje' idi; iki işi tek
  // başlıkta birleştiriyordu ve kullanıcı kararıyla kaldırıldı.
  // Yeni ad tek sözcük: 'Doğalgaz'.
  //
  // ⚠ KATEGORİ ADI ZATEN KULLANICIYA GÖSTERİLMİYOR (öneri
  // listesinde kırılım çizilmez); ad yalnız kart ızgarasında ve
  // sistem içinde kullanılır.
  //
  // Eklenen dört hizmet, sahada AYRI olarak istenen işlerdir:
  //   · İç Tesisat   — daire/bina içi, kolon hattından ayrı
  //   · Kolon Hattı  — bina ana hattı, yönetim işi
  //   · Kaçak Tespiti / Kaçak Onarımı — kullanıcı kararıyla ayrıldı
  //
  // ⚠ NOT: tespit ile onarımı sahada çoğunlukla aynı usta aynı
  // ziyarette yapar; üçe bölmek teklif havuzunu böler. Risk
  // bildirildi, karar ürün tarafının.
  'Doğalgaz': [
    'Doğalgaz Tesisatı',
    'Doğalgaz Projesi',
    'Doğalgaz İç Tesisatı',
    'Doğalgaz Kolon Hattı',
    'Doğalgaz Kaçak Kontrolü',
    'Doğalgaz Kaçak Tespiti',
    'Doğalgaz Kaçak Onarımı',
    'Doğalgaz Boru Hattı Tadilatı',
    'Doğalgaz Ocak Bağlantısı',
    'Doğalgaz Ocak Dönüşümü',
    'Doğalgaz Sobası Montajı',
    ],
  // ⚠ KOMBİ İKİYE AYRILDI (14 Ağu, ürün kararı).
  //
  // Eskiden tek kategori vardı: `Kombi Servisi`. Adı "servis" diyordu
  // ama içinde MONTAJ işleri de duruyordu. Kullanıcı kararı: kurulum
  // ile bakım/onarım AYRI işlerdir, ayrı kategori olmalıdır.
  //
  // ⚠ ALT HİZMET SAYISI DEĞİŞMEDİ (dördü de duruyor); yalnız iki
  // kategoriye dağıtıldı. Kategori 54 → 55.
  //
  // ⚠ Ad "Kombi" DEĞİL: tek başına "Kombi" hangi işi anlattığını
  // söylemiyordu.
  'Kombi Montaj': [
    'Kombi Montajı', 'Kombi Değişimi', 'Kombi Yeri Değişimi',
    'Kombi Baca Montajı'
  ],
  'Kombi Servis': [
    'Kombi Tamiri', 'Kombi Bakımı', 'Kombi Arıza Tespiti'
  ],
  'Isıtma Sistemleri': [
    'Petek Temizliği', 'Petek Montajı', 'Yerden Isıtma',
    'Şofben Tamiri', 'Termosifon Tamiri', 'Radyatör Vana Değişimi',
    'Kalorifer Kazanı Bakımı', 'Oda Termostatı Montajı',
    'Boyler Montajı'
  ],
  'Elektrik': [
    'Elektrikçi', 'Elektrik Arıza', 'Elektrik Tesisatı',
    'Priz Montajı', 'Anahtar Montajı', 'Avize Montajı',
    'Sigorta Panosu Montajı', 'Elektrik Panosu Yenileme',
    'Aydınlatma Sistemleri', 'Kaçak Akım Rölesi Montajı',
    'Spot Aydınlatma Montajı', 'Elektrik Kablo Çekimi',
    'Jeneratör Montajı', 'Elektrikli Panjur Montajı'
  ],
  'Güvenlik Sistemleri': [
    'Kamera Sistemi Kurulumu', 'Alarm Sistemi Kurulumu',
    'Görüntülü Diafon Montajı', 'Akıllı Kilit', 'Yangın Algılama',
    'Kamera Bakım ve Onarımı', 'Parmak İzli Geçiş Sistemi',
    'Bariyer ve Otopark Sistemi'
  ],
  'Klima Montaj ve Servis': [
    'Klima Montajı', 'Klima Bakımı', 'Klima Tamiri', 'Klima Temizliği',
    'Havalandırma Sistemleri', 'VRF Sistemleri', 'Klima Gaz Dolumu',
    'Klima Sökme Takma', 'Kanallı Klima Montajı',
    'Salon Tipi Klima Montajı'
  ],
  'Beyaz Eşya Servisi': [
    'Buzdolabı Tamiri', 'Çamaşır Makinesi Tamiri',
    'Bulaşık Makinesi Tamiri', 'Kurutma Makinesi Tamiri',
    'Fırın Tamiri', 'Aspiratör Tamiri', 'Ankastre Cihaz Montajı',
    'Davlumbaz Tamiri', 'Su Sebili Tamiri', 'Beyaz Eşya Nakli'
  ],
  'Elektronik Cihaz Tamiri': [
    'Televizyon Tamiri', 'Bilgisayar Tamiri', 'Telefon Tamiri',
    'Tablet Tamiri', 'Oyun Konsolu Tamiri', 'Telefon Ekran Değişimi',
    'Telefon Batarya Değişimi', 'Bilgisayar Format ve Kurulum',
    'Veri Kurtarma', 'Projeksiyon Tamiri',
    // ⚠ SAAT TAMİRİ — ÇATISI TAMİR (15 Ağu, kesin karar).
    //
    // Çatı katmanı KATEGORİ eşler, hizmet değil. Bu yüzden bir
    // hizmetin çatısı, bağlı olduğu kategorinin çatısıdır:
    // Elektronik Cihaz Tamiri → Tamir. Saat tamiri buraya
    // konularak Tamir çatısına girer; yeni kategori AÇILMADI.
    'Saat Tamiri'
  ],
  'Uydu ve Anten Sistemleri': [
    'Uydu Anteni Kurulumu', 'Çanak Anten Ayarı',
    'Merkezi Uydu Sistemi', 'Televizyon Duvar Montajı',
    'Uydu Alıcı Kurulumu', 'Karasal Anten Montajı',
    'Anten Kablo Çekimi'
  ],
  'İnternet ve Ağ Kurulumu': [
    'Modem Kurulumu', 'Ağ Kablolama', 'Wifi Güçlendirme',
    'Akıllı Ev Sistemleri', 'Fiber İnternet Kurulumu',
    'Kamera Ağ Kurulumu', 'Sunucu ve NAS Kurulumu'
  ],
  'Boya ve Badana': [
    'Boya Badana', 'İç Cephe Boya', 'Dış Cephe Boyama',
    'Dekoratif Boya', 'Kapı Boyama', 'Tavan Boyama',
    'Silinebilir Boya Uygulaması', 'Mobilya Boyama',
    'Cephe Boya Onarımı'
  ],
  'Alçı ve Sıva İşleri': [
    'Alçıpan', 'Alçı Sıva', 'Kartonpiyer', 'Asma Tavan Yapımı',
    'Saten Alçı Uygulaması', 'Sıva Tamiri'
  ],
  'Duvar Kağıdı ve Dekorasyon': [
    'Duvar Kağıdı Uygulama', 'Duvar Paneli', '3D Duvar Kaplama',
    'Poster Duvar Kağıdı', 'Duvar Kağıdı Sökme', 'Akustik Panel Montajı'
  ],
  'Tadilat ve Yenileme': [
    'Ev Tadilatı', 'Daire Tadilatı', 'Ofis Tadilatı',
    'Dükkan Tadilatı', 'Anahtar Teslim Tadilat',
    'Kiralık Daire Tadilatı', 'Villa Tadilatı', 'Bina Yenileme'
  ],
  'Banyo Tadilat ve Montaj': [
    'Banyo Tadilatı', 'Duşakabin Montajı', 'Banyo Dolabı Montajı',
    'Lavabo Montajı', 'Duş Teknesi Montajı', 'Küvet Montajı',
    'Klozet Değişimi', 'Banyo Fayans Yenileme'
  ],
  'Mutfak Tadilat ve Dolap': [
    'Mutfak Tadilatı', 'Mutfak Dolabı Yapımı', 'Mutfak Dolabı Tamiri',
    'Mutfak Tezgahı Montajı', 'Hazır Mutfak', 'Mutfak Dolabı Montajı',
    'Mutfak Dolabı Kapak Değişimi', 'Granit Tezgah Montajı',
    'Evye Montajı'
  ],
  'İnşaat ve Kaba Yapı': [
    'Kaba İnşaat', 'Anahtar Teslim İnşaat', 'Duvar Örme',
    'Yıkım İşleri', 'Moloz Taşıma', 'Şap Atma', 'Kolon Güçlendirme'
  ],
  'Fayans ve Seramik Döşeme': [
    'Fayans Döşeme', 'Seramik Döşeme', 'Fayans Tamiri',
    'Mermer Döşeme', 'Granit Uygulama', 'Derz Yenileme', 'Silikon Uygulaması', 'Mermer Eşik Montajı',
    'Dış Cephe Seramik'
  ],
  'Zemin Kaplama': [
    'Parke Döşeme', 'Parke Tamiri',
    'Halıfleks Uygulama', 'PVC Zemin', 'Epoksi Zemin Kaplama',
    'Parke Zımpara ve Cila', 'Süpürgelik Montajı',
    'Vinil Zemin Uygulaması', 'Zemin Şap Düzeltme'
  ],
  'Yalıtım ve Mantolama': [
    'Su Yalıtımı', 'Isı Yalıtımı', 'Mantolama', 'Ses Yalıtımı',
    'Teras İzolasyonu', 'Balkon Su Yalıtımı', 'Çatı Su Yalıtımı',
    'Rutubet ve Küf Onarımı', 'Pencere Ses Yalıtımı'
  ],
  'Çatı Yapım ve Onarım': [
    'Çatı Tamiri', 'Çatı Yapımı', 'Çatı İzolasyonu', 'Çatı Aktarma',
    'Oluk Montajı', 'Kiremit Değişimi', 'Kiremit Aktarma',
    'Oluk Temizliği', 'Çatı Kaçak Onarımı', 'Çelik Çatı İmalatı'
  ],
  'Mobilya Yapım ve Montaj': [
    'Mobilya Montajı', 'Mobilya Tamiri', 'Mobilya İmalatı',
    'Gardırop Yapımı', 'Gardırop Montajı', 'TV Ünitesi Yapımı',
    'TV Ünitesi Montajı', 'Vestiyer Yapımı', 'Hazır Mobilya Kurulumu',
    'Yatak Odası Takımı Montajı', 'Raf ve Kitaplık Montajı',
    'Mobilya Sökme ve Taşıma'
  ],
  'Marangozluk ve Ahşap İşleri': [
    'Özel Mobilya Yapımı', 'Ahşap Raf Yapımı', 'Ahşap Masa Yapımı',
    'Ahşap Merdiven', 'Ahşap Pergola', 'Masa ve Sandalye Tamiri',
    'Vernik ve Cila', 'Ahşap Deck Uygulaması', 'Ahşap Kapı Onarımı',
    'Ölçüye Özel Dolap'
  ],
  'Kapı Montaj ve Tamir': [
    'İç Kapı Montajı', 'İç Kapı İmalatı', 'Çelik Kapı Montajı',
    'Çelik Kapı Tamiri', 'Kapı Tamiri', 'Kapı Kolu Değişimi',
    'Kapı Menteşe Ayarı', 'Sürgülü Kapı Montajı',
    'Kapı Otomatiği Montajı'
  ],
  'Cam Balkon Sistemleri': [
    'Cam Balkon', 'Cam Değişimi', 'Ayna Montajı',
    'Duş Camı Montajı', 'Isıcam Değişimi', 'Kırık Cam Değişimi',
    'Giyotin Cam Montajı'
  ],
  'PVC ve Alüminyum Doğrama': [
    'PVC Pencere Montajı', 'PVC Pencere Tamiri', 'PVC Kapı',
    'Alüminyum Doğrama', 'Sineklik Montajı', 'Panjur Sistemleri',
    'Pencere Ayarı ve Fitil Değişimi', 'Pileli Sineklik Montajı',
    'Otomatik Panjur Montajı', 'Alüminyum Cephe Kaplama'
  ],
  'Demir Doğrama ve Kaynak': [
    'Demir Doğrama İşleri', 'Ferforje', 'Kaynakçı', 'Korkuluk Montajı',
    'Çelik Konstrüksiyon', 'Balkon Korkuluğu Montajı',
    'Merdiven Korkuluğu', 'Demir Kapı İmalatı', 'Yerinde Kaynak İşi'
  ],
  'Çilingir ve Kilit': [
    'Kapı Açma', 'Kilit Değişimi', 'Barel Değişimi', 'Oto Anahtarcı',
    'Çelik Kapı Kilidi Değişimi', 'Kasa Açma', 'Anahtar Kopyalama'
  ],
  'Bahçe ve Peyzaj': [
    'Bahçe Düzenleme', 'Çim Ekimi', 'Çim Serme', 'Ağaç Budama',
    'Otomatik Sulama Sistemi', 'Bahçe Bakımı', 'Çim Biçme',
    'Ağaç Kesimi', 'Otomatik Sulama Montajı', 'Bahçe Duvarı ve Çit',
    'Sera Kurulumu'
  ],
  'Havuz Yapım ve Bakım': [
    'Havuz Yapımı', 'Havuz Bakımı', 'Havuz Kimyasal Dengeleme',
    'Havuz Tamiri', 'Havuz Su Kaçağı Onarımı', 'Havuz Kışa Hazırlık'
  ],
  'Nakliyat ve Taşımacılık': [
    'Evden Eve Nakliyat', 'Şehirler Arası Nakliyat', 'Ofis Taşıma',
    'Parça Eşya Taşıma', 'Asansörlü Nakliyat', 'Eşya Depolama',
    'Piyano Taşıma', 'Asansörlü Taşıma', 'Sigortalı Nakliyat'
  ],
  'Kurye ve Küçük Taşıma': [
    'Moto Kurye', 'Paket Taşıma', 'Küçük Nakliye', 'Aynı Gün Kurye'
  ],
  'Asansör Montaj ve Bakım': [
    'Asansör Bakımı', 'Asansör Tamiri', 'Asansör Montajı',
    'Asansör Kabin Yenileme', 'Asansör Kapı Tamiri'
  ],
  'Mühendislik ve Proje': [
    'Statik Proje', 'Mimari Proje', 'Elektrik Projesi',
    'Mekanik Tesisat Projesi', 'Zemin Etüdü', 'Enerji Kimlik Belgesi',
    'Güçlendirme Projesi', 'Deprem Performans Analizi',
    'Ruhsat Projesi', 'Röleve Projesi'
  ],
  'Oto Çekici ve Yol Yardım': [
    'Oto Çekici', 'Yol Yardım', 'Akü Takviye',
    'Kilitli Araç Açma'
  ],
  'Oto Servis ve Bakım': [
    'Oto Elektrik', 'Oto Klima', 'Fren Balata Değişimi',
    'Periyodik Araç Bakımı', 'Motor Yağı Değişimi', 'Akü Değişimi',
    'Araç Klima Gaz Dolumu', 'Fren Bakımı'
  ],
  'Araç Temizlik ve Detaylı Bakım': [
    'Araç Detaylı Temizlik', 'Araç Koltuk Yıkama', 'Oto Yıkama',
    'Pasta ve Cila', 'Motor Yıkama', 'Yerinde Oto Yıkama'
  ],
  'Özel Ders': [
    'Matematik Özel Ders', 'Fizik Özel Ders',
    'Fen Bilimleri Özel Ders', 'İlkokul Özel Ders', 'Kimya Özel Ders',
    'Biyoloji Özel Ders', 'Türkçe ve Edebiyat Özel Ders',
    'Geometri Özel Ders', 'LGS Hazırlık', 'YKS Hazırlık'
  ],
  'Yabancı Dil Eğitimi': [
    'İngilizce Özel Ders', 'Almanca Özel Ders', 'Fransızca Özel Ders',
    'Online İngilizce Dersi', 'İspanyolca Özel Ders',
    'Rusça Özel Ders', 'IELTS ve TOEFL Hazırlık', 'İş İngilizcesi'
  ],
  'Sürücü Eğitimi': [
    'Direksiyon Dersi', 'İleri Sürüş Eğitimi',
    'Park Etme Eğitimi'
  ],
  'Spor ve Kişisel Antrenör': [
    'Yüzme Dersi', 'Fitness Özel Ders', 'Pilates Dersi', 'Tenis Dersi',
    'Evde Fitness Antrenörü', 'Yoga Dersi',
    'Beslenme ve Antrenman Programı'
  ],
  'Müzik Dersleri': [
    'Piyano Dersi', 'Gitar Dersi', 'Keman Dersi', 'Şan Dersi',
    'Bağlama Dersi', 'Davul ve Perküsyon Dersi', 'Ud ve Kanun Dersi',
    'Flüt Dersi'
  ],
  'Yazılım ve Web Hizmetleri': [
    'Web Sitesi Yapımı', 'Mobil Uygulama Geliştirme',
    'E-Ticaret Sitesi Yapımı', 'WordPress Site Kurulumu',
    'Web Sitesi Bakımı', 'SEO Uyumlu Site Kurulumu',
    'Yazılım Danışmanlığı', 'Veri Tabanı Kurulumu'
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
  'Fotoğraf Çekimi': [
    'Ürün Fotoğraf Çekimi', 'Kurumsal Fotoğraf Çekimi',
    'Düğün ve Nişan Fotoğrafçısı', 'Bebek ve Aile Çekimi',
    'Mekan ve Emlak Çekimi', 'Video Çekim ve Kurgu'
  ],
  'Etkinlik ve Organizasyon': [
    'Doğum Günü Organizasyonu', 'Düğün Organizasyonu',
    'Balon ve Süsleme', 'Kına ve Nişan Organizasyonu',
    'Kurumsal Etkinlik Organizasyonu', 'Ses ve Işık Sistemi Kiralama'
  ],
  // ⚠ ANA KATEGORİ ADI DEĞİŞTİRİLDİ: 'Evcil Hayvan' → 'Evcil Hayvan
  // Bakımı' yapılınca ALT HİZMETLE ÇAKIŞTI. `anaKategoriBul` her
  // zaman ana kategoriyi döndürdüğü için o alt hizmet SEÇİLEMEZ
  // hâle gelmişti. Ana kategori 'Evcil Hayvan Hizmetleri' oldu.
  'Evcil Hayvan Hizmetleri': [
    'Köpek Gezdirme', 'Evcil Hayvan Bakımı', 'Pet Kuaför',
    'Evde Hayvan Bakıcılığı', 'Köpek Eğitimi', 'Evcil Hayvan Taşıma'
  ],
  'Güzellik ve Bakım Hizmetleri': [
    'Makyaj', 'Manikür Pedikür', 'Saç Tasarımı',
    'Gelin Saçı ve Makyajı', 'Kalıcı Oje', 'Ağda ve Epilasyon',
    'Cilt Bakımı', 'Evde Kuaför'
  ],

  // ═══════════════════════════════════════════════════════════
  // ⚠ HİZMET LİDERİ YAPISI (14 Ağu, ürün kararı)
  //
  // Ürün adı TEK BAŞINA kategori olmaz. Her ailede kullanıcının en
  // doğal arayacağı iş LİDER HİZMETTİR ve GERÇEK HİZMET olarak
  // listelenir; ilgili işler onunla aynı kategoride durur.
  //
  //   ✗ AYAKKABI (ürün adı)      ✓ Ayakkabı Tamiri (lider hizmet)
  //   ✗ ÇANTA                    ✓ Çanta Tamiri
  //   ✗ DERİ ÜRÜNLERİ            ✓ Deri Tamiri
  //
  // ⚠ 21 lider ÜÇ KATEGORİYE toplandı, 21 ayrı kategori AÇILMADI:
  // her kategori bir fotoğraf ve bir ikon ister; liderleri kategori
  // yapmak hem 21 görsel gerektirir hem de lider adını hizmet
  // listesinden düşürürdü. Bu yapıda lider ARANABİLİR HİZMETTİR —
  // "ayakkabı" yazan doğrudan `Ayakkabı Tamiri`'ni görür.
  //
  // ⚠ MİKRO HİZMET AÇILMADI: taban değişimi, fermuar tamiri, sap
  // değişimi, toka değişimi gibi işler liderin kapsamındadır.
  //
  // ⚠ `Halı Yıkama` EKLENMEDİ — katalogda kendi kategorisi var.
  // Yıkama bir temizlik işi, tamir/dokuma zanaat işidir; ikisi ayrı
  // yerde durur.
  'Ayakkabı ve Deri İşleri': [
    'Ayakkabı Tamiri', 'Bot Tamiri', 'Çizme Tamiri',
    'Spor Ayakkabı Tamiri', 'Sneaker Tamiri', 'Ayakkabı Boyama',
    'Ayakkabı Temizleme', 'Ayakkabı Bakımı', 'Ayakkabı Restorasyonu',
    'Ayakkabı Yapımı', 'Çanta Tamiri', 'Çanta Yapımı',
    'Çanta Temizleme', 'Çanta Boyama', 'Çanta Restorasyonu',
    'Deri Tamiri', 'Deri Ürün Yapımı', 'Deri Boyama', 'Deri Temizleme',
    'Deri Bakımı', 'Deri Restorasyonu', 'Kemer Tamiri', 'Kemer Yapımı',
    'Cüzdan Tamiri', 'Cüzdan Yapımı'
  ],
  'Terzilik ve Dikiş': [
    'Perde Dikimi', 'Perde Tadilatı', 'Perde Temizleme',
    'Perde Ölçüsü Alma', 'Perde Montajı', 'Stor Perde',
    'Fon Perde Dikimi', 'Fason Dikim', 'Seri Dikim', 'Numune Dikimi',
    'Kalıp Hazırlama', 'Özel Ölçü Kalıp Hazırlama', 'Overlok Hizmeti',
    'Reçme Hizmeti', 'Tekstil Ütüleme', 'Tekstil Paketleme',
    'Triko Tamiri', 'Triko Yapımı', 'Triko Yenileme', 'Triko Tadilatı',
    'Örgü Yapımı', 'Kazak Örme', 'Hırka Örme', 'Bebek Örgüsü',
    'Örgü Kıyafet Tamiri', 'Nakış', 'El Nakışı', 'Bilgisayarlı Nakış',
    'Logo Nakışı', 'Kişiye Özel Nakış', 'Monogram', 'Tekstil İşleme',
    'Piko', 'İlik Açma', 'Kumaş Dokuma', 'Kumaş Kesimi',
    'Kumaş Tamiri'
  ],
  'Ev Tekstili': [
    'Yorgan Dikimi', 'Yorgan Yapımı', 'Yorgan Yenileme',
    'Yorgan İçi Değişimi', 'Yatak Yenileme', 'Yatak Dolgusu Yenileme',
    'Yatak Tamiri', 'Halı Tamiri', 'Halı Dokuma', 'Halı Restorasyonu',
    'Halı Saçak Yenileme', 'Halı Overlok', 'Kilim Tamiri',
    'Kilim Dokuma', 'Kilim Restorasyonu'
  ],

  // ══════════════════════════════════════════════════════════════
  //  PROFESYONEL / OFİS HİZMETLERİ (16 Ağustos'ta eklendi)
  // ══════════════════════════════════════════════════════════════
  //
  // ⚠ BU BEŞ KATEGORİ SAHA İŞİ DEĞİL, MESLEK HİZMETİDİR.
  //
  // Katalogun geri kalanı ustalık işlerinden oluşur (tesisat, boya,
  // nakliyat). Bunlar ise büro hizmetleridir: iş genellikle uzaktan
  // veya danışmanın ofisinde yapılır. Yapı aynıdır — kategori ve
  // içinde hizmetler — ayrı bir mekanizma GEREKMEZ.
  //
  // ⚠ KATALOGLA ÇAKIŞMA YOK: 123 hizmetin hiçbiri mevcut 517
  // hizmetten biriyle aynı adı taşımıyor (ölçüldü).
  'Avukatlık ve Hukuk': [
    'Hukuki Danışmanlık', 'Dava Danışmanlığı', 'Dava Takibi',
    'İcra Takibi', 'Alacak Takibi', 'Sözleşme Hazırlama',
    'Sözleşme İnceleme', 'İş Hukuku Danışmanlığı',
    'İşçi Hakları Danışmanlığı', 'İşveren Hukuku Danışmanlığı',
    'Kira Hukuku', 'Gayrimenkul Hukuku', 'Aile Hukuku',
    'Boşanma Davası', 'Miras Hukuku', 'Tüketici Hukuku',
    'Ceza Hukuku', 'Ticaret Hukuku', 'Şirketler Hukuku',
    'Vergi Hukuku', 'Bilişim Hukuku', 'KVKK Danışmanlığı',
    'İş Kazası Hukuku', 'Tazminat Davaları', 'Arabuluculuk',
    'Marka ve Patent Hukuku', 'Fikri Mülkiyet Hukuku',
    'Hukuki Belge Hazırlama', 'Hukuki Belge İnceleme'
  ],
  'Muhasebe ve Mali Müşavirlik': [
    'Ön Muhasebe', 'Genel Muhasebe', 'Mali Müşavirlik',
    'Vergi Danışmanlığı', 'Vergi Beyannamesi Hazırlama',
    'KDV Beyannamesi', 'Gelir Vergisi İşlemleri',
    'Kurumlar Vergisi İşlemleri', 'Geçici Vergi İşlemleri',
    'E-Fatura İşlemleri', 'E-Arşiv İşlemleri', 'E-Defter İşlemleri',
    'SGK İşlemleri', 'Bordro Hazırlama', 'Personel Özlük İşlemleri',
    'Şirket Kuruluş İşlemleri', 'Şahıs Şirketi Kuruluşu',
    'Limited Şirket Kuruluşu', 'Anonim Şirket Kuruluşu',
    'Şirket Kapanış İşlemleri', 'Vergi Mükellefiyeti İşlemleri',
    'Muhasebe Kayıt İşlemleri', 'Finansal Raporlama',
    'Maliyet Analizi', 'Muhasebe Danışmanlığı',
    'Mali Denetim Danışmanlığı'
  ],
  'İş Güvenliği ve İSG': [
    'İş Güvenliği Uzmanlığı', 'İSG Danışmanlığı',
    'Risk Değerlendirmesi', 'İş Yeri Risk Analizi',
    'Acil Durum Eylem Planı', 'Acil Durum Planı Hazırlama',
    'Acil Durum Tatbikatı', 'İSG Eğitimleri',
    'Çalışan İş Güvenliği Eğitimi', 'İşe Giriş İSG Eğitimi',
    'Yangın Eğitimi', 'Tahliye Eğitimi', 'İş Kazası İnceleme',
    'İş Kazası Raporlama', 'İSG Saha Denetimi',
    'İSG Dokümantasyonu', 'İSG Kurul Danışmanlığı',
    'İş Hijyeni Danışmanlığı', 'Periyodik Kontrol Organizasyonu',
    'Risk Analizi Güncelleme', 'İSG Mevzuat Danışmanlığı',
    'OSGB Hizmetleri'
  ],
  'Marka ve Patent': [
    'Marka Araştırması', 'Marka Başvurusu', 'Marka Tescili',
    'Marka Yenileme', 'Marka Devir İşlemleri',
    'Marka İtiraz İşlemleri', 'Marka İzleme',
    'Marka Koruma Danışmanlığı', 'Patent Araştırması',
    'Patent Başvurusu', 'Patent Tescili',
    'Faydalı Model Başvurusu', 'Faydalı Model Tescili',
    'Tasarım Tescili', 'Endüstriyel Tasarım Başvurusu',
    'Patent Yenileme', 'Patent Devir İşlemleri',
    'Patent İtiraz İşlemleri', 'Fikri Mülkiyet Danışmanlığı',
    'Telif Hakkı Danışmanlığı', 'Lisanslama Danışmanlığı'
  ],
  'Sigorta': [
    'Sigorta Danışmanlığı', 'Sigorta Poliçesi Karşılaştırma',
    'Konut Sigortası', 'DASK', 'İşyeri Sigortası',
    'Ticari İşletme Sigortası', 'Kasko', 'Trafik Sigortası',
    'Sağlık Sigortası', 'Tamamlayıcı Sağlık Sigortası',
    'Özel Sağlık Sigortası', 'Hayat Sigortası',
    'Ferdi Kaza Sigortası', 'Seyahat Sigortası',
    'İşveren Sorumluluk Sigortası', 'Mesleki Sorumluluk Sigortası',
    'Nakliyat Sigortası', 'Yangın Sigortası', 'Tarım Sigortası',
    'Makine Kırılması Sigortası', 'Elektronik Cihaz Sigortası',
    'Sigorta Hasar Danışmanlığı', 'Hasar Dosyası Takibi',
    'Poliçe Yenileme', 'Kurumsal Sigorta Danışmanlığı'
  ],
};



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
  // ⚠ 'Doğalgaz Tesisatı ve Proje' kısaltması KALDIRILDI —
  // kategorinin gerçek adı zaten 'Doğalgaz'.
  'İlaçlama ve Haşere Kontrolü': 'İlaçlama',
  // ⚠ 'Elektrik Tesisat ve Arıza' birleşik adı KALKTI. Kategori adı
  // 'Elektrik'; tesisat ve arıza AYRI HİZMET olarak zaten duruyor.
  // Kısaltma da gereksiz: kategori adı hizmet adıyla çakışmasın.
  'Klima Montaj ve Servis': 'Klima Servisi',
  'Duvar Kağıdı ve Dekorasyon': 'Duvar Kağıdı',
  // ⚠ "Yenileme" yerine "Dekorasyon": kart artık dekorasyon işlerinin
  // de adresi olarak okunuyor (Duvar Kağıdı kartı kısaldığı için
  // "dekorasyon" sözcüğü buraya taşındı).
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
  // değiştirilir, kod aynı kalır.
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
  // gerçek görseller geldiğinde dosyalar aynı adla değiştirilir,
  // KODDA TEK SATIR DEĞİŞMEZ.
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

/// ⚠ ANA KATEGORİ SINIRI KALDIRILDI.
///
/// Eskiden `kMaxAnaKategori = 2` vardı: hizmet veren en fazla iki ana
/// kategori seçebiliyordu. Katalog 53 kategoriye çıkınca bu sınır
/// gerçekliğe aykırı hâle geldi — hem tesisat, hem kombi, hem ısıtma
/// yapan bir hizmet veren üçünü birden seçemiyordu.
///
/// NİHAİ KURAL: hizmet veren BİRDEN FAZLA ana kategori ve BİRDEN FAZLA
/// alt hizmet seçebilir. Sayı sınırı yoktur.

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
