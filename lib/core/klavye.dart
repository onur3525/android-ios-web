import 'package:flutter/material.dart';

/// UYGULAMA GENELİ GEÇİŞ HIZI
///
/// ⚠ Flutter'ın varsayılan sayfa geçişi (Android'de `ZoomPageTransition`)
/// ~300 ms sürer ve ağır hissettirir. Uygulama boyunca daha kısa ve
/// keskin bir geçiş kullanılır.
class HizliGecis extends PageTransitionsBuilder {
  const HizliGecis();

  /// Alt menünün kök sekmeleri sayfa geçişi sırasında birbirinin üstüne
  /// animasyonla bindirilmez. Bu rotalarda her ekran kendi Scaffold'ı ve
  /// alt menüsünü taşıdığı için fade/slide animasyonu alt menüde titreme
  /// hissi oluşturuyordu. Ayrıntı ekranlarının geçişleri aynen korunur.
  static const Set<String> _altMenuKokRotalari = {
    '/customer/find-provider',
    '/customer/listings',
    '/provider/jobs',
    '/provider/won',
    '/notifications',
    '/profile',
  };

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Kök sekmeler anında değişir; yalnız bu altı rota etkilenir.
    if (_altMenuKokRotalari.contains(route.settings.name)) {
      return child;
    }

    final egri = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: egri,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.045, 0),
          end: Offset.zero,
        ).animate(egri),
        child: child,
      ),
    );
  }
}
