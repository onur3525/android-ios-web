import 'eposta_oneri.dart';
import '../domain/form_mesajlari.dart';

/// ŞİFRE KURALI (ürün kararı — 16 Ağustos'ta güncellendi)
///
/// ASGARİ 8 KARAKTER, AZAMİ 64.
///
/// ⚠ ESKİ DEĞER 6'YDI; STANDARTLARIN ALTINDAYDI.
///
/// NIST SP 800-63B kullanıcı seçimli şifrelerde asgari 8 karakter
/// istiyor ve doğrulayıcının 64+ karakteri DESTEKLEMESİNİ şart
/// koşuyor. OWASP ASVS daha katı (12), ama bir pazaryeri uygulaması
/// için sürtünmesi yüksek görüldü; 8 denge noktası olarak seçildi.
///
/// ⚠ App Store ve Play bu konuda SAYI BELİRTMEZ. Apple yalnız
/// "uygun güvenlik önlemleri" diyor. Yani bu değişiklik mağaza
/// zorunluluğu değil, sektör standardına hizalanmadır.
///
/// ⚠ ŞİMDİ DEĞİŞTİRİLDİ ÇÜNKÜ GERÇEK KULLANICI YOK. Backend canlı
/// olsaydı mevcut kullanıcıların tamamı şifre değiştirmeye
/// zorlanırdı.
///
/// ⚠ İÇERİK ZORUNLULUĞU YOKTUR. Rakam, harf ve simge KULLANILABİLİR
/// ama hiçbiri ŞART DEĞİLDİR — kullanıcı dilediği şifreyi koyar.
/// Standart da keyfi kompozisyon kurallarını (en az bir rakam, en az
/// bir simge) açıkça reddediyor.
const int kPasswordMinLength = 8;

/// ⚠ ÜST SINIR — ÖNCEDEN HİÇ YOKTU.
///
/// Standart azami uzunluğun 64'ün ALTINA düşürülmemesini istiyor:
/// düşük üst sınır şifre yöneticisi kullanan kullanıcıyı engeller.
/// 64 tam olarak o taban değerdir; daha aşağı çekilmemelidir.
const int kPasswordMaxLength = 64;

/// Yerel telefon gösterim uzunluğu: baştaki `0` DAHİL 11 hane.
/// Sunucuya gönderilen normalize değer `phoneFmt` ile 10 haneye iner.
const int kPhoneLocalMaxLength = 11;

/// ═══════════════════════════════════════════════════════════════
/// UYARI METNİ DİLİ — ORTAK KURAL
///
/// Formlardaki tüm uyarılar AYNI dille yazılır:
///   · Kibar ve nötr bitiş: giriniz · olmalıdır · seçiniz
///   · TEK cümle, kısa
///   · PARANTEZ İÇİ AÇIKLAMA YOKTUR. Biçim ipucu, örnek ve sayısal
///     ayrıntı uyarıya EKLENMEZ; bunlar alanın kendi yer tutucusunda
///     zaten yazar. Uyarıda tekrar edilmesi hem uzatıyor hem amatör
///     duruyordu.
///   · Örnek verilmez, tire ile ek cümle bağlanmaz
///   · Suçlayıcı ton yoktur
///
/// ⚠ Yeni bir uyarı eklenirken bu dile uyulur; aynı durum iki farklı
/// cümleyle anlatılmaz.
/// ═══════════════════════════════════════════════════════════════

/// Boş bırakılan zorunlu alanın TEK mesajı.
const String kZorunluAlan = 'Bu alan zorunludur';

