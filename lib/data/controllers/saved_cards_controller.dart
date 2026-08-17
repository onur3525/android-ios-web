import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ports/repository_ports.dart';

/// Sağlayıcıdaki kayıtlı kartın GÜVENLİ gösterimi.
///
/// ⚠ Ham kart numarası, CVV ve açık son kullanma tarihi bu sınıfta
/// BULUNMAZ ve hiçbir yerde saklanmaz.
@immutable
class SavedCard {
  /// Sağlayıcının kart tokenı — ham veri değildir.
  final String token;
  /// Kart markası: Mastercard · Visa · Troy
  final String brand;
  /// Maskeli gösterim: `**** **** **** 4242`
  final String masked;
  final bool isDefault;

  const SavedCard({
    required this.token,
    required this.brand,
    required this.masked,
    required this.isDefault,
  });

  factory SavedCard.fromJson(Map<String, dynamic> j) => SavedCard(
        token: j['token'] as String? ?? '',
        brand: j['brand'] as String? ?? 'Kart',
        masked: j['masked'] as String? ?? '**** **** **** ****',
        isDefault: j['isDefault'] as bool? ?? false,
      );
}

/// KAYITLI KART DENETLEYİCİSİ
///
/// ── KART GİRİŞ MİMARİSİ (iki mod) ──
///
/// Backend `GET /wallet/cards/config` ile hangi modun geçerli olduğunu
/// bildirir; denetleyici bunu `entryMode` alanında tutar:
///
///   · `hosted_fields` — Kart alanları UYGULAMADA gösterilir
///     (referans tasarım böyledir). Girilen değerler ödeme
///     sağlayıcısının SDK'sına verilir; SDK doğrudan sağlayıcıyla
///     konuşur ve tek kullanımlık `paymentToken` üretir.
///     ⚠ Kart numarası, son kullanma ve CVV HizmetCep SUNUCUSUNA
///     GÖNDERİLMEZ ve veritabanına YAZILMAZ; sunucuya yalnız token
///     iletilir (`saveCard`).
///
///   · `redirect` — Kart, sağlayıcının barındırdığı sayfada girilir;
///     uygulama yalnız yönlendirme adresini açar (`startSetup`).
///
///   · `unavailable` — Sağlayıcı yapılandırılmamıştır; kart kaydı
///     YAPILAMAZ ve arayüz gerekçesini gösterir.
///
/// Her iki modda da ham kart verisi HizmetCep tarafında SAKLANMAZ;
/// yalnız sağlayıcı tokenı ve maskeli gösterim tutulur.
class SavedCardsController extends ChangeNotifier {
  SavedCardsController(this._port);
  final SavedCardsPort _port;

  bool loading = false;
  bool busy = false;
  /// Sağlayıcı kart saklamayı destekliyor ve yapılandırılmış mı?
  bool available = false;
  List<SavedCard> cards = const [];

  /// Ödeme için seçili kart tokenı.
  /// Kullanıcı seçmediyse varsayılan kart kullanılır; kayıtlı kart
  /// yoksa `null` döner ve ödeme sağlayıcı sayfasında alınır.
  String? _secili;
  String? get selectedToken =>
      _secili ?? (cards.isEmpty ? null : cards.firstWhere(
          (c) => c.isDefault, orElse: () => cards.first).token);

  void select(String? token) {
    _secili = token;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final r = await _port.listCards();
      available = r.available;
      cards = r.cards;
      await loadEntryConfig();
    } catch (_) {
      available = false;
      cards = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// `redirect` modunda kullanılır: kart ekleme oturumu açar ve
  /// kullanıcıyı sağlayıcının barındırdığı sayfaya yönlendirir.
  ///
  /// `hosted_fields` modunda bunun yerine `saveCard()` çağrılır.
  /// Hata varsa mesajını döner.
  Future<String?> startSetup() async {
    busy = true;
    notifyListeners();
    try {
      final url = await _port.startCardSetup();
      if (url == null || url.isEmpty) {
        return 'Kart ekleme şu anda kullanılamıyor';
      }
      final uri = Uri.parse(url);
      final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!acildi) {
        return 'Güvenli ödeme sayfası açılamadı';
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Kart giriş yöntemi: hosted_fields · redirect · unavailable
  String entryMode = 'unavailable';
  Map<String, String>? entryConfig;

  Future<void> loadEntryConfig() async {
    try {
      final r = await _port.cardEntryConfig();
      entryMode = r.mode;
      entryConfig = r.config;
    } catch (_) {
      entryMode = 'unavailable';
      entryConfig = null;
    }
    notifyListeners();
  }

  /// Varsayılan kartı değiştirir (yıldız butonu).
  Future<String?> setDefault(String token) async {
    busy = true;
    notifyListeners();
    try {
      await _port.setDefaultCard(token);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Kartı kaydeder.
  ///
  /// ⚠ `paymentToken` sağlayıcı SDK'sının ürettiği TEK KULLANIMLIK
  /// tokendır. Kart numarası, CVV ve son kullanma tarihi bu metoda
  /// HİÇ ULAŞMAZ.
  Future<String?> saveCard({
    required String paymentToken,
    required String holderName,
    required bool makeDefault,
  }) async {
    busy = true;
    notifyListeners();
    try {
      await _port.saveCard(
        paymentToken: paymentToken,
        holderName: holderName,
        makeDefault: makeDefault,
      );
      await load();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> remove(String token) async {
    busy = true;
    notifyListeners();
    try {
      await _port.deleteCard(token);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
