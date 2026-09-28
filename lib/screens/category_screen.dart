// ⚠ `unawaited` buradan gelir.
import 'dart:async';
import '../data/hizmet_alanlari.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/category_tree.dart';
import '../data/izmir.dart';
import '../data/models/account.dart';
import 'category_ui.dart';
import 'create_listing_screen.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import 'prelogin_listing_route.dart';

/// Kategori detayı (HTML v66 düzeni): kategori başlığı + alt hizmet listesi
/// + bu kategorideki UYGUN (açık) ilanlar.
class CategoryScreen extends StatefulWidget {
  final String category;

  /// ── ⚠ ÇATI BAĞLAMI ──
  ///
  /// Kullanıcı bu ekrana bir ÇATIDAN geldiyse o çatının adı burada
  /// taşınır. Boşsa (arama, Tüm Kategoriler, doğrudan bağlantı)
  /// kategorinin tüm hizmetleri gösterilir.
  ///
  /// ⚠ NEDEN GEREKLİ: hizmet düzeyinde çatı istisnası var. "Oto
  /// Anahtarcı" Çilingir kategorisinde ama Araç Hizmeti çatısında.
  /// Bağlam taşınmazsa Ev Hizmeti'nden gelen kullanıcı onu da görür
  /// ve çatı ayrımı anlamını kaybeder.
  final String? alan;

  /// ── ⚠ ÖNSEÇİLİ HİZMET ──
  ///
  /// Çatı ekranındaki aramadan bir HİZMET seçilerek gelindiğinde o
  /// hizmet burada seçili açılır; kullanıcı listede ikinci kez
  /// aramak zorunda kalmaz.
  ///
  /// ⚠ Boşsa hiçbir şey seçili değildir — mevcut davranış.
  final String? onSecili;

