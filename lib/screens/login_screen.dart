import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../core/platform_kapilari.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import 'forgot_password_screen.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../ui/web_panel.dart';
import '../data/remote/api_config.dart';
import '../core/teshis.dart';
import '../data/repositories/oturum_tercihi.dart';
import '../ui/panel_rotasi.dart';

/// Giriş — HTML davranışlarının birebir karşılığı:
/// alan-altı hatalar, buton loading + çift tıklama kilidi,
/// kimlik doğrulama (genel hata), 0'sız telefon, test hesabı notu.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass = TextEditingController();

  bool _busy = false;       // lockBtn karşılığı: reentry engeli
  bool _obscure = true;
  // ══════════════════════════════════════════════════════════════
  // İKİ GİRİŞ YOLU — HESAP MODELİ KARARI
  //
  //   E-posta ile Giriş : e-posta + şifre
  //   Telefon ile Giriş : telefon → SMS kodu → doğrulama
  //
  // ⚠ TELEFON + ŞİFRE KOMBİNASYONU ARTIK YOK. Telefonla girişte
  // şifre sorulmaz; sahiplik SMS ile doğrulanır.
  // ══════════════════════════════════════════════════════════════
  /// ⚠ VARSAYILAN AÇILIŞ: TELEFON FORMU.
  ///
  /// Kullanıcıların çoğu numarasını ezbere biliyor; e-posta ikincil
  /// yol. Düğme de bu yüzden "E-posta ile Giriş" yazarak açılır.
  bool _epostaModu = false;

  final _email = TextEditingController();

  /// ── HATA SINIFLARI AYRI ──
  ///
  /// ⚠ İŞ KURALI HATASI VALIDATOR'A GİRMEZ.
  ///
  /// "Telefon numarası veya şifre hatalı" bir ALAN hatası değildir;
  /// hangi alanın yanlış olduğunu söylemez ve söylememelidir. Eskiden
  /// şifre alanının `validator`'ından döndürülüyordu: Flutter onu
  /// FormFieldState içinde tutuyor, alan silinse bile ekranda
  /// kalıyordu.
  ///
  /// Artık form düzeyinde, alanların ÜSTÜNDE tek satırda gösterilir.
  String? _isHatasi;

  /// Ağ/sunucu gibi ALANDAN BAĞIMSIZ hatalar — ayrı sınıf.
  String? _sistemHatasi;

  // ══════════════════════════════════════════════════════════════
  // UYARI ZAMANI — ORTAK KURAL
  //
  // ⚠ BOŞ ALAN UYARI ÜRETMEZ. Kullanıcı bir alanı doldurup silerse
  // ekranda uyarı KALMAZ. Zorunluluk gönderim anında denetlenir —
  // ama zaten düğme boş alan varken PASİFTİR, yani gönderim
  // denenemez.
  // ══════════════════════════════════════════════════════════════

  final FocusNode _fEmail = FocusNode();
  final FocusNode _fPhone = FocusNode();
  final FocusNode _fPass = FocusNode();
  final Set<String> _terkEdilen = {};

  String? _kural(
      String alan, FocusNode odak, String? v, String? Function(String?) asil) {
    if (odak.hasFocus) {
      return null;
    }
    if (!_terkEdilen.contains(alan)) {
      return null;
    }
    if ((v ?? '').trim().isEmpty) {
      return null;
    }
    return asil(v);
  }

  /// ⚠ ZORUNLU ALANLAR DOLU VE GEÇERLİ Mİ?
  ///
  /// Düğme yalnız bu doğruyken aktif olur. Eksik alanla gönderim
  /// denenemediği için "Bu alan zorunludur" uyarısı da hiç çıkmaz.
  ///
  /// ── ⚠ "DOLU" YETMEZ, "GEÇERLİ" ARANIR ──
  ///
  /// Kural eskiden yalnız alanın boş olmadığına bakıyordu. Kullanıcı
  /// e-posta yerine `abc`, telefon yerine `53` yazdığında düğme AKTİF
  /// kalıyor, basınca sunucuya geçersiz istek gidiyordu.
  ///
  /// Aynı ekranın kardeşi olan Şifremi Unuttum'da doğrusu zaten
  /// vardı (`forgot_password_screen` → `_epostaGecerli`); giriş
  /// ekranı o kuralla hizalandı.
  ///
  /// ⚠ ŞİFREDE YALNIZ DOLULUK ARANIR — BİLEREK.
  ///
  /// Şifre kuralı zamanla değişebilir; mevcut kullanıcının eski
  /// şifresi bugünkü kurala uymuyor olabilir. Düğmeyi şifre biçimine
  /// bağlamak o kullanıcıyı kendi hesabından KİLİTLERDİ. Şifrenin
  /// doğruluğuna sunucu karar verir.
  bool get _zorunlularDolu =>
      _pass.text.trim().isNotEmpty &&
      (_epostaModu
          ? Validators.email(_email.text) == null
          : Validators.phone(_phone.text) == null);

  /// ── GİRİŞ KİLİDİ GERİ SAYIMI ──
  ///
  /// ⚠ ESKİDEN SAYI METNE GÖMÜLÜYDU VE DONUYORDU.
  ///
  /// Depo "20 saniye sonra tekrar deneyin" diye BİR metin üretiyor,
  /// ekran onu `_authError` olarak saklıyordu. Metin bir daha
  /// değişmediği için sayı ilerlemiyordu: kullanıcı bekliyor, ekranda
  /// hep aynı saniye yazıyor, yeniden denemeden güncellenmiyordu.
  ///
  /// Artık kalan süre depodan SANİYEDE BİR sorulur ve metin her
  /// saniye yeniden kurulur. Süre bitince uyarı kendiliğinden kalkar.
  int _kilitKalan = 0;
  Timer? _kilitSayaci;

  /// Kilit uyarısı — canlı. Kilit yoksa `null`.
  String? get _kilitMesaji => _kilitKalan > 0
      ? 'Çok fazla hatalı deneme. $_kilitKalan saniye sonra tekrar deneyin.'
      : null;

  /// Kilidi depodan okuyup geri sayımı başlatır/durdurur.
  ///
  /// ⚠ TEK KAYNAK DEPODUR: sayaç yerel olarak azaltılmaz, her tıkta
  /// yeniden SORULUR. Böylece ekran kapanıp açılsa da, uygulama arka
  /// plana alınsa da kalan süre gerçek kalır.
  void _kilidiTazele() {
    if (!mounted) {
      return;
    }
    final kalan = context
        .read<AuthController>()
        .girisKilidiKalan(Validators.phoneFmt(_phone.text));
    if (kalan != _kilitKalan) {
      setState(() => _kilitKalan = kalan);
    }
    if (kalan <= 0) {
      _kilitSayaci?.cancel();
      _kilitSayaci = null;
      return;
    }
    _kilitSayaci ??= Timer.periodic(
        const Duration(seconds: 1), (_) => _kilidiTazele());
  }

  @override
  void initState() {
    super.initState();
    // Alan terk edilince uyarı değerlendirilebilir hâle gelir.
    for (final e in <String, FocusNode>{
      'eposta': _fEmail,
      'telefon': _fPhone,
      'sifre': _fPass,
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
    // ⚠ Kilit ekran yeniden açıldığında da sürer — bkz. aşağıdaki
    // post-frame çağrısı.
    // ⚠ EKRAN YENİDEN AÇILDIĞINDA KİLİT DEVAM EDER.
    //
    // Kilit numaraya aittir ve depoda durur; ekran durumunda değil.
    // Eskiden kilit mesajı yalnız başarısız denemenin dönüşünde
    // üretildiği için ekran kapanıp açılınca kayboluyor ya da eski
    // saniyede donuyordu. Artık ilk karede depodan sorulur.
    WidgetsBinding.instance.addPostFrameCallback((_) => _kilidiTazele());
  }

  /// Kullanıcı alanı düzenlemeye başladı — eski kimlik hatası düşer.
  ///
  /// ⚠ KİLİT MESAJI SİLİNMEZ: o, numaraya uygulanan bir yaptırımdır;
  /// yazı yazmakla kalkmaz. Yalnız "telefon veya şifre hatalı"
  /// uyarısı temizlenir.
  void _degerDegisti() {
    _kimlikHatasiniTemizle();
    // Düğmenin aktifliği alanların doluluğuna bağlı.
    setState(() {});
  }

  void _kimlikHatasiniTemizle() {
    if (_isHatasi == null && _sistemHatasi == null) {
      return;
    }
    setState(() {
      _isHatasi = null;
      _sistemHatasi = null;
    });
  }


  /// GİRİŞ YOLUNU DEĞİŞTİR — hatalar sıfırlanır.
  ///
  /// ⚠ Bir yoldaki hata öteki yolda anlamsızdır; taşınmaz.
  void _moduDegistir(bool eposta) {
    if (_epostaModu == eposta || _busy) {
      return;
    }
    setState(() {
      _epostaModu = eposta;
      _isHatasi = null;
      _sistemHatasi = null;
    });
  }

  /// E-POSTA + ŞİFRE İLE GİRİŞ.
  ///
  /// ⚠ STALE-RESPONSE KORUMASI: gönderim anındaki değerler
  /// KOPYALANIR (`snapshot`) ve `enabled: !_busy` ile alanlar
  /// kilitlenir. Dönen cevap artık değişmiş bir değere yazılamaz.
  Future<void> _submit() async {
    if (_busy) return;                       // çift tıklama koruması
    setState(() {
      _isHatasi = null;
      _sistemHatasi = null;
    });
    if (!_form.currentState!.validate()) {
      return;
    }
    // Gönderim anındaki değerler — sonuç bunlara aittir.
    final epostaAnlik = _email.text;
    final telefonAnlik = Validators.phoneFmt(_phone.text);
    final sifreAnlik = _pass.text;
    setState(() => _busy = true);
    // ⚠ İKİ KİMLİK, TEK YÖNTEM: her ikisinde de ŞİFRE.
    // Gerçek çağrı: sonuç kesinleşmeden başarı gösterilmez.
    final auth = context.read<AuthController>();
    final err = _epostaModu
        ? await auth.girisEposta(epostaAnlik, sifreAnlik)
        : await auth.girisTelefonSifre(telefonAnlik, sifreAnlik);
    if (!mounted) {
      return;
    }
    setState(() { _busy = false; _isHatasi = err; });
    // ⚠ Kilit oluşmuş olabilir: kalan süre depodan okunup canlı
    // geri sayım başlatılır.
    _kilidiTazele();
    if (err == null) {
      // ⚠ TERCİH GİRİŞ BAŞARILI OLUNCA yazılır. Başarısız denemede
      // yazılsaydı cihaz var olmayan bir kullanıcıyı hatırlardı.
      //
      // ⚠ BEKLENMEZ (`unawaited`).
      //
      // Disk yazımı giriş akışını GECİKTİRMEMELİ: kullanıcı doğru
      // şifreyi girdi, karşılığında hemen paneline gitmeli. Tercih
      // kaydı arka planda tamamlanır.
      //
      // Güvenli: `OturumTercihi` context KULLANMAZ ve hataları kendi
      // içinde yutar (bkz. sınıf belgesi). Widget kalksa bile yazım
      // sürer, sürmezse de giriş etkilenmez.
      // ⚠ SNAPSHOT KULLANILIR: istek sonrası denetleyici değerinin
      // değişmiş olabileceği varsayılır.
      //
      // ⚠ ARTIK KOŞULSUZ — "Beni Hatırla" kutucuğu KALDIRILDI (ürün
      // kararı): cihaz HER girişte otomatik hatırlar, kayıt akışıyla
      // (bkz. `register_screen.dart`) AYNI davranış. Kullanıcı
      // "hatırlama" DEMEK isterse çıkış yaparak bunu geri alabilir
      // (`AuthController.logout` zaten `OturumTercihi().temizle()`
      // çağırır).
      unawaited(
          OturumTercihi().kaydet(_epostaModu ? epostaAnlik : telefonAnlik));

      sysToastOk(context, 'Hoş geldiniz! Giriş yapıldı');
      _girisSonrasiYonlendir();
    }
    // ⚠ `_form.validate()` ÇAĞRILMAZ: iş kuralı hatası artık
    // validator'dan gelmiyor, form düzeyinde gösteriliyor.
    _kilidiTazele();
  }



  /// BAŞARILI GİRİŞ SONRASI YÖNLENDİRME
  ///
  /// Referans `loginSubmit()` akışı:
  ///   1. hesap doğrulanır      → `CUR_ACC = acc`
  ///   2. toast gösterilir      → 'Hoş geldiniz! Giriş yapıldı ✓'
  ///   3. oturum işaretlenir    → `LOGGED = true`
  ///   4. panel rolü belirlenir → `MODE = acc.role`
  ///   5. 450 ms sonra          → `navigate('cust')`
  ///
  /// `vCust` rol duyarlıdır (`custTabsHTML`):
  ///   provider → "Yeni işler" / "Kazandığım işler"
  ///   customer → "Açık işler" / "Tamamlanan işler" / "Süresi dolan işler"
  ///
  /// Flutter karşılığı: hizmet veren `JobsScreen`, müşteri
  /// `MyListingsScreen`.
  ///
  /// ⚠ `maybePop()` KULLANILMAZ: giriş ekranı yığının kökündeyse
  /// (örn. oturum düşmesi sonrası `pushNamedAndRemoveUntil('/login')`)
  /// hiçbir şey yapmaz ve kullanıcı giriş ekranında kalır.
  /// Bunun yerine panel ekranı yığının kökü yapılır.
  void _girisSonrasiYonlendir() {
    final rol = context.read<AuthController>().activeRole;
    final hedef = rol == Role.provider
        ? '/provider/jobs'
        : '/customer/listings';
    Navigator.of(context).pushNamedAndRemoveUntil(hedef, (r) => false);
  }


  // ═════════════════════════════════════════════════════════════
  // GÖRÜNÜM — referans `vLogin` (hizmetcep-v66-final__1_.html)
  //
  //   .rg-back   geri düğmesi (sol üst)
  //   .rg-wrap   padding:2px 20px 36px · .lg-wrap padding-top:6px
  //   .lg-ico    74×74 daire, #EAF1FB, IC_PROFILE
  //   .rg-title  25px/700 #16233D, ls -.3, margin:4px 0 8px
  //   .rg-sub    14.5px #5B6472, lh1.45, margin:0 6px 22px
  //   .rg-f      telefon (IC_PHONE_F + .lg-cc "+90")
  //   .rg-f      şifre  (IC_LOCK + .rg-eye göz düğmesi)
  //   .rg-infobox.blue  test girişi bilgisi, margin:2px 0 4px
  //   .lg-forgot 13px/700 #1D6BE3, sağa yaslı, margin:2px 2px 14px auto
  //   .rg-primary "Giriş Yap"
  //   .rg-or     "veya"
  //   .rg-google "Google ile Devam Et"
  //   .lg-reg    "Hesabınız yok mu? Kayıt Olun"
  // ═════════════════════════════════════════════════════════════
  @override
  void dispose() {
    _kilitSayaci?.cancel();
    _phone.dispose();
    _fEmail.dispose();
    _fPhone.dispose();
    _fPass.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// Giriş formu — TEK KAYNAK.
  ///
  /// ⚠ Tam gövde (mobil) ve panel (web) AYNI widget'ı kullanır.
  Widget _formu(BuildContext context) => Form(
                    // ⚠ ORTAK UYARI ZAMANI KURALI (tüm formlarda aynı).
                    //
                    //   · alan odaktayken       → uyarı YOK
                    //   · alan hiç terk edilmemişse → uyarı YOK
                    //   · alan BOŞ              → uyarı YOK
                    //   · dolu ama geçersiz + terk edilmiş → UYARI
                    //
                    // Kararı `_kural` verir; çerçeveye bırakılmaz.
                    autovalidateMode: AutovalidateMode.always,
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // .lg-ico{margin:6px auto 14px}
                        const SizedBox(height: 6),
                        const Center(
                          // .lg-ico{color:#1D6BE3} · svg 40×40
                          child: RefScreenIcon(
                            asset: 'assets/svg/ic_profile.svg',
                          ),
                        ),
                        const SizedBox(height: 14),

                        // .rg-title{margin:4px 0 8px}
                        const SizedBox(height: 4),
                        Text(
                          'Giriş Yap',
                          textAlign: TextAlign.center,
                          style: refText(
                            size: RF.s25,
                            weight: RF.w700,
                            color: RC.text,
                            letterSpacing: RF.lsM03,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // .rg-sub{margin:0 6px 22px}
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'HizmetCep hesabınıza giriş yaparak kaldığınız '
                            'yerden devam edin.',
                            textAlign: TextAlign.center,
                            style: refText(
                              size: RF.s145,
                              weight: RF.w400,
                              color: RC.textSoft,
                              height: RF.lh145,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ══════════════════════════════════════════
                        // GİRİŞ YOLU — TEK GEÇİŞ DÜĞMESİ
                        //
                        _GirisYoluDegistir(
                          etiket: _epostaModu
                              ? 'Telefon ile Giriş'
                              : 'E-posta ile Giriş',
                          onTap: () => _moduDegistir(!_epostaModu),
                        ),
                        const SizedBox(height: 16),

                        // ── FORM DÜZEYİNDE HATA ──
                        //
                        // ⚠ İŞ KURALI VE SİSTEM HATASI ALAN ALTINDA
                        // GÖSTERİLMEZ. "Telefon numarası veya şifre
                        // hatalı" hangi alanın yanlış olduğunu
                        // söylemez; sistem hatası ise hiçbir alanın
                        // değerinden kaynaklanmaz.
                        if (_kilitMesaji != null ||
                            _isHatasi != null ||
                            _sistemHatasi != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              // ⚠ SIRA: kilit > iş kuralı > sistem.
                              // Kilit varken öteki mesajlar anlamsız.
                              _kilitMesaji ?? _isHatasi ?? _sistemHatasi!,
                              style: refText(
                                  size: RF.s135,
                                  weight: RF.w600,
                                  color: RC.danger),
                            ),
                          ),

                        // ── E-posta (yalnız e-posta modunda) ──
                        if (_epostaModu)
                          RefFormField(
                            // ⚠ AYRI KİMLİK — KLAVYE TÜRÜ KARIŞMASIN.
                            //
                            // İki alan Column'da AYNI konumda ve aynı
                            // tipte. Anahtar verilmezse Flutter mod
                            // değişince eski Element'i YENİDEN
                            // KULLANIYOR: e-posta alanı çiziliyor ama
                            // altındaki metin girişi telefon
                            // klavyesiyle açık kalıyordu (`* #`, `+`
                            // tuşları; `@` yok).
                            //
                            // Anahtar farklı olunca Element yeniden
                            // kurulur ve `keyboardType` doğru uygulanır.
                            key: const ValueKey('giris-eposta'),
                            iconAsset: 'assets/svg/ic_mail.svg',
                            controller: _email,
                            onChanged: (_) => _degerDegisti(),
                            enabled: !_busy,
                            hint: 'E-posta',
                            yerTutucu: 'E posta giriniz.',
                            keyboardType: TextInputType.emailAddress,
                  // ⚠ E-postada baş harf büyütülmez.
                  textCapitalization: TextCapitalization.none,
                            textInputAction: TextInputAction.next,
                            focusNode: _fEmail,
                            validator: (v) =>
                                _kural('eposta', _fEmail, v, Validators.email),
                          ),

                        // ── Telefon (yalnız telefon modunda) ──
                        if (!_epostaModu)
                        RefFormField(
                          // ⚠ Ayrı kimlik — bkz. e-posta alanındaki not.
                          key: const ValueKey('giris-telefon'),
                          iconAsset: 'assets/svg/ic_phone_f.svg',
                          controller: _phone,
                          // ⚠ DEĞER DEĞİŞİNCE ESKİ HATA DÜŞER.
                          //
                          // "Telefon veya şifre hatalı" DENENEN
                          // değerlere aittir; kullanıcı düzeltmeye
                          // başlayınca geçerliliğini yitirir. Eskiden
                          // alan tamamen silinse bile ekranda ASILI
                          // KALIYORDU.
                          //
                          // ⚠ Kilit mesajı bundan ETKİLENMEZ: kilit
                          // numaraya aittir, yazıyla kalkmaz.
                          onChanged: (_) => _degerDegisti(),
                          enabled: !_busy,
                          // ⚠ "5XX XXX XX XX" BİÇİM ÖRNEĞİDİR, alan adı değil:
                      // etikette "Telefon" yazar, kutunun içinde biçim
                      // ipucu kalır.
                      // ⚠ `hint` ZORUNLU PARAMETRE: `RefFormField`
                      // etiket verilmediğinde onu kullanır. Burada
                      // etiket ayrıca veriliyor ama parametre yine de
                      // dolu olmalı — aksi hâlde derleme kırılır.
                      hint: 'Telefon',
                      etiket: 'Telefon',
                      yerTutucu: '5XX XXX XX XX',
                          keyboardType: TextInputType.phone,
                          // ⚠ DİĞER EKRANLARLA AYNI KURAL.
                          //
                          // Sınır 10 idi: `0` ile başlayan 11 haneli
                          // numara YAZILAMIYORDU. Artık otomatik `0`
                          // eklenir ve sınır `kPhoneLocalMaxLength`.
                          inputFormatters: const [
                            TelefonBicimlendirici()
                          ],
                          textInputAction: TextInputAction.next,
                          focusNode: _fPhone,
                          validator: (v) =>
                              _kural('telefon', _fPhone, v, Validators.phone),
                        ),

                        // ── Şifre — HER İKİ MODDA DA ──
                        //
                        // ⚠ KARAR GÜNCELLENDİ: telefonla giriş de
                        // şifreyle yapılır. SMS OTP giriş anahtarı
                        // değildir; yalnız kayıt, numara değişikliği
                        // ve hesap kurtarmada sahiplik doğrular.
                        RefFormField(
                          iconAsset: 'assets/svg/ic_lock.svg',
                          controller: _pass,
                          // ⚠ Değer değişince eski kimlik hatası düşer.
                          onChanged: (_) => _degerDegisti(),
                          // ⚠ İSTEK SÜRERKEN ALAN KİLİTLİ: dönen cevap
                          // artık değişmiş bir değere yazılamaz.
                          enabled: !_busy,
                          // ⚠ ÜRÜN KURALI: şifrenin TEK koşulu en az
                          // `kPasswordMinLength` karakter olmasıdır.
                          // Üst sınır ve içerik zorunluluğu YOKTUR.
                          hint: 'Şifre',
                          yerTutucu: 'Şifre giriniz.',
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          // ⚠ VALIDATOR YALNIZ ALAN KURALINI DENETLER.
                          //
                          // İş kuralı hatası ("telefon veya şifre
                          // hatalı") ve kilit mesajı buradan
                          // DÖNDÜRÜLMEZ; ikisi de form düzeyinde
                          // gösterilir. Eskiden validator'dan
                          // dönüyorlardı ve FormFieldState içinde
                          // takılı kalıyorlardı.
                          //
                          // ⚠ GİRİŞTE üst sınır uygulanmaz: eski uzun
                          // şifreli hesaplar kilitlenmemeli.
                          focusNode: _fPass,
                          validator: (v) => _kural(
                              'sifre', _fPass, v, Validators.loginPassword),
                          // Basılı tutulduğu sürece gösterir.
                          suffix: RefSifreGozu(
                            gizli: _obscure,
                            onDegisti: (g) => setState(() => _obscure = g),
                          ),
                        ),

                        // .lg-forgot{margin:2px 2px 14px auto} — sağa yaslı
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 2, bottom: 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: RefTap(
                              onTap: _busy
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        panelRotasi<void>(
                                          // ⚠ AD YALNIZ ÖLÇÜ İÇİN:
                                          // web kabuğu içerik
                                          // genişliğini rota adından
                                          // seçer. Gezinme davranışı
                                          // DEĞİŞMEZ.
                                          settings: const RouteSettings(
                                              name: '/sifremi-unuttum'),
                                          builder: (_) =>
                                              // ── ⚠ HER ZAMAN E-POSTA
                                              // YOLUYLA AÇILIR ──
                                              //
                                              // Bir tur giriş moduna
                                              // bağlanmıştı (telefon
                                              // modundan gelen telefon
                                              // formunu görüyordu).
                                              // Ürün kararı geri aldı:
                                              // ANA YOL E-POSTADIR,
                                              // telefon doğrulama
                                              // ekranın içindeki
                                              // seçenekten açılır.
                                              const ForgotPasswordScreen(),
                                        ),
                                      ),
                              borderRadius: BorderRadius.circular(RR.r8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 2),
                                child: Text(
                                  'Şifremi Unuttum',
                                  style: refText(
                                    size: RF.s13,
                                    weight: RF.w700,
                                    color: RC.blue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // .rg-primary
                        RefPrimaryButton(
                          // ⚠ TEK EYLEM: iki modda da GİRİŞ.
                          'Giriş Yap',
                          busy: _busy,
                          // ⚠ EKSİK ALAN VARKEN PASİF.
                          //
                          // Zorunlu alanların hepsi dolmadan gönderim
                          // denenemez; bu yüzden "Bu alan zorunludur"
                          // uyarısı da hiç çıkmaz.
                          onPressed: (!_zorunlularDolu)
                              ? null
                              : _submit,
                        ),

                        // .rg-or + .rg-google
                        //
                        // ⚠ iOS'TA GÖSTERİLMEZ (App Store kuralı 4.8 —
                        // bkz. lib/core/platform_kapilari.dart).
                        // Ayırıcı ile düğme BİRLİKTE gizlenir; yalnız
                        // düğme kaldırılsaydı ekranda sahipsiz bir
                        // "veya" çizgisi kalırdı.
                        //
                        // ⚠ ANDROID'DE HİÇBİR ŞEY DEĞİŞMEZ: düğme,
                        // ikonu, ölçüsü, sırası ve davranışı aynen
                        // buradadır.

                        // .lg-reg{margin-top:16px}
                        const SizedBox(height: 16),
                        Center(
                          child: RefTap(
                            onTap: _busy
                                ? null
                                // ⚠ `pushReplacement` DEĞİL `push`:
                                // önceki hâlde giriş ekranı yığından
                                // SİLİNİYORDU, bu yüzden rol
                                // seçimindeki geri oku giriş yerine
                                // ana sayfaya düşüyordu. Kullanıcı
                                // "hesabım varmış" deyip geri
                                // dönebilmeli.
                                : () =>
                                    Navigator.pushNamed(context, '/role'),
                            borderRadius: BorderRadius.circular(RR.r8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 6),
                              child: RichText(
                                text: TextSpan(
                                  style: refText(
                                    size: RF.s135,
                                    weight: RF.w400,
                                    color: RC.textSoft,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Hesabınız yok mu? '),
                                    TextSpan(
                                      text: 'Kayıt Olun',
                                      style: refText(
                                        size: RF.s135,
                                        weight: RF.w800,
                                        color: RC.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

  @override
  Widget build(BuildContext context) => Scaffold(
        // `.page{background:#fff}` — referansta AppBar YOKTUR.
                // ⚠ PANELDE ZEMİN SAYDAM: `Scaffold` beyaz boyadığı için
        // şeffaf rotanın altındaki sayfa ÖRTÜLÜYORDU — modalın arkası
        // boş beyaz görünüyordu. Panelde zemin saydam olur, karartma
        // ve bulanıklık altındaki gerçek sayfaya düşer.
        //
        // ⚠ MOBİLDE DEĞİŞMEZ: `panelMi` yalnız web'de true.
        backgroundColor:
            WebPanel.panelMi(context) ? Colors.transparent : RC.pageBg,
        body: WebPanel(
        // ⚠ MASAÜSTÜ WEB PANELİ — ortak bileşen
        // (`ui/web_panel.dart`). Mobilde ve <1024 px'te gövdeyi
        // OLDUĞU GİBİ döndürür; bu ekranın kendi Scaffold /
        // RefScroll / adım yapısı değişmedi.
        //
        // ⚠ GÖVDENİN TAMAMI SARILIR: çok adımlı akışlarda
        // yalnız ilk adım değil, tüm gövde panelin içindedir.
        // ── ⚠ PANELDE SADECE FORM ÇİZİLİR ──
        //
        // Tam gövde `SafeArea > Column > Expanded > RefScroll`
        // biçiminde ve `Expanded` ALANI DOLDURUR; panel onu sardığında
        // kart içeriğe göre büzülemiyor, altta kocaman boşluk
        // kalıyordu. Oysa modal, içeriği kadar kısa olmalıdır.
        //
        // `panelIcerik` ile panele `Expanded` İÇERMEYEN sade form
        // verilir: kart içerik kadar yüksek olur, uzun formda yalnız
        // bu bölüm kayar.
        //
        // ⚠ AYNI WIDGET İKİ KEZ KURULMAZ: `_formu(context)` tek
        // kaynaktır; tam gövde de panel de onu çağırır. Kopyalasaydım
        // biri düzeltilip öteki unutulurdu.
        panelIcerik: _formu(context),
        icerik: SafeArea(
          child: Column(
            children: [
              // .rg-back — sol üstte, başlık çubuğu olmadan
              //
              // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar).
              // Giriş ekranı ana sayfadan açılır; kullanıcının vazgeçip
              // dönebilmesi gerekir. Android'de donanım tuşu vardı ama
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RefBackButton(),
                ),
              ),
              Expanded(
                child: RefScroll(
                  // .rg-wrap{padding:2px 20px 36px} + .lg-wrap{padding-top:6px}
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  child: _formu(context),
                ),
              ),
            ],
          ),
        )),
      );
}

/// GİRİŞ YOLU DEĞİŞTİRME — TEK DÜĞME.
///
/// ⚠ SEÇİLİ/SEÇİLİ DEĞİL DURUMU YOKTUR. Düğme tek bir eylemdir:
/// "öteki yola geç". Bulunulan yol formdan zaten anlaşılır.
///
/// ⚠ İKİNCİL GÖRÜNÜM: birincil eylem "Giriş Yap"tır. Bu düğme
/// çerçeveli ve beyaz zeminli; mavi dolu düğmeyle yarışmaz.
///
/// ⚠ Yeni tasarım dili ÜRETİLMEDİ: mevcut tasarım sisteminin renk,
/// yarıçap ve tipografi belirteçleri kullanılır.
class _GirisYoluDegistir extends StatelessWidget {
  const _GirisYoluDegistir({required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.r12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RC.white,
            border: Border.all(color: RC.border),
            borderRadius: BorderRadius.circular(RR.r12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const RefSvg('assets/svg/ic_pswap.svg',
                  size: 16, color: RC.blue),
              const SizedBox(width: 8),
              Text(
                etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: refText(
                  size: RF.s135,
                  weight: RF.w700,
                  color: RC.blue,
                ),
              ),
            ],
          ),
        ),
      );
}
