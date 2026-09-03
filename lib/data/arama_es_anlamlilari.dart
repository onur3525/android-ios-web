/// ARAMA EŞ ANLAMLILARI — halk dilindeki karşılıklar.
///
/// ## NİÇİN VAR
///
/// Kullanıcı çoğu zaman HİZMET ADINI değil DERDİNİ yazar:
///
/// | Kullanıcı yazar        | Katalogdaki ad          |
/// |------------------------|-------------------------|
/// | `gaz kaçağı`           | Doğalgaz Tesisatı       |
/// | `kapıda kaldım`        | Kapı Açma               |
/// | `kombi yanmıyor`       | Kombi Tamiri            |
/// | `badana`               | Saten Boya Badana       |
/// | `mantolama`            | Mantolama               |
///
/// Yalnız katalog adları arandığında bu sorguların hepsi SIFIR sonuç
/// döner. Kullanıcı hizmetin var olduğunu bilemez ve uygulamayı
/// terk eder.
///
/// ## NİÇİN KATALOG BÜYÜTÜLMEDİ
///
/// ⚠ `kCategoryTree` ELLE DÜZENLENMEZ — admin/backend üretir.
///
/// Ayrıca kelime çeşidi kategori sayısından her zaman fazladır:
/// "Doğalgaz Kaçak Tespiti" diye bir kategori açsak bile kullanıcı
/// "gaz kokusu" yazınca yine bulamaz. Sözlük bu işi TERSTEN çözer —
/// bir hizmete beş kelime bağlanır, katalog büyümez.
///
/// ## İŞ KURALI — YENİ KATEGORİ EKLENİRKEN
///
/// ⚠ Kataloğa yeni bir alt hizmet eklendiğinde BU DOSYAYA DA
/// karşılıkları eklenmelidir. Eklenmezse hizmet yalnız tam adıyla
/// aranabilir ve pratikte görünmez kalır.
///
/// Terim seçerken:
///   1. Halk dilindeki adı  → `badana`, `mantolama`, `çilingir`
///   2. Arıza cümlesi       → `kombi yanmıyor`, `klima soğutmuyor`
///   3. Eş anlamlılar       → `kaçak` / `sızıntı` / `damlama`
///   4. Yaygın kısaltma     → `çam. makinesi`, `bulaşık mak.`
///
/// ⚠ ÇAKIŞMA SORUN DEĞİLDİR. `kaçak` hem `Tesisat Kaçağı Tespiti`
/// hem `Doğalgaz Tesisatı` altında geçer; kullanıcı yalnız "kaçak"
/// yazınca ikisi de listelenir — doğrusu budur, hangisini kastettiğini
/// kullanıcı seçer.
///
/// ⚠ TERİMLER KÜÇÜK HARF ve TÜRKÇE YAZILIR. Karşılaştırma
/// `SearchService._norm` ile yapılır: büyük/küçük ve Türkçe karakter
/// farkı zaten normalleştirilir.
library;