  const CategoryScreen({
    super.key,
    required this.category,
    this.alan,
    this.onSecili,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  /// ── ⚠ TEK HİZMET SEÇİLİR ──
  ///
  /// Bir ilan tek bir hizmete açılır. Çoklu seçim, ilanın hangi işe
  /// ait olduğunu belirsizleştirir ve eşleştirmeyi bozar.
  String? _secili;

  @override
  void initState() {
    super.initState();
    // ⚠ Önseçim yalnız BAŞLANGIÇTA uygulanır; kullanıcı sonradan
    _secili = widget.onSecili;
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final alan = widget.alan;
    final auth = context.watch<AuthController>();
    // ⚠ ÇATI SÜZGECİ MERKEZİ FONKSİYONDAN. Ekran kendi kuralını
    // yazmaz; istisna listesi büyüyünce burası kendiliğinden uyar.
    final subs = [
      for (final h in kSubServices[category] ?? const <String>[])
        if (alan == null || hizmetAlani(category, h) == alan) h
    ];

    void startFlow(String? sub) {
      // ⚠ ROL SEÇİM EKRANI AÇILMAZ.
      //
      // Ana sayfadan kategori/hizmet seçen kullanıcının niyeti zaten
      // HİZMET ALAN olarak ilan vermektir; tekrar rol sorulmaz.
      // (Bağımsız kayıt akışındaki `RoleSelectScreen` KORUNUR.)
      if (!auth.loggedIn) {
        Navigator.pushNamed(
          context,
          PreLoginListingRoute.name,
          arguments: PreLoginListingArgs(category: category, subService: sub),
        );
        return;
      }
      // ── OTURUM AÇIK ──
      final acc = auth.currentAccount;
      final musteriRolu = acc?.roles.contains(Role.customer) ?? false;

      if (musteriRolu) {
        // Aktif rol sağlayıcıysa hizmet ALMA niyeti için müşteri
        // rolüne geçilir; ilan formu korumalı akışta açılır.
        if (auth.activeRole != Role.customer) {
          unawaited(auth.switchRole(Role.customer));
        }
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateListingScreen(
                      initialCategory: category,
                      initialSubService: sub,
                    )));
        return;
      }

      // ── YALNIZ HİZMET VEREN ROLÜ OLAN KULLANICI ──
      //
      // ⚠ ÖNCEDEN BU DAL BOŞTU: kategoriye dokunulduğunda hiçbir şey
      // olmuyordu (sessiz ölü dal).
      //
      // Kullanıcı sağlayıcı ilan formuna GÖNDERİLMEZ ve yetkisiz
      // customer route'una ZORLANMAZ. İlanını public taslak formunda
      // hazırlar; Hizmet Alan rolü mevcut `addRole` sözleşmesiyle
      // tamamlandıktan sonra taslak yayınlanır.
      Navigator.pushNamed(
        context,
        PreLoginListingRoute.name,
        arguments: PreLoginListingArgs(category: category, subService: sub),
      );
    }

    // ⚠ Referansta AppBar YOKTUR; başlık sayfa içindedir.
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // ⚠ Başlık ve açıklamada GÖRÜNEN ad kullanılır; kimlik
            // (`category`) aynen taşınır.
            RefDetailHeader(title: kategoriEtiketi(category)),
            const SizedBox(height: 8),
            Row(children: [
              CategoryBadge(category, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    '${kategoriEtiketi(category)} kategorisindeki hizmetler '
                    've açık ilanlar',
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: HC.grey)),
              ),
            ]),
            const SizedBox(height: 14),
            // ── ⚠ TEK SEÇİM KURALI ──
            //
            // Bir ilan TEK bir hizmete açılır; çoklu seçim ilanın
            // hangi işe ait olduğunu belirsizleştirir ve hizmet
            // verenle eşleştirmeyi bozar.
            const Text('Hizmet seçin',
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800, color: HC.dark)),
            const SizedBox(height: 3),
            const Text('Her ilan için yalnızca bir hizmet seçebilirsiniz.',
                style: TextStyle(fontSize: 12.5, color: HC.grey)),
            const SizedBox(height: 10),

            // ── ⚠ TEK SÜTUN, EŞİT SATIR ──
            //
            // Eskiden `Wrap` ile yan yana diziliyordu: satır başına
            // düşen kart sayısı ada göre değişiyor, ızgara düzensiz
            // görünüyordu. Tek sütunda her satır aynı genişlikte.
            for (var i = 0; i < subs.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _HizmetSatiri(
                ad: subs[i],
                secili: _secili == subs[i],
                // ⚠ Aynı satıra tekrar dokunmak seçimi KALDIRIR;
                // kullanıcı vazgeçebilmeli.
                onTap: () => setState(
                    () => _secili = _secili == subs[i] ? null : subs[i]),
              ),
            ],

            // ── ⚠ DÜĞME HER ROLDE ÇİZİLİR ──
            //
            // Eskiden çipler doğrudan tıklanıyordu ve rol ne olursa
            // olsun akış başlıyordu. Seçim düğmeye taşınınca düğmeyi
            // yalnız müşteriye göstermek, hizmet veren rolündeki
            // kullanıcıyı SESSİZ BİR ÖLÜ DALA sokuyordu: hizmeti
            // seçiyor ama devam edemiyordu.
            //
            // ⚠ Rol kararı `startFlow` içinde verilir: sağlayıcı
            // korumalı müşteri rotasına ZORLANMAZ, taslak formu açılır.
            ...[
              const SizedBox(height: 16),
              // ⚠ SEÇİM YOKKEN DÜĞME PASİF: `onPressed: null` Flutter'da
              // düğmeyi hem soluklaştırır hem dokunulamaz yapar.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _secili == null ? null : () => startFlow(_secili),
                  child: const Text('Devam Et',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tek hizmet satırı — seçilebilir.
///
/// ⚠ Seçili hâli RENKLE değil, RENK + KENARLIK + İŞARET ile belli
/// edilir; yalnız renge dayanmak renk körü kullanıcılar için yetersiz.
class _HizmetSatiri extends StatelessWidget {
  const _HizmetSatiri({
    required this.ad,
    required this.secili,
    required this.onTap,
  });

  final String ad;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secili ? const Color(0xFFEFF5FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
                color: secili ? RC.blue : HC.border,
                width: secili ? 1.4 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // ⚠ HİZMET SATIRINDA İKON YOK.
              //
              // Her satıra KATEGORİ ikonu çiziliyordu; listedeki tüm
              // hizmetlerde aynı simge tekrarlanıyor ve hiçbir şeyi
              // ayırt etmiyordu. Satırlar artık yalnız hizmet adıyla
              // ve seçim işaretiyle okunuyor.
              Expanded(
                child: Text(ad,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                        color: HC.dark)),
              ),
              // ⚠ SEÇİM İŞARETİ: yalnız seçiliyken çizilir, yer her
              // zaman ayrılır ki satırlar seçimle birlikte kaymasın.
              SizedBox(
                width: 18,
                height: 18,
                child: secili
                    ? const RefTik(size: 18, color: RC.blue)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
