import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════
// KALICI FOTOĞRAF ÖNBELLEĞİ — MOBİL (28 Eki, kullanıcı kararı)
// ═══════════════════════════════════════════════════════════════
//
// Sorun: ağdan çizilen fotoğraflar yalnız BELLEKTE tutuluyordu; uygulama
// kapatılıp açılınca ana sayfanın çatı fotoğrafları (24 adet, her biri
// 5 MB'a kadar), ilan ve sohbet fotoğrafları BAŞTAN indiriliyordu
// (mobil ağ katmanı sunucunun "değişmez, sakla" başlığını dikkate almaz).
//
// Çözüm: bir kez indirilen fotoğraf uygulamanın ÖNBELLEK klasörüne yazılır
// (Android: uygulamanın cache klasörü; iOS: tmp — işletim sistemi yer
// gerektiğinde silebilir, o zaman yeniden indirilir).
//
// ANAHTAR: adresin SORGU KISMI ATILMIŞ hâli. İlan/sohbet fotoğraflarının
// adresi her yanıtta yeniden imzalanır (?X-Amz-…, 1 saat geçerli); yol
// (dosyanın deposundaki kimliği) değişmez. Çatı fotoğrafının adresi zaten
// sabittir. Sunucu bir dosyanın ÜZERİNE YAZMAZ: her yükleme yeni benzersiz
// ad alır; güncellenen fotoğraf yeni adresle gelir ve yeni indirilir.
//
// SINIRLAR: dosya en çok `kOnbellekSuresi` (30 gün) kullanılır; klasör
// `kOnbellekAzamiBoyut`u (200 MB) aşarsa en eski dosyalar silinir.
// Aynı fotoğrafı aynı anda isteyen çizimler TEK indirmeyi bekler.
// Başarısız indirme önbelleğe YAZILMAZ (çağıranın yedek görseli çizilir).

const Duration kOnbellekSuresi = Duration(days: 30);
const int kOnbellekAzamiBoyut = 200 * 1024 * 1024;
const Duration _kIndirmeZamanAsimi = Duration(seconds: 30);

/// Adresin önbellek anahtarı: sorgu ve parça kısmı atılmış hâli.
String gorselOnbellekAnahtari(String url) {
  final u = Uri.tryParse(url);
  if (u == null) {
    return url;
  }
  return u.replace(query: '', fragment: '').toString().replaceAll(RegExp(r'[?#]+$'), '');
}

class GorselOnbellegi {
  GorselOnbellegi._();

  static Directory? _klasor;
  static bool _budandi = false;
  static final Map<String, Future<Uint8List>> _ucuslar = {};

  /// Testler için: klasör ve indirme işlevi değiştirilebilir.
  @visibleForTesting
  static Directory? testKlasoru;
  @visibleForTesting
  static Future<http.Response> Function(Uri adres)? testIndir;
  @visibleForTesting
  static void testSifirla() {
    _klasor = null;
    _budandi = false;
    _ucuslar.clear();
  }

  static Future<Directory> _dizin() async {
    final hazir = _klasor;
    if (hazir != null) {
      return hazir;
    }
    final d = testKlasoru ??
        Directory('${Directory.systemTemp.path}${Platform.pathSeparator}hc_gorsel_onbellek');
    await d.create(recursive: true);
    return _klasor = d;
  }

  static File _dosya(Directory d, String anahtar) => File(
      '${d.path}${Platform.pathSeparator}${sha256.convert(utf8.encode(anahtar))}');

  /// Fotoğrafın baytları: önbellekte (süresi geçmemiş) varsa oradan, yoksa ağdan.
  static Future<Uint8List> getir(String url) {
    final anahtar = gorselOnbellekAnahtari(url);
    return _ucuslar[anahtar] ??=
        _getir(url, anahtar).whenComplete(() => _ucuslar.remove(anahtar));
  }

