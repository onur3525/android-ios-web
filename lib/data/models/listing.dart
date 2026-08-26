import '../../domain/config.dart';

/// İLANIN YAŞAM DURUMU — nihai dört değer (API sözleşmesi §24).
///
/// ── ⚠ DURUM İLE TAMAMLANMIŞLIK AYRI KAVRAMLARDIR ──
///
/// Eskiden altı değer vardı: `open · providerSelected · inProgress ·
/// completed · cancelled · expired`. Bunların dördü ilanın yaşamını
/// değil, İŞİN GİDİŞATINI anlatıyordu ve iki kavram tek alanda
/// karışıyordu.
///
/// Nihai ayrım şudur:
///   · `ListingStatus`  → ilan yaşıyor mu, süresi mi doldu, silindi mi
///   · `selectedOfferId` → iş tamamlandı mı
///
/// ⚠ TAMAMLANMIŞLIK ARTIK BİR DURUM DEĞİLDİR. `isTamamlanmisIs`
/// yardımcısı (bu dosyanın altında) tek kaynaktır; ekranlar kendi
/// koşulunu YAZMAZ.
///
/// ⚠ ESKİ DEĞERLER YENİ ADLA GERİ GETİRİLMEZ: `finished`, `done`,
/// `working`, `selected`, `removed` gibi karşılıklar üretilmeyecek.
enum ListingStatus {
  /// Yaşıyor: teklif kabul edebilir. Seçilmiş teklifi olsa bile
  /// ilanın kendisi ACTIVE kalır — tamamlanmışlık ayrı alandadır.
  active,

  /// 30 saat doldu; yeni teklif ve yeni iletişim açma yapılamaz.
  expired,

  /// Kullanıcı kendi ilanını sildi.
  userDeleted,

  /// Admin kaldırdı (gerekçeli).
  adminRemoved,
}


/// İŞİN NE ZAMAN YAPILMASI İSTENDİĞİ.
///
/// ⚠ İSTEĞE BAĞLIDIR: alan `null` olabilir ve olması normaldir.
/// Kullanıcı hiçbir şey seçmeden ilan verebilir; seçim yapılmadıysa
/// ilanda zaman bilgisi HİÇ GÖSTERİLMEZ.
///
/// ⚠ ÜÇ SEÇENEK KESİNDİR. "Acil", "Bugün", "Yarın", "Planlı" gibi
/// başka değerler EKLENMEZ; tarih seçici de yoktur (ürün kararı).
enum IsZamani {
  hemen,
  buHafta,
  esnek;

  /// Kullanıcıya ve hizmet verene gösterilen etiket.
  ///
  /// ⚠ TEK KAYNAK: ekranlar kendi metnini yazmaz, ikisi de buradan
  /// okur; oluşturma ile görüntüleme ayrışmaz.
  String get etiket => switch (this) {
        IsZamani.hemen => 'Hemen',
        IsZamani.buHafta => 'Bu hafta',
        IsZamani.esnek => 'Esnek zaman',
      };

  /// Sunucuya gidecek değer.
  String get kod => switch (this) {
        IsZamani.hemen => 'NOW',
        IsZamani.buHafta => 'THIS_WEEK',
        IsZamani.esnek => 'FLEXIBLE',
      };

  /// ⚠ BİLİNMEYEN DEĞER `null` DÖNER, hata fırlatmaz: sunucu ileride
  /// yeni bir değer gönderirse uygulama çökmez, yalnız etiket
  /// gösterilmez.
  static IsZamani? koddan(String? k) => switch (k) {
        'NOW' => IsZamani.hemen,
        'THIS_WEEK' => IsZamani.buHafta,
        'FLEXIBLE' => IsZamani.esnek,
        _ => null,
      };
}

class Listing {
  final String id;       // değişmez UUID

