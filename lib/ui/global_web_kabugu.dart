import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'olcu.dart';
import 'gezgin.dart';
import 'ref_widgets.dart';
import 'web_kenar_cubugu.dart';
import '../screens/nav_actions.dart';
import '../data/models/account.dart';
import '../data/controllers/auth_controller.dart';
import 'package:provider/provider.dart';
import 'web_header.dart';
import 'web_kabuk.dart';

/// ═══════════════════════════════════════════════════════════════
/// GLOBAL WEB KABUĞU — TEK YERDEN, TÜM EKRANLARA
///
/// ## ⚠ NİÇİN `MaterialApp.builder`, NİÇİN 48 EKRAN DEĞİL
///
/// `MerkezliIcerik` altyapısı aylardır duruyordu ama HİÇBİR ekranda
/// kullanılmıyordu. 48 ekranı tek tek sarmak hem bu depodaki "tek tek
/// ekran düzeltilmez" kuralına aykırıydı hem de 48 ayrı regresyon
/// riski üretirdi.
///
/// `MaterialApp.builder` her route'un ÜSTÜNDE çalışır: tek satır
/// değişiklikle bütün ekranlar sınırlanır. Yeni eklenen bir ekran da
/// kuralı kendiliğinden alır — unutulamaz.
///
/// ## ⚠ MOBİL KİLİTLİ: `kIsWeb` OLMADAN OLMAZ
///
/// `MerkezliIcerik` 600 px'in ÜSTÜNDE devreye girer. Android ve iOS
/// TABLETLERİ de 600'ün üstündedir — `kIsWeb` koşulu olmasaydı bu
/// kabuk kilitli mobil baseline'ın tablet görünümünü değiştirirdi.
/// Bu yüzden kabuk YALNIZ web derlemesinde çalışır; Android/iOS'ta
/// çocuk olduğu gibi döner, ağaç bugünküyle birebir aynı kalır.
///
/// ## ⚠ NİÇİN `izgara` (1200) SINIRI
///
/// Bu kabuk en DIŞ sınırdır, ekranın kendi iç sınırı değil. Formu
/// 560'a, listeyi 760'a sıkıştırmak ekran ekran verilecek bir karar;
/// buradaki iş, içeriğin 2560 px'lik bir monitörde kenardan kenara
/// yayılmasını önlemek. `IcerikGenisligi.izgara` mevcut tasarım
/// sisteminin en geniş değeri — yeni bir sayı uydurulmadı.
///
/// ⚠ İÇ SINIRLAR SONRA GELİR: ekranlar kendi `MerkezliIcerik`
/// sarmalayıcılarını aldığında bu dış sınır onları etkilemez; iç
/// sınır daha dar olduğu için kazanan o olur.
///
/// ## ⚠ ZEMİN KENARDAN KENARA UZANIR
///
/// Yalnız içerik ortalanır. Zemin sınırlansaydı geniş ekranda iki
/// yanda gri şeritler kalır, uygulama "ortada duran bir kutu" gibi
/// görünürdü.
/// ═══════════════════════════════════════════════════════════════
class GlobalWebKabugu extends StatelessWidget {
  const GlobalWebKabugu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ⚠ MOBİLDE ARAYA HİÇBİR ŞEY GİRMEZ.
    if (!kIsWeb) {
      return child;
    }
    // ── ⚠ METİN SEÇİMİ (`SelectionArea`) KALDIRILDI ──
    //
    // `SelectionArea` seçim tutamaçlarını bir `Overlay` üzerinde
    // çizer ve burası `MaterialApp.builder`, yani Navigator'ın
    // ÜSTÜ — Navigator'ın `Overlay`i buranın ALTINDA kalıyor.
    // Onu çalıştırmak için kabuğa AYRI bir `Overlay` kurmak
    // gerekiyordu ve o katman iki kez üretime hata taşıdı:
    // önce "No Overlay widget found" ile kırmızı ekran, sonra
    // sayfanın ekranın tamamını kaplamayıp dar bir şerite
    // sıkışması.
    //
    // ⚠ MALİYET/KAZANÇ: metin seçimi bir kolaylıktır; açılışı
    // tamamen bozma riski taşıyan bir katmana değmez. Gerekirse
    // ileride ekran ekran `SelectableText` ile, riski yayarak
    // yapılabilir.
    return _icerik(context);
  }

  Widget _icerik(BuildContext context) {
    // ── ⚠ KENAR ÇUBUĞU VARKEN KABUK DARALTMAZ ──
    //
    // `MerkezliIcerik` tüm uygulamayı rota genişliğine göre
    // ortalıyordu. Kenar çubuğu gelince o daraltmanın İÇİNDE kaldı:
    // rota değiştikçe genişlik değişiyor, çubuk sağa sola KAYIYORDU
    // (Bildirimler'de 760, ana sayfada 1200 …).
    //
    // Geniş web'de sayfa çerçevesi artık kenar çubuğudur; genişlik
    // sınırı SAYFANIN TAMAMINA değil, sağdaki içerik sütununa
    // uygulanmalı. Bu yüzden burada hiç sarmalanmaz — `RefShell` ve
    // `jobs_screen` kendi içerik alanını yönetir.
    //
    // ⚠ DAR WEB DEĞİŞMEZ: kenar çubuğu yokken kabuk eskisi gibi
    // ortalar (form 560 / liste 760 / geniş 1200).
    if (masaustuNav(context)) {
      // ── ⚠ KENAR ÇUBUĞU BURADA, EKRANLARDA DEĞİL ──
      //
      // Önce `RefShell` ve `jobs_screen` kendi çubuklarını
      // çiziyordu. Sonuç: o iki yapıyı kullanmayan ekranlar (Hizmet
      // Kategorilerim, Hizmet Bölgelerim, İlan Oluştur …) çubuksuz,
      // TAM PENCERE olarak açılıyordu — kullanıcı bölüm değiştirdiğini
      // değil, uygulamadan çıktığını sanıyordu.
      //
      // Kabuk `Navigator`ın ÜSTÜNDEDİR: çubuk bir kez çizilir, rota
      // değişse de YERİNDE KALIR, yalnız sağdaki içerik değişir.
      // İstenen davranış tam olarak budur.
      //
      // ⚠ ÇUBUK YALNIZ OTURUM AÇIKKEN: ana sayfa, giriş ve kayıt
      // ekranlarında kullanıcının bir paneli yoktur.
      return ValueListenableBuilder<String?>(
        valueListenable: AktifRota.ad,
        builder: (context, rota, __) {
          final auth = context.watch<AuthController>();
          // ⚠ MODAL ROTALARDA ÇUBUK YOK: giriş ve rol seçimi ana
          // sayfanın üstünde açılan pencerelerdir.
          final disarida = rota == '/login' || rota == '/role';
          if (!auth.loggedIn || disarida) {
            return child;
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebKenarCubugu(
                // ⚠ TIKLAMA İŞLEVLERİ YENİDEN BAĞLANIR.
                //
                // `custNavItems`in `onTap`leri KENDİLERİNE VERİLEN
                // context ile `Navigator.of(context)` çağırır. Burada
                // verilen context kabuğa aittir ve Navigator'ın
                // ÜSTÜNDEDİR — çağrı hiçbir şey yapmıyordu, sekmeler
                // tıklanıyor ama ekran değişmiyordu.
                //
                // ⚠ ROTALAR YENİDEN TANIMLANMAZ: anahtar → rota
                // eşlemesi `_sekmeAnahtari`nin TERSİDİR; tek tablo
                // iki yönde kullanılır.
                items: [
                  for (final it in custNavItems(context,
                      saglayici: auth.activeRole == Role.provider))
                    (
                      key: it.key,
                      label: it.label,
                      asset: it.asset,
                      onTap: () => _sekmeyeGit(
                          it.key, auth.activeRole == Role.provider),
                      rozet: it.rozet,
                      belirginRozetSayisi: it.belirginRozetSayisi,
                    ),
                ],
                // ⚠ AKTİF SEKME ROTADAN: çubuk hangi bölümün açık
                // olduğunu kendisi bilir; ekranlar bildirmez.
                activeKey: _sekmeAnahtari(rota),
                eylem: (e) => RefShell.menuEylemi(context, e),
              ),
              Expanded(child: child),
            ],
          );
        },
      );
    }
    // ⚠ GENİŞLİK ROTAYA GÖRE: `ValueListenableBuilder` yalnız rota
    // değiştiğinde yeniden çizer; her karede değil.
    return ValueListenableBuilder<String?>(
      valueListenable: AktifRota.ad,
      builder: (context, rota, __) {
        // ⚠ PANEL BİÇİMİ BURADAN KALDIRILDI.
        //
        // Kabuk `Navigator`ı sarıyordu; `Navigator` ve `Scaffold`
        // verilen alanı DOLDURUR, içeriğine göre büzülmez. Bu yüzden
        // kart yüksekliği ekranın %88'ine sabitlenmek zorunda kalmış
        // ve kısa formlarda altta büyük boşluk bırakmıştı.
        //
        // Panel artık EKRANIN GÖVDESİNDE: `ui/web_panel.dart`. Orada
        // içeriğe göre yükseklik alabiliyor ve `Navigator.of(context)`
        // ile kendi X'ini çalıştırabiliyor.
        //
        // ⚠ ÇİFT PANEL OLMASIN diye buradaki dal SİLİNDİ; ikisi
        // birlikte kalsaydı kart içinde kart görünürdü.
        return MerkezliIcerik(enFazla: _genislik(rota), child: child);
      },
    );
  }

  /// Bu rota masaüstünde panel olarak mı çizilsin?
  ///
  /// ⚠ YALNIZ FORM/İŞLEM EKRANLARI: ana sayfa, listeler ve detaylar
  /// sayfa olarak kalır — onlarda panel, içeriği gereksiz daraltırdı.
  static double _genislik(String? rota) {
    if (rota == null) {
      return IcerikGenisligi.izgara;
    }
    // ── ⚠ PANEL ROTALARINDA KABUK DARALTMAZ ──
    //
    // Kabuk `MaterialApp.builder` içinde, yani TÜM uygulamayı sarar —
    // üstteki panel rotasını DA altındaki sayfayı DA. Form rotasında
    // 560'a daraltınca arkadaki ana sayfa da 560'a sıkışıyor ve modalın
    // arkası dar bir şerit hâlinde görünüyordu.
    //
    // Panel kendi genişliğini ZATEN yönetiyor (`WebPanel.enFazla`),
    // dolayısıyla kabuğun ayrıca daraltmasına gerek yok. Burada en
    // geniş değer döndürülür; alttaki sayfa kendi düzenini korur.
    if (_formRotalari.contains(rota)) {
      return IcerikGenisligi.izgara;
    }
    if (_listeRotalari.contains(rota) || rota.startsWith('/mesaj/')) {
      return IcerikGenisligi.liste;
    }
    // Geri kalan: ana sayfa, kategori ızgarası, detaylar, profil.
    return IcerikGenisligi.izgara;
  }

  /// ── ⚠ FORM / İŞLEM EKRANLARI ──
  ///
  /// Hem genişlik (560) hem panel biçimi bu tek listeden okunur. İki
  /// ayrı liste tutmak, birini güncelleyip ötekini unutmaya
  /// davetiyedir.
  ///
  /// ⚠ ADLAR `main.dart`taki rota tablosuyla BİREBİR eşleşmeli.
  /// Adsız açılan ekranlara (`Navigator.push`) ad verildi; adsız bir
  /// rotanın `settings.name`i `null` olur ve buradaki tablo onu
  /// tanıyamazdı.
  static const Set<String> _formRotalari = {
    '/login', '/role',
    '/profile/info', '/profile/address', '/profile/password',
    '/profile/account', '/profile/rate', '/profile/role',
    '/provider/categories', '/provider/areas',
    '/customer/new-listing',
    '/kayit', '/dogrulama', '/sifremi-unuttum',
  };

  /// Dikey kart akışları — uzun metin satırları okunmaz hâle gelmesin.
  /// Rota → alt bar sekme anahtarı.
  ///
  /// ⚠ ALT BARLA AYNI ANAHTARLAR: ikinci bir eşleme tablosu
  /// tutulmadı; `custNavItems` hangi anahtarı veriyorsa o.
  /// Sekme anahtarı → rota. `_sekmeAnahtari`nin tersi.
  ///
  /// ⚠ `pushNamedAndRemoveUntil` DEĞİL `pushNamed`: sekmeler arası
  /// geçişte tarayıcı geri tuşu çalışmaya devam etmeli.
  static void _sekmeyeGit(String anahtar, bool saglayici) {
    // ⚠ ANAHTARLAR `nav_actions.dart`TAKİLERLE BİREBİR OLMALI.
    //
    // Burada 'islerim' ve 'bildirimler' yazılıydı; gerçek anahtarlar
    // 'ilanlarim' ve 'bildirim'. Eşleşme tutmayınca `switch` `null`
    // dönüyor ve tıklama SESSİZCE hiçbir şey yapmıyordu — İşlerim ve
    // Bildirimler çalışmamasının sebebi buydu.
    //
    // ⚠ 'ilanlarim' İKİ ROLDE İKİ FARKLI EKRAN: etiketi hizmet
    // verende "İşlerim", hizmet alanda "İlanlarım".
    final rota = switch (anahtar) {
      'ilanlarim' => saglayici ? '/provider/jobs' : '/customer/listings',
      'kazandigim' => '/provider/won',
      'bildirim' => '/notifications',
      'profil' => '/profile',
      'bul' => '/customer/find-provider',
      _ => null,
    };
    if (rota != null) {
      gezginAnahtari.currentState?.pushNamed(rota);
    }
  }

  static String _sekmeAnahtari(String? rota) => switch (rota) {
        '/provider/jobs' || '/customer/listings' => 'ilanlarim',
        '/provider/won' => 'kazandigim',
        '/notifications' => 'bildirim',
        '/profile' => 'profil',
        '/customer/find-provider' => 'bul',
        _ => '',
      };

  static const Set<String> _listeRotalari = {
    '/notifications', '/customer/listings', '/provider/jobs',
    '/provider/won', '/provider/reviews',
    // ⚠ EKLENDİ (19 Eyl): bu ikisi de dikey satır listesidir ama
    // tabloda yoktu, dolayısıyla 1200 px'e yayılıyordu. Masaüstünde
    // "Hizmet Kategorilerim", "Çıkış Yap" gibi tek satırlık öğeler
    // ekran boyunca uzuyor ve sağda kocaman boşluk kalıyordu.
    //
    // ⚠ HİZMET ALAN VE HİZMET VEREN AYNI: profil iki rolde de aynı
    // ekran; ayrı kural tutmanın anlamı yok.
    '/profile', '/provider/status',
  };
}

