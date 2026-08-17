import 'package:flutter/widgets.dart';

/// AD / SOYAD BAŞ HARFİ BÜYÜK — TÜRKÇE DUYARLI
///
/// Kullanıcı "onur" yazdığında alanda "Onur" görünür.
///
/// ── NEDEN `TextCapitalization` YETMEZ ──
///
/// `TextCapitalization.words` yalnız KLAVYEYE VERİLEN BİR İPUCUDUR.
/// Kullanıcı büyük harf ipucunu yok sayabilir, panodan küçük harfle
/// yapıştırabilir ya da klavye bu ipucunu desteklemeyebilir. Bu yüzden
/// ipucunun yanında biçim ZORLANIR.
///
/// ── NEDEN `toUpperCase()` DEĞİL ──
///
/// Dart'ın `toUpperCase()` metodu Türkçe'yi bilmez:
///   'i'.toUpperCase() → 'I'   (yanlış — 'İ' olmalı)
///   'ı'.toUpperCase() → 'I'   (doğru)
/// "irem" → "Irem" olurdu. Eşleme burada elle yapılır.
///
/// ── SEÇİM (İMLEÇ) NEDEN BOZULMAZ ──
///
/// Dönüşüm yalnız harf BÜYÜKLÜĞÜNÜ değiştirir; metnin uzunluğu
/// değişmez. Bu yüzden gelen `selection` olduğu gibi korunabilir ve
/// imleç yazarken yerinden oynamaz.
/// AD/SOYAD BİÇİMİ — YAZARKEN DEĞİL, ALANDAN ÇIKINCA.
///
/// ⚠ ESKİ `AdBicimiFormatter` KALDIRILDI.
///
/// Her tuşta metni yeniden yazıyordu: `"Onur"` içinde baştaki `O`
/// silinince kalan `"nur"` anında `"Nur"` yapılıyordu. Metin
/// kullanıcının yazdığından farklı olunca Android IME bileşim
/// durumunu sıfırlıyor; hızlı silmede tuşlar kayboluyor veya geç
/// işleniyordu.
///
/// Artık kullanıcı yazarken metnine karışılmaz; biçim alandan
/// ÇIKILDIĞINDA bir kez uygulanır. Sonuç aynı, yazma ve silme akıcı.

/// Alandan çıkıldığında ad/soyad biçimini uygular.
///
/// Metin zaten doğruysa denetleyiciye HİÇ dokunulmaz; gereksiz
/// bildirim ve imleç sıçraması olmaz.
void adAlaniBicimle(TextEditingController c) {
  final duzeltilmis = adBicimlendir(c.text);
  if (duzeltilmis == c.text) {
    return;
  }
  c.value = TextEditingValue(
    text: duzeltilmis,
    selection: TextSelection.collapsed(offset: duzeltilmis.length),
  );
}


/// Türkçe büyük harf karşılığı (tek karakter).
String trBuyuk(String h) => switch (h) {
      'i' => 'İ',
      'ı' => 'I',
      _ => h.toUpperCase(),
    };

/// Türkçe küçük harf karşılığı (tek karakter).
String trKucuk(String h) => switch (h) {
      'I' => 'ı',
      'İ' => 'i',
      _ => h.toLowerCase(),
    };

/// "onur bütün" → "Onur Bütün"
///
/// Kelime sınırı: boşluk, kısa çizgi ve kesme işareti. Böylece
/// "ali-veli" → "Ali-Veli", "d'angelo" → "D'Angelo" olur.
/// Boşluklar OLDUĞU GİBİ korunur — kullanıcı iki kelime arasına
/// boşluk koyarken metin kısalmaz.
String adBicimlendir(String metin) {
  if (metin.isEmpty) {
    return metin;
  }
  const ayirici = {' ', '-', "'", '’'};
  final b = StringBuffer();
  var yeniKelime = true;
  for (final h in metin.characters0) {
    if (ayirici.contains(h)) {
      b.write(h);
      yeniKelime = true;
      continue;
    }
    b.write(yeniKelime ? trBuyuk(h) : trKucuk(h));
    yeniKelime = false;
  }
  return b.toString();
}

/// `characters` paketine bağımlılık eklemeden karakter karakter gezinme.
///
/// Ad/soyad alanları tek kod noktalı harflerden oluşur; bileşik
/// grafemler (emoji vb.) bu alanlarda zaten geçerli değildir.
extension _Karakterler on String {
  Iterable<String> get characters0 sync* {
    for (var i = 0; i < length; i++) {
      yield this[i];
    }
  }
}
