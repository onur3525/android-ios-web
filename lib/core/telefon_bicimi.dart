import 'package:flutter/services.dart';

import 'validators.dart';

/// TELEFON ALANI BİÇİMLENDİRİCİSİ
///
/// ── KURAL ──
///
/// 1. Baştaki `0` ELLE YAZILAMAZ. Kullanıcı ilk tuş olarak `0`
///    yazarsa yok sayılır; `0` yalnız geçerli bir numara yazılmaya
///    başlandığında OTOMATİK eklenir.
///    → `0 0555…` gibi çift sıfır OLUŞAMAZ.
///
/// 2. GEÇERSİZ NUMARA ALANA HİÇ GİRMEZ. Türkiye cep numaraları `5`
///    ile başlar; ilk hane `5` değilse tuş kabul edilmez. Kullanıcı
///    `0333…` yazıp gönderim anında hata almak yerine, yanlış haneyi
///    zaten yazamaz.
///
/// 3. En fazla 10 hane (baştaki `0` hariç) — toplam 11 karakter.
///
/// 4. Rakam dışı her karakter atılır (boşluk, tire, parantez dâhil).
///    Yapıştırılan `+90 555 563 19 93` gibi değerler de temizlenir.
///
/// ⚠ Bu kural TEK YERDE tanımlıdır; beş telefon alanı da bunu
/// kullanır, ekranlar arasında ayrışamaz.
///
/// ⚠ Backend sözleşmesi DEĞİŞMEZ: gönderim öncesi `Validators.phoneFmt`
/// baştaki `0`ı atar ve 10 haneli değer üretir.
class TelefonBicimlendirici extends TextInputFormatter {
  const TelefonBicimlendirici();

  /// Ülke kodu yapıştırıldığında temizlenecek önek.
  static const _ulkeKodu = '90';

