import 'listing.dart' show IsZamani;

/// ── ⚠ "DOĞRUDAN TEKLİF İSTE" — AYRI VE YENİ BİR MODEL ──
///
/// Bu, mevcut `Offer`/`Listing` çiftinden BİLİNÇLİ OLARAK AYRIDIR:
/// `Listing` HERKESE AÇIKTIR (tüm hizmet verenler teklif verebilir);
/// `TeklifTalebi` ise "Bul" akışından seçilen TEK bir hizmet verene
/// ÖZEL gönderilir — asla genel ilan listesinde görünmez.
///
/// Var olan `Offer`/`Listing` modeline yeni alanlar ekleyip bu ikisi
/// karıştırılmadı; iki akış birbirinden BAĞIMSIZ kalır.
enum TeklifTalebiDurumu {
  /// Hizmet veren henüz yanıt vermedi.
  beklemede,

  /// Hizmet veren fiyat/açıklama gönderdi — hizmet alan henüz karar
  /// vermedi.
  teklifGeldi,

  /// Hizmet alan "Teklifi Seç" dedi — iş aktif.
  secildi,

  /// Hizmet alan reddetti.
  reddedildi,

  /// 30 saat içinde işlem yapılmadı.
  suresiDoldu,

  /// İş tamamlandı.
  tamamlandi,
}

enum IletisimTercihi {
  /// Telefon numarası hizmet verene gösterilir.
  telefonGoster,

  /// Yalnız uygulama içi mesajlaşma — telefon GİZLİDİR.
  yalnizMesaj,
}

/// ⚠ MASKELEME KURALI (güncel ürün kararı):
///
/// Hizmet veren TEKLİF VERENE KADAR iki taraf da birbirine
/// MASKELİDİR (`maskeliAd()` ile). Hizmet veren teklif verdiği ANDA
/// (`teklifTarihi` dolduğu an) İKİ TARAF İÇİN DE maskeleme kalkar —
/// gerçek ad ve iletişim görünür olur.
///
/// Bu yüzden ham adlar (`hizmetAlanAdi`, `saglayiciAdi`) modelde
/// SAKLANIR; maskeleme yalnız GÖSTERİM anında, `teklifTarihi`
/// durumuna göre EKRAN TARAFINDA uygulanır.
/// Mesajın gönderim/okunma durumu — `chat_screen.dart`daki
/// `MessageStatus` ile AYNI kavram, ama `TeklifTalebi` kendi
/// bağımsız zincirinde tutulduğu için (bkz. yukarıdaki not) o enum
/// PAYLAŞILMADI, buraya özel bir kopyası tanımlandı.
enum TeklifMesajDurumu {
  gonderildi,
  iletildi,

  /// Karşı taraf sohbeti AÇTIĞINDA bu duruma geçer.
  okundu,
}

class TeklifMesaj {
  TeklifMesaj({
    required this.id,
    required this.gonderenId,
    required this.zaman,
    this.metin,
    this.fotografYolu,
    this.durum = TeklifMesajDurumu.gonderildi,
  });

  final String id;
  final String gonderenId;
  final DateTime zaman;

  /// ⚠ İKİSİNDEN EN AZ BİRİ dolu olmalı — metin VEYA fotoğraf.
  final String? metin;
  final String? fotografYolu;

  /// ⚠ MUTABLE — `TeklifTalebiRepository.mesajlariOkunduIsaretle()`
  /// karşı taraf sohbeti açtığında bunu günceller (`final` değil,
  /// modelin geri kalanı gibi yeni bir kopya OLUŞTURULMAZ; bkz. o
  /// metodun kendi notu).
  TeklifMesajDurumu durum;
}

/// ⚠ TEK BİR İSTEK/İŞ KAYDI. `saglayiciId` mock veya gerçek hizmet
/// veren kimliği olabilir — bu model kaynağı BİLMEZ (bkz.
/// `mock_saglayici_dizini.dart`'taki not: gerçek dizin bağlandığında
/// `saglayiciId` gerçek hesap id'sine dönüşür, bu modelin ALANLARI
/// DEĞİŞMEZ).
class TeklifTalebi {
  TeklifTalebi({
    required this.id,
    required this.talepNo,
    required this.hizmetAlanId,
    required this.saglayiciId,
    required this.saglayiciAdi,
    required this.kategori,
    required this.hizmet,
    required this.aciklama,
    required this.iletisimTercihi,
    required this.createdAt,
    this.fotograflar = const [],
    this.isZamani,
    this.durum = TeklifTalebiDurumu.beklemede,
    this.teklifFiyati,
    this.teklifAciklamasi,
    this.teklifTarihi,
    List<TeklifMesaj>? mesajlar,
    this.redGerekcesi,
    this.silindiAt,
    this.saglayiciReddetti = false,
  }) : mesajlar = mesajlar ?? [];

