// GÖRSEL META VERİSİ TEMİZLEYİCİ (KVKK takip denetimi B5, 22 Eki)
//
// ⚠ NEDEN: telefon kamerasıyla çekilen fotoğrafın EXIF bölümünde GPS
// konumu (çoğu zaman evin adresi), cihaz modeli, çekim zamanı bulunur.
// `image_picker`'ın `imageQuality`/`maxWidth` seçenekleri bunu
// temizlemez: Android eklentisi EXIF'i yeniden kodlanan dosyaya kopyalar,
// web'de dosya hiç işlenmeden yüklenir. Sunucu dosyayı yeniden kodlamaz
// (imzalı adrese doğrudan yüklenir, bkz. storage_api.dart).
//
// ⚠ NASIL: harici paket YOK; dosya yeniden kodlanmaz (kalite kaybı yok).
// Yalnız meta veri bölümleri ayıklanır:
//   · JPEG: APP1 (EXIF, XMP), APP3–APP13, APP15, yorum (COM), ICC dışı
//     APP2 (MPF) atılır; son EOI'den sonraki ekler (ikincil görseller,
//     üretici ekleri) atılır. Görselin dik durması için EXIF'teki YÖN
//     (Orientation) değeri varsa, YALNIZ bu değeri taşıyan küçük bir EXIF
//     bölümü yeniden yazılır. JFIF (APP0), Adobe (APP14) ve ICC renk
//     profili korunur.
//   · PNG: eXIf, tEXt, zTXt, iTXt, tIME parçaları ve IEND sonrası atılır.
//   · WEBP: EXIF ve "XMP " parçaları atılır; VP8X bayrakları düzeltilir.
//   · HEIC ve diğer türler: DEĞİŞTİRİLMEDEN döner (güvenli ayıklama bu
//     sürümde YOK — bkz. KVKK takip raporu, cihazda doğrulama gerekir).
//
// ⚠ BOZUK DOSYA: JPEG/PNG/WEBP yapısı çözülemezse [FormatException]
// fırlatılır; çağıran YÜKLEMEZ (meta verili dosya sessizce gitmez).
//
// ⚠ BOYUT: çıktı hiçbir zaman girdiden büyük değildir (yeniden yazılan
// yön bölümü 34 bayttır ve yalnız daha büyük bir EXIF'in yerine yazılır);
// sunucuya önceden bildirilen `sizeBytes` sınırı aşılmaz.
import 'dart:typed_data';

abstract final class GorselMetaTemizleyici {
  /// Meta verisi ayıklanmış baytlar. Desteklenmeyen tür → aynı baytlar.
  static Uint8List temizle(List<int> bayt, String icerikTuru) {
    final b = bayt is Uint8List ? bayt : Uint8List.fromList(bayt);
    switch (icerikTuru.toLowerCase().trim()) {
      case 'image/jpeg':
      case 'image/jpg':
        return _jpeg(b);
      case 'image/png':
        return _png(b);
      case 'image/webp':
        return _webp(b);
      default:
        return b;
    }
  }

  /// Bu tür için meta veri ayıklanabiliyor mu?
  static bool destekleniyor(String icerikTuru) => const {
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
      }.contains(icerikTuru.toLowerCase().trim());

  // ═══════════════════════════ JPEG ═══════════════════════════

  static Never _bozuk(String neden) =>
      throw FormatException('Görsel çözülemedi: $neden');

  /// [i] konumundaki 0xFF'ten sonra gelen dolgu 0xFF'leri atlar; işaretin
  /// önündeki 0xFF'in konumunu döner.
  static int _isaret(Uint8List b, int i) {
    if (i >= b.length || b[i] != 0xFF) {
      _bozuk('işaret bekleniyordu');
    }
    while (i + 1 < b.length && b[i + 1] == 0xFF) {
      i++;
    }
    if (i + 1 >= b.length) {
      _bozuk('dosya erken bitti');
    }
    return i;
  }

  /// Uzunluk alanı olan bölümün bittiği konum.
  static int _bolumSonu(Uint8List b, int i) {
    if (i + 3 >= b.length) {
      _bozuk('bölüm başlığı eksik');
    }
    final uzunluk = (b[i + 2] << 8) | b[i + 3];
    final son = i + 2 + uzunluk;
    if (uzunluk < 2 || son > b.length) {
      _bozuk('bölüm uzunluğu geçersiz');
    }
    return son;
  }

  static bool _tekBasina(int m) => m == 0x01 || (m >= 0xD0 && m <= 0xD7);

  static const List<int> _icc = [
    0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00, // ICC_PROFILE\0
  ];