  /// ── KULLANICIYA GÖSTERİLEN İLAN NUMARASI ──
  ///
  /// ⚠ `id` İLE KARIŞTIRILMAZ. `id` sistemin teknik kimliğidir
  /// (UUID) ve teklif, mesaj, ödeme, şikâyet ilişkileri DAİMA onun
  /// üzerinden kurulur. `ilanNo` yalnız KULLANICI, hizmet veren,
  /// admin ve destek süreçlerinde kullanılan okunabilir referanstır.
  ///
  /// ⚠ FOREIGN KEY DEĞİLDİR. Hiçbir ilişki bu alan üzerinden
  /// kurulmaz.
  ///
  /// ⚠ DEĞİŞMEZ: `final`. İlan düzenlense, teklif alsa, kapatılsa,
  /// geçmişe taşınsa da aynı kalır. Silinen/kapanan bir ilanın
  /// numarası BAŞKA bir ilana yeniden verilmez.
  ///
  /// ⚠ ÜRETİM OTORİTESİ İSTEMCİ DEĞİLDİR. Mock ortamda
  /// `ListingRepository` artan bir sayaçla üretir; gerçek backend
  /// geldiğinde numarayı üreten ve benzersizliğini garanti eden
  /// taraf veritabanıdır (UNIQUE kısıt).
  final String ilanNo;
  final String ownerId;  // müşteri hesabı
  String title;
  String location;
  String desc;
  ListingStatus status;
  List<String> photoPaths;
  String? selectedOfferId;

  /// İŞİN YAPILMASI İSTENEN ZAMAN — İSTEĞE BAĞLI.
  ///
  /// ⚠ `null` = kullanıcı seçim YAPMADI. Bu bir eksiklik değildir;
  /// ilanda hiçbir zaman etiketi gösterilmez.
  ///
  /// ⚠ `final` DEĞİL: kullanıcı ilanını düzenlerken seçimini
  /// değiştirebilmeli veya kaldırabilmelidir.
  IsZamani? isZamani;

  final DateTime createdAt;
  final DateTime expiresAt;   // createdAt + DomainConfig.listingLifetime

  Listing({
    required this.id,
    required this.ilanNo,
    required this.ownerId,
    required this.title,
    required this.location,
    required this.desc,
    this.status = ListingStatus.active,
    // ⚠ İSTEĞE BAĞLI: verilmezse `null` kalır, seçim yapılmamış demektir.
    this.isZamani,
    List<String>? photoPaths,
    DateTime? createdAt,
  })  : photoPaths = photoPaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        expiresAt =
            (createdAt ?? DateTime.now()).add(DomainConfig.listingLifetime);

  /// İlan yeni teklif kabul ediyor mu?
  ///
  /// ── ⚠ İKİ KOŞUL BİRDEN (§22) ──
  ///
  /// Eskiden YALNIZ duruma bakıyordu. Ama nihai modelde seçim ilanın
  /// durumunu DEĞİŞTİRMİYOR: teklif seçilmiş bir ilan `active`
  /// kalmaya devam ediyor. Tek koşullu hâlde tamamlanmış işe yeni
  /// teklif verilebiliyordu — "ACTIVE olduğu için teklif verilebilir"
  /// yanılgısının domain katmanındaki karşılığı.
  ///
  /// ⚠ Bu, ekran koşullarının değil DOMAIN'in sorumluluğudur:
  /// arayüzde düğmeyi gizlemek güvenlik değildir.
  bool get acceptsOffers =>
      status == ListingStatus.active && !isTamamlanmisIs;

  /// Ekranlarda gösterilecek biçim — TEK KAYNAK.
  ///
  /// ⚠ Ekranlar "İlan No: " önekini elle yazmaz; biçim değişirse
  /// tek yerden değişsin.
  String get ilanNoEtiketi => 'İlan No: $ilanNo';

  /// ── ⚠ TAMAMLANMIŞ İŞ — TEK KAYNAK ──
  ///
  /// Eskiden `status == ListingStatus.completed` bakılıyordu. Nihai
  /// sözleşmede tamamlanmışlık bir DURUM DEĞİL, bir İLİŞKİDİR:
  /// ilanın seçilmiş bir teklifi varsa iş tamamlanmıştır (§11).
  ///
  /// ⚠ YAŞAM DURUMUNA BAĞLANMAZ. Tamamlanmış bir ilan sonradan
  /// silinebilir ya da admin tarafından kaldırılabilir; bu, işin
  /// tamamlanmış olduğu gerçeğini DEĞİŞTİRMEZ. Bu yüzden koşulda
  /// `status` HİÇ geçmez.
  ///
  /// ⚠ TEK YERDE TUTULUR: onlarca ekranda `selectedOfferId != null`
  /// yazılırsa biri güncellenip öteki unutulur. Sekme filtreleri,
  /// rozetler ve kartlar hep buradan okur.
  bool get isTamamlanmisIs => selectedOfferId != null;
}
