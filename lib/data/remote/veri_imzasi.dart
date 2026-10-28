import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════
/// VERİ İMZASI — TEK KAYNAK (28 Eki, telefon performansı)
///
/// Sunucudan gelen ham yanıtın imzası. Depolar, yeni yanıt öncekiyle
/// AYNIYSA önbelleği yeniden kurmaz ve dinleyicilere haber vermez; böylece
/// anlık haberle ya da uygulama öne gelince yapılan sessiz yenilemede veri
/// değişmediyse ekran yeniden çizilmez.
///
/// Depo verisini başka bir yoldan (tek kayıt yükleme, ekleme, silme)
/// değiştirdiğinde imzasını SIFIRLAR; bir sonraki liste yanıtı mutlaka
/// uygulanır.
/// ═══════════════════════════════════════════════════════════════
String? veriImzasi(Object? ham) {
  try {
    return jsonEncode(ham);
  } catch (_) {
    return null; // imzalanamayan veri her zaman uygulanır
  }
}
