/// DESTEK MERKEZİ İÇERİĞİ
///
/// Metin ve e-posta adresi HARD-CODE DEĞİLDİR: admin panel /
/// remote config / API üzerinden gelir. Mock modda örnek veri
/// kullanılır.
class SupportInfo {
  /// Kullanıcıya gösterilen açıklama.
  final String description;

  /// Adminin belirlediği destek e-posta adresi.
  final String email;

  const SupportInfo({required this.description, required this.email});

  /// Sunucu gövdesinden okur; eksik alanlarda güvenli varsayılana düşer.
  factory SupportInfo.fromJson(Map<String, dynamic> j) => SupportInfo(
        description: (j['description'] as String?)?.trim().isNotEmpty == true
            ? (j['description'] as String).trim()
            : _varsayilan.description,
        email: (j['email'] as String?)?.trim().isNotEmpty == true
            ? (j['email'] as String).trim()
            : _varsayilan.email,
      );

  /// MOCK / çevrimdışı varsayılan.
  ///
  /// ⚠ Bu değer yalnız sunucudan içerik gelmediğinde kullanılır;
  /// gerçek içerik admin tarafından yönetilir.
  static const _varsayilan = SupportInfo(
    // ⚠ KISA VE KURUMSAL. Önceki metin üç satırdı ve e-posta adresi
    // cümlenin ardında kalıyordu; panelin tamamı yazıya boğuluyordu.
    // ⚠ "Yanıt süresi ortalama 1 iş günüdür" ÇIKARILDI: taahhüt
    // niteliği taşıyor ve destek kapasitesi henüz kurulmadan söz
    // vermek doğru değil.
    description: 'Soru, öneri ve teknik destek talepleriniz için '
        'destek ekibimize yazın.',
    email: 'destek@hizmetcep.com',
  );

  static SupportInfo get fallback => _varsayilan;
}
