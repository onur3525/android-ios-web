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
/// ⚠ TEK REGEX YETMEZ. Kullanıcı rakamların arasına boşluk, nokta,
/// tire, parantez koyabilir; hatta "5 5 5 5 6 3 1 9 9 3" diye tek tek
/// yazabilir. Bu yüzden yöntem şudur:
///
///   1. Metinde RAKAM ve ARALARINDAKİ AYRAÇLARDAN oluşan blokları bul.
///   2. Bloktaki ayraçları at, geriye kalan rakam dizisine bak.
///   3. Türk cep numarası kalıbına uyuyorsa bloğun TAMAMINI maskele.
///
/// Böylece `+90 555 563 19 93`, `0555-563-19-93`, `05555631993` ve
/// `5 5 5 5 6 3 1 9 9 3` aynı numara olarak yakalanır.
///
/// ⚠ YANLIŞ POZİTİF KORUMASI: "500 TL", "3 metre", "4 saat" gibi kısa
/// sayılar kalıba uymaz; en az 10 rakam gerekir.
List<_Aralik> _telefonAraliklari(String metin) {
  final out = <_Aralik>[];
  // Rakam · boşluk · nokta · tire · parantez · artı · slash
  //
  // ── ⚠ SATIR SONU AYRAÇ DEĞİLDİR ──
  //
  // Eskiden `\s` kullanılıyordu ve satır sonunu da kapsıyordu.
  // Kullanıcı numaraları ALT ALTA yazınca üçü TEK BLOĞA birleşiyor,
  // rakam dizisi 31 haneye çıkıyor ve telefon kalıbına uymuyordu —
  // yani hiçbiri maskelenmiyordu.
  //
  // ⚠ Yalnız BOŞLUK ve SEKME ayraç sayılır; her satır ayrı
  // değerlendirilir.
  final blok = RegExp(r'[+(]?[\d][\d \t().\-/+]{7,}\d');
  for (final m in blok.allMatches(metin)) {
    final ham = m.group(0)!;
    final rakam = ham.replaceAll(RegExp(r'\D'), '');
    if (_telefonMu(rakam)) {
      out.add(_Aralik(m.start, m.end));
    }
  }
  return out;
}