class Validators {
  // ── ⚠ DESENLER BİR KEZ DERLENİR (kullanıcı bulgusu, 9 Eyl) ──
  //
  // BULGU: "Ad/soyad/telefon girildikten sonra il-ilçe-mahalle
  // seçimine gelindiğinde yavaşlama oluyor; hiç dokunmadan doğrudan
  // seçime gidilirse kasma yok."
  //
  // ÖLÇÜLEN ZİNCİR:
  //   1. Form `AutovalidateMode.onUserInteraction` ile çalışır —
  //      alanlara DOKUNULANA KADAR hiçbir doğrulayıcı koşmaz. Kasmanın
  //      yalnız yazdıktan sonra başlamasının sebebi budur.
  //   2. Dokunulduktan sonra HER yeniden çizim altı alanı yeniden
  //      doğrular.
  //   3. Kayıt ekranının dolgusu `MediaQuery.viewInsetsOf` değerine
  //      bağlıdır; klavye inip çıkarken 613 satırlık `build` metodu
  //      animasyon boyunca ~15-20 KEZ koşar. İl satırına dokunulduğu
  //      an klavye kapanma ve panel açılma animasyonları ÜST ÜSTE
  //      biner.
  //
  // ⚠ ASIL MALİYET: `RegExp(...)` her çağrıldığında deseni YENİDEN
  // DERLER — Dart bunları önbelleğe almaz. `name()` tek çağrıda dört
  // desen kuruyordu; ad ve soyad ayrı alanlar olduğu için bir
  // doğrulama turu dokuz desen derliyordu. Bunu animasyon kare
  // sayısıyla çarpın.
  //
  // Desenler `static final` alanlara taşındı: SINIF İLK
  // KULLANILDIĞINDA bir kez derlenir, sonra yeniden kullanılır.
  //
  // ⚠ HİÇBİR KURAL DEĞİŞMEDİ: desenlerin metinleri BİREBİR aynı.
  // Değişen tek şey, nerede ve kaç kez derlendikleri. Doğrulama
  // sonuçları aynı kalmalıdır.
  //
  // ⚠ `static final`, `static const` DEĞİL: `RegExp` sabit ifade
  // olamaz; `final` ilk erişimde tembelce kurulur.

  /// Boşluklara böler (`anlamsizKelimeVarMi`).
  static final RegExp _reBosluk = RegExp(r'\s+');

  /// Harf dışı her şeyi atar (`anlamsizKelimeVarMi`).
  static final RegExp _reHarfDisi = RegExp(r"[^a-zA-ZçÇğĞıİöÖşŞüÜ]");

  /// Rakam dışı her şeyi atar — telefon ve kart alanları.
  static final RegExp _reRakamDisi = RegExp(r'\D');

  /// Baştaki sıfırlar (telefon sadeleştirme).
  static final RegExp _reBastakiSifir = RegExp(r'^0+');

  /// E-posta biçimi.
  static final RegExp _reEposta =
      RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(?:\.[\w-]+)*\.[A-Za-z]{2,}$');

  /// Kelimenin baş/son noktalama kırpması (`eposta` önerisi).
  static final RegExp _reKenarNoktalama =
      RegExp(r'^[^a-zçğıöşü]+|[^a-zçğıöşü]+$');

  /// Ad/soyad genel biçimi.
  static final RegExp _reAdBicimi =
      RegExp(r"^[a-zçğıiöşü]+(?:[ '\-][a-zçğıiöşü]+)*$");

  /// Ad içindeki ayırıcılar (boşluk, kesme, tire).
  static final RegExp _reAdAyirici = RegExp(r"[ '\-]+");

  /// Aynı harfin üç kez üst üste gelmesi.
  static final RegExp _reUcTekrar = RegExp(r'(.)\1\1');

  /// Arka arkaya dört sessiz harf.
  static final RegExp _reDortSessiz = RegExp(r'[bcçdfgğhjklmnprsştvyz]{4,}');

  /// Dörtlü gruplama (kart numarası görünümü).
  static final RegExp _reDortluGrup = RegExp(r'.{1,4}');

  /// Son kullanma tarihi AA/YY.
  static final RegExp _reSonKullanma = RegExp(r'^(0[1-9]|1[0-2])/\d{2}$');

