import 'package:flutter/services.dart';

/// ── ⚠ TUTAR BİÇİMİ — TEK KAYNAK ──
///
/// KULLANICI KURALI (9 Eyl): "TL'yi otomatik ata. Hizmet veren fiyat
/// girerken 1000 yazdığında 1.000 olarak otomatik atasın. 1, 10, 100
/// haricinde sonraki büyük rakamlara otomatik nokta konulsun."
///
/// ⚠ ÖNCEDEN HİÇ BİÇİM YOKTU: tutar dört ayrı ekranda
/// `'${talep.teklifFiyati} TL'` diye ham yazılıyordu — 3000 ekranda
/// "3000 TL" olarak, binlik ayracı olmadan çıkıyordu. Dört kopya,
/// biri düzeltilse ötekiler ayrışırdı.
///
/// ⚠ TÜRKÇE AYRAÇ: binlik ayracı NOKTA, ondalık ayracı virgüldür.
/// Uygulamada tutarlar tam sayı tutulduğu için burada yalnız binlik
/// ayracı vardır; ondalık gerekirse kural yine BURAYA eklenir.

/// 3000 → "3.000" · 1000000 → "1.000.000" · 100 → "100"
///
/// ⚠ ÜÇ BASAMAĞA KADAR AYRAÇ YOK: 1, 10, 100 olduğu gibi kalır —
/// kullanıcının istediği davranış budur.
String binlikAyir(int deger) {
  final negatif = deger < 0;
  final s = deger.abs().toString();
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    // Soldan sağa giderken, kalan basamak sayısı 3'ün katıysa ayraç.
    if (i > 0 && (s.length - i) % 3 == 0) {
      sb.write('.');
    }
    sb.write(s[i]);
  }
  return negatif ? '-${sb.toString()}' : sb.toString();
}

/// Ekranda gösterilen tutar: "3.000 TL"
///
/// ⚠ "TL" BURADA EKLENİR: çağıran ekranlar kendi başına yazmaz,
/// yoksa biri "TL", öteki "₺" yazmaya başlar.
String tutarMetni(int deger) => '${binlikAyir(deger)} TL';

/// [ham] metindeki rakam dışındaki her şeyi atıp sayıya çevirir.
///
/// ⚠ GİRİŞ ALANINDAN OKURKEN ŞART: alanda "3.000" yazıyorsa
/// `int.parse` çöker; noktalar temizlenmeden okunmaz.
int? tutarOku(String ham) {
  final rakamlar = ham.replaceAll(RegExp(r'[^0-9]'), '');
  if (rakamlar.isEmpty) {
    return null;
  }
  return int.tryParse(rakamlar);
}

/// Fiyat alanına yazarken binlik ayracını CANLI uygular.
///
/// ⚠ İMLEÇ SONA ÇEKİLİR: ayraç eklendikçe metnin uzunluğu değişir;
/// imleç eski yerinde bırakılırsa rakamın ortasına düşer. Fiyat
/// alanı tek satırlık ve sayıdan ibaret olduğu için imleci sona
/// almak güvenlidir.
///
/// ⚠ BAŞTAKİ SIFIR YUTULUR: `int` üzerinden geçtiği için "007"
/// yazılamaz; tutar için doğru davranış budur.
class TutarBicimlendirici extends TextInputFormatter {
  const TutarBicimlendirici();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) {
    final deger = tutarOku(yeni.text);
    if (deger == null) {
      // ⚠ ALANI BOŞALTMAK SERBEST: rakam kalmadıysa boş metin döner,
      // "0" YAZILMAZ — kullanıcı silmeye devam edebilmeli.
      return const TextEditingValue();
    }
    final metin = binlikAyir(deger);
    return TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
  }
}
