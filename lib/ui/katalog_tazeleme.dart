import '../data/category_tree.dart';
import '../data/hizmet_alanlari.dart' show sunucuAlanlariniAyarla;
import '../data/remote/api/category_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/veri_imzasi.dart';
import '../screens/category_ui.dart' show sunucuIkonlariniAyarla;

/// ═══════════════════════════════════════════════════════════════
/// KATALOG TAZELEME — TEK KAYNAK (28 Eki, telefon performansı)
///
/// Sunucu kataloğu (kategori/hizmet, ikonlar, ana sayfa çatıları:
/// ad, açıklama, fotoğraf) alınır ve yerleştirilir. İki yerden çağrılır:
///   · Açılış (`SplashScreen`) — eskisi gibi.
///   · Uygulama/sekme öne gelince (`AnlikTazelemeKapisi`) — admin
///     panelinden yayınlanan değişiklik uygulama kapanıp açılmadan da
///     gelir; en sık [enAzAralik] aralıkla.
///
/// Değişmediyse istek gövdesiz döner (sunucu 304, `ApiClient` okuma
/// önbelleği) ve hiçbir şey yeniden yerleştirilmez. Yeni katalog açık
/// ekranlarda bir sonraki çizimde, yeni açılan ekranlarda hemen görünür.
/// ═══════════════════════════════════════════════════════════════
class KatalogTazeleme {
  KatalogTazeleme._();

  static const Duration enAzAralik = Duration(minutes: 5);

  static String? _sonImza;
  static DateTime? _sonDeneme;

  /// Kataloğu çeker ve DEĞİŞTİYSE yerleştirir; değiştiyse `true`.
  /// Ağ hatası çağırana yükselir (açılış kendi yakalar).
  static Future<bool> tazele(ApiClient client) async {
    _sonDeneme = DateTime.now();
    final j = await CategoryApi(client).tree();
    final imza = veriImzasi(j);
    if (imza != null && imza == _sonImza) {
      return false;
    }
    KatalogKaynagi.i.guncelle(CategoryApi.parse(j));
    sunucuIkonlariniAyarla(CategoryApi.ikonlar(j));
    sunucuAlanlariniAyarla(j['roofs'], apiKoku: Uri.parse(client.baseUrl).origin);
    _sonImza = imza;
    return true;
  }

  /// Öne gelme: son denemeden bu yana [enAzAralik] geçtiyse sessizce
  /// tazeler; hata yutulur (gömülü/önceki katalog devrede kalır).
  static Future<void> gerekirseTazele(ApiClient client) async {
    final son = _sonDeneme;
    if (son != null && DateTime.now().difference(son) < enAzAralik) {
      return;
    }
    try {
      await tazele(client);
    } catch (_) {}
  }
}
