import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/region_controller.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'widgets/kategori_secim_paneli.dart';
import '../ui/alt_panel.dart';

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
/// hizmet bölgesi zorunludur. Müşteri rolü ek bilgi istemez.
/// Ad, telefon ve e-posta mevcut hesaptan taşınır; tekrar sorulmaz.
class RoleSwitchScreen extends StatefulWidget {
  const RoleSwitchScreen({super.key});

  @override
  State<RoleSwitchScreen> createState() => _RoleSwitchScreenState();
}

class _RoleSwitchScreenState extends State<RoleSwitchScreen> {
  Set<String> _kategoriler = {};
  Set<String> _bolgeler = {};

  /// ⚠ HİZMET İLİ TEK SEÇİMDİR.
  ///
  /// Hizmet veren TEK bir ilde çalışır; o ilin ilçelerinden istediği
  String? _il;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final acc = context.read<AuthController>().currentAccount;
    _kategoriler = {...?acc?.categories};
    _bolgeler = {...?acc?.serviceDistricts};
    // Kayıtlı adres varsa o ilden başlanır; yoksa tek il ise o seçilir.
    final r = context.read<RegionController>();
    _il = acc?.address?.city.isNotEmpty == true
        ? acc!.address!.city
        : r.soleCityName ?? r.cityName;
  }

  Role get _hedef => context.read<AuthController>().activeRole == Role.provider
      ? Role.customer
      : Role.provider;

  /// Hedef rol hesapta ZATEN tanımlı mı? Tanımlıysa bilgi istenmez.
  bool _rolVar(Account acc, Role r) => acc.roles.contains(r);

  bool get _hazir {
    final acc = context.read<AuthController>().currentAccount;
    if (acc == null) {
      return false;
    }
    if (_hedef == Role.customer || _rolVar(acc, Role.provider)) {
      return true;
    }
    return _kategoriler.isNotEmpty &&
        _il != null &&
        _bolgeler.isNotEmpty;
  }

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
    final eksikVar = hedef == Role.provider && !_rolVar(acc, Role.provider);

    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: RefDetailHeader(title: 'Rol Değiştir'),
            ),
            // ── ⚠ İKİ AYRI YERLEŞİM ──
            //
            // Bilgilendirme kutusu kalkınca, tamamlanacak bir şey
            // olmayan durumda ekranın tamamı boş kalıyordu: kart
            // yukarıda asılı duruyor, altında yarım sayfa boşluk
            // oluyordu.
            //
            //   · eksik bilgi VAR  → kart üstte, altında tamamlanacak
            //                        liste (kaydırmalı)
            //   · eksik bilgi YOK  → kart sayfanın DİKEY ORTASINDA
            if (!eksikVar)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _GecisKarti(simdiki: simdiki, hedef: hedef),
                  ),
                ),
              )
            else
            Expanded(
              child: RefScroll(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Geçiş özeti: şu anki rol → hedef rol ──
                    _GecisKarti(simdiki: simdiki, hedef: hedef),
                    const SizedBox(height: 18),

                    if (eksikVar) ...[
                      Text('Tamamlanması Gerekenler',
                          style: refText(
                              size: RF.s15,
                              weight: RF.w800,
                              color: RC.text)),
                      const SizedBox(height: 4),
                      Text(
                        // ⚠ KISA VE ÖZ. Kategori sınırı buradan
                        'Teklif verebilmek için bu bilgiler gereklidir.',
                        style: refText(
                            size: RF.s125,
                            weight: RF.w400,
                            color: RC.textSoft,
                            height: RF.lh145),
                      ),
                      const SizedBox(height: 12),
                      _GereklilikSatiri(
                        ikon: 'assets/svg/ic_wrenchp.svg',
                        baslik: 'Hizmet Kategorileri',
                        bosMetin: 'Henüz seçilmedi',
                        secili: _kategoriler,
                        onTap: _busy ? null : _kategoriSec,
                      ),
                      const SizedBox(height: 10),
                      // ⚠ ÖNCE İL, SONRA İLÇE. Hizmet veren TEK ilde
                      // çalışır; o ilin ilçelerinden istediği kadarını
                      // seçebilir.
                      _GereklilikSatiri(
                        ikon: 'assets/svg/ic_ppin.svg',
                        baslik: 'Hizmet İli',
                        bosMetin: 'Henüz seçilmedi',
                        secili: _il == null ? const {} : {_il!},
                        onTap: _busy ? null : _ilSec,
                      ),
                      const SizedBox(height: 10),
                      _GereklilikSatiri(
                        ikon: 'assets/svg/ic_ppin.svg',
                        baslik: 'Hizmet İlçeleri',
                        bosMetin: _il == null
                            ? 'Önce il seçin'
                            : 'Henüz seçilmedi',
                        secili: _bolgeler,
                        onTap: _busy ? null : _bolgeSec,
                      ),
                    ],
                  ],
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
                onPressed: _hazir ? _gec : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kategoriSec() async {
    // ── ⚠ DÜZ LİSTE DEĞİL, ARAMA TABANLI SEÇİM ──
    //
    // Eskiden `RefMultiSelectSheet` 53 ANA KATEGORİYİ onay kutusu
    // listesi olarak gösteriyordu. İki sorun vardı:
    //
    //   1. Kullanıcı YALNIZ ANA KATEGORİ seçebiliyordu. "Kombi
    //      Servisi" seçen usta 4 alt hizmetin tamamına bağlanıyor,
    //      "yalnız kombi bakımı yapıyorum" diyemiyordu.
    //   2. 53 satırı kaydırarak aramak yorucuydu.
    //
    // Artık Hizmet Kategorilerim ekranıyla AYNI panel kullanılır:
    // kullanıcı yazar, eşleşen ALT HİZMETLER çıkar, dokununca seçilir.
    // İki ekranda iki farklı davranış olmaz.
    final sonuc = await altPanelGoster<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => KategoriSecimPaneli(baslangic: _kategoriler),
    );
    if (sonuc == null || !mounted) {
      return;
    }
    setState(() => _kategoriler = sonuc);
  }

  /// HİZMET İLİ — TEK SEÇİM.
  ///
  /// Liste sunucudan gelen aktif illerdir; koda gömülü değildir.
  /// İl değişirse seçili ilçeler TEMİZLENİR.
  Future<void> _ilSec() async {
    final rc = context.read<RegionController>();
    final iller = rc.cityNames;
    if (iller.isEmpty) {
      return;
    }
    final sonuc = await altPanelGoster<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => RefMultiSelectSheet(
        title: 'Hizmet Verilen İl',
        options: iller,
        initial: _il == null ? const {} : {_il!},
        // ⚠ TEK SEÇİM: son dokunulan il geçerlidir.
        tekSecim: true,
      ),
    );
    if (sonuc == null || !mounted) {
      return;
    }
    final yeni = sonuc.isEmpty ? null : sonuc.first;
    if (yeni == _il) {
      return;
    }
    setState(() {
      _il = yeni;
      // Başka ilin ilçesi seçili kalamaz.
      _bolgeler = {};
    });
  }

  Future<void> _bolgeSec() async {
    if (_il == null) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Önce hizmet vereceğiniz ili seçin');
      return;
    }
    // ⚠ Controller DİNLENİR: bölge verisi sonradan gelirse liste
    // kendiliğinden dolar, boş "Sonuç bulunamadı" oluşmaz.
    final sonuc = await altPanelGoster<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Consumer<RegionController>(
        builder: (_, rc, __) => RefMultiSelectSheet(
          title: '$_il — Hizmet Verilen İlçeler',
          // ⚠ SEÇİLİ İLİN ilçeleri; varsayılan ilin değil.
          options: rc.districtsOf(_il),
          initial: _bolgeler,
          tumuEtiketi: 'Tüm İlçeler',
        ),
      ),
    );
    if (sonuc != null && mounted) {
      setState(() => _bolgeler = sonuc);
    }
  }

  /// ROLE GEÇİŞ
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
      final ekleErr = await auth.addRole(
        hedef,
        categories: hedef == Role.provider ? _kategoriler : null,
        serviceDistricts: hedef == Role.provider ? _bolgeler : null,
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

/// Eksik bilgi satırı — seçim yapılınca yeşil onaya döner.
class _GereklilikSatiri extends StatelessWidget {
  const _GereklilikSatiri({
    required this.ikon,
    required this.baslik,
    required this.bosMetin,
    required this.secili,
    required this.onTap,
  });

  final String ikon;
  final String baslik;
  final String bosMetin;
  final Set<String> secili;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tamam = secili.isNotEmpty;
    // Seçilenler tek satırda özetlenir; taşarsa "+N" ile kısaltılır.
    final ozet = tamam
        ? (secili.length <= 2
            ? secili.join(', ')
            : '${secili.take(2).join(', ')} +${secili.length - 2}')
        : bosMetin;
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(
            color: tamam ? const Color(0xFFCDE9D8) : const Color(0xFFF7E4C8),
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(RR.r14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tamam
                    ? const Color(0xFFE9F9EF)
                    : const Color(0xFFFDF4E8),
                shape: BoxShape.circle,
              ),
              child: RefSvg(ikon,
                  size: 18,
                  color: tamam
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF5820C)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(baslik,
                      style: refText(
                          size: RF.s145, weight: RF.w700, color: RC.text)),
                  const SizedBox(height: 2),
                  Text(ozet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s125,
                          weight: RF.w400,
                          color: tamam
                              ? RC.textSoft
                              : const Color(0xFFF5820C))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (tamam)
              const RefSvg('assets/svg/ic_checkc.svg',
                  size: 22, color: Color(0xFF16A34A))
            else
              const RefSvg('assets/svg/ic_chev.svg',
                  size: 18, color: Color(0xFFD3D8E0)),
          ],
        ),
      ),
    );
  }
}
