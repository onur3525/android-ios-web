import 'package:flutter/material.dart';
import '../domain/form_mesajlari.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/eposta_oneri.dart';
import '../core/ad_bicimi.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/profile_controller.dart';
import 'otp_screen.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';
import '../core/geri.dart';

/// Profil Bilgileri (HTML pinfo): ad, e-posta, profil fotoğrafı;
/// telefon değişikliği SMS DOĞRULAMALI (OTP ekranı yeniden kullanılır).
class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});
  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
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

  /// Formun TAMAMI kurallara uygun mu? (hata gösterimiyle ilgisi yok)
  bool get _formGecerli =>
      _adHata == null &&
      _soyadHata == null &&
      _epostaHata == null &&
      _telefonHata == null;

  Account? get _hesap => context.read<AuthController>().currentAccount;

  /// Ad veya soyad GEÇERLİ biçimde değişti mi?
  bool get _adSoyadDegisti {
    final acc = _hesap;
    if (acc == null || _adHata != null || _soyadHata != null) {
      return false;
    }
    final yeni = '${_first.text.trim()} ${_last.text.trim()}'.trim();
    return yeni != acc.name.trim();
  }

  /// TELEFON GEÇERLİ BİÇİMDE DEĞİŞTİ Mİ?
  ///
  /// ⚠ ÜÇ KOŞUL BİRLİKTE: boş DEĞİL · GEÇERLİ · kayıtlıdan FARKLI.
  ///
  /// Eskiden yalnız "farklı mı" bakılıyordu. Alan boşaltıldığında da
  /// "farklı" çıkıyor, bu yüzden doğrulama bilgi kutusu boş alanda
  /// bile görünüyordu. Boşaltma bir doğrulama gerektiren değişiklik
  /// DEĞİLDİR.
  bool get _telefonDegisti {
    final acc = _hesap;
    if (acc == null || _phone.text.trim().isEmpty || _telefonHata != null) {
      return false;
    }
    return Validators.phoneFmt(_phone.text) != acc.phone;
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

  /// Kaydedilecek GEÇERLİ bir değişiklik var mı?
  bool get _degisiklikVar =>
      _adSoyadDegisti || _telefonDegisti || _epostaDegisti;

  /// ⚠ İKİ DOĞRULAMA AYRIDIR: telefon SMS ile, e-posta bağlantı ile
  /// doğrulanır. Birinin doğrulanması ötekini doğrulanmış SAYMAZ.
  bool get _dogrulamaGerekli => _telefonDegisti || _epostaDegisti;

  bool _busy = false;

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

  /// ⚠ YALNIZ `validate()` ÇAĞRISI SÜRESİNCE AÇIK.
  ///
  /// Eski hâlde bunun yerine kalıcı bir `_gonderimDenendi` bayrağı
  /// vardı ve bir kez kaydetmeye basıldıktan sonra BİR DAHA
  /// KAPANMIYORDU: kullanıcı alanı düzeltmek için içine girip yazsa
  /// bile kırmızı uyarı ekranda ASILI KALIYORDU.
  ///
  /// Gönderim anında odak kuralı atlanmalıdır (yoksa o sırada odakta
  /// olan alan denetlenmeden geçer), ama gönderimden SONRA normal
  /// kural yeniden geçerlidir.
  bool _gonderimAninda = false;

  String? _kural(
      String alan, FocusNode odak, String? v, String? Function(String?) asil) {
    if (!_gonderimAninda) {
      if (odak.hasFocus) {
        return null;
      }
      if (!_terkEdilen.contains(alan)) {
        return null;
      }
      // ⚠ BOŞ ALAN UYARI ÜRETMEZ.
      //
      // Kullanıcı bir alanı doldurup silerse ekranda uyarı KALMAZ.
      // Zorunluluk gönderim anında denetlenir; ama düğme zaten boş
      // alan varken PASİF olduğu için gönderim denenemez.
      if ((v ?? '').trim().isEmpty) {
        return null;
      }
    }
    return asil(v);
  }

  /// Gönderimde tüm alanları denetler; uyarıların kalıcı olmaması için
  /// alanları "terk edilmiş" sayar ve odak kuralını geri açar.
  bool _hepsiniDenetle() {
    _terkEdilen.addAll(const ['ad', 'soyad', 'eposta', 'telefon']);
    _gonderimAninda = true;
    final ok = _form.currentState!.validate();
    _gonderimAninda = false;
    setState(() {});
    return ok;
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

  @override
  void initState() {
    super.initState();
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

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    // Kaydetme denendi: tüm alanlar denetlenir.
    if (!_hepsiniDenetle()) {
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    final profile = context.read<ProfileController>();
    final newPhone = Validators.phoneFmt(_phone.text);
    final oldPhone = auth.currentAccount!.phone;
    // ── AD/SOYAD ──
    //
    // ⚠ E-POSTA BU ÇAĞRIDA GÖNDERİLMEZ. İş kuralları §4:
    // "E-posta değişimi doğrulama bağlantısıyla yapılır." Profil
    // güncelleme ucundan yollamak doğrulamayı atlatmak olurdu.
    final err = await profile.updateProfile(
        name: '${_first.text.trim()} ${_last.text.trim()}'.trim());
    if (!mounted) {
      return;
    }
    if (err != null) {
      setState(() => _busy = false);
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }

    // ── E-POSTA DEĞİŞİMİ — DOĞRULAMA BAĞLANTISI ──
    //
    // ⚠ Hesabın e-postası BURADA DEĞİŞMEZ: sunucu yeni adrese
    // bağlantı yollar, adres ancak tıklanınca yürürlüğe girer.
    // Kullanıcıya "güncellendi" demek yanlış olurdu.
    var epostaBeklemede = false;
    if (_epostaDegisti) {
      final e = await profile
          .epostaDegisimiBaslat(epostaNormalize(_email.text));
      if (!mounted) {
        return;
      }
      if (e != null) {
        setState(() => _busy = false);
        sysToastErr(context, SysKind.genericError, extra: e.message);
        return;
      }
      epostaBeklemede = true;
    }
    setState(() => _busy = false);
    if (newPhone != oldPhone) {
      // ── TELEFON DEĞİŞİKLİĞİ CHALLENGE'I ──
      //
      // ⚠ MEVCUT NUMARA BU AŞAMADA DEĞİŞMEZ. Challenge YENİ numaraya
      // bağlanır; doğrulama başarılı olduğunda benzersizlik yeniden
      // denetlenir ve bağlama tek adımda yapılır (Y6).
      final ch = await context
          .read<AuthController>()
          .telefonDegisimiKodGonder(newPhone);
      if (!mounted) {
        return;
      }
      if (ch.hata != null || ch.challengeId == null) {
        sysToastErr(context, SysKind.genericError,
            extra: ch.hata ?? FormMesaj.otpGonderilemedi);
        return;
      }
      var challengeId = ch.challengeId!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: newPhone,
            purpose: OtpPurpose.phoneChange,
            // ⚠ EKRAN KODU DOĞRULAMAZ. Numara da buradan geçmez —
            // challenge'ın içinden gelir (Y4): kullanıcı alanı
            // sonradan değiştirse bile eski challenge yeni değeri
            // doğrulayamaz.
            dogrula: (kod) => context
                .read<AuthController>()
                .telefonDegisimiDogrula(challengeId, kod),
            // ⚠ AKIŞA ÖZEL: yeni DEĞİŞİKLİK challenge'ı üretilir.
            yenidenGonder: () async {
              final y = await context
                  .read<AuthController>()
                  .telefonDegisimiKodGonder(newPhone);
              if (y.hata != null || y.challengeId == null) {
                return y.hata ?? FormMesaj.otpGonderilemedi;
              }
              challengeId = y.challengeId!;
              return null;
            },
            onVerified: (c, _) {
              // ⚠ EKRAN GERÇEK DURUMDAN TAZELENİR.
              //
              // Alan, kullanıcının yazdığı metinden değil GÜNCEL
              // hesap durumundan doldurulur: challenge'la doğrulanan
              // numara ile ekranda görünen numara arasında fark
              // kalmaz (kullanıcı yazımı boşluklu/0'lı olabilir).
              final guncel = context.read<AuthController>().currentAccount;
              if (guncel != null && mounted) {
                _phone.text = Validators.phoneLocal(guncel.phone);
              }
              sysToastOk(c, 'Telefon numaranız güncellendi');
              Navigator.pop(c);
              geriGit(c);
            },
          ),
        ),
      );
    } else {
      // ⚠ MESAJ GERÇEĞİ SÖYLER: e-posta değiştiyse "güncellendi"
      // DENMEZ — henüz değişmedi, doğrulama bekliyor.
      sysToastOk(
          context,
          epostaBeklemede
              ? 'Yeni e-posta adresinize doğrulama bağlantısı gönderildi. '
                  'Bağlantıya tıklayana kadar mevcut adresiniz geçerlidir.'
              : 'Profil bilgileriniz güncellendi');
      geriGit(context);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _fAd.removeListener(_adOdak);
    _fSoyad.removeListener(_soyadOdak);
    _fAd.dispose();
    _fSoyad.dispose();
    _fEposta.dispose();
    _fTelefon.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠ `final me = ...currentAccount!` KALDIRILDI: değerler artık
    // `initState`'te denetleyicilere yükleniyor, burada okunmuyordu.
    // Ayrıca `!` oturum düşerse çökme riskiydi.
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RefPageTitle('Profil Bilgilerim'),
            const RefSubtitle(
                'Profil bilgilerinizi görüntüleyebilir ve '
                'güncelleyebilirsiniz.'),

            // ⚠ FOTOĞRAF BÖLÜMÜ BU EKRANDAN KALDIRILDI.
            //
            // Fotoğraf yönetimi TEK YERDE olmalı: Profil ekranındaki
            // avatar. Aynı işi iki ekranda sunmak hem yer kaplıyor
            // hem de "hangisi geçerli?" sorusunu doğuruyordu.
            // Bu ekran artık YALNIZ ad/soyad/e-posta/telefon alanını
            // yönetir.

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
              // Yalnız "e-posta değişti mi" bilgi kutusu için yeniden
              // çizim tetikler; uyarının zamanı `_kural`'a aittir.
              onChanged: (_) => setState(() {}),
              hint: 'E-posta',
              keyboardType: TextInputType.emailAddress,
                  // ⚠ E-postada baş harf büyütülmez.
                  textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              onEditingComplete: () => _fTelefon.requestFocus(),
              // ⚠ ÖNERİ SATIRI KALDIRILDI.
              //
              // Yazım hatası artık BİLGİ NOTU değil, DOĞRULAMA HATASIDIR:
              // `Validators.email` yaygın sağlayıcıdaki hatalı uzantıyı
              // ("hotmail.co") reddeder ve alanın altında kırmızı uyarı
              // verir. Kayıt ekranlarıyla AYNI davranış.
              validator: (v) => _kural('eposta', _fEposta, v, Validators.email),
            ),

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
              // değişti mi" bilgisi için yeniden çizim.
              onChanged: (_) => setState(() {}),
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

            // ⚠ KUTU ÜÇ KOŞULLA ÇIKAR: boş değil · geçerli · farklı.
            // Yazım sürecindeki ara değerlerde ("onur@") görünmez.
            if (_epostaDegisti)
              RefInfoBox(
                mavi: true,
                margin: const EdgeInsets.only(top: 14),
                child: Text(
                  'Yeni e-posta adresinize doğrulama bağlantısı '
                  'gönderilir. Doğrulanana kadar bildirim ve hesap '
                  'kurtarma iletileri ESKİ adresinize gider.',
                  style: refText(
                    size: RF.s135,
                    weight: RF.w400,
                    color: RC.textDark,
                    height: RF.lh150,
                  ),
                ),
              ),

            // ⚠ Aynı üç koşul telefonda da geçerlidir.
            if (_telefonDegisti)
              RefInfoBox(
                mavi: true,
                margin: const EdgeInsets.only(top: 14),
                child: Text(
                  'Numara doğrulanmadan telefon güncellemesi kaydedilmez.',
                  style: refText(
                    size: RF.s135,
                    weight: RF.w400,
                    color: RC.textDark,
                    height: RF.lh150,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            // ── BUTON DURUMU ──
            //
            // ⚠ PASİF: hiç değişiklik yoksa VEYA formda eksik/geçersiz
            // zorunlu alan varsa. Eskiden buton her hâlde aktifti;
            // kullanıcı yarım formla basıp hata alıyordu.
            //
            // ⚠ METİN: doğrulama gerektiren bir değişiklik (telefon
            // veya e-posta) varsa "Doğrula ve Kaydet", yalnız ad/soyad
            // değiştiyse "Bilgileri Güncelle".
            RefNextButton(
              _dogrulamaGerekli ? 'Doğrula ve Kaydet' : 'Bilgileri Güncelle',
              iconAsset: 'assets/svg/ic_pen.svg',
              busy: _busy,
              onPressed: (_formGecerli && _degisiklikVar) ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// `pfAvatar(104)` + `.pf-cam` — profil fotoğrafı seçici.
// ⚠ `_AvatarSecici` KALDIRILDI: fotoğraf yönetimi yalnız
// Profil ekranındadır.
