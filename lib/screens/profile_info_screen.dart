import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/eposta_oneri.dart';
import '../core/ad_bicimi.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/profile_controller.dart';
import 'widgets/eposta_gonderildi_kutusu.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../ui/sms_kod_akisi.dart';
import '../ui/web_panel.dart';
import 'nav_actions.dart';

/// Profil Bilgileri (HTML pinfo): ad, soyad, e-posta, telefon.
///
/// 6 Kas (kullanıcı kararı) — SADE EKRAN:
/// · "Kaydet" YALNIZ ad/soyadı kaydeder; düğmenin altında 5 sn yeşil
///   "Kaydedildi" görünüp kaybolur. Açılır pencere (şifre, Google ile devam,
///   yeniden giriş) YOKTUR.
/// · E-posta: yeni adrese bağlantı gider; tıklanınca adres değişir ve
///   "E-posta onaylı ✓" görünür (ekrana dönülünce eşitlenir).
/// · Telefon: kutunun altında "Kod Gönder" → kod alanı → "Telefon onaylı ✓"
///   (onaylı numaranın değişimi de aynı satır içi akışla, şifresiz).
class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});
  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  /// Ad ve Soyad AYRI alanlardır (tek "Ad Soyad" kutusu yanlıştı).
  ///
  /// `Account` modelinde tek `name` alanı bulunduğundan kaydederken
  /// mevcut sözleşme korunur: `'$ad $soyad'` biçiminde birleştirilir —
  /// kayıt ekranı da aynı biçimi kullanır.
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  // ══════════════════════════════════════════════════════════════
  // GEÇERLİLİK ≠ HATA GÖRÜNÜRLÜĞÜ
  //
  // ⚠ BU AYRIM BİLİNÇLİDİR VE BOZULMAMALIDIR.
  //
  //   • Aşağıdaki `_*Hata` getter'ları formun İÇ GEÇERLİLİĞİNİ her
  //     yeniden çizimde hesaplar. Buton durumu bundan beslenir.
  //   • Kullanıcıya KIRMIZI HATA gösterme kararı bunlarda DEĞİL,
  //     `_kural` içindedir (odak + terk edilme + gönderim).
  //
  // Yani kullanıcı "O" yazarken buton pasif olabilir ama ALTINDA
  // hata metni ÇIKMAZ.
  // ══════════════════════════════════════════════════════════════

  String? get _adHata => Validators.name(_first.text, min: 3, label: 'ad');
  String? get _soyadHata =>
      Validators.name(_last.text, min: 2, label: 'soyad');
  String? get _epostaHata => Validators.email(_email.text);
  String? get _telefonHata => Validators.phone(_phone.text);

  Account? get _hesap => context.read<AuthController>().currentAccount;

  /// Hesabın onaylı telefonu var mı? Varsa yeni numara PHONE_CHANGE koduyla
  /// değişir (`telefonDegisimi*`), yoksa numara PHONE_VERIFY koduyla
  /// onaylanır (`profiliTamamla`). İkisi de satır içi ve şifresizdir.
  bool get _telefonOnayli {
    final a = _hesap;
    return a != null && a.phoneVerified && a.phone.trim().isNotEmpty;
  }

  // ── TELEFON — SATIR İÇİ SMS ONAYI ──
  // Kutunun altında "Kod Gönder" → kod alanı açılır; 6 hane girilince numara
  // onaylanır, alan ve bağlantı kaybolur, "Telefon onaylı ✓" kalır.
  // Gönderme/sayaç/tekrar gönder/kilit: TEK KAYNAK (`ui/sms_kod_akisi.dart`,
  // Profilinizi Tamamlayın ile aynı).
  final SmsKodAkisi _smsAkis = SmsKodAkisi();
  final _telKod = TextEditingController();
  bool _telDogrulaniyor = false;
  String? _telKodHata;

  void _smsDegisti() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _telKodGonder() async {
    if (_telefonHata != null || _telDogrulaniyor) {
      return;
    }
    final tel = Validators.phoneFmt(_phone.text);
    setState(() => _telKodHata = null);
    final auth = context.read<AuthController>();
    final gonderildi = await _smsAkis.gonder(auth, tel,
        gonderici: _telefonOnayli ? auth.telefonDegisimiKodGonder : null);
    if (!mounted || !gonderildi) {
      return;
    }
    setState(_telKod.clear);
  }

  Future<void> _telDogrula() async {
    final challengeId = _smsAkis.challengeId;
    if (_telDogrulaniyor || challengeId == null) {
      return;
    }
    setState(() {
      _telDogrulaniyor = true;
      _telKodHata = null;
    });
    final auth = context.read<AuthController>();
    // Onaylı numara değişiyorsa kod YENİ numaranın sahipliğini kanıtlar
    // (sunucu: /profiles/me/phone/change, şifresiz — 6 Kas).
    final hata = _telefonOnayli
        ? await auth.telefonDegisimiDogrula(challengeId, _telKod.text)
        : await auth.profiliTamamla(
            telefon: Validators.phoneFmt(_phone.text),
            challengeId: challengeId,
            kod: _telKod.text,
          );
    if (!mounted) {
      return;
    }
    setState(() {
      _telDogrulaniyor = false;
      _telKod.clear();
      if (hata != null) {
        _telKodHata = hata;
      } else {
        _smsAkis.durdur();
        // Alan güncel hesap numarasından doldurulur.
        final guncel = auth.currentAccount;
        if (guncel != null) {
          _phone.text = Validators.phoneLocal(guncel.phone);
        }
      }
    });
  }

  bool get _adSoyadDegisti {
    final acc = _hesap;
    if (acc == null || _adHata != null || _soyadHata != null) {
      return false;
    }
    final yeni = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    return yeni != acc.name.trim();
  }

  /// E-POSTA GEÇERLİ BİÇİMDE DEĞİŞTİ Mİ?
  ///
  /// ⚠ İŞ KURALI: e-posta hesabın kurtarma ve bildirim adresidir.
  /// Değiştirildiğinde YENİ adres doğrulanana kadar hesap doğrulanmış
  /// sayılmaz. Kullanıcı bunu kaydetmeden ÖNCE bilir.
  ///
  /// ⚠ Telefonla AYNI üç koşul: boş DEĞİL · GEÇERLİ · FARKLI.
  /// "onur@" gibi yazım sürecindeki ara değerlerde kutu çıkmaz.
  bool get _epostaDegisti {
    final acc = _hesap;
    if (acc == null || _email.text.trim().isEmpty || _epostaHata != null) {
      return false;
    }
    return epostaNormalize(_email.text) != epostaNormalize(acc.email);
  }

  bool _busy = false;

  /// 6 Kas: kayıt başarılıysa düğmenin altında 5 sn yeşil "Kaydedildi".
  bool _kaydedildi = false;
  Timer? _kaydedildiZamanlayici;

  void _kaydedildiGoster() {
    _kaydedildiZamanlayici?.cancel();
    setState(() => _kaydedildi = true);
    _kaydedildiZamanlayici = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _kaydedildi = false);
      }
    });
  }

  /// ── ⚠ E-POSTA GÖNDERİM DURUMU — ALANIN ALTINDA KALICI YAZI (21 Eki) ──
  ///
  /// Başarı uyarıları (`sysToastOk`) 9 Eyl'den beri bilerek çizilmiyor;
  /// bu yüzden doğrulama bağlantısı gönderildiğinde ekranda HİÇBİR şey
  /// değişmiyordu ve kullanıcı e-postanın gidip gitmediğini bilemiyordu.
  /// Sonuç alt şerit olarak değil, e-posta alanının altında yeşil kutu
  /// (`EpostaGonderildiKutusu`, kullanıcının görseliyle birebir) olarak
  /// durur; adres değişince kalkar.
  bool _epostaGonderildi = false;

  /// ⚠ ALAN BAZLI YENİDEN DOĞRULAMA ANAHTARLARI.
  ///
  /// Uyarı bir kez göründükten sonra, kullanıcı hatayı düzeltince
  /// başka bir alana dokunmaya GEREK KALMADAN kalkar. Formun tamamı
  /// değil YALNIZ ilgili alan yeniden doğrulanır — dokunulmamış
  /// alanlar erkenden kırmızıya boyanmaz.
  final _adKey = GlobalKey<FormFieldState<String>>();
  final _soyadKey = GlobalKey<FormFieldState<String>>();
  final _epostaKey = GlobalKey<FormFieldState<String>>();
  final _telefonKey = GlobalKey<FormFieldState<String>>();

  /// Ad/soyad alanlarının odak düğümleri.
  ///
  /// ⚠ Biçim ODAK KAYBINDA uygulanır; yazarken biçimlendirmek silmeyi
  /// bozuyordu (bkz. `ad_bicimi`).
  final _fAd = FocusNode();
  final _fSoyad = FocusNode();

  /// ⚠ E-POSTA VE TELEFON İÇİN DE ODAK DÜĞÜMÜ.
  ///
  /// Uyarının ne zaman görüneceği odağa bağlıdır (bkz. `_kural`);
  /// bu iki alanın odak durumu izlenmeden kural uygulanamaz.
  final _fEposta = FocusNode();
  final _fTelefon = FocusNode();

  /// UYARI ZAMANI — kayıt ekranıyla AYNI KURAL.
  ///
  /// ⚠ YAZARKEN UYARI YOKTUR.
  ///
  /// Eski davranış her tuşta `validate()` çağırıyordu: kullanıcı tek
  /// harf yazar yazmaz "Geçerli bir ad giriniz" beliriyor, alan
  /// boşaltıldığında da `reset()` düzenlemenin ortasında alan
  /// durumunu sıfırlıyordu — bu yüzden satırlar silinemiyor gibi
  /// davranıyordu.
  ///
  /// Yeni kural: uyarı YALNIZ alan terk edildikten sonra ve alan
  /// odakta DEĞİLKEN görünür.
  final Set<String> _terkEdilen = {};

  /// 6 Kas: Kaydet yalnız ad/soyadı kaydeder ve yalnız ikisi geçerliyken
  /// aktiftir (`_adSoyadDegisti`); gönderimde ayrıca form denetimi yoktur.
  /// Uyarı her zaman odak/terk kuralından geçer.
  String? _kural(
      String alan, FocusNode odak, String? v, String? Function(String?) asil) {
    if (odak.hasFocus) {
      return null;
    }
    if (!_terkEdilen.contains(alan)) {
      return null;
    }
    // ⚠ BOŞ ALAN UYARI ÜRETMEZ.
    //
    // Kullanıcı bir alanı doldurup silerse ekranda uyarı KALMAZ.
    if ((v ?? '').trim().isEmpty) {
      return null;
    }
    return asil(v);
  }

  void _adOdak() {
    if (!_fAd.hasFocus) {
      adAlaniBicimle(_first);
    }
  }

  void _soyadOdak() {
    if (!_fSoyad.hasFocus) {
      adAlaniBicimle(_last);
    }
  }

  /// ── ⚠ E-POSTA ONAYI EŞİTLEME (21 Eki, kullanıcı bulgusu) ──
  ///
  /// E-postadaki bağlantıya tıklanınca doğrulama Firebase'de olur; ekran
  /// bunu bilmediği için "onaylanmadı" yazıp düğmeyi açık tutuyordu.
  /// Ekran açılınca ve uygulamaya/sekmeye geri dönülünce hesap sunucuyla
  /// eşitlenir. "Doğrula ve değiştir" tamamlandıysa alana yeni adres yazılır.
  Future<void> _epostaOnayiniEsitle() async {
    final once = context.read<AuthController>().currentAccount;
    if (once == null) return;
    final oncekiEposta = once.email;
    final oncekiOnay = once.emailVerified;
    await context.read<ProfileController>().epostaOnayiniEsitle();
    if (!mounted) return;
    final sonra = context.read<AuthController>().currentAccount;
    if (sonra == null || !sonra.emailVerified) return;
    final adresDegisti =
        epostaNormalize(sonra.email) != epostaNormalize(oncekiEposta);
    if (!adresDegisti && oncekiOnay) return;
    setState(() {
      _epostaGonderildi = false;
      // Alan hâlâ eski adresi ya da az önce doğrulanan yeni adresi
      // gösteriyorsa güncel adres yazılır (kullanıcı yeni bir şey yazdıysa
      // dokunulmaz).
      final alan = epostaNormalize(_email.text);
      if (alan == epostaNormalize(oncekiEposta) ||
          alan == epostaNormalize(sonra.email)) {
        _email.text = sonra.email;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _epostaOnayiniEsitle();
    }
  }

  @override
  void initState() {
    super.initState();
    _smsAkis.addListener(_smsDegisti);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _epostaOnayiniEsitle();
    });
    _fAd.addListener(_adOdak);
    _fSoyad.addListener(_soyadOdak);
    // Alan odaktan çıkınca "terk edildi" sayılır; odağa dönünce uyarı
    // gizlenir ama girilen değer korunur.
    for (final e in <String, FocusNode>{
      'ad': _fAd,
      'soyad': _fSoyad,
      'eposta': _fEposta,
      'telefon': _fTelefon,
    }.entries) {
      e.value.addListener(() {
        if (!mounted) {
          return;
        }
        setState(() {
          if (!e.value.hasFocus) {
            _terkEdilen.add(e.key);
          }
        });
      });
    }
    final me = context.read<AuthController>().currentAccount!;
    // Mevcut değeri iki alana dağıt: ilk kelime ad, kalanı soyad.
    final parcalar = me.name.trim().split(RegExp(r'\s+'));
    _first = TextEditingController(
        text: parcalar.isNotEmpty ? parcalar.first : '');
    _last = TextEditingController(
        text: parcalar.length > 1 ? parcalar.sublist(1).join(' ') : '');
    _email = TextEditingController(text: me.email);
    // ⚠ MODEL 10 HANE SAKLAR, ALAN YEREL BİÇİM GÖSTERİR.
    //
    // Doğrudan `me.phone` verilince alan `5321112233` diye açılıyordu:
    // baştaki `0` yok, biçimlendirici de yalnız KULLANICI yazınca
    // devreye girdiği için ilk görünüm kuralın dışında kalıyordu.
    // Başlangıç değeri de aynı kuraldan geçirilir.
    // ⚠ BAŞLANGIÇ DEĞERİ DE ALAN KURALINDAN GEÇER.
    //
    // Model 10 hane saklar. Doğrudan verilince alan `5321112233` diye
    // açılıyordu: ne baştaki `0` ne de gruplama vardı; biçimlendirici
    // yalnız KULLANICI yazınca çalıştığı için ilk görünüm kuralın
    // dışında kalıyordu.
    _phone = TextEditingController(
        // ⚠ ALANDA HAM YEREL BİÇİM DURUR (`05321112233`).
        //
        // Gruplama artık yalnız OKUMA yerlerinde uygulanır; alan içinde
        // boşluk olması silmeyi ve imleç konumunu bozuyordu
        // (bkz. `TelefonBicimlendirici`).
        text: Validators.phoneLocal(me.phone));
  }

  Future<void> _mevcutEpostaDogrulamaGonder() async {
    if (_busy) return;
    final mevcut = _hesap?.email.trim() ?? '';
    if (mevcut.isEmpty || epostaNormalize(_email.text) != epostaNormalize(mevcut)) {
      sysToastErr(context, SysKind.genericError, extra: 'Mevcut e-posta adresini geri yükleyin veya yeni adres doğrulamasını kullanın.');
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<ProfileController>().mevcutEpostaDogrulamaGonder(mevcut);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    setState(() => _epostaGonderildi = true);
  }

  /// 6 Kas (kullanıcı kararı): yeni adrese bağlantı ŞİFRESİZ gönderilir;
  /// adres yalnız bağlantı tıklanınca değişir (bkz. `_epostaOnayiniEsitle`).
  Future<void> _yeniEpostaDogrulamaGonder() async {
    if (_busy || !_epostaDegisti || _epostaHata != null) return;
    setState(() => _busy = true);
    final err = await context
        .read<ProfileController>()
        .epostaDegisimiBaslat(epostaNormalize(_email.text));
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    setState(() => _epostaGonderildi = true);
  }

  /// KAYDET — YALNIZ AD/SOYAD (6 Kas).
  ///
  /// ⚠ E-posta ve telefon bu çağrıda GÖNDERİLMEZ: e-posta bağlantıyla,
  /// telefon SMS koduyla kendi satırında değişir. Ekranda kalınır.
  Future<void> _save() async {
    if (_busy || !_adSoyadDegisti) {
      return;
    }
    setState(() {
      _busy = true;
      _kaydedildi = false;
    });
    final err = await context.read<ProfileController>().updateProfile(
        name: '${_first.text.trim()} ${_last.text.trim()}'.trim());
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    _kaydedildiGoster();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kaydedildiZamanlayici?.cancel();
    _email.dispose();
    _fAd.removeListener(_adOdak);
    _fSoyad.removeListener(_soyadOdak);
    _fAd.dispose();
    _fSoyad.dispose();
    _fEposta.dispose();
    _fTelefon.dispose();
    _smsAkis
      ..removeListener(_smsDegisti)
      ..dispose();
    _telKod.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefShell(
      nav: RefBottomNav(
        activeKey: 'profil',
        items: custNavItems(
          context,
          saglayici:
              context.watch<AuthController>().activeRole == Role.provider,
        ),
      ),
      child: Form(
        // ⚠ UYARININ ZAMANI `_kural` İÇİNDE BELİRLENİR.
        //
        // Doğrulama her yeniden çizimde koşar, ama alan odaktaysa ya
        // da henüz terk edilmediyse `null` döner. Böylece "ilk harfte
        // kırmızı" davranışı oluşmaz.
        autovalidateMode: AutovalidateMode.always,
        key: _form,
        // ── ⚠ MASAÜSTÜ WEB: ORTAK PANEL — `change_password_screen`
        // ile AYNI kural (bkz. `ui/web_panel.dart`). ──
        child: WebPanel(
          baslik: 'Profil Bilgilerim',
          altYazi: 'Profil bilgilerinizi görüntüleyebilir ve '
              'güncelleyebilirsiniz.',
          icerik: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ⚠ BAŞLIK ÇİFT ÇİZİLMEZ: panelde başlığı panel çizer.
            if (!WebPanel.panelMi(context)) ...[
              const RefPageTitle('Profil Bilgilerim'),
              const RefSubtitle(
                  'Profil bilgilerinizi görüntüleyebilir ve '
                  'güncelleyebilirsiniz.'),
              // ⚠ FOTOĞRAF YOK (16 Eki, kullanıcı kararı): bu ekranda profil
              // fotoğrafı ve kamera simgesi gösterilmez; yalnız dört alan.
            ],

            // ⚠ Alt başlıkla ilk alan arasındaki boşluk da etiketten
            // geliyordu; etiket kalkınca elle verildi.
            const SizedBox(height: 14),
            RefTextField(
              // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
              zorunlu: true,
              alanAnahtari: _adKey,
              // ⚠ `onChanged` DOĞRULAMA YAPMAZ.
              //
              // Yalnız buton durumunu tazelemek için yeniden çizim
              // ister. Hata görünürlüğü `_kural`'a aittir: alan
              // odaktayken uyarı çıkmaz, yani "O" yazarken kırmızı
              // metin belirmez.
              onChanged: (_) => setState(() {}),
              focusNode: _fAd,
              controller: _first,
              // ⚠ ENTER/İLERİ TUŞU BİR SONRAKİ ALANA GEÇER.
              //
              // Bu ekranda `textInputAction` HİÇ VERİLMİYORDU; tek
              // satırlık alanlarda varsayılan `done`dur, yani Enter
              // klavyeyi kapatıyor ve kullanıcı her alanı ELLE
              // seçmek zorunda kalıyordu.
              //
              // Sıra görsel sırayla AYNI: Ad → Soyad → E-posta →
              // Telefon. Son alanda `done`: klavye kapanır, form
              // kendiliğinden GÖNDERİLMEZ (buton kuralı ayrıdır).
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _fSoyad.requestFocus(),
              hint: 'Ad',
              // ⚠ Baş harfler BÜYÜK — Türkçe duyarlı (kayıt ekranıyla aynı).
              validator: (v) => _kural('ad', _fAd, v,
                  (x) => Validators.name(x, min: 3, label: 'ad')),
            ),

            // ⚠ ALANLAR ARASI BOŞLUK — ETİKETLER KALKINCA GEREKTİ.
            //
            // Dikey aralığı eskiden `RefFieldLabel` sağlıyordu
            // (üstte 15, altta 7 dolgu). Etiketler kaldırılınca
            // kutular birbirine yapıştı. Değer kayıt ekranıyla
            // AYNI: 12 dp.
            const SizedBox(height: 12),
            RefTextField(
              // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
              zorunlu: true,
              alanAnahtari: _soyadKey,
              // ⚠ `onChanged` doğrulama YAPMAZ — bkz. üstteki not.
              onChanged: (_) => setState(() {}),
              focusNode: _fSoyad,
              controller: _last,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _fEposta.requestFocus(),
              hint: 'Soyad',
              // ⚠ Baş harfler BÜYÜK — Türkçe duyarlı (kayıt ekranıyla aynı).
              validator: (v) => _kural('soyad', _fSoyad, v,
                  (x) => Validators.name(x, min: 2, label: 'soyad')),
            ),

            // ⚠ E-POSTA ZORUNLUDUR.
            //
            // Hesap kurtarma, bildirim ve fatura akışlarının tamamı
            // e-postaya bağlıdır; kayıt ekranlarında da zorunludur.
            // Zorunluluk yıldızı bu yüzden eklendi.
            // ⚠ ALANLAR ARASI BOŞLUK — ETİKETLER KALKINCA GEREKTİ.
            //
            // Dikey aralığı eskiden `RefFieldLabel` sağlıyordu
            // (üstte 15, altta 7 dolgu). Etiketler kaldırılınca
            // kutular birbirine yapıştı. Değer kayıt ekranıyla
            // AYNI: 12 dp.
            const SizedBox(height: 12),
            RefTextField(
              // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
              zorunlu: true,
              controller: _email,
              alanAnahtari: _epostaKey,
              focusNode: _fEposta,
              // ⚠ `onChanged` doğrulama YAPMAZ.
              //
              onChanged: (_) => setState(() => _epostaGonderildi = false),
              hint: 'E-posta',
              keyboardType: TextInputType.emailAddress,
                  // ⚠ E-postada baş harf büyütülmez.
                  textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _fTelefon.requestFocus(),
              validator: (v) => _kural('eposta', _fEposta, v, Validators.email),
            ),

            // E-POSTA DOĞRULAMA DURUMU — e-posta alanının hemen altında.
            Builder(builder: (context) {
              final hesap = context.watch<AuthController>().currentAccount;
              final yeniAdresGirildi = _epostaDegisti;
              final onayli = !yeniAdresGirildi && (hesap?.emailVerified ?? false);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          onayli ? Icons.check_circle : Icons.info_outline,
                          size: 18,
                          color: onayli ? RC.success : RC.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            onayli ? 'E-posta onaylı ✓' : 'E-posta adresi onaylanmadı',
                            style: refText(
                              size: RF.s135,
                              weight: RF.w500,
                              color: onayli ? RC.success : RC.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 21 Eki: kullanıcının görseliyle birebir — durum
                    // satırının altında, düğmenin üstünde.
                    if (_epostaGonderildi && !onayli) ...[
                      const SizedBox(height: 10),
                      const EpostaGonderildiKutusu(),
                      const SizedBox(height: 4),
                    ],
                    if (!onayli && !yeniAdresGirildi)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _mevcutEpostaDogrulamaGonder,
                          icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                          label: const Text('E-posta Adresini Doğrula'),
                        ),
                      ),
                    if (yeniAdresGirildi)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _yeniEpostaDogrulamaGonder,
                          icon: const Icon(Icons.outgoing_mail, size: 18),
                          label: const Text('Yeni E-posta Adresini Doğrula'),
                        ),
                      ),
                  ],
                ),
              );
            }),

            // ⚠ KAYIT EKRANIYLA AYNI KISIT.
            //
            // Yalnız rakam, en fazla `kPhoneLocalMaxLength` hane
            // (baştaki `0` dâhil) ve yazmaya başlanınca başa otomatik
            // `0` eklenir (`Validators.phoneLocal`).
            // ⚠ ALANLAR ARASI BOŞLUK — ETİKETLER KALKINCA GEREKTİ.
            //
            // Dikey aralığı eskiden `RefFieldLabel` sağlıyordu
            // (üstte 15, altta 7 dolgu). Etiketler kaldırılınca
            // kutular birbirine yapıştı. Değer kayıt ekranıyla
            // AYNI: 12 dp.
            const SizedBox(height: 12),
            RefTextField(
              // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
              zorunlu: true,
              controller: _phone,
              alanAnahtari: _telefonKey,
              focusNode: _fTelefon,
              // ⚠ `onChanged` doğrulama YAPMAZ — yalnız "numara
              onChanged: (_) {
                final oncedenGonderildi =
                    _smsAkis.gonderildiMi(Validators.phoneFmt(_phone.text));
                _smsAkis.telefonDegisti(Validators.phoneFmt(_phone.text));
                setState(() {
                  if (!oncedenGonderildi) {
                    _telKod.clear();
                    _telKodHata = null;
                  }
                });
              },
              // ⚠ "5XX XXX XX XX" BİÇİM ÖRNEĞİDİR, alan adı değil:
                      // etikette "Telefon" yazar, kutunun içinde biçim
                      // ipucu kalır.
                      etiket: 'Telefon',
                      yerTutucu: '5XX XXX XX XX',
              keyboardType: TextInputType.number,
              // Son alan: klavye kapanır, form kendiliğinden gönderilmez.
              textInputAction: TextInputAction.done,
              inputFormatters: [
                // ⚠ TEK KURAL KAYNAĞI — bkz. `TelefonBicimlendirici`.
                // Baştaki `0` elle yazılamaz, otomatik atanır; `5` ile
                // başlamayan numara alana hiç girmez.
                TelefonBicimlendirici(),
              ],
              validator: (v) =>
                  _kural('telefon', _fTelefon, v, Validators.phone),
            ),

            // ── 5 Kas: TELEFON ONAY DURUMU — telefon alanının hemen altında
            // (e-posta durumu ile aynı görünüm). Onaylı telefonu olmayan
            // hesapta "Kod Gönder" → kod alanı → "Telefon onaylı ✓".
            Builder(builder: (context) {
              final hesap = context.watch<AuthController>().currentAccount;
              final tel = Validators.phoneFmt(_phone.text);
              // Kutudaki numara hesabın ONAYLI numarasıysa "Telefon onaylı ✓";
              // başka bir numara yazıldıysa satır içi kod akışı (6 Kas).
              final onayli = hesap != null &&
                  hesap.phoneVerified &&
                  hesap.phone.trim().isNotEmpty &&
                  tel == hesap.phone;
              if (onayli) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 18, color: RC.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Telefon onaylı ✓',
                          style: refText(
                              size: RF.s135,
                              weight: RF.w500,
                              color: RC.success)),
                    ),
                  ]),
                );
              }
              final gecerli = _telefonHata == null;
              final gonderildi = gecerli && _smsAkis.gonderildiMi(tel);
              final denendi = gecerli && _smsAkis.denendiMi(tel);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: RC.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Telefon numarası onaylanmadı',
                            style: refText(
                                size: RF.s135,
                                weight: RF.w500,
                                color: RC.textMuted)),
                      ),
                    ]),
                    if (gecerli && !gonderildi && !denendi && _smsAkis.sayac == 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy || _smsAkis.gonderiliyor
                              ? null
                              : _telKodGonder,
                          icon: const Icon(Icons.sms_outlined, size: 18),
                          label: const Text('Kod Gönder'),
                        ),
                      ),
                    if (gonderildi || denendi) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _telKod,
                        enabled: gonderildi && !_telDogrulaniyor,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (v) {
                          _smsAkis.hatayiTemizle();
                          setState(() => _telKodHata = null);
                          if (v.length == 6) {
                            _telDogrula();
                          }
                        },
                        decoration: refIkonluAlanDekoru(
                          'Telefonunuza gelen 6 haneli kodu girin',
                          'assets/svg/ic_plock.svg',
                          hata: _telKodHata ?? _smsAkis.hata,
                          suffix: _telDogrulaniyor
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      SmsKodAltSatiri(
                        akis: _smsAkis,
                        telefon: tel,
                        onTekrar: _telKodGonder,
                        kapali: _telDogrulaniyor,
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            // ── 6 Kas: SADE "Kaydet" — yalnız ad/soyad değişip geçerliyse
            // aktif; başarıda altında 5 sn yeşil "Kaydedildi".
            RefNextButton(
              'Kaydet',
              busy: _busy,
              onPressed: _adSoyadDegisti ? _save : null,
            ),
            SizedBox(
              height: 28,
              child: _kaydedildi
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Kaydedildi',
                          textAlign: TextAlign.center,
                          style: refText(
                              size: RF.s135,
                              weight: RF.w600,
                              color: RC.success)),
                    )
                  : null,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// `pfAvatar(104)` + `.pf-cam` — profil fotoğrafı seçici.
