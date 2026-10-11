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
/// ⚠ 1587 ALT HİZMETİN TAMAMI KAPSANIR. Test bunu denetler; kataloğa
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
  'Görüntülü Diafon': ['diafon', 'interkom', 'görüntülü kapı',
    'kapı zili montajı',
    'diafon montajı', 'interkom montajı', 'kapı zili sistemi',
    'görüntülü kapı zili'
  ],
  'Akıllı Kilit': ['akıllı kilit', 'parmak izi kilit', 'şifreli kilit',
    'parmak izli kilit', 'akıllı kapı kilidi'
  ],
  'Yangın Algılama Sistemi': ['yangın alarmı', 'duman dedektörü',
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
  'VRF Klima Sistemi Bakımı': ['vrf', 'merkezi klima', 'multi split',
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
  'Uydu Anteni Montajı': ['uydu anteni', 'çanak kurulumu',
    'anten takma',
    'çanak anten kurulumu', 'uydu montajı', 'digitürk montajı'
  ],
  'Uydu Anteni Ayarı': ['çanak ayarı', 'uydu ayarı', 'sinyal yok',
    'kanal gelmiyor',
    'sinyal ayarı', 'kanal ayarı'
  ],
  'Merkezi Uydu Sistemi': ['merkezi uydu', 'santral anten',
    'apartman anten',
    'merkezi sistem anten', 'apartman anten sistemi'
  ],

  // ── İnternet ve Ağ ──
  'Modem Kurulumu': ['modem kurulum', 'internet bağlantısı',
    'modem ayarı', 'internet gelmiyor',
    'modem kurulumu', 'internet kurulumu'
  ],
  'İnternet Kablosu Çekme': ['ağ kablosu', 'network kurulumu', 'ethernet çekimi',
    'kablolama',
    'network kablolama', 'kablo tesisatı'
  ],
  'Wi-Fi Sinyal Güçlendirme': ['wifi çekmiyor', 'internet yavaş',
    'sinyal güçlendirici', 'mesh sistem',
    'access point'
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
    'tv ünitesi kurulumu',
    // Katalogda ayrı "TV duvar montajı" hizmeti yok; duvara asılan
    // televizyon ve ünite montajı bu hizmetin kapsamındadır.
    'tv askı aparatı', 'televizyon duvara asma'
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
  , 'çelik kapı kilidi', 'çoklu kilit değişimi'],
  'Barel Değişimi': ['barel değişimi', 'kilit göbeği',
    'silindir değişimi',
    'barel değiştirme'
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
  'Pilates': ['pilates', 'pilates dersi', 'reformer pilates',
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
  'Buharlı Ev Temizliği': [
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
  'Parmak İzi Geçiş Sistemi': [
    'parmak izi okuyucu', 'personel geçiş sistemi', 'kartlı geçiş'
  ],
  'Otopark Bariyer Sistemi': [
    'otopark bariyeri', 'kollu bariyer montajı'
  ],

  // ── Klima Montaj ve Servis — yeni hizmetler ──
  'Klima Gaz Dolumu': [
    'klima gaz dolumu', 'klima gazı bitti', 'soğutucu gaz dolumu'
  ],
  'Klima Sökme-Takma': [
    'klima taşıma', 'klima yeri değişimi', 'klima sökümü'
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

  // ── İnternet ve Ağ Kurulumu — yeni hizmetler ──

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
  'Yoga': [
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
  // ⚠ ÜÇÜNCÜ TARAF MARKA ADLARI KALDIRILDI (19 Eyl, kullanıcı
  // kararı): burada iki pazaryeri şirketinin adı arama terimi olarak
  // yazılıydı. Üretim deposunda başka şirketlerin markası bulunmamalı
  // — yorumda bile.
  //
  // ⚠ ARAMA KAPSAMI KORUNDU: marka adı yerine kullanıcıların aynı
  // hizmeti tarif ederken yazdığı genel terimler bırakıldı. Tek
  // terime düşürseydim bu hizmet aramada bulunamaz hâle gelirdi.
  'E-Ticaret Pazaryeri Yönetimi': [
    'pazaryeri yönetimi', 'pazaryeri mağaza yönetimi',
    'e-ticaret mağaza yönetimi', 'online mağaza yönetimi',
    'sanal mağaza yönetimi'
  ],

  // ── Fotoğraf Çekimi — yeni hizmetler ──
  'Düğün ve Nişan Fotoğrafçısı': [
    'düğün fotoğrafçısı', 'nişan çekimi', 'kına çekimi'
  ],
  'Bebek ve Aile Çekimi': [
    'bebek fotoğrafçısı', 'aile çekimi', 'doğum günü çekimi'
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

  // ── Bahçe ve Peyzaj ──
  'Çim Halı / Suni Çim': ['suni çim', 'yapay çim', 'çim halı'],
  'Suni Çim Montajı': ['suni çim döşeme', 'yapay çim montajı', 'çim halı serimi'],
  'Suni Çim Serme': ['suni çim serimi', 'yapay çim serme', 'bahçeye suni çim'],
  'Suni Çim Sökme': ['suni çim kaldırma', 'yapay çim sökümü'],
  'Ağaç Dikimi': ['fidan dikimi', 'ağaç diktirme', 'meyve ağacı dikimi'],
  'Bitki Dikimi': ['bitki diktirme', 'fide dikimi', 'saksı bitkisi dikimi'],
  'Çiçek Dikimi': ['çiçek ekimi', 'bahçeye çiçek dikme', 'mevsimlik çiçek dikimi'],
  'Bitki Hastalığı Tedavisi': ['bitki hastalığı', 'ağaç hastalığı tedavisi', 'yaprak hastalığı'],
  'Budama Sonrası Atık Temizliği': ['dal atığı temizliği', 'budama artığı toplama', 'bahçe atığı temizliği'],
  'Bahçe Toprak Düzenleme': ['toprak tesviyesi', 'bahçe toprağı düzeltme', 'toprak serme'],
  'Toprak Gübreleme': ['bahçe gübreleme', 'gübre atma', 'çim gübreleme'],
  'Bahçe Sulama Sistemi Bakımı': ['sulama sistemi bakımı', 'fıskiye bakımı', 'bahçe sulama tamiri'],
  'Bahçe Drenajı': ['bahçe su birikmesi', 'drenaj borusu döşeme', 'bahçe drenaj sistemi'],
  'Bahçe Aydınlatma': ['bahçe lambası', 'bahçe ışıklandırma', 'peyzaj aydınlatma'],
  'Bahçe Aydınlatma Sistemi Montajı': ['bahçe lambası montajı', 'bahçe aydınlatma kurulumu', 'peyzaj aydınlatma montajı'],
  'Bahçe Çit Montajı': ['bahçe çiti', 'tel çit montajı', 'panel çit montajı'],
  'Bahçe Kapısı Montajı': ['bahçe kapısı takma', 'bahçe giriş kapısı', 'demir bahçe kapısı'],
  'Peyzaj Tasarımı': ['bahçe tasarımı', 'peyzaj mimarı', 'bahçe projesi'],
  'Yağmur Suyu Toplama Sistemi': ['yağmur suyu hasadı', 'yağmur suyu biriktirme', 'çatı suyu toplama'],
  'Yağmur Suyu Depolama Sistemi': ['yağmur suyu deposu', 'yağmur suyu tankı', 'yer altı su deposu'],
  'Drenaj Pompası Montajı': ['drenaj pompası', 'pis su pompası montajı', 'bodrum su tahliye pompası'],

  // ── Havuz Yapım ve Bakım ──
  'Havuz Açılış Bakımı': ['havuz sezon açılışı', 'havuz açılış temizliği', 'yaz öncesi havuz bakımı'],
  'Havuz Kapatma Bakımı': ['havuz kışlatma', 'havuz sezon kapatma', 'kış öncesi havuz bakımı'],
  'Havuz Filtre Bakımı': ['havuz filtresi temizliği', 'havuz kum filtresi', 'havuz filtre yıkama'],
  'Havuz Filtresi Değişimi': ['havuz filtre değiştirme', 'havuz kum değişimi', 'havuz filtre yenileme'],
  'Havuz Pompa Bakımı': ['havuz pompası bakımı', 'havuz sirkülasyon pompası', 'havuz pompa servisi'],
  'Havuz Pompa Değişimi': ['havuz pompası değiştirme', 'yeni havuz pompası', 'havuz pompası yenileme'],
  'Havuz Motoru Tamiri': ['havuz motoru arızası', 'havuz motoru çalışmıyor', 'havuz motor tamiri'],
  'Havuz Ekipmanları Montajı': ['havuz ekipmanı kurulumu', 'havuz merdiveni montajı', 'havuz skimmer montajı'],
  'Havuz Aydınlatma Tamiri': ['havuz lambası tamiri', 'havuz ışığı yanmıyor', 'havuz led tamiri'],
  'Havuz Derz Yenileme': ['havuz derzi', 'havuz fayans derzi', 'havuz derz dolgusu'],
  'Havuz Kaplama Yenileme': ['havuz kaplaması', 'havuz liner değişimi', 'havuz seramik yenileme'],
  'Havuz Isıtma Sistemi': ['havuz ısıtma', 'havuz suyu ısıtma', 'havuz ısıtıcı'],
  'Havuz Isı Pompası Montajı': ['havuz ısı pompası', 'havuz ısıtma pompası', 'havuz ısı pompası kurulumu'],
  'Havuz Otomasyon Sistemi': ['havuz otomasyonu', 'akıllı havuz sistemi', 'havuz otomatik dozaj'],
  'Havuz Kapak Sistemi': ['havuz kapağı', 'havuz örtüsü', 'otomatik havuz kapağı'],

  // ── Su Tesisatı ──
  'Kameralı Su Kaçağı Tespiti': ['kamerayla kaçak bulma', 'kameralı kaçak tespiti', 'boru içi kamera'],
  'Termal Kamera ile Su Kaçağı Tespiti': ['termal kamera kaçak', 'termal kamerayla kaçak bulma', 'kırmadan kaçak tespiti'],
  'Su Kaçağı Onarımı': ['su kaçağı tamiri', 'kaçak su onarımı', 'patlak boru tamiri'],
  'Alt Kata Su Sızıntısı Onarımı': ['alt kata su akıyor', 'tavandan su damlıyor', 'komşuya su sızıyor'],
  'Batarya Değişimi': ['musluk değişimi', 'armatür değişimi', 'lavabo bataryası değişimi'],
  'Klozet Tamiri': ['tuvalet tamiri', 'klozet arızası', 'tuvalet taşı tamiri'],
  'Klozet İç Takım Değişimi': ['rezervuar iç takımı', 'sifon iç takım değişimi', 'tuvalet iç takımı'],
  'Gömme Rezervuar Tamiri': ['gömme rezervuar arızası', 'gömme sifon tamiri', 'gömme rezervuar su kaçırıyor'],
  'Gömme Rezervuar Montajı': ['gömme rezervuar takma', 'asma klozet montajı', 'gömme sifon montajı'],
  'Sifon Tamiri': ['lavabo sifonu tamiri', 'sifon kaçırıyor', 'sifon arızası'],
  'Sifon Değişimi': ['lavabo sifonu değişimi', 'sifon değiştirme', 'gider sifonu'],
  'Lavabo Tamiri': ['lavabo arızası', 'lavabo kırık', 'lavabo gideri tamiri'],
  'Vana Değişimi': ['ana vana değişimi', 'küresel vana', 'vana değiştirme'],
  'Su Sayacı Değişimi': ['su saati değişimi', 'sayaç değişimi', 'kartlı su sayacı'],
  'Su Basıncı Problemi': ['su basıncı düşük', 'su tazyiki yok', 'musluktan su az akıyor'],
  'Hidrofor Bakımı': ['hidrofor servisi', 'su pompası bakımı', 'hidrofor periyodik bakım'],
  'Hidrofor Tamiri': ['hidrofor arızası', 'hidrofor çalışmıyor', 'hidrofor sürekli çalışıyor'],
  'Hidrofor Basınç Tankı Değişimi': ['genleşme tankı değişimi', 'hidrofor tankı', 'basınç tankı değişimi'],
  'Lavabo Su Akıtıyor': ['lavabo kaçırıyor', 'lavabo altından su geliyor', 'lavabo sızdırıyor'],
  'Klozet Su Kaçırıyor': ['tuvalet sürekli su akıtıyor', 'rezervuar su kaçırıyor', 'klozet sızdırıyor'],
  'Alaturka Tuvaleti Alafrangaya Çevirme': ['alaturka tuvalet değişimi', 'alafranga klozet takma', 'tuvalet dönüşümü'],
  'Gömme Rezervuar İç Takım Değişimi': ['gömme rezervuar iç takımı', 'gömme sifon iç takım', 'gömme rezervuar parça değişimi'],
  'Gömme Rezervuar Değişimi': ['gömme rezervuar yenileme', 'gömme sifon değişimi', 'gömme rezervuar değiştirme'],
  'Batarya Montajı': ['musluk takma', 'armatür montajı', 'lavabo bataryası takma'],

  // ── Doğalgaz ──
  'Doğalgaz Tesisat Kontrolü': ['gaz tesisatı kontrolü', 'doğalgaz hattı kontrolü', 'tesisat gaz kontrolü'],
  'Doğalgaz Tesisat Uygunluk Kontrolü': ['gaz uygunluk raporu', 'tesisat uygunluk belgesi', 'gaz açma uygunluğu'],
  'Doğalgaz Tesisat Sızdırmazlık Testi': ['gaz sızdırmazlık testi', 'tesisat basınç testi', 'gaz hattı test'],
  'Doğalgaz Tesisat Yenileme': ['gaz tesisatı yenileme', 'eski gaz borusu değişimi', 'gaz hattı yenileme'],
  'Doğalgaz Hat Tadilatı': ['gaz hattı tadilatı', 'gaz borusu taşıma', 'gaz hattı değişikliği'],

  // ── Kombi Servis ──
  'Kombi Petek Isınmama Arızası': ['petekler ısınmıyor', 'kombi çalışıyor petek soğuk', 'kalorifer ısıtmıyor'],
  'Kombi Su Basıncı Sorunu': ['kombi basınç düşüyor', 'kombi bar düşük', 'kombiye su basma'],
  'Kombi Su Kaçağı Tamiri': ['kombi su damlatıyor', 'kombi altından su geliyor', 'kombi sızdırıyor'],
  'Kombi Eşanjör Temizliği': ['eşanjör temizliği', 'kombi kireç temizliği', 'kombi eşanjör yıkama'],
  'Kombi Fan Değişimi': ['kombi fanı', 'kombi fan motoru', 'kombi fan arızası'],
  'Kombi Pompa Değişimi': ['kombi pompası', 'kombi sirkülasyon pompası', 'kombi pompa arızası'],
  'Kombi Sensör Değişimi': ['kombi sensörü', 'kombi ntc sensör', 'kombi sensör arızası'],
  'Kombi Kart Tamiri': ['kombi anakart', 'kombi elektronik kart', 'kombi kartı arızası'],
  'Kombi Baca Kontrolü': ['kombi bacası kontrolü', 'baca gazı kontrolü', 'kombi baca testi'],
  'Kombi Baca Temizliği': ['kombi bacası temizliği', 'baca temizletme', 'kombi baca tıkanıklığı'],
  'Kombi Yoğuşma Gideri Temizliği': ['yoğuşma gideri', 'kombi yoğuşma suyu', 'kombi gider hortumu'],

  // ── Isıtma Sistemleri ──
  'Petek Havası Alma': ['petek hava alma', 'kaloriferin havasını alma', 'petek tıkırdıyor'],
  'Petek Vana Değişimi': ['radyatör vanası', 'petek musluğu değişimi', 'kalorifer vanası'],
  'Termostatik Vana Montajı': ['termostatik vana', 'radyatör termostatı', 'petek termostatı'],
  'Yerden Isıtma Bakımı': ['yerden ısıtma servisi', 'yerden ısıtma temizliği', 'yerden ısıtma kollektör bakımı'],
  'Yerden Isıtma Tamiri': ['yerden ısıtma arızası', 'yerden ısıtma çalışmıyor', 'yerden ısıtma onarımı'],
  'Yerden Isıtma Kaçak Tespiti': ['yerden ısıtma su kaçağı', 'yerden ısıtma boru kaçağı', 'yerden ısıtma basınç düşüyor'],
  'Kalorifer Tesisatı': ['kalorifer döşeme', 'kalorifer borusu', 'radyatör tesisatı'],
  'Kalorifer Tesisatı Tamiri': ['kalorifer borusu tamiri', 'kalorifer kaçağı', 'kalorifer arızası'],
  'Kalorifer Tesisatı Yenileme': ['kalorifer borusu yenileme', 'eski kalorifer değişimi', 'radyatör tesisatı yenileme'],
  'Merkezi Isıtma Sistemi Bakımı': ['merkezi sistem bakımı', 'kazan dairesi bakımı', 'kalorifer kazanı bakımı'],
  'Merkezi Isıtma Sistemi Tamiri': ['merkezi sistem arızası', 'kazan dairesi tamiri', 'kalorifer kazanı arızası'],
  'Şofben Montajı': ['şofben takma', 'şofben bağlantısı', 'yeni şofben kurulumu'],
  'Termosifon Montajı': ['termosifon takma', 'elektrikli su ısıtıcı montajı', 'termosifon bağlantısı'],
  'Boyler Bakımı': ['boyler servisi', 'boyler temizliği', 'sıcak su boyleri'],
  'Isı Pompası Montajı': ['ısı pompası kurulumu', 'hava kaynaklı ısı pompası', 'ısı pompası takma'],
  'Isı Pompası Bakımı': ['ısı pompası servisi', 'ısı pompası periyodik bakım', 'ısı pompası temizliği'],
  'Isı Pompası Tamiri': ['ısı pompası arızası', 'ısı pompası çalışmıyor', 'ısı pompası onarımı'],

  // ── Elektrik ──
  'Ev Elektrik Tesisatı': ['daire elektrik tesisatı', 'ev elektrik döşeme', 'konut elektrik tesisatı'],
  'Elektrik Tesisatı Yenileme': ['elektrik kablolarının yenilenmesi', 'eski tesisat yenileme', 'elektrik hattı yenileme'],
  'Elektrik Kaçağı Tespiti': ['kaçak akım', 'sigorta sürekli atıyor', 'elektrik çarpıyor'],
  'Priz Değişimi': ['priz değiştirme', 'yanık priz', 'priz yenileme'],
  'Anahtar Değişimi': ['lamba anahtarı değişimi', 'elektrik düğmesi değişimi', 'ışık anahtarı'],
  'Ampul Değişimi': ['ampul takma', 'lamba değişimi', 'tavan lambası ampulü'],
  'LED Aydınlatma Montajı': ['led montajı', 'şerit led', 'led spot montajı'],
  'Sensörlü Aydınlatma Montajı': ['hareket sensörlü lamba', 'sensörlü lamba takma', 'otomatik yanan lamba'],
  'Sigorta Değişimi': ['sigorta değiştirme', 'otomatik sigorta', 'sigorta kutusu'],
  'Aydınlatma Otomasyonu': ['akıllı aydınlatma', 'akıllı lamba sistemi', 'aydınlatma kontrol sistemi'],
  'Topraklama Ölçümü': ['topraklama testi', 'topraklama raporu', 'topraklama direnci ölçümü'],
  'Zil Montajı': ['kapı zili takma', 'zil takma', 'kablosuz zil montajı'],
  'Kapı Zili Tamiri': ['zil çalmıyor', 'kapı zili arızası', 'zil tamiri'],
  'Elektrikli Araç Şarj İstasyonu Montajı': ['şarj istasyonu kurulumu', 'elektrikli araç şarj ünitesi', 'ev tipi şarj istasyonu'],
  'Wallbox Montajı': ['wallbox kurulumu', 'duvar tipi şarj cihazı', 'elektrikli araç wallbox'],

  // ── Güvenlik Sistemleri ──
  'IP Kamera Sistemi': ['ip kamera', 'ağ kamerası', 'internetli kamera sistemi'],
  'Analog Kamera Sistemi': ['analog kamera', 'ahd kamera sistemi', 'dvr kamera sistemi'],
  'Kamera Montajı': ['güvenlik kamerası takma', 'kamera kurulumu', 'kamera montaj ustası'],
  'Kamera Sökme': ['kamera sökümü', 'güvenlik kamerası kaldırma', 'kamera demontajı'],
  'Kamera Bakımı': ['kamera sistemi bakımı', 'güvenlik kamerası bakımı', 'kamera periyodik bakım'],
  'Kamera Arıza Tamiri': ['kamera görüntü vermiyor', 'güvenlik kamerası arızası', 'kamera tamiri'],
  'Hırsız Alarmı': ['hırsız alarm sistemi', 'ev alarmı', 'alarm sistemi kurulumu'],
  'Yangın Alarm Sistemi': ['yangın alarmı', 'duman dedektörü', 'yangın ihbar sistemi'],
  'Gaz Alarm Sistemi': ['gaz alarm cihazı', 'gaz dedektörü', 'karbonmonoksit dedektörü'],
  'Su Baskını Alarm Sistemi': ['su baskın sensörü', 'su taşma alarmı', 'su sızıntı dedektörü'],
  'Diafon Tamiri': ['diyafon tamiri', 'kapı telefonu tamiri', 'diafon arızası'],
  'Akıllı Ev Güvenlik Sistemi': ['akıllı ev alarmı', 'akıllı güvenlik sistemi', 'telefondan izlenen alarm'],
  'Apartman Güvenlik Sistemi': ['apartman kamera sistemi', 'bina güvenlik sistemi', 'site güvenlik kamerası'],
  'Kartlı Geçiş Sistemi': ['kartlı giriş sistemi', 'personel geçiş kontrolü', 'kartlı kapı sistemi'],
  'Yüz Tanıma Sistemi': ['yüz tanımalı geçiş', 'yüz tanıma cihazı', 'biyometrik geçiş sistemi'],
  'Turnike Sistemi': ['turnike kurulumu', 'giriş turnikesi', 'personel turnikesi'],
  'Otomatik Kapı Sistemi': ['otomatik kapı motoru', 'motorlu kapı sistemi', 'otomatik bahçe kapısı'],
  'Güvenlik Sistemi Uzaktan İzleme': ['alarm izleme merkezi', 'uzaktan kamera izleme', 'alarm takip hizmeti'],
  'İnterkom/Diafon Montajı': ['interkom montajı', 'diafon montajı', 'görüntülü diafon takma'],

  // ── Klima Montaj ve Servis ──
  'Klima Gaz Kaçağı Tespiti': ['klima gazı kaçırıyor', 'klima gaz kaçağı', 'klima soğutmuyor gaz'],
  'Klima Sökme': ['klima sökümü', 'klima demontajı', 'taşınmada klima sökme'],
  'Klima Dış Ünite Montajı': ['klima dış ünitesi', 'dış ünite takma', 'klima dış ünite sabitleme'],
  'Klima İç Ünite Montajı': ['klima iç ünitesi', 'iç ünite takma', 'klima iç ünite asma'],
  'Klima Yer Değişimi': ['klima yerini değiştirme', 'klima taşıma', 'klima başka odaya alma'],
  'Klima Drenaj Hattı': ['klima su akıtıyor', 'klima gider hortumu', 'klima drenaj borusu'],
  'Klima Elektrik Bağlantısı': ['klima elektrik hattı', 'klima için ayrı hat', 'klima sigorta hattı'],
  'Multi Klima Sistemi Montajı': ['multi klima', 'tek dış ünite çok iç ünite', 'multi split klima'],

  // ── Çilingir ve Kilit ──
  'Ev Kapısı Açma': ['evde kapı kilitli kaldı', 'ev kapısı açtırma', 'anahtar içeride kaldı'],
  'Çelik Kapı Açma': ['çelik kapı açtırma', 'çelik kapı kilitli kaldı', 'çelik kapı çilingir'],
  'Kilit Tamiri': ['kilit arızası', 'kilit dönmüyor', 'kilit onarımı'],
  'Silindir Değişimi': ['kilit göbeği değişimi', 'barel değiştirme', 'kapı göbeği'],
  'Akıllı Kilit Montajı': ['akıllı kilit takma', 'akıllı kapı kilidi', 'telefonla açılan kilit'],
  'Şifreli Kilit Montajı': ['şifreli kilit takma', 'şifreli kapı kilidi montajı', 'tuşlu kilit montajı'],
  'Elektrikli Kilit Montajı': ['elektrikli kilit takma', 'elektronik kilit montajı', 'otomatik kilit montajı'],
  'Manyetik Kilit Montajı': ['manyetik kilit', 'elektromanyetik kilit', 'mıknatıslı kapı kilidi'],
  'Panik Bar Montajı': ['panik bar', 'yangın kapısı kolu', 'acil çıkış barı'],
  'Kapı Kilidi Bakımı': ['kilit bakımı', 'kilit yağlama', 'kapı kilidi servisi'],
  'Şifreli Kilit': ['şifreli kapı kilidi', 'şifreli kilit sistemi', 'tuşlu kilit'],

  // ── Uydu ve Anten Sistemleri ──
  'Uydu Kurulumu': ['çanak anten kurulumu', 'uydu anteni takma', 'uydu sistemi kurulumu'],
  'Uydu Sinyal Sorunu': ['uydu sinyal yok', 'uydu çekmiyor', 'televizyonda sinyal yok'],
  'Uydu Kanal Ayarlama': ['kanal ayarı', 'uydu kanal arama', 'kanalları yükleme'],
  'Uydu Sinyal Ölçümü': ['sinyal ölçümü', 'uydu sinyal ayarı', 'çanak yön ayarı'],
  'LNB Değişimi': ['lnb değiştirme', 'çanak lnb', 'uydu lnb arızası'],
  'Uydu Kablosu Çekme': ['anten kablosu çekme', 'uydu kablosu döşeme', 'koaksiyel kablo çekimi'],
  'Merkezi Uydu Sistemi Arızası': ['merkezi uydu arızası', 'apartman uydusu çalışmıyor', 'merkezi anten arızası'],
  'Merkezi Uydu Sistemi Yenileme': ['merkezi uydu yenileme', 'apartman uydu sistemi yenileme', 'merkezi anten değişimi'],
  'TV Sinyal Dağıtım Sistemi': ['tv sinyal dağıtımı', 'anten dağıtım sistemi', 'çoklu televizyon bağlantısı'],
  'TV Anteni Montajı': ['televizyon anteni takma', 'karasal anten montajı', 'çatı anteni montajı'],

  // ── İnternet ve Ağ Kurulumu ──
  'İnternet Kurulumu': ['internet bağlatma', 'modem kurulumu', 'ev internet kurulumu'],
  'İnternet Nakli': ['internet taşıma', 'internet adres değişikliği', 'taşınmada internet nakli'],
  'İnternet Arıza / Hat Sorunu': ['internet kesiliyor', 'internet hattı arızası', 'internet yok'],
  'Wi-Fi Kurulumu': ['wifi kurulumu', 'kablosuz ağ kurulumu', 'wifi ayarlama'],
  'Wi-Fi Mesh Sistem Kurulumu': ['mesh wifi sistemi', 'mesh ağ kurulumu', 'tüm eve wifi yayma'],
  'Wi-Fi Access Point Kurulumu': ['access point kurulumu', 'erişim noktası kurulumu', 'kablosuz erişim noktası'],
  'Wi-Fi Ölü Nokta Çözümü': ['wifi çekmiyor', 'wifi zayıf', 'wifi kapsama alanı'],
  'Ev İçi Ağ Kurulumu': ['ev ağı kurulumu', 'ev içi network', 'evde kablolu ağ'],
  'Router Kurulumu': ['router ayarlama', 'yönlendirici kurulumu', 'router bağlama'],
  'Mesh Wi-Fi Kurulumu': ['mesh wifi kurulumu', 'mesh router', 'mesh modem kurulumu'],
  'CAT6 Kablo Çekimi': ['cat6 kablo', 'ethernet kablosu çekimi', 'network kablosu döşeme'],
  'Ethernet Prizi Montajı': ['ethernet prizi', 'data prizi montajı', 'internet prizi takma'],
  'Fiber Kablo Çekimi': ['fiber kablo döşeme', 'fiber altyapı', 'fiber internet kablosu'],
  'Fiber Optik Sonlandırma': ['fiber sonlandırma', 'fiber ek', 'fiber konnektör takma'],
  'Fiber Optik Arıza Tespiti': ['fiber arızası', 'fiber kopukluk tespiti', 'fiber hat ölçümü'],
  'Network Kablo Testi': ['kablo test cihazı', 'network kablo ölçümü', 'ethernet kablo testi'],
  'İnternet Arıza Tespiti': ['internet neden yavaş', 'internet arızası bulma', 'internet bağlantı sorunu'],

  // ── Güneş Enerjisi Sistemleri ──
  'Ev Tipi Güneş Enerjisi Sistemi': ['ev tipi güneş paneli', 'eve güneş enerjisi', 'konut güneş sistemi'],
  'Çatı Güneş Enerjisi Sistemi': ['çatıya güneş paneli', 'çatı tipi ges', 'çatı güneş paneli'],
  'Güneş Paneli Montajı': ['güneş paneli takma', 'solar panel montajı', 'panel kurulumu'],
  'Güneş Paneli Bakımı': ['solar panel bakımı', 'ges bakımı', 'güneş paneli servisi'],
  'Güneş Paneli Temizliği': ['solar panel temizliği', 'ges panel yıkama', 'güneş paneli yıkama'],
  'Güneş Paneli Arıza Tespiti': ['güneş paneli arızası', 'solar panel üretim düştü', 'ges arıza tespiti'],
  'Güneş Paneli Değişimi': ['güneş paneli değiştirme', 'kırık güneş paneli', 'solar panel yenileme'],
  'On-Grid Güneş Enerjisi Sistemi': ['on grid sistem', 'şebeke bağlantılı güneş enerjisi', 'on grid ges'],
  'Off-Grid Güneş Enerjisi Sistemi': ['off grid sistem', 'şebekeden bağımsız güneş enerjisi', 'bağ evi güneş enerjisi'],
  'Hibrit Güneş Enerjisi Sistemi': ['hibrit sistem', 'hibrit ges', 'aküllü şebeke bağlantılı sistem'],
  'Güneş Enerjisi Batarya Sistemi': ['güneş enerjisi aküsü', 'solar akü', 'lityum akü sistemi'],
  'Enerji Depolama Sistemi': ['enerji depolama', 'batarya depolama sistemi', 'ev tipi enerji depolama'],
  'İnverter Montajı': ['inverter takma', 'solar inverter', 'evirici montajı'],
  'Güneş Enerjisi Sistem Bakımı': ['ges sistem bakımı', 'güneş enerjisi servisi', 'solar sistem bakımı'],
  'Güneş Enerjisi Sistem İzleme': ['ges izleme', 'üretim takibi', 'solar uzaktan izleme'],

  // ── Oto Çekici ve Yol Yardım ──
  'Lastik Yol Yardımı': ['yolda lastik patladı', 'lastik yol yardım', 'patlak lastik yardımı'],

  // ── Oto Servis ve Bakım ──
  'Bilgisayarlı Arıza Tespiti': ['araç arıza tespiti', 'motor arıza lambası', 'oto teşhis cihazı'],
  'Triger Seti Değişimi': ['triger kayışı değişimi', 'triger değişimi', 'eksantrik kayışı'],
  'Yağ ve Filtre Değişimi': ['motor yağı değişimi', 'yağ değişimi', 'filtre değişimi'],
  'Şanzıman Bakımı': ['vites kutusu bakımı', 'şanzıman yağı değişimi', 'otomatik şanzıman bakımı'],
  'Mobil Lastik Hizmeti': ['yerinde lastik değişimi', 'gezici lastikçi', 'mobil lastikçi'],
  'Motor Rektifiye': ['motor revizyonu', 'motor yenileme', 'rektifiye işi'],

  // ── Araç Temizlik ve Detaylı Bakım ──
  'Seramik Kaplama': ['araç seramik kaplama', 'oto seramik kaplama', 'boya koruma seramik'],
  'Far Temizleme ve Parlatma': ['far parlatma', 'sararmış far temizliği', 'far yenileme'],

  // ── Oto Ekspertiz ──
  'Oto Ekspertiz': ['araç ekspertizi', 'ikinci el araç kontrolü', 'oto ekspertiz raporu'],
  'Mobil Oto Ekspertiz': ['yerinde ekspertiz', 'gezici ekspertiz', 'araç başında ekspertiz'],

  // ── Kaporta ve Boya ──
  'Kaporta Onarımı': ['kaporta tamiri', 'kaportacı', 'hasarlı kaporta'],
  'Boya Onarımı': ['oto boya tamiri', 'araç boyama', 'çizik boyama'],
  'Mini Onarım': ['lokal boya', 'küçük hasar onarımı', 'çizik giderme'],
  'Göçük Düzeltme': ['boyasız göçük düzeltme', 'göçük çıkarma', 'dolu hasarı onarımı'],

  // ── Lastik ve Jant Hizmetleri ──
  'Lastik Değişimi': ['lastik değiştirme', 'kışlık lastik takma', 'yazlık lastik takma'],
  'Lastik Tamiri': ['patlak lastik tamiri', 'lastik yaması', 'lastik onarımı'],
  'Rot Balans Ayarı': ['rot balans', 'rot ayarı', 'balans ayarı'],
  'Jant Onarımı': ['jant tamiri', 'eğik jant düzeltme', 'jant boyama'],

  // ── Oto Görsel & Koruma Hizmetleri ──
  'Araç Kaplama': ['folyo kaplama', 'araç folyo', 'oto kaplama'],
  'Oto Cam Filmi': ['araç cam filmi', 'cam film çektirme', 'oto film'],
  'Oto Boya Koruma': ['boya koruma', 'araç boya koruma', 'pasta cila koruma'],
  'Oto Modifiye': ['araç modifiye', 'modifiye atölyesi', 'tuning'],
  'PPF Kaplama': ['ppf koruma filmi', 'şeffaf boya koruma filmi', 'ppf uygulama'],

  // ── Beyaz Eşya Servisi ──
  'Mikrodalga Fırın Tamiri': ['mikrodalga tamiri', 'mikrodalga ısıtmıyor', 'mikrodalga arızası'],
  'Derin Dondurucu Tamiri': ['derin dondurucu arızası', 'dondurucu soğutmuyor', 'sandık tipi dondurucu tamiri'],
  'Buzdolabı Bakımı': ['buzdolabı servisi', 'buzdolabı periyodik bakım', 'buzdolabı kondanser temizliği'],
  'Çamaşır Makinesi Bakımı': ['çamaşır makinesi servisi', 'çamaşır makinesi kireç temizliği', 'çamaşır makinesi periyodik bakım'],
  'Bulaşık Makinesi Bakımı': ['bulaşık makinesi servisi', 'bulaşık makinesi kireç temizliği', 'bulaşık makinesi filtre temizliği'],
  'Buzdolabı Gaz Dolumu': ['buzdolabı gazı', 'buzdolabı gaz bitti', 'buzdolabına gaz basma'],
  'Motor Değişimi': ['beyaz eşya motoru değişimi', 'makine motoru değişimi', 'cihaz motoru değiştirme'],
  'Rezistans Değişimi': ['rezistans değiştirme', 'ısıtıcı rezistans', 'rezistans yandı'],
  'Rulman Değişimi': ['çamaşır makinesi rulmanı', 'rulman sesi', 'kazan rulmanı değişimi'],
  'Bakır Kalaylama': ['kalaycı', 'bakır kap kalaylama', 'bakır tencere kalaylama'],
  'Çaydanlık Tamiri': ['çaydanlık kulpu tamiri', 'elektrikli çaydanlık tamiri', 'çay makinesi tamiri'],
  'Çaydanlık Parlatma': ['çaydanlık kireç temizliği', 'çelik çaydanlık parlatma', 'çaydanlık yenileme'],
  'Çelik Tencere Parlatma': ['tencere parlatma', 'paslanmaz tencere parlatma', 'tencere yenileme'],
  'Ütü Tamiri': ['ütü arızası', 'buharlı ütü tamiri', 'ütü ısıtmıyor'],

  // ── Elektronik Cihaz Tamiri ──
  'Yazıcı Tamiri': ['printer tamiri', 'yazıcı arızası', 'yazıcı kağıt sıkıştırıyor'],
  'Monitör Tamiri': ['monitör arızası', 'monitör görüntü vermiyor', 'ekran tamiri'],
  'Ses Sistemi Tamiri': ['müzik seti tamiri', 'ses sistemi arızası', 'amfi tamiri'],
  'Hoparlör Tamiri': ['hoparlör arızası', 'hoparlör cızırdıyor', 'kolon tamiri'],
  'Projeksiyon Kurulumu': ['projeksiyon montajı', 'projektör kurulumu', 'projeksiyon perdesi montajı'],
  'Akıllı Saat Tamiri': ['akıllı saat ekran değişimi', 'akıllı saat arızası', 'saat batarya değişimi'],
  'Drone Tamiri': ['drone arızası', 'drone pervane değişimi', 'drone onarımı'],
  'Bilgisayar Temizliği': ['bilgisayar içi temizlik', 'laptop fan temizliği', 'termal macun değişimi'],
  'Elektrikli Scooter Tamiri': ['scooter tamiri', 'scooter arızası', 'elektrikli scooter onarımı'],
  'Elektrikli Scooter Servisi': ['scooter servisi', 'scooter bakımı', 'elektrikli scooter bakımı'],
  'Scooter Tamiri': ['scooter onarımı', 'scooter lastik değişimi', 'scooter fren tamiri'],
  'PlayStation Tamiri': ['playstation tamiri', 'ps5 tamiri', 'ps4 tamiri'],
  'Xbox Tamiri': ['xbox arızası', 'xbox onarımı', 'oyun konsolu tamiri'],

  // ── Küçük Ev Aletleri ──
  'Küçük Ev Aletleri Tamiri': ['küçük ev aleti tamiri', 'mutfak aleti tamiri', 'elektrikli ev aleti tamiri'],
  'Kahve Makinesi Tamiri': ['kahve makinesi arızası', 'espresso makinesi tamiri', 'kahve makinesi kireç temizliği'],
  'Elektrikli Süpürge Tamiri': ['süpürge tamiri', 'süpürge çekmiyor', 'robot süpürge tamiri'],

  // ── Temizlik Hizmetleri ──
  'Apartman / Ortak Alan Temizliği': ['merdiven temizliği', 'ortak alan temizliği', 'apartman merdiveni temizliği'],
  'Buzdolabı İçi Temizliği': ['buzdolabı temizliği', 'buzdolabı içi silme', 'buzdolabı dezenfeksiyon'],
  'Fırın İçi Temizliği': ['fırın temizliği', 'fırın yağ temizliği', 'fırın camı temizliği'],
  'Dolap İçi Temizliği': ['dolap temizliği', 'mutfak dolabı içi temizlik', 'gardırop içi temizlik'],
  'Taşınma Öncesi Temizlik': ['taşınmadan önce temizlik', 'eve girmeden temizlik', 'boş ev temizliği'],
  'Dükkan Temizliği': ['mağaza temizliği', 'işyeri temizliği', 'dükkan temizlikçisi'],

  // ── Halı Yıkama ──
  'Bambu Halı Yıkama': ['bambu halı', 'bambu halı temizliği', 'ipeksi halı yıkama'],
  'Ofis Halı Yıkama': ['ofis halısı yıkama', 'yerinde ofis halı temizliği', 'karo halı yıkama'],

  // ── Kuru Temizleme ──
  'Kuru Temizleme': ['kuru temizlemeci', 'elbise temizleme', 'kuru temizleme hizmeti'],
  'Kıyafet Kuru Temizleme': ['takım elbise temizleme', 'mont temizleme', 'abiye temizleme'],
  'Perde Kuru Temizleme': ['perde temizleme', 'fon perde kuru temizleme', 'tül perde temizleme'],

  // ── Zemin ve Yüzey Temizliği ──
  'Mermer Cilalama': ['mermer cila', 'mermer parlatma', 'mermer zemin cilası'],
  'Mermer Silim': ['mermer silme', 'mermer zımpara', 'mermer yenileme'],
  'Zemin Cilalama': ['zemin cilası', 'yer cilalama', 'parke zemin cilası'],

  // ── Nakliyat ve Taşımacılık ──
  'Şehir İçi Nakliyat': ['şehir içi taşımacılık', 'şehir içi evden eve', 'izmir içi nakliyat'],
  'Minivan Nakliye': ['minivan taşıma', 'küçük araçla nakliye', 'az eşya taşıma'],
  'Yük Taşıma': ['yük taşımacılığı', 'kamyonetle yük taşıma', 'ağır yük taşıma'],
  'Koli Taşıma': ['koli nakliye', 'kutu taşıma', 'paket taşıma'],
  'Koltuk Taşıma': ['kanepe taşıma', 'koltuk takımı taşıma', 'tek parça mobilya taşıma'],
  'Buzdolabı Taşıma': ['beyaz eşya taşıma', 'buzdolabı nakliye', 'tek parça beyaz eşya taşıma'],
  'Çeyiz Taşıma': ['çeyiz nakliye', 'gelin eşyası taşıma', 'çeyiz götürme'],
  'Paletli Yük Taşıma': ['palet taşıma', 'paletli nakliye', 'forkliftli yük taşıma'],
  'Motosiklet Taşıma': ['motor taşıma', 'motosiklet nakliye', 'motosiklet çekme'],
  'Araç Taşıma': ['oto taşıma', 'araç nakliye', 'tırla araç taşıma'],
  'Uluslararası Nakliyat': ['yurtdışı nakliyat', 'yurtdışına ev taşıma', 'uluslararası ev taşıma'],
  'Eşya Paketleme Hizmeti': ['eşya paketleme', 'taşınma paketleme', 'ambalajlama hizmeti'],

  // ── Depolama Hizmetleri ──
  'Mini Depo': ['self depo', 'kiralık depo', 'küçük depo kiralama'],
  'Ticari Eşya Depolama': ['ticari depolama', 'stok depolama', 'işyeri eşyası depolama'],
  'Arşiv Depolama': ['arşiv saklama', 'evrak depolama', 'dosya arşivleme'],
  'Antrepo': ['antrepo hizmeti', 'gümrüklü depo', 'antrepo depolama'],

  // ── Kurye ve Küçük Taşıma ──
  'Arabalı Kurye': ['araçlı kurye', 'arabalı paket gönderimi', 'büyük paket kurye'],
  'Acil Kurye': ['hızlı kurye', 'aynı gün teslimat', 'acil paket gönderimi'],
  'Evrak Kurye': ['evrak gönderimi', 'belge kurye', 'dosya kurye'],

  // ── Personel ve Öğrenci Servisi ──
  'Personel Servisi': ['personel taşıma', 'işçi servisi', 'çalışan servisi'],
  'Fabrika Personel Servisi': ['fabrika servisi', 'fabrika işçi servisi', 'vardiya servisi'],
  'İş Yeri Personel Servisi': ['işyeri servisi', 'ofis personel servisi', 'şirket servisi'],
  'Öğrenci Servisi': ['öğrenci taşıma', 'servis aracı', 'kurs servisi'],
  'Okul Servisi': ['okul servis aracı', 'okula servis', 'servis şoförü'],
  'Servis Aracı Kiralama': ['servis minibüsü kiralama', 'şoförlü servis aracı', 'kiralık servis'],

  // ── Araç ve Ekipman Kiralama ──
  'Kamyonet Kiralama': ['kiralık kamyonet', 'kamyonet tutma', 'şoförlü kamyonet'],
  'Minibüs Kiralama': ['kiralık minibüs', 'şoförlü minibüs', 'minibüs tutma'],
  'Otobüs Kiralama': ['kiralık otobüs', 'şoförlü otobüs', 'gezi otobüsü kiralama'],
  'Panelvan Kiralama': ['kiralık panelvan', 'panelvan tutma', 'kapalı kasa araç kiralama'],

  // ── Güzellik ve Bakım Hizmetleri ──
  'Dövme Tattoo': ['dövme', 'tattoo', 'dövme yaptırma'],
  'Protez Tırnak Yapımı': ['protez tırnak', 'jel tırnak uygulaması', 'tırnak uzatma'],
  'Berber': ['erkek kuaförü', 'saç tıraşı', 'sakal tıraşı'],

  // ── Masaj ve Wellness ──
  'Masaj': ['masör', 'masaj hizmeti', 'rahatlama masajı'],
  'Evde Masaj': ['eve masaj', 'evde masör', 'adrese masaj'],
  'Spa Bakımı': ['spa', 'spa hizmeti', 'vücut bakımı'],

  // ── Spor ──
  'Personal Trainer': ['kişisel antrenör', 'özel antrenör', 'fitness hocası'],
  'Voleybol Dersi': ['voleybol antrenörü', 'voleybol eğitimi', 'voleybol hocası'],
  'Kiralık Kaleci': ['halı saha kalecisi', 'maç için kaleci', 'kaleci bulma'],
  'Dalış Eğitmeni': ['dalış dersi', 'tüplü dalış eğitimi', 'dalış kursu'],
  'Kayak Dersi': ['kayak hocası', 'kayak eğitmeni', 'kayak eğitimi'],
  'Binicilik Dersi': ['at binme dersi', 'binicilik eğitimi', 'ata binmeyi öğrenme'],

  // ── Kişisel Gelişim ve Koçluk ──
  'Yaşam Koçu': ['yaşam koçluğu', 'life coach', 'kişisel koç'],
  'Öğrenci Koçu': ['öğrenci koçluğu', 'ders çalışma koçu', 'öğrenci danışmanı'],
  'Eğitim Koçu': ['eğitim koçluğu', 'sınav hazırlık koçu', 'akademik koç'],

  // ── Evcil Hayvan Hizmetleri ──
  'Pet Oteli ve Pansiyon': ['köpek oteli', 'kedi oteli', 'hayvan pansiyonu'],
  'Pet Kreş Hizmeti': ['köpek kreşi', 'gündüz köpek bakımı', 'pet kreş'],
  'Kedi Bakımı': ['kedi bakıcısı', 'kedi bakım hizmeti', 'tatilde kedi bakımı'],
  'Kedi Gezdirme': ['kedi yürüyüşü', 'kedi dışarı çıkarma', 'tasmalı kedi gezdirme'],
  'Evcil Hayvan Gezdirme': ['hayvan gezdirme', 'pet yürüyüşü', 'pet gezdirme'],
  'Evcil Hayvan Bakıcısı': ['pet bakıcısı', 'hayvan bakıcısı', 'pet sitter'],
  'Evde Evcil Hayvan Bakımı': ['evde pet bakımı', 'evde hayvan bakımı', 'tatilde evde hayvan bakımı'],
  'Evcil Hayvan Eğitimi': ['pet eğitimi', 'hayvan eğitmeni', 'evcil hayvan itaat eğitimi'],
  'Kedi Kısırlaştırma': ['kedi kısırlaştırma ameliyatı', 'kedi kısırlaştırma operasyonu', 'dişi kedi kısırlaştırma'],
  'Köpek Kısırlaştırma': ['köpek kısırlaştırma ameliyatı', 'köpek kısırlaştırma operasyonu', 'köpek kastrasyon'],
  'Kedi Traşı': ['kedi tıraşı', 'kedi tüy kesimi', 'kedi kuaförü'],
  'Köpek Traşı': ['köpek tıraşı', 'köpek tüy kesimi', 'köpek kuaförü'],

  // ── Özel Ders ──
  'Okuma Yazma Özel Ders': ['okuma yazma öğretme', 'ilkokul okuma yazma dersi', 'okuma yazma hocası'],
  'Sınav Koçluğu': ['sınav koçu', 'lgs koçluğu', 'yks koçluğu'],
  'Disleksi Özel Ders': ['disleksi eğitimi', 'öğrenme güçlüğü dersi', 'disleksi destek'],
  'Diksiyon Dersi': ['diksiyon eğitimi', 'güzel konuşma dersi', 'hitabet dersi'],
  'Hızlı Okuma Dersi': ['hızlı okuma kursu', 'hızlı okuma eğitimi', 'anlayarak hızlı okuma'],
  'İşaret Dili Özel Ders': ['işaret dili dersi', 'işaret dili eğitimi', 'türk işaret dili'],

  // ── Yabancı Dil Eğitimi ──
  'İtalyanca Özel Ders': ['italyanca dersi', 'italyanca öğretmeni', 'italyanca kursu'],
  'Yabancılara Türkçe Öğretimi': ['yabancılara türkçe', 'türkçe öğretmeni', 'türkçe dersi yabancı'],

  // ── Sürücü Eğitimi ──
  'Motosiklet Direksiyon Dersi': ['motor ehliyeti dersi', 'motosiklet sürüş dersi', 'a2 ehliyet direksiyon'],

  // ── Müzik Dersleri ──
  'Ukulele Dersi': ['ukulele öğretmeni', 'ukulele kursu', 'ukulele eğitimi'],
  'Elektronik Piyano Dersi': ['org dersi', 'klavye dersi', 'dijital piyano dersi'],

  // ── Kodlama ve Yazılım Eğitimi ──
  'Çocuklar İçin Kodlama': ['çocuk kodlama dersi', 'scratch dersi', 'çocuklara yazılım eğitimi'],
  'Python Eğitimi': ['python dersi', 'python kursu', 'python öğretmeni'],
  'Web Geliştirme Eğitimi': ['web programlama dersi', 'html css eğitimi', 'web yazılım kursu'],

  // ── Teknik ve Hobi Eğitimleri ──
  'Drone Eğitimi': ['drone kullanma dersi', 'drone pilotluğu', 'drone uçurma eğitimi'],

  // ── Yazılım ve Web Hizmetleri ──
  'API Entegrasyonu': ['api bağlantısı', 'sistem entegrasyonu', 'yazılım entegrasyonu'],
  'Mobil Uygulama Bakımı': ['uygulama güncelleme', 'mobil uygulama desteği', 'uygulama bakım hizmeti'],
  'Web Uygulama Geliştirme': ['web uygulaması yaptırma', 'web tabanlı yazılım', 'özel web uygulaması'],

  // ── Dijital Pazarlama ──
  'Influencer Marketing': ['influencer reklamı', 'fenomen iş birliği', 'influencer pazarlama'],
  'Mobil Reklamcılık': ['mobil reklam', 'uygulama içi reklam', 'mobil reklam kampanyası'],
  'Reklam Ajansı': ['reklamcı', 'ajans hizmeti', 'reklam kampanyası hazırlama'],

  // ── Video ve Animasyon ──
  'Video Montajı': ['video kurgu', 'video düzenleme', 'montajcı'],
  'Reels ve Kısa Video Montajı': ['reels montajı', 'kısa video kurgusu', 'tiktok video montajı'],
  'Motion Graphics': ['hareketli grafik', 'motion tasarım', 'animasyonlu grafik'],
  '2D Animasyon': ['iki boyutlu animasyon', 'çizgi animasyon', 'animasyon video'],

  // ── Müzik & Ses Prodüksiyonu ──
  'Müzik Prodüksiyon': ['müzik prodüktörü', 'şarkı prodüksiyonu', 'beat yapımı'],
  'Ses Kayıt': ['stüdyo kaydı', 'ses kaydı', 'şarkı kaydı'],
  'Şarkı Aranje': ['aranjör', 'şarkı düzenleme', 'aranje yaptırma'],
  'Mix & Mastering': ['mix mastering', 'şarkı mix', 'mastering hizmeti'],
  'Jingle Yapımı': ['reklam müziği', 'jingle', 'kurumsal müzik yapımı'],
  'Müzik Yapımı': ['beste yaptırma', 'müzik besteleme', 'özel şarkı yapımı'],

  // ── Video, Ses & Animasyon ──
  'Seslendirme & Dublaj': ['seslendirme sanatçısı', 'dublaj hizmeti', 'reklam seslendirme'],
  'Seslendirme': ['seslendirmen', 'ses kaydı seslendirme', 'tanıtım seslendirmesi'],
  'Dublaj': ['film dublajı', 'dublaj sanatçısı', 'video dublaj'],

  // ── Etkinlik ve Organizasyon ──
  'Masa & Sandalye Kiralama': ['masa sandalye kiralama', 'kiralık sandalye', 'organizasyon masası kiralama'],
  'Palyaço': ['palyaço kiralama', 'doğum günü palyaçosu', 'çocuk partisi palyaço'],
  'Gelin Arabası Kiralama': ['gelin arabası', 'düğün arabası kiralama', 'klasik gelin arabası'],
  'Gelin Arabası Süsleme': ['gelin arabası süsü', 'düğün arabası süsleme', 'gelin arabası çiçek'],
  'Doğum Günü Mekanı Hizmeti': ['doğum günü mekanı', 'parti mekanı', 'çocuk doğum günü mekanı'],
  'Düğün Salonu Hizmeti': ['düğün salonu', 'nikah salonu', 'kına salonu'],

  // ── Fotoğraf Çekimi ──
  'Drone Çekimi': ['dronla çekim', 'havadan çekim', 'drone video çekimi'],

  // ── Catering ve İkram ──
  'Catering Hizmeti': ['yemek organizasyonu', 'toplu yemek', 'catering firması'],
  'Kokteyl İkram Hizmeti': ['kokteyl ikramı', 'kokteyl menüsü', 'ayaküstü ikram'],
  'Etkinlik Yemek Servisi': ['organizasyon yemeği', 'etkinlik yemeği', 'davet yemek servisi'],
  'Yaprak Sarma Yapımı': ['sarma yaptırma', 'zeytinyağlı sarma', 'yaprak sarması siparişi'],
  'Evde Yemek Pişirme': ['eve aşçı', 'ev yemeği yapma', 'evde aşçı'],
  'Tavuklu Pilav Yapımı': ['tavuklu pilav siparişi', 'toplu pilav', 'pilav dağıtımı'],
  'İrmik Helvası Yapımı': ['irmik helvası', 'helva dağıtımı', 'helva yaptırma'],
  'Aşure Yapımı': ['aşure', 'aşure dağıtımı', 'aşure siparişi'],
  'Çiğ Köfte Yapımı': ['çiğ köfte siparişi', 'çiğ köfte yoğurma', 'toplu çiğ köfte'],
  'İçli Köfte Yapımı': ['içli köfte siparişi', 'ev yapımı içli köfte', 'içli köfte yaptırma'],
  'Su Böreği Yapımı': ['su böreği siparişi', 'ev yapımı su böreği', 'su böreği yaptırma'],
  'Baklava Yapımı': ['ev baklavası', 'baklava siparişi', 'baklava yaptırma'],
  'Lahmacun Yapımı': ['lahmacun siparişi', 'toplu lahmacun', 'lahmacun yaptırma'],
  'Pide Yapımı': ['pide siparişi', 'toplu pide', 'pide yaptırma'],
  'Künefe Yapımı': ['künefe siparişi', 'künefe yaptırma', 'ev künefesi'],
  'Kurabiye Yapımı': ['kurabiye siparişi', 'ev kurabiyesi', 'kurabiye yaptırma'],
  'Kokoreç Yapımı': ['kokoreç siparişi', 'kokoreç standı', 'kokoreççi'],

  // ── Etkinlik Personeli ──
  'Garson': ['garson kiralama', 'servis elemanı', 'organizasyon garsonu'],
  'Servis Personeli': ['servis elemanı kiralama', 'ikram personeli', 'servis görevlisi'],
  'Host / Hostes': ['hostes', 'host', 'karşılama hostesi'],
  'Karşılama Personeli': ['karşılama görevlisi', 'misafir karşılama', 'resepsiyon görevlisi'],
  'Komi': ['komi kiralama', 'garson yardımcısı', 'servis komisi'],
  'Barmen / Bar Servis Personeli': ['barmen', 'bar personeli', 'kokteyl barmeni'],
  'Etkinlik Görevlisi': ['organizasyon görevlisi', 'etkinlik elemanı', 'saha görevlisi'],
  'Etkinlik Kurulum Personeli': ['organizasyon kurulum ekibi', 'sahne kurulum ekibi', 'etkinlik hazırlık ekibi'],
  'Etkinlik Söküm Personeli': ['organizasyon söküm ekibi', 'sahne söküm ekibi', 'etkinlik toplama ekibi'],
  'Vale Hizmeti': ['vale', 'vale parkı', 'otopark valesi'],

  // ── Müzik & Eğlence ──
  'Orkestra': ['düğün orkestrası', 'orkestra kiralama', 'canlı orkestra'],
  'Solist': ['şarkıcı', 'düğün şarkıcısı', 'solist kiralama'],
  'Canlı Müzik': ['canlı müzik grubu', 'mekana canlı müzik', 'akustik müzik'],
  'Müzik Grubu': ['grup kiralama', 'düğün müzik grubu', 'cover grup'],
  'DJ': ['dj kiralama', 'düğün djsi', 'parti djsi'],
  'Fasıl Ekibi': ['fasıl', 'fasıl grubu', 'türk sanat müziği fasıl'],
  'Davul Zurna': ['davulcu', 'zurnacı', 'düğün davul zurna'],
  'Bando Takımı': ['bando', 'bando kiralama', 'açılış bandosu'],
  'Mehter Takımı': ['mehter', 'mehter kiralama', 'sünnet mehteri'],
  'Dansöz': ['oryantal dansöz', 'dansöz kiralama', 'oryantal gösteri'],
  'Dansçı': ['dansçı kiralama', 'profesyonel dansçı', 'sahne dansçısı'],
  'Dans Ekibi': ['dans grubu', 'dans ekibi kiralama', 'halk oyunları ekibi'],
  'Dans Gösterisi': ['dans şovu', 'sahne dans gösterisi', 'düğün dans gösterisi'],

  // ── Fuar & Stand Hizmetleri ──
  'Stand Kurulumu': ['stand montajı', 'fuar standı kurulumu', 'tanıtım standı'],
  'Fuar Standı Tasarımı': ['stand tasarımı', 'fuar stand projesi', 'stand tasarımcısı'],
  'Fuar Standı Montajı': ['fuar stand kurulumu', 'stand kurulum ekibi', 'fuar montajı'],
  'Fuar Standı Sökümü': ['stand sökümü', 'fuar sonrası söküm', 'stand demontajı'],

  // ── İnşaat ve Kaba Yapı ──
  'Duvar Ustası': ['duvarcı', 'tuğla örme ustası', 'gazbeton duvar ustası'],
  'İnşaat Kalıp Ustası': ['kalıpçı', 'kalıp ustası', 'inşaat kalıpçısı'],
  'Beton Kalıp Ustası': ['beton kalıpçı', 'kolon kalıbı ustası', 'döşeme kalıbı'],
  'İnşaat Demir Ustası': ['demirci ustası', 'inşaat demircisi', 'betonarme demir ustası'],
  'Demir Bağlama Ustası': ['demir bağlayıcı', 'nervürlü demir bağlama', 'etriye bağlama'],
  'İnşaat Demir Döşeme': ['demir döşeme', 'betonarme demiri döşeme', 'temel demiri döşeme'],
  'Bina Güçlendirme': ['yapı güçlendirme', 'deprem güçlendirmesi', 'kolon güçlendirme'],
  'Şömine Yapımı': ['şömine', 'şömine yaptırma', 'odun şöminesi'],

  // ── Çatı Yapım ve Onarım ──
  'Çatı Oluk Bakımı': ['oluk temizliği', 'yağmur oluğu bakımı', 'çatı oluğu tamiri'],
  'Çatı Kiremit Tamiri': ['kiremit değişimi', 'kırık kiremit', 'kiremit aktarma'],

  // ── Tadilat ve Yenileme ──
  'Konut Tadilatı': ['ev tadilatı', 'daire tadilatı', 'komple ev yenileme'],
  'Bina Restorasyonu': ['restorasyon', 'tarihi bina restorasyonu', 'eski bina yenileme'],

  // ── Banyo Tadilat ve Montaj ──
  'Duşakabin Tamiri': ['duşakabin arızası', 'duşakabin kapısı tamiri', 'duşakabin tekerleği'],
  'Duşakabin Değişimi': ['duşakabin değiştirme', 'yeni duşakabin', 'duşakabin yenileme'],

  // ── Mutfak Tadilat ve Dolap ──
  'Mutfak Tezgahı Yapımı': ['tezgah yaptırma', 'mutfak tezgahı', 'çimstone tezgah'],

  // ── Boya ve Badana ──
  'Boya Öncesi Hazırlık': ['boya öncesi macun', 'duvar hazırlığı', 'zımpara ve astar'],

  // ── Duvar Kağıdı ve Dekorasyon ──
  'Çıta Uygulaması': ['duvar çıtası', 'çıta kaplama', 'dekoratif çıta'],
  'Dekoratif Duvar Çıtası': ['duvar çıtası uygulaması', 'çıtalı duvar', 'çıta dekor'],
  'MDF Çıta Uygulaması': ['mdf çıta', 'mdf duvar çıtası', 'mdf lambri'],
  'PVC Çıta Uygulaması': ['pvc çıta', 'pvc duvar çıtası', 'plastik çıta'],

  // ── Zemin Kaplama ──
  'Laminat Parke Döşeme': ['laminat parke', 'laminat döşeme', 'laminat parke ustası'],

  // ── Yalıtım ve Mantolama ──
  'Ses İzolasyonu Uygulaması': ['ses yalıtımı', 'ses izolasyonu', 'akustik yalıtım'],
  'Teras Su Yalıtımı': ['teras yalıtımı', 'teras su sızdırıyor', 'teras izolasyonu'],

  // ── PVC ve Alüminyum Doğrama ──
  'Pencere Sineklik Montajı': ['pencere sinekliği', 'sineklik takma', 'plise sineklik'],

  // ── Marangozluk ve Ahşap İşleri ──
  'Ahşap Restorasyon': ['ahşap yenileme', 'antika mobilya restorasyonu', 'ahşap onarımı'],

  // ── Mobilya Yapım ve Montaj ──
  'Korniş Montajı': ['korniş takma', 'perde rayı montajı', 'korniş asma'],

  // ── Havalandırma Sistemleri ──
  'Havalandırma Kanalı Montajı': ['havalandırma kanalı', 'hava kanalı montajı', 'kanal sistemi kurulumu'],
  'Davlumbaz Havalandırma Montajı': ['davlumbaz bacası', 'davlumbaz hattı', 'mutfak havalandırması'],
  'Menfez Açma': ['menfez', 'havalandırma deliği açma', 'duvara menfez'],

  // ── Çelik Yapı & Prefabrik Yapılar ──
  'Çelik Ev Yapımı': ['çelik ev', 'hafif çelik ev', 'çelik konstrüksiyon ev'],
  'Anahtar Teslim Prefabrik Ev': ['anahtar teslim ev', 'hazır prefabrik ev', 'prefabrik ev kurulumu'],
  'Prefabrik Ev Yapımı': ['prefabrik ev', 'prefabrik yapı', 'prefabrik konut'],
  'Prefabrik Ev Montajı': ['prefabrik montaj', 'prefabrik ev kurma', 'prefabrik ev kurulumu ekibi'],
  'Çelik Ev Montajı': ['çelik ev kurulumu', 'çelik yapı montajı', 'çelik ev kurma'],
  'Konteyner Yapımı': ['konteyner imalatı', 'konteyner üretimi', 'özel konteyner'],
  'Konteyner Ev': ['konteyner evi', 'yaşam konteyneri', 'konteynerden ev'],
  'Konteyner Ofis': ['ofis konteyneri', 'şantiye ofisi', 'büro konteyner'],
  'Konteyner Montajı': ['konteyner kurulumu', 'konteyner yerleştirme', 'konteyner sabitleme'],
  'Konteyner Demontajı': ['konteyner sökümü', 'konteyner kaldırma', 'konteyner söküm'],
  'Konteyner Taşıma': ['konteyner nakliye', 'vinçle konteyner taşıma', 'konteyner yer değişimi'],
  'Konteyner Tadilatı': ['konteyner yenileme', 'konteyner onarımı', 'konteyner iç düzenleme'],
  'Yangın Merdiveni': ['yangın merdiveni yapımı', 'çelik yangın merdiveni', 'acil çıkış merdiveni'],
  'Bungalov Ev Yapımı': ['bungalov', 'bungalov ev', 'ahşap bungalov'],
  'Tiny House Yapımı': ['tiny house', 'mini ev', 'tekerlekli ev'],
  'Konteyner Ev Yapımı': ['konteyner ev imalatı', 'konteyner ev yaptırma', 'konteyner ev üretimi'],

  // ── Pergola & Gölgelendirme Sistemleri ──
  'Alüminyum Pergola': ['alüminyum pergole', 'alüminyum gölgelik', 'bioklimatik pergola'],
  'Pergola Montajı': ['pergola kurulumu', 'pergola takma', 'pergola yaptırma'],
  'Pergola Kapatma': ['pergola kapatma sistemi', 'pergola cam kapatma', 'pergola branda kapatma'],
  'Pergola Tamiri': ['pergola arızası', 'pergola motoru tamiri', 'pergola onarımı'],
  'Tente': ['tente yaptırma', 'gölgelik tente', 'dükkan tentesi'],
  'Mafsallı Tente': ['mafsallı tente montajı', 'kollu tente', 'açılır kapanır tente'],
  'Otomatik Tente': ['motorlu tente', 'kumandalı tente', 'otomatik tente montajı'],
  'Balkon Tentesi': ['balkon gölgeliği', 'balkon tente montajı', 'balkona tente'],
  'Tente Tamiri': ['tente arızası', 'tente kolu tamiri', 'tente motoru tamiri'],
  'Tente Kumaş Değişimi': ['tente branda değişimi', 'tente bezi değişimi', 'tente kumaşı yenileme'],
  'Kış Bahçesi Sistemleri': ['kış bahçesi', 'cam kış bahçesi', 'kış bahçesi sistemi'],
  'Çardak & Kamelya': ['çardak', 'kamelya', 'bahçe kamelyası'],

  // ── Cam Film ve Kış Bahçesi ──
  'Cam Filmi Uygulama': ['cam filmi', 'cam film kaplama', 'pencere filmi'],
  'Güneş Kontrol Cam Filmi': ['güneş kırıcı film', 'ısı yalıtım filmi', 'güneş filmi'],
  'Güvenlik Cam Filmi': ['kırılmaz cam filmi', 'güvenlik filmi', 'patlamaya dayanıklı film'],
  'Dekoratif Cam Filmi': ['buzlu cam filmi', 'desenli cam filmi', 'dekoratif folyo'],
  'Cam Filmi Sökme': ['cam filmi sökümü', 'eski film çıkarma', 'cam filmi temizleme'],
  'Kış Bahçesi Yapımı': ['kış bahçesi yaptırma', 'kış bahçesi kurulumu', 'teras kış bahçesi'],
  'Kış Bahçesi Cam Sistemi': ['kış bahçesi camı', 'kış bahçesi cam tavan', 'kış bahçesi doğrama'],
  'Kış Bahçesi Kapatma': ['balkon kış bahçesi kapatma', 'teras kapatma', 'kış bahçesine dönüştürme'],
  'Kış Bahçesi Bakım ve Tadilat': ['kış bahçesi bakımı', 'kış bahçesi tamiri', 'kış bahçesi yenileme'],

  // ── Kapı Sistemleri ──
  'Çelik Kapı İmalatı': ['çelik kapı yaptırma', 'çelik kapı üretimi', 'özel ölçü çelik kapı'],
  'Çelik Kapı Değişimi': ['çelik kapı değiştirme', 'yeni çelik kapı', 'çelik kapı yenileme'],
  'Çelik Kapı Kilit Değişimi': ['çelik kapı kilidi', 'çelik kapı göbek değişimi', 'çelik kapı kilit yenileme'],
  'Çelik Kapı Kasa Değişimi': ['çelik kapı kasası', 'kapı kasası değişimi', 'çelik kasa yenileme'],
  'Fotoselli Otomatik Kapı': ['fotoselli kapı', 'otomatik cam kapı', 'sensörlü kapı'],
  'Garaj Kapı Sistemleri': ['garaj kapısı', 'otomatik garaj kapısı', 'seksiyonel garaj kapısı'],

  // ── Kepenk Sistemleri ──
  'Otomatik Kepenk': ['motorlu kepenk', 'kumandalı kepenk', 'dükkan kepengi'],
  'Otomatik Kepenk Montajı': ['kepenk montajı', 'kepenk takma', 'motorlu kepenk kurulumu'],
  'Otomatik Kepenk Tamiri': ['kepenk tamiri', 'kepenk açılmıyor', 'kepenk motoru tamiri'],
  'Otomatik Kepenk Servisi': ['kepenk servisi', 'kepenk bakımı', 'kepenk motor servisi'],
  'Garaj Kepengi': ['garaj kepenk', 'garaj için kepenk', 'otopark kepengi'],

  // ── Endüstriyel Yapı & Kurulum ──
  'Fabrika Kurulumu': ['fabrika kurma', 'tesis kurulumu', 'fabrika projesi'],
  'Fabrika Montajı': ['fabrika makine montajı', 'tesis montajı', 'fabrika kurulum ekibi'],
  'Endüstriyel Makine Montajı': ['makine montajı', 'üretim makinesi kurulumu', 'sanayi makinesi montajı'],
  'Üretim Tesisi Kurulumu': ['üretim hattı kurulumu', 'tesis kurma', 'üretim tesisi projesi'],

  // ── Cam & Alüminyum ──
  'Cam Tavan Sistemleri': ['cam tavan', 'cam çatı', 'ışıklık cam tavan'],
  'Lamine Cam': ['lamine cam üretimi', 'güvenlikli cam', 'katmanlı cam'],
  'Masa Camı İmalatı': ['masa camı', 'sehpa camı', 'temperli masa camı'],
  'Ofis Cam Bölme': ['cam bölme', 'ofis cam bölme sistemi', 'cam bölme duvar'],
  'Dekoratif Ayna Yapımı': ['dekoratif ayna', 'özel ölçü ayna', 'ayna yaptırma'],

  // ── Zemin & Beton ──
  'Baskı Beton': ['baskı beton uygulaması', 'desenli beton', 'stampa beton'],
  'Hazır Beton': ['hazır beton siparişi', 'beton mikseri', 'beton dökümü'],
  'İnşaat Temeli': ['temel kazısı', 'temel atma', 'radye temel'],

  // ── Sauna, Hamam & Spa ──
  'Sauna Yapımı': ['sauna', 'ev tipi sauna', 'sauna kurulumu'],
  'Hamam Yapımı': ['türk hamamı yapımı', 'ev hamamı', 'hamam kurulumu'],
  'Jakuzi': ['jakuzi montajı', 'jakuzi kurulumu', 'jakuzi tamiri'],
  'Spa Yapımı': ['spa merkezi yapımı', 'spa kurulumu', 'otel spa yapımı'],

  // ── Jeneratör Servisi ──
  'Jeneratör Servisi': ['jeneratör tamircisi', 'jeneratör teknik servis', 'jeneratör servisçisi'],
  'Jeneratör Bakımı': ['jeneratör periyodik bakım', 'jeneratör yağ değişimi', 'jeneratör bakım servisi'],
  'Jeneratör Arıza Onarımı': ['jeneratör arızası', 'jeneratör çalışmıyor', 'jeneratör tamiri'],
  'Jeneratör Devreye Alma': ['jeneratör devreye alınması', 'jeneratör ilk çalıştırma', 'jeneratör kurulumu'],

  // ── Kompresör ve Basınçlı Hava Sistemleri ──
  'Kompresör Servisi': ['kompresör teknik servis', 'hava kompresörü servisi', 'kompresör servisçisi'],
  'Kompresör Bakımı': ['kompresör periyodik bakım', 'kompresör yağ değişimi', 'vidalı kompresör bakımı'],
  'Kompresör Tamiri': ['kompresör arızası', 'kompresör çalışmıyor', 'kompresör onarımı'],
  'Kompresör Montajı': ['kompresör kurulumu', 'hava kompresörü montajı', 'kompresör yerleşimi'],
  'Basınçlı Hava Sistemi Kurulumu': ['basınçlı hava tesisatı', 'hava hattı kurulumu', 'pnömatik tesisat'],
  'Basınçlı Hava Hattı Bakımı': ['hava hattı bakımı', 'hava kaçağı tespiti', 'basınçlı hava tesisatı bakımı'],

  // ── Endüstriyel Makine ve Ekipman Servisi ──
  'Endüstriyel Makine Bakımı': ['makine bakımı', 'sanayi makinesi bakımı', 'periyodik makine bakımı'],
  'Endüstriyel Makine Arıza Tespiti': ['makine arıza tespiti', 'sanayi makinesi arızası', 'makine arıza analizi'],
  'Endüstriyel Makine Tamiri': ['makine tamiri', 'sanayi makinesi tamiri', 'üretim makinesi onarımı'],
  'Makine Kurulum ve Devreye Alma': ['makine devreye alma', 'makine kurulumu', 'üretim makinesi devreye alma'],
  'Pompa Servisi': ['pompa tamiri', 'su pompası servisi', 'santrifüj pompa bakımı'],
  'Endüstriyel Yıkama Makinesi Servisi': ['endüstriyel çamaşır makinesi servisi', 'sanayi tipi yıkama makinesi', 'endüstriyel bulaşık makinesi servisi'],

  // ── Endüstriyel Otomasyon ve Kontrol ──
  'PLC Programlama': ['plc yazılımı', 'plc programcı', 'otomasyon yazılımı'],
  'PLC Arıza ve Bakım': ['plc arızası', 'plc bakımı', 'plc tamiri'],
  'Otomasyon Panosu Yapımı': ['otomasyon panosu', 'kumanda panosu', 'elektrik kontrol panosu'],
  'Otomasyon Panosu Revizyonu': ['pano revizyonu', 'kumanda panosu yenileme', 'otomasyon pano güncelleme'],
  'Frekans İnverteri Kurulumu': ['frekans konvertörü', 'motor sürücü kurulumu', 'hız kontrol cihazı'],
  'Endüstriyel Otomasyon Devreye Alma': ['otomasyon devreye alma', 'otomasyon sistemi kurulumu', 'scada devreye alma'],

  // ── Ayakkabı ve Deri İşleri ──
  'Çanta Fermuar Değişimi': ['çanta fermuarı', 'çanta fermuar tamiri', 'bozuk çanta fermuarı'],
  'Deri/Süet Temizliği': ['deri temizleme', 'süet temizleme', 'deri ceket temizliği'],
  'Deri/Süet Boyama': ['deri boyama', 'süet boyama', 'deri ayakkabı boyama'],
  'Deri Ceket Tadilatı': ['deri ceket tamiri', 'deri mont tadilatı', 'deri ceket daraltma'],
  'Valiz Tekerlek Değişimi': ['bavul tekerleği', 'valiz tekerleği değiştirme', 'valiz tamiri'],

  // ── Ev Tekstili ──
  'Kırlent Dikimi': ['kırlent kılıfı dikimi', 'yastık kılıfı dikme', 'kırlent yaptırma'],
  'Masa Örtüsü Dikimi': ['masa örtüsü yaptırma', 'özel ölçü masa örtüsü', 'örtü dikimi'],
  'Nevresim Dikimi': ['nevresim takımı dikimi', 'özel ölçü nevresim', 'nevresim yaptırma'],
  'Battaniye Dikimi': ['battaniye yaptırma', 'pike dikimi', 'battaniye kenar dikişi'],
  'Perde Montajı ve Sökümü': ['perde takma', 'perde sökme', 'perde asma'],

  // ── Kumaş ve Tekstil İşleme ──
  'Kumaş Baskı': ['kumaşa baskı', 'dijital kumaş baskı', 'tekstil baskı'],
  'Kumaş Boyama': ['kumaş boyatma', 'tekstil boyama', 'kumaş renk değiştirme'],

  // ── Terzilik ve Dikim ──
  'Kişiye Özel Kıyafet Dikimi': ['özel dikim kıyafet', 'ısmarlama elbise', 'terziye kıyafet diktirme'],
  'Gelinlik Dikimi': ['gelinlik diktirme', 'özel gelinlik', 'gelinlik terzisi'],
  'Abiye Dikimi': ['abiye diktirme', 'özel abiye', 'gece elbisesi dikimi'],
  'Damatlık Dikimi': ['damatlık diktirme', 'ısmarlama damatlık', 'damatlık terzisi'],
  'Üniforma Dikimi': ['iş kıyafeti dikimi', 'personel kıyafeti dikimi', 'okul forması dikimi'],
  'Kostüm Dikimi': ['kostüm diktirme', 'sahne kostümü', 'tiyatro kostümü'],
  'Fermuar Değişimi': ['fermuar değiştirme', 'mont fermuarı', 'pantolon fermuarı'],
  'Düğme Değişimi': ['düğme dikme', 'düğme takma', 'düğme değiştirme'],
  'Astar Yenileme': ['astar değişimi', 'ceket astarı', 'mont astarı yenileme'],

  // ── Mimari Proje ──
  'Restorasyon Projesi': ['restorasyon çizimi', 'tarihi yapı projesi', 'koruma projesi'],
  'İç Mekân Projesi': ['iç mimari proje', 'iç mekan tasarımı', 'iç dekorasyon projesi'],
  'Vaziyet Planı': ['vaziyet planı çizimi', 'yerleşim planı', 'arsa yerleşim planı'],
  '3D Mimari Modelleme': ['3d mimari çizim', 'mimari görselleştirme', 'üç boyutlu mimari model'],

  // ── Statik ve Yapı Projeleri ──
  'Çelik Yapı Projesi': ['çelik yapı statik projesi', 'çelik konstrüksiyon projesi', 'çelik çatı projesi'],
  'Betonarme Yapı Projesi': ['betonarme proje', 'betonarme statik proje', 'betonarme hesap'],
  'Yapı Statiği Hesabı': ['statik hesap', 'statik hesaplama', 'yapı hesabı'],
  'Taşıyıcı Sistem Analizi': ['taşıyıcı sistem hesabı', 'yapı analizi', 'taşıyıcı sistem kontrolü'],
  'Yapı Hasar Tespiti': ['hasar tespit raporu', 'deprem hasar tespiti', 'bina hasar tespiti'],

  // ── Elektrik Projeleri ──
  'Elektrik Tesisat Projesi': ['elektrik tesisat çizimi', 'iç tesisat projesi', 'elektrik proje çizimi'],
  'Aydınlatma Projesi': ['aydınlatma tasarımı', 'aydınlatma hesabı', 'ışık projesi'],
  'Topraklama Projesi': ['topraklama hesabı', 'topraklama çizimi', 'topraklama tasarımı'],
  'Paratoner Projesi': ['yıldırımdan korunma projesi', 'paratoner hesabı', 'paratoner çizimi'],
  'Yangın Algılama Projesi': ['yangın algılama sistemi projesi', 'yangın ihbar projesi', 'dedektör projesi'],

  // ── Mekanik Projeler ──
  'Isıtma Projesi': ['ısıtma tesisatı projesi', 'kalorifer projesi', 'ısı kaybı hesabı'],
  'Sıhhi Tesisat Projesi': ['su tesisatı projesi', 'sıhhi tesisat çizimi', 'temiz su pis su projesi'],
  'Havalandırma Projesi': ['havalandırma tesisatı projesi', 'havalandırma hesabı', 'hava kanalı projesi'],
  'Klima Projesi': ['klima tesisatı projesi', 'iklimlendirme projesi', 'vrf projesi'],
  'Yangın Tesisatı Projesi': ['yangın tesisatı çizimi', 'sprinkler projesi', 'yangın dolabı projesi'],

  // ── Harita ve Ölçüm ──
  'Harita Ölçümü ve Aplikasyon': ['aplikasyon', 'harita aplikasyonu', 'zemin aplikasyonu'],
  'Plankote': ['plankote çizimi', 'kotlu plan', 'plankote ölçümü'],
  'Halihazır Harita': ['halihazır harita çizimi', 'mevcut durum haritası', 'halihazır ölçümü'],
  'Kotlu Kroki': ['kotlu kroki çizimi', 'arsa krokisi', 'kroki ölçümü'],
  'Parsel Ölçümü': ['parsel sınırı ölçümü', 'tapu parsel ölçümü', 'parsel tespiti'],
  'İmar Uygulaması': ['imar uygulaması işlemi', 'imar parselasyonu', 'imar düzenlemesi'],
  'Arazi Ölçümü': ['arazi ölçtürme', 'tarla ölçümü', 'arazi sınır tespiti'],

  // ── Zemin ve Jeoteknik ──
  'Jeolojik Etüt': ['jeolojik inceleme', 'jeoloji raporu', 'jeolojik araştırma'],
  'Jeoteknik Etüt': ['jeoteknik rapor', 'jeoteknik inceleme', 'zemin jeoteknik raporu'],
  'Zemin Sondajı': ['sondaj', 'zemin sondaj kuyusu', 'sondaj ile zemin araştırması'],
  'Zemin Analizi': ['zemin testi', 'zemin numunesi analizi', 'zemin laboratuvar analizi'],

  // ── Enerji ve Yapı Belgelendirme ──
  'Enerji Performans Analizi': ['enerji verimliliği analizi', 'enerji performansı hesabı', 'bina enerji analizi'],

  // ── Proje Danışmanlığı ──
  'Proje Yönetimi': ['proje müdürü', 'inşaat proje yönetimi', 'proje koordinasyonu'],
  'Teknik Şartname Hazırlama': ['teknik şartname', 'şartname yazımı', 'ihale şartnamesi'],
  'Metraj ve Keşif': ['metraj', 'keşif özeti', 'metraj çıkarma'],
  'Yaklaşık Maliyet Hesabı': ['maliyet hesabı', 'inşaat maliyeti hesaplama', 'yaklaşık maliyet'],
  'Proje Kontrol ve Teknik Danışmanlık': ['proje kontrolü', 'teknik danışman', 'proje denetimi'],

  // ── Yapı Denetim ──
  'Yapı Denetim Hizmeti': ['yapı denetim firması', 'yapı denetim', 'yapı denetçisi'],
  'Yapı Denetim Proje Kontrolü': ['proje inceleme', 'denetim proje kontrolü', 'ruhsat proje kontrolü'],
  'İnşaat Kontrolü': ['şantiye kontrolü', 'inşaat denetimi', 'yapım kontrolü'],
  'Hakediş Kontrolü': ['hakediş', 'hakediş hesabı', 'hakediş inceleme'],
  'Beton ve Yapı Malzemesi Kontrolü': ['beton testi', 'beton numunesi', 'malzeme kontrolü'],

  // ── Avukatlık ve Hukuk ──
  'İş Hukuku Uyuşmazlıkları': ['iş avukatı', 'işçi alacağı davası', 'tazminat davası'],
  'İcra ve İflas Hukuku': ['icra avukatı', 'icra takibi', 'alacak tahsili'],
  'Tüketici Uyuşmazlıkları': ['tüketici avukatı', 'tüketici hakem heyeti', 'ayıplı mal davası'],
  'Gayrimenkul ve Kira Uyuşmazlıkları': ['kira avukatı', 'kiracı tahliye davası', 'tapu davası'],
  'Miras ve Veraset İşlemleri': ['miras avukatı', 'veraset ilamı', 'mirasçılık belgesi'],
  'Aile ve Boşanma Hukuku': ['boşanma avukatı', 'velayet davası', 'nafaka davası'],
  'Ceza Hukuku Danışmanlığı': ['ceza avukatı', 'ağır ceza avukatı', 'ceza davası danışmanlığı'],
  'Ticaret ve Şirketler Hukuku': ['şirket avukatı', 'ticari dava', 'ticaret hukuku avukatı'],
  'Arabuluculuk Hizmeti': ['arabulucu', 'arabuluculuk', 'uzlaştırma'],

  // ── Muhasebe ve Mali Müşavirlik ──
  'Şirket Kuruluş Danışmanlığı': ['şirket kurma', 'şirket kuruluşu', 'şahıs şirketi açma'],
  'E-Fatura ve E-Arşiv Danışmanlığı': ['e-fatura', 'e-arşiv fatura', 'e-fatura geçişi'],
  'Bordro ve Özlük Hizmetleri': ['bordro', 'maaş bordrosu', 'özlük işleri'],
  'Mali Müşavirlik Danışmanlığı': ['mali müşavir', 'muhasebeci', 'smmm danışmanlık'],
  'Vergi Uyuşmazlık Danışmanlığı': ['vergi davası', 'vergi cezası itiraz', 'vergi uzlaşması'],

  // ── İş Güvenliği ve İSG ──
  'İSG Risk Değerlendirmesi': ['risk değerlendirme raporu', 'isg risk analizi', 'iş güvenliği risk analizi'],
  'İş Yeri İSG Denetimi': ['isg denetimi', 'iş güvenliği denetimi', 'iş yeri güvenlik denetimi'],

  // ── Marka ve Patent ──
  'Marka İtirazı': ['marka itiraz', 'marka başvurusuna itiraz', 'marka yayın itirazı'],

  // ── Ofis & İş Yeri Hizmetleri ──
  'Hazır Ofis': ['hazır ofis kiralama', 'mobilyalı ofis', 'kiralık hazır ofis'],
  'Sanal Ofis': ['sanal ofis adresi', 'yasal adres hizmeti', 'sanal ofis kiralama'],
  'E-Ofis': ['e ofis', 'dijital ofis adresi', 'eofis hizmeti'],
  'Toplantı Odası Kiralama': ['kiralık toplantı odası', 'saatlik toplantı salonu', 'toplantı salonu kiralama'],
  'Paylaşımlı Ofis': ['ortak çalışma alanı', 'coworking', 'paylaşımlı çalışma alanı'],
  'Sekreterya Hizmeti': ['sekreter hizmeti', 'sekreterlik', 'dış kaynak sekreterya'],
  'Çağrı Karşılama Hizmeti': ['telefon karşılama', 'çağrı merkezi hizmeti', 'telefon sekreterliği'],

  // ── Dış Ticaret & Gümrük ──
  'Gümrük Müşaviri': ['gümrük müşavirliği', 'gümrükçü', 'gümrük komisyoncusu'],
  'Gümrük Danışmanlığı': ['gümrük danışmanı', 'gümrük mevzuatı danışmanlığı', 'gümrük işlemleri desteği'],
  'İthalat İşlemleri': ['ithalat', 'ithalat danışmanlığı', 'mal ithal etme'],
  'İhracat İşlemleri': ['ihracat', 'ihracat danışmanlığı', 'yurtdışına satış'],
  'Gümrük İşlemleri Danışmanlığı': ['gümrükleme', 'gümrük beyannamesi', 'gümrük işlemleri'],

  // ── Tercüme ve Çeviri Hizmetleri ──
  'Yeminli Tercüme': ['yeminli tercüman', 'yeminli çeviri', 'resmi tercüme'],
  'İngilizce Yeminli Tercüme': ['ingilizce yeminli tercüman', 'ingilizce resmi çeviri', 'ingilizce belge tercümesi'],
  'Almanca Yeminli Tercüme': ['almanca yeminli tercüman', 'almanca resmi çeviri', 'almanca belge tercümesi'],
  'Noter Onaylı Tercüme': ['noter tasdikli tercüme', 'noter onaylı çeviri', 'tercüme noter onayı'],
  'Sözlü Tercüme': ['simultane tercüme', 'ardıl çeviri', 'tercüman refakati'],
  'Teknik Çeviri': ['teknik tercüme', 'kullanım kılavuzu çevirisi', 'mühendislik çevirisi'],
  'Akademik Çeviri': ['akademik tercüme', 'makale çevirisi', 'tez çevirisi'],
  'Hukuki Metin Çevirisi': ['hukuki tercüme', 'sözleşme çevirisi', 'mahkeme kararı çevirisi'],

  // ── Teşvik & Hibe Danışmanlığı ──
  'KOSGEB Danışmanlığı': ['kosgeb desteği', 'kosgeb başvurusu', 'kosgeb hibe'],
  'Teşvik Danışmanlığı': ['devlet teşviki', 'teşvik başvurusu', 'teşvik belgesi'],
  'Hibe Danışmanlığı': ['hibe başvurusu', 'hibe programı', 'proje hibesi'],
  'Yatırım Teşvik Danışmanlığı': ['yatırım teşvik belgesi', 'yatırım teşviki', 'teşvikli yatırım'],
  'Devlet Destekleri Danışmanlığı': ['devlet desteği', 'devlet destek başvurusu', 'kamu destekleri'],
  'İşe Alım Danışmanlığı': ['personel seçme', 'insan kaynakları danışmanlığı', 'eleman bulma'],
  'Girişim Danışmanlığı': ['girişimcilik danışmanlığı', 'startup danışmanlığı', 'iş kurma danışmanlığı'],
  'Üretim Danışmanlığı': ['üretim planlama danışmanlığı', 'verimlilik danışmanlığı', 'fabrika danışmanlığı'],
  'Ticari Danışmanlık': ['iş danışmanlığı', 'işletme danışmanlığı', 'ticari strateji'],
  'Şirket Satışı Danışmanlığı': ['şirket satışı', 'şirket değerleme', 'şirket devri'],
  'ArGe Danışmanlığı': ['arge danışmanlığı', 'ar-ge projesi', 'tübitak projesi danışmanlığı'],
  'Satış Danışmanlığı': ['satış stratejisi', 'satış eğitimi danışmanlığı', 'satış artırma danışmanlığı'],

  // ── Hasta Bakımı ──
  'Günlük Hasta Bakımı': ['gündüzlü hasta bakıcısı', 'günlük hasta bakıcısı', 'saatlik hasta bakımı'],
  'Yatılı Hasta Bakımı': ['yatılı hasta bakıcısı', 'gece kalan hasta bakıcısı', '24 saat hasta bakımı'],
  'Hasta Öz Bakım': ['hasta kişisel bakım', 'hastanın öz bakımı', 'hasta bakım desteği'],
  'Hasta Beslenme': ['hasta yemek yedirme', 'hasta beslenme desteği', 'hastaya yemek hazırlama'],
  'Hasta Hijyen ve Banyo': ['hasta banyosu', 'yatalak hasta temizliği', 'hasta hijyeni'],
  'Hasta Giyinme ve Günlük Yaşam': ['hasta giydirme', 'hastaya günlük yardım', 'hasta günlük destek'],
  'Hasta Mobilizasyon': ['hasta yürütme', 'hasta hareket ettirme', 'yataktan kaldırma'],

  // ── Yaşlı Bakımı ──
  'Günlük Yaşlı Bakımı': ['gündüzlü yaşlı bakıcısı', 'günlük yaşlı bakıcısı', 'saatlik yaşlı bakımı'],
  'Yatılı Yaşlı Bakımı': ['yatılı yaşlı bakıcısı', 'yaşlıya yatılı bakıcı', '24 saat yaşlı bakımı'],
  'Yaşlı Öz Bakım': ['yaşlı kişisel bakım', 'yaşlı bakım desteği', 'yaşlının öz bakımı'],
  'Yaşlı Beslenme': ['yaşlıya yemek yedirme', 'yaşlı beslenme desteği', 'yaşlıya yemek hazırlama'],
  'Yaşlı Hijyen ve Banyo': ['yaşlı banyosu', 'yaşlı temizliği', 'yaşlı hijyeni'],
  'Yaşlı Giyinme ve Günlük Yaşam': ['yaşlı giydirme', 'yaşlıya günlük yardım', 'yaşlı günlük destek'],
  'Yaşlı Gezdirme': ['yaşlı yürüyüşü', 'yaşlıyı dışarı çıkarma', 'yaşlıya eşlik'],
  'Alzheimer ve Demans Bakımı': ['alzheimer bakıcısı', 'demans bakıcısı', 'unutkan yaşlı bakımı'],
  'Yaşlı Refakat': ['yaşlı refakatçisi', 'yaşlıya refakat', 'yaşlı arkadaşlığı'],
  'Yaşlı Alışveriş Refakati': ['yaşlıyla alışverişe gitme', 'yaşlı için alışveriş', 'yaşlıya pazar alışverişi'],
  'Yaşlı Randevu Refakati': ['yaşlıyı doktora götürme', 'yaşlı hastane randevusu', 'yaşlıya randevu eşliği'],
  'Yaşlı Sosyal Aktivite Refakati': ['yaşlıyla etkinliğe gitme', 'yaşlı sosyal etkinlik', 'yaşlıyla vakit geçirme'],

  // ── Evde Hasta Bakımı ──
  'Evde Günlük Hasta Bakımı': ['evde gündüz hasta bakımı', 'eve günlük hasta bakıcısı', 'evde saatlik hasta bakımı'],
  'Evde Hasta Öz Bakım': ['evde hasta kişisel bakım', 'evde hasta bakım desteği', 'evde hastanın öz bakımı'],
  'Evde Hasta Beslenme': ['evde hasta yemek yedirme', 'evde hasta beslenme desteği', 'evde hastaya yemek'],
  'Evde Hasta Hijyen ve Banyo': ['evde hasta banyosu', 'evde yatalak hasta temizliği', 'evde hasta hijyeni'],
  'Evde Hasta Giyinme': ['evde hasta giydirme', 'evde hastayı giydirme', 'evde hasta giyinme desteği'],
  'Evde Hasta Mobilizasyon': ['evde hasta yürütme', 'evde hasta hareket ettirme', 'evde yataktan kaldırma'],
  'Evde Hasta Refakati': ['evde hasta refakatçisi', 'evde hastaya refakat', 'evde hasta yanında kalma'],
  'Evde Hasta Günlük Yaşam Yardımı': ['evde hastaya günlük yardım', 'evde hasta ev işleri desteği', 'evde hasta günlük destek'],
  'Evde Hasta Alışveriş Yardımı': ['hasta için alışveriş', 'evde hastaya market alışverişi', 'hastaya ihtiyaç alma'],
  'Evde Hasta Sosyal Refakati': ['evde hastayla vakit geçirme', 'hasta sohbet arkadaşı', 'evde hasta sosyal destek'],

  // ── Evde Yaşlı Bakımı ──
  'Evde Günlük Yaşlı Bakımı': ['evde gündüz yaşlı bakımı', 'eve günlük yaşlı bakıcısı', 'evde saatlik yaşlı bakımı'],
  'Evde Yaşlı Öz Bakım': ['evde yaşlı kişisel bakım', 'evde yaşlı bakım desteği', 'evde yaşlının öz bakımı'],
  'Evde Yaşlı Beslenme': ['evde yaşlıya yemek yedirme', 'evde yaşlı beslenme desteği', 'evde yaşlıya yemek'],
  'Evde Yaşlı Hijyen ve Banyo': ['evde yaşlı banyosu', 'evde yaşlı temizliği', 'evde yaşlı hijyeni'],
  'Evde Yaşlı Giyinme': ['evde yaşlı giydirme', 'evde yaşlıyı giydirme', 'evde yaşlı giyinme desteği'],
  'Evde Yaşlı Mobilizasyon': ['evde yaşlı yürütme', 'evde yaşlıyı hareket ettirme', 'evde yaşlı yürüme desteği'],
  'Evde Yaşlı Refakati': ['evde yaşlı refakatçisi', 'evde yaşlıya refakat', 'evde yaşlının yanında kalma'],
  'Evde Alzheimer ve Demans Bakımı': ['evde alzheimer bakımı', 'evde demans bakımı', 'evde alzheimer bakıcısı'],
  'Evde Yaşlı Günlük Yaşam Yardımı': ['evde yaşlıya günlük yardım', 'evde yaşlı ev işleri desteği', 'evde yaşlı günlük destek'],
  'Evde Yaşlı Alışveriş Yardımı': ['yaşlı için market alışverişi', 'evde yaşlıya ihtiyaç alma', 'yaşlıya alışveriş yardımı'],
  'Evde Yaşlı Sosyal Refakati': ['evde yaşlıyla vakit geçirme', 'yaşlı sohbet arkadaşı', 'evde yaşlı sosyal destek'],

  // ── Hastane Refakatçisi ──
  'Hastane Hasta Refakati': ['hastanede hasta refakatçisi', 'hastanede refakat', 'hasta yanında kalma'],
  'Hastane Yaşlı Refakati': ['hastanede yaşlı refakatçisi', 'hastanede yaşlıya refakat', 'yaşlı hasta refakatçisi'],
  'Hastane Gece Refakati': ['hastanede gece refakatçisi', 'gece hasta refakatçisi', 'hastanede gece kalma'],
  'Hastane Gündüz Refakati': ['hastanede gündüz refakatçisi', 'gündüz hasta refakatçisi', 'hastanede gündüz kalma'],
  'Hastane Yatılı Refakat': ['hastanede yatılı refakatçi', 'hastanede 24 saat refakat', 'yatılı hasta refakatçisi'],
  'Hastane Taburculuk Refakati': ['taburcu refakati', 'hastaneden eve götürme', 'taburculukta eşlik'],

  // ── Evde Refakat ──
  'Gece Evde Refakat': ['gece refakatçisi', 'evde gece kalan refakatçi', 'gece bakıcısı'],
  'Gündüz Evde Refakat': ['gündüz refakatçisi', 'evde gündüz refakatçi', 'gündüz bakıcısı'],
  'Yatılı Evde Refakat': ['yatılı refakatçi', 'evde yatılı kalan refakatçi', 'yatılı bakıcı'],
  'Randevu ve Hastane Gidiş Refakati': ['hastaneye götürme', 'doktor randevusuna eşlik', 'hastane refakati'],
  'Alışveriş Refakati': ['alışverişe eşlik', 'alışveriş arkadaşı', 'pazara götürme'],
  'Günlük İşlere Refakat': ['günlük işlere eşlik', 'banka işlerine eşlik', 'resmi işlere refakat'],
  'Sosyal Aktivite Refakati': ['etkinliğe eşlik', 'sosyal etkinlik refakatçisi', 'gezmeye eşlik'],

  // ── Günlük Yaşam Desteği ──
  'Kişisel Bakım': ['kişisel bakım desteği', 'öz bakım yardımı', 'bakım yardımı'],
  'Banyo ve Hijyen': ['banyo yaptırma', 'banyo desteği', 'hijyen desteği'],
  'Giyinme ve Soyunma': ['giyinme yardımı', 'giydirme desteği', 'soyunma yardımı'],
  'Beslenme ve Yemek': ['yemek yedirme', 'beslenme desteği', 'yemek hazırlama yardımı'],
  'Ev İçinde Günlük Yaşam Yardımı': ['ev içi günlük yardım', 'evde günlük destek', 'ev işlerine yardım'],
  'Alışveriş ve Temel İhtiyaç Yardımı': ['ihtiyaç alışverişi', 'temel ihtiyaç desteği', 'market alışverişi yardımı'],
  'Yürüyüş ve Sosyal Aktivite Refakati': ['yürüyüşe eşlik', 'yürüyüş arkadaşı', 'sosyal aktiviteye eşlik'],
  'Randevu ve Günlük İşlere Refakat': ['randevuya eşlik', 'günlük işlerde refakat', 'resmi işlerde eşlik'],

  // ── Geleneksel ve Tamamlayıcı Sağlık Uygulamaları ──
  'Kupa Uygulaması (Hacamat)': ['hacamat', 'kupa çekme', 'hacamat yaptırma'],
  'Sülük Uygulaması (Hirudoterapi)': ['sülük tedavisi', 'hirudoterapi', 'sülük uygulaması'],
  'Akupunktur Uygulaması': ['akupunktur', 'akupunktur tedavisi', 'akupunkturcu'],
  'Apiterapi Uygulaması': ['apiterapi', 'arı sokması tedavisi', 'arı ürünleriyle tedavi'],
  'Fitoterapi Uygulaması': ['fitoterapi', 'bitkisel tedavi', 'bitkisel destek uygulaması'],
  'Larva (Maggot) Uygulaması': ['maggot tedavisi', 'larva tedavisi', 'yara larva uygulaması'],
  'Osteopati Uygulaması': ['osteopati', 'osteopat', 'osteopatik tedavi'],
  'Müzikterapi Uygulaması': ['müzik terapisi', 'müzikterapi', 'müzikle terapi'],
  'Refleksoloji Uygulaması': ['refleksoloji', 'ayak refleksolojisi', 'refleksoloji masajı'],
  'Hipnoz Uygulaması': ['hipnoz', 'hipnoterapi', 'hipnoz seansı'],
  'Homeopati Uygulaması': ['homeopati', 'homeopatik tedavi', 'homeopat'],
  'Mezoterapi Uygulaması': ['mezoterapi', 'mezoterapi seansı', 'bölgesel mezoterapi'],
  'Ozon Uygulaması': ['ozon tedavisi', 'ozon terapisi', 'majör ozon'],
  'Proloterapi Uygulaması': ['proloterapi', 'proloterapi tedavisi', 'proloterapi enjeksiyonu'],
  'Kayropraktik Uygulaması': ['kayropraktik', 'kayropraktör', 'chiropractic'],

  // ── Psikolojik Danışmanlık ve Terapi ──
  'Psikolog': ['psikolojik destek', 'psikoloğa gitme', 'terapist'],
  'Online Psikolog': ['internetten psikolog', 'görüntülü psikolog', 'online terapi'],
  'Klinik Psikolog': ['klinik psikoloji', 'uzman klinik psikolog', 'klinik terapist'],
  'Yetişkin Psikolog': ['yetişkin terapisi', 'yetişkin psikolojik danışmanlık', 'yetişkin terapist'],
  'Çocuk Psikoloğu': ['çocuk psikolog', 'çocuk terapisti', 'çocuk psikolojik danışmanlık'],
  'Ergen Psikoloğu': ['ergen psikolog', 'genç psikoloğu', 'ergen terapisti'],
  'Online Çocuk Psikoloğu': ['online çocuk psikolog', 'görüntülü çocuk psikoloğu', 'internetten çocuk terapisi'],
  'Online Ergen Psikolog': ['online ergen psikoloğu', 'görüntülü ergen terapisi', 'internetten ergen psikolog'],
  'Aile Danışmanı': ['aile danışmanlığı', 'aile danışman', 'evlilik danışmanı'],
  'Aile Terapisi': ['aile terapisti', 'aile içi terapi', 'aile seansı'],
  'Çift Terapisi': ['çift terapisti', 'evlilik terapisi', 'ilişki terapisi'],
  'Online Çift Terapisi': ['online evlilik terapisi', 'görüntülü çift terapisi', 'internetten ilişki terapisi'],
  'Bilişsel Davranışçı Terapi': ['bilişsel davranışçı terapist', 'bdt terapisi', 'bilişsel terapi'],
  'EMDR Terapisi': ['emdr', 'emdr terapisti', 'travma terapisi'],
  'Oyun Terapisi': ['oyun terapisti', 'çocuk oyun terapisi', 'oyunla terapi'],
  'Dil ve Konuşma Terapisi': ['dil konuşma terapisti', 'konuşma terapisi', 'kekemelik terapisi'],
  'Pedagog': ['çocuk pedagogu', 'pedagog danışmanlığı', 'çocuk gelişim uzmanı'],
  'Online Psikoterapi': ['online terapi seansı', 'görüntülü psikoterapi', 'internetten psikoterapi'],
  'Online Psikolojik Danışman': ['online psikolojik danışmanlık', 'görüntülü danışman', 'internetten psikolojik destek'],

  // ── Diyetisyen ve Beslenme Danışmanlığı ──
  'Diyetisyen': ['diyet uzmanı', 'diyet listesi', 'zayıflama diyetisyeni'],
  'Online Diyetisyen': ['online diyet', 'görüntülü diyetisyen', 'internetten diyet takibi'],
  'Beslenme Danışmanlığı': ['beslenme uzmanı', 'sağlıklı beslenme programı', 'beslenme planı'],
  'Spor Beslenmesi Danışmanlığı': ['sporcu beslenmesi', 'sporcu diyetisyeni', 'kas gelişimi beslenme'],

  // ── Fizyoterapi ve Rehabilitasyon ──
  'Fizyoterapist': ['fizyoterapi', 'fizik tedavi uzmanı', 'fizik tedavi'],
  'Evde Fizik Tedavi': ['evde fizyoterapi', 'eve fizyoterapist', 'evde rehabilitasyon'],
  'Ergoterapi': ['ergoterapist', 'iş uğraşı terapisi', 'ergoterapi seansı'],
  'Manuel Terapi': ['manuel terapist', 'elle tedavi', 'manuel terapi seansı'],
  'Manuel Lenf Drenajı': ['lenf drenajı', 'lenf ödemi masajı', 'lenfatik drenaj'],

  // ── Evde Hemşirelik Hizmetleri ──
  'Evde Hemşire': ['eve hemşire', 'evde hemşirelik', 'özel hemşire'],
  'Evde Serum Takma': ['eve serum', 'evde serum', 'serum taktırma'],
  'Evde Enjeksiyon': ['evde iğne', 'eve iğne yapma', 'evde enjeksiyon yapan hemşire'],
  'Evde Pansuman': ['eve pansuman', 'evde yara bakımı', 'evde pansuman yapma'],

  // ── Tarım Danışmanlığı ──
  'Tarım Danışmanlığı': ['tarım danışmanı', 'çiftçi danışmanlığı', 'tarımsal danışmanlık'],
  'Ziraat Danışmanlığı': ['ziraat mühendisi', 'ziraat danışmanı', 'zirai danışmanlık'],
  'Tarımsal Sulama Danışmanlığı': ['sulama danışmanı', 'tarla sulama planı', 'sulama projesi danışmanlığı'],

  // ── Tarla ve Bahçe İşleri ──
  'Tarla Sürme': ['traktörle sürme', 'tarla sürümü', 'toprak sürme'],
  'Toprak Hazırlama': ['ekime hazırlık', 'toprak işleme', 'tarla hazırlığı'],
  'Ekim Hizmeti': ['tohum ekimi', 'ekim makinesi', 'tarla ekimi'],
  'Hasat Hizmeti': ['hasat', 'biçerdöver', 'ürün hasadı'],
  'Budama': ['ağaç budama', 'meyve ağacı budama', 'bağ budama'],
  'Aşılama': ['ağaç aşılama', 'fidan aşılama', 'meyve ağacı aşısı'],
  'Ot Biçme': ['ot biçimi', 'tırpan', 'yabani ot biçme'],
  'Çapalama': ['çapa', 'tarla çapalama', 'bahçe çapası'],
  'Meyve Toplama': ['meyve hasadı', 'zeytin toplama', 'meyve toplayıcı'],

  // ── Tarımsal Sulama ──
  'Tarımsal Sulama Sistemi Kurulumu': ['tarla sulama sistemi', 'sulama sistemi kurma', 'tarımsal sulama kurulumu'],
  'Tarımsal Sulama Sistemi Bakımı': ['tarla sulama bakımı', 'sulama sistemi tamiri', 'tarımsal sulama servisi'],
  'Damla Sulama Sistemi': ['damla sulama', 'damlama sulama', 'damla sulama borusu'],
  'Yağmurlama Sulama Sistemi': ['yağmurlama sulama', 'yağmurlama sistemi', 'sprink sulama'],

  // ── Bitki Koruma ve İlaçlama ──
  'Tarım İlaçlama': ['tarla ilaçlama', 'tarımsal ilaçlama', 'ekin ilaçlama'],
  'Bitki Hastalıkları ve Zararlılarıyla Mücadele': ['zararlı mücadelesi', 'bitki zararlısı', 'hastalık ve zararlı ilaçlaması'],
  'Zirai İlaçlama': ['zirai mücadele', 'bağ ilaçlama', 'meyve bahçesi ilaçlama'],
  'Sera İlaçlama': ['sera zararlısı', 'sera ilaçlaması', 'serada ilaçlama'],

  // ── Hayvancılık Hizmetleri ──
  'Büyükbaş Hayvancılık Danışmanlığı': ['büyükbaş danışmanlığı', 'süt sığırcılığı danışmanlığı', 'besi danışmanlığı'],
  'Küçükbaş Hayvancılık Danışmanlığı': ['küçükbaş danışmanlığı', 'koyun keçi yetiştiriciliği', 'ağıl danışmanlığı'],
  'At Pansiyonu': ['at barınağı', 'at bakımı pansiyonu', 'at ahırı kiralama'],

  // ── Veteriner Hizmetleri ──
  'Veteriner Hekim': ['veteriner', 'hayvan doktoru', 'veteriner muayenesi'],
  'Evde Veteriner Hizmeti': ['eve veteriner', 'evde veteriner muayenesi', 'mobil veteriner'],
  'Hayvan Aşılama': ['hayvan aşısı', 'kedi aşısı', 'köpek aşısı'],
  'Hayvan Sağlığı Danışmanlığı': ['hayvan sağlığı', 'çiftlik hayvanı sağlığı', 'veteriner danışmanlığı'],

  // ── Tur Organizasyon ──
  'Tur Organizasyonu': ['tur düzenleme', 'gezi organizasyonu', 'grup turu'],
  'Günübirlik Tur': ['günübirlik gezi', 'günübirlik tur programı', 'bir günlük tur'],
  'Kültür Turu': ['tarihi yerler turu', 'kültür gezisi', 'antik kent turu'],
  'Doğa Turu': ['doğa yürüyüşü turu', 'trekking turu', 'kamp turu'],
  'Tekne Turu': ['tekne gezisi', 'koy turu', 'mavi tur'],
  'Özel Tur Organizasyonu': ['özel tur', 'kişiye özel gezi', 'vip tur'],
  'Balık Turu': ['balık avı turu', 'olta turu', 'tekneyle balık tutma'],
  'Kaptanlı Yat Kiralama': ['yat kiralama', 'kaptanlı yat', 'günlük yat kiralama'],
  'Tekne Kiralama Hizmeti': ['tekne kiralama', 'kiralık tekne', 'günlük tekne kiralama'],
  'Düğün Teknesi Hizmeti': ['düğün teknesi', 'teknede düğün', 'nişan teknesi'],

  // ── Konaklama ──
  'Otel Rezervasyonu': ['otel ayarlama', 'otel bulma', 'otel odası rezervasyonu'],
  'Pansiyon Rezervasyonu': ['pansiyon ayarlama', 'pansiyon bulma', 'pansiyon odası'],
  'Villa Kiralama': ['kiralık villa', 'havuzlu villa kiralama', 'tatil villası'],
  'Günlük Ev Kiralama': ['günlük kiralık ev', 'günlük daire', 'kısa süreli ev kiralama'],
  'Bungalov Kiralama': ['kiralık bungalov', 'bungalov tatili', 'bungalov ev kiralama'],
  'Apart Konaklama': ['apart otel', 'apart daire', 'apart kiralama'],
  'Karavan Kiralama Hizmeti': ['karavan kiralama', 'kiralık karavan', 'karavan tatili'],

  // ── Transfer ve Ulaşım ──
  'Havalimanı Transferi': ['havaalanı transferi', 'havalimanından alma', 'havalimanına götürme'],
  'VIP Transfer': ['vip araç transferi', 'lüks transfer', 'vip transfer hizmeti'],
  'Şoförlü Araç Hizmeti': ['şoförlü araç kiralama', 'şoförlü araba', 'araç ve şoför'],
  'Turizm Transferi': ['turist transferi', 'otel transferi', 'tur transferi'],
  'Özel Araç Tahsisi': ['araç tahsisi', 'özel araç kiralama', 'şoförlü özel araç'],
  'Taksi': ['taksi çağırma', 'taksici', 'taksi hizmeti'],
  'Saatlik Şoför': ['saatlik şoför kiralama', 'kısa süreli şoför', 'saat başı şoför'],
  'Karavan Transfer Hizmeti': ['karavan çekme', 'karavan taşıma', 'karavan transferi'],
  'Tekne Transfer Hizmeti': ['tekneyle transfer', 'deniz taksi', 'tekne ile ulaşım'],
  'Özel Şoför Hizmeti': ['özel şoför', 'kişisel şoför', 'aile şoförü'],
  'Tekne Çekme Hizmeti': ['tekne çekme', 'tekne römork taşıma', 'tekne karaya çekme'],

  // ── Seyahat Danışmanlığı ──
  'Seyahat Planlama': ['seyahat planı', 'gezi planlama', 'rota planlama'],
  'Tatil Planlama': ['tatil planı', 'tatil ayarlama', 'tatil önerisi'],
  'Yurtiçi Tatil Organizasyonu': ['yurtiçi tatil', 'yurtiçi tur', 'türkiye tatili'],
  'Yurtdışı Tatil Organizasyonu': ['yurtdışı tatil', 'yurtdışı tur', 'yurtdışı gezi'],

  // ── Rehberlik ──
  'Profesyonel Turist Rehberi': ['turist rehberi', 'profesyonel rehber', 'kokartlı rehber'],
  'Özel Tur Rehberi': ['özel rehber', 'kişiye özel rehber', 'özel gezi rehberi'],
  'Şehir Turu Rehberi': ['şehir rehberi', 'şehir gezisi rehberi', 'izmir turu rehberi'],
  'Müze ve Kültür Turu Rehberi': ['müze rehberi', 'kültür turu rehberi', 'ören yeri rehberi'],

  // ── Vize & Seyahat İşlemleri ──
  'Vize Danışmanı': ['vize danışmanlığı', 'vize işlemleri', 'vize takibi'],
  'Vize Başvurusu': ['vize başvurusu yapma', 'vize alma', 'schengen vizesi'],
  'Vize Evrak Hazırlama': ['vize evrakı', 'vize dosyası hazırlama', 'vize belgeleri'],
  'Vize Randevu İşlemleri': ['vize randevusu', 'konsolosluk randevusu', 'vize randevu alma'],

  // ── Emlak Danışmanlığı ──
  'Konut Alım Satım Danışmanlığı': ['ev satma', 'ev alma danışmanlığı', 'daire alım satım'],
  'Konut Kiralama Danışmanlığı': ['ev kiralama', 'kiralık daire bulma', 'kiracı bulma'],
  'İşyeri Alım Satım Danışmanlığı': ['dükkan satışı', 'işyeri satın alma', 'ticari gayrimenkul satışı'],
  'İşyeri Kiralama Danışmanlığı': ['kiralık dükkan', 'işyeri kiralama', 'ofis kiralama'],
  'Arsa Alım Satım Danışmanlığı': ['arsa satışı', 'arsa alma', 'tarla satışı'],
  'Gayrimenkul Danışmanlığı': ['gayrimenkul danışmanı', 'emlak danışmanı', 'emlakçı'],
  'Emlak Değerleme Danışmanlığı': ['ev değerleme', 'gayrimenkul değerleme', 'ekspertiz raporu konut'],

  // ── Site ve Apartman Yönetimi ──
  'Site Yönetimi': ['site yöneticisi', 'site yönetim firması', 'site yönetim hizmeti'],
  'Apartman Yönetimi': ['apartman yöneticisi', 'bina yönetimi', 'apartman yönetim hizmeti'],
  'Profesyonel Apartman Yönetimi': ['profesyonel bina yönetimi', 'apartman yönetim şirketi', 'dışarıdan apartman yöneticisi'],
  'Profesyonel Site Yönetimi': ['site yönetim şirketi', 'profesyonel site yöneticisi', 'dışarıdan site yönetimi'],
  'Aidat Yönetimi': ['aidat takibi', 'aidat toplama', 'aidat hesaplama'],
  'Site Yönetim Danışmanlığı': ['site yönetim danışmanı', 'kat mülkiyeti danışmanlığı', 'site yönetim planı'],

  // ── Gayrimenkul Hizmetleri ──
  'Emlak Drone Çekimi': ['emlak drone videosu', 'arsa drone çekimi', 'gayrimenkul havadan çekim'],
  'Gayrimenkul Kiralama Yönetimi': ['kira yönetimi', 'kiralık mülk yönetimi', 'kira takibi'],
  'Kiralık Ev Yönetimi': ['kiralık daire yönetimi', 'ev kiraya verme yönetimi', 'kiracı takibi'],
  'Gayrimenkul İlan Yönetimi': ['emlak ilanı yönetimi', 'ilan verme hizmeti', 'emlak ilan hazırlama'],
  'Gayrimenkul Fotoğraf Çekimi': ['emlak fotoğrafı', 'ev fotoğraf çekimi', 'emlak fotoğrafçısı'],
  'Gayrimenkul Video Çekimi': ['emlak videosu', 'ev tanıtım videosu', 'emlak video çekimi'],

  // ── Özel Güvenlik ──
  'Özel Güvenlik Hizmeti': ['özel güvenlik firması', 'güvenlik hizmeti', 'güvenlik şirketi'],
  'Site Özel Güvenlik': ['site güvenliği', 'site güvenlik görevlisi', 'konut sitesi güvenliği'],
  'İşyeri Özel Güvenlik': ['işyeri güvenliği', 'fabrika güvenliği', 'mağaza güvenliği'],
  'Etkinlik Özel Güvenlik': ['etkinlik güvenliği', 'konser güvenliği', 'düğün güvenliği'],
  'Organizasyon Güvenliği': ['organizasyon güvenlik ekibi', 'etkinlik güvenlik görevlisi', 'kapı güvenliği'],

  // ── Yakın Koruma ──
  'Yakın Koruma': ['koruma', 'bodyguard', 'yakın koruma görevlisi'],
  'Kişisel Koruma': ['kişisel koruma görevlisi', 'özel koruma', 'şahıs koruma'],
  'Etkinlik Yakın Koruma': ['etkinlikte koruma', 'sanatçı koruması', 'organizasyon koruması'],

  // ── Güvenlik Personeli ──
  'Güvenlik Görevlisi': ['güvenlikçi', 'bekçi', 'güvenlik elemanı'],
  'Gece Güvenliği': ['gece bekçisi', 'gece güvenlik görevlisi', 'gece nöbeti'],
  'Gündüz Güvenliği': ['gündüz bekçisi', 'gündüz güvenlik görevlisi', 'gündüz nöbeti'],
  'Özel Etkinlik Güvenliği': ['özel davet güvenliği', 'özel etkinlik güvenlik ekibi', 'vip etkinlik güvenliği'],

  // ── Kartvizit & Kurumsal Baskı ──
  'Kartvizit Baskı': ['kartvizit bastırma', 'kartvizit basımı', 'iş kartı baskısı'],
  'Antetli Kağıt Baskı': ['antetli kağıt', 'firma antetli kağıdı', 'antet baskısı'],
  'Zarf Baskı': ['logolu zarf', 'zarf basımı', 'kurumsal zarf'],
  'Fatura Baskı': ['fatura bastırma', 'matbu fatura', 'fatura koçanı'],
  'İrsaliye Baskı': ['sevk irsaliyesi baskısı', 'irsaliye koçanı', 'irsaliye bastırma'],
  'Kaşe Yapımı': ['kaşe', 'firma kaşesi', 'mühür yapımı'],

  // ── Broşür & Tanıtım Baskıları ──
  'Broşür Baskı': ['broşür bastırma', 'broşür basımı', 'tanıtım broşürü'],
  'El İlanı Baskı': ['el ilanı', 'el ilanı bastırma', 'reklam ilanı baskısı'],
  'Flyer Baskı': ['flyer', 'flyer bastırma', 'tanıtım flyerı'],
  'Katalog Baskı': ['katalog bastırma', 'ürün kataloğu', 'katalog basımı'],
  'Afiş Baskı': ['afiş', 'afiş bastırma', 'reklam afişi'],
  'Poster Baskı': ['poster', 'poster bastırma', 'büyük boy poster'],

  // ── Davetiye & Özel Gün Baskıları ──
  'Davetiye Baskı': ['davetiye', 'davetiye bastırma', 'davetiye basımı'],
  'Düğün Davetiyesi Baskı': ['düğün davetiyesi', 'düğün davetiye bastırma', 'evlilik davetiyesi'],
  'Nişan Davetiyesi Baskı': ['nişan davetiyesi', 'nişan davetiye bastırma', 'söz davetiyesi'],
  'Doğum Günü Davetiyesi Baskı': ['doğum günü davetiyesi', 'parti davetiyesi', 'çocuk doğum günü davetiyesi'],

  // ── Etiket & Ambalaj Baskıları ──
  'Etiket Baskı': ['etiket bastırma', 'etiket basımı', 'yapışkanlı etiket'],
  'Sticker Baskı': ['sticker', 'sticker bastırma', 'çıkartma baskısı'],
  'Ürün Etiketi Baskı': ['ürün etiketi', 'şişe etiketi', 'kavanoz etiketi'],
  'Ambalaj Baskı': ['ambalaj basımı', 'baskılı ambalaj', 'ürün ambalajı'],
  'Kutu Baskı': ['baskılı kutu', 'karton kutu baskısı', 'kutu basımı'],
  'Poşet Baskı': ['baskılı poşet', 'logolu poşet', 'karton çanta baskısı'],

  // ── Promosyon Baskıları ──
  'Magnet Baskı': ['magnet', 'buzdolabı magneti', 'magnet bastırma'],
  'Takvim Baskı': ['takvim', 'duvar takvimi', 'masa takvimi'],
  'Bloknot Baskı': ['bloknot', 'logolu bloknot', 'not defteri baskısı'],
  'Ajanda Baskı': ['ajanda', 'logolu ajanda', 'kurumsal ajanda'],
  'Promosyon Ürün Baskısı': ['promosyon ürün', 'logolu kupa', 'logolu kalem'],

  // ── Kitap & Yayın Baskıları ──
  'Kitap Baskı': ['kitap bastırma', 'kitap basımı', 'kitap matbaası'],
  'Dergi Baskı': ['dergi bastırma', 'dergi basımı', 'bülten baskısı'],
  'Tez Baskı': ['tez bastırma', 'tez çıktısı', 'tez cildi'],
  'Ciltleme': ['cilt yaptırma', 'spiral cilt', 'kitap ciltleme'],

  // ── 3D Baskı & Üretim ──
  '3D Baskı': ['3d yazıcı', 'üç boyutlu baskı', '3d çıktı'],
  '3D PLA Baskı': ['pla baskı', 'pla filament', 'pla ile baskı'],
  '3D ABS Baskı': ['abs baskı', 'abs filament', 'abs ile baskı'],
  '3D PETG Baskı': ['petg baskı', 'petg filament', 'petg ile baskı'],
  '3D Prototip Baskı': ['prototip baskı', 'hızlı prototipleme', 'prototip üretimi'],
  'Kişiye Özel 3D Baskı': ['kişiye özel baskı', 'özel tasarım 3d', 'hediye 3d baskı'],
  '3D Modelden Baskı': ['stl dosyası baskı', 'modelden baskı', 'stl baskı'],
  '3D Yedek Parça Baskı': ['yedek parça baskı', 'kırık parça baskısı', 'plastik parça üretimi'],

  // ── Tabela & Reklam Uygulamaları ──
  'Tabela': ['tabela yaptırma', 'dükkan tabelası', 'tabelacı'],
  'Işıklı Tabela': ['ışıklı tabela', 'led tabela', 'neon tabela'],
  'Kutu Harf Tabela': ['kutu harf', 'harf tabela', 'ışıklı kutu harf'],
  'Kompozit Tabela': ['kompozit', 'alüminyum kompozit tabela', 'kompozit cephe tabela'],
  'Branda Tabela': ['branda', 'vinil branda', 'branda baskı'],
  'Tabela Montajı': ['tabela takma', 'tabela asma', 'tabela kurulumu'],

  // ── Geri Dönüşüm Hizmetleri ──
  'Tekstil Geri Dönüşüm': ['eski kıyafet geri dönüşümü', 'kumaş geri dönüşümü', 'tekstil atığı geri dönüşümü'],
  'Plastik Geri Dönüşüm': ['plastik atık geri dönüşümü', 'pet şişe geri dönüşümü', 'plastik hurda'],
  'Kağıt ve Karton Geri Dönüşüm': ['atık kağıt', 'karton toplama', 'kağıt hurdası'],
  'Metal Geri Dönüşüm': ['metal hurda', 'demir hurda', 'bakır hurda'],
  'Elektronik Atık Geri Dönüşüm': ['elektronik atık', 'e-atık', 'eski elektronik toplama'],
  'Ahşap Geri Dönüşüm': ['ahşap atık', 'palet geri dönüşümü', 'odun atığı'],
  'Tekstil Atık Toplama': ['kumaş atığı toplama', 'tekstil hurdası toplama', 'parça kumaş toplama'],
  'Plastik Atık Toplama': ['plastik toplama', 'pet şişe toplama', 'plastik hurda toplama'],
  'Hurdacı': ['hurda alımı', 'hurdacı çağırma', 'eski eşya hurda'],
  'Atık Ayrıştırma ve Sınıflandırma': ['atık ayrıştırma', 'çöp ayrıştırma', 'atık sınıflandırma'],
  'Cam Geri Dönüşüm': ['cam şişe geri dönüşümü', 'cam atık', 'cam hurda'],

  // ── Bebek Bakımı ──
  'Bebek Bakıcısı': ['bebek bakıcı', 'bebek dadısı', 'bebeğe bakacak kişi'],
  'Saatlik Bebek Bakımı': ['saatlik bebek bakıcısı', 'birkaç saatlik bebek bakımı', 'saat başı bebek bakıcı'],
  'Gündüzlü Bebek Bakıcısı': ['gündüz bebek bakıcısı', 'gündüzcü bebek bakıcı', 'gündüz bebek bakımı'],
  'Yatılı Bebek Bakıcısı': ['yatılı bebek bakıcı', 'evde kalan bebek bakıcısı', 'yatılı dadı'],
  'Yenidoğan Bebek Bakımı': ['yenidoğan bakıcısı', 'lohusa bakımı', 'yeni doğmuş bebek bakımı'],
  'İkiz Bebek Bakımı': ['ikiz bebek bakıcısı', 'ikizlere bakıcı', 'ikiz bakımı'],

  // ── Çocuk Bakımı ──
  'Çocuk Bakıcısı': ['çocuk bakıcı', 'dadı', 'çocuğa bakacak kişi'],
  'Saatlik Çocuk Bakımı': ['saatlik çocuk bakıcısı', 'birkaç saatlik çocuk bakımı', 'saat başı çocuk bakıcı'],
  'Gündüzlü Çocuk Bakıcısı': ['gündüz çocuk bakıcısı', 'gündüzcü çocuk bakıcı', 'gündüz çocuk bakımı'],
  'Yatılı Çocuk Bakıcısı': ['yatılı çocuk bakıcı', 'evde kalan çocuk bakıcısı', 'yatılı çocuk dadısı'],
  'Çocuk Bakımı ve Ev Yardımcısı': ['bakıcı ve ev yardımcısı', 'çocuk bakıcısı ve temizlik', 'ev işi ve çocuk bakımı'],
  'Okul Sonrası Çocuk Bakımı': ['okul çıkışı bakıcı', 'okul sonrası bakıcı', 'okuldan sonra çocuk bakımı'],

  // ── Oyun & Gelişim Desteği ──
  'Oyun Ablası / Oyun Abisi': ['oyun ablası', 'oyun abisi', 'çocukla oyun oynayacak kişi'],
  'Çocuk Etkinlik ve Oyun Desteği': ['çocuk etkinliği', 'çocuk oyun desteği', 'çocuk aktivite desteği'],
  'Ebeveynli Oyun Grubu': ['anne çocuk oyun grubu', 'ebeveyn çocuk etkinliği', 'oyun grubu'],

  // ── Çocuk Refakat ve Destek ──
  'Okul Gidiş-Geliş Refakati': ['okula götürme getirme', 'okul refakatçisi', 'çocuğu okula bırakma'],
  'Çocuk Etkinlik Refakati': ['kursa götürme', 'etkinliğe eşlik', 'çocuk etkinlik eşliği'],
  'Çocuk Gezi Refakati': ['çocuk gezi eşliği', 'geziye eşlik', 'çocuk gezisi refakatçisi'],
  'Gölge Öğretmen': ['gölge öğretmenlik', 'kaynaştırma öğretmeni', 'sınıf içi destek öğretmeni'],

  // ── Çiçekçilik ──
  'Çiçekçi': ['çiçek siparişi', 'çiçek dükkanı', 'çiçek satışı'],
  'Buket Hazırlama': ['buket', 'gül buketi', 'çiçek buketi'],
  'Çiçek Aranjmanı': ['aranjman', 'masa aranjmanı', 'kutuda çiçek'],
  'Çelenk Hazırlama': ['çelenk', 'cenaze çelengi', 'tebrik çelengi'],
  'Özel Gün Çiçekleri': ['sevgililer günü çiçeği', 'anneler günü çiçeği', 'doğum günü çiçeği'],
  'Açılış Çiçekleri': ['açılış çiçeği', 'açılış çelengi', 'ayaklı çiçek'],
  'Düğün Çiçekleri': ['gelin buketi', 'gelin arabası süsleme', 'düğün çiçek süslemesi'],
  'Çiçek Gönderme': ['çiçek gönder', 'online çiçek', 'adrese çiçek teslimi'],
  'Butik Sabun Yapımı': ['el yapımı sabun', 'butik sabun', 'doğal sabun yapımı'],
  'Mum Yapımı': ['el yapımı mum', 'kokulu mum', 'dekoratif mum'],
  'Mum İmalatı': ['toptan mum', 'mum üretimi', 'mum fabrikası'],

  // ── Asistanlık & Günlük Destek ──
  'Günlük Asistan': ['günlük yardımcı asistan', 'gün boyu asistan', 'yarı zamanlı asistan'],
  'Kişisel Asistan': ['kişisel yardımcı', 'personal assistant', 'şahsi asistan'],
  'Özel Asistan': ['özel kalem', 'birebir asistan', 'özel yardımcı'],
  'Sanal Asistan': ['online asistan', 'uzaktan asistan', 'virtual assistant'],
  'Yönetici Asistanı': ['sekreter', 'yönetici sekreteri', 'idari asistan'],
  'Randevu ve Takvim Yönetimi': ['randevu takibi', 'takvim yönetimi', 'ajanda yönetimi'],
  'Evrak ve Dosya Takibi': ['evrak takibi', 'dosya takibi', 'resmi işlem takibi'],
  'Günlük İş Takibi': ['iş takibi', 'günlük işlerin takibi', 'ayak işleri'],
  'Veri Girişi': ['data girişi', 'veri giriş elemanı', 'excel veri girişi'],

  // ── Dedektiflik & Araştırma ──
  'Özel Dedektif': ['dedektif', 'özel araştırmacı', 'dedektiflik bürosu'],
  'Kişi Araştırması': ['kişi sorgulama', 'şahıs araştırması', 'geçmiş araştırması'],
  'Adres Tespiti': ['adres bulma', 'adres araştırması', 'ikamet tespiti'],
  'Kayıp Kişi Araştırması': ['kayıp kişi bulma', 'kayıp yakın arama', 'kaybolan kişi'],
  'Ticari Araştırma': ['firma araştırması', 'şirket istihbaratı', 'ticari istihbarat'],
  'Saha Araştırması': ['saha incelemesi', 'yerinde araştırma', 'saha tespiti'],
  'Delil Toplama': ['delil tespiti', 'kanıt toplama', 'ispat için delil'],

  // ── Araştırma & Saha Hizmetleri ──
  'Pazar Araştırması': ['pazar analizi', 'hedef pazar araştırması', 'pazar raporu'],
  'Piyasa Araştırması': ['piyasa analizi', 'sektör araştırması', 'piyasa raporu'],
  'Gizli Müşteri': ['mystery shopper', 'gizli müşteri denetimi', 'gizli alışverişçi'],
  'Anket': ['anket yaptırma', 'kamuoyu yoklaması', 'online anket'],
  'Anketör Hizmeti': ['anketör', 'saha anketörü', 'yüz yüze anket'],
  'Müşteri Memnuniyeti Araştırması': ['memnuniyet anketi', 'müşteri memnuniyet ölçümü', 'nps anketi'],
  'Müşteri Deneyimi Araştırması': ['müşteri deneyimi', 'kullanıcı deneyimi araştırması', 'deneyim analizi'],
  'Rakip Araştırması': ['rakip analizi', 'rakip firma analizi', 'rekabet analizi'],
  'Ürün Araştırması': ['ürün analizi', 'ürün testi', 'ürün karşılaştırma'],

  // ── Günlük Eleman & Personel Desteği ──
  'Günlük Eleman': ['günlükçü', 'yevmiyeli eleman', 'günlük işçi'],
  'Günlük Yardımcı Eleman': ['yardımcı eleman', 'günlük yardımcı', 'yevmiyeli yardımcı'],
  'Geçici Personel': ['geçici işçi', 'geçici eleman', 'dönemsel personel'],
  'Kısa Süreli Personel': ['kısa süreli eleman', 'proje bazlı personel', 'süreli personel'],
  'İş Gücü Desteği': ['işgücü temini', 'personel temini', 'eleman desteği'],
  'Depo Yardımcı Personeli': ['depo elemanı', 'depo işçisi', 'depocu'],
  'Yükleme / Boşaltma Personeli': ['hamal', 'yükleme boşaltma', 'kamyon boşaltma'],
  'Genel Yardımcı Personel': ['genel yardımcı', 'yardımcı personel', 'getir götür elemanı'],

  // ── Nikah ve Tören Hizmetleri ──
  'İmam Nikahı Kıyma': ['imam nikahı', 'dini nikah', 'nikah kıyacak hoca'],
  'Nikah Duası': ['nikah duası okuma', 'düğün duası', 'nikahta dua'],
  'Nikah Şekeri Yapımı': ['nikah şekeri', 'düğün şekeri', 'nikah hediyeliği'],

  // ── Mevlüt ve Dua Programları ──
  'Mevlüt Okuma': ['mevlüt', 'mevlit okutma', 'mevlüthan'],
  'Hatim Okuma': ['hatim', 'hatim duası', 'hatim indirme'],
  'Dua Programı': ['dua okuma', 'toplu dua', 'dua meclisi'],
  'Mevlüt Pilavı Yapımı': ['mevlüt pilavı', 'hayır pilavı', 'pilav dağıtımı'],
  'Lokma Yapımı': ['lokma tatlısı', 'hayır lokması', 'lokma'],
  'Lokma Döktürme Hizmeti': ['lokma döktürme', 'lokma arabası', 'lokma dağıtımı'],

  // ── Kur'an-ı Kerim Eğitimi ──
  'Kur\'an-ı Kerim Özel Dersi': ['kuran dersi', 'kuran öğrenme', 'kuran hocası'],
  'Tecvid Dersi': ['tecvit', 'tecvid', 'tecvitli okuma'],
  'Hafızlık Eğitimi': ['hafızlık', 'hafız hocası', 'ezber kuran'],

  // ── İlahi ve Dini Musiki ──
  'İlahi Okuma': ['ilahi', 'ilahici', 'ilahi grubu'],

  // ── Bileme ve Keskinleştirme Hizmetleri ──
  'Bıçak Bileme': ['bıçak bilemek', 'bıçak bileyici', 'bileyici'],
  'Makas Bileme': ['makas bilemek', 'kuaför makası bileme', 'terzi makası bileme'],
};

