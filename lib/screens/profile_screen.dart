import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../data/services/share_service.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/support_info.dart';
import '../data/remote/api/legal_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import 'package:image_picker/image_picker.dart';
import '../data/controllers/profile_controller.dart';
import 'role_switch_screen.dart';
import '../data/repositories/oturum_tercihi.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROFİL — referans `vProfileCust()` / `vProfileProv()`
///
/// Kaynak: `hizmetcep-v66-final__1_.html`
///
/// ```
/// <div class="scroll cust-scroll">
///   <div class="pf-wrap">
///     <h1 class="pf-title">Profil - Hizmet Alan</h1>
///     <div class="pf-top">
///       <div class="pf-av">pfAvatar(96) pfCamBtn()</div>
///       <button class="pf-card" onclick="navigate('pinfo')">
///         .pf-name / .pf-line telefon / .pf-line e-posta   IC_CHEV
///       </button>
///     </div>
///     <h3 class="pf-h3">Hesabım</h3>
///     <div class="pf-group"> pfRow × N </div>
///     <h3 class="pf-h3">Diğer</h3>
///     <div class="pf-group"> pfRow × 5 </div>
///     <div class="pf-group pf-out"> Çıkış Yap </div>
///   </div>
/// </div>
/// custNav('profil')
/// ```
///
/// CSS:
///   .pf-top  { display:flex; gap:14px; align-items:center }
///   .pf-card { border:1px solid #ECEEF1; radius:14px; padding:13px; gap:8px }
///   .pf-info { gap:7px }
///   .pf-name { 17px/700 #16233D }
///   .pf-line { 12.5px #3A4658; gap:8px }
///   .pf-out  { margin-top:14px }
///   .pf-red  { color:#E5452C }
///
/// ⚠ Referansta `AppBar` YOKTUR; başlık sayfa içi `.pf-title` metnidir.
/// ═══════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final saglayici = auth.activeRole == Role.provider;
    final acc = auth.currentAccount;

    return RefShell(
      nav: RefBottomNav(
        activeKey: 'profil',
        items: custNavItems(context, saglayici: saglayici),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠ BÜYÜK BAŞLIK YERİNE ROL ETİKETİ.
          //
          // "Profil - Hizmet Veren" satırı iki iş yapıyordu: sayfayı
          // adlandırmak ve rolü söylemek. Sayfa hangi sayfa olduğunu
          // alt bardaki seçili sekmeden zaten belli ediyor; geriye
          // yalnız ROL bilgisi kalıyor. İşlerim ekranındaki rozetin
          // AYNISI kullanılır (`RefRolEtiketi`) — iki ekranda farklı
          // görünmez.
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: RefRolEtiketi(saglayici: saglayici),
            ),
          ),

          // .pf-top — avatar + bilgi kartı
          // ⚠ KİŞİSEL BİLGİLER KARTA GİRİLMEDEN GÖRÜNÜR.
          //
          // Ad, soyad, telefon ve e-posta kayıt sırasında girilen
          // değerlerden okunur; profil düzenlendiğinde kendiliğinden
          // güncellenir. Telefon 10 hane saklanır, GÖSTERİMDE
          // `0532 123 45 67` biçimine getirilir.
          _ProfilKarti(
            ad: acc?.name ?? '',
            fotoYolu: acc?.photoPath ?? '',
            telefon: _telefonGoster(acc?.phone),
            eposta: (acc?.email ?? '').trim().isEmpty
                ? 'E-posta eklenmedi'
                : acc!.email,
            onTap: () => Navigator.pushNamed(context, '/profile/info'),
          ),

          // <h3 class="pf-h3">Hesabım</h3>
          const RefSectionTitle('Hesabım'),
          RefRowGroup(
            children: saglayici
                ? _saglayiciSatirlari(context)
                : _musteriSatirlari(context),
          ),

          // <h3 class="pf-h3">Diğer</h3>
          const RefSectionTitle('Diğer'),
          RefRowGroup(children: _digerSatirlar(context)),

          // .pf-group.pf-out{margin-top:14px}
          const SizedBox(height: 14),
          RefRowGroup(
            children: [
              RefMenuRow(
                iconAsset: 'assets/svg/ic_pout.svg',
                iconBg: const Color(0xFFFDEAE6),
                title: 'Çıkış Yap',
                subtitle: 'Hesabınızdan güvenli çıkış yapın.',
                // .pf-red{color:#E5452C}
                titleColor: RC.danger,
                onTap: () => _cikis(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Müşteri satırları — referans `vProfileCust`.
  List<Widget> _musteriSatirlari(BuildContext c) => [
        RefMenuRow(
          iconAsset: 'assets/svg/ic_ppin.svg',
          iconBg: const Color(0xFFE7EFFD),
          title: 'Adreslerim',
          subtitle: 'Kayıtlı adreslerinizi görüntüleyin ve yönetin.',
          onTap: () => Navigator.pushNamed(c, '/profile/address'),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_pswap.svg',
          iconBg: const Color(0xFFE7F8EC),
          title: 'Rol Değiştir',
          subtitle: 'Hizmet alan veya hizmet veren rolünüze geçin.',
          onTap: () => _rolDegistir(c),
        ),
      ];

  /// Hizmet veren satırları — referans `vProfileProv`.
  List<Widget> _saglayiciSatirlari(BuildContext c) => [
        RefMenuRow(
          iconAsset: 'assets/svg/ic_wrenchp.svg',
          iconBg: const Color(0xFFF3E9FD),
          title: 'Hizmet Kategorilerim',
          subtitle: 'Hizmet verdiğiniz kategorileri yönetin.',
          onTap: () => Navigator.pushNamed(c, '/provider/categories'),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_ppin.svg',
          iconBg: const Color(0xFFE7EFFD),
          title: 'Hizmet Bölgelerim',
          subtitle: 'Hizmet verdiğiniz il ve ilçeleri yönetin.',
          onTap: () => Navigator.pushNamed(c, '/provider/areas'),
        ),
        // ⚠ DEĞERLENDİRMELERİM YALNIZ BU ROLDE.
        //
        // Hizmet veren ALDIĞI puan ve yorumları görür. Hizmet alan
        // tarafında böyle bir satır YOKTUR — aynı başlığı iki rolde
        // iki farklı anlamda kullanmak kafa karıştırıyordu.
        RefMenuRow(
          iconAsset: 'assets/svg/ic_pstar.svg',
          iconBg: const Color(0xFFFDEAF1),
          title: 'Müşteri Yorumları',
          subtitle: 'Aldığınız puan ve yorumları görüntüleyin.',
          onTap: () => Navigator.pushNamed(c, '/provider/reviews'),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_pswap.svg',
          iconBg: const Color(0xFFE7F8EC),
          title: 'Rol Değiştir',
          subtitle: 'Hizmet alan veya hizmet veren rolünüze geçin.',
          onTap: () => _rolDegistir(c),
        ),
      ];

  /// "Diğer" grubu — her iki rolde AYNI (referansta birebir aynı satırlar).
  List<Widget> _digerSatirlar(BuildContext c) => [
        RefMenuRow(
          iconAsset: 'assets/svg/ic_phead.svg',
          iconBg: const Color(0xFFF3E9FD),
          title: 'Destek Merkezi',
          subtitle: 'Sorularınız için bize ulaşın.',
          onTap: () => _destekSheet(c),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_pdoc.svg',
          iconBg: const Color(0xFFE2F7FA),
          title: 'Kullanım Koşulları',
          subtitle: 'Uygulama kullanım koşullarını inceleyin.',
          onTap: () => Navigator.pushNamed(c, '/legal',
              arguments: {'slug': 'terms', 'title': 'Kullanım Koşulları'}),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_pshield.svg',
          iconBg: const Color(0xFFE7EFFD),
          title: 'Gizlilik Politikası',
          subtitle: 'Kişisel verilerinizin nasıl işlendiğini görün.',
          onTap: () => Navigator.pushNamed(c, '/legal',
              arguments: {'slug': 'privacy', 'title': 'Gizlilik Politikası'}),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_pstar.svg',
          iconBg: const Color(0xFFFDE9F1),
          title: 'Uygulamayı Puanla',
          subtitle: 'Deneyiminizi bizimle paylaşın.',
          onTap: () => Navigator.pushNamed(c, '/profile/rate'),
        ),
        RefMenuRow(
          iconAsset: 'assets/svg/ic_shareapp.svg',
          iconBg: const Color(0xFFE9F9EF),
          title: 'Uygulamayı Paylaş',
          subtitle: "HizmetCep'i sevdiklerinize önerin.",
          onTap: () => _paylas(c),
        ),
        // ⚠ ULAŞILAMAYAN EKRAN DÜZELTMESİ.
        //
        // `AccountSettingsScreen` (hesap dondurma / silme talebi)
        // `/profile/account` route'uyla tanımlıydı ama HİÇBİR yerden
        // açılmıyordu: kullanıcı hesabını donduramıyor, silme talebi
        // oluşturamıyordu. Menüye giriş noktası eklendi.
        // ⚠ İKON KALKANDAN ÇARKA ÇEVRİLDİ.
        //
        // Kalkan (`ic_pshield`) GÜVENLİK anlatır; bu ekranda güvenlik
        // yalnız bir bölüm — yanında bildirim tercihleri, hesap
        // dondurma ve silme de var. Dişli çark evrensel "ayarlar"
        // simgesidir ve uygulamanın başka hiçbir yerinde kullanılmaz.
        //
        // Zemin de turuncu-kremden (uyarı çağrışımı) nötr griye alındı.
        RefMenuRow(
          iconAsset: 'assets/svg/ic_gear.svg',
          iconBg: const Color(0xFFEEF0F4),
          title: 'Hesap Ayarları',
          subtitle: 'Bildirim tercihleri, hesap dondurma ve silme.',
          onTap: () => Navigator.pushNamed(c, '/profile/account'),
        ),
      ];

  /// Referans `supportSheet()` — alt panel.
  /// Referans `supportSheet()` — DESTEK MERKEZİ
  ///
  /// Açıklama ve e-posta HARD-CODE DEĞİLDİR: `SupportInfo` modelinden
  /// gelir (admin panel / remote config / API). Mock modda örnek veri
  /// kullanılır. E-posta altı çizili ve tıklanabilir; `mailto:` ile
  /// cihazın varsayılan e-posta uygulaması açılır.
  Future<void> _destekSheet(BuildContext c) async {
    final bilgi = await _destekBilgisi(c);
    if (!c.mounted) {
      return;
    }
    await RefBottomSheet.goster<void>(
      c,
      title: 'Destek Merkezi',
      // `.rs-body` — referansta destek paneli ortalanmış ikon + başlık
      // + açıklama düzenindedir (`supportSheet`).
      child: RefSheetBody(
        ikon: 'assets/svg/ic_phead.svg',
        ikonZemin: const Color(0xFFF3E9FD),
        baslik: 'Size nasıl yardımcı olabiliriz?',
        aciklama: bilgi.description,
        // ── ADRES VURGULU KUTUDA ──
        //
        // ⚠ Önceki hâl adresi düz bir bağlantı satırıydı; metnin
        // devamı gibi görünüyor, dokunulabilir olduğu anlaşılmıyordu.
        // Artık kendi kutusunda, ikonla birlikte ve tıklanınca
        // e-posta uygulamasını açıyor.
        altKisim: RefTap(
          onTap: () => _mailAc(c, bilgi.email),
          borderRadius: BorderRadius.circular(RR.r12),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E9FD),
              borderRadius: BorderRadius.circular(RR.r12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RefSvg('assets/svg/ic_mail.svg',
                    size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    bilgi.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s145,
                        weight: RF.w700,
                        color: const Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Destek içeriğini getirir.
  ///
  /// API modunda sunucudan okunur; mock modda veya hata durumunda
  /// `SupportInfo.fallback` kullanılır (ekran ASLA boş kalmaz).
  Future<SupportInfo> _destekBilgisi(BuildContext c) async {
    if (!ApiConfig.useRealApi) {
      return SupportInfo.fallback;
    }
    try {
      final j = await LegalApi(c.read<ApiClient>()).one('support');
      return SupportInfo.fromJson(j);
    } catch (_) {
      return SupportInfo.fallback;
    }
  }

  /// `mailto:` ile varsayılan e-posta uygulamasını açar.
  Future<void> _mailAc(BuildContext c, String adres) async {
    final uri = Uri(scheme: 'mailto', path: adres);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && c.mounted) {
        sysToastErr(c, SysKind.genericError,
            extra: 'E-posta uygulaması bulunamadı: $adres');
      }
    } catch (_) {
      if (c.mounted) {
        sysToastErr(c, SysKind.genericError,
            extra: 'E-posta uygulaması açılamadı: $adres');
      }
    }
  }

  Future<void> _paylas(BuildContext c) async {
    final ok = await ShareService().shareApp();
    if (!c.mounted) {
      return;
    }
    if (!ok) {
      sysToastErr(c, SysKind.genericError, extra: 'Paylaşım açılamadı.');
    }
  }

  /// Referans `roleSwitch()` — aktif rolü değiştirir.
  /// ROL DEĞİŞTİR
  ///
  /// ⚠ Artık panel + iki ayrı ekran gezdirme YOKTUR. Tek bir sayfa
  /// açılır; eksik bilgiler orada listelenir, orada doldurulur ve
  /// geçiş oradan yapılır (`RoleSwitchScreen`).
  Future<void> _rolDegistir(BuildContext c) async {
    await Navigator.push(
      c,
      MaterialPageRoute<void>(builder: (_) => const RoleSwitchScreen()),
    );
  }

  /// Referans `pfLogout()`:
  /// `LOGGED=false; toast('Çıkış yapıldı'); navigate('home')`
  Future<void> _cikis(BuildContext c) async {
    // ⚠ CİHAZ HATIRLAMASI DA SİLİNİR.
    //
    // "Beni Hatırla" işaretliyken çıkış yapan kullanıcı bir
    // daha otomatik giriş YAPMAMALIDIR; aksi hâlde çıkış
    // düğmesi hiçbir işe yaramaz.
    // ⚠ CONTROLLER `await`'TEN ÖNCE ALINIR — bkz. `account_settings`.
    final auth = c.read<AuthController>();
    await OturumTercihi().temizle();
    await auth.logout();
    if (!c.mounted) {
      return;
    }
    sysToastOk(c, 'Çıkış yapıldı');
    Navigator.of(c).pushNamedAndRemoveUntil('/home', (r) => false);
  }
}

/// `.pf-top` — avatar + bilgi kartı.
class _ProfilKarti extends StatelessWidget {
  const _ProfilKarti({
    required this.ad,
    required this.telefon,
    required this.eposta,
    required this.fotoYolu,
    required this.onTap,
  });

  /// `Account.photoPath` — boşsa baş harf gösterilir.
  final String fotoYolu;

  final String ad;
  final String telefon;
  final String eposta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // .pf-av — pfAvatar(96)
        _Avatar(ad: ad, fotoYolu: fotoYolu),
        const SizedBox(width: 14), // gap:14px
        // .pf-card
        Expanded(
          child: RefTap(
            onTap: onTap,
            borderRadius: BorderRadius.circular(RR.r14),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: RC.border), // #ECEEF1
                borderRadius: BorderRadius.circular(RR.r14),
              ),
              child: Row(
                children: [
                  // .pf-info{gap:7px}
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: refText(
                              size: RF.s17, weight: RF.w700, color: RC.text),
                        ),
                        const SizedBox(height: 7),
                        _Satir(
                          asset: 'assets/svg/ic_phone_f.svg',
                          boyut: 16,
                          metin: telefon,
                        ),
                        const SizedBox(height: 7),
                        _Satir(
                          asset: 'assets/svg/ic_mail.svg',
                          boyut: 17,
                          metin: eposta,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8), // gap:8px
                  const RefSvg('assets/svg/ic_chev.svg',
                      size: 18, color: RC.textSoft),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `.pf-line{display:flex;gap:8px;font-size:12.5px;color:#3A4658}`
class _Satir extends StatelessWidget {
  const _Satir({required this.asset, required this.boyut, required this.metin});

  final String asset;
  final double boyut;
  final String metin;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          RefSvg(asset, size: boyut, color: RC.textSoft),
          const SizedBox(width: 8), // gap:8px
          Expanded(
            child: Text(
              metin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // .pf-mail
              style: refText(
                  size: RF.s125, weight: RF.w400, color: RC.textDark),
            ),
          ),
        ],
      );
}

/// `pfAvatar(96)` — baş harfli daire.
/// `.pf-av` — `pfAvatar(96)` + `pfCamBtn()`
///
/// ```css
/// .pf-cam{position:absolute;right:0;bottom:4px;width:28px;height:28px;
///   border-radius:50%;background:#1D6BE3;border:3px solid #fff;
///   box-shadow:0 2px 6px rgba(20,40,80,.2)}
/// ```
///
/// Hem avatarın TAMAMI hem kamera ikonu tıklanabilir; ikisi de aynı
/// fotoğraf seçme işlevini çağırır. Kaynak GALERİdir (kamera açılmaz).
class _Avatar extends StatelessWidget {
  const _Avatar({required this.ad, required this.fotoYolu});

  final String ad;
  final String fotoYolu;

  /// ⚠ SEÇENEK PANELİ — tek bir "galeriden seç" değil.
  ///
  /// Eskiden avatara dokunmak DOĞRUDAN galeriyi açıyordu: kamerayla
  /// çekmek ya da mevcut fotoğrafı silmek mümkün değildi. Artık
  /// uygulamanın ortak alt paneli açılır ve kullanıcı seçer.
  ///
  /// ⚠ "Fotoğrafı Kaldır" YALNIZ fotoğraf varken görünür.
  Future<void> _fotoMenusu(BuildContext context) async {
    final secim = await RefBottomSheet.goster<String>(
      context,
      title: 'Profil Fotoğrafı',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RefSecimKarti(
            ikon: 'assets/svg/ic_camplus.svg',
            baslik: 'Fotoğraf Çek',
            aciklama: 'Kamerayla yeni bir fotoğraf çekin.',
            secili: false,
            onTap: () => Navigator.of(context).pop('kamera'),
          ),
          RefSecimKarti(
            ikon: 'assets/svg/ic_gallery.svg',
            baslik: 'Galeriden Yükle',
            aciklama: 'Cihazınızdaki bir fotoğrafı seçin.',
            secili: false,
            onTap: () => Navigator.of(context).pop('galeri'),
          ),
          if (fotoYolu.trim().isNotEmpty)
            RefSecimKarti(
              ikon: 'assets/svg/ic_trash.svg',
              baslik: 'Fotoğrafı Kaldır',
              aciklama: 'Yerine adınızın baş harfi gösterilir.',
              secili: false,
              onTap: () => Navigator.of(context).pop('sil'),
            ),
        ],
      ),
    );
    if (secim == null || !context.mounted) {
      return;
    }
    if (secim == 'sil') {
      await _fotoYaz(context, '', 'Profil fotoğrafı kaldırıldı');
      return;
    }
    await _fotoSec(
      context,
      secim == 'kamera' ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<void> _fotoSec(BuildContext context, ImageSource kaynak) async {
    try {
      final x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1024);
      if (x == null || !context.mounted) {
        return;
      }
      await _fotoYaz(context, x.path, 'Profil fotoğrafı güncellendi');
    } catch (_) {
      if (context.mounted) {
        sysToastErr(context, SysKind.photoUploadError);
      }
    }
  }

  /// ⚠ FOTOĞRAF YALNIZ AKTİF ROLE YAZILIR.
  ///
  /// `Account.photoPath` aktif rolün fotoğrafına bağlıdır; çift rollü
  /// kullanıcıda öteki rol ETKİLENMEZ (bkz. `Account.fotografAta`).
  Future<void> _fotoYaz(
      BuildContext context, String yol, String basariMesaji) async {
    final err = await context
        .read<ProfileController>()
        .updateProfile(photoPath: yol);
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    sysToastOk(context, basariMesaji);
  }

  @override
  Widget build(BuildContext context) {
    final harf = ad.trim().isEmpty ? '?' : ad.trim()[0].toUpperCase();
    final varFoto = fotoYolu.trim().isNotEmpty && File(fotoYolu).existsSync();

    return SizedBox(
      width: 96,
      height: 100, // .pf-cam{bottom:4px} taşmasına pay
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatarın TAMAMI tıklanabilir.
          RefTap(
            onTap: () => _fotoMenusu(context),
            borderRadius: BorderRadius.circular(RR.circle),
            child: ClipOval(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                color: RC.blueSoft,
                child: varFoto
                    ? Image.file(
                        File(fotoYolu),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          harf,
                          style: refText(
                              size: 38, weight: RF.w700, color: RC.blue),
                        ),
                      )
                    : Text(
                        harf,
                        style: refText(
                            size: 38, weight: RF.w700, color: RC.blue),
                      ),
              ),
            ),
          ),

          // .pf-cam — kamera ikonu da tıklanabilir.
          Positioned(
            right: 0,
            bottom: 4,
            child: RefTap(
              onTap: () => _fotoMenusu(context),
              borderRadius: BorderRadius.circular(RR.circle),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RC.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: RC.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33142850),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                // ⚠ `color` VERİLMEZ — referans `IC_CAM(15)` İKİ
                // RENKLİDİR: gövde beyaz (`fill=#fff`), objektif
                // halkası mavi (`fill=#1D6BE3`). Tek renge zorlanınca
                // objektif kayboluyor ve ikon düz beyaz leke oluyordu.
                child: const RefSvg('assets/svg/ic_cam.svg', size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Telefon gösterimi: `0532 123 45 67`.
///
/// Model 10 hane saklar (`phoneFmt`); kullanıcıya baştaki `0` ile ve
/// 4-3-2-2 gruplanmış hâli gösterilir.
String _telefonGoster(String? ham) {
  final d = Validators.phoneLocal(ham ?? '');
  if (d.isEmpty) {
    return 'Telefon eklenmedi';
  }
  // ⚠ TEK KURAL KAYNAĞI — alan içindeki gruplama ile AYNI.
  // İki ayrı kopya vardı; biri değişince diğeri geride kalıyordu.
  return TelefonBicimlendirici.gruplu(d);
}
