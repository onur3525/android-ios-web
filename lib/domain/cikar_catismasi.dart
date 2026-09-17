import '../data/category_tree.dart';

/// ═══════════════════════════════════════════════════════════════
/// ÇIKAR ÇATIŞMASI — HİZMET VERENİN KENDİ ALANINDA İLAN AÇMASI
///
/// ## İŞ KURALI
///
/// Bir kullanıcı hizmet veren rolünde BİR HİZMETİ sunuyorsa, hizmet
/// alan rolünde AYNI HİZMET için ilan AÇAMAZ.
///
/// ⚠ NİÇİN: aksi hâlde kendi işindeki rakiplerinden teklif toplayıp
/// fiyatlarını öğrenebilir. Pazaryerinin güveni buna dayanır.
///
/// ## ── ⚠ KAPSAM DARALTILDI (kullanıcı kararı, 9 Eyl) ──
///
/// ÖNCEDEN denetim ANA KATEGORİ düzeyindeydi: "Doğalgaz Kaçağı" ve
/// "Doğalgaz Tespiti" hizmetlerini seçmiş biri, Doğalgaz
/// kategorisindeki HİÇBİR ilanı açamıyordu — doğalgaz tesisatı,
/// kombi bağlantısı, hiçbiri.
///
/// KULLANICI BULGUSU: "Bu yanlış. Sadece seçmiş olduğu ve hizmet
/// verdiği hizmetler için geçerli olmalı. Doğalgaz kaçağı ve tespiti
/// hizmeti veren biri, doğalgazın diğer hizmetleri için hizmet
/// alabilmeli."
///
/// Artık denetim SEÇİLEN HİZMET düzeyinde:
///
///   • Hizmet veren "Doğalgaz Kaçağı" seçmişse → yalnız "Doğalgaz
///     Kaçağı" ilanı açamaz; aynı kategorideki öteki hizmetler için
///     ilan açabilir.
///   • Hizmet veren ANA KATEGORİNİN KENDİSİNİ seçmişse ("Doğalgaz")
///     → o kategorinin TAMAMINDA ilan açamaz. Çünkü kategoriyi
///     bütün olarak seçmek, o alandaki her işi yaptığını beyan
///     etmektir.
///
/// ⚠ ESKİ GEREKÇE NEDEN GEÇERSİZ KALDI: "alt hizmetler aynı ustanın
/// işidir" varsayımı katalog büyüdükçe tutmuyor. Aynı ana kategori
/// altında birbirine hiç benzemeyen işler var; birini yapan ötekini
/// yapmak zorunda değil ve o iş için müşteri OLABİLMELİ.
///
/// ⚠ KURALIN ÖZÜ KORUNDU: kişi kendi sunduğu işte hâlâ müşteri
/// olamaz. Daralan şey, "kendi işi" tanımıdır.
///
/// ## TEK KAYNAK
///
/// Bu dosya saf fonksiyonlardan oluşur: widget, controller ve ağ
/// bilmez. Hem ekran (seçim anında uyarı) hem port (ikinci savunma)
/// aynı kuralı çağırır; backend'de de birebir yeniden yazılmalıdır.
/// ═══════════════════════════════════════════════════════════════

/// Kullanıcının hizmet verdiği ANA KATEGORİLER.
///
/// ⚠ ARTIK YALNIZ TAM KATEGORİ SEÇİMLERİ: `Account.categories` içinde
/// ana kategori ve alt hizmet adları KARIŞIK bulunur. Eskiden hepsi
/// ana kategoriye indirgeniyordu; şimdi yalnız GERÇEKTEN ana kategori
/// olarak seçilenler döner. Alt hizmet seçimi, kategorinin tamamını
/// kapsamaz.
Set<String> hizmetVerilenAnaKategoriler(Iterable<String> saglayiciSecimleri) =>
    {
      for (final s in saglayiciSecimleri)
        if (kCategoryTree.containsKey(s)) s,
    };

/// Kullanıcının hizmet verdiği ALT HİZMETLER.
Set<String> hizmetVerilenHizmetler(Iterable<String> saglayiciSecimleri) => {
      for (final s in saglayiciSecimleri)
        if (!kCategoryTree.containsKey(s)) s,
    };

/// [ilanBasligi] ile ÇATIŞAN seçim; çatışma yoksa `null`.
///
/// Dönen değer kullanıcıya gösterilecek ADdır: çatışma alt hizmetten
/// geliyorsa alt hizmetin adı, ana kategoriden geliyorsa kategorinin
/// adı.
///
/// [ilanBasligi] ana kategori de olabilir alt hizmet de.
///
/// ⚠ Hizmet veren rolü YOKSA ya da hiç seçim yapmamışsa çatışma
/// aranmaz: kural yalnız gerçekten hizmet verene uygulanır.
String? catisanKategori({
  required Iterable<String> saglayiciSecimleri,
  required String ilanBasligi,
}) {
  // ── 1. TAM KATEGORİ SEÇİMİ ──
  //
  // Hizmet veren ana kategoriyi bütün olarak seçmişse, o kategorinin
  // altındaki HER ilan çatışır.
  final ana = anaKategoriBul(ilanBasligi);
  if (ana != null &&
      hizmetVerilenAnaKategoriler(saglayiciSecimleri).contains(ana)) {
    return ana;
  }

  // ── 2. ALT HİZMET SEÇİMİ ──
  //
  // ⚠ YALNIZ BİREBİR AYNI HİZMET: "Doğalgaz Kaçağı" sunan biri
  // "Doğalgaz Tesisatı" ilanı açabilir.
  //
  // ⚠ İLAN BAŞLIĞI ANA KATEGORİ İSE: kullanıcı kategorinin tamamı
  // için ilan açıyor demektir; sunduğu alt hizmetlerden BİRİ o
  // kategorideyse çatışır — aksi hâlde kural tek satırla delinirdi.
  final verilenler = hizmetVerilenHizmetler(saglayiciSecimleri);
  if (verilenler.contains(ilanBasligi)) {
    return ilanBasligi;
  }
  if (ana != null && ana == ilanBasligi) {
    for (final h in verilenler) {
      if (anaKategoriBul(h) == ana) {
        return h;
      }
    }
  }
  return null;
}

/// Bu başlıkta ilan açılabilir mi?
bool ilanAcilabilir({
  required Iterable<String> saglayiciSecimleri,
  required String ilanBasligi,
}) =>
    catisanKategori(
          saglayiciSecimleri: saglayiciSecimleri,
          ilanBasligi: ilanBasligi,
        ) ==
        null;

/// Kullanıcıya gösterilecek metin.
///
/// ⚠ ORTAK DİL: tek cümle, suçlayıcı değil, ne yapılacağını söyler.
///
/// ⚠ METİN DARALDI: "bu kategoride" değil "bu hizmet için" — kural
/// artık kategoriyi değil hizmeti kapsıyor ve mesaj bunu doğru
/// anlatmalı, yoksa kullanıcı ötekiler için de açamayacağını sanır.
String catismaMesaji(String catisanAd) =>
    '"$catisanAd" hizmetini verdiğiniz için bu hizmet için ilan '
    'açamazsınız. Hizmet kategorilerinizi Hizmet Kategorilerim '
    'ekranından düzenleyebilirsiniz.';
