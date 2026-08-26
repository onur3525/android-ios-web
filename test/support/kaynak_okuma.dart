/// KAYNAK METNİ ÜZERİNDE GÜVENLİ PENCERE
///
/// ⚠ `substring(i, i + N)` kaynak dosya kısaldığında/uzadığında
/// `RangeError` fırlatır ve test KENDİ KENDİNE patlar. Bu yardımcı
/// pencereyi dosya sonuna göre kırpar; iddia (assertion) değişmez.
extension GuvenliPencere on String {
  /// [baslangic] konumundan itibaren en fazla [uzunluk] karakter.
  /// Sınır aşılırsa dosya sonuna kadar döner.
  String pencere(int baslangic, int uzunluk) {
    if (baslangic < 0 || baslangic >= length) {
      return '';
    }
    final son = (baslangic + uzunluk) > length ? length : baslangic + uzunluk;
    return substring(baslangic, son);
  }

  /// Baştan en fazla [uzunluk] karakter.
  String bastan(int uzunluk) => pencere(0, uzunluk);
}