  static Future<Uint8List> _getir(String url, String anahtar) async {
    final d = await _dizin();
    final f = _dosya(d, anahtar);
    try {
      final st = await f.stat();
      if (st.type == FileSystemEntityType.file &&
          st.size > 0 &&
          DateTime.now().difference(st.modified) < kOnbellekSuresi) {
        return await f.readAsBytes();
      }
    } catch (_) {
      // Okunamayan önbellek dosyası: ağdan yeniden indirilir.
    }
    final adres = Uri.parse(url);
    final r = await (testIndir ?? http.get)(adres).timeout(_kIndirmeZamanAsimi);
    if (r.statusCode != 200 || r.bodyBytes.isEmpty) {
      throw HttpException('Görsel indirilemedi (${r.statusCode})', uri: adres);
    }
    final baytlar = r.bodyBytes;
    try {
      // Yarım yazılmış dosya okunmasın: önce geçici ada yazılır, sonra taşınır.
      final gecici = File('${f.path}.${DateTime.now().microsecondsSinceEpoch}.yaziliyor');
      await gecici.writeAsBytes(baytlar, flush: true);
      await gecici.rename(f.path);
    } catch (_) {
      // Yazılamazsa (disk dolu vb.) görsel yine gösterilir; yalnız saklanmaz.
    }
    unawaited(_buda(d));
    return baytlar;
  }

  /// Oturum başına bir kez: süresi geçenleri ve boyut sınırını aşan en eskileri siler.
  static Future<void> _buda(Directory d) async {
    if (_budandi) {
      return;
    }
    _budandi = true;
    await budaSimdi(d);
  }

  @visibleForTesting
  static Future<void> budaSimdi(Directory d) async {
    try {
      final dosyalar = <(File, FileStat)>[];
      await for (final e in d.list()) {
        if (e is File) {
          dosyalar.add((e, await e.stat()));
        }
      }
      final simdi = DateTime.now();
      var toplam = 0;
      final kalan = <(File, FileStat)>[];
      for (final (f, st) in dosyalar) {
        if (simdi.difference(st.modified) >= kOnbellekSuresi) {
          await f.delete();
        } else {
          kalan.add((f, st));
          toplam += st.size;
        }
      }
      kalan.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (f, st) in kalan) {
        if (toplam <= kOnbellekAzamiBoyut) {
          break;
        }
        await f.delete();
        toplam -= st.size;
      }
    } catch (_) {
      // Budama en iyi çaba; hata görsel gösterimini etkilemez.
    }
  }
}

/// Önbellekli ağ görseli sağlayıcısı. Eşitlik ANAHTARA göredir: aynı
/// fotoğrafın yeniden imzalanmış adresi bellekteki çözülmüş görseli de bulur.
@immutable
class KaliciAgGorseli extends ImageProvider<KaliciAgGorseli> {
  const KaliciAgGorseli(this.url);

  final String url;

  String get anahtar => gorselOnbellekAnahtari(url);

  @override
  Future<KaliciAgGorseli> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<KaliciAgGorseli>(this);

  @override
  ImageStreamCompleter loadImage(KaliciAgGorseli key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _coz(key, decode),
        scale: 1.0,
        debugLabel: key.anahtar,
      );

  static Future<ui.Codec> _coz(KaliciAgGorseli key, ImageDecoderCallback decode) async {
    final baytlar = await GorselOnbellegi.getir(key.url);
    return decode(await ui.ImmutableBuffer.fromUint8List(baytlar));
  }

  @override
  bool operator ==(Object other) =>
      other is KaliciAgGorseli && other.anahtar == anahtar;

  @override
  int get hashCode => anahtar.hashCode;

  @override
  String toString() => 'KaliciAgGorseli("$anahtar")';
}

/// Platform köprüsü (mobil): kalıcı önbellekli sağlayıcı.
ImageProvider kaliciAgGorseli(
  String url, {
  WebHtmlElementStrategy webHtmlElementStrategy = WebHtmlElementStrategy.never,
}) =>
    KaliciAgGorseli(url);
