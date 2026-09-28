/// ═══════════════════════════════════════════════════════════════
/// İLAN / TALEP NUMARASI — TEK ÜRETEÇ
///
/// ## NİÇİN ORTAK
///
/// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "Talep numarası her ilan için
/// konulacak. İlan oluştur veya bul üzerinden teklif talep edilsin
/// farketmez."
///
/// Yani kullanıcı için ikisi AYNI ŞEYDİR: bir iş kaydı ve onun
/// numarası. İki ayrı sayaç tutulsaydı aynı numara hem bir ilanda
/// hem bir talepte çıkabilirdi; kullanıcı "#10458231" diye referans
/// verdiğinde hangisi olduğu belirsiz kalırdı. Destek ve arama bu
/// belirsizliği kaldıramaz.
///
/// ⚠ BU YÜZDEN SAYAÇ TEKTİR ve `static`tir: `ListingRepository` ile
/// `TeklifTalebiRepository` aynı diziden numara alır.
///
/// ## KURALLAR (ilan tarafından devralındı)
///
/// ⚠ ARTAN SAYAÇ, "EN BÜYÜK + 1" DEĞİL. Mevcut kayıtlara bakıp en
/// büyüğü bulmak, silinen bir kaydın numarasının YENİDEN
/// VERİLMESİNE yol açar. Sayaç yalnız ileri gider.
///
/// ⚠ VERİLMİŞ NUMARALAR UNUTULMAZ: kayıt silinse de küme içinde
/// kalır. Yeniden kullanımı engellemenin ikinci savunması.
///
/// ⚠ BU İSTEMCİ TARAFI BİR SİMÜLASYONDUR. Gerçek benzersizlik
/// otoritesi veritabanıdır: numara üzerinde UNIQUE kısıt ve atomik
/// üretim (sequence / identity) gerekir. "Önce kontrol et, sonra
/// yaz" yeterli değildir — iki paralel istek aynı anda kontrolü
/// geçebilir.
///
/// ⚠ Başlangıç değeri SABİT: testler deterministik olsun diye
/// rastgelelik kullanılmaz.
/// ═══════════════════════════════════════════════════════════════
class IlanNoUretici {
  IlanNoUretici._();

  static const int kBaslangic = 10458231;

  static int _sonraki = kBaslangic;

  /// Üretilmiş TÜM numaralar — kayıt silinse de burada kalır.
  static final Set<String> _verilmis = <String>{};

  /// Bir sonraki benzersiz numarayı üretir.
  static String uret() {
    var no = (_sonraki++).toString();
    // Dışarıdan verilmiş numaralarla çakışma ihtimaline karşı ilerle.
    while (_verilmis.contains(no)) {
      no = (_sonraki++).toString();
    }
    _verilmis.add(no);
    return no;
  }

  /// Dışarıdan (sunucudan, testten) gelen numarayı rezerve eder.
  ///
  /// ⚠ ÜRETECİN ONU TEKRAR VERMESİNİ ENGELLER. API modunda numarayı
  /// sunucu üretir; istemci sayacı o numaraları bilmezse aynı
  /// numarayı yerel bir kayda verebilir.
  static void rezerveEt(String no) {
    final n = no.trim();
    if (n.isNotEmpty) {
      _verilmis.add(n);
    }
  }

  /// ⚠ YALNIZ TEST İÇİN: sayacı başa alır.
  ///
  /// Üretim kodundan çağrılmaz — `static` durum testler arasında
  /// sızmasın diye vardır.
  static void sifirlaTestIcin() {
    _sonraki = kBaslangic;
    _verilmis.clear();
  }

  /// ⚠ Numaranın kullanıcıya gösterilen biçimi TEK YERDE.
  ///
  /// Model sınıfları ham numarayı tutar; başına "#" koymak bir
  /// SUNUM kararıdır ve iki modelde ayrı ayrı yazılırsa ayrışır.
  static String etiket(String no) => '#${no.trim()}';
}
