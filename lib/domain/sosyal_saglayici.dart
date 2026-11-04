/// ═══════════════════════════════════════════════════════════════
/// GOOGLE / APPLE İLE GİRİŞ — SAĞLAYICILAR (4 Kas, kullanıcı talebi)
///
/// Kimliği Firebase doğrular (Google / Apple); HizmetCep hesabı, rolü ve
/// bütün iş verisi backend'dedir. Sunucu belgedeki sağlayıcıyı
/// (`firebase.sign_in_provider`) okur.
/// ═══════════════════════════════════════════════════════════════
enum SosyalSaglayici {
  google('google.com', 'Google'),
  apple('apple.com', 'Apple');

  const SosyalSaglayici(this.kimlik, this.ad);

  /// Firebase sağlayıcı kimliği — sunucunun `socialProvider` değeriyle aynı.
  final String kimlik;

  /// Ekranda görünen ad.
  final String ad;

  static SosyalSaglayici? kimliktenBul(String? kimlik) {
    for (final s in values) {
      if (s.kimlik == kimlik) {
        return s;
      }
    }
    return null;
  }
}

/// Google/Apple girişinin sonucu.
///
///   · [girisYapildi] — hesap vardı, HizmetCep oturumu açıldı.
///   · [kayitBelgesi] dolu — hesap yok; kayıt ekranı açılır (ad, rol,
///     sözleşme onayı) ve belge `sosyalKayit` ile sunucuya gider.
///   · [iptal] — kullanıcı Google/Apple penceresini kapattı (hata değil).
///   · [hata] — gösterilecek hata.
class SosyalGirisSonucu {
  final bool girisYapildi;
  final String? kayitBelgesi;
  final String? ad;
  final String? eposta;
  final bool iptal;
  final String? hata;

  const SosyalGirisSonucu({
    this.girisYapildi = false,
    this.kayitBelgesi,
    this.ad,
    this.eposta,
    this.iptal = false,
    this.hata,
  });
}