/// ═══════════════════════════════════════════════════════════════
/// AKTİF ROTA — KABUĞUN GENİŞLİK KARARI İÇİN
///
/// ⚠ NİÇİN GÖZLEMCİ: `MaterialApp.builder` Navigator'ın ÜSTÜNDE
/// çalışır, dolayısıyla orada `ModalRoute.of(context)` her zaman
/// `null` döner. Aktif rota adı ancak gezinme olaylarından öğrenilir.
///
/// ⚠ MOBİLDE DE ÇALIŞIR AMA HİÇBİR ŞEY DEĞİŞTİRMEZ: kabuk `kIsWeb`
/// ile korunduğu için değer okunmaz. Gözlemciyi platforma göre
/// ayırmak, gezinme davranışını platforma bağımlı kılardı — istenmez.
/// ═══════════════════════════════════════════════════════════════
class AktifRota extends NavigatorObserver {
  /// Ekranda duran rotanın adı.
  static final ValueNotifier<String?> ad = ValueNotifier<String?>(null);

  // ⚠ `sonGezgin` ALANI KALDIRILDI.
  //
  // Kabuktaki eski panel, X'i çizmek için Navigator'a erişmek
  // zorundaydı (builder Navigator'ın ÜSTÜNDE çalışır). Panel artık
  // `ui/web_panel.dart` içinde, ekranın gövdesinde; orada
  // `Navigator.of(context)` doğrudan bulunur. Alan bu turda ÖLÜ
  // kaldı ve silindi — duran bir "son gezgin" başvurusu, sonraki
  // turda yanlış yerden kullanılmaya davetiye çıkarırdı.

