/// TÜRKÇE DUYARSIZ ARAMA NORMALİZASYONU
///
/// ⚠ `'İ'.toLowerCase()` Unicode kuralına göre `'i' + U+0307`
/// (birleşen nokta) üretir. Bu yüzden `toLowerCase()`'ten SONRA
/// yazılan `replaceAll('İ', 'i')` ÖLÜ KODdur ve büyük harfle yapılan
/// Türkçe arama ("ÇİĞLİ") sonuç vermez.
///
/// Doğru sıra: Türkçe büyük harfler ÖNCE sadeleştirilir, sonra
/// `toLowerCase()` uygulanır.
String turkceNormalize(String s) {
  // 1) Türkçe büyük harfler — toLowerCase'TEN ÖNCE.
  final on = s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('Ş', 's')
      .replaceAll('Ğ', 'g')
      .replaceAll('Ü', 'u')
      .replaceAll('Ö', 'o')
      .replaceAll('Ç', 'c');

  // 2) Küçük harfe indir, kalan Türkçe küçük harfleri sadeleştir.
  return on
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      // Birleşen nokta kalıntısı (güvenlik ağı).
      .replaceAll('\u0307', '');
}
