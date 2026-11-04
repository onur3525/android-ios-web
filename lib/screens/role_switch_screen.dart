import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../ui/sifre_dogrulama_paneli.dart' show sosyalIleDogrula;

/// ROL DEĞİŞTİR
///
/// ⚠ TASARIM KARARI
///
/// Önceki akış kullanıcıyı DIŞARI atıyordu: küçük bir panel çıkıyor,
/// "Bilgilerimi Tamamla" denince önce Kategorilerim, sonra Bölgelerim
/// ekranına gidiliyordu. Kullanıcı iki ekran geziyor, nereye gittiğini
/// ve ne kadar kaldığını göremiyordu.
///
/// Bu ekran her şeyi TEK SAYFADA toplar:
///   • Şu anki rol ve geçilecek rol açıkça görünür
///   • Eksik bilgiler LİSTE hâlinde, yanlarında durum işaretiyle
///   • Seçimler bu sayfadan yapılır (yarım ekran açılır, sayfa kalır)
///   • Alt düğme her şey tamamlanana kadar PASİFTİR
///
/// ⚠ İŞ KURALI: Hizmet Veren rolü için EN AZ 1 kategori ve EN AZ 1
/// hizmet bölgesi zorunludur — 4 Kas'tan beri hizmet veren paneli açılınca
/// `ProfilTamamlamaScreen`de istenir (bu ekranda değil).
/// Ad, telefon ve e-posta mevcut hesaptan taşınır; tekrar sorulmaz.
class RoleSwitchScreen extends StatefulWidget {
  const RoleSwitchScreen({super.key});

  @override
  State<RoleSwitchScreen> createState() => _RoleSwitchScreenState();
}

class _RoleSwitchScreenState extends State<RoleSwitchScreen> {
  // ── ⚠ 4 KAS (kullanıcı kararı): KATEGORİ VE BÖLGE BURADA SORULMAZ ──
  // Hizmet veren paneli açılır açılmaz `ProfilTamamlamaScreen` telefon
  // doğrulaması, adres, uzmanlık kategorileri ve hizmet bölgelerini
  // TEK formda ister. Burada yalnız rol (şifre onayıyla) eklenir/geçilir.
  bool _busy = false;

  Role get _hedef => context.read<AuthController>().activeRole == Role.provider
      ? Role.customer
      : Role.provider;

