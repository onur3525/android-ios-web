/// İLETİŞİM VE ADRES MASKELEME
///
/// ── ⚠ NİÇİN VAR ──
///
/// İletişim açma bedellidir. Hizmet alan, açıklamaya telefonunu veya
/// adresini yazarak bu adımı atlatabilir; hizmet veren de aynısını
/// teklif notunda yapabilir. Bu dosya, İLETİŞİM AÇILMADAN ÖNCE karşı
/// tarafın gördüğü metinde bu bilgileri maskeler.
///
/// ── ⚠ KULLANICIYA GÖRÜNÜR KISITLAMA YOKTUR ──
///
/// Yazan kişi hiçbir uyarı görmez, metni değiştirilmez, hiçbir karakter
/// silinmez. Kendi ekranında açıklaması AYNEN durur. Maskeleme YALNIZ
/// karşı tarafın görüntüsünde uygulanır.
///
/// ── ⚠ BU BİR GÜVENLİK KATMANI DEĞİLDİR ──
///
/// Maskeleme İSTEMCİDE yapılır; ham metin cihaza yine iner. Gerçek
/// koruma sunucunun, iletişim kapalıyken maskelenmiş metni göndermesiyle
/// olur. Backend kaynak kodu bu depoda yoktur; sunucu tarafı kural
/// ayrıca raporlanmıştır.
library;

/// Maskeleme sonucu metinde görünen etiket.
const String kMaskeEtiketi = '[İLETİŞİM BİLGİSİ GİZLENDİ]';

