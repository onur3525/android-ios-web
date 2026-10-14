// ── SUNUCU FOTOĞRAFI: REFERANS → GÖRÜNTÜLEME ADRESİ (TEK KAYNAK) ──
//
// Sunucu dosya REFERANSINI (`u/<kullanıcı>/<uuid>.jpg`) aynen gönderir;
// görüntülenebilir dosyalar için yanına aynı sıradaki İMZALI https
// adresini ekler (backend `gorsel_adresleri.js`):
//   photoPaths → photoUrls · fotograflar → fotografAdresleri
//   fotografRef → fotografUrl · storageRef → storageUrl
//
// Ekranlar (`yerelGorsel`) `https://` adresini ağdan çizer. Adres
// gelmezse (depolama kapalı, eski sunucu) referans döner ve ekran
// mevcut davranışla nötr yer tutucu çizer — sahte adres üretilmez.
//
// ⚠ Bütün eşlemeler (ilan, teklif talebi, talep mesajı, sohbet mesajı)
// BU İKİ FONKSİYONU kullanır; ekran başına ayrı çözüm yazılmaz.

/// Tek dosya: imzalı adres varsa o, yoksa referans.
String? gorselYolu(Object? ref, Object? adres) {
  if (adres is String && adres.startsWith('https://')) {
    return adres;
  }
  return ref is String ? ref : null;
}

/// Dosya listesi: her öğe için [gorselYolu]; adres listesi eksik ya da
/// boyu farklıysa eksik öğeler referansta kalır.
List<String> gorselYollari(Object? refler, Object? adresler) {
  final r = refler is List ? refler : const <Object?>[];
  final a = adresler is List ? adresler : const <Object?>[];
  return [
    for (var i = 0; i < r.length; i++)
      gorselYolu(r[i], i < a.length ? a[i] : null) ?? '${r[i]}',
  ];
}