  /// Hedef rol hesapta ZATEN tanımlı mı? Tanımlıysa bilgi istenmez.
  bool _rolVar(Account acc, Role r) => acc.roles.contains(r);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final acc = auth.currentAccount;
    if (acc == null) {
      return const Scaffold(
        backgroundColor: RC.pageBg,
        body: Center(child: SysState(SysKind.sessionExpired)),
      );
    }
    final hedef = _hedef;
    final simdiki = auth.activeRole;

    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: RefDetailHeader(title: 'Rol Değiştir'),
            ),
            // Geçiş kartı sayfanın dikey ortasında (tamamlanacak bilgiler
            // panel açılınca `ProfilTamamlamaScreen`de istenir).
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _GecisKarti(simdiki: simdiki, hedef: hedef),
                ),
              ),
            ),

            // ── Alt sabit eylem ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: RefNextButton(
                hedef == Role.provider
                    ? 'Hizmet Veren Olarak Devam Et'
                    : 'Hizmet Alan Olarak Devam Et',
                iconAsset: 'assets/svg/ic_pswap.svg',
                busy: _busy,
                onPressed: _gec,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ///
  /// Rol hesapta yoksa önce EKLENİR (toplanan bilgilerle), sonra
  /// aktif role geçilir. İki adım da başarısız olabilir; her birinde
  /// kullanıcı bilgilendirilir ve ekran KAPANMAZ.
  Future<void> _gec() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    final hedef = _hedef;
    final acc = auth.currentAccount;

    if (acc != null && !_rolVar(acc, hedef)) {
      // ⚠ API MODU: sunucu rol eklemeden önce şifre ve kayıtlı telefona
      // gönderilen YENİ bir SMS doğrulaması ister. Mock modda gerekmez.
      String? sifre;
      String? kanit;
      if (auth.rolEklemeDogrulamaIster) {
        final d = await _rolEklemeDogrula(auth, acc.phone);
        if (!mounted) {
          return;
        }
        if (d == null) {
          setState(() => _busy = false);
          return;
        }
        sifre = d.sifre;
        kanit = d.kanit;
      }
      final ekleErr = await auth.addRole(
        hedef,
        sifre: sifre,
        telefonKaniti: kanit,
      );
      if (!mounted) {
        return;
      }
      if (ekleErr != null) {
        setState(() => _busy = false);
        sysToastErr(context, SysKind.genericError, extra: ekleErr.message);
        return;
      }
    }

    final err = await auth.switchRole(hedef);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    sysToastOk(
      context,
      hedef == Role.provider
          ? 'Hizmet veren moduna geçildi'
          : 'Hizmet alan moduna geçildi',
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      hedef == Role.provider ? '/provider/jobs' : '/customer/listings',
      (r) => false,
    );
  }

  /// ROL EKLEME DOĞRULAMASI (yalnız API modu).
  ///
  /// ⚠ 21 Eki (kullanıcı kararı): telefon numarası ve SMS kodu
  /// İSTENMEZ. Yalnız şifre sorulur (sunucuda doğrulanır); vazgeçilirse
  /// `null`.
  Future<({String sifre, String? kanit})?> _rolEklemeDogrula(
      AuthController auth, String telefon) async {
    final sifre = await _sifreAl(auth);
    if (sifre == null || !mounted) {
      return null;
    }
    return (sifre: sifre, kanit: null);
  }

  /// Şifre paneli — şifre sunucuda doğrulanır (`verifyPassword`);
  /// doğruysa panel kapanır ve şifre döner. Ekran şifreyi SAKLAMAZ.
  Future<String?> _sifreAl(AuthController auth) async {
    // 4 Kas: Google/Apple ile açılmış şifresiz hesap → aynı sağlayıcıyla
    // yeniden giriş (tek kaynak: `sosyalIleDogrula`).
    if (auth.currentAccount?.sifresiVar == false) {
      return sosyalIleDogrula(context,
          aciklama: 'Hesabınıza yeni rol eklemek için kimliğinizi doğrulayın.',
          renk: RC.blue);
    }
    final ctl = TextEditingController();
    final hataNot = ValueNotifier<String?>(null);
    final doluNot = ValueNotifier<bool>(false);
    final mesgulNot = ValueNotifier<bool>(false);
    String? dogrulanan;
    try {
      await RefBottomSheet.goster<void>(
        context,
        title: 'Kimliğinizi Doğrulayın',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hesabınıza yeni rol eklemek için şifrenizi girin.',
              style: refText(
                  size: RF.s135,
                  weight: RF.w400,
                  color: RC.textDark,
                  height: RF.lh155),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<String?>(
              valueListenable: hataNot,
              builder: (_, hata, __) => TextField(
                controller: ctl,
                obscureText: true,
                textCapitalization: TextCapitalization.none,
                autofocus: true,
                onChanged: (_) {
                  if (hataNot.value != null) {
                    hataNot.value = null;
                  }
                  doluNot.value = ctl.text.trim().isNotEmpty;
                },
                decoration: InputDecoration(
                  hintText: 'Şifreniz',
                  errorText: hata,
                  errorMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (c) => ValueListenableBuilder<bool>(
                valueListenable: doluNot,
                builder: (_, dolu, __) => ValueListenableBuilder<bool>(
                  valueListenable: mesgulNot,
                  builder: (_, mesgul, __) => RefPrimaryButton(
                    'Devam Et',
                    busy: mesgul,
                    onPressed: !dolu || mesgul
                        ? null
                        : () async {
                            mesgulNot.value = true;
                            final err = await auth.verifyPassword(ctl.text);
                            mesgulNot.value = false;
                            if (err != null) {
                              hataNot.value = err.message;
                              return;
                            }
                            dogrulanan = ctl.text;
                            if (c.mounted) {
                              Navigator.of(c).pop();
                            }
                          },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } finally {
      // Panel kapanma animasyonu bitene kadar dinleyiciler ağaçta
      // kalabilir; bırakma bir sonraki kareye ertelenir.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctl.dispose();
        hataNot.dispose();
        doluNot.dispose();
        mesgulNot.dispose();
      });
    }
    return dogrulanan;
  }
}

/// Şu anki rol → hedef rol geçiş kartı.
class _GecisKarti extends StatelessWidget {
  const _GecisKarti({required this.simdiki, required this.hedef});

  final Role simdiki;
  final Role hedef;

  static String _ad(Role r) =>
      // ⚠ Rol adı uygulama genelinde AYNI: "Hizmet Alan" / "Hizmet
      // Veren". Tek yerde "Müşteri" demek kullanıcıyı ikinci bir
      // kavramla karşılaştırıyordu.
      r == Role.provider ? 'Hizmet Veren' : 'Hizmet Alan';

  static String _ikon(Role r) => r == Role.provider
      ? 'assets/svg/ic_wrenchp.svg'
      : 'assets/svg/ic_pshield.svg';

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
        // ── ⚠ ALTLI ÜSTLÜ DİZİLİM ──
        //
        // Roller eskiden YAN YANA duruyordu; iki kutu dar ekranda
        // sıkışıyor, uzun rol adları tek satıra zor sığıyordu.
        // Dikey dizilimde ad ve etiket rahat okunur, geçiş yönü
        // yukarıdan aşağı akar.
        //
        // ⚠ İKON, AD VE ETİKETLERE DOKUNULMADI — yalnız yerleşim ve
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RolKutusu(
              ad: _ad(simdiki),
              ikon: _ikon(simdiki),
              etiket: 'Şu anki rolünüz',
              vurgulu: false,
            ),
            const SizedBox(height: 16),
            // ⚠ AYNI OK İKONU, ÇEYREK TUR ÇEVRİLİ.
            //
            // Yatay dizilimde sağa-sola gösteren `ic_pswap`, dikey
            // dizilimde yukarı-aşağı gösterir. Yeni bir ikon
            // ÜRETİLMEDİ; geçiş anlamı korunur.
            //
            // ⚠ Ok da rol logolarıyla AYNI ORANDA büyüdü: 28 → 36.
            // İkisi büyürken ok küçük kalırsa denge bozulur.
            const RotatedBox(
              quarterTurns: 1,
              child: RefSvg('assets/svg/ic_pswap.svg',
                  size: 36, color: RC.greyLight),
            ),
            const SizedBox(height: 16),
            _RolKutusu(
              ad: _ad(hedef),
              ikon: _ikon(hedef),
              etiket: 'Geçilecek rol',
              vurgulu: true,
            ),
          ],
        ),
      );
}

class _RolKutusu extends StatelessWidget {
  const _RolKutusu({
    required this.ad,
    required this.ikon,
    required this.etiket,
    required this.vurgulu,
  });

  final String ad;
  final String ikon;
  final String etiket;
  final bool vurgulu;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⚠ GEÇİŞ LOGOLARI %30 BÜYÜTÜLDÜ.
          //
          // Daire 64→83, ikon 30→39 (%30, yuvarlanmış). Daire/ikon
          // oranı korundu; ikon dosyaları, adlar ve etiket metinleri
          // DEĞİŞMEDİ. Yazı ölçüleri de aynı — istenen yalnız
          // logoların büyümesiydi.
          Container(
            width: 83,
            height: 83,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: vurgulu ? RC.blue : const Color(0xFFF2F4F7),
              shape: BoxShape.circle,
            ),
            child: RefSvg(ikon,
                size: 39, color: vurgulu ? RC.white : RC.textSoft),
          ),
          const SizedBox(height: 10),
          Text(ad,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: refText(
                  size: RF.s18,
                  weight: RF.w700,
                  color: vurgulu ? RC.blue : RC.text)),
          const SizedBox(height: 4),
          Text(etiket,
              textAlign: TextAlign.center,
              style: refText(
                  size: RF.s135, weight: RF.w400, color: RC.textSoft)),
        ],
      );
}

