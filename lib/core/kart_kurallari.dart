/// KART FORMU KURALLARI — TEK MERKEZ
///
/// Kredi kartı, banka kartı ve SANAL KART aynı kurallara tabidir:
/// üçü de aynı numara şemasını (ISO/IEC 7812) kullanır, aynı Luhn
/// denetiminden geçer. Sanal kart için AYRI bir kural YOKTUR — tek
/// farkı numaranın geçici olmasıdır ve bu istemciyi ilgilendirmez.
///
/// ⚠ BURADA KART VERİSİ SAKLANMAZ, SUNUCUYA GÖNDERİLMEZ. Bu dosya
/// yalnız BİÇİM doğrulaması yapar; gerçek geçerlilik (kart açık mı,
/// limit var mı) yalnız ödeme sağlayıcısında belli olur.
///
/// ⚠ Luhn geçmesi kartın GERÇEK olduğunu göstermez; yalnız yazım
/// hatalarını yakalar.
library;

/// Kart ailesi — numara uzunluğu ve CVV uzunluğu buna göre değişir.
enum KartAilesi {
  /// American Express: 15 hane, 4 haneli güvenlik kodu (CID).
  amex,

  /// Diners Club / Discover kısa şeması: 14 hane.
  diners,

  /// Visa · Mastercard · Troy · UnionPay ve diğerleri: 16 hane.
  standart,
}

/// İlk hanelerden kart ailesini bulur.
///
/// ⚠ Numara yazılırken ÇAĞRILIR: aile belli olur olmaz alanın hane
/// sınırı buna göre daralır, böylece fazladan rakam GİRİLEMEZ.
KartAilesi kartAilesi(String haneler) {
  if (haneler.length >= 2) {
    final ilkIki = int.tryParse(haneler.substring(0, 2)) ?? -1;
    if (ilkIki == 34 || ilkIki == 37) {
      return KartAilesi.amex;
    }
    if (ilkIki == 36 || ilkIki == 38 || ilkIki == 39) {
      return KartAilesi.diners;
    }
    if (ilkIki == 30 && haneler.length >= 3) {
      // 300–305 Diners; 3095 de Diners. 306–309 standart kalır.
      final ucuncu = int.tryParse(haneler[2]) ?? 9;
      if (ucuncu <= 5) {
        return KartAilesi.diners;
      }
    }
  }
  return KartAilesi.standart;
}

/// Ailenin gerektirdiği TAM hane sayısı.
int kartHaneSayisi(String haneler) => switch (kartAilesi(haneler)) {
      KartAilesi.amex => 15,
      KartAilesi.diners => 14,
      KartAilesi.standart => 16,
    };

/// Ailenin gerektirdiği TAM CVV uzunluğu.
///
/// ⚠ Amex'te güvenlik kodu 4 hanedir; 3 hane beklemek kartı
/// reddettirir.
int kartCvvUzunlugu(String haneler) =>
    kartAilesi(haneler) == KartAilesi.amex ? 4 : 3;

/// Luhn (mod 10) denetimi.
bool kartLuhn(String haneler) {
  if (haneler.isEmpty) {
    return false;
  }
  var toplam = 0;
  var cift = false;
  for (var i = haneler.length - 1; i >= 0; i--) {
    final k = int.tryParse(haneler[i]);
    if (k == null) {
      return false;
    }
    var d = k;
    if (cift) {
      d *= 2;
      if (d > 9) {
        d -= 9;
      }
    }
    toplam += d;
    cift = !cift;
  }
  return toplam % 10 == 0;
}

/// Kart numarası geçerli mi? (TAM uzunluk + Luhn)
///
/// Eksik hane KABUL EDİLMEZ: "Kartı Kaydet" düğmesi bu yüzden pasif
/// kalır ve kullanıcı sağlayıcıdan hata almadan önce uyarılır.
bool kartNumarasiGecerli(String haneler) =>
    haneler.length == kartHaneSayisi(haneler) && kartLuhn(haneler);

/// Numara grupları — ekranda okunaklı boşluk düzeni.
///
/// Amex referans biçimi `0000 000000 00000`, diğerleri `0000 0000
/// 0000 0000`. Diners 14 hane olduğu için son grup kısa kalır.
String kartNumarasiBicimle(String haneler) {
  final gruplar = kartAilesi(haneler) == KartAilesi.amex
      ? const [4, 6, 5]
      : const [4, 4, 4, 4];
  final b = StringBuffer();
  var i = 0;
  for (final g in gruplar) {
    if (i >= haneler.length) {
      break;
    }
    if (i > 0) {
      b.write(' ');
    }
    final son = (i + g) > haneler.length ? haneler.length : i + g;
    b.write(haneler.substring(i, son));
    i = son;
  }
  // Gruplara sığmayan artık hane (olmamalı; sınırlayıcı engeller).
  if (i < haneler.length) {
    b.write(haneler.substring(i));
  }
  return b.toString();
}

/// `AA/YY` son kullanma tarihi geçerli mi?
///
/// Denetlenen üç şey: biçim, ayın 01–12 aralığı ve tarihin GEÇMİŞ
/// OLMAMASI. Kart, son kullanma AYININ SONUNA kadar geçerlidir —
/// içinde bulunulan ay hâlâ kabul edilir.
///
/// ⚠ `simdi` yalnız test içindir; üretimde verilmez.
bool kartSonKullanmaGecerli(String metin, {DateTime? simdi}) {
  final haneler = metin.replaceAll(RegExp(r'\D'), '');
  if (haneler.length != 4) {
    return false;
  }
  final ay = int.tryParse(haneler.substring(0, 2));
  final yy = int.tryParse(haneler.substring(2));
  if (ay == null || yy == null || ay < 1 || ay > 12) {
    return false;
  }
  final an = simdi ?? DateTime.now();
  final yil = 2000 + yy;
  // Bir sonraki ayın ilk günü > şimdi ⇒ kart hâlâ geçerli.
  final bitis = DateTime(yil, ay + 1, 1);
  return bitis.isAfter(DateTime(an.year, an.month, an.day));
}

/// CVV geçerli mi? Uzunluk kart ailesine göre TAM olmalıdır.
bool kartCvvGecerli(String cvv, String numaraHaneleri) =>
    cvv.length == kartCvvUzunlugu(numaraHaneleri) &&
    RegExp(r'^\d+$').hasMatch(cvv);

/// Kart sahibi adı geçerli mi?
///
/// Kurallar: en az iki kelime, her kelime en az iki harf, yalnız harf
/// ve boşluk. Kart üzerindeki ad rakam içermez; rakam girilirse
/// sağlayıcı reddeder.
bool kartAdiGecerli(String ad) {
  final t = ad.trim();
  if (t.length < 5) {
    return false;
  }
  if (!RegExp(r"^[A-Za-zÇĞİıÖŞÜçğöşü' ]+$").hasMatch(t)) {
    return false;
  }
  final kelimeler = t.split(RegExp(r'\s+')).where((k) => k.isNotEmpty);
  return kelimeler.length >= 2 && kelimeler.every((k) => k.length >= 2);
}
