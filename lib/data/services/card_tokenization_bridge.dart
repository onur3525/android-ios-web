import 'package:flutter/services.dart';

/// Tokenizasyon sonucu.
class CardTokenResult {
  /// Sağlayıcının ürettiği TEK KULLANIMLIK token.
  /// ⚠ Ham kart verisi DEĞİLDİR.
  final String paymentToken;
  final String? maskedNumber;
  final String? brand;

  const CardTokenResult({
    required this.paymentToken,
    this.maskedNumber,
    this.brand,
  });
}

/// Tokenizasyon başarısız olduğunda fırlatılır.
class CardTokenizationException implements Exception {
  final String message;
  final String code;
  const CardTokenizationException(this.code, this.message);
  @override
  String toString() => 'CardTokenizationException($code): $message';
}

/// ═══════════════════════════════════════════════════════════════
/// KART TOKENİZASYON KÖPRÜSÜ — SAĞLAYICI BAĞIMSIZ ARAYÜZ
///
/// Kart alanları uygulamada gösterilir, ancak ham veri HizmetCep
/// sunucusuna GÖNDERİLMEZ. Bu arayüz, girilen kart bilgisini ödeme
/// sağlayıcısının SDK'sına devreder ve tek kullanımlık `paymentToken`
/// alır.
///
/// ── UYGULAMA DURUMU ──
/// Ödeme sağlayıcısı henüz seçilmediği için somut SDK adaptörü
/// YAZILMAMIŞTIR. `UnconfiguredCardTokenizer` bu boşluğu AÇIK HATA
/// ile bildirir; sessizce `null` dönmez, sahte token üretmez.
///
/// Sağlayıcı seçildiğinde yapılacak: `CardTokenizer` arayüzünü
/// uygulayan bir sınıf yazılır (ör. `IyzicoCardTokenizer`) ve
/// `main.dart` içinde `unconfigured` yerine bağlanır. Başka hiçbir
/// dosya DEĞİŞMEZ.
/// ═══════════════════════════════════════════════════════════════
abstract class CardTokenizer {
  /// Sağlayıcı SDK'sı bu cihazda kullanılabilir mi?
  bool get isConfigured;

  /// Kart bilgisini sağlayıcıya iletir ve tek kullanımlık token alır.
  ///
  /// ⚠ Bu metoda verilen değerler HizmetCep sunucusuna GİTMEZ;
  /// yalnız sağlayıcının SDK'sına iletilir.
  ///
  /// Başarısızlıkta `CardTokenizationException` fırlatır.
  Future<CardTokenResult> tokenize({
    required Map<String, String> providerConfig,
    required String holderName,
    required String number,
    required String expMonth,
    required String expYear,
    required String cvv,
  });
}

/// Sağlayıcı seçilmediğinde kullanılan uygulama.
///
/// Her çağrıda AÇIK HATA fırlatır — çağıran bunu kullanıcıya
/// gerekçesiyle gösterir. Sahte başarı veya sessiz `null` YOKTUR.
class UnconfiguredCardTokenizer implements CardTokenizer {
  const UnconfiguredCardTokenizer();

  @override
  bool get isConfigured => false;

  @override
  Future<CardTokenResult> tokenize({
    required Map<String, String> providerConfig,
    required String holderName,
    required String number,
    required String expMonth,
    required String expYear,
    required String cvv,
  }) {
    throw const CardTokenizationException(
      'PROVIDER_NOT_CONFIGURED',
      'Ödeme sağlayıcısı SDK entegrasyonu tamamlanmadı. '
      'Kart kaydı şu anda yapılamıyor.',
    );
  }
}

/// Platform kanalı üzerinden çalışan somut köprü.
///
/// Sağlayıcının yerel SDK'sı (Android/iOS) `hizmetcep/card_tokenizer`
/// kanalına bağlanır. Kanal kayıtlı değilse `MissingPluginException`
/// yakalanır ve açık hataya çevrilir.
class PlatformCardTokenizer implements CardTokenizer {
  const PlatformCardTokenizer({required bool kanalKayitli})
      : _kanalKayitli = kanalKayitli;