  /// BOŞ ALAN DEĞERİ — imleç GEÇERLİ konumda (0).
  static const _bos = TextEditingValue(
    text: '',
    selection: TextSelection.collapsed(offset: 0),
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) {
    // ── SİLME SORUNUNUN KÖKÜ VE ÇÖZÜMÜ ──
    //
    // ⚠ ESKİ DAVRANIŞ ÜÇ AYRI HATA ÜRETİYORDU:
    //
    //   1. Metin ALAN İÇİNDE gruplanıyordu (`0532 111 22 33`). Klavye
    //      bir karakter silince biçimlendirici boşlukları yeniden
    //      diziyor, metin kullanıcının beklediğinden farklı çıkıyordu.
    //
    //   2. Baştaki `0` HER TUŞTA yeniden ekleniyordu. Kullanıcı onu
    //      silmeye çalıştığında anında geri geliyor, hiçbir zaman
    //      silinemiyordu.
    //
    //   3. İmleç HER DÜZENLEMEDE sona zorlanıyordu. Ortadan veya
    //      baştan silme imkânsızdı; imleç kaçtığı için tuşlar
    //      "takılıyor" gibi hissediliyordu.
    //
    // Üçü birleşince Android IME beklemediği değişiklikler alıyor,
    // bileşim durumunu sıfırlıyor ve hızlı silmede kare süresi aşılıp
    // uygulama yanıt veremez hâle geliyordu.
    //
    // ── YENİ DAVRANIŞ ──
    //
    // Alanda HAM YEREL biçim durur: `05321112233`. Boşluklu gösterim
    // yalnız OKUMA yerlerinde uygulanır (`gruplu`).
    //
    // Kural yalnız iki şey yapar: rakam dışını atar ve uzunluğu
    // sınırlar. Baştaki `0` sadece alan BOŞKEN ilk rakam girildiğinde
    // eklenir; sonrasında kullanıcının metnine karışılmaz — silinebilir.
    //
    // İmleç KORUNUR: kullanıcı nereye koyduysa orada kalır.
    final eskiHane = eski.text.replaceAll(RegExp(r'\D'), '');
    var haneler = yeni.text.replaceAll(RegExp(r'\D'), '');

    // `+90 …` yapıştırıldıysa ülke kodunu at (yalnız tam numarada).
    if (haneler.length >= 12 && haneler.startsWith(_ulkeKodu)) {
      haneler = haneler.substring(_ulkeKodu.length);
    }

    // ⚠ TAMAMEN SİLME SERBEST. Alan boşaltılabilir.
    //
    // ⚠ `const TextEditingValue()` DÖNDÜRÜLMEZ.
    //
    // Varsayılan seçim `TextSelection.collapsed(offset: -1)`, yani
    // GEÇERSİZ bir imleç konumudur. Alanda son kalan hane (`0`)
    // silinince bu değer IME'ye gidiyor, bileşim durumu bozuluyor ve
    // silme tuşu "takılmış" gibi davranıyordu; ardından yazılan ilk
    // rakam da yanlış konuma düşüyordu (bkz. aşağıdaki imleç notu).
    //
    // ⚠ KESİN KÖK NEDEN OLARAK İLAN EDİLMEMİŞTİR: cihazda ölçüm
    // yapılamadı. Geçersiz imleç konumu SOMUT bir kusurdur ve
    // düzeltilmiştir; davranışın tümüyle düzelip düzelmediği cihazda
    // doğrulanacaktır.
    if (haneler.isEmpty) {
      return _bos;
    }

    // ── ⚠ İLK GİRİŞ KURALI (yalnız alan BOŞKEN) ──
    //
    // ⚠ BAŞTAKİ `0` ARTIK YAZMA ANINDA EKLENMİYOR.
    //
    // Eskiden ilk rakam girildiğinde metne otomatik `0` ekleniyordu.
    // Bu, kullanıcının BASTIĞI tuş sayısı ile alandaki karakter
    // sayısını EŞİTSİZ hale getiriyordu: bir tuşa basılıyor, metin
    // iki karakter uzuyordu.
    //
    // Android IME, biçimlendiricinin metni uzattığını ancak bir
    // sonraki güncellemeyle öğrenir. Kullanıcı o güncelleme cihaza
    // ulaşmadan bir sonraki tuşa basarsa, IME kendi bildiği ESKİ
    // metin üzerinden düzenleme gönderir; imleç hesabı kayar ve
    // hızlı ardışık yazımda RAKAM DÜŞER. Yavaş yazımda pencere
    // kapandığı için sorun görünmezdi.
    //
    // ⚠ ARTIK UZUNLUK DEĞİŞTİRİLMİYOR: kural yalnız rakam dışını
    // atar ve sınırlar. Kullanıcı `5` ile başlar.
    //
    // ⚠ BACKEND SÖZLEŞMESİ ETKİLENMEZ. `Validators.phoneFmt` baştaki
    // sıfırları zaten atıyor, `Validators.phone` 10 haneli ve `5` ile
    // başlayan değeri doğruluyor. Gösterimde `0` gerektiğinde
    // `Validators.phoneLocal` üretir. Yani `0` ihtiyacı NORMALİZE ve
    // GÖNDERİM aşamasında karşılanır, yazma anında değil.
    //
    // ⚠ Bu kurallar DÜZENLEME sırasında İŞLEMEZ. İşleseydi kullanıcı
    if (eskiHane.isEmpty) {
      // Türkiye cep numaraları `5` ile başlar. İlk hane `0` da olabilir:
      // sunucudan gelen numara alana `phoneLocal` ile `0532…` biçiminde
      // yazılır ve kullanıcı onu düzenleyebilmelidir. Başka bir rakamla
      // başlayan giriş alana HİÇ girmez.
      final ilk = haneler[0];
      if (ilk != '5' && ilk != '0') {
        return _bos;
      }
    }

    // Fazla sıfırlar temizlenir (`00532…` → `0532…`).
    haneler = haneler.replaceFirst(RegExp(r'^0{2,}'), '0');

    // ⚠ SINIR, BAŞTAKİ `0`IN VARLIĞINA GÖRE HESAPLANIR.
    //
    // `0` ile başlayan yerel biçim 11 hanedir (`05321112233`); `5`
    // ile başlayan biçim 10 hanedir (`5321112233`). Tek bir sabit
    // sınır kullanılsaydı, `5` ile başlayan alanda kullanıcı 11.
    final sinir = haneler.startsWith('0')
        ? kPhoneLocalMaxLength
        : kPhoneLocalMaxLength - 1;
    if (haneler.length > sinir) {
      haneler = haneler.substring(0, sinir);
    }

    // ⚠ İMLEÇ KORUNUR.
    //
    // Metin uzunluğu değiştiyse imleç, kullanıcının konumundan metnin
    // ne kadar kısaldığı/uzadığı kadar kaydırılır. Sona zorlanmaz.
    // ⚠ GEÇERSİZ TABAN KONUMU (`-1`) SONA ÇEVRİLİR.
    //
    // Alan boşaltıldıktan sonra gelen ilk düzenlemede `baseOffset`
    // `-1` olabiliyordu; `-1 + fark` küçük bir sayı verip imleci
    // metnin BAŞINA atıyor, sonraki rakamlar başa ekleniyordu.
    final taban = yeni.selection.baseOffset < 0
        ? yeni.text.length
        : yeni.selection.baseOffset;
    final fark = haneler.length - yeni.text.length;
    var konum = taban + fark;
    if (konum < 0) {
      konum = 0;
    }
    if (konum > haneler.length) {
      konum = haneler.length;
    }

    return TextEditingValue(
      text: haneler,
      selection: TextSelection.collapsed(offset: konum),
    );
  }

  /// GÖSTERİM BİÇİMİ — `0532 111 22 33` (4-3-2-2).
  ///
  /// ⚠ Numara BİTİŞİK YAZILMAZ. `05321112233` okunması zor ve
  /// hataya açıktır; kullanıcı kendi numarasını gözle doğrulayamaz.
  /// Gruplama alanın İÇİNDE yapılır, ekranda gösterilen değer budur.
  ///
  /// ⚠ Doğrulama ve gönderim etkilenmez: `Validators.phoneFmt`
  /// rakam dışını atar, backend yine 10 haneli değeri alır.
  static String gruplu(String yerel) {
    final d = yerel.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 4) {
      return d;
    }
    if (d.length <= 7) {
      return '${d.substring(0, 4)} ${d.substring(4)}';
    }
    if (d.length <= 9) {
      return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    }
    return '${d.substring(0, 4)} ${d.substring(4, 7)} '
        '${d.substring(7, 9)} ${d.substring(9)}';
  }

  /// Doğrulama tarafıyla aynı kaynağı kullandığını gösterir.
  static String yerel(String v) => Validators.phoneLocal(v);
}