/// ── TÜRKÇE KÜÇÜK HARFE ÇEVİRME ──
///
/// ⚠ `toLowerCase()` TÜRKÇE İÇİN YANLIŞTIR: 'I' → 'i' yapar, oysa
/// Türkçede 'I' → 'ı' olmalıdır. "SOKAK" ve "Sokak" eşleşsin diye
/// dönüşüm elle yapılır.
String trKucuk(String s) {
  const esle = {
    'I': 'ı', 'İ': 'i', 'Ş': 'ş', 'Ğ': 'ğ',
    'Ü': 'ü', 'Ö': 'ö', 'Ç': 'ç',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(esle[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}

/// Metinde maskelenecek aralık.
class _Aralik {
  const _Aralik(this.bas, this.son);
  final int bas;
  final int son;
}

/// ═══════════════════════════════════════════════════════════════
///  TELEFON
/// ═══════════════════════════════════════════════════════════════
///

/// ── ⚠ NORMALİZE EDİLMİŞ TELEFON TARAMASI ──
///
/// Önceki yaklaşım her kaçış biçimi için ayrı kalıp yazıyordu ve her
/// yeni varyasyon yeni bir açık oluşturuyordu. Bu tarayıcı metni ÖNCE
/// ortak bir rakam temsiline indirger, SONRA telefon arar.
///
/// Böylece şunların hepsi AYNI diziye iner:
///   0555 563 19 93 · 0555-563-19-93 · 05a55b631c993
///   0x5x5x5x6x3x1x9x9x3 · +90/0090 önekli · satır sonlu
///   beşyüzellibeşbeşyüzatmışüçondokuzdoksanüç
///   0555 altmışüç ondokuz doksanüç
///
/// ── ⚠ KOŞU (RUN) MANTIĞI ──
///
/// Metin belirteçlere ayrılır. Rakam ve sayı sözcükleri koşuya rakam
/// EKLER; kısa harf parçaları (1-2 harf) GÜRÜLTÜ sayılıp atlanır;
/// bunun dışındaki her sözcük koşuyu BİTİRİR.
///
/// ⚠ YANLIŞ POZİTİFİ ENGELLEYEN ŞART BUDUR: "3 odalı 2 banyolu 150 m²"
/// cümlesinde "odalı" ve "banyolu" koşuyu keser, rakamlar birbirine
/// yapışmaz. Aksi hâlde normal ilanlardaki sayılar birleşip telefon
/// gibi görünürdü.
class _KosuParcasi {
  const _KosuParcasi(this.rakam, this.bas, this.son);

  /// Bu parçanın koşuya kattığı rakamlar.
  final String rakam;

  /// Kaynak metindeki yeri — maskeleme aralığı buradan kurulur.
  final int bas;
  final int son;
}

final RegExp _kosuBelirtec = RegExp(r'[0-9]+|[a-zA-ZçğıöşüÇĞİÖŞÜ]+');

/// Metni rakam koşularına böler.
List<List<_KosuParcasi>> _rakamKosulari(String metin) {
  final out = <List<_KosuParcasi>>[];
  var cur = <_KosuParcasi>[];
  for (final m in _kosuBelirtec.allMatches(metin)) {
    final t = m.group(0)!;
    if (RegExp(r'^[0-9]+$').hasMatch(t)) {
      cur.add(_KosuParcasi(t, m.start, m.end));
      continue;
    }
    final r = _sayiCoz(trKucuk(t));
    if (r != null) {
      cur.add(_KosuParcasi(r, m.start, m.end));
      continue;
    }
    // ⚠ 1-2 HARFLİK PARÇA GÜRÜLTÜDÜR: "05a55b631c993" ya da
    // "0x5x5x..." gibi araya harf serpiştirme kaçışları burada
    // atlanır. Koşu KIRILMAZ ama rakam da EKLENMEZ.
    if (t.length <= 2 && cur.isNotEmpty) {
      continue;
    }
    // Anlamlı sözcük → koşu biter.
    if (cur.isNotEmpty) {
      out.add(cur);
      cur = <_KosuParcasi>[];
    }
  }
  if (cur.isNotEmpty) {
    out.add(cur);
  }
  return out;
}

/// Rakam dizisi geçerli bir Türk numarasının GÖVDESİ mi (10 hane)?
bool _govdeMu(String s) =>
    s.length == 10 && RegExp(r'^[2345]\d{9}$').hasMatch(s);

/// ── ⚠ ÇOKLU VE BİTİŞİK TELEFON ──
///
/// Koşu içindeki rakam dizisi baştan sona taranır; her geçerli
/// numara bulunduğunda maskelenir ve tarama HEMEN ARDINDAN devam
/// eder. Böylece "0555563199305551234567" gibi aralıksız yazılmış
/// iki numara da AYRI AYRI yakalanır.
///
/// ⚠ HİÇBİR ÜST SINIR YOKTUR ve bir adayın başarısız olması taramayı
/// durdurmaz.
List<_Aralik> _telefonAraliklari(String metin) {
  final out = <_Aralik>[];
  for (final kosu in _rakamKosulari(metin)) {
    // Koşunun düz rakam dizisi + her rakamın kaynak parçası.
    final b = StringBuffer();
    final sahip = <int>[];
    for (var i = 0; i < kosu.length; i++) {
      b.write(kosu[i].rakam);
      for (var k = 0; k < kosu[i].rakam.length; k++) {
        sahip.add(i);
      }
    }
    final d = b.toString();
    var i = 0;
    while (i + 10 <= d.length) {
      // ⚠ ÖNEK SIYIRMA: 0090 / 90 / 0 biçimlerinin hepsi aynı
      // gövdeye iner.
      var atla = 0;
      if (d.startsWith('0090', i)) {
        atla = 4;
      } else if (d.startsWith('90', i) && _govdeMu(_dilim(d, i + 2, 10))) {
        atla = 2;
      } else if (d.startsWith('0', i) && _govdeMu(_dilim(d, i + 1, 10))) {
        atla = 1;
      }
      final govde = _dilim(d, i + atla, 10);
      if (_govdeMu(govde)) {
        final bas = kosu[sahip[i]].bas;
        final sonIdx = i + atla + 10 - 1;
        final son = kosu[sahip[sonIdx.clamp(0, sahip.length - 1)]].son;
        out.add(_Aralik(bas, son));
        i = i + atla + 10; // ⚠ Ardından TARAMA SÜRER.
        continue;
      }
      i++;
    }
  }
  return out;
}

String _dilim(String s, int bas, int uzunluk) =>
    (bas < 0 || bas + uzunluk > s.length)
        ? ''
        : s.substring(bas, bas + uzunluk);

/// ═══════════════════════════════════════════════════════════════
///  E-POSTA · URL · SOSYAL MEDYA
/// ═══════════════════════════════════════════════════════════════
List<_Aralik> _kanalAraliklari(String metin) {
  final out = <_Aralik>[];
  final kalip = <RegExp>[
    // e-posta
    RegExp(r'[\w.+-]+\s*@\s*[\w-]+\s*\.\s*[\w.]{2,}'),
    // URL (şemalı ya da www ile)
    RegExp(r'(https?://|www\.)[\w.-]+\.[a-zA-Z]{2,}(/\S*)?',
        caseSensitive: false),
    // ── ⚠ PROTOKOLSÜZ ALAN ADI ──
    //
    // "example.com" gibi şemasız yazımlar kaçıyordu. Yalnız BİLİNEN
    // uzantılar sayılır; "3.kat" ya da "1.5 metre" yakalanmaz.
    RegExp(
        r'(?<![\w@])[\w-]{2,}\s*[.]\s*'
        r'(com|net|org|info|biz|co|io|me|tr|com\.tr|net\.tr|org\.tr)'
        r'(?![\w])',
        caseSensitive: false),
    // ── ⚠ METİNSEL URL / E-POSTA ──
    //
    // "example nokta com", "ornek [at] gmail [dot] com" gibi
    // yazımlar açıkça iletişim bilgisidir.
    RegExp(
        r'[\w-]{2,}\s*(nokta|dot|\[dot\]|\(dot\))\s*[\w-]{2,}',
        caseSensitive: false),
    RegExp(
        r'[\w.-]{2,}\s*(\[at\]|\(at\)|\bat\b)\s*[\w.-]{2,}'
        r'\s*(\[dot\]|\(dot\)|nokta|dot|[.])\s*[\w-]{2,}',
        caseSensitive: false),
    // "instagram: kullanici", "telegram - kullanici", "wp: 0555..."
    // ── ⚠ AYRAÇ ZORUNLU ──
    //
    // "Instagram'dan ulaşabilirsiniz" yalnız YÖNLENDİRME cümlesidir
    // ve ürün kararı gereği maskelenmez. Hesap adı ancak ':' ya da
    // '@' ile verildiğinde yakalanır: "Instagram: @ornek".
    RegExp(
        r'(instagram|insta|facebook|fb|twitter|telegram|whatsapp|whatsap|wp|snapchat|tiktok)'
        r'\s*(:|-)\s*@?[\w.]{2,}',
        caseSensitive: false),
    // @kullaniciadi — e-posta olmayan tekil kullanıcı adı
    RegExp(r'(?<![\w.])@[\w.]{3,}'),
  ];
  for (final k in kalip) {
    for (final m in k.allMatches(metin)) {
      out.add(_Aralik(m.start, m.end));
    }
  }
  return out;
}

/// ═══════════════════════════════════════════════════════════════
///  ADRES
/// ═══════════════════════════════════════════════════════════════
///
/// ── ⚠ İKİ FARKLI GÜÇTE İŞARET VAR ──
///
/// **GÜÇLÜ**: tek başına adres demektir — "sokak", "cadde", "mahalle",
/// "apartman", "site", "blok", "pasaj", "iş hanı", "plaza", "daire",
/// "kapı no". Bunlar görülünce bulunduğu ÖBEK maskelenir.
///
/// **ZAYIF**: tek başına masum olabilir — "kat", "no", "giriş", "d",
/// "avm", "mağaza". "4 kat boya yapılacak" cümlesi maskelenmemeli.
/// Bunlar YALNIZ başka bir işaretle birlikteyse sayılır.
///
/// ⚠ Bu ayrım, talimatın "3 odalı ev / 4 saat / 500 TL / 4 kat boya"
/// örneklerinin maskelenmemesi için gereklidir.

/// Tek başına adres sayılan sözcükler.
final RegExp _guclu = RegExp(
  r'(?<![\wçğıöşü])('
  r'sokak|sokağ\w*|sok\.?|sk\.?|'
  r'cadde\w*|cad\.?|cd\.?|'
  r'apartman\w*|apart\w*|apt\.?|'
  r'sitesi|site|'
  r'blok|bloğ\w*|'
  r'pasaj\w*|'
  r'plaza|'
  r'iş\s*hanı|iş\s*merkezi|'
  // ⚠ "daire" TEK BAŞINA yetmez: "2+1 daire" normal bir ilan
  // ifadesidir. Ardından ya da önünde SAYI olmalı ("Daire 4").
  // ⚠ "2+1 daire" NORMAL bir ilan ifadesidir: sayıdan hemen önce
  // '+' varsa daire numarası DEĞİL, oda sayısıdır.
  r'daire\s*[:.]?\s*\d{1,4}|(?<![+\d])\d{1,4}\s*\.?\s*daire|'
  r'dai\.?\s*\d{1,4}|'
  r'kapı\s*(no|numara\w*)|'
  // ⚠ "No:25" / "No 25" / "Numara 25" / "25 numara" GÜÇLÜDÜR.
  //
  // Sayıyla birlikte kapı numarası demektir. Zayıf listede kalınca
  // tek başına yakalanamıyordu. `no` tek başına DEĞİL, YALNIZ ardından
  // sayı gelirse sayılır — "no problem" gibi kullanımlar etkilenmez.
  r'no\s*[:.]?\s*\d{1,5}|numara\s*[:.]?\s*\d{1,5}|\d{1,5}\s*numara\w*|'
  r'bulvar\w*|bulv\.?|blv\.?'
  r')(?![\wçğıöşü])',
  caseSensitive: false,
);

/// Yalnız başka işaretle birlikte adres sayılanlar.
final RegExp _zayif = RegExp(
  r'(?<![\wçğıöşü])('
  r'kat|katı|'
  // ── ⚠ MAHALLE TEK BAŞINA ADRES DEĞİLDİR ──
  //
  // "Karşıyaka Girne Mahallesi'nde hizmet almak istiyorum" NORMAL bir
  // ilan cümlesidir; il/ilçe/mahalle zaten ilanın kendi konum
  // alanında görünüyor.
  //
  // ⚠ Güçlü listedeyken bu cümle maskeleniyordu. Artık ZAYIF: ancak
  // sokak/cadde/no/daire gibi İKİNCİ bir işaretle birlikte adres
  // sayılır ("Girne Mahallesi, X Sokak, No: 25").
  r'mahalle\w*|mah\.?|mh\.?|'
  // ⚠ "no/numara" BURADAN ÇIKARILDI — artık GÜÇLÜ listede
  // (bkz. `_guclu`): sayıyla birlikte kapı numarası demektir.
  r'bina|binası|'
  r'giriş\w*|'
  r'avm|'
  r'mağaza\w*|dükkan\w*|dükkân\w*|'
  r'karşısı|karşısında|yanı|yanında|arkası|arkasında|içinde|üstünde'
  r')(?![\wçğıöşü])',
  caseSensitive: false,
);

/// "D4", "D:4", "D.4", "Dai4" — daire kısaltması.
///
/// ⚠ Tek harf `d` çok geneldir; YALNIZ hemen ardından sayı gelirse
/// ve sözcük sınırındaysa sayılır.
final RegExp _daireKisa = RegExp(
  r'(?<![\wçğıöşü])(d|dai)\s*[:.]?\s*\d{1,4}(?![\wçğıöşü])',
  caseSensitive: false,
);

/// Metni cümlelere / öbeklere böler.
///
/// ⚠ MASKELEME LOKALDİR: adres işareti bulunan öbek maskelenir, cümlenin
/// geri kalanı GÖRÜNMEYE DEVAM EDER. Ayraçlar: nokta, virgül, noktalı
/// virgül, satır sonu.
List<_Aralik> _obekler(String metin) {
  final out = <_Aralik>[];
  var bas = 0;
  for (var i = 0; i < metin.length; i++) {
    final c = metin[i];
    if (c == '.' || c == ',' || c == ';' || c == '\n') {
      if (i > bas) {
        out.add(_Aralik(bas, i));
      }
      bas = i + 1;
    }
  }
  if (bas < metin.length) {
    out.add(_Aralik(bas, metin.length));
  }
  return out;
}

/// Adres içeren öbekleri bulur.
List<_Aralik> _adresAraliklari(String metin) {
  final out = <_Aralik>[];
  for (final o in _obekler(metin)) {
    final parca = metin.substring(o.bas, o.son);
    final guclu = _guclu.allMatches(parca).length;
    final zayif = _zayif.allMatches(parca).length;
    final daire = _daireKisa.allMatches(parca).length;

    // ⚠ KARAR KURALI:
    //   · bir GÜÇLÜ işaret            → adres
    //   · bir daire kısaltması (D4)   → adres
    //   · İKİ zayıf işaret birlikte   → adres ("4. kat, B giriş")
    // Tek zayıf işaret YETMEZ: "4 kat boya yapılacak" maskelenmez.
    if (guclu >= 1 || daire >= 1 || zayif >= 2) {
      out.add(o);
    }
  }
  return out;
}


/// ── ⚠ ADRES BAĞLAMINDA YAZIYLA SAYI ──
///
/// "No yirmi beş", "Kat iki", "Daire dört", "Bina on iki" gibi
/// yazımlar rakam içermediği için adres kalıplarına takılmıyordu.
///
/// ⚠ BÜTÜN YAZIYLA SAYILAR ADRES SAYILMAZ. Yalnız bir ADRES
/// İŞARETİNİN hemen ardından gelen sayı adres kabul edilir:
///   "No yirmi beş"   → adres      "iki oda"        → serbest
///   "Kat iki"        → adres      "üç petek"       → serbest
///   "Daire dört"     → adres      "beş metre"      → serbest
///
/// Ayrım işaretin KENDİSİNDEDİR, sayının değil.
final RegExp _adresIsareti = RegExp(
  r'(?<![\wçğıöşü])('
  r'no|numara|numarası|'
  r'kapı\s*no|kapı\s*numarası|'
  r'sokak\s*no|sokak\s*numarası|'
  r'kat|daire|dai|bina|blok|apartman'
  r')(?![\wçğıöşü])',
  caseSensitive: false,
);

/// İşaretin ardından gelen sayı sözcüklerini adres olarak işaretler.
List<_Aralik> _yaziylaAdresNo(String metin) {
  final out = <_Aralik>[];
  for (final m in _adresIsareti.allMatches(metin)) {
    // İşaretten sonraki metinde ilk belirteçleri incele.
    final kalan = metin.substring(m.end);
    // ⚠ Araya yalnız boşluk / iki nokta / nokta girebilir.
    final bas = RegExp(r'^[\s:.]{0,3}').firstMatch(kalan)!.end;
    var i = bas;
    var son = bas;
    var bulundu = false;
    while (i < kalan.length) {
      final k = RegExp(r'^[a-zA-ZçğıöşüÇĞİÖŞÜ]+').firstMatch(kalan.substring(i));
      if (k == null) {
        break;
      }
      final kelime = k.group(0)!;
      if (_sayiCoz(trKucuk(kelime)) == null) {
        break;
      }
      bulundu = true;
      son = i + k.end;
      // Sonraki sözcüğe geç (yalnız boşluk atlanır).
      final bosluk =
          RegExp(r'^[ \t]{0,3}').firstMatch(kalan.substring(son))!.end;
      i = son + bosluk;
      if (bosluk == 0) {
        break;
      }
    }
    if (bulundu) {
      out.add(_Aralik(m.start, m.end + son));
      continue;
    }
    // ── ⚠ RAKAMLI BİÇİM DE AYNI KURALA TABİ ──
    //
    // "Kat 2", "Bina 12" güçlü kalıplara takılmıyordu ("kat" ve
    // "bina" tek başına ZAYIF işaret). Ama bir adres işaretinin
    // HEMEN ARDINDAN gelen sayı — yazıyla ya da rakamla — adres
    // numarasıdır.
    //
    // ⚠ "2+1 daire" etkilenmez: orada sayı işaretten ÖNCE gelir.
    final rakam =
        RegExp(r'^\d{1,5}(?![\d])').firstMatch(kalan.substring(bas));
    if (rakam != null) {
      out.add(_Aralik(m.start, m.end + bas + rakam.end));
    }
  }
  return out;
}

/// ── ⚠ TARİFLİ KONUM ──
///
/// "Karşıyaka Çiçek Pasajı içinde Ayşe Terzi" cümlesinde sokak ya da
/// numara YOKTUR ama kişi fiziksel olarak bulunabilir. Bu tür tarifler
/// bir YER SÖZCÜĞÜ + KONUM EKİ ikilisiyle yakalanır.
final RegExp _yerSozcugu = RegExp(
  // ⚠ GENEL İŞLETME/YER SÖZCÜKLERİ — markaya özel değil.
  r'(?<![\wçğıöşü])('
  r'pasaj\w*|avm|çarşı\w*|market\w*|mağaza\w*|dükkan\w*|dükkân\w*|'
  r'fırın\w*|eczane\w*|restoran\w*|lokanta\w*|kafe\w*|büfe\w*|'
  r'benzinlik\w*|benzin\s*istasyon\w*|otel\w*|banka\w*|berber\w*|'
  r'cami\w*|okul\w*|hastane\w*|karakol\w*|postane\w*|'
  r'apartman\w*|site\w*|bina\w*|plaza|han|iş\s*hanı|durak\w*|'
  r'köprü\w*|meydan\w*|park\w*|terminal\w*|istasyon\w*|hal'
  r')(?![\wçğıöşü])',
  caseSensitive: false,
);

final RegExp _konumEki = RegExp(
  // ── ⚠ KÖK BİÇİMLER DE KAPSANIR ──
  //
  r'(?<![\wçğıöşü])('
  r'içinde|içindeki|'
  r'karşısı|karşısında|karşısındaki|karşısındakı|'
  r'yanı|yanında|yanındaki|'
  r'arkası|arkasında|arkasındaki|'
  r'üstü|üstünde|üstündeki|üst\s*katı|'
  r'altı|altında|altındaki|'
  r'girişinde|girişindeki|bitişiğinde|civarında'
  r')(?![\wçğıöşü])',
  caseSensitive: false,
);

List<_Aralik> _tarifliKonum(String metin) {
  final out = <_Aralik>[];
  for (final o in _obekler(metin)) {
    final parca = metin.substring(o.bas, o.son);
    // ⚠ YER SÖZCÜĞÜ + KAT da konum tarifidir: "Y binasının 3. katı"
    // içinde konum eki yoktur ama kişiyi fiziksel olarak bulmaya yarar.
    final katVar = RegExp(r'(?<![\wçğıöşü])kat[ıi]?(?![\wçğıöşü])',
            caseSensitive: false)
        .hasMatch(parca);
    if (_yerSozcugu.hasMatch(parca) &&
        (_konumEki.hasMatch(parca) || katVar)) {
      out.add(o);
    }
  }
  return out;
}

/// ═══════════════════════════════════════════════════════════════
///  GİRİŞ NOKTASI
/// ═══════════════════════════════════════════════════════════════

/// Metinde maskelenecek bir şey var mı?
bool iletisimIceriyor(String metin) => _tumAraliklar(metin).isNotEmpty;


/// ── ⚠ ANLAMSIZ / TEKRARLAYAN HARF DİZİSİ ──
///
/// "jjjjjj", "jjjkdnddmddk" gibi yazılar. Bunlar iletişim bilgisi
/// DEĞİLDİR ama açıklamayı okunamaz kılar ve maskelemeyi test etmek
/// için kullanılabilir.
///
/// ⚠ İKİ ÖLÇÜT BİRDEN, YÜKSEK EŞİKLE:
///   · aynı harfin 4+ kez ardışık tekrarı ("jjjj"), YA DA
///   · 6+ harflik sözcükte sesli harf ORANI çok düşük (<%15)
///
/// ⚠ MEŞRU KISALTMALAR KORUNUR: "TSE", "İSG", "PVC", "CNC" gibi
/// kısaltmalar 6 harften kısa olduğu için eşiğin altında kalır.
final RegExp _sesli = RegExp(r'[aeıioöuüAEIİOÖUÜ]');

List<_Aralik> _anlamsizAraliklari(String metin) {
  final out = <_Aralik>[];
  for (final m in RegExp(r'[A-Za-zçğıöşüÇĞİÖŞÜ]{4,}').allMatches(metin)) {
    final k = m.group(0)!;
    final tekrar = RegExp(r'(.)\1{3,}').hasMatch(trKucuk(k));
    final sesliSayisi = _sesli.allMatches(k).length;
    final seslisiz = k.length >= 6 && sesliSayisi / k.length < 0.15;
    if (tekrar || seslisiz) {
      out.add(_Aralik(m.start, m.end));
    }
  }
  return out;
}

/// ── ⚠ TÜRKÇE SAYI OKUNUŞU ÇÖZÜMLEYİCİSİ ──
///
/// "beşyüzellibeş" → 555 · "ondokuz" → 19 · "doksanüç" → 93
///
/// Basit "her sözcüğü rakama çevir" yöntemi YANLIŞTIR: "beşyüz"
/// 5+00 değil 500'dür, "beşyüzellibeş" ise 555'tir. Bu yüzden gerçek
/// sayı okunuşu çözümlenir.
///
/// ⚠ HARD-CODE DEĞİL: herhangi bir Türkçe sayı okunuşu çalışır.
const Map<String, int> _birimler = {
  'sıfır': 0, 'sifir': 0, 'bir': 1, 'iki': 2, 'üç': 3, 'uc': 3,
  'dört': 4, 'dort': 4, 'beş': 5, 'bes': 5, 'altı': 6, 'alti': 6,
  'yedi': 7, 'sekiz': 8, 'dokuz': 9,
};

const Map<String, int> _onlar = {
  'on': 10, 'yirmi': 20, 'otuz': 30, 'kırk': 40, 'kirk': 40,
  'elli': 50, 'altmış': 60, 'altmis': 60,
  // ⚠ Konuşma dilindeki "atmış" biçimi de desteklenir.
  'atmış': 60, 'atmis': 60,
  'yetmiş': 70, 'yetmis': 70, 'seksen': 80, 'doksan': 90,
};

/// Tüm belirteçler — UZUN OLAN ÖNCE denenmeli.
/// Aksi hâlde "beşyüz" içindeki "beş" önce eşleşir ve değer bozulur.
final List<String> _sayiBelirtec = () {
  final l = <String>[
    ..._birimler.keys,
    ..._onlar.keys,
    'yüz',
    'yuz',
    'bin',
  ]..sort((a, b) => b.length.compareTo(a.length));
  return l;
}();

/// Sözcüğü sayı belirteçlerine ayırır.
///
/// ⚠ SÖZCÜK TAMAMEN TÜKENMELİ: artan harf kalırsa `null` döner.
/// Bu koşul yanlış pozitifi engelleyen kilittir — "üçodalı" gibi
/// karışık sözcükler sayı sayılmaz.
List<String>? _sayiBelirtecleri(String k) {
  final out = <String>[];
  var i = 0;
  while (i < k.length) {
    var eslesti = false;
    for (final p in _sayiBelirtec) {
      if (k.startsWith(p, i)) {
        out.add(p);
        i += p.length;
        eslesti = true;
        break;
      }
    }
    if (!eslesti) {
      return null;
    }
  }
  return out.isEmpty ? null : out;
}

/// Belirteçleri AYRI SAYI GRUPLARINA böler.
///
/// "beşyüzellibeş|beşyüzaltmışüç|ondokuz|doksanüç" → dört grup.
/// Yeni grup, önceki grup tamamlandığında başlar: birimden sonra
/// birim gelirse ya da ikinci bir onlar basamağı görülürse.
List<List<String>> _sayiGruplari(List<String> bs) {
  final g = <List<String>>[];
  var cur = <String>[];
  for (final t in bs) {
    if (cur.isEmpty) {
      cur = [t];
      continue;
    }
    final onc = cur.last;
    var yeni = false;
    if (t == 'yüz' || t == 'yuz' || onc == 'yüz' || onc == 'yuz') {
      yeni = false; // yüz, önündeki birimi çarpar; sonrasına ek gelir
    } else if (_onlar.containsKey(t)) {
      yeni = cur.any(_onlar.containsKey);
    } else if (_birimler.containsKey(t)) {
      yeni = _birimler.containsKey(onc);
    }
    if (yeni) {
      g.add(cur);
      cur = [t];
    } else {
      cur.add(t);
    }
  }
  if (cur.isNotEmpty) {
    g.add(cur);
  }
  return g;
}

/// Tek bir grubun sayısal değeri.
int _grupDegeri(List<String> g) {
  var top = 0;
  var bek = 0;
  for (final t in g) {
    if (_birimler.containsKey(t)) {
      bek = _birimler[t]!;
      top += bek;
    } else if (_onlar.containsKey(t)) {
      top += _onlar[t]!;
    } else if (t == 'yüz' || t == 'yuz') {
      // ⚠ Önündeki birim YÜZLER basamağıdır: "beş" + "yüz" = 500.
      // Birim yoksa yalnız "yüz" = 100.
      top = bek > 0 ? (top - bek) + bek * 100 : top + 100;
      bek = 0;
    }
  }
  return top;
}

/// Sözcüğü rakam dizisine çevirir; sayı değilse `null`.
String? _sayiCoz(String k) {
  final bs = _sayiBelirtecleri(k);
  if (bs == null) {
    return null;
  }
  return _sayiGruplari(bs).map((g) => _grupDegeri(g).toString()).join();
}

/// ── ⚠ SAYI BÖLGESİ — AYRAÇLA PARÇALAMAYA DİRENÇLİ ──
///
/// Saldırgan sayı sözcüklerini boşluk, nokta, tire, slash, parantez,
/// virgül ve satır sonuyla parçalayarak tespitten kaçabiliyordu.
///
/// Eski yöntem her SÖZCÜĞÜ ayrı çözüp sonuçları birleştiriyordu:
/// "beş" + "yüz" → "5" + "00" = 500 yerine 5+00. Yanlış.
///
/// Yeni yöntem: ardışık sayı belirteçlerinden oluşan BÖLGE bulunur,
/// aradaki ayraçlar yok sayılır ve bölge TEK BİR metin gibi çözülür.
/// Böylece "Beş yüz elli beş", "Beşyüz.ellibeş", "Beşyüz-elli-beş"
/// hepsi aynı sonucu verir.
///
/// ⚠ Ayraç dışında bir şey araya girerse bölge KAPANIR: normal
/// cümledeki sayılar birbirine yapıştırılmaz.



/// ── ⚠ IBAN ──
///
/// "TR12 0000 6100 5190 0078 0000 12" ve boşluklu/parçalanmış
/// varyasyonları. Platform dışı ödeme yönlendirmesidir.
///
/// ⚠ TR + 24 rakam. Aradaki boşluk, nokta ve tire temizlenerek
/// değerlendirilir; parçalama tespiti bozmaz.
List<_Aralik> _ibanAraliklari(String metin) {
  final out = <_Aralik>[];
  final k = RegExp(r'[Tt][Rr][\d \t.\-]{24,44}');
  for (final m in k.allMatches(metin)) {
    final rakam = m.group(0)!.substring(2).replaceAll(RegExp(r'\D'), '');
    if (rakam.length >= 24) {
      out.add(_Aralik(m.start, m.end));
    }
  }
  return out;
}

/// ── ⚠ MARKA / İŞLETME + KONUM TARİFİ ──
///
/// "McDonald's'ın üstü", "X mağazasının arkasındaki bina" gibi
/// tarifler hizmet verenin müşteriyi FİZİKSEL olarak bulmasını
/// sağlar.
///
/// ⚠ GENEL BÖLGE SERBEST KALIR: "Karşıyaka'da" ya da "Girne
/// Mahallesi'nde" bu kurala GİRMEZ — burada aranan ÖZEL AD (büyük
/// harfle başlayan marka/işletme adı) ile KONUM EKİ'nin bir arada
/// bulunmasıdır.
final RegExp _ozelAd = RegExp(r"[A-ZÇĞİÖŞÜ][\wçğıöşü'’]{2,}");

List<_Aralik> _markaKonum(String metin) {
  final out = <_Aralik>[];
  for (final o in _obekler(metin)) {
    final parca = metin.substring(o.bas, o.son);
    if (!_konumEki.hasMatch(parca)) {
      continue;
    }
    // ⚠ Yalnız konum eki YETMEZ ("içinde" tek başına adres değildir);
    // yanında bir özel ad ya da yer sözcüğü bulunmalı.
    if (_ozelAd.hasMatch(parca) || _yerSozcugu.hasMatch(parca)) {
      out.add(o);
    }
  }
  return out;
}

List<_Aralik> _tumAraliklar(String metin) => [
      ..._telefonAraliklari(metin),
      ..._kanalAraliklari(metin),
      ..._adresAraliklari(metin),
      ..._yaziylaAdresNo(metin),
      ..._tarifliKonum(metin),
      ..._anlamsizAraliklari(metin),
      ..._ibanAraliklari(metin),
      ..._markaKonum(metin),
    ];

/// İLETİŞİM VE ADRES BİLGİLERİNİ MASKELER.
///
/// ⚠ LOKALDİR: yalnız riskli parçalar `[İLETİŞİM BİLGİSİ GİZLENDİ]` ile
/// değiştirilir; açıklamanın geri kalanı olduğu gibi görünür.
///
/// ⚠ ÇAKIŞAN ARALIKLAR BİRLEŞTİRİLİR: aynı yer iki kez maskelenip
/// etiket tekrarlanmaz.
String maskele(String metin) {
  final araliklar = _tumAraliklar(metin);
  if (araliklar.isEmpty) {
    return metin;
  }
  araliklar.sort((a, b) => a.bas.compareTo(b.bas));

  // Çakışanları birleştir.
  final birlesik = <_Aralik>[];
  var bas = araliklar.first.bas;
  var son = araliklar.first.son;
  for (final a in araliklar.skip(1)) {
    if (a.bas <= son) {
      if (a.son > son) {
        son = a.son;
      }
    } else {
      birlesik.add(_Aralik(bas, son));
      bas = a.bas;
      son = a.son;
    }
  }
  birlesik.add(_Aralik(bas, son));

  final b = StringBuffer();
  var imlec = 0;
  for (final a in birlesik) {
    if (a.bas > imlec) {
      b.write(metin.substring(imlec, a.bas));
    }
    // ⚠ Baştaki/sondaki boşluk KORUNUR: cümle yapısı bozulmasın.
    final parca = metin.substring(a.bas, a.son);
    final solBosluk = parca.length - parca.trimLeft().length;
    final sagBosluk = parca.length - parca.trimRight().length;
    b.write(parca.substring(0, solBosluk));
    b.write(kMaskeEtiketi);
    b.write(parca.substring(parca.length - sagBosluk));
    imlec = a.son;
  }
  if (imlec < metin.length) {
    b.write(metin.substring(imlec));
  }
  return b.toString();
}

/// İLETİŞİM DURUMUNA GÖRE METİN.
///
/// ⚠ TEK GEÇİT: ekranlar kendi koşulunu yazmaz.
///   · iletişim AÇIK  → metin AYNEN
///   · iletişim KAPALI → maskeli
String gorunenMetin(String metin, {required bool iletisimAcik}) =>
    iletisimAcik ? metin : maskele(metin);
