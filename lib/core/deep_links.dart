import 'dart:async';
import 'package:flutter/services.dart';

/// DERİN BAĞLANTI (deep link) DİNLEYİCİSİ
///
/// Ödeme sağlayıcısı işlemi bitirince uygulamaya
/// `hizmetcep://payment/return?session=<id>` adresiyle döner.
///
/// Üç durum da ele alınır:
///   • Uygulama AÇIKKEN      → stream üzerinden gelir
///   • ARKA PLANDAYKEN       → stream üzerinden gelir (activity öne alınır)
///   • TAMAMEN KAPALIYKEN    → [initialLink] ile ilk açılışta okunur
///
/// GÜVENLİK: Callback YALNIZ session kimliği taşır. Adreste "success=true"
/// gibi bir parametre olsa dahi ASLA ödeme kanıtı sayılmaz; son durum her
/// zaman backend `confirmTopup` ile doğrulanır.
///
/// Uygulama, harici bir paket eklemeden platform kanalı üzerinden çalışır;
/// böylece pubspec bağımlılıkları değişmez. Kanal adı native tarafta
/// PLATFORM_SETUP.md'de anlatıldığı gibi kaydedilir.
class DeepLinks {
  DeepLinks._();
  static final DeepLinks instance = DeepLinks._();

  static const MethodChannel _method =
      MethodChannel('hizmetcep/deeplinks');
  static const EventChannel _events =
      EventChannel('hizmetcep/deeplinks/events');

  StreamController<Uri>? _controller;
  StreamSubscription<dynamic>? _sub;

  /// Aynı bağlantının iki kez işlenmesini engeller (duplicate callback).
  final Set<String> _handled = <String>{};

  /// Gelen bağlantı akışı. Birden fazla dinleyici olabilir.
  ///
  /// [stream] ve [links] AYNI nesneyi döndürür — iki farklı ad tek akışı
  /// gösterir. `StreamController.stream` her erişimde yeni bir sarmalayıcı
  /// ürettiği için sonuç bir kez üretilip saklanır.
  Stream<Uri> get stream => links;

  /// Gelen bağlantı akışı. Birden fazla dinleyici olabilir.
  Stream<Uri> get links {
    if (_stream == null) {
      _controller ??= StreamController<Uri>.broadcast(
        onListen: _attach,
        onCancel: _detach,
      );
      _stream = _controller!.stream;
    }
    return _stream!;
  }

  /// Tek örnek akış — bkz. [links].
  Stream<Uri>? _stream;

  /// Dinleyiciyi açılışta başlatır (main.dart çağırır).
  /// Akış broadcast olduğu için ekranlar sonradan abone olabilir.
  Future<void> start() async {
    _attach();
  }

  void _attach() {
    _sub ??= _events.receiveBroadcastStream().listen(
      (event) {
        final uri = _parse(event);
        if (uri != null) {
          _controller?.add(uri);
        }
      },
      onError: (_) {
        // Native taraf kanalı sağlamıyorsa sessizce devre dışı kalır;
        // uygulama yaşam döngüsü tabanlı doğrulama yedek olarak çalışır.
      },
    );
  }

  void _detach() {
    _sub?.cancel();
    _sub = null;
  }

  /// Uygulama KAPALIYKEN açılışa neden olan bağlantı (varsa).
  /// Yalnız bir kez döner; ikinci çağrıda null verir.
  Future<Uri?> initialLink() async {
    try {
      final raw = await _method.invokeMethod<String>('getInitialLink');
      return _parse(raw);
    } on MissingPluginException {
      return null; // native taraf henüz kayıtlı değil
    } catch (_) {
      return null;
    }
  }

  Uri? _parse(Object? raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) {
      return null;
    }
    return Uri.tryParse(s);
  }

  /// Bu bağlantı daha önce işlendi mi? (idempotent callback)
  /// İlk çağrıda false döner ve bağlantıyı işlenmiş olarak işaretler.
  bool markHandled(Uri uri) {
    final key = uri.toString();
    if (_handled.contains(key)) {
      return true;
    }
    _handled.add(key);
    return false;
  }

  void resetHandled() => _handled.clear();
}

