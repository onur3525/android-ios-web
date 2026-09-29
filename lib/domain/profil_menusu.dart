import 'package:flutter/widgets.dart';

import '../data/models/account.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROFİL MENÜSÜ — TEK KAYNAK
///
/// ## ⚠ NİÇİN VERİ, NİÇİN WIDGET DEĞİL
///
/// Bu menü iki ayrı yerde çizilecek:
///
///   · Profil ekranı — mobil ve dar web'de, `RefMenuRow` satırları
///     hâlinde (ikon kutusu, başlık, alt yazı, ok).
///   · Masaüstü kenar çubuğu — yalnız ikon ve başlık, alt yazı yok.
///
/// Aynı öğeleri iki yerde widget olarak yazmak, birini güncelleyip
/// ötekini unutmak demekti; bu depoda defalarca yaşandı. Bu yüzden
/// menü VERİ olarak burada durur, çizimi çağıran taraf yapar.
///
/// ## ⚠ ROL AYRIMI BURADA
///
/// Hizmet veren ile hizmet alanın kendi bölümleri farklıdır; "Diğer"
/// grubu ve "Çıkış Yap" ikisinde de aynıdır. Kural tek yerde olsun
/// diye rol ayrımı da buraya taşındı.
///
/// ## ⚠ EYLEMLER ÇAĞIRANA AİT
///
/// Bazı öğeler rota açar (`rota` dolu), bazıları ekranın kendi
/// yöntemini çağırır — rol değiştirme, destek paneli, paylaşma,
/// çıkış. Bunlar `eylem` anahtarıyla bildirilir; çağıran taraf
/// karşılığını verir. Menü verisinin `Navigator` veya `context`
/// bilmesine gerek yoktur.
/// ═══════════════════════════════════════════════════════════════

/// Rota dışı eylemler.
///
/// ⚠ Rota ile açılan öğelerde bu alan `null` kalır.
enum ProfilEylemi { rolDegistir, destek, paylas, cikis }

/// Menüdeki tek satır.
@immutable
class ProfilMenuOgesi {
  const ProfilMenuOgesi({
    required this.ikon,
    required this.ikonZemini,
    required this.baslik,
    required this.altYazi,
    this.rota,
    this.rotaArgumani,
    this.eylem,
    this.tehlikeli = false,
  });

  /// SVG yolu — mevcut ikon sistemi; yeni ikon üretilmedi.
  final String ikon;

  /// İkon kutusunun zemin rengi (profil ekranındaki yuvarlak kutu).
  ///
  /// ⚠ KENAR ÇUBUĞU BUNU KULLANMAZ: orada ikon düz çizilir. Alan yine
  /// de burada durur, çünkü profil ekranının bugünkü görünümü ona
  /// dayanıyor ve o görünüm değişmeyecek.
  final Color ikonZemini;

  final String baslik;

  /// Profil ekranında başlığın altında görünen açıklama.
  ///
  /// ⚠ KENAR ÇUBUĞUNDA ÇİZİLMEZ: orada yalnız başlık var.
  final String altYazi;

  /// Adlandırılmış rota — doluysa öğe onu açar.
  final String? rota;

  /// Rota argümanı (yasal metinlerde slug ve başlık taşır).
  final Object? rotaArgumani;

  /// Rota dışı eylem — `rota` boşsa dolu olur.
  final ProfilEylemi? eylem;

  /// Yıkıcı eylem mi? (çıkış) — kırmızı çizilir.
  final bool tehlikeli;
}

/// Bir menü bölümü.
@immutable
class ProfilMenuBolumu {
  const ProfilMenuBolumu({required this.baslik, required this.ogeler});

  /// Bölüm başlığı — profil ekranında "Hesabım" / "Diğer".
  ///
  /// ⚠ KENAR ÇUBUĞUNDA BAŞLIK YOK: bölümler ince çizgiyle ayrılır.
  final String baslik;

  final List<ProfilMenuOgesi> ogeler;
}

/// Role göre menü bölümleri.
///
/// ⚠ SIRA ÖNEMLİ: profil ekranı ve kenar çubuğu aynı sırayı çizer.
List<ProfilMenuBolumu> profilMenusu(Role rol) => [
      ProfilMenuBolumu(
        baslik: 'Hesabım',
        ogeler: rol == Role.provider ? _saglayici : _musteri,
      ),
      const ProfilMenuBolumu(baslik: 'Diğer', ogeler: _diger),
    ];

/// Çıkış — bölümlerin dışında, en altta ve ayrı durur.
const ProfilMenuOgesi cikisOgesi = ProfilMenuOgesi(
  ikon: 'assets/svg/ic_pout.svg',
  ikonZemini: Color(0xFFFDEAE6),
  baslik: 'Çıkış Yap',
  altYazi: 'Hesabınızdan güvenli çıkış yapın.',
  eylem: ProfilEylemi.cikis,
  tehlikeli: true,
);