  final String id;

  /// ── ⚠ KULLANICIYA GÖSTERİLEN NUMARA ──
  ///
  /// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "Talep numarası her ilan
  /// için konulacak. İlan oluştur veya bul üzerinden teklif talep
  /// edilsin farketmez." Kullanıcı için ikisi aynı şeydir.
  ///
  /// ⚠ `id` İLE KARIŞTIRILMAZ: ilişkiler (teklif, mesaj, bildirim)
  /// DAİMA `id` üzerinden kurulur. `talepNo` yalnız kullanıcının
  /// gördüğü, telefonda söylediği, destekte aradığı referanstır.
  ///
  /// ⚠ İLAN NUMARALARIYLA AYNI DİZİDEN gelir (`IlanNoUretici`):
  /// aynı numara bir ilanda ve bir talepte birden çıkamaz.
  ///
  /// ⚠ BOŞ OLABİLİR: API modunda sunucu alanı göndermezse boş kalır
  /// ve gösterim tarafı hiçbir şey çizmez.
  final String talepNo;

  /// ── ⚠ TALEP SİLİNEBİLİR Mİ — TEK KAYNAK ──
  ///
  /// ⚠ KULLANICI KARARI (12 Eyl): "Üç nokta menüsü sadece AÇIK
  /// işlerde olacak; tamamlanan işlerde buna gerek yok."
  ///
  /// Menü tek bir şey yapar: talebi siler. İş bir kez ilerlediyse
  /// silmek bir kaydı yok etmektir — tamamlanmış işin yorumu, puanı
  /// ve karşı tarafın geçmişi ona bağlıdır.
  ///
  /// ⚠ AÇIK = HENÜZ KARARA BAĞLANMAMIŞ: hizmet veren yanıt
  /// vermemiştir (`beklemede`) ya da teklifini göndermiş, hizmet alan
  /// henüz seçmemiştir (`teklifGeldi`). Seçildikten sonra ortada bir
  /// İŞ vardır.
  ///
  /// (Eski kural: `reddedildi` ve `suresiDoldu` kapsam dışıydı — 16 Eki
  /// kullanıcı isteğiyle değişti, aşağıya bkz.)
  ///
  /// ⚠ EKRANLAR KENDİ KOŞULUNU YAZMAZ — `Listing.isTamamlanmisIs`
  /// ile aynı desen. İki ekran ayrı koşul yazsaydı biri güncellenip
  /// öteki eskide kalırdı.
  ///
  /// ── ⚠ 16 Eki KULLANICI İSTEĞİ: REDDEDİLEN / SÜRESİ DOLAN DA SİLİNİR ──
  /// "Teklif talebini silebilmek için sağ üst köşede 3 nokta olsun,
  /// silme nedeni seçilerek talep silinsin, hiçbir ekranda görünmesin."
  /// Reddedilmiş ya da süresi dolmuş talep de hizmet alanın listesinde
  /// kalıyordu ve kaldırılamıyordu. Artık yalnız İŞE DÖNÜŞMÜŞ talep
  /// (seçildi / tamamlandı — yorum ve puan ona bağlı) silinemez; sunucu
  /// da aynı kuralı uygular (`/sil` → SECILDI/TAMAMLANDI 409). Zaten
  /// silinmiş talepte menü çizilmez.
  bool get silinebilir =>
      !hizmetAlanSildi &&
      durum != TeklifTalebiDurumu.secildi &&
      durum != TeklifTalebiDurumu.tamamlandi;

  /// İsteği gönderen hizmet alanın hesap id'si.
  final String hizmetAlanId;

  /// Talebin gönderildiği TEK hizmet veren.
  final String saglayiciId;

  /// ── TARAF DENETİMİ — TEK KAYNAK ──
  ///
  /// Bu talebi yalnız iki taraf görebilir ve üzerinde işlem yapabilir:
  /// talebi açan hizmet alan ve talebin gönderildiği hizmet veren.
  /// Detay ekranı, sohbet ekranı ve mock port bu yöntemi kullanır;
  /// ayrı ayrı kural yazılmaz.
  ///
  /// ⚠ Asıl koruma SUNUCUDA olmalı (backend'de yazılmadı); istemci
  /// taraf olmayan birine talebi hiç göstermez.
  bool tarafMi(String kullaniciId) =>
      kullaniciId == hizmetAlanId || kullaniciId == saglayiciId;

