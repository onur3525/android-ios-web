import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'olcu.dart';
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
    // ⚠ GENİŞLİK ROTAYA GÖRE: `ValueListenableBuilder` yalnız rota
    // değiştiğinde yeniden çizer; her karede değil.
    return ValueListenableBuilder<String?>(
      valueListenable: AktifRota.ad,
      builder: (_, rota, __) => MerkezliIcerik(
        enFazla: _genislik(rota),
        child: child,
      ),
    );
  }

  /// Rota adından içerik genişliği.
  ///
  /// ── ⚠ NİÇİN ROTA TABLOSU, NİÇİN 48 EKRAN DEĞİL ──
  ///
  /// "Form 560, liste 760, geniş içerik 1200" kuralı 48 ekrana tek tek
  /// yazılsaydı 48 ayrı düzenleme ve 48 ayrı unutma riski doğardı;
  /// yeni eklenen ekran da kuralsız kalırdı. Rota adları zaten
  /// `main.dart`ta MERKEZİ olarak tanımlı — kural onların yanında
  /// tutuluyor.
  ///
  /// ⚠ VARSAYILAN EN GENİŞ: tanınmayan rota 1200'de kalır. Ters
  /// olsaydı (varsayılan 560) listesi olan bir ekran sessizce
  /// daralırdı; geniş kalmak güvenli taraftır.
  ///
  /// ⚠ DEĞERLER MEVCUT SİSTEMDEN: `IcerikGenisligi` içindeki üç sayı
  /// kullanıldı, yenisi uydurulmadı.
  static double _genislik(String? rota) {
    if (rota == null) {
      return IcerikGenisligi.izgara;
    }
    // FORM — tek sütunlu giriş ekranları.
    const form = {
      '/login', '/register', '/role', '/forgot', '/new-password',
      '/profile/info', '/profile/address', '/profile/password',
      '/profile/account', '/profile/rate', '/customer/new-listing',
    };
    if (form.contains(rota)) {
      return IcerikGenisligi.form;
    }
    // LİSTE — dikey kart akışları. Uzun metin satırlarının
    // okunamayacak kadar uzamasını engeller.
    const liste = {
      '/notifications', '/customer/listings', '/provider/jobs',
      '/provider/won', '/provider/reviews',
    };
    if (liste.contains(rota) || rota.startsWith('/mesaj/')) {
      return IcerikGenisligi.liste;
    }
    // Geri kalan: ana sayfa, kategori ızgarası, detaylar, profil.
    return IcerikGenisligi.izgara;
  }
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

  void _yaz(Route<dynamic>? rota) => ad.value = rota?.settings.name;

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