  /// ── ⚠ ANLAMSIZ METİN (KLAVYE KARMASI) TESPİTİ ──
  ///
  /// "Jjjj", "dkdkdld", "skskdgaga", "dodkds" gibi rastgele tuş
  /// vuruşlarını yakalamayı hedefler. Bir SÖZLÜK/DİL MODELİ YOKTUR —
  /// üç basit, dürüst kural kullanılır:
  ///   1. Aynı harf 3+ kez ÜST ÜSTE ("jjj", "kkkk")
  ///   2. 4+ harfli kelimede HİÇ sesli harf yok ("dkdkdld")
  ///   3. 4+ ÜST ÜSTE sessiz harf ("skskdgaga" içindeki "sksk")
  ///
  /// ⚠ Bu, İYİ NİYETLİ bir yaklaşıklıktır — gerçek bir dil modeli
  /// DEĞİLDİR. Nadir gerçek kelimeleri (özellikle kısaltmalar)
  /// yanlışlıkla işaretleyebilir; buna karşılık yaygın "klavye
  /// karması" desenini güvenilir şekilde yakalar.
  static bool anlamsizKelimeVarMi(String metin) {
    const sesliler = 'aeıioöuüAEIİOÖUÜ';
    final kelimeler =
        metin.split(_reBosluk).where((k) => k.trim().isNotEmpty);
    for (final kelime in kelimeler) {
      final harfler =
          kelime.replaceAll(_reHarfDisi, '').split('');
      if (harfler.length < 3) {
        continue; // ⚠ Çok kısa kelimeler ("ve", "bir") serbest.
      }

      // Kural 1: aynı harf 3+ kez üst üste.
      for (var i = 0; i + 2 < harfler.length; i++) {
        if (harfler[i].toLowerCase() == harfler[i + 1].toLowerCase() &&
            harfler[i].toLowerCase() == harfler[i + 2].toLowerCase()) {
          return true;
        }
      }

      if (harfler.length < 4) {
        continue; // ⚠ 3 harfli kelimede yalnız Kural 1 uygulanır.
      }

      // Kural 2: hiç sesli harf yok.
      final sesliSayisi =
          harfler.where((h) => sesliler.contains(h)).length;
      if (sesliSayisi == 0) {
        return true;
      }

      // Kural 3: 4+ üst üste sessiz harf.
      var ardisikSessiz = 0;
      for (final h in harfler) {
        if (sesliler.contains(h)) {
          ardisikSessiz = 0;
        } else {
          ardisikSessiz++;
          if (ardisikSessiz >= 4) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Telefon: baştaki 0 atılır, yalnız rakam (HTML phFmt).
  static String phoneFmt(String v) =>
      v.replaceAll(_reRakamDisi, '').replaceFirst(_reBastakiSifir, '');

  /// KULLANICIYA GÖSTERİLEN yerel biçim: başında `0`.
  ///
  /// Backend sözleşmesi DEĞİŞMEZ: gönderim öncesi `phoneFmt` ile
  /// baştaki `0` atılır ve 10 haneli değer üretilir.
  static String phoneLocal(String v) {
    final d = phoneFmt(v);
    if (d.isEmpty) {
      return '';
    }
    return '0$d';
  }

  static String? phone(String? v) {
    final d = phoneFmt(v ?? '');
    if (d.isEmpty) {
      return kZorunluAlan;
    }
    if (d.length != 10 || !d.startsWith('5')) {
      return 'Geçerli bir telefon numarası giriniz';
    }
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) {
      return kZorunluAlan;
    }
    // ⚠ Üst düzey alan adı EN AZ 2 HARF olmalı: `ornek@site.c`
    // gibi eksik adresler kabul EDİLMEZ.
    if (!_reEposta
        .hasMatch(v.trim())) {
      return 'Geçerli bir e-posta adresi giriniz';
    }

    // ── YAYGIN SAĞLAYICIDA YANLIŞ UZANTI REDDEDİLİR ──
    //
    // ⚠ `.co` TEK BAŞINA GEÇERSİZ DEĞİLDİR (Kolombiya alan adı) ve
    // genel bir uzantı listesi tutulmaz — dünyada 1500'den fazla
    // uzantı vardır, listelemek gerçek adresleri reddetmeye yol açar.
    //
    // Buradaki kural DAR ve KESİNDİR: alan adı, bilinen bir posta
    // sağlayıcısına ÇOK BENZİYOR ama tam değilse (bir harf eksik,
    // fazla, yanlış veya yer değiştirmiş) bu bir YAZIM HATASIDIR.
    // `hotmail.co`, `gmail.con`, `gmial.com` bu kurala takılır;
    // `sirketim.co` gibi bilinmeyen alan adları ETKİLENMEZ.
    // ⚠ UYARI METNİ DOĞRU ADRESİ SÖYLEMEZ.
    //
    // Önceden "… hotmail.com olmalı" deniyordu. Bu iki açıdan yanlıştı:
    //   • Kullanıcının adresini biz TAHMİN ediyorduk; benzer yazılan
    //     ama gerçekten farklı bir alan adı kullanan kişiye yanlış
    //     yönlendirme yapılıyordu.
    //   • Girilen adresin hangi sağlayıcıya benzediğini ekrana yazmak
    //     omuz üstünden okuyana bilgi sızdırır.
    //
    // Tüm biçim hataları için TEK ve GENEL uyarı verilir; kullanıcı
    // kendi adresini kendisi düzeltir.
    if (epostaOnerisi(v) != null) {
      return 'Geçerli bir e-posta adresi giriniz';
    }
    return null;
  }

  /// ZAYIF ŞİFRE KARA LİSTESİ.
  ///
  /// ⚠ İŞ + GÜVENLİK KURALI: kolay tahmin edilen şifreler kabul
  /// EDİLMEZ. Bunlar saldırganın ilk denediği dizilerdir; hesabın
  /// ele geçirilmesi kullanıcının değil platformun sorunudur.
  ///
  /// Liste KÖK sözcüklerdir; sonuna rakam eklenmesi (`sifre123`)
  /// veya baş harfin büyütülmesi (`Parola`) kuralı ATLATMAZ.
  static const _zayifSifreler = {
    'sifre', 'şifre', 'sifrem', 'şifrem', 'parola', 'parolam',
    'password', 'passwd', 'pass', 'gizli', 'hesap', 'banka',
    'merhaba', 'selam', 'naber',
    'qwerty', 'qwertz', 'asdf', 'asdfg', 'zxcv', 'zxcvb', 'qazwsx',
    'admin', 'root', 'user', 'kullanici', 'giris', 'login',
    'test', 'deneme', 'ornek', 'demo',
    'iphone', 'android', 'samsung', 'facebook', 'instagram',
    'hizmetcep', 'turkiye', 'istanbul', 'ankara', 'izmir',
    'fenerbahce', 'galatasaray', 'besiktas', 'trabzonspor',
    'seni', 'seviyorum', 'canim', 'askim', 'anne', 'baba',
  };

  /// YENİ şifre kuralı.
  ///
  /// 1. [kPasswordMinLength] – [kPasswordMaxLength] karakter.
  /// 2. İçerik ZORUNLULUĞU yoktur — rakam, harf, simge serbesttir,
  ///    hiçbiri şart değildir.
  /// 3. Ama KOLAY TAHMİN EDİLEN şifreler REDDEDİLİR:
  ///    • sıralı diziler       → `12345678`, `87654321`, `abcdefgh`
  ///    • tekrar eden karakter → `11111111`, `aaaaaaaa`
  ///    • yaygın sözcükler     → `sifre`, `qwerty`, `parola1`
  ///
  /// ⚠ UYARI METİNLERİ KISA TUTULUR. Uzun cümleler alanın içindeki
  /// hata satırına sığmıyor ve üç noktayla KESİLİYORDU: 360 dp'lik
  /// bir telefonda o satıra ~212 dp yer kalıyor, eski metinler ise
  /// 268–305 dp genişliğindeydi.
  static String? password(String? v) {
    if (v == null || v.isEmpty) {
      return kZorunluAlan;
    }
    if (v.length < kPasswordMinLength) {
      return FormMesaj.sifreKisa;
    }
    // ⚠ ÜST SINIR: standart 64'ün altına inilmemesini ister.
    if (v.length > kPasswordMaxLength) {
      return FormMesaj.sifreUzun;
    }
    if (_ardisik(v)) {
      return FormMesaj.sifreArdisik;
    }
    if (_tekrarEden(v)) {
      return FormMesaj.sifreTekrar;
    }
    if (_yaygin(v)) {
      return FormMesaj.sifreYaygin;
    }
    return null;
  }

  /// Tüm karakterler ARDIŞIK mı? (artan veya azalan, kesintisiz)
  ///
  /// `123456` ve `fedcba` reddedilir; `1235` gibi kısa olanlar zaten
  /// uzunluk kuralına takılır. `a1b2c3` ardışık DEĞİLDİR, geçer.
  static bool _ardisik(String v) {
    final k = v.toLowerCase();
    var artan = true;
    var azalan = true;
    for (var i = 1; i < k.length; i++) {
      final fark = k.codeUnitAt(i) - k.codeUnitAt(i - 1);
      if (fark != 1) {
        artan = false;
      }
      if (fark != -1) {
        azalan = false;
      }
      if (!artan && !azalan) {
        return false;
      }
    }
    return artan || azalan;
  }

  /// Tek karakterin tekrarı mı? (`111111`, `aaaaaa`)
  static bool _tekrarEden(String v) {
    final ilk = v.codeUnitAt(0);
    for (var i = 1; i < v.length; i++) {
      if (v.codeUnitAt(i) != ilk) {
        return false;
      }
    }
    return true;
  }

  /// Yaygın sözcük mü?
  ///
  /// Karşılaştırma önce KÜÇÜK HARFE çevirir (Türkçe `İ/I` dâhil),
  /// sonra baştaki/sondaki rakam ve simgeleri ATAR. Böylece
  /// `Sifre123`, `parola!`, `01qwerty` gibi türevler de yakalanır.
  static bool _yaygin(String v) {
    final k = _kucuk(v);
    if (_zayifSifreler.contains(k)) {
      return true;
    }
    final cekirdek = k.replaceAll(_reKenarNoktalama, '');
    return cekirdek.length >= 3 && _zayifSifreler.contains(cekirdek);
  }

  /// ŞİFRE TEKRAR ALANI.
  ///
  /// ⚠ Bu alan şifre KURALLARINI tekrar denetlemez — kurallar birinci
  /// alanda zaten uygulanır. Burada tek soru vardır: iki alan aynı mı?
  ///
  /// Önceden `password()` çağrılıyordu; alan boşken "Bu alan
  /// zorunludur", kısa yazılınca "en az 6 karakter" diyordu. İkisi de
  /// kullanıcıya ASIL sorunu söylemiyordu: yazdığı şifre üsttekiyle
  /// aynı değil.
  static String? passwordRepeat(String? v, String orijinal) {
    final t = v ?? '';
    // ⚠ BOŞ ALAN MESAJI DİĞER ALANLARLA AYNI.
    //
    // "Şifrenizi bir kez daha yazın" tek başına doğruydu ama formdaki
    // öbür boş alanlar "Bu alan zorunludur" diyordu; aynı durum iki
    // farklı cümleyle anlatılıyordu.
    if (t.isEmpty) {
      return kZorunluAlan;
    }
    if (t != orijinal) {
      return 'Şifreler aynı olmalıdır';
    }
    return null;
  }

  /// Türkçe duyarlı küçük harf (`İ→i`, `I→ı`).
  static String _kucuk(String v) =>
      v.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  /// GİRİŞ ekranı şifre doğrulaması.
  ///
  /// ⚠ GİRİŞTE uzunluk dışında kural aranmaz; kayıt kuralı YENİ şifre
  /// belirlerken (kayıt / şifre değiştir / sıfırlama) geçerlidir.
  /// Girişte uygulanırsa kural yürürlüğe girmeden önce oluşturulmuş
  /// daha uzun şifreye sahip kullanıcılar hesaplarına giremez ve
  /// istek sunucuya hiç gitmez.
  ///
  /// Alt sınır korunur: boş veya çok kısa değer yine reddedilir.
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) {
      return kZorunluAlan;
    }
    if (v.length < kPasswordMinLength) {
      return 'Şifreniz en az $kPasswordMinLength karakter olmalıdır';
    }
    return null;
  }

  static const _nameBlock = {
    'ben', 'sen', 'biz', 'siz', 'onlar', 'bu', 'test', 'deneme', 'asd',
    'asdf', 'qwe', 'qwerty', 'abc', 'abcd', 'aaa', 'bbb', 'xxx', 'sdf',
    'sad', 'dsa', 'isim', 'ad', 'soyad', 'evet', 'hayir', 'tamam', 'selam',
    'merhaba', 'falan', 'filan',
  };

  /// Junk isim engeli (HTML nameOk mantığı: harf + sesli + tekrar kontrolleri).
  static String? name(String? v, {int min = 3, String label = 'ad'}) {
    final t = (v ?? '').trim().toLowerCase();
    if (t.isEmpty) {
      return kZorunluAlan;
    }
    // ⚠ TEK VE GENEL MESAJ. "En az 3 harf" ve "gerçek bir ad" ekleri
    String bad() => 'Geçerli bir $label giriniz';
    if (t.length < min) {
      return bad();
    }
    if (!_reAdBicimi.hasMatch(t)) {
      return bad();
    }
    const vowels = 'aeıioöuü';
    for (final w in t.split(_reAdAyirici)) {
      if (w.length < 2 ||
          _nameBlock.contains(w) ||
          !w.split('').any(vowels.contains) ||
          _reUcTekrar.hasMatch(w) ||
          _reDortSessiz.hasMatch(w)) {
        return bad();
      }
    }
    return null;
  }

  /// Kart numarası: 16 hane, 4'lü gruplu görünüm (HTML ncNumFmt).
  static String cardNumFmt(String v) {
    var d = v.replaceAll(_reRakamDisi, '');
    if (d.length > 16) {
      d = d.substring(0, 16);
    }
    return _reDortluGrup
        .allMatches(d)
        .map((m) => m.group(0))
        .join(' ');
  }

  static String? cardNum(String? v) {
    final d = (v ?? '').replaceAll(_reRakamDisi, '');
    if (d.isEmpty) {
      return kZorunluAlan;
    }
    if (d.length != 16) {
      return 'Kart numarası 16 haneli olmalıdır';
    }
    return null;
  }

  /// AA/YY: yazarken otomatik '/', silerken eklenmez (HTML ncExpFmt kuralı).
  static String expFmt(String v, {required bool deleting}) {
    var d = v.replaceAll(_reRakamDisi, '');
    if (d.length > 4) {
      d = d.substring(0, 4);
    }
    if (deleting) {
      return d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    }
    if (d.isNotEmpty && int.parse(d[0]) > 1) {
      d = '0$d';
    }
    if (d.length >= 2) {
      final mm = int.parse(d.substring(0, 2));
      if (mm == 0 || mm > 12) {
        d = d.substring(0, 1);
      }
    }
    if (d.length > 2) {
      return '${d.substring(0, 2)}/${d.substring(2)}';
    }
    return d.length == 2 ? '$d/' : d;
  }

  static String? exp(String? v) {
    if (v == null || v.isEmpty) {
      return kZorunluAlan;
    }
    if (!_reSonKullanma.hasMatch(v)) {
      return 'Geçerli bir son kullanma tarihi giriniz';
    }
    return null;
  }

  static String? cvv(String? v) {
    final d = (v ?? '').replaceAll(_reRakamDisi, '');
    if (d.isEmpty) {
      return kZorunluAlan;
    }
    if (d.length < 3) {
      return 'Güvenlik kodu 3 veya 4 haneli olmalıdır';
    }
    return null;
  }
}
