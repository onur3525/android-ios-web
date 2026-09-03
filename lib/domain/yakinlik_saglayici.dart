/// ── ⚠ YAKINLIK SAĞLAYICISI SOYUTLAMASI ──
///
/// "Bul" akışında hizmet verenler önce hizmet alanın İLÇESİNDE,
/// bulunamazsa YAKIN İLÇELERDE, hâlâ yoksa İL GENELİNDE aranır.
///
/// Projede GERÇEK KOORDİNAT (enlem/boylam) verisi YOKTUR — yalnız
/// il/ilçe/mahalle metin hiyerarşisi var. Bu yüzden "yakın ilçe"
/// burada COĞRAFİ MESAFEYLE değil, aynı ildeki DİĞER ilçeler olarak
/// tanımlanır — geçici ve dürüst bir yaklaşıklık.
///
/// ⚠ GERÇEK KOORDİNAT VERİSİ GELDİĞİNDE yalnız bu dosyadaki
/// `IlBazliYakinlikSaglayici` sınıfı GerçekKoordinatYakinlikSaglayici
/// gibi bir sınıfla DEĞİŞTİRİLİR — çağıran kod (`YakinlikSaglayici`
/// arayüzü) DEĞİŞMEZ.
abstract class YakinlikSaglayici {
  /// Verilen il/ilçenin "yakın ilçeleri" — uzaklık sırasına göre
  /// DEĞİL, sağlayıcının elindeki en iyi tahmine göre sıralı.
  ///
  /// ⚠ ŞU ANKİ UYGULAMADA bu sıra coğrafi anlam TAŞIMAZ; yalnız aynı
  /// ildeki öteki ilçelerin listesidir.
  List<String> yakinIlceler(String il, String ilce);
}

/// ── ⚠ GEÇİCİ UYGULAMA — İL/İLÇE HİYERARŞİSİNE DAYALI ──
///
/// Gerçek coğrafi mesafe hesaplayamaz. Yalnız aynı ildeki, verilen
/// ilçe dışındaki ilçeleri döndürür.
class IlBazliYakinlikSaglayici implements YakinlikSaglayici {
  const IlBazliYakinlikSaglayici(this._ilceleriGetir);

  /// Bir ilin ilçe adlarını döndüren fonksiyon — çağıran taraf
  /// `RegionController.tree` üzerinden sağlar. Bu sınıf `RegionTree`
  /// tipine DOĞRUDAN bağımlı değildir; test edilebilirlik için.
  final List<String> Function(String il) _ilceleriGetir;

  @override
  List<String> yakinIlceler(String il, String ilce) {
    final tumIlceler = _ilceleriGetir(il);
    return tumIlceler.where((i) => i != ilce).toList(growable: false);
  }
}