// ── HİZMET ALAN ──
const List<ProfilMenuOgesi> _musteri = [
  ProfilMenuOgesi(
    // ⚠ ÇİZGİ İĞNE: kenar çubuğu ikonu tek renge boyar; dolgulu
    // `ic_ppin` (Android profil karesi için) içi dolu leke oluyordu.
    ikon: 'assets/svg/ic_pin.svg',
    ikonZemini: Color(0xFFE7EFFD),
    baslik: 'Adreslerim',
    altYazi: 'Kayıtlı adreslerinizi görüntüleyin ve yönetin.',
    rota: '/profile/address',
  ),
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_pswap.svg',
    ikonZemini: Color(0xFFE7F8EC),
    baslik: 'Rol Değiştir',
    altYazi: 'Hizmet alan veya hizmet veren rolünüze geçin.',
    // ⚠ SAĞ ALANDA AÇILIR (eskiden `/role` paneli): Android'deki
    // `RoleSwitchScreen`'in AYNISI, diğer menü sayfaları gibi düz
    // sayfa rotasıyla (bkz. main.dart `/profile/role`). Rota olduğu
    // için çubukta seçili de görünür.
    rota: '/profile/role',
  ),
];

// ── HİZMET VEREN ──
const List<ProfilMenuOgesi> _saglayici = [
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_wrenchp.svg',
    ikonZemini: Color(0xFFF3E9FD),
    baslik: 'Hizmet Kategorilerim',
    altYazi: 'Hizmet verdiğiniz kategorileri yönetin.',
    rota: '/provider/categories',
  ),
  ProfilMenuOgesi(
    // ⚠ ÇİZGİ İĞNE: kenar çubuğu ikonu tek renge boyar; dolgulu
    // `ic_ppin` (Android profil karesi için) içi dolu leke oluyordu.
    ikon: 'assets/svg/ic_pin.svg',
    ikonZemini: Color(0xFFE7EFFD),
    baslik: 'Hizmet Bölgelerim',
    altYazi: 'Hizmet verdiğiniz il ve ilçeleri yönetin.',
    rota: '/provider/areas',
  ),
  // ⚠ YALNIZ BU ROLDE: hizmet veren ALDIĞI puan ve yorumları görür.
  // Hizmet alan tarafında böyle bir satır YOKTUR — aynı başlığı iki
  // rolde iki farklı anlamda kullanmak kafa karıştırıyordu.
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_pstar.svg',
    ikonZemini: Color(0xFFFDEAF1),
    baslik: 'Müşteri Yorumları',
    altYazi: 'Aldığınız puan ve yorumları görüntüleyin.',
    rota: '/provider/reviews',
  ),
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_pswap.svg',
    ikonZemini: Color(0xFFE7F8EC),
    baslik: 'Rol Değiştir',
    altYazi: 'Hizmet alan veya hizmet veren rolünüze geçin.',
    // ⚠ SAĞ ALANDA AÇILIR (eskiden `/role` paneli): Android'deki
    // `RoleSwitchScreen`'in AYNISI, diğer menü sayfaları gibi düz
    // sayfa rotasıyla (bkz. main.dart `/profile/role`). Rota olduğu
    // için çubukta seçili de görünür.
    rota: '/profile/role',
  ),
];

// ── İKİ ROLDE DE AYNI ──
const List<ProfilMenuOgesi> _diger = [
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_phead.svg',
    ikonZemini: Color(0xFFF3E9FD),
    baslik: 'Destek Merkezi',
    altYazi: 'Sorularınız için bize ulaşın.',
    eylem: ProfilEylemi.destek,
  ),
  ProfilMenuOgesi(
    // ⚠ ÇİZGİ BELGE: dolgulu `ic_pdoc` (Android profil karesi için)
    // tek renge boyanınca satırları kayboluyordu.
    ikon: 'assets/svg/ic_doc_cizgi.svg',
    ikonZemini: Color(0xFFE2F7FA),
    baslik: 'Kullanım Koşulları',
    altYazi: 'Uygulama kullanım koşullarını inceleyin.',
    rota: '/legal',
    rotaArgumani: {'slug': 'terms', 'title': 'Kullanım Koşulları'},
  ),
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_pshield.svg',
    ikonZemini: Color(0xFFE7EFFD),
    baslik: 'Gizlilik Politikası',
    altYazi: 'Kişisel verilerinizin nasıl işlendiğini görün.',
    rota: '/legal',
    rotaArgumani: {'slug': 'privacy', 'title': 'Gizlilik Politikası'},
  ),
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_pstar.svg',
    ikonZemini: Color(0xFFFDE9F1),
    baslik: 'Uygulamayı Puanla',
    altYazi: 'Deneyiminizi bizimle paylaşın.',
    rota: '/profile/rate',
  ),
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_shareapp.svg',
    ikonZemini: Color(0xFFE9F9EF),
    baslik: 'Uygulamayı Paylaş',
    altYazi: "HizmetCep'i sevdiklerinize önerin.",
    eylem: ProfilEylemi.paylas,
  ),
  // ⚠ İKON DİŞLİ ÇARK: kalkan GÜVENLİK anlatır, bu ekranda güvenlik
  // yalnız bir bölüm — yanında bildirim tercihleri, hesap dondurma ve
  // silme de var.
  ProfilMenuOgesi(
    ikon: 'assets/svg/ic_gear.svg',
    ikonZemini: Color(0xFFEEF0F4),
    baslik: 'Hesap Ayarları',
    altYazi: 'Bildirim tercihleri, hesap dondurma ve silme.',
    rota: '/profile/account',
  ),
];
