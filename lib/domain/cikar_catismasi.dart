import '../data/category_tree.dart';

/// ═══════════════════════════════════════════════════════════════
/// ÇIKAR ÇATIŞMASI — HİZMET VERENİN KENDİ ALANINDA İLAN AÇMASI
///
/// ## İŞ KURALI
///
/// Bir kullanıcı hizmet veren rolünde bir kategoride çalışıyorsa,
/// hizmet alan rolünde AYNI kategoride ilan AÇAMAZ.
///
/// ⚠ NİÇİN: aksi hâlde kendi alanındaki rakiplerinden teklif toplayıp
/// fiyatlarını öğrenebilir. Pazaryerinin güveni buna dayanır.
///
/// ## KAPSAM — ANA KATEGORİ DÜZEYİ
///
/// Denetim ANA KATEGORİ üzerinden yapılır: hizmet veren yalnız bir alt
/// hizmet seçmiş olsa bile (\"Kombi Bakımı\"), o alt hizmetin ana
/// kategorisindeki (\"Kombi Servis\") HİÇBİR ilanı açamaz.
///
/// Gerekçe: alt hizmetler aynı ustanın işidir; \"kombi bakımı yapıyorum
/// ama kombi tamiri ilanı veriyorum\" ayrımı gerçekte yoktur ve kuralı
/// delmenin en kolay yolu olurdu.
///
/// ## TEK KAYNAK
///
/// Bu dosya saf fonksiyonlardan oluşur: widget, controller ve ağ
/// bilmez. Hem ekran (seçim anında uyarı) hem port (ikinci savunma)
/// aynı kuralı çağırır; backend'de de birebir yeniden yazılmalıdır.
/// ═══════════════════════════════════════════════════════════════

/// Kullanıcının hizmet verdiği ANA KATEGORİLER.
///
/// [saglayiciSecimleri] `Account.categories` — ana kategori ve alt
/// hizmet adları KARIŞIK bulunur; ikisi de ana kategoriye indirgenir.
Set<String> hizmetVerilenAnaKategoriler(Iterable<String> saglayiciSecimleri) =>
    anaKategorileri(saglayiciSecimleri);

/// [ilanBasligi] ile ÇATIŞAN ana kategori; çatışma yoksa `null`.
///
/// [ilanBasligi] ana kategori de olabilir alt hizmet de.
///
/// ⚠ Hizmet veren rolü YOKSA ya da hiç kategori seçmemişse çatışma
/// aranmaz: kural yalnız gerçekten hizmet verene uygulanır.
String? catisanKategori({
  required Iterable<String> saglayiciSecimleri,
  required String ilanBasligi,
}) {
  final ana = anaKategoriBul(ilanBasligi);
  if (ana == null) {
    return null;
  }
  return hizmetVerilenAnaKategoriler(saglayiciSecimleri).contains(ana)
      ? ana
      : null;
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
String catismaMesaji(String anaKategori) =>
    '"$anaKategori" alanında hizmet verdiğiniz için bu kategoride ilan '
    'açamazsınız. Hizmet kategorilerinizi Hizmet Kategorilerim '
    'ekranından düzenleyebilirsiniz.';