  static bool _iccMi(Uint8List bolum) {
    if (bolum.length < 4 + _icc.length) {
      return false;
    }
    for (var k = 0; k < _icc.length; k++) {
      if (bolum[4 + k] != _icc[k]) {
        return false;
      }
    }
    return true;
  }

  /// Meta veri bölümü mü (atılacak)?
  static bool _atilir(int m, Uint8List bolum) {
    if (m == 0xFE) {
      return true; // COM — serbest metin
    }
    if (m == 0xE2) {
      return !_iccMi(bolum); // APP2: ICC korunur, MPF/FlashPix atılır
    }
    if (m == 0xE0 || m == 0xEE) {
      return false; // APP0 (JFIF), APP14 (Adobe renk dönüşümü)
    }
    return m >= 0xE1 && m <= 0xEF; // APP1 (EXIF/XMP), APP3–13, APP15
  }

  static Uint8List _jpeg(Uint8List b) {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) {
      _bozuk('JPEG imzası yok');
    }
    final app0 = <Uint8List>[];
    final ust = <Uint8List>[];
    final govde = BytesBuilder(copy: false);
    int? yon;
    var i = 2;

    // 1) İlk taramaya (SOS) kadar olan bölümler.
    while (true) {
      i = _isaret(b, i);
      final m = b[i + 1];
      if (m == 0xDA) {
        break;
      }
      if (m == 0xD9) {
        _bozuk('görsel verisi yok');
      }
      if (_tekBasina(m)) {
        i += 2;
        continue;
      }
      final son = _bolumSonu(b, i);
      final bolum = Uint8List.sublistView(b, i, son);
      if (m == 0xE1) {
        yon ??= _exifYonu(bolum);
      } else if (m == 0xE0) {
        app0.add(bolum);
      } else if (!_atilir(m, bolum)) {
        ust.add(bolum);
      }
      i = son;
    }

    // 2) Taramalar (ilerlemeli JPEG'de birden çok) ve EOI.
    while (true) {
      i = _isaret(b, i);
      final m = b[i + 1];
      if (m == 0xD9) {
        govde.add(const [0xFF, 0xD9]);
        break; // ⚠ EOI sonrası (ikincil görseller, üretici ekleri) atılır
      }
      if (_tekBasina(m)) {
        govde.add(Uint8List.sublistView(b, i, i + 2));
        i += 2;
        continue;
      }
      final son = _bolumSonu(b, i);
      final bolum = Uint8List.sublistView(b, i, son);
      if (!_atilir(m, bolum)) {
        govde.add(bolum);
      }
      i = son;
      if (m == 0xDA) {
        // Sıkıştırılmış veri: 0xFF00 ve RSTn verinin parçasıdır.
        var j = i;
        while (true) {
          if (j + 1 >= b.length) {
            _bozuk('EOI yok');
          }
          if (b[j] == 0xFF) {
            final x = b[j + 1];
            if (x == 0x00 || (x >= 0xD0 && x <= 0xD7)) {
              j += 2;
              continue;
            }
            break; // yeni işaret (dolgu dahil)
          }
          j++;
        }
        govde.add(Uint8List.sublistView(b, i, j));
        i = j;
      }
    }