  void _yaz(Route<dynamic>? rota) {
    final yeni = rota?.settings.name;
    ad.value = yeni;
    _sekmeBasligi(yeni);
  }

  /// ── ⚠ TARAYICI SEKMESİ BAŞLIĞI ──
  ///
  /// `MaterialApp.title` sabit `HizmetCep` idi ve rota değişince
  /// güncellenmiyordu. Web'de her sayfanın kendi sekme başlığı olması
  /// beklenir: kullanıcı birkaç sekme açtığında hangisinin ne olduğunu
  /// ayırt edebilmeli, tarayıcı geçmişinde de anlamlı bir iz kalmalı.
  ///
  /// ⚠ YALNIZ WEB: `SystemChrome.setApplicationSwitcherDescription`
  /// mobilde uygulama değiştirici etiketini değiştirir; Android/iOS
  /// baseline'ı kilitli olduğu için orada çağrılmaz.
  ///
  /// ⚠ MARKA ÖNDE: "HizmetCep · Giriş Yap" biçimi. Sekme daraldığında
  /// tarayıcı sondan kırpar; marka görünür kalsın diye başa alındı.
  ///
  /// ⚠ TANINMAYAN ROTA YALIN MARKA: parametreli adresler
  /// (`/ilan/<id>`) ve adsız rotalar için kimlik uydurulmaz.
  ///
  /// ⚠ ADLAR EKRANLARIN BAŞLIKLARIYLA AYNI: aynı yere iki ad
  /// verilmesin.
  static void _sekmeBasligi(String? rota) {
    if (!kIsWeb) {
      return;
    }
    const adlar = <String, String>{
      '/home': 'Ana Sayfa',
      '/login': 'Giriş Yap',
      '/kayit': 'Kayıt Ol',
      '/dogrulama': 'Doğrulama',
      '/sifremi-unuttum': 'Şifremi Unuttum',
      // ⚠ EKRANIN KENDİ BAŞLIĞIYLA AYNI: sekmede 'Rol Seçimi',
      // ekranda 'Nasıl Başlamak İstersiniz?' yazıyordu.
      '/role': 'Nasıl Başlamak İstersiniz?',
      '/profile': 'Profil',
      '/profile/info': 'Profil Bilgilerim',
      '/profile/address': 'Adreslerim',
      '/profile/password': 'Şifre Değiştir',
      '/profile/account': 'Hesap Ayarları',
      '/profile/rate': 'Uygulama Değerlendirmesi',
      '/profile/role': 'Rol Değiştir',
      '/notifications': 'Bildirimler',
      '/customer/listings': 'İlanlarım',
      '/customer/new-listing': 'İlan Oluştur',
      '/provider/jobs': 'İşlerim',
      '/provider/won': 'Kazandığım',
      '/provider/reviews': 'Müşteri Yorumları',
      '/provider/categories': 'Hizmet Kategorilerim',
      '/provider/areas': 'Hizmet Bölgelerim',
    };
    final ad = adlar[rota];
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        // ⚠ `primaryColor` VERİLMEZ: `Color.toARGB32()` yeni bir API
        // ve burada tek işi süslemek olurdu. Sekme başlığı için
        // gereksiz bir sürüm bağımlılığı alınmadı.
        label: ad == null ? 'HizmetCep' : 'HizmetCep · $ad',
      ),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _yaz(route);

  // ⚠ `pop` ve `remove`da ALTTAKİ rota geçerli olur.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _yaz(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _yaz(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _yaz(newRoute);
}
