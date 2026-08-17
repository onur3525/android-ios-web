/// AYLIK FATURA — BİLGİ AMAÇLIDIR.
///
/// ⚠ TAHSİLAT ÖNCEDEN YAPILMIŞTIR. Kullanıcı cüzdanına para yükler;
/// her iletişim açılışında ücret cüzdandan O ANDA düşülür. Fatura,
/// ay içinde gerçekleşen bu işlemlerin TOPLAMINI belgeler.
///
/// Yani bu belge "ödenecek borç" DEĞİLDİR. Bu yüzden modelde ödeme
/// durumu (ödendi/bekliyor/gecikti) YOKTUR ve ekranda ödeme akışı
/// bulunmaz — olsaydı kullanıcı ikinci kez ödeme yapması gerektiğini
/// sanırdı.
///
/// ⚠ FATURALARI UYGULAMA ÜRETMEZ. Belgeler admin/muhasebe tarafında
/// oluşturulur ve buraya salt okunur gelir.
class Invoice {
  /// Sunucudaki belge kimliği.
  final String id;

  /// Fatura numarası — muhasebe tarafından verilir (ör. `HC-2026-000148`).
  final String no;

  /// Faturanın ait olduğu dönem (ayın ilk günü).
  final DateTime donem;

  /// Düzenlenme tarihi.
  final DateTime tarih;

  /// KDV DAHİL toplam tutar (TL).
  ///
  /// ⚠ Kuruş kaybı olmaması için `double` yerine KURUŞ cinsinden `int`
  /// tutulur; gösterimde 100'e bölünür.
  final int kurus;

  /// Dönem içinde açılan İLETİŞİM SAYISI.
  ///
  /// Fatura bu işlemlerin toplamıdır; her iletişim açılışında ücret
  /// cüzdandan ZATEN tahsil edilmiştir.
  final int islemAdedi;

  /// Belgenin indirilebileceği adres (sunucudan gelir; boş olabilir).
  final String pdfUrl;

  const Invoice({
    required this.id,
    required this.no,
    required this.donem,
    required this.tarih,
    required this.kurus,
    required this.islemAdedi,
    this.pdfUrl = '',
  });

  /// `1.250,00 TL`
  ///
  /// ⚠ ŞU AN EKRANDA GÖSTERİLMİYOR. Tutar, işlem adedi ve fatura
  /// numarası BELGENİN KENDİSİNDE bulunur; listede tekrarlanmaz.
  /// Alanlar modelde KALIR: sunucudan geliyorlar ve ileride bir özet
  /// ekranı gerekirse yeniden hesaplanmaları gerekmesin.
  String get tutarMetni {
    final tam = kurus ~/ 100;
    final kalan = (kurus % 100).toString().padLeft(2, '0');
    final basamak = tam.toString();
    final buf = StringBuffer();
    for (var i = 0; i < basamak.length; i++) {
      if (i > 0 && (basamak.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(basamak[i]);
    }
    return '$buf,$kalan TL';
  }

  /// Ay adı (1-12) — filtre etiketlerinde de kullanılır.
  static String ayAdi(int ay) => _aylar[ay - 1];

  static const _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /// `Haziran 2026`
  String get donemMetni => '${_aylar[donem.month - 1]} ${donem.year}';

  /// `18 Haziran 2026`
  String get tarihMetni =>
      '${tarih.day.toString().padLeft(2, '0')} '
      '${_aylar[tarih.month - 1]} ${tarih.year}';

  /// `4 iletişim` — faturanın neyi kapsadığını tek satırda söyler.
  String get islemMetni => '$islemAdedi iletişim';

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: (j['id'] ?? '').toString(),
        no: (j['no'] ?? '').toString(),
        donem: DateTime.tryParse((j['period'] ?? '').toString()) ??
            DateTime.now(),
        tarih: DateTime.tryParse((j['issuedAt'] ?? '').toString()) ??
            DateTime.now(),
        kurus: (j['amountMinor'] as num?)?.toInt() ?? 0,
        islemAdedi: (j['itemCount'] as num?)?.toInt() ?? 0,
        pdfUrl: (j['pdfUrl'] ?? '').toString(),
      );
}