    final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
    for (final a in app0) {
      out.add(a);
    }
    if (yon != null && yon != 1) {
      out.add(_yonExif(yon));
    }
    for (final u in ust) {
      out.add(u);
    }
    out.add(govde.takeBytes());
    return out.takeBytes();
  }

  /// EXIF APP1 bölümündeki yön (1–8); yoksa / çözülemezse null.
  static int? _exifYonu(Uint8List bolum) {
    // FF E1 LL LL "Exif\0\0" TIFF…
    const imza = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
    if (bolum.length < 4 + 6 + 8) {
      return null;
    }
    for (var k = 0; k < imza.length; k++) {
      if (bolum[4 + k] != imza[k]) {
        return null; // XMP vb.
      }
    }
    const t = 10; // TIFF başlangıcı
    final bool kucukUclu;
    if (bolum[t] == 0x49 && bolum[t + 1] == 0x49) {
      kucukUclu = true;
    } else if (bolum[t] == 0x4D && bolum[t + 1] == 0x4D) {
      kucukUclu = false;
    } else {
      return null;
    }
    int u16(int p) {
      if (p + 1 >= bolum.length) {
        throw RangeError('exif');
      }
      return kucukUclu ? bolum[p] | (bolum[p + 1] << 8) : (bolum[p] << 8) | bolum[p + 1];
    }

    int u32(int p) {
      if (p + 3 >= bolum.length) {
        throw RangeError('exif');
      }
      return kucukUclu
          ? bolum[p] | (bolum[p + 1] << 8) | (bolum[p + 2] << 16) | (bolum[p + 3] << 24)
          : (bolum[p] << 24) | (bolum[p + 1] << 16) | (bolum[p + 2] << 8) | bolum[p + 3];
    }

    try {
      if (u16(t + 2) != 42) {
        return null;
      }
      final ifd = t + u32(t + 4);
      final n = u16(ifd);
      for (var k = 0; k < n; k++) {
        final e = ifd + 2 + 12 * k;
        if (u16(e) == 0x0112 && u16(e + 2) == 3) {
          final v = u16(e + 8);
          return v >= 1 && v <= 8 ? v : null;
        }
      }
    } on RangeError {
      return null;
    }
    return null;
  }

  /// Yalnız yön etiketini taşıyan EXIF APP1 bölümü (34 bayt, büyük uçlu).
  static Uint8List _yonExif(int yon) => Uint8List.fromList([
        0xFF, 0xE1, 0x00, 0x22, // APP1, uzunluk 34
        0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // Exif\0\0
        0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // MM, 42, IFD0 @8
        0x00, 0x01, // 1 kayıt
        0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
        0x00, yon, 0x00, 0x00, // değer
        0x00, 0x00, 0x00, 0x00, // sonraki IFD yok
      ]);

  // ═══════════════════════════ PNG ═══════════════════════════

  static const List<int> _pngImza = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const Set<String> _pngAtilan = {'eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'};

  static Uint8List _png(Uint8List b) {
    if (b.length < 8) {
      _bozuk('PNG imzası yok');
    }
    for (var k = 0; k < 8; k++) {
      if (b[k] != _pngImza[k]) {
        _bozuk('PNG imzası yok');
      }
    }
    final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
    var i = 8;
    while (true) {
      if (i + 8 > b.length) {
        _bozuk('IEND yok');
      }
      final uzunluk = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
      final tur = String.fromCharCodes(b.sublist(i + 4, i + 8));
      final son = i + 12 + uzunluk;
      if (uzunluk < 0 || son > b.length) {
        _bozuk('PNG parça uzunluğu geçersiz');
      }
      if (!_pngAtilan.contains(tur)) {
        out.add(Uint8List.sublistView(b, i, son));
      }
      i = son;
      if (tur == 'IEND') {
        break; // ⚠ IEND sonrası ekler atılır
      }
    }
    return out.takeBytes();
  }

  // ═══════════════════════════ WEBP ═══════════════════════════

  static int _le32(Uint8List b, int p) =>
      b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24);

  static Uint8List _webp(Uint8List b) {
    if (b.length < 12 ||
        String.fromCharCodes(b.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(b.sublist(8, 12)) != 'WEBP') {
      _bozuk('WEBP imzası yok');
    }
    final riffSonu = 8 + _le32(b, 4);
    if (riffSonu > b.length || riffSonu < 12) {
      _bozuk('RIFF uzunluğu geçersiz');
    }
    final parcalar = BytesBuilder(copy: false);
    var i = 12;
    while (i < riffSonu) {
      if (i + 8 > riffSonu) {
        _bozuk('WEBP parça başlığı eksik');
      }
      final tur = String.fromCharCodes(b.sublist(i, i + 4));
      final uzunluk = _le32(b, i + 4);
      final son = i + 8 + uzunluk + (uzunluk & 1);
      if (uzunluk < 0 || son > riffSonu + (uzunluk & 1) || i + 8 + uzunluk > b.length) {
        _bozuk('WEBP parça uzunluğu geçersiz');
      }
      final bitis = son > b.length ? b.length : son;
      if (tur == 'EXIF' || tur == 'XMP ') {
        // atılır
      } else if (tur == 'VP8X' && uzunluk >= 1) {
        final p = Uint8List.fromList(b.sublist(i, bitis));
        p[8] = p[8] & ~0x0C; // EXIF (0x08) ve XMP (0x04) bayrakları
        parcalar.add(p);
      } else {
        parcalar.add(Uint8List.sublistView(b, i, bitis));
      }
      i = son;
    }
    final govde = parcalar.takeBytes();
    final boy = 4 + govde.length;
    return (BytesBuilder(copy: false)
          ..add(const [0x52, 0x49, 0x46, 0x46]) // RIFF
          ..add([boy & 0xFF, (boy >> 8) & 0xFF, (boy >> 16) & 0xFF, (boy >> 24) & 0xFF])
          ..add(const [0x57, 0x45, 0x42, 0x50]) // WEBP
          ..add(govde))
        .takeBytes();
  }
}