/// Alt hizmet adı → o hizmeti anlatan arama terimleri.
///
/// Anahtarlar `kCategoryTree` içindeki alt hizmet adlarıyla BİREBİR
/// aynı yazılır; eşleşmeyen anahtar sessizce yok sayılır.
///
/// ⚠ 640 ALT HİZMETİN TAMAMI KAPSANIR. Test bunu denetler; kataloğa
/// yeni hizmet eklenip terimi unutulursa test düşer.
const Map<String, List<String>> kAramaEsAnlamlilari = {
  // ── Temizlik ──
  'Ev Temizliği': ['ev temizlik', 'temizlikçi', 'gündelikçi',
    'daire temizliği', 'temizlik yardımcısı', 'ev işi',
    'haftalık temizlik', 'günlük temizlik', 'temizlik görevlisi',
    'ev işleri yardımcısı'
  ],
  'Boş Ev Temizliği': ['boş ev temizliği', 'eşyasız ev temizliği',
    'yeni ev temizliği',
    'kiralık ev temizliği'
  ],
  'Ofis Temizliği': ['ofis temizlik', 'iş yeri temizliği',
    'büro temizliği', 'dükkan temizliği',
    'işyeri temizliği', 'kurumsal temizlik'
  ],
  'İnşaat Sonrası Temizlik': ['tadilat sonrası temizlik',
    'inşaat temizliği', 'boya sonrası temizlik', 'kaba temizlik',
    'inşaat sonrası', 'ince temizlik'
  ],
  'Derin Temizlik': ['detaylı temizlik', 'bahar temizliği',
    'kapsamlı temizlik', 'dip temizlik'],
  'Taşınma Temizliği': ['taşınma öncesi temizlik', 'çıkış temizliği',
    'yeni ev temizliği',
    'taşınma sonrası temizlik', 'eve girmeden temizlik'
  ],
  'Cam Temizliği': ['cam silme', 'pencere temizliği', 'cephe cam',
    'cam yıkama',
    'cam silici', 'dış cephe cam temizliği', 'vitrin temizliği',
    'cephe cam silme'
  ],

  // ── Halı Yıkama · Koltuk ve Döşeme Yıkama ──
  // ⚠ Kategori ikiye bölündü; alt hizmet adları DEĞİŞMEDİ, bu yüzden
  // aşağıdaki karşılıklar aynen geçerlidir.
  'Koltuk Yıkama': ['koltuk temizliği', 'kanepe yıkama',
    'döşeme temizliği', 'yerinde koltuk yıkama',
    'oturma grubu yıkama'
  ],
  'Yatak Yıkama': ['yatak temizliği', 'baza temizliği', 'şilte yıkama',
    'şilte temizliği', 'yatak leke çıkarma'
  ],
  'Perde Yıkama': ['perde temizliği', 'perde yıkatma', 'tül yıkama',
    'perde sökme takma'
  ],
  'Stor Perde Temizliği': ['stor temizliği', 'jaluzi temizliği',
    'zebra perde',
    'zebra perde temizliği'
  ],

  // ── İlaçlama ──
  'Ev İlaçlama': ['ev ilaçlama', 'evde ilaçlama', 'ilaçlamacı',
    'ilaçlama servisi', 'böcek ilaçlaması', 'ev dezenfeksiyonu'
  ],
  'Böcek İlaçlama': ['böcek ilaçlama', 'hamamböceği', 'karınca',
    'böcek var',
    'hamamböceği ilaçlama', 'hamam böceği ilaçlama',
    'karafatma ilaçlama', 'böcek ilaçlama servisi'
  ],
  'Haşere İlaçlama': ['böcek ilaçlama', 'hamamböceği', 'karınca',
    'ilaçlama', 'haşere', 'sinek ilaçlama',
    'haşere ilaçlama', 'karınca ilaçlama', 'güve ilaçlama',
    'pire ilaçlama'
  ],
  'Kene İlaçlama': ['kene', 'pire ilaçlama', 'bahçe ilaçlama',
    'kene ilaçlama', 'bahçe kene ilaçlama', 'kene mücadelesi'
  ],
  'Fare Mücadelesi': ['fare', 'sıçan', 'kemirgen', 'fare ilaçlama',
    'sıçan mücadelesi', 'kemirgen mücadelesi',
    'fare kapanı uygulaması'
  ],
  'Tahtakurusu İlaçlama': ['tahtakurusu', 'yatak böceği',
    'tahta kurusu ilaçlama',
    'tahtakurusu ilaçlama', 'yatak böceği ilaçlama'
  ],

  // ── Su Tesisatı ──
  'Su Tesisatçısı': ['su tesisatçısı', 'tesisatçı', 'su borusu',
    'boru patladı', 'musluk takma',
    'su ustası', 'tesisat ustası', 'sıhhi tesisatçı'
  ],
  'Sıhhi Tesisat': ['klozet', 'lavabo', 'rezervuar', 'duşakabin',
    'armatür', 'sifon', 'banyo tesisatı', 'mutfak tesisatı',
    'tuvalet montajı',
    'sıhhi tesisat', 'temiz su tesisatı', 'pis su tesisatı'
  ],
  'Su Kaçağı Tespiti': ['su kaçağı', 'kaçak bulma', 'tesisat kaçağı',
    'sızıntı', 'damlama', 'alt kata su iniyor', 'kırmadan kaçak',
    'termal kaçak',
    'su kaçağı tespiti', 'su sızıntısı tespiti', 'duvardan su geliyor',
    'cihazla su kaçağı bulma'
  ],
  'Tıkanıklık Açma': ['tıkanıklık', 'tıkalı', 'tıkanıklık açma',
    'lavabo tıkalı', 'tuvalet tıkalı', 'kanal açma',
    'tıkanıklık açtırma', 'lavabo tıkandı', 'klozet tıkandı',
    'gider tıkalı', 'tuvalet tıkanıklığı'
  ],
  'Gider Açma': ['tıkanıklık', 'tıkalı', 'gider tıkandı',
    'lavabo tıkalı', 'tuvalet tıkalı', 'kanal açma', 'kanalizasyon',
    'rögar', 'pis su', 'su taşıyor', 'gider açma', 'sifon tıkandı',
    'pissu açma', 'rögar açma'
  ],
  'Musluk Montajı': ['musluk takma', 'musluk değişimi',
    'batarya montajı', 'armatür montajı',
    'batarya değişimi', 'çeşme değişimi', 'musluk damlatıyor'
  ],
  'Klozet Montajı': ['klozet takma', 'tuvalet montajı',
    'rezervuar montajı', 'klozet değişimi',
    'tuvalet taşı montajı', 'rezervuar tamiri', 'taharet musluğu'
  ],
  'Su Deposu Temizliği': ['depo temizliği', 'su tankı',
    'sarnıç temizliği', 'su deposu',
    'su tankı temizliği'
  ],
  'Tesisat Tamiri': ['tesisatçı', 'su arızası', 'tesisat arızası',
    'boru onarımı', 'su tamiri',
    'boru patladı', 'boru tamiri', 'sızdıran boru'
  ],
  'Su Arıtma Servisi': ['su arıtma', 'filtre değişimi', 'arıtma cihazı',
    'su filtresi', 'su arıtma servisi',
    'arıtma filtresi değişimi', 'su arıtma bakımı'
  ],

  // ── Doğalgaz ──
  //
  // ⚠ KURAL: "DOĞALGAZ" GEÇEN HER İŞ BURAYA BAĞLANIR.
  //
  // Katalog BÜYÜTÜLMEZ — yeni kategori/alt hizmet açılmaz. Kullanıcı
  // ne yazarsa yazsın mevcut DÖRT hizmetten birine düşer ve o
  // hizmetle ilan açar.
  //
  // ⚠ Varyantın çokluğu sorun değildir: sözlük büyüdükçe arama
  // isabeti artar, katalog aynı kalır.
  // ⚠ KAÇAK TERİMLERİ BURADAN ÇIKARILDI.
  //
  // Kaçak artık ÜÇ AYRI hizmet (kontrol · tespit · onarım). Genel
  // "gaz kaçağı", "gaz kokusu" gibi terimler burada da dururken
  // "gaz kaçağı onarımı" sorgusunda Doğalgaz Tesisatı, asıl hedef
  // olan Kaçak Onarımı'nın ÖNÜNE geçiyordu.
  'Doğalgaz Tesisatı': ['gaz tesisatı',
    'gaz hattı', 'gaz borusu', 'sayaç bağlantısı', 'gaz açtırma',
    'doğalgaz çekimi',
    // Ocak bağlantısı — sahada en sık istenen tekil iş.
    'doğalgaz ocak bağlama', 'ocak bağlama', 'ocak bağlantısı',
    'ankastre ocak bağlantısı', 'set üstü ocak bağlantısı',
    'ocak hortumu', 'fleksi hortum', 'flexi boru montajı',
    // LPG → doğalgaz dönüşümü (enjektör/meme değişimi).
    'lpg doğalgaz dönüşümü', 'ocak dönüşümü', 'meme değişimi',
    'enjektör değişimi', 'tüpten doğalgaza geçiş',
    // Daire içi / bina içi tesisat.
    'daire içi doğalgaz', 'daire içi tesisat', 'bina içi tesisat',
    'iç tesisat', 'doğalgaz iç tesisat', 'doğalgaz kurulumu',
    'doğalgaz montajı', 'doğalgaz ustası', 'doğalgaz tesisatçısı',
    'gaz borusu değişimi', 'doğalgaz boru değişimi',
    // Cihaz bağlantıları — hepsi doğalgaz tesisat işi.
    'doğalgaz sobası', 'doğalgaz sobası montajı', 'sobalı tesisat',
    'doğalgazlı şofben', 'şofben gaz bağlantısı',
    // Ölçek varyantları.
    'endüstriyel doğalgaz tesisatı', 'merkezi sistem doğalgaz',
    'doğalgaz kolon tesisatı', 'kazan dairesi doğalgaz',
    'işyeri doğalgaz tesisatı'],
  'Doğalgaz Projesi': ['gaz projesi', 'doğalgaz çizimi', 'gaz abonelik',
    'gaz proje onayı',
    // Abonelik ve gaz açma süreci — proje ile yürür.
    'gaz açma', 'gaz açımı', 'doğalgaz açtırma', 'doğalgaz aboneliği',
    'izmirgaz abonelik', 'izmirgaz proje', 'doğalgaz sözleşmesi',
    'uygunluk belgesi', 'tadilat uygunluk belgesi',
    'doğalgaz proje onayı', 'kolon projesi', 'doğalgaz projelendirme',
    'doğalgaz mühendislik', 'gaz açım işlemleri'],
  'Doğalgaz Kaçak Kontrolü': ['gaz kaçağı', 'doğalgaz kaçağı',
    'gaz kokusu', 'gaz sızıntısı', 'gaz kaçak kontrolü',
    // ⚠ TAMİR DE BURAYA: bizde ayrı bir "kaçak tamiri" kaydı yok.
    // Kaçakla ilgili her iş tek hizmete düşer; usta yerinde tespit
    // eder ve onarır.
    'doğalgaz kaçağı tamiri', 'gaz kaçağı onarımı',
    'doğalgaz kaçak onarım', 'gaz kaçağı bulma',
    'doğalgaz kaçağı tespiti', 'gaz dedektörü kontrolü',
    'doğalgaz güvenlik kontrolü', 'gaz kaçak testi'],
  'Doğalgaz Boru Hattı Tadilatı': ['gaz borusu', 'gaz hattı',
    'doğalgaz tadilat', 'gaz hattı taşıma',
    'sayaç yeri değişikliği', 'doğalgaz sayaç taşıma',
    'kolon tesisatı', 'ana kolon tesisatı', 'kolon tadilatı',
    // ⚠ "hat" sözcüğüyle arayanlar da bulmalı: sözlükte yalnız
    // "tesisat" biçimi vardı, "kolon hattı" sorgusu SIFIR dönüyordu.
    'kolon hattı', 'doğalgaz kolon hattı', 'gaz kolon hattı',
    'ana kolon hattı',
    'doğalgaz hattı uzatma', 'gaz borusu taşıma',
    'doğalgaz tesisat tadilatı', 'petek yeri değişikliği'],

  // ── ⚠ DOĞALGAZ — YENİ HİZMETLER (katalog 4 → 8) ──
  //
  // Bu dördü eskiden yalnız TERİMDİ ve "Doğalgaz Tesisatı" adıyla
  // ilan açıyordu; kullanıcının seçtiğiyle ilanında yazan farklı
  // oluyordu. Artık gerçek hizmet kayıtları.
  'Doğalgaz İç Tesisatı': ['daire içi doğalgaz', 'daire içi tesisat',
    'bina içi tesisat', 'iç tesisat', 'doğalgaz iç tesisat',
    'daire içi gaz tesisatı', 'iç tesisat çekimi',
    'doğalgaz ocak hattı', 'ocak hattı çekimi'],
  'Doğalgaz Kolon Hattı': ['kolon hattı', 'doğalgaz kolon hattı',
    'gaz kolon hattı', 'ana kolon hattı', 'kolon tesisatı',
    'ana kolon tesisatı', 'bina ana kolon', 'kolon projesi',
    'apartman doğalgaz hattı'],
  'Doğalgaz Kaçak Tespiti': ['gaz kaçağı tespiti',
    'doğalgaz kaçağı tespiti', 'gaz kaçağı bulma',
    'gaz sızıntısı tespiti', 'cihazla gaz kaçağı bulma',
    'gaz dedektörü ölçümü', 'gaz kokusu tespiti'],
  'Doğalgaz Kaçak Onarımı': ['gaz kaçağı onarımı',
    'doğalgaz kaçağı tamiri', 'doğalgaz kaçak onarım',
    'gaz kaçağı giderme', 'kaçak noktası onarımı',
    'gaz borusu kaçak tamiri'],

  // ── Kombi ──
  'Kombi Montajı': ['kombi takma', 'kombi kurulumu', 'yeni kombi',
    'kombi değişimi', 'kombi montaj',
    'yeni kombi montajı', 'kombi yeri değişikliği'
  ],
  'Kombi Tamiri': ['kombi yanmıyor', 'kombi çalışmıyor', 'kombi arızası',
    'kombi ısıtmıyor', 'kombi su akıtıyor', 'kombi hata veriyor',
    'kombi basınç düşüyor', 'sıcak su yok',
    'sıcak su gelmiyor'
  ],
  'Kombi Bakımı': ['kombi bakım', 'kombi temizliği', 'yıllık bakım',
    'kombi servisi', 'kombi kontrol',
    'kombi bakımı', 'yıllık kombi bakımı', 'eşanjör temizliği',
    'kombi periyodik bakım'
  ],
  'Kombi Değişimi': ['kombi değiştirme', 'yeni kombi', 'kombi yenileme',
    'eski kombi değişimi'
  ],

  // ── Isıtma ──
  'Petek Temizliği': ['petek ısınmıyor', 'petek altı soğuk',
    'radyatör temizliği', 'peteklerde hava', 'petek yıkama',
    'petek temizletme', 'petek ısıtmıyor',
    'kombi eşanjör temizliği', 'kombi iç temizlik'
  ],
  'Petek Montajı': ['petek takma', 'radyatör montajı', 'petek ekleme',
    'petek değişimi', 'petek yeri değiştirme'
  ],
  'Yerden Isıtma': ['yerden ısıtma', 'yerden ısıtma sistemi',
    'döşemeden ısıtma',
    'yerden ısıtma tesisatı', 'yerden ısıtma arızası'
  ],
  'Şofben Tamiri': ['şofben', 'şofben yanmıyor', 'şofben arızası',
    'şofben bakımı'
  ],
  'Termosifon Tamiri': ['termosifon', 'su ısıtıcı', 'boyler',
    'sıcak su yok',
    'termosifon arızası', 'termosifon değişimi', 'boyler tamiri'
  ],

  // ── Elektrik ──
  'Elektrikçi': ['elektrikçi', 'elektrik ustası', 'elektrik işi',
    'elektrik teknisyeni'
  ],
  'Elektrik Arıza': ['elektrik yok', 'sigorta atıyor',
    'elektrik kesildi', 'kısa devre', 'elektrik arızası',
    'priz çalışmıyor',
    'sigorta attı', 'kaçak akım arızası', 'kısa devre arızası'
  ],
  'Elektrik Tesisatı': ['elektrik çekme', 'kablo çekimi',
    'tesisat yenileme', 'hat çekme', 'elektrik döşeme',
    'elektrik tesisatı yenileme', 'sıva altı tesisat'
  ],
  // ⚠ PRİZ ve ANAHTAR AYRI HİZMET. Eski birleşik ad
  // "priz ve anahtar montajı" İKİSİNİN DE terimi olarak durur;
  // kullanıcı eski adı yazarsa iki hizmet de listelenir.
  'Priz Montajı': ['priz takma', 'priz ekleme', 'priz montajı',
    'priz ve anahtar montajı',
    'priz değişimi', 'usb priz'
  ],
  'Anahtar Montajı': ['elektrik anahtarı', 'ışık anahtarı',
    'anahtar takma', 'anahtar değişimi', 'düğme montajı',
    'priz ve anahtar montajı',
    'düğme değişimi', 'dimmer montajı'
  ],
  'Avize Montajı': ['avize takma', 'avize asma', 'lamba takma',
    'aplik montajı',
    'lamba montajı', 'sarkıt montajı', 'spot montajı'
  ],
  // ⚠ YENİ PANO MONTAJI ile MEVCUT PANONUN YENİLENMESİ ayrı iştir.
  'Sigorta Panosu Montajı': ['sigorta panosu', 'pano montajı',
    'sigorta kutusu', 'yeni pano', 'şalter montajı',
    'sigorta değişimi', 'kaçak akım rölesi'
  ],
  'Elektrik Panosu Yenileme': ['pano yenileme',
    'elektrik panosu değişimi', 'pano değişimi',
    'elektrik panosu yenileme', 'eski pano',
    'elektrik panosu bakımı'
  ],
  'Aydınlatma Sistemleri': ['led aydınlatma', 'spot montajı',
    'bahçe aydınlatma', 'dekoratif ışık', 'sensörlü lamba',
    'spot aydınlatma', 'bahçe aydınlatması', 'dekoratif aydınlatma'
  ],

  // ── Güvenlik Sistemleri ──
  'Kamera Sistemi Kurulumu': ['güvenlik kamerası', 'kamera montajı',
    'cctv', 'ip kamera', 'kamera sistemi'],
  'Alarm Sistemi Kurulumu': ['alarm', 'hırsız alarmı', 'alarm kurulumu',
    'güvenlik alarmı',
    'alarm montajı', 'ev alarm sistemi'
  ],
  'Görüntülü Diafon Montajı': ['diafon', 'interkom', 'görüntülü kapı',
    'kapı zili montajı',
    'diafon montajı', 'interkom montajı', 'kapı zili sistemi',
    'görüntülü kapı zili'
  ],
  'Akıllı Kilit': ['akıllı kilit', 'parmak izi kilit', 'şifreli kilit',
    'parmak izli kilit', 'akıllı kapı kilidi'
  ],
  'Yangın Algılama': ['yangın alarmı', 'duman dedektörü',
    'yangın sistemi',
    'yangın sensörü'
  ],

  // ── Klima ──
  'Klima Montajı': ['klima takma', 'klima kurulumu', 'klima montaj',
    'yeni klima', 'split klima',
    'split klima montajı', 'klima yeri değişikliği'
  ],
  'Klima Bakımı': ['klima soğutmuyor', 'gaz dolumu', 'klima temizliği',
    'klima bakım', 'klima filtresi', 'klima kokuyor',
    'klima bakımı', 'klima gaz dolumu', 'klima periyodik bakım'
  ],
  'Klima Tamiri': ['klima çalışmıyor', 'klima arızası',
    'klima su akıtıyor', 'klima ses yapıyor',
    'klima soğutmuyor'
  ],
  'Klima Temizliği': ['klima temizliği', 'klima filtresi',
    'klima kokuyor', 'klima bakımı',
    'filtre temizliği', 'klima dezenfeksiyonu'
  ],
  'Havalandırma Sistemleri': ['havalandırma', 'aspiratör montajı',
    'baca fanı', 'hava kanalı',
    'havalandırma sistemi', 'aspiratör sistemi', 'menfez montajı',
    'baca havalandırma'
  ],
  'VRF Sistemleri': ['vrf', 'merkezi klima', 'multi split',
    'ticari klima',
    'vrf klima', 'merkezi klima sistemi', 'kanallı klima'
  ],

  // ── Beyaz Eşya ──
  'Buzdolabı Tamiri': ['buzdolabı soğutmuyor', 'dolap bozuldu',
    'buzluk çalışmıyor', 'dolap su yapıyor', 'buzdolabı ses yapıyor',
    'buzdolabı arızası',
    'dolap arızası', 'no-frost tamiri', 'buzdolabı su akıtıyor'
  ],
  'Çamaşır Makinesi Tamiri': ['çamaşır makinesi su almıyor',
    'çamaşır makinesi sıkmıyor', 'çamaşır makinesi akıtıyor',
    'çamaşır makinesi çalışmıyor', 'çamaşır makinesi ses yapıyor',
    'kapağı açılmıyor',
    'çamaşır makinesi arızası', 'makine su akıtıyor'
  ],
  'Bulaşık Makinesi Tamiri': ['bulaşık makinesi yıkamıyor',
    'bulaşık makinesi su almıyor', 'bulaşık makinesi akıtıyor',
    'bulaşık makinesi kurutmuyor',
    'bulaşık makinesi arızası'
  ],
  'Kurutma Makinesi Tamiri': ['kurutma makinesi kurutmuyor',
    'kurutma makinesi ısıtmıyor', 'kurutucu arızası',
    'kurutma makinesi arızası'
  ],
  'Aspiratör Tamiri': ['aspiratör', 'davlumbaz', 'davlumbaz çekmiyor',
    'aspiratör tamiri', 'davlumbaz tamiri',
    'aspiratör çekmiyor', 'davlumbaz montajı'
  ],
  'Fırın Tamiri': ['fırın ısınmıyor', 'ocak yanmıyor',
    'fırın çalışmıyor', 'ankastre arıza', 'set üstü ocak',
    'fırın ısıtmıyor', 'ankastre fırın tamiri', 'ocak tamiri',
    'set üstü ocak arızası'
  ],

  // ── Elektronik Tamiri ──
  'Televizyon Tamiri': ['tv açılmıyor', 'televizyon arızası',
    'ekran bozuk', 'tv tamiri',
    'ekran değişimi', 'led tv tamiri'
  ],
  'Bilgisayar Tamiri': ['bilgisayar açılmıyor', 'laptop tamiri',
    'pc arızası', 'format atma', 'bilgisayar yavaş',
    'pc tamiri', 'virüs temizleme'
  ],
  'Telefon Tamiri': ['telefon ekranı kırıldı', 'telefon tamiri',
    'şarj almıyor', 'batarya değişimi',
    'cep telefonu tamiri', 'ekran değişimi', 'şarj soketi'
  ],
  'Tablet Tamiri': ['tablet ekranı', 'tablet tamiri', 'tablet açılmıyor',
    'tablet ekran değişimi', 'ipad tamiri'
  ],
  'Oyun Konsolu Tamiri': ['playstation tamiri', 'konsol arızası',
    'xbox tamiri',
    'konsol tamiri'
  ],

  // ── Uydu ve Görüntü Sistemleri ──
  'Uydu Anteni Kurulumu': ['uydu anteni', 'çanak kurulumu',
    'anten takma',
    'çanak anten kurulumu', 'uydu montajı', 'digitürk montajı'
  ],
  'Çanak Anten Ayarı': ['çanak ayarı', 'uydu ayarı', 'sinyal yok',
    'kanal gelmiyor',
    'sinyal ayarı', 'kanal ayarı'
  ],
  'Merkezi Uydu Sistemi': ['merkezi uydu', 'santral anten',
    'apartman anten',
    'merkezi sistem anten', 'apartman anten sistemi'
  ],
  'Televizyon Duvar Montajı': ['tv askı aparatı', 'televizyon asma',
    'tv duvara montaj',
    'televizyon askısı montajı', 'duvara tv asma'
  ],

  // ── İnternet ve Ağ ──
  'Modem Kurulumu': ['modem kurulum', 'internet bağlantısı',
    'modem ayarı', 'internet gelmiyor',
    'modem kurulumu', 'internet kurulumu'
  ],
  'Ağ Kablolama': ['ağ kablosu', 'network kurulumu', 'ethernet çekimi',
    'kablolama',
    'network kablolama', 'kablo tesisatı'
  ],
  'Wifi Güçlendirme': ['wifi çekmiyor', 'internet yavaş',
    'sinyal güçlendirici', 'mesh sistem',
    'access point'
  ],
  'Akıllı Ev Sistemleri': ['akıllı ev', 'otomasyon', 'akıllı priz',
    'sesli asistan',
    'smart home', 'google home kurulumu'
  ],

  // ── Boya ──
  'Boya Badana': ['boya', 'badana', 'ev boyama', 'boyacı', 'badanacı',
    'duvar boyama',
    'oda boyama', 'boya badana ustası'
  ],
  'İç Cephe Boya': ['iç boya', 'oda boyama', 'duvar boyama',
    'ev boyatma', 'boyacı',
    'iç cephe', 'salon boyama', 'tavan boyama', 'silinebilir boya'
  ],
  'Dış Cephe Boyama': ['dış cephe boya', 'bina boyama', 'apartman boya',
    'cephe boyama',
    'ipli cephe'
  ],
  'Dekoratif Boya': ['dekoratif duvar', 'efektli boya', 'antik boya',
    'desenli boya',
    'italyan boya', 'sıva üstü desen'
  ],
  'Kapı Boyama': ['kapı boyama', 'kapı boyatma', 'ahşap kapı boya',
    'dolap boyama', 'ahşap boyama', 'mobilya boyama'
  ],

  // ── Alçı ──
  'Alçıpan': ['alçıpan', 'asma tavan', 'bölme duvar', 'alçıpan ustası',
    'alçıpan bölme', 'asma tavan yapımı', 'alçıpan tavan',
    'gizli ışık bandı uygulaması',
    'oda bölme duvar', 'alçıpan duvar'
  ],
  'Alçı Sıva': ['alçı', 'sıva', 'saten alçı', 'duvar düzeltme', 'sıvacı',
    'alçı sıva', 'sıva tamiri'
  ],
  'Kartonpiyer': ['kartonpiyer', 'tavan süsü', 'kornis',
    'kartonpiyer montajı', 'kornis montajı', 'tavan süsü uygulaması'
  ],

  // ── Duvar Kağıdı ve Dekorasyon ──
  'Duvar Kağıdı Uygulama': ['duvar kağıdı', 'duvar kağıdı yapıştırma',
    'tapet',
    'duvar kağıdı ustası', 'duvar kağıdı sökme'
  ],
  'Duvar Paneli': ['duvar panel', 'ahşap panel', 'dekoratif panel',
    'lambri',
    'duvar paneli montajı', 'akustik panel',
    'ahşap panel montajı', 'lambri kaplama'
  ],
  '3D Duvar Kaplama': ['3d panel', 'üç boyutlu duvar',
    'kabartmalı duvar',
    'kabartmalı duvar kaplama'
  ],
  'Poster Duvar Kağıdı': ['poster duvar', 'manzara duvar kağıdı',
    'fotoğraf duvar',
    'özel baskı duvar kağıdı'
  ],

  // ── Tadilat ──
  'Ev Tadilatı': ['ev tadilat', 'daire yenileme', 'tadilatçı',
    'ev renovasyon', 'komple tadilat',
    'ev yenileme', 'tadilat ustası', 'ev renovasyonu'
  ],
  'Daire Tadilatı': ['daire tadilat', 'apartman dairesi tadilat',
    'daire yenileme', 'daire tadilatı'
  ],
  'Ofis Tadilatı': ['ofis yenileme', 'büro tadilat', 'iş yeri tadilat',
    'işyeri tadilatı'
  ],
  'Dükkan Tadilatı': ['dükkan yenileme', 'mağaza tadilat',
    'vitrin düzenleme',
    'mağaza tadilatı'
  ],
  'Anahtar Teslim Tadilat': ['anahtar teslim tadilat', 'komple yenileme',
    'baştan sona tadilat',
    'anahtar teslim', 'projeli tadilat'
  ],

  // ── Banyo ──
  'Banyo Tadilatı': ['banyo yenileme', 'banyo değişimi', 'banyo tadilat',
    'banyo komple tadilat', 'tuvalet tadilatı'
  ],
  'Duşakabin Montajı': ['duşakabin takma', 'duşakabin kurulumu',
    'duş kabini',
    'duş teknesi montajı', 'duşakabin tamiri'
  ],
  'Banyo Dolabı Montajı': ['banyo dolabı', 'lavabo dolabı',
    'banyo ayna dolabı',
    'banyo dolabı takma', 'ayna dolabı montajı'
  ],
  'Lavabo Montajı': ['lavabo takma', 'lavabo değişimi', 'lavabo montaj',
    'evye montajı', 'tezgah üstü lavabo'
  ],

  // ── Mutfak ──
  'Mutfak Tadilatı': ['mutfak yenileme', 'mutfak değişimi',
    'mutfak tadilat',
    'mutfak komple tadilat'
  ],
  'Mutfak Dolabı Yapımı': ['mutfak dolabı', 'mutfak dolabı yaptırma',
    'ölçüye göre mutfak',
    'mutfak imalatı'
  ],
  'Mutfak Dolabı Tamiri': ['mutfak dolabı tamiri', 'kapak ayarı',
    'menteşe değişimi',
    'dolap kapağı tamiri', 'çekmece tamiri'
  ],
  'Mutfak Tezgahı Montajı': ['tezgah takma', 'mutfak tezgahı',
    'tezgah değişimi',
    'granit tezgah', 'mermer tezgah montajı'
  ],
  'Hazır Mutfak': ['hazır mutfak', 'mutfak montajı', 'modüler mutfak',
    'hazır mutfak montajı'
  ],

  // ── İnşaat ──
  'Kaba İnşaat': ['kaba yapı', 'betonarme', 'temel atma', 'kolon kiriş',
    'betonarme işi', 'inşaat ustası'
  ],
  'Anahtar Teslim İnşaat': ['anahtar teslim', 'müteahhit', 'ev yapımı',
    'villa yapımı',
    'anahtar teslim ev', 'müteahhitlik hizmeti'
  ],
  'Duvar Örme': ['duvar yapma', 'tuğla örme', 'briket duvar',
    'bölme duvar',
    'duvar örme', 'tuğla duvar', 'gazbeton duvar',
    'tuğla duvar örme'
  ],
  'Yıkım İşleri': ['yıkım', 'duvar yıkma', 'kırım', 'hafriyat', 'moloz',
    'yıkım işi', 'hafriyat işi', 'moloz taşıma'
  ],

  // ── Seramik ──
  'Fayans Döşeme': ['fayans', 'fayans yapıştırma', 'fayansçı',
    'banyo fayansı',
    'fayans ustası'
  ],
  'Seramik Döşeme': ['seramik', 'seramik yapıştırma', 'yer karosu',
    'karo döşeme',
    'seramik ustası', 'yer seramiği', 'duvar seramiği'
  ],
  'Fayans Tamiri': ['fayans tamiri', 'fayans kırıldı', 'fayans değişimi',
    'fayans onarım',
    'kırık fayans değişimi', 'fayans kabardı'
  ],
  'Mermer Döşeme': ['mermer', 'mermer basamak', 'mermer eşik',
    'mermer tezgah',
    'mermer ustası', 'mermer merdiven'
  ],
  'Granit Uygulama': ['granit', 'granit tezgah', 'granit döşeme'],

  // ── Zemin ──
  'Parke Döşeme': ['parke', 'parke döşetme', 'ahşap zemin',
    'masif parke',
    'parke ustası', 'lamine parke',
    'laminat', 'laminat parke', 'lamine zemin', 'laminat döşeme',
    'laminat ustası'
  ],
  'Parke Tamiri': ['parke tamiri', 'parke kabardı', 'parke onarım',
    'parke değişimi',
    'parke zımpara', 'parke cila'
  ],
  'Halıfleks Uygulama': ['halıfleks', 'halı zemin', 'karo halı',
    'halıfleks döşeme', 'halıfleks değişimi'
  ],
  'PVC Zemin': ['pvc yer', 'vinil zemin', 'lvt zemin',
    'pvc zemin kaplama', 'spor zemini'
  ],
  'Epoksi Zemin Kaplama': ['epoksi', 'epoksi zemin', 'endüstriyel zemin',
    'garaj zemini',
    'otopark zemini'
  ],

  // ── Yalıtım ──
  'Su Yalıtımı': ['su yalıtımı', 'izolasyon', 'membran', 'nem yalıtımı',
    'bodrum su alıyor',
    'su izolasyonu', 'temel yalıtımı', 'balkon yalıtımı',
    'rutubet yalıtımı'
  ],
  'Isı Yalıtımı': ['ısı yalıtımı', 'ev soğuk', 'yalıtım',
    'enerji tasarrufu',
    'ısı izolasyonu', 'iç cephe yalıtım'
  ],
  'Mantolama': ['mantolama', 'dış cephe yalıtım', 'ısı yalıtım levhası',
    'bina mantolama',
    'mantolama yaptırma'
  ],
  'Ses Yalıtımı': ['ses yalıtımı', 'gürültü', 'akustik yalıtım',
    'komşu sesi',
    'ses izolasyonu', 'gürültü yalıtımı'
  ],
  'Teras İzolasyonu': ['teras yalıtımı', 'teras su alıyor',
    'teras membran',
    'çatı su izolasyonu', 'membran uygulama'
  ],

  // ── Çatı ──
  'Çatı Tamiri': ['çatı akıyor', 'dam akıntısı', 'çatı su alıyor',
    'çatı onarım', 'tavandan su damlıyor',
    'çatı akıtıyor', 'çatı onarımı', 'kayan kiremit onarımı'
  ],
  'Çatı Yapımı': ['çatı yapımı', 'yeni çatı', 'çatı inşaatı',
    'çatı imalatı', 'çelik çatı', 'ahşap çatı'
  ],
  'Çatı İzolasyonu': ['çatı yalıtımı', 'çatı membran', 'çatı izolasyon'],
  'Çatı Aktarma': ['çatı aktarma', 'kiremit aktarma', 'çatı yenileme',
    'çatı aktarımı'
  ],
  'Oluk Montajı': ['oluk', 'yağmur oluğu', 'dere oluk', 'oluk değişimi',
    'yağmur oluğu montajı', 'oluk temizliği'
  ],
  'Kiremit Değişimi': ['kiremit kırıldı', 'kiremit uçtu',
    'kiremit değiştirme',
    'kırık kiremit değişimi', 'kiremit değişimi'
  ],

  // ── Mobilya ──
  'Mobilya Montajı': ['mobilya kurulumu', 'mobilya takma', 'ikea montaj',
    'dolap kurma',
    'ikea montajı', 'dolap montajı', 'mobilya toplama'
  ],
  'Mobilya Tamiri': ['mobilya onarım', 'dolap tamiri', 'kapak ayarı',
    'menteşe değişimi',
    'mobilya onarımı', 'kanepe tamiri', 'sandalye tamiri'
  ],
  'Mobilya İmalatı': ['özel mobilya', 'ölçüye göre mobilya',
    'mobilya yapımı',
    'özel ölçü mobilya'
  ],
  'Gardırop Yapımı': ['gardırop yaptırma', 'özel gardırop',
    'giyinme odası yapımı',
    'gömme dolap yapımı', 'ölçüye göre gardırop'
  ],
  'Gardırop Montajı': ['gardırop kurulumu', 'dolap montajı',
    'giyinme odası'],
  'TV Ünitesi Yapımı': ['tv ünitesi yaptırma', 'özel tv ünitesi',
    'duvar ünitesi yapımı',
    'tv ünitesi imalatı'
  ],
  'TV Ünitesi Montajı': ['tv ünitesi', 'televizyon ünitesi',
    'duvar ünitesi',
    'tv ünitesi kurulumu'
  ],
  'Vestiyer Yapımı': ['vestiyer', 'portmanto', 'antre dolabı',
    'vestiyer yapımı', 'portmanto yapımı'
  ],

  // ── Marangozluk ──
  'Özel Mobilya Yapımı': ['özel mobilya', 'ölçüye göre mobilya',
    'mobilya yaptırma', 'marangoz',
    'marangoz ustası', 'masif mobilya'
  ],
  'Ahşap Raf Yapımı': ['ahşap raf', 'raf yaptırma', 'duvar rafı',
    'raf yapımı', 'kitaplık yapımı'
  ],
  'Ahşap Masa Yapımı': ['ahşap masa', 'masa yaptırma', 'özel masa',
    'masa yapımı', 'mutfak masası', 'epoksi masa'
  ],
  'Ahşap Merdiven': ['merdiven yapımı', 'ahşap basamak',
    'merdiven korkuluk'],
  'Ahşap Pergola': ['pergola', 'çardak', 'ahşap gölgelik', 'kameriye',
    'ahşap pergola yapımı', 'çardak yapımı'
  ],
  'Masa ve Sandalye Tamiri': ['masa tamiri', 'sandalye tamiri',
    'ahşap onarım',
    'masa onarımı'
  ],
  'Vernik ve Cila': ['vernik', 'cila', 'ahşap boyama', 'parke cilası',
    'ahşap cila', 'vernik uygulaması', 'mobilya cilası'
  ],

  // ── Kapı ──
  'İç Kapı Montajı': ['iç kapı takma', 'oda kapısı montajı',
    'kapı montaj',
    'kapı takma'
  ],
  'İç Kapı İmalatı': ['iç kapı', 'oda kapısı', 'kapı yapımı',
    'amerikan kapı',
    'özel ölçü kapı'
  ],
  'Çelik Kapı Montajı': ['çelik kapı takma', 'çelik kapı montaj',
    'güvenlik kapısı',
    'güvenlik kapısı montajı'
  ],
  'Çelik Kapı Tamiri': ['çelik kapı arızası', 'kapı kolu kırıldı',
    'kapı ayarı', 'menteşe', 'kapı kapanmıyor',
    'çelik kapı ayarı', 'kapı kilidi arızası', 'kapı sürtüyor'
  ],
  'Kapı Tamiri': ['kapı tamiri', 'kapı kapanmıyor', 'kapı kolu kırıldı',
    'kapı ayarı',
    'kapı kolu değişimi', 'menteşe ayarı'
  ],

  // ── Cam İşleri ──
  'Cam Balkon': [
    'balkon kapatma', 'balkon kapama', 'teras kapatma', 'giyotin cam',
    'cam balkon', 'katlanır cam', 'balkon camı', 'ısıcamlı balkon',
    'cam balkon yaptırma'
  ],
  'Cam Değişimi': ['cam kırıldı', 'cam takma', 'pencere camı',
    'cam değiştirme',
    'kırık cam değişimi', 'ısıcam değişimi'
  ],
  'Ayna Montajı': ['ayna takma', 'ayna asma', 'banyo aynası',
    'boy aynası montajı'
  ],
  'Duş Camı Montajı': ['duş camı', 'duş bölme', 'cam duş kabini',
    'duş cam bölme', 'duşakabin camı'
  ],

  // ── PVC Pencere ──
  'PVC Pencere Montajı': ['pvc pencere', 'pimapen', 'pencere değişimi',
    'plastik doğrama'],
  'PVC Pencere Tamiri': ['pencere tamiri', 'pimapen tamiri',
    'pencere ayarı', 'fitil değişimi',
    'pencere fitili', 'pencere kapanmıyor'
  ],
  'PVC Kapı': ['pvc kapı', 'balkon kapısı', 'plastik kapı',
    'pvc kapı montajı'
  ],
  'Alüminyum Doğrama': ['alüminyum', 'alüminyum pencere',
    'cephe doğrama',
    'alüminyum cephe', 'giydirme cephe'
  ],
  'Sineklik Montajı': ['sineklik', 'sinek teli', 'pileli sineklik',
    'sineklik takma', 'menteşeli sineklik'
  ],
  'Panjur Sistemleri': ['panjur', 'kepenk', 'otomatik panjur',
    'stor kepenk',
    'panjur montajı', 'kepenk montajı'
  ],

  // ── Demir Doğrama ──
  'Demir Doğrama İşleri': ['demir doğrama', 'demir kapı',
    'demir çerçeve', 'demirci',
    'demirci ustası', 'demir doğrama işi', 'demir kapı yapımı'
  ],
  'Ferforje': ['ferforje', 'süs demiri', 'dövme demir',
    'ferforje korkuluk', 'ferforje kapı', 'dövme demir işi'
  ],
  'Kaynakçı': ['kaynakçı', 'kaynak yapma', 'demir kaynağı',
    'argon kaynak',
    'kaynak işi', 'argon kaynak işi', 'elektrik kaynağı işi'
  ],
  'Korkuluk Montajı': ['korkuluk', 'balkon demiri', 'merdiven korkuluğu',
    'küpeşte',
    'balkon korkuluğu', 'paslanmaz korkuluk'
  ],
  'Çelik Konstrüksiyon': ['çelik yapı', 'hangar', 'çelik çatı',
    'prefabrik',
    'çelik yapı imalatı', 'çelik çatı konstrüksiyon'
  ],

  // ── Anahtar ve Çilingir ──
  'Kapı Açma': [
    'kapı kilitli kaldı', 'anahtar içerde', 'kapı kilitlendi',
    'çilingir', 'acil kapı açma', 'kapı açtırma', 'anahtar kayboldu',
    'kapı açılmıyor', 'çilingir çağır', 'anahtar içeride kaldı'
  ],
  'Kilit Değişimi': ['kilit bozuldu', 'kilit takma', 'barel değişimi',
    'göbek değişimi', 'kilit yenileme',
    'kilit değiştirme', 'kapı kilidi montajı'
  ],
  'Barel Değişimi': ['barel değişimi', 'kilit göbeği',
    'silindir değişimi',
    'barel değiştirme'
  ],
  'Oto Anahtarcı': ['araba anahtarı', 'oto kumanda', 'immobilizer',
    'araç anahtar kopyalama', 'araba kilitlendi',
    'araba anahtarı kopyalama', 'oto anahtar kopyalama',
    'immobilizer anahtar'
  ],

  // ── Bahçe ──
  'Bahçe Düzenleme': ['bahçe düzenleme', 'peyzaj', 'bahçe tasarımı',
    'bahçıvan',
    'peyzaj düzenleme', 'bahçıvan hizmeti'
  ],
  // ⚠ TOHUMLA EKİM ile HAZIR ÇİM ayrı hizmettir.
  'Çim Ekimi': ['çim ekme', 'çim tohumu', 'bahçeye çim ekme',
    'çim ekimi', 'tohumla çim',
    'çim tohumu ekimi'
  ],
  'Çim Serme': ['rulo çim', 'hazır çim', 'çim döşeme', 'çim serme',
    'hazır çim serme', 'rulo çim döşeme'
  ],
  'Ağaç Budama': ['ağaç budama', 'dal kesme', 'ağaç kesimi',
    'çit budama',
    'dal kesimi'
  ],
  'Otomatik Sulama Sistemi': ['sulama sistemi', 'damlama sulama',
    'fıskiye', 'otomatik sulama',
    'damlama sulama sistemi', 'sprinkler montajı',
    'bahçe sulama sistemi'
  ],
  'Bahçe Bakımı': ['bahçe bakım', 'çim biçme', 'yabani ot',
    'bahçe temizliği',
    'ot temizliği'
  ],

  // ── Havuz ──
  'Havuz Yapımı': ['havuz yapımı', 'havuz inşaatı', 'yüzme havuzu',
    'betonarme havuz', 'prefabrik havuz'
  ],
  'Havuz Bakımı': ['havuz bakım', 'havuz temizliği',
    'havuz suyu bulanık',
    'havuz süpürme', 'filtre bakımı',
    'havuz filtresi', 'filtre değişimi havuz', 'havuz pompası bakımı'
  ],
  'Havuz Kimyasal Dengeleme': ['havuz kimyasalı', 'klor dengesi',
    'ph ayarı', 'havuz suyu yeşil',
    'havuz kimyasalı uygulaması', 'klor dengeleme'
  ],
  'Havuz Tamiri': ['havuz tamiri', 'havuz kaçağı', 'havuz pompası',
    'havuz kaçağı onarımı', 'havuz izolasyonu',
    'havuz pompası arızası'
  ],

  // ── Nakliyat ──
  'Evden Eve Nakliyat': ['ev taşıma', 'nakliyeci', 'taşınma',
    'evden eve', 'eşya taşıma',
    'taşınma yardımı', 'nakliye firması', 'sigortalı nakliyat'
  ],
  'Şehirler Arası Nakliyat': ['şehirler arası', 'uzak mesafe nakliyat',
    'il dışı taşıma',
    'şehirlerarası nakliyat'
  ],
  'Ofis Taşıma': ['ofis taşıma', 'iş yeri taşıma', 'büro nakliyat',
    'işyeri taşıma', 'büro taşıma'
  ],
  'Parça Eşya Taşıma': ['parça eşya', 'tek parça taşıma', 'küçük taşıma',
    'tek eşya taşıma', 'koltuk taşıma', 'buzdolabı taşıma'
  ],
  'Asansörlü Nakliyat': ['asansörlü nakliyat', 'mobil asansör',
    'dış cephe asansörü',
    'eşya asansörü', 'mobilya asansörü', 'dıştan taşıma'
  ],
  'Eşya Depolama': ['eşya depolama', 'depo kiralama', 'geçici depolama',
    'kiralık depo'
  ],
  'Piyano Taşıma': ['piyano taşıma', 'kasa taşıma', 'ağır yük taşıma',
    'piyano nakliyesi'
  ],

  // ── Kurye ve Taşıma ──
  'Moto Kurye': ['motorlu kurye', 'acil kurye', 'moto kurye',
    'aynı gün teslim',
    'aynı gün kurye'
  ],
  'Paket Taşıma': ['paket gönderimi', 'kargo taşıma', 'koli taşıma'],
  'Küçük Nakliye': ['küçük taşıma', 'tek parça taşıma', 'kamyonet',
    'minivan taşıma', 'küçük eşya taşıma'
  ],

  // ── Asansör ──
  'Asansör Bakımı': ['asansör bakım', 'aylık bakım', 'asansör kontrolü',
    'asansör periyodik bakım', 'asansör sözleşmesi'
  ],
  'Asansör Tamiri': ['asansör arızası', 'asansör çalışmıyor',
    'asansör bozuldu', 'asansörde mahsur kalma',
    'asansör kaldı', 'asansör kapısı arızası'
  ],
  'Asansör Montajı': ['asansör yapımı', 'asansör kurulumu',
    'yeni asansör'],

  // ── Mühendislik ──
  'Statik Proje': ['statik hesap', 'betonarme proje', 'taşıyıcı sistem',
    'güçlendirme projesi'],
  'Mimari Proje': ['mimari çizim', 'ruhsat projesi', 'plan çizimi',
    'mimar',
    'tadilat projesi'
  ],
  'Elektrik Projesi': ['elektrik proje', 'elektrik çizimi',
    'elektrik onay projesi',
    'elektrik proje çizimi', 'elektrik ruhsat projesi'
  ],
  'Mekanik Tesisat Projesi': ['mekanik proje', 'tesisat projesi',
    'sıhhi tesisat projesi'],
  'Zemin Etüdü': ['zemin etüt', 'sondaj', 'jeolojik rapor',
    'zemin analizi',
    'zemin etüt raporu', 'zemin sondajı'
  ],
  'Enerji Kimlik Belgesi': ['ekb', 'enerji kimlik', 'enerji belgesi',
    'enerji sınıfı',
    'enerji kimlik belgesi', 'ekb belgesi'
  ],

  // ── Oto Yardım ──
  'Oto Çekici': ['çekici', 'oto çekici', 'araba çekici', 'araç çekme',
    'oto çekici çağır', 'kurtarıcı çağır', 'oto kurtarma'
  ],
  'Yol Yardım': [
    'yol yardım', 'araç bozuldu', 'araç yolda kaldı', 'acil yardım',
    'lastik değişimi', 'araçta benzin bitti',
    'yolda lastik değişimi', 'stepne takma'
  ],
  'Akü Takviye': ['akü takviye', 'akü bitti', 'araba çalışmıyor',
    'takviye',
    'akü takviyesi', 'araç çalışmıyor', 'akü değişimi'
  ],

  // ── Oto Servis ──
  'Oto Elektrik': ['oto elektrik', 'araç elektrik arızası',
    'oto elektrikçi',
    'marş sorunu'
  ],
  'Oto Klima': ['oto klima', 'araç klima bakımı',
    'klima gaz dolumu araba',
    'araç kliması', 'klima gazı dolumu', 'oto klima bakımı'
  ],
  'Fren Balata Değişimi': ['balata değişimi', 'fren balatası',
    'fren bakımı', 'fren ses yapıyor',
    'fren tamiri', 'disk değişimi'
  ],
  'Periyodik Araç Bakımı': ['araç bakımı', 'periyodik bakım',
    'yağ değişimi', 'filtre değişimi'],

  // ── Oto Temizlik ──
  'Araç Detaylı Temizlik': ['araç detaylı temizlik', 'oto detailing',
    'iç dış temizlik',
    'araç iç dış temizlik', 'pasta cila uygulaması'
  ],
  'Araç Koltuk Yıkama': ['araç koltuk yıkama', 'oto koltuk temizliği',
    'araç döşeme temizliği',
    'oto koltuk yıkama', 'araç iç temizliği'
  ],
  'Oto Yıkama': ['oto yıkama', 'araba yıkama', 'araç yıkama',
    'yerinde oto yıkama', 'buharlı yıkama'
  ],

  // ── Özel Ders ──
  'Matematik Özel Ders': ['matematik özel ders', 'matematik öğretmeni',
    'matematik dersi',
    'lgs matematik', 'tyt matematik'
  ],
  'Fizik Özel Ders': ['fizik özel ders', 'fizik öğretmeni',
    'fizik dersi',
    'ayt fizik'
  ],
  'Fen Bilimleri Özel Ders': ['fen bilimleri', 'fen dersi',
    'fen özel ders',
    'fen bilgisi öğretmeni'
  ],
  'İlkokul Özel Ders': ['ilkokul özel ders', 'ilkokul öğretmeni',
    'ödev desteği',
    'ilkokul dersi', 'okuma yazma desteği'
  ],

  // ── Yabancı Dil ──
  'İngilizce Özel Ders': ['ingilizce özel ders', 'ingilizce öğretmeni',
    'ingilizce dersi',
    'ingilizce kursu', 'konuşma pratiği'
  ],
  'Almanca Özel Ders': ['almanca özel ders', 'almanca öğretmeni',
    'almanca dersi',
    'almanca kursu'
  ],
  'Fransızca Özel Ders': ['fransızca özel ders', 'fransızca öğretmeni',
    'fransızca dersi'],
  'Online İngilizce Dersi': ['online ingilizce', 'uzaktan ingilizce',
    'internetten ingilizce',
    'online ders', 'skype ders'
  ],

  // ── Sürücü Eğitimi ──
  'Direksiyon Dersi': ['direksiyon dersi', 'sürüş dersi',
    'özel direksiyon dersi',
    'direksiyon eğitimi', 'direksiyon usta öğretici',
    'araç kullanma dersi',
    'direksiyon takviye dersi', 'ehliyet sonrası direksiyon'
  ],
  'İleri Sürüş Eğitimi': ['ileri sürüş', 'güvenli sürüş eğitimi',
    'defansif sürüş',
    'ileri sürüş teknikleri', 'güvenli sürüş'
  ],

  // ── Spor ──
  'Yüzme Dersi': ['yüzme dersi', 'yüzme öğretmeni', 'yüzme kursu',
    'çocuk yüzme dersi'
  ],
  'Fitness Özel Ders': ['fitness', 'personal trainer', 'özel antrenör',
    'spor hocası',
    'kişisel antrenör'
  ],
  'Pilates Dersi': ['pilates', 'pilates dersi', 'reformer pilates',
    'pilates eğitmeni'
  ],
  'Tenis Dersi': ['tenis dersi', 'tenis hocası', 'tenis kursu',
    'tenis antrenörü'
  ],

  // ── Müzik ──
  'Piyano Dersi': ['piyano dersi', 'piyano öğretmeni', 'piyano kursu'],
  'Gitar Dersi': ['gitar dersi', 'gitar öğretmeni', 'gitar kursu',
    'bas gitar dersi'
  ],
  'Keman Dersi': ['keman dersi', 'keman öğretmeni'],
  'Şan Dersi': ['şan dersi', 'ses eğitimi', 'vokal dersi',
    'şan hocası'
  ],

  // ── Yazılım ──
  'Web Sitesi Yapımı': ['web sitesi', 'site yaptırma', 'internet sitesi',
    'web tasarım',
    'kurumsal web sitesi'
  ],
  'Mobil Uygulama Geliştirme': ['mobil uygulama', 'app yaptırma',
    'android uygulama', 'ios uygulama',
    'uygulama yaptırma'
  ],
  'E-Ticaret Sitesi Yapımı': ['e-ticaret sitesi', 'online mağaza',
    'satış sitesi',
    'online satış sitesi', 'e-ticaret kurulumu', 'sanal mağaza'
  ],
  'WordPress Site Kurulumu': ['wordpress', 'wordpress kurulumu',
    'wp site',
    'wp tema kurulumu'
  ],

  // ── Tasarım ──
  'Logo Tasarımı': ['logo tasarımı', 'logo yaptırma', 'marka logosu',
    'marka logosu tasarımı'
  ],
  'Grafik Tasarım': ['grafik tasarım', 'afiş tasarımı',
    'broşür tasarımı', 'tasarımcı',
    'sosyal medya görseli'
  ],
  'Kurumsal Kimlik Tasarımı': ['kurumsal kimlik', 'marka kimliği',
    'kartvizit tasarımı',
    'antetli kağıt tasarımı', 'kurumsal kimlik tasarımı'
  ],

  // ── Dijital Pazarlama ──
  'Sosyal Medya Yönetimi': ['sosyal medya yönetimi',
    'instagram yönetimi', 'sosyal medya uzmanı',
    'sosyal medya danışmanı'
  ],
  'Google Reklam Yönetimi': ['google reklam', 'google ads',
    'reklam yönetimi',
    'google ads yönetimi', 'adwords yönetimi'
  ],
  'SEO Hizmeti': ['seo', 'arama motoru optimizasyonu', 'google sıralama',
    'seo danışmanı', 'google sıralama desteği'
  ],

  // ── Fotoğraf ──
  'Ürün Fotoğraf Çekimi': ['ürün fotoğrafı', 'ürün çekimi',
    'e-ticaret fotoğrafı',
    'katalog çekimi'
  ],
  'Kurumsal Fotoğraf Çekimi': ['kurumsal fotoğraf', 'firma çekimi',
    'profesyonel fotoğrafçı',
    'kurumsal çekim', 'mekan çekimi', 'portre çekimi'
  ],

  // ── Organizasyon ──
  'Doğum Günü Organizasyonu': ['doğum günü organizasyonu',
    'parti organizasyonu', 'doğum günü süsleme',
    'çocuk partisi', 'balon süsleme'
  ],
  'Düğün Organizasyonu': ['düğün organizasyonu', 'düğün planlama',
    'organizasyon firması',
    'nişan organizasyonu', 'kına organizasyonu'
  ],

  // ── Evcil Hayvan ──
  'Köpek Gezdirme': ['köpek gezdirme', 'köpek yürüyüşü', 'pet gezdirme',
    'evcil hayvan gezdirme'
  ],
  'Evcil Hayvan Bakımı': ['evcil hayvan bakımı', 'pet bakım',
    'kedi bakımı', 'köpek bakımı',
    'evde hayvan bakıcısı', 'pet oteli hizmeti'
  ],

  // ── Güzellik ──
  'Makyaj': ['makyaj', 'gelin makyajı', 'profesyonel makyaj', 'makyöz',
    'makyöz hizmeti'
  ],
  'Manikür Pedikür': ['manikür', 'pedikür', 'tırnak bakımı', 'oje',
    'manikür yaptırma', 'pedikür yaptırma', 'protez tırnak',
    'kalıcı oje'
  ],
  'Saç Tasarımı': ['saç tasarımı', 'kuaför', 'saç kesimi', 'saç boyama',
    'kuaför hizmeti', 'gelin saçı', 'evde kuaför'
  ],

  // ═══════════════════════════════════════════════════════════
  // ⚠ KATALOG GENİŞLETMESİ (14 Ağu) — 255 → 459 hizmet
  //
  // Onaylı öneri listesindeki maddelerden AYRI BİR İŞ olanlar
  // gerçek hizmet kaydına çevrildi. Meslek adları ("boyacı"),
  // şikâyet cümleleri ("sigorta attı") ve eş anlamlılar TERİM
  // olarak kaldı — hizmet yapılmadı.
  //
  // ⚠ Her yeni hizmetin EN AZ İKİ terimi olmalı (test kilidi).
  // ═══════════════════════════════════════════════════════════

  // ── Temizlik Hizmetleri — yeni hizmetler ──
  'Cam Silme': [
    'cam silme', 'dış cephe cam temizliği', 'vitrin temizliği',
    'cephe cam silme'
  ],
  'Ütü Hizmeti': [
    'ütü yapma', 'ütücü', 'çamaşır ütüleme', 'evde ütü'
  ],
  'Merdiven Temizliği': [
    'apartman temizliği', 'bina merdiven temizliği', 'site temizliği'
  ],
  'Buhar Makinesiyle Temizlik': [
    'buharlı temizlik', 'buhar makinesi', 'dezenfekte temizlik'
  ],

  // ── Halı Yıkama — yeni hizmetler ──
  'Kilim Yıkama': [
    'kilim yıkatma', 'kilim temizleme', 'el dokuma kilim'
  ],
  'Yolluk Yıkama': [
    'yolluk yıkatma', 'koridor halısı yıkama'
  ],
  'Halı Leke Çıkarma': [
    'halı leke temizliği', 'halıda leke', 'inatçı leke halı'
  ],
  'Yerinde Halı Yıkama': [
    'evde halı yıkama', 'yerinde halı temizliği',
    'sökmeden halı yıkama',
    'halı temizliği', 'halı yıkatma', 'kilim yıkama',
    'halı şampuanlama', 'halı temizleme', 'makine halısı yıkama',
    'yolluk yıkama'
  ],

  // ── Koltuk ve Döşeme Yıkama — yeni hizmetler ──
  'Sandalye Yıkama': [
    'sandalye temizliği', 'yemek sandalyesi yıkama'
  ],
  'Halıfleks Yıkama': [
    'halıfleks temizliği', 'duvardan duvara halı yıkama'
  ],
  'Araç Döşeme Yıkama': [
    'oto döşeme yıkama', 'araç koltuk temizliği'
  ],

  // ── İlaçlama ve Haşere Kontrolü — yeni hizmetler ──
  'Karınca İlaçlama': [
    'karınca ilaçlama', 'karınca mücadelesi'
  ],
  'Güve İlaçlama': [
    'güve ilaçlama', 'güve mücadelesi', 'dolap güvesi'
  ],
  'Sinek ve Sivrisinek İlaçlama': [
    'sinek ilaçlama', 'sivrisinek ilaçlama', 'bahçe sinek ilaçlama'
  ],
  'Pire İlaçlama': [
    'pire ilaçlama', 'pire mücadelesi'
  ],
  'İşyeri İlaçlama': [
    'işyeri ilaçlama', 'restoran ilaçlama', 'depo ilaçlama'
  ],

  // ── Su Tesisatı — yeni hizmetler ──
  'Petek Borusu Tesisatı': [
    'petek borusu çekimi', 'kalorifer borusu döşeme',
    'kalorifer', 'radyatör', 'petek montajı', 'petek değişimi',
    'yerden ısıtma', 'kalorifer borusu', 'ısıtma tesisatı',
    'kalorifer tesisatı', 'petek borusu', 'radyatör tesisatı'
  ],
  'Duş Bataryası Montajı': [
    'duş bataryası değişimi', 'duş musluğu montajı'
  ],
  'Hidrofor Montajı': [
    'hidrofor kurulumu', 'su basıncı hidrofor', 'hidrofor tamiri'
  ],
  'Pissu Tesisatı': [
    'pis su borusu', 'atık su tesisatı', 'pimaş boru değişimi'
  ],

  // ── Doğalgaz — yeni hizmetler ──
  'Doğalgaz Ocak Bağlantısı': [
    'doğalgaz ocak bağlama', 'ocak bağlama',
    'ankastre ocak bağlantısı', 'set üstü ocak bağlantısı',
    'ocak hortumu', 'fleksi hortum'
  ],
  'Doğalgaz Ocak Dönüşümü': [
    'lpg doğalgaz dönüşümü', 'ocak dönüşümü', 'meme değişimi',
    'enjektör değişimi', 'tüpten doğalgaza geçiş'
  ],
  'Doğalgaz Sobası Montajı': [
    'doğalgaz sobası', 'doğalgaz sobası montajı', 'sobalı tesisat'
  ],

  // ── Kombi Montaj — yeni hizmetler ──
  'Kombi Yeri Değişimi': [
    'kombi yeri değiştirme', 'kombi taşıma', 'kombi sökme takma'
  ],
  'Kombi Baca Montajı': [
    'kombi bacası', 'hermetik baca montajı', 'baca çıkışı kombi'
  ],

  // ── Kombi Servis — yeni hizmetler ──
  'Kombi Arıza Tespiti': [
    'kombi arıza tespiti', 'kombi hata kodu', 'kombi kontrol'
  ],

  // ── Isıtma Sistemleri — yeni hizmetler ──
  'Radyatör Vana Değişimi': [
    'petek vanası değişimi', 'termostatik vana', 'radyatör vanası'
  ],
  'Kalorifer Kazanı Bakımı': [
    'kazan bakımı', 'kalorifer kazanı temizliği', 'katı yakıtlı kazan'
  ],
  'Oda Termostatı Montajı': [
    'oda termostatı', 'akıllı termostat montajı', 'termostat kurulumu'
  ],
  'Boyler Montajı': [
    'boyler kurulumu', 'termosifon montajı', 'sıcak su deposu'
  ],

  // ── Elektrik — yeni hizmetler ──
  'Kaçak Akım Rölesi Montajı': [
    'kaçak akım rölesi', 'hayat kurtaran montajı', 'rcd montajı'
  ],
  'Spot Aydınlatma Montajı': [
    'spot montajı', 'led spot takma', 'tavan spotu'
  ],
  'Elektrik Kablo Çekimi': [
    'kablo çekimi', 'sıva altı tesisat', 'yeni hat çekimi'
  ],
  'Jeneratör Montajı': [
    'jeneratör kurulumu', 'güç kaynağı montajı'
  ],
  'Elektrikli Panjur Montajı': [
    'motorlu panjur elektrik', 'panjur motoru bağlantısı'
  ],

  // ── Güvenlik Sistemleri — yeni hizmetler ──
  'Kamera Bakım ve Onarımı': [
    'kamera tamiri', 'kamera arızası', 'kayıt cihazı arızası'
  ],
  'Parmak İzli Geçiş Sistemi': [
    'parmak izi okuyucu', 'personel geçiş sistemi', 'kartlı geçiş'
  ],
  'Bariyer ve Otopark Sistemi': [
    'otopark bariyeri', 'kollu bariyer montajı'
  ],

  // ── Klima Montaj ve Servis — yeni hizmetler ──
  'Klima Gaz Dolumu': [
    'klima gaz dolumu', 'klima gazı bitti', 'soğutucu gaz dolumu'
  ],
  'Klima Sökme Takma': [
    'klima taşıma', 'klima yeri değişimi', 'klima sökümü'
  ],
  'Kanallı Klima Montajı': [
    'kanallı klima', 'gizli tavan klima montajı'
  ],
  'Salon Tipi Klima Montajı': [
    'salon tipi klima', 'dikey klima montajı'
  ],

  // ── Beyaz Eşya Servisi — yeni hizmetler ──
  'Ankastre Cihaz Montajı': [
    'ankastre montajı', 'ankastre fırın montajı',
    'ankastre ocak montajı', 'davlumbaz montajı'
  ],
  'Davlumbaz Tamiri': [
    'davlumbaz tamiri', 'davlumbaz çekmiyor', 'aspiratör motoru'
  ],
  'Su Sebili Tamiri': [
    'su sebili tamiri', 'sebil bakımı'
  ],
  'Beyaz Eşya Nakli': [
    'beyaz eşya taşıma', 'buzdolabı taşıma'
  ],

  // ── Elektronik Cihaz Tamiri — yeni hizmetler ──
  'Telefon Ekran Değişimi': [
    'telefon ekran değişimi', 'kırık ekran değişimi',
    'cam değişimi telefon'
  ],
  'Telefon Batarya Değişimi': [
    'telefon bataryası', 'pil değişimi telefon', 'şarj tutmuyor'
  ],
  'Bilgisayar Format ve Kurulum': [
    'format atma', 'windows kurulumu', 'işletim sistemi kurulumu'
  ],
  'Veri Kurtarma': [
    'veri kurtarma', 'silinen dosya kurtarma', 'disk kurtarma'
  ],
  'Projeksiyon Tamiri': [
    'projeksiyon tamiri', 'projektör arızası'
  ],

  // ⚠ Çatısı TAMİR — bkz. category_tree.dart'taki not.
  'Saat Tamiri': [
    'saat tamiri', 'saatçi', 'kol saati tamiri', 'saat pili değişimi',
    'duvar saati tamiri', 'saat kayışı değişimi'
  ],


  // ── Uydu ve Anten Sistemleri — yeni hizmetler ──
  'Uydu Alıcı Kurulumu': [
    'uydu alıcısı kurulumu', 'receiver ayarı', 'kanal yükleme'
  ],
  'Karasal Anten Montajı': [
    'karasal anten', 'çatı anteni montajı'
  ],
  'Anten Kablo Çekimi': [
    'anten kablosu çekimi', 'tv kablo çekimi'
  ],

  // ── İnternet ve Ağ Kurulumu — yeni hizmetler ──
  'Fiber İnternet Kurulumu': [
    'fiber kurulumu', 'fiber modem kurulumu', 'fiber hat çekimi'
  ],
  'Kamera Ağ Kurulumu': [
    'ip kamera ağı', 'nvr ağ ayarı'
  ],
  'Sunucu ve NAS Kurulumu': [
    'nas kurulumu', 'yedekleme sunucusu', 'ev sunucusu'
  ],

  // ── Boya ve Badana — yeni hizmetler ──
  'Tavan Boyama': [
    'tavan boyama', 'tavan badanası'
  ],
  'Silinebilir Boya Uygulaması': [
    'silinebilir boya', 'plastik boya uygulaması'
  ],
  'Mobilya Boyama': [
    'mobilya boyama', 'dolap boyama', 'ahşap boyama'
  ],
  'Cephe Boya Onarımı': [
    'cephe boya tamiri', 'dış cephe rötuş'
  ],

  // ── Alçı ve Sıva İşleri — yeni hizmetler ──
  'Asma Tavan Yapımı': [
    'asma tavan', 'alçıpan tavan', 'gizli ışık bandı uygulaması'
  ],
  'Saten Alçı Uygulaması': [
    'saten alçı', 'duvar düzeltme', 'perdah'
  ],
  'Sıva Tamiri': [
    'sıva tamiri', 'duvar çatlağı onarımı', 'dökülen sıva'
  ],

  // ── Duvar Kağıdı ve Dekorasyon — yeni hizmetler ──
  'Duvar Kağıdı Sökme': [
    'duvar kağıdı sökme', 'eski kağıt sökümü'
  ],
  'Akustik Panel Montajı': [
    'akustik panel', 'ses paneli montajı'
  ],

  // ── Tadilat ve Yenileme — yeni hizmetler ──
  'Kiralık Daire Tadilatı': [
    'kiralık daire yenileme', 'kiraya vermeden önce tadilat'
  ],
  'Villa Tadilatı': [
    'villa yenileme', 'müstakil ev tadilatı'
  ],
  'Bina Yenileme': [
    'apartman yenileme', 'bina cephe yenileme'
  ],

  // ── Banyo Tadilat ve Montaj — yeni hizmetler ──
  'Duş Teknesi Montajı': [
    'duş teknesi montajı', 'duş teknesi değişimi'
  ],
  'Küvet Montajı': [
    'küvet montajı', 'küvet değişimi', 'küvet sökümü'
  ],
  'Klozet Değişimi': [
    'klozet değişimi', 'tuvalet taşı değişimi', 'asma klozet montajı'
  ],
  'Banyo Fayans Yenileme': [
    'banyo fayans değişimi', 'banyo seramik yenileme'
  ],

  // ── Mutfak Tadilat ve Dolap — yeni hizmetler ──
  'Mutfak Dolabı Montajı': [
    'mutfak dolabı montajı', 'hazır mutfak montajı',
    'modüler mutfak kurulumu'
  ],
  'Mutfak Dolabı Kapak Değişimi': [
    'dolap kapağı değişimi', 'mutfak kapak yenileme'
  ],
  'Granit Tezgah Montajı': [
    'granit tezgah', 'mermer tezgah montajı', 'tezgah değişimi'
  ],
  'Evye Montajı': [
    'evye montajı', 'eviye değişimi', 'mutfak lavabosu'
  ],

  // ── İnşaat ve Kaba Yapı — yeni hizmetler ──
  'Moloz Taşıma': [
    'moloz taşıma', 'hafriyat taşıma', 'enkaz kaldırma'
  ],
  'Şap Atma': [
    'şap atma', 'tesviye şapı', 'zemin şapı',
    'beton dökme', 'zemin betonu', 'tesviye şap', 'beton dökümü',
    'tesviye şapı uygulaması'
  ],
  'Kolon Güçlendirme': [
    'güçlendirme işi', 'karbon takviye', 'kolon takviyesi'
  ],

  // ── Fayans ve Seramik Döşeme — yeni hizmetler ──
  'Derz Yenileme': [
    'derz yenileme', 'derz dolgu', 'derz temizliği',
    'derz', 'fuga', 'silikon yenileme', 'ara dolgu', 'silikon çekme'
  ],
  'Silikon Uygulaması': [
    'silikon çekme', 'banyo silikonu', 'küvet silikonu'
  ],
  'Mermer Eşik Montajı': [
    'mermer eşik', 'denizlik montajı', 'pencere denizliği'
  ],
  'Dış Cephe Seramik': [
    'dış cephe seramik', 'teras seramiği'
  ],

  // ── Zemin Kaplama — yeni hizmetler ──
  'Parke Zımpara ve Cila': [
    'parke zımpara', 'parke cila', 'parke yenileme'
  ],
  'Süpürgelik Montajı': [
    'süpürgelik montajı', 'parke süpürgeliği'
  ],
  'Vinil Zemin Uygulaması': [
    'vinil zemin', 'lvt zemin', 'spor zemini'
  ],
  'Zemin Şap Düzeltme': [
    'zemin düzeltme', 'self levelling', 'zemin tesviye'
  ],

  // ── Yalıtım ve Mantolama — yeni hizmetler ──
  'Balkon Su Yalıtımı': [
    'balkon yalıtımı', 'balkon su izolasyonu'
  ],
  'Çatı Su Yalıtımı': [
    'çatı yalıtımı', 'membran uygulaması', 'teras izolasyon'
  ],
  'Rutubet ve Küf Onarımı': [
    'rutubet giderme', 'küf temizliği duvar', 'nem yalıtımı'
  ],
  'Pencere Ses Yalıtımı': [
    'ses yalıtımı pencere', 'gürültü yalıtımı'
  ],

  // ── Çatı Yapım ve Onarım — yeni hizmetler ──
  'Kiremit Aktarma': [
    'kiremit aktarma', 'çatı aktarımı'
  ],
  'Oluk Temizliği': [
    'oluk temizliği', 'yağmur oluğu temizleme'
  ],
  'Çatı Kaçak Onarımı': [
    'çatı akıtıyor', 'çatı su kaçağı', 'çatı onarımı'
  ],
  'Çelik Çatı İmalatı': [
    'çelik çatı', 'sandviç panel çatı'
  ],

  // ── Mobilya Yapım ve Montaj — yeni hizmetler ──
  'Hazır Mobilya Kurulumu': [
    'ikea montajı', 'kutulu mobilya kurulumu', 'mobilya toplama'
  ],
  'Yatak Odası Takımı Montajı': [
    'yatak odası montajı', 'baza montajı'
  ],
  'Raf ve Kitaplık Montajı': [
    'raf montajı', 'kitaplık montajı', 'duvar rafı takma'
  ],
  'Mobilya Sökme ve Taşıma': [
    'mobilya sökme', 'mobilya taşıma montaj'
  ],

  // ── Marangozluk ve Ahşap İşleri — yeni hizmetler ──
  'Ahşap Deck Uygulaması': [
    'deck döşeme', 'ahşap teras', 'bahçe deck'
  ],
  'Ahşap Kapı Onarımı': [
    'ahşap kapı tamiri', 'kapı rötuş'
  ],
  'Ölçüye Özel Dolap': [
    'ölçüye göre dolap', 'gömme dolap yapımı', 'özel dolap imalatı'
  ],

  // ── Kapı Montaj ve Tamir — yeni hizmetler ──
  'Kapı Kolu Değişimi': [
    'kapı kolu değişimi', 'kol takma'
  ],
  'Kapı Menteşe Ayarı': [
    'menteşe ayarı', 'kapı sürtüyor', 'kapı kapanmıyor'
  ],
  'Sürgülü Kapı Montajı': [
    'sürme kapı montajı', 'sürgülü kapı sistemi'
  ],
  'Kapı Otomatiği Montajı': [
    'kapı otomatiği', 'hidrolik kapı kolu'
  ],

  // ── Cam Balkon — yeni hizmetler ──
  'Isıcam Değişimi': [
    'ısıcam değişimi', 'çift cam değişimi', 'buğulanan cam'
  ],
  'Kırık Cam Değişimi': [
    'kırık cam değişimi', 'pencere camı değişimi'
  ],
  'Giyotin Cam Montajı': [
    'giyotin cam', 'sürme cam balkon'
  ],

  // ── PVC ve Alüminyum Doğrama — yeni hizmetler ──
  'Pencere Ayarı ve Fitil Değişimi': [
    'pencere ayarı', 'fitil değişimi', 'pencere kapanmıyor'
  ],
  'Pileli Sineklik Montajı': [
    'pileli sineklik', 'menteşeli sineklik', 'sineklik takma'
  ],
  'Otomatik Panjur Montajı': [
    'otomatik panjur', 'motorlu panjur', 'panjur montajı'
  ],
  'Alüminyum Cephe Kaplama': [
    'alüminyum cephe', 'kompozit panel cephe', 'giydirme cephe'
  ],

  // ── Demir Doğrama ve Kaynak — yeni hizmetler ──
  'Balkon Korkuluğu Montajı': [
    'balkon korkuluğu', 'korkuluk montajı'
  ],
  'Merdiven Korkuluğu': [
    'merdiven korkuluğu', 'paslanmaz korkuluk'
  ],
  'Demir Kapı İmalatı': [
    'demir kapı yapımı', 'bahçe kapısı imalatı'
  ],
  'Yerinde Kaynak İşi': [
    'argon kaynak işi', 'yerinde kaynak', 'elektrik kaynağı'
  ],

  // ── Çilingir ve Kilit — yeni hizmetler ──
  'Çelik Kapı Kilidi Değişimi': [
    'çelik kapı kilidi', 'çoklu kilit değişimi'
  ],
  'Kasa Açma': [
    'kasa açma', 'para kasası açtırma'
  ],
  'Anahtar Kopyalama': [
    'anahtar kopyalama', 'yedek anahtar'
  ],

  // ── Bahçe ve Peyzaj — yeni hizmetler ──
  'Çim Biçme': [
    'çim biçme', 'çim kesimi', 'bahçe biçme'
  ],
  'Ağaç Kesimi': [
    'ağaç kesimi', 'tehlikeli ağaç kesimi', 'kütük sökümü'
  ],
  'Otomatik Sulama Montajı': [
    'damlama sulama sistemi', 'sprinkler montajı',
    'bahçe sulama sistemi'
  ],
  'Bahçe Duvarı ve Çit': [
    'bahçe çiti', 'tel çit montajı', 'bahçe duvarı'
  ],
  'Sera Kurulumu': [
    'sera kurulumu', 'bahçe serası'
  ],

  // ── Havuz Yapım ve Bakım — yeni hizmetler ──
  'Havuz Su Kaçağı Onarımı': [
    'havuz kaçağı onarımı', 'havuz su kaçağı'
  ],
  'Havuz Kışa Hazırlık': [
    'havuz kapatma', 'havuz kışlık bakım'
  ],

  // ── Nakliyat ve Taşımacılık — yeni hizmetler ──
  'Asansörlü Taşıma': [
    'eşya asansörü', 'mobilya asansörü', 'dıştan taşıma'
  ],
  'Sigortalı Nakliyat': [
    'sigortalı nakliyat', 'sigortalı taşıma'
  ],

  // ── Kurye ve Küçük Taşıma — yeni hizmetler ──
  'Aynı Gün Kurye': [
    'aynı gün teslim', 'acil kurye', 'hızlı kurye'
  ],

  // ── Asansör Montaj ve Bakım — yeni hizmetler ──
  'Asansör Kabin Yenileme': [
    'kabin yenileme', 'asansör iç dekorasyon'
  ],
  'Asansör Kapı Tamiri': [
    'asansör kapısı arızası', 'kabin kapısı tamiri'
  ],

  // ── Mühendislik ve Proje — yeni hizmetler ──
  'Güçlendirme Projesi': [
    'güçlendirme projesi', 'deprem güçlendirme',
    'karbon takviye projesi'
  ],
  'Deprem Performans Analizi': [
    'deprem raporu', 'performans analizi', 'bina risk raporu'
  ],
  'Ruhsat Projesi': [
    'ruhsat projesi', 'mimari ruhsat', 'proje onayı belediye'
  ],
  'Röleve Projesi': [
    'röleve', 'mevcut yapı ölçümü'
  ],

  // ── Oto Çekici ve Yol Yardım — yeni hizmetler ──
  'Kilitli Araç Açma': [
    'araç kapısı açma', 'arabada anahtar kaldı'
  ],

  // ── Oto Servis ve Bakım — yeni hizmetler ──
  'Motor Yağı Değişimi': [
    'yağ değişimi', 'motor yağı', 'filtre değişimi'
  ],
  'Akü Değişimi': [
    'akü değişimi', 'akü satış montaj'
  ],
  'Araç Klima Gaz Dolumu': [
    'oto klima gazı', 'araç klima bakımı'
  ],
  'Fren Bakımı': [
    'balata değişimi', 'fren tamiri', 'disk değişimi'
  ],

  // ── Araç Temizlik ve Detaylı Bakım — yeni hizmetler ──
  'Pasta ve Cila': [
    'pasta cila uygulaması', 'araç cilası', 'boya koruma'
  ],
  'Motor Yıkama': [
    'motor temizliği', 'motor bölümü yıkama'
  ],
  'Yerinde Oto Yıkama': [
    'yerinde oto yıkama', 'adrese oto yıkama', 'buharlı yıkama'
  ],

  // ── Özel Ders — yeni hizmetler ──
  'Kimya Özel Ders': [
    'kimya öğretmeni', 'kimya dersi', 'ayt kimya'
  ],
  'Biyoloji Özel Ders': [
    'biyoloji öğretmeni', 'biyoloji dersi'
  ],
  'Türkçe ve Edebiyat Özel Ders': [
    'türkçe dersi', 'edebiyat öğretmeni', 'paragraf dersi'
  ],
  'Geometri Özel Ders': [
    'geometri dersi', 'geometri öğretmeni'
  ],
  'LGS Hazırlık': [
    'lgs hazırlık', 'lgs kursu', 'ortaokul sınav hazırlık'
  ],
  'YKS Hazırlık': [
    'yks hazırlık', 'tyt ayt hazırlık', 'üniversite sınavı hazırlık'
  ],

  // ── Yabancı Dil Eğitimi — yeni hizmetler ──
  'İspanyolca Özel Ders': [
    'ispanyolca öğretmeni', 'ispanyolca dersi'
  ],
  'Rusça Özel Ders': [
    'rusça öğretmeni', 'rusça dersi'
  ],
  'IELTS ve TOEFL Hazırlık': [
    'ielts hazırlık', 'toefl hazırlık', 'yds hazırlık'
  ],
  'İş İngilizcesi': [
    'iş ingilizcesi', 'business english', 'mülakat ingilizcesi'
  ],

  // ── Sürücü Eğitimi — yeni hizmetler ──
  'Park Etme Eğitimi': [
    'park etme dersi', 'paralel park eğitimi'
  ],

  // ── Spor ve Kişisel Antrenör — yeni hizmetler ──
  'Evde Fitness Antrenörü': [
    'evde spor hocası', 'evde personal trainer'
  ],
  'Yoga Dersi': [
    'yoga eğitmeni', 'yoga dersi'
  ],
  'Beslenme ve Antrenman Programı': [
    'antrenman programı', 'spor programı hazırlama'
  ],

  // ── Müzik Dersleri — yeni hizmetler ──
  'Bağlama Dersi': [
    'bağlama öğretmeni', 'saz dersi'
  ],
  'Davul ve Perküsyon Dersi': [
    'davul dersi', 'perküsyon eğitmeni'
  ],
  'Ud ve Kanun Dersi': [
    'ud dersi', 'kanun dersi', 'türk müziği dersi'
  ],
  'Flüt Dersi': [
    'flüt dersi', 'flüt öğretmeni'
  ],

  // ── Yazılım ve Web Hizmetleri — yeni hizmetler ──
  'Web Sitesi Bakımı': [
    'site bakımı', 'web sitesi güncelleme', 'site tamiri'
  ],
  'SEO Uyumlu Site Kurulumu': [
    'seo uyumlu site', 'hızlı site kurulumu'
  ],
  'Yazılım Danışmanlığı': [
    'yazılım danışmanı', 'teknik danışmanlık'
  ],
  'Veri Tabanı Kurulumu': [
    'veritabanı kurulumu', 'sql kurulumu'
  ],

  // ── Grafik ve Logo Tasarım — yeni hizmetler ──
  'Sosyal Medya Görsel Tasarımı': [
    'sosyal medya görseli', 'instagram tasarımı', 'post tasarımı'
  ],
  'Katalog ve Broşür Tasarımı': [
    'broşür tasarımı', 'katalog tasarımı', 'afiş tasarımı'
  ],
  'Ambalaj Tasarımı': [
    'ambalaj tasarımı', 'etiket tasarımı'
  ],

  // ── Dijital Pazarlama — yeni hizmetler ──
  'Meta Reklam Yönetimi': [
    'instagram reklam', 'facebook reklam yönetimi', 'meta ads'
  ],
  'İçerik Üretimi': [
    'içerik üretimi', 'blog yazarlığı', 'metin yazarlığı'
  ],
  'E-Ticaret Pazaryeri Yönetimi': [
    'trendyol mağaza yönetimi', 'pazaryeri yönetimi',
    'hepsiburada mağaza'
  ],

  // ── Fotoğraf Çekimi — yeni hizmetler ──
  'Düğün ve Nişan Fotoğrafçısı': [
    'düğün fotoğrafçısı', 'nişan çekimi', 'kına çekimi'
  ],
  'Bebek ve Aile Çekimi': [
    'bebek fotoğrafçısı', 'aile çekimi', 'doğum günü çekimi'
  ],
  'Mekan ve Emlak Çekimi': [
    'emlak fotoğrafı', 'mekan çekimi', 'airbnb çekimi'
  ],
  'Video Çekim ve Kurgu': [
    'video çekimi', 'tanıtım filmi', 'drone çekimi'
  ],

  // ── Etkinlik ve Organizasyon — yeni hizmetler ──
  'Balon ve Süsleme': [
    'balon süsleme', 'parti süslemesi', 'doğum günü süsleme'
  ],
  'Kına ve Nişan Organizasyonu': [
    'kına organizasyonu', 'nişan organizasyonu'
  ],
  'Kurumsal Etkinlik Organizasyonu': [
    'kurumsal organizasyon', 'açılış organizasyonu',
    'seminer organizasyonu'
  ],
  'Ses ve Işık Sistemi Kiralama': [
    'ses sistemi kiralama', 'ışık sistemi', 'dj hizmeti'
  ],

  // ── Evcil Hayvan Hizmetleri — yeni hizmetler ──
  'Pet Kuaför': [
    'pet kuaför', 'köpek tıraşı', 'kedi tımarı'
  ],
  'Evde Hayvan Bakıcılığı': [
    'evde hayvan bakıcısı', 'pet sitting', 'tatilde hayvan bakımı'
  ],
  'Köpek Eğitimi': [
    'köpek eğitmeni', 'itaat eğitimi'
  ],
  'Evcil Hayvan Taşıma': [
    'pet taksi', 'hayvan nakli'
  ],

  // ── Güzellik ve Bakım Hizmetleri — yeni hizmetler ──
  'Gelin Saçı ve Makyajı': [
    'gelin saçı', 'gelin makyajı', 'gelin paketi'
  ],
  'Kalıcı Oje': [
    'kalıcı oje', 'protez tırnak', 'jel tırnak'
  ],
  'Ağda ve Epilasyon': [
    'ağda', 'epilasyon', 'sir ağdası'
  ],
  'Cilt Bakımı': [
    'cilt bakımı', 'yüz bakımı', 'leke bakımı'
  ],
  'Evde Kuaför': [
    'evde kuaför', 'adrese kuaför', 'evde saç kesimi'
  ],

  // ═══════════════════════════════════════════════════════════
  // ⚠ HİZMET LİDERİ YAPISI — 77 YENİ HİZMET (14 Ağu)
  //
  // Lider hizmetin terimleri ÜRÜN ADINI da içerir: kullanıcı
  // "ayakkabı" yazınca `Ayakkabı Tamiri` bulunur. Ürün adı ayrı bir
  // kategori olarak AÇILMAZ.
  //
  // ⚠ Mikro işler (taban değişimi, fermuar tamiri, sap değişimi)
  // ayrı hizmet DEĞİL, liderin TERİMİDİR.

  // ── Ayakkabı ve Deri İşleri ──
  'Ayakkabı Tamiri': [
    'ayakkabı tamircisi', 'ayakkabı tamiri', 'ayakkabıcı',
    'taban değişimi', 'topuk tamiri', 'fermuar tamiri ayakkabı'
  ],
  'Bot Tamiri': [
    'bot tamiri', 'bot tamircisi', 'bot taban değişimi'
  ],
  'Çizme Tamiri': [
    'çizme tamiri', 'çizme fermuarı', 'çizme topuğu'
  ],
  'Spor Ayakkabı Tamiri': [
    'spor ayakkabı tamiri', 'koşu ayakkabısı tamiri'
  ],
  'Sneaker Tamiri': [
    'sneaker tamiri', 'sneaker onarımı'
  ],
  'Ayakkabı Boyama': [
    'ayakkabı boyama', 'ayakkabı boyatma', 'ayakkabı rengi değiştirme'
  ],
  'Ayakkabı Temizleme': [
    'ayakkabı temizleme', 'ayakkabı yıkama', 'sneaker temizliği'
  ],
  'Ayakkabı Bakımı': [
    'ayakkabı bakımı', 'ayakkabı cilalama', 'deri ayakkabı bakımı'
  ],
  'Ayakkabı Restorasyonu': [
    'ayakkabı restorasyonu', 'eski ayakkabı yenileme'
  ],
  'Ayakkabı Yapımı': [
    'ayakkabı yapımı', 'ısmarlama ayakkabı', 'el yapımı ayakkabı'
  ],
  'Çanta Tamiri': [
    'çanta tamiri', 'çanta tamircisi', 'çanta sapı tamiri',
    'çanta fermuarı'
  ],
  'Çanta Yapımı': [
    'çanta yapımı', 'özel çanta dikimi', 'el yapımı çanta'
  ],
  'Çanta Temizleme': [
    'çanta temizleme', 'çanta yıkama', 'deri çanta temizliği'
  ],
  'Çanta Boyama': [
    'çanta boyama', 'çanta rengi değiştirme'
  ],
  'Çanta Restorasyonu': [
    'çanta restorasyonu', 'eski çanta yenileme'
  ],
  'Deri Tamiri': [
    'deri tamiri', 'deri onarımı', 'deri yırtık tamiri',
    'deri ceket tamiri'
  ],
  'Deri Ürün Yapımı': [
    'deri ürün yapımı', 'deri imalat', 'özel deri ürün'
  ],
  'Deri Boyama': [
    'deri boyama', 'deri rengi yenileme'
  ],
  'Deri Temizleme': [
    'deri temizleme', 'deri ürün yıkama'
  ],
  'Deri Bakımı': [
    'deri bakımı', 'deri besleme', 'deri koruma'
  ],
  'Deri Restorasyonu': [
    'deri restorasyonu', 'eski deri yenileme'
  ],
  'Kemer Tamiri': [
    'kemer tamiri', 'kemer deliği açma', 'kemer kısaltma'
  ],
  'Kemer Yapımı': [
    'kemer yapımı', 'özel kemer dikimi'
  ],
  'Cüzdan Tamiri': [
    'cüzdan tamiri', 'cüzdan dikişi'
  ],
  'Cüzdan Yapımı': [
    'cüzdan yapımı', 'el yapımı cüzdan'
  ],

  // ── Terzilik ve Dikiş ──
  'Perde Dikimi': [
    'perde dikimi', 'perde diktirme', 'perde terzisi'
  ],
  'Perde Tadilatı': [
    'perde tadilatı', 'perde kısaltma', 'perde boyu ayarlama'
  ],
  'Perde Temizleme': [
    'perde temizleme', 'perde yıkatma'
  ],
  'Perde Ölçüsü Alma': [
    'perde ölçüsü alma', 'yerinde perde ölçüsü'
  ],
  'Perde Montajı': [
    'perde montajı', 'korniş montajı', 'perde takma'
  ],
  'Stor Perde': [
    'stor perde', 'zebra perde', 'stor perde dikimi'
  ],
  'Fon Perde Dikimi': [
    'fon perde dikimi', 'fon perde'
  ],
  'Fason Dikim': [
    'fason dikim', 'fason üretim', 'fason atölye'
  ],
  'Seri Dikim': [
    'seri dikim', 'toplu dikim', 'seri üretim dikiş'
  ],
  'Numune Dikimi': [
    'numune dikimi', 'örnek dikim', 'prototip dikim'
  ],
  'Kalıp Hazırlama': [
    'kalıp hazırlama', 'kalıpçı', 'model kalıbı'
  ],
  'Özel Ölçü Kalıp Hazırlama': [
    'özel ölçü kalıp', 'ölçüye göre kalıp'
  ],
  'Overlok Hizmeti': [
    'overlok', 'overlok yaptırma', 'kenar overlok'
  ],
  'Reçme Hizmeti': [
    'reçme', 'reçme yaptırma', 'paça reçme'
  ],
  'Tekstil Ütüleme': [
    'tekstil ütüleme', 'toplu ütüleme', 'buharlı ütü tekstil'
  ],
  'Tekstil Paketleme': [
    'tekstil paketleme', 'ürün paketleme', 'poşetleme hizmeti'
  ],
  'Triko Tamiri': [
    'triko tamiri', 'kazak tamiri', 'triko onarım'
  ],
  'Triko Yapımı': [
    'triko yapımı', 'triko üretim'
  ],
  'Triko Yenileme': [
    'triko yenileme', 'eski triko yenileme'
  ],
  'Triko Tadilatı': [
    'triko tadilatı', 'triko daraltma'
  ],
  'Örgü Yapımı': [
    'örgü yapımı', 'el örgüsü', 'örgü siparişi'
  ],
  'Kazak Örme': [
    'kazak örme', 'el örgüsü kazak'
  ],
  'Hırka Örme': [
    'hırka örme', 'el örgüsü hırka'
  ],
  'Bebek Örgüsü': [
    'bebek örgüsü', 'bebek battaniyesi örme', 'bebek patiği'
  ],
  'Örgü Kıyafet Tamiri': [
    'örgü kıyafet tamiri', 'örgü onarımı'
  ],
  'Nakış': [
    'nakış', 'nakış işleme', 'nakışçı'
  ],
  'El Nakışı': [
    'el nakışı', 'elde nakış'
  ],
  'Bilgisayarlı Nakış': [
    'bilgisayarlı nakış', 'makine nakışı'
  ],
  'Logo Nakışı': [
    'logo nakışı', 'kurumsal nakış', 'iş kıyafeti logo'
  ],
  'Kişiye Özel Nakış': [
    'kişiye özel nakış', 'isim nakışı'
  ],
  'Monogram': [
    'monogram', 'harf işleme', 'isim baş harfi işleme'
  ],
  'Tekstil İşleme': [
    'tekstil işleme', 'kumaş işleme'
  ],
  'Piko': [
    'piko', 'piko yaptırma', 'kenar piko'
  ],
  'İlik Açma': [
    'ilik açma', 'düğme iliği', 'ilik makinesi'
  ],
  'Kumaş Dokuma': [
    'kumaş dokuma', 'el dokuma kumaş'
  ],
  'Kumaş Kesimi': [
    'kumaş kesimi', 'toplu kumaş kesim'
  ],
  'Kumaş Tamiri': [
    'kumaş tamiri', 'kumaş yırtık onarımı'
  ],

  // ── Ev Tekstili ──
  'Yorgan Dikimi': [
    'yorgan dikimi', 'yorgancı', 'yorgan diktirme'
  ],
  'Yorgan Yapımı': [
    'yorgan yapımı', 'el yapımı yorgan'
  ],
  'Yorgan Yenileme': [
    'yorgan yenileme', 'eski yorgan yenileme'
  ],
  'Yorgan İçi Değişimi': [
    'yorgan içi değişimi', 'yorgan elyaf değişimi',
    'yorgan pamuk atma'
  ],
  'Yatak Yenileme': [
    'yatak yenileme', 'yatak yenileme servisi'
  ],
  'Yatak Dolgusu Yenileme': [
    'yatak dolgusu yenileme', 'yatak süngeri değişimi'
  ],
  'Yatak Tamiri': [
    'yatak tamiri', 'yatak onarımı', 'yaylı yatak tamiri'
  ],
  'Halı Tamiri': [
    'halı tamiri', 'halı onarımı', 'halı yırtık tamiri'
  ],
  'Halı Dokuma': [
    'halı dokuma', 'el dokuma halı'
  ],
  'Halı Restorasyonu': [
    'halı restorasyonu', 'antika halı yenileme'
  ],
  'Halı Saçak Yenileme': [
    'halı saçak yenileme', 'halı saçağı değişimi'
  ],
  'Halı Overlok': [
    'halı overlok', 'halı kenar overlok', 'halı kenarı yapma'
  ],
  'Kilim Tamiri': [
    'kilim tamiri', 'kilim onarımı'
  ],
  'Kilim Dokuma': [
    'kilim dokuma', 'el dokuma kilim'
  ],
  'Kilim Restorasyonu': [
    'kilim restorasyonu', 'antika kilim yenileme'
  ],

  // ══════════════════════════════════════════════════════════════
  //  PROFESYONEL / OFİS HİZMETLERİ TERİMLERİ (16 Ağu)
  // ══════════════════════════════════════════════════════════════
  //
  // ⚠ TERİM YAZIM KURALLARI AYNEN UYGULANDI: fiyat geçmez, bağlamsız
  // nesne/canlı adı yoktur, kişisel anlatım ("avukata ihtiyacım var")
  // yoktur. Meslek adları ("avukat", "mali müşavir", "smmm") ve
  // kısaltmalar ("dask", "osgb", "tss") SERBESTTİR — sahada aranan
  // biçim budur.
  //
  // ⚠ KISALTMALAR BİLEREK EKLENDİ: kullanıcı "dask" yazar, "Zorunlu
  // Deprem Sigortası" yazmaz.
  // ── Avukatlık ve Hukuk ──
  'Hukuki Danışmanlık': [
    'avukat', 'hukuk danışmanı', 'hukuki görüş', 'avukata danışma'
  ],
  'Dava Danışmanlığı': ['dava açma', 'dava danışmanı', 'dava için avukat'],
  'Dava Takibi': ['dava takip', 'duruşma takibi', 'dosya takibi avukat'],
  'İcra Takibi': ['icra avukatı', 'icra dosyası', 'haciz işlemleri'],
  'Alacak Takibi': [
    'alacak davası', 'borç tahsilat', 'alacak tahsili avukat'
  ],
  'Sözleşme Hazırlama': [
    'sözleşme yazımı', 'kontrat hazırlama', 'anlaşma metni'
  ],
  'Sözleşme İnceleme': [
    'sözleşme kontrolü', 'kontrat inceleme', 'sözleşme gözden geçirme'
  ],
  'İş Hukuku Danışmanlığı': [
    'iş hukuku avukatı', 'işçi işveren uyuşmazlığı'
  ],
  'İşçi Hakları Danışmanlığı': [
    'işçi hakları', 'kıdem tazminatı danışmanlık',
    'işten çıkarma hakları'
  ],
  'İşveren Hukuku Danışmanlığı': [
    'işveren danışmanlığı', 'şirket iş hukuku'
  ],
  'Kira Hukuku': [
    'kira davası', 'kiracı tahliye', 'kira sözleşmesi avukat'
  ],
  'Gayrimenkul Hukuku': [
    'tapu davası', 'emlak avukatı', 'gayrimenkul uyuşmazlığı'
  ],
  'Aile Hukuku': ['aile avukatı', 'velayet davası', 'nafaka davası'],
  'Boşanma Davası': [
    'boşanma avukatı', 'anlaşmalı boşanma', 'çekişmeli boşanma'
  ],
  'Miras Hukuku': [
    'miras avukatı', 'veraset işlemleri', 'miras paylaşımı'
  ],
  'Tüketici Hukuku': [
    'tüketici hakem heyeti', 'ayıplı mal', 'tüketici davası'
  ],
  'Ceza Hukuku': ['ceza avukatı', 'savunma avukatı', 'ceza davası'],
  'Ticaret Hukuku': ['ticaret avukatı', 'ticari uyuşmazlık'],
  'Şirketler Hukuku': [
    'şirket avukatı', 'ortaklık uyuşmazlığı',
    'şirket hukuku danışmanı'
  ],
  'Vergi Hukuku': [
    'vergi avukatı', 'vergi cezası itiraz', 'vergi uyuşmazlığı'
  ],
  'Bilişim Hukuku': [
    'siber hukuk', 'internet hukuku', 'bilişim suçları avukatı'
  ],
  'KVKK Danışmanlığı': [
    'kişisel verilerin korunması', 'kvkk uyum',
    'veri koruma danışmanlığı'
  ],
  'İş Kazası Hukuku': ['iş kazası avukatı', 'iş kazası tazminat davası'],
  'Tazminat Davaları': ['tazminat avukatı', 'maddi manevi tazminat'],
  'Arabuluculuk': ['arabulucu', 'uzlaştırma', 'arabuluculuk görüşmesi'],
  'Marka ve Patent Hukuku': [
    'marka avukatı', 'patent avukatı', 'marka hakkı ihlali'
  ],
  'Fikri Mülkiyet Hukuku': ['fikri haklar avukatı', 'telif ihlali dava'],
  'Hukuki Belge Hazırlama': [
    'dilekçe yazımı', 'ihtarname hazırlama', 'vekaletname hazırlama'
  ],
  'Hukuki Belge İnceleme': ['dilekçe kontrolü', 'hukuki metin inceleme'],
  // ── Muhasebe ve Mali Müşavirlik ──
  'Ön Muhasebe': ['ön muhasebeci', 'cari takip', 'fatura kayıt'],
  'Genel Muhasebe': ['muhasebeci', 'defter tutma', 'muhasebe kaydı'],
  'Mali Müşavirlik': [
    'mali müşavir', 'smmm', 'serbest muhasebeci mali müşavir'
  ],
  'Vergi Danışmanlığı': ['vergi danışmanı', 'vergi planlaması'],
  'Vergi Beyannamesi Hazırlama': [
    'beyanname verme', 'vergi beyanı', 'beyanname hazırlama'
  ],
  'KDV Beyannamesi': ['kdv beyanı', 'katma değer vergisi beyannamesi'],
  'Gelir Vergisi İşlemleri': [
    'gelir vergisi beyanı', 'yıllık gelir vergisi'
  ],
  'Kurumlar Vergisi İşlemleri': [
    'kurumlar vergisi beyanı', 'şirket vergisi'
  ],
  'Geçici Vergi İşlemleri': ['geçici vergi beyanı', 'üç aylık vergi'],
  'E-Fatura İşlemleri': [
    'e fatura kurulum', 'elektronik fatura', 'e fatura geçiş'
  ],
  'E-Arşiv İşlemleri': ['e arşiv fatura', 'elektronik arşiv'],
  'E-Defter İşlemleri': ['e defter', 'elektronik defter beratı'],
  'SGK İşlemleri': [
    'sgk bildirge', 'sigorta girişi', 'sgk işlemleri takip'
  ],
  'Bordro Hazırlama': [
    'maaş bordrosu', 'bordro hesaplama', 'ücret bordrosu'
  ],
  'Personel Özlük İşlemleri': [
    'özlük dosyası', 'personel evrakı', 'işe giriş çıkış işlemleri'
  ],
  'Şirket Kuruluş İşlemleri': [
    'şirket kurma', 'firma kuruluşu', 'şirket açma'
  ],
  'Şahıs Şirketi Kuruluşu': ['şahıs firması açma', 'şahıs şirketi kurma'],
  'Limited Şirket Kuruluşu': ['limited şirket kurma', 'ltd şti kuruluş'],
  'Anonim Şirket Kuruluşu': ['anonim şirket kurma', 'a.ş. kuruluş'],
  'Şirket Kapanış İşlemleri': [
    'şirket kapatma', 'firma tasfiye', 'şirket tasfiyesi'
  ],
  'Vergi Mükellefiyeti İşlemleri': [
    'mükellefiyet açılışı', 'vergi levhası işlemleri'
  ],
  'Muhasebe Kayıt İşlemleri': ['muhasebe kaydı girme', 'fiş kaydı'],
  'Finansal Raporlama': [
    'mali tablo hazırlama', 'bilanço raporu', 'finansal rapor'
  ],
  'Maliyet Analizi': ['maliyet hesabı', 'maliyet muhasebesi'],
  'Muhasebe Danışmanlığı': ['muhasebe danışmanı', 'mali danışmanlık'],
  'Mali Denetim Danışmanlığı': [
    'mali denetim', 'bağımsız denetim danışmanlığı'
  ],
  // ── İş Güvenliği ve İSG ──
  'İş Güvenliği Uzmanlığı': [
    'iş güvenliği uzmanı', 'isg uzmanı', 'a sınıfı iş güvenliği'
  ],
  'İSG Danışmanlığı': [
    'isg danışmanı', 'iş sağlığı güvenliği danışmanlık'
  ],
  'Risk Değerlendirmesi': [
    'risk değerlendirme raporu', 'isg risk değerlendirmesi'
  ],
  'İş Yeri Risk Analizi': ['işyeri risk analizi', 'tehlike analizi'],
  'Acil Durum Eylem Planı': ['acil eylem planı', 'acil durum planı isg'],
  'Acil Durum Planı Hazırlama': [
    'acil durum planı yazımı', 'acil plan hazırlığı'
  ],
  'Acil Durum Tatbikatı': [
    'yangın tatbikatı', 'tahliye tatbikatı', 'acil durum provası'
  ],
  'İSG Eğitimleri': ['iş güvenliği eğitimi', 'isg eğitim'],
  'Çalışan İş Güvenliği Eğitimi': [
    'personel isg eğitimi', 'çalışan güvenlik eğitimi'
  ],
  'İşe Giriş İSG Eğitimi': [
    'oryantasyon isg eğitimi', 'işe başlama güvenlik eğitimi'
  ],
  'Yangın Eğitimi': [
    'yangın güvenliği eğitimi', 'yangın söndürme eğitimi'
  ],
  'Tahliye Eğitimi': ['tahliye planı eğitimi', 'acil tahliye eğitimi'],
  'İş Kazası İnceleme': ['kaza incelemesi', 'iş kazası araştırma'],
  'İş Kazası Raporlama': ['kaza raporu', 'iş kazası bildirimi'],
  'İSG Saha Denetimi': ['isg saha kontrolü', 'iş güvenliği denetimi'],
  'İSG Dokümantasyonu': ['isg evrak hazırlama', 'iş güvenliği dosyası'],
  'İSG Kurul Danışmanlığı': ['isg kurulu', 'iş sağlığı güvenliği kurulu'],
  'İş Hijyeni Danışmanlığı': [
    'iş hijyeni ölçümü', 'işyeri hijyen danışmanlığı'
  ],
  'Periyodik Kontrol Organizasyonu': [
    'periyodik muayene', 'ekipman periyodik kontrolü'
  ],
  'Risk Analizi Güncelleme': [
    'risk analizi yenileme', 'risk raporu güncelleme'
  ],
  'İSG Mevzuat Danışmanlığı': ['isg mevzuat', 'iş güvenliği yasal uyum'],
  'OSGB Hizmetleri': ['osgb', 'ortak sağlık güvenlik birimi'],
  // ── Marka ve Patent ──
  'Marka Araştırması': ['marka sorgulama', 'marka benzerlik araştırması'],
  'Marka Başvurusu': ['marka başvuru', 'marka kaydı başvurusu'],
  'Marka Tescili': ['marka tescil', 'markamı tescil ettirme'],
  'Marka Yenileme': ['marka süre uzatma', 'marka tescil yenileme'],
  'Marka Devir İşlemleri': ['marka devri', 'marka satışı devir'],
  'Marka İtiraz İşlemleri': ['marka itirazı', 'marka yayına itiraz'],
  'Marka İzleme': ['marka takibi', 'marka ihlal izleme'],
  'Marka Koruma Danışmanlığı': [
    'marka koruma', 'marka hakkı danışmanlığı'
  ],
  'Patent Araştırması': ['patent sorgulama', 'patent ön araştırma'],
  'Patent Başvurusu': ['patent başvuru', 'buluş başvurusu'],
  'Patent Tescili': ['patent tescil', 'buluş tescili'],
  'Faydalı Model Başvurusu': [
    'faydalı model başvuru', 'faydalı model kaydı'
  ],
  'Faydalı Model Tescili': [
    'faydalı model tescil', 'faydalı model belgesi'
  ],
  'Tasarım Tescili': ['tasarım tescil', 'tasarım koruma başvurusu'],
  'Endüstriyel Tasarım Başvurusu': [
    'endüstriyel tasarım', 'tasarım başvuru'
  ],
  'Patent Yenileme': ['patent süre uzatma', 'patent yıllık ücret'],
  'Patent Devir İşlemleri': ['patent devri', 'patent hakkı devri'],
  'Patent İtiraz İşlemleri': ['patent itirazı', 'patent yayına itiraz'],
  'Fikri Mülkiyet Danışmanlığı': [
    'fikri mülkiyet', 'sınai mülkiyet danışmanlığı'
  ],
  'Telif Hakkı Danışmanlığı': ['telif hakkı', 'eser sahibi hakları'],
  'Lisanslama Danışmanlığı': [
    'lisans sözleşmesi', 'marka lisansı danışmanlık'
  ],
  // ── Sigorta ──
  'Sigorta Danışmanlığı': [
    'sigorta danışmanı', 'sigorta acentesi', 'poliçe danışmanlığı'
  ],
  'Sigorta Poliçesi Karşılaştırma': [
    'poliçe karşılaştırma', 'sigorta teklifi karşılaştırma'
  ],
  'Konut Sigortası': ['ev sigortası', 'mesken sigortası'],
  'DASK': ['zorunlu deprem sigortası', 'dask poliçesi'],
  'İşyeri Sigortası': ['dükkan sigortası', 'işyeri poliçesi'],
  'Ticari İşletme Sigortası': ['ticari sigorta', 'işletme sigortası'],
  'Kasko': ['araç kasko', 'kasko poliçesi'],
  'Trafik Sigortası': ['zorunlu trafik sigortası', 'trafik poliçesi'],
  'Sağlık Sigortası': ['sağlık poliçesi', 'sağlık sigortası teklifi'],
  'Tamamlayıcı Sağlık Sigortası': ['tss', 'tamamlayıcı sağlık'],
  'Özel Sağlık Sigortası': [
    'özel sağlık poliçesi', 'özel sağlık sigortası teklifi'
  ],
  'Hayat Sigortası': ['hayat poliçesi', 'yaşam sigortası'],
  'Ferdi Kaza Sigortası': ['ferdi kaza poliçesi', 'kaza sigortası'],
  'Seyahat Sigortası': ['seyahat sağlık sigortası', 'vize sigortası'],
  'İşveren Sorumluluk Sigortası': [
    'işveren mali sorumluluk', 'işveren sorumluluk poliçesi'
  ],
  'Mesleki Sorumluluk Sigortası': [
    'mesleki sorumluluk poliçesi', 'meslek sorumluluk sigortası'
  ],
  'Nakliyat Sigortası': ['emtia nakliyat sigortası', 'taşıma sigortası'],
  'Yangın Sigortası': ['yangın poliçesi', 'yangın sigortası teklifi'],
  'Tarım Sigortası': ['tarsim', 'tarım sigortası poliçesi'],
  'Makine Kırılması Sigortası': [
    'makine sigortası', 'makine kırılma poliçesi'
  ],
  'Elektronik Cihaz Sigortası': [
    'cihaz sigortası', 'elektronik ekipman sigortası'
  ],
  'Sigorta Hasar Danışmanlığı': [
    'hasar danışmanı', 'sigorta hasar süreci'
  ],
  'Hasar Dosyası Takibi': ['hasar dosyası', 'hasar takip sigorta'],
  'Poliçe Yenileme': ['poliçe yenileme işlemi', 'sigorta yenileme'],
  'Kurumsal Sigorta Danışmanlığı': [
    'kurumsal sigorta', 'şirket sigorta danışmanlığı'
  ],
};

