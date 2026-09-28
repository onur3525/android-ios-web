import 'package:flutter/widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// UYGULAMANIN NAVIGATOR ANAHTARI — TEK KAYNAK
///
/// ## ⚠ NİÇİN GEREKLİ
///
/// `GlobalWebKabugu` (ve içindeki kenar çubuğu) `MaterialApp.builder`
/// içinde, yani Navigator'ın ÜSTÜNDE çizilir. Oradaki `context` ile
/// `Navigator.of(context)` çağrılınca Navigator BULUNAMAZ: kenar
/// çubuğundaki bağlantılar tıklanıyor ama hiçbir şey olmuyordu.
///
/// Bu anahtar `MaterialApp`e verilir; kabuk gezinmeyi onun üzerinden
/// yapar.
///
/// ⚠ İKİNCİ BİR ANAHTAR ÜRETİLMEZ: `main.dart` de bunu kullanır.
/// İki ayrı anahtar olsaydı biri MaterialApp'e bağlı, öteki boş
/// kalırdı.
///
/// ⚠ EKRANLAR BUNU KULLANMAZ: onlar Navigator'ın ALTINDADIR ve
/// `Navigator.of(context)` orada doğru çalışır. Bu anahtar yalnız
/// kabuk katmanı içindir.
/// ═══════════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> gezginAnahtari = GlobalKey<NavigatorState>();