  /// Yerel taraf kanalı kaydettiyse `true` olur.
  /// `CardTokenizerFactory.olustur()` uygulama açılışında belirler.
  final bool _kanalKayitli;

  static const _kanal = MethodChannel('hizmetcep/card_tokenizer');

  /// Yerel tarafta kanalın kayıtlı olup olmadığını SORAR.
  ///
  /// Yerel SDK adaptörü bağlandığında `ping` çağrısına yanıt verir.
  /// Kanal yoksa `MissingPluginException` gelir ve `false` döner —
  /// bu beklenen davranıştır, hata değildir.
  /// ⚠ ZAMAN AŞIMI ZORUNLU.
  ///
  /// Eskiden bu çağrı ÇIPLAK `await` idi. `MissingPluginException`
  /// yakalanıyordu ama yerel taraf YANIT VERMEZSE (kanal kayıtlı ama
  /// işleyici takıldı) çağrı SONSUZA KADAR beklerdi. Bu çağrı
  /// `main()` içinde `runApp`'ten önce yapıldığı sürece uygulama
  /// hiç açılmazdı.
  ///
  /// Belirsizlikte cevap `false`'tur: yapılandırılmamış tokenizer
  /// açık hata verir, SAHTE başarı üretmez.
  /// ⚠ SÜRE 300 → 1000 ms.
  ///
  /// Bugünkü yerel işleyici (`MainActivity`) `ping` çağrısına SABİT
  /// bir değer döndürüyor (`CARD_TOKENIZER_READY = false`), yani
  /// anında yanıtlıyor; 300 ms bugün yeterliydi.
  ///
  /// Ama sağlayıcı SDK'sı bağlandığında bu işleyici SDK'ya soracak.
  /// Yavaş cihazda 300 ms dolar ve gerçek tokenizer YANLIŞLIKLA
  /// "yapılandırılmamış" sayılır — kullanıcı kart ekranında sebepsiz
  /// hata görür. 1000 ms bu riski kapatır.
  ///
  /// ⚠ AÇILIŞA ETKİSİ YOK: bu çağrı artık `main()` içinde değil, ilk
  /// kart/ödeme işleminde yapılır (tembel kurulum).
  static const Duration pingButce = Duration(milliseconds: 1000);

  static Future<bool> kanalKayitliMi() async {
    try {
      final yanit =
          await _kanal.invokeMethod<bool>('ping').timeout(pingButce);
      return yanit == true;
    } on MissingPluginException {
      return false;   // yerel adaptör henüz bağlanmadı
    } catch (_) {
      return false;   // zaman aşımı dahil
    }
  }

  @override
  bool get isConfigured => _kanalKayitli;

  @override
  Future<CardTokenResult> tokenize({
    required Map<String, String> providerConfig,
    required String holderName,
    required String number,
    required String expMonth,
    required String expYear,
    required String cvv,
  }) async {
    if (!_kanalKayitli) {
      throw const CardTokenizationException(
        'PROVIDER_NOT_CONFIGURED',
        'Ödeme sağlayıcısı SDK entegrasyonu tamamlanmadı.',
      );
    }
    try {
      final sonuc = await _kanal.invokeMapMethod<String, dynamic>('tokenize', {
        'config': providerConfig,
        'holderName': holderName,
        'number': number,
        'expMonth': expMonth,
        'expYear': expYear,
        'cvv': cvv,
      });
      final token = sonuc?['paymentToken'] as String?;
      if (token == null || token.isEmpty) {
        throw const CardTokenizationException(
          'EMPTY_TOKEN', 'Sağlayıcı geçerli bir kart tokenı üretmedi.');
      }
      return CardTokenResult(
        paymentToken: token,
        maskedNumber: sonuc?['masked'] as String?,
        brand: sonuc?['brand'] as String?,
      );
    } on MissingPluginException {
      throw const CardTokenizationException(
        'PROVIDER_NOT_CONFIGURED',
        'Ödeme sağlayıcısı SDK entegrasyonu tamamlanmadı.',
      );
    } on PlatformException catch (e) {
      throw CardTokenizationException(
        e.code, e.message ?? 'Kart doğrulanamadı.');
    }
  }
}


