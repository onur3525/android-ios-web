/// ═══════════════════════════════════════════════════════════════
/// BİLDİRİM METİNLERİ — İKİ AKIŞ İÇİN TEK KAYNAK
///
/// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "Teklif seçildiğinde, Bul ile
/// veya ilan oluşturmayla farketmeksizin 'Teklifiniz seçildi 🎉'
/// olarak bildirim gelmeli. 'Teklifiniz kabul edildi' kabul
/// etmiyorum."
///
/// ## NİÇİN ORTAK
///
/// Aynı olay iki ayrı portta ayrı ayrı yazılmıştı:
///   · `mock_ports.dart`        → "Teklifiniz seçildi 🎉"
///   · `teklif_talebi_port.dart` → "Teklifiniz kabul edildi"
///
/// Hizmet veren için olay AYNI: verdiği teklif kabul edildi, iş
/// başladı. Bildirim listesinde alt alta iki farklı başlık görmek,
/// iki farklı şey olmuş izlenimi veriyordu (bkz. ekran görüntüsü:
/// 3 dk ve 10 dk önce, iki ayrı başlık).
///
/// ⚠ PORTLAR KENDİ METNİNİ YAZMAZ. Üçüncü bir akış eklendiğinde
/// metni buradan alır; "kabul edildi" gibi bir varyant yeniden
/// doğamaz.
/// ═══════════════════════════════════════════════════════════════
library;

/// Teklifi seçilen hizmet verene gönderilen bildirimin başlığı.
///
/// ⚠ EMOJİ METNİN PARÇASIDIR: kutlama tonu ürün kararıdır, süs
/// değil. Ayrı bir "emoji ekle" adımı YOKTUR — başlık neyse odur.
const String kTeklifSecildiBaslik = 'Teklifiniz seçildi 🎉';

/// Teklifi seçilen hizmet verene gönderilen bildirimin gövdesi.
///
/// [isAdi] ilan başlığı ya da talepteki hizmet adıdır; iki akışta
/// farklı alanlardan gelir ama kullanıcı için ikisi de "iş"tir.
///
/// ⚠ GÖVDE DE ORTAK: yalnız başlığı eşitleyip gövdeyi ayrı bırakmak,
/// aynı ayrışmayı bir satır aşağı taşımak olurdu.
String teklifSecildiGovde(String isAdi) =>
    '"$isAdi" işinde hizmet alan sizinle çalışmak istiyor.';

/// ── ⚠ YENİ TEKLİF BİLDİRİMİ — TEK BAŞLIK ──
///
/// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "'Teklifiniz geldi' farklı bir
/// dil, bunu kabul etmiyorum. 'Yeni teklif aldınız' olarak yazılmalı.
/// Bul veya ilan oluşturmayla nereden gelirse gelsin."
///
/// İki port aynı olay için iki ayrı başlık yazıyordu:
///   · `mock_ports`        → "Yeni teklif aldınız"
///   · `teklif_talebi_port` → "Teklifiniz geldi"
///
/// ⚠ "Teklifiniz geldi" AYRICA YANILTICIYDI: bildirimi alan kişi
/// hizmet ALANDIR, teklifi o vermemiştir. "Teklifiniz" iyelik eki
/// karşı tarafın teklifini okuyana aitmiş gibi gösteriyordu.
const String kYeniTeklifBaslik = 'Yeni teklif aldınız';

/// İlan akışı gövdesi — ortada bir İLAN vardır.
String yeniTeklifGovdeIlan(String ilanBasligi) =>
    '"$ilanBasligi" ilanınıza yeni bir teklif geldi.';

/// Bul akışı gövdesi — ortada bir TALEP vardır ve fiyat bellidir.
///
/// ⚠ GÖVDELER AYRI, BAŞLIK ORTAK: iki akışta olan şey aynı (yeni bir
/// teklif geldi) ama ayrıntı farklı — ilan akışında henüz fiyat
/// okunmadan bildirim gider, Bul akışında teklif fiyatla birlikte
/// gelir. Gövdeyi de zorla eşitlemek, Bul akışında işe yarayan fiyat
/// bilgisini SİLMEK olurdu.
String yeniTeklifGovdeTalep(String hizmet, Object fiyat) =>
    '"$hizmet" talebiniz için $fiyat TL teklif aldınız.';
