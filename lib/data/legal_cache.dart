/// YASAL METİN ÖNBELLEĞİ
///
/// Çevrimdışı görüntüleme için son başarılı içerik bellekte tutulur.
/// Kalıcı saklama gerekirse aynı arayüz korunarak disk katmanı eklenebilir;
/// ekran kodu değişmez.
library;

class LegalDoc {
  final String slug;
  final String title;
  final String version;
  final String effectiveDate;
  final String body;

  const LegalDoc({
    required this.slug,
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.body,
  });

  factory LegalDoc.fromJson(Map<String, dynamic> j) => LegalDoc(
        slug: j['slug'] as String? ?? '',
        title: j['title'] as String? ?? '',
        version: j['version'] as String? ?? '',
        effectiveDate: j['effectiveDate'] as String? ?? '',
        body: j['body'] as String? ?? '',
      );
}

class LegalCache {
  LegalCache._();
  static final LegalCache instance = LegalCache._();

  final Map<String, LegalDoc> _mem = {};

  LegalDoc? read(String slug) => _mem[slug];

  void write(LegalDoc doc) {
    _mem[doc.slug] = doc;
  }

  void clear() => _mem.clear();
}

/// Profil menüsünde gösterilecek yasal/destek bağlantıları.
/// slug değerleri backend'deki LEGAL_DOCUMENTS ile BİREBİR aynıdır.
const List<({String slug, String title})> kLegalLinks = [
  (slug: 'support', title: 'Destek Merkezi'),
  (slug: 'terms', title: 'Kullanım Koşulları'),
  (slug: 'privacy', title: 'Gizlilik Politikası'),
  (slug: 'kvkk', title: 'KVKK Aydınlatma Metni'),
  (slug: 'membership', title: 'Üyelik Sözleşmesi'),
  (slug: 'refund', title: 'İptal ve İade Politikası'),
  (slug: 'cookies', title: 'Çerez Politikası'),
];