/// ═══════════════════════════════════════════════════════════════
/// TOKENİZER FABRİKASI — uygulama açılışında çalışır
///
/// Yerel SDK adaptörünün bağlı olup olmadığını SORAR ve uygun
/// uygulamayı döner:
///
///   · Kanal yanıt veriyorsa  → `PlatformCardTokenizer` (gerçek SDK)
///   · Yanıt vermiyorsa       → `UnconfiguredCardTokenizer` (açık hata)
///
/// ⚠ Widget kodu bu seçimi BİLMEZ; `context.read<CardTokenizer>()`
/// ile hangisi bağlıysa onu kullanır. Sağlayıcı SDK'sı eklendiğinde
/// EKRAN DOSYASI DEĞİŞMEZ.
/// ═══════════════════════════════════════════════════════════════
class CardTokenizerFactory {
  const CardTokenizerFactory._();

  /// ⚠ AÇILIŞI BLOKLAMAZ — TEMBEL (LAZY) KURULUM.
  ///
  /// Eskiden `main()` içinde `runApp`'ten ÖNCE `await` ediliyordu:
  /// ana ekranın ilk karesi, hiç kart ekranı açılmasa bile bu
  /// platform kanalı turunun bitmesini bekliyordu.
  ///
  /// Artık sonuç ilk İHTİYAÇ anında (kart/ödeme ekranı) üretilir ve
  /// önbelleğe alınır. Eşzamanlı iki çağrı TEK sorgu yapar: aynı
  /// `Future` paylaşılır.
  static Future<CardTokenizer>? _bekleyen;
  static CardTokenizer? _hazir;

  /// Test/geliştirme için önbelleği temizler.
  static void sifirla() {
    _bekleyen = null;
    _hazir = null;
  }

  /// Hazırsa anında, değilse tek seferlik sorguyla döner.
  static Future<CardTokenizer> olustur() {
    final h = _hazir;
    if (h != null) {
      return Future<CardTokenizer>.value(h);
    }
    return _bekleyen ??= _sor();
  }

  static Future<CardTokenizer> _sor() async {
    final kayitli = await PlatformCardTokenizer.kanalKayitliMi();
    final t = kayitli
        ? const PlatformCardTokenizer(kanalKayitli: true)
        : const UnconfiguredCardTokenizer();
    _hazir = t;
    return t;
  }
}

/// Ekranların `context.read<CardTokenizer>()` sözleşmesini BOZMADAN
/// tembel kurulumu mümkün kılan sarmalayıcı.
///
/// ⚠ EKRAN KODU DEĞİŞMEZ. Sağlayıcı ağacına bu sınıf konur; ilk
/// `tokenize` çağrısında gerçek tokenizer hazırlanır ve iş ona
/// devredilir. `isConfigured` ise henüz sorulmadıysa `false` döner —
/// yani "bilmiyorum" değil, "yapılandırılmış saymıyorum" denir;
/// sahte başarı üretilmez.
class LazyCardTokenizer implements CardTokenizer {
  const LazyCardTokenizer();

  @override
  bool get isConfigured => CardTokenizerFactory._hazir?.isConfigured ?? false;

  @override
  Future<CardTokenResult> tokenize({
    required Map<String, String> providerConfig,
    required String holderName,
    required String number,
    required String expMonth,
    required String expYear,
    required String cvv,
  }) async {
    final t = await CardTokenizerFactory.olustur();
    return t.tokenize(
      providerConfig: providerConfig,
      holderName: holderName,
      number: number,
      expMonth: expMonth,
      expYear: expYear,
      cvv: cvv,
    );
  }
}