  /// ⚠ HAM AD — maskeleme burada DEĞİL, gösterim anında uygulanır
  /// (bkz. sınıf başındaki not). `teklifTarihi` doluysa ekran bu
  /// adı OLDUĞU GİBİ gösterir; değilse `maskeliAd()` ile sarmalar.
  final String saglayiciAdi;

  final String kategori;
  final String hizmet;
  final String aciklama;
  final List<String> fotograflar;
  final IletisimTercihi iletisimTercihi;

  /// HİZMET ZAMANI TERCİHİ — Acil / Bu hafta / Esnek zaman.
  ///
  /// ⚠ İSTEĞE BAĞLIDIR: `null` normaldir ve "belirtilmedi" demektir;
  /// seçim yoksa hizmet verene HİÇBİR ŞEY gösterilmez (`Listing`
  /// tarafındaki AYNI kural).
  ///
  /// ⚠ TİP PAYLAŞILDI, MODEL PAYLAŞILMADI: `IsZamani` enum'u
  /// `listing.dart`tan alınır — üç seçeneğin, etiketlerin ve sunucu
  /// kodlarının (`NOW`/`THIS_WEEK`/`FLEXIBLE`) iki akışta AYRI AYRI
  /// tanımlanması sapmaya davetiye olurdu. `TeklifTalebi`nin
  /// `Listing`den bağımsız kalma kuralı, ORTAK BİR ENUM'u kullanmayı
  /// engellemez.
  final IsZamani? isZamani;

  final DateTime createdAt;

  TeklifTalebiDurumu durum;

  /// ⚠ YALNIZ "reddedildi" DURUMUNDA ANLAMLIDIR — hizmet alanın
  /// talebi neden reddettiği/sildiği (`listing_detail_screen.dart`
  /// içindeki "İlanı neden siliyorsunuz?" akışıyla AYNI desen).
  /// Yönetim/denetim amaçlı tutulur; hizmet verene GÖSTERİLMEZ.
  String? redGerekcesi;

  /// ── ⚠ HİZMET ALAN TALEBİ SİLDİ (15 Eki) ──
  /// Doluysa talep hizmet alanın listesinde GÖRÜNMEZ; hizmet veren
  /// "İptal edildi" görür ve mesajlaşma kapanır. Kayıt kalıcı silinmez.
  DateTime? silindiAt;

  bool get hizmetAlanSildi => silindiAt != null;

  /// ── ⚠ HİZMET VEREN TALEBİ REDDETTİ (22 Eki, kullanıcı kararı) ──
  /// Hizmet veren teklif vermek zorunda değildir; "Talebi Reddet" der.
  /// Talep hizmet verenin listesinden kalkar (`bySaglayici` döndürmez);
  /// hizmet alan "Hizmet veren reddetti" olarak PASİF görür ve kendisi
  /// silebilir. Durum `reddedildi`dir.
  bool saglayiciReddetti;

  /// Hizmet verenin sunduğu fiyat — YALNIZ `teklifGeldi` ve sonrası
  /// durumlarda dolu.
  int? teklifFiyati;

  /// ⚠ GÖNDERİLDİKTEN SONRA KİLİTLENİR — hizmet veren tarafında
  /// "Teklifi Düzenle" YOKTUR; bu alan bir kez yazılır.
  String? teklifAciklamasi;

  /// ⚠ BU ALAN DOLDUĞU AN: (1) maskeleme İKİ TARAF İÇİN de kalkar,
  /// (2) uygulama içi mesajlaşma AÇILIR. Tek tetikleyici budur.
  DateTime? teklifTarihi;

  /// ⚠ UYGULAMA İÇİ MESAJLAŞMA — yalnız `teklifTarihi` dolduktan
  /// SONRA gönderilebilir (bkz. repository'deki kapı kontrolü).
  /// "Sadece uygulama içi mesajlaşma" seçiliyse TEK iletişim kanalı
  /// budur; "Telefon numaramı göster" seçiliyse EK kanaldır.
  final List<TeklifMesaj> mesajlar;

  /// ⚠ 30 SAATLİK SÜRE — GERÇEK OLUŞTURULMA ZAMANINDAN HESAPLANIR,
  /// sabit/uydurma bir geri sayım DEĞİLDİR.
  DateTime? get suresiDolacagiZaman =>
      teklifTarihi?.add(const Duration(hours: 30));

  bool get suresiGecmisMi {
    final son = suresiDolacagiZaman;
    return son != null && DateTime.now().isAfter(son);
  }
}
