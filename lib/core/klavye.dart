import 'package:flutter/material.dart';

/// UYGULAMA GENELİ GEÇİŞ HIZI
///
/// ⚠ Flutter'ın varsayılan sayfa geçişi (Android'de `ZoomPageTransition`)
/// ~300 ms sürer ve ağır hissettirir. Uygulama boyunca daha kısa ve
/// keskin bir geçiş kullanılır.
class HizliGecis extends PageTransitionsBuilder {
  const HizliGecis();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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
