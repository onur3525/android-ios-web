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
class TeklifMesaj {
  const TeklifMesaj({
    required this.id,
    required this.gonderenId,
    required this.zaman,
    this.metin,
    this.fotografYolu,
  });

  final String id;
  final String gonderenId;
  final DateTime zaman;

  /// ⚠ İKİSİNDEN EN AZ BİRİ dolu olmalı — metin VEYA fotoğraf.
  final String? metin;
  final String? fotografYolu;
}

/// ⚠ TEK BİR İSTEK/İŞ KAYDI. `saglayiciId` mock veya gerçek hizmet
/// veren kimliği olabilir — bu model kaynağı BİLMEZ (bkz.
/// `mock_saglayici_dizini.dart`'taki not: gerçek dizin bağlandığında
/// `saglayiciId` gerçek hesap id'sine dönüşür, bu modelin ALANLARI
/// DEĞİŞMEZ).
class TeklifTalebi {
  TeklifTalebi({
    required this.id,
    required this.hizmetAlanId,
    required this.saglayiciId,
    required this.saglayiciAdi,
    required this.kategori,
    required this.hizmet,
    required this.aciklama,
    required this.iletisimTercihi,
    required this.createdAt,
    this.fotograflar = const [],
    this.durum = TeklifTalebiDurumu.beklemede,
    this.teklifFiyati,
    this.teklifAciklamasi,
    this.teklifTarihi,
    List<TeklifMesaj>? mesajlar,
  }) : mesajlar = mesajlar ?? [];

  final String id;

  /// İsteği gönderen hizmet alanın hesap id'si.
  final String hizmetAlanId;

  /// Talebin gönderildiği TEK hizmet veren.
  final String saglayiciId;

  /// ⚠ HAM AD — maskeleme burada DEĞİL, gösterim anında uygulanır
  /// (bkz. sınıf başındaki not). `teklifTarihi` doluysa ekran bu
  /// adı OLDUĞU GİBİ gösterir; değilse `maskeliAd()` ile sarmalar.
  final String saglayiciAdi;

  final String kategori;
  final String hizmet;
  final String aciklama;
  final List<String> fotograflar;
  final IletisimTercihi iletisimTercihi;
  final DateTime createdAt;

  TeklifTalebiDurumu durum;

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