/// Rakam dizisi Türk telefon numarası mı?
///
/// ⚠ KABUL EDİLEN BİÇİMLER:
///   `5XXXXXXXXX`      (10 hane, cep)
///   `05XXXXXXXXX`     (11 hane)
///   `905XXXXXXXXX`    (12 hane, +90)
///   Ayrıca sabit hat: alan kodu 2/3/4 ile başlayan 10-11 hane.
bool _telefonMu(String r) {
  if (r.length < 10 || r.length > 13) {
    return false;
  }
  var s = r;
  if (s.startsWith('90') && s.length >= 12) {
    s = s.substring(2);
  }
  if (s.startsWith('0')) {
    s = s.substring(1);
  }
  if (s.length != 10) {
    return false;
  }
  // Cep 5 ile, sabit hat 2/3/4 ile başlar.
  return RegExp(r'^[2345]\d{9}$').hasMatch(s);
}

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
    // "instagram: kullanici", "telegram - kullanici", "wp: 0555..."
    RegExp(
        r'(instagram|insta|facebook|fb|twitter|telegram|whatsapp|whatsap|wp|snapchat|tiktok)'
        r'\s*[:\-]?\s*@?[\w.]{2,}',
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
  r'mahalle\w*|mah\.?|mh\.?|'
  r'apartman\w*|apart\w*|apt\.?|'
  r'sitesi|site|'
  r'blok|bloğ\w*|'
  r'pasaj\w*|'
  r'plaza|'
  r'iş\s*hanı|iş\s*merkezi|'
  r'daire|dai\.?|'
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

/// ── ⚠ TARİFLİ KONUM ──
///
/// "Karşıyaka Çiçek Pasajı içinde Ayşe Terzi" cümlesinde sokak ya da
/// numara YOKTUR ama kişi fiziksel olarak bulunabilir. Bu tür tarifler
/// bir YER SÖZCÜĞÜ + KONUM EKİ ikilisiyle yakalanır.
final RegExp _yerSozcugu = RegExp(
  r'(?<![\wçğıöşü])('
  r'pasaj\w*|avm|çarşı\w*|hal|market\w*|mağaza\w*|dükkan\w*|dükkân\w*|'
  r'cami\w*|okul\w*|hastane\w*|banka\w*|eczane\w*|'
  r'apartman\w*|site\w*|bina\w*|plaza|han|iş\s*hanı|durak\w*|'
  r'köprü\w*|meydan\w*|park\w*|terminal\w*|istasyon\w*'
  r')(?![\wçğıöşü])',
  caseSensitive: false,
);

final RegExp _konumEki = RegExp(
  r'(?<![\wçğıöşü])('
  r'içinde|içindeki|karşısı|karşısında|karşısındaki|'
  r'yanı|yanında|yanındaki|arkası|arkasında|arkasındaki|'
  r'girişinde|girişindeki|üstünde|altında|bitişiğinde|civarında'
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

/// ── ⚠ YAZIYLA YAZILAN RAKAM ──
///
/// "beş beş beş üç bir dokuz dokuz üç" gibi. Rakam kullanmadan numara
/// vermenin en yaygın yolu; blok tespiti bunu göremez çünkü ortada
/// rakam yoktur.
///
/// Yöntem: ardışık sayı SÖZCÜKLERİ bulunur, rakama çevrilir ve aynı
/// telefon kalıbına vurulur.
const Map<String, String> _sayiSozcugu = {
  'sıfır': '0', 'sifir': '0',
  'bir': '1', 'iki': '2', 'üç': '3', 'uc': '3', 'dört': '4', 'dort': '4',
  'beş': '5', 'bes': '5', 'altı': '6', 'alti': '6', 'yedi': '7',
  'sekiz': '8', 'dokuz': '9',
  // ── ⚠ BİLEŞİK SAYI SÖZCÜKLERİ ──
  //
  // Kullanıcı numarayı OKUNUŞUYLA yazabiliyor:
  // "beşyüz elli beş beş yüz altmış üç" = 555 563.
  // Yalnız tek haneler tanınsaydı bu kaçardı.
  'on': '10', 'yirmi': '20', 'otuz': '30', 'kırk': '40', 'kirk': '40',
  'elli': '50', 'altmış': '60', 'altmis': '60', 'atmış': '60',
  'atmis': '60', 'yetmiş': '70', 'yetmis': '70', 'seksen': '80',
  'doksan': '90', 'yüz': '00', 'yuz': '00',
  // ⚠ "beşyüz" bitişik de yazılabilir.
  'beşyüz': '500', 'besyuz': '500', 'üçyüz': '300', 'ucyuz': '300',
  'dörtyüz': '400', 'dortyuz': '400', 'altıyüz': '600',
  'yediyüz': '700', 'sekizyüz': '800', 'dokuzyüz': '900',
  'ikiyüz': '200', 'biryüz': '100',
};

List<_Aralik> _yaziylaRakam(String metin) {
  final out = <_Aralik>[];
  final kucuk = trKucuk(metin);
  // Sözcük sınırlarıyla tara.
  final kelime = RegExp(r'[a-zçğıöşü]+').allMatches(kucuk).toList();
  var i = 0;
  while (i < kelime.length) {
    if (!_sayiSozcugu.containsKey(kelime[i].group(0))) {
      i++;
      continue;
    }
    var j = i;
    final b = StringBuffer();
    while (j < kelime.length &&
        _sayiSozcugu.containsKey(kelime[j].group(0))) {
      b.write(_sayiSozcugu[kelime[j].group(0)]);
      j++;
    }
    // ⚠ EN AZ 7 HANE: "üç oda" ya da "iki kat" yanlışlıkla
    // yakalanmasın. Kısa sayı dizileri günlük dilde çok yaygın.
    if (b.length >= 7) {
      out.add(_Aralik(kelime[i].start, kelime[j - 1].end));
    }
    i = j;
  }
  return out;
}

/// ── ⚠ HARF ARAYA SIKIŞTIRMA ──
///
/// "5o5 5b6 3x1 99 3" gibi rakamların arasına harf serpiştirme.
/// Blok tespiti harfte kesildiği için bunu kaçırıyordu.
///
/// ⚠ ÖLÇÜLÜ: bloğun EN AZ YARISI rakam olmalı ve rakamlar telefon
/// kalıbına uymalı. Aksi hâlde "3 metre kablo A5 tipi" gibi normal
/// metinler yakalanırdı.
List<_Aralik> _harfKarisikNumara(String metin) {
  final out = <_Aralik>[];
  // ⚠ SATIR SONU HARİÇ (yukarıdaki aynı gerekçe).
  final blok = RegExp(r'[\dA-Za-zçğıöşüÇĞİÖŞÜ \t().\-/+]{10,}');
  for (final m in blok.allMatches(metin)) {
    final ham = m.group(0)!;
    final rakam = ham.replaceAll(RegExp(r'\D'), '');
    // ⚠ 9 HANE DE SAYILIR: kullanıcı baştaki `0`ı yazmayabilir
    // ("5o5 5b6 3x1 99 3" → 555631993). Bu durumda başa `0`
    // eklenerek kalıba vurulur.
    if (rakam.length < 9) {
      continue;
    }
    final harf = ham.replaceAll(RegExp(r'[^A-Za-zçğıöşüÇĞİÖŞÜ]'), '');
    // Rakam ağırlıklı olmalı: harf sayısı rakamı geçmesin.
    if (harf.length > rakam.length) {
      continue;
    }
    if (_telefonMu(rakam) || _telefonMu('0$rakam')) {
      out.add(_Aralik(m.start, m.end));
    }
  }
  return out;
}

// ⚠ İLETİŞİME YÖNLENDİRME TESPİTİ KALDIRILDI (ürün kararı).
//
// "numaram profilimde", "beni ara", "whatsapptan yaz" gibi ifadeler
// MASKELENMEZ. Gerekçe: bu cümleler numaranın KENDİSİNİ içermiyor.
// Numara zaten görünmüyorsa karşı taraf bir yere ulaşamaz; cümleyi
// gizlemek kullanıcıyı gereksiz yere kısıtlardı.
//
// ⚠ Maskeleme YALNIZ gerçek iletişim verisine uygulanır: numara,
// adres, e-posta, bağlantı, kullanıcı adı.

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

List<_Aralik> _tumAraliklar(String metin) => [
      ..._telefonAraliklari(metin),
      ..._kanalAraliklari(metin),
      ..._adresAraliklari(metin),
      ..._tarifliKonum(metin),
      ..._yaziylaRakam(metin),
      ..._harfKarisikNumara(metin),
      ..._anlamsizAraliklari(metin),
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
