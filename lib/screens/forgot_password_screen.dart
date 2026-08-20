import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/geri.dart';
import '../core/telefon_bicimi.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../domain/form_mesajlari.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'otp_screen.dart';
import 'yeni_sifre_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// ŞİFREMİ UNUTTUM
///
/// ## ANA YOL: E-POSTA
///
/// E-posta → güvenli şifre yenileme bağlantısı → Yeni Şifre Belirle.
///
/// ⚠ EKRAN TELEFON AĞIRLIKLI DEĞİLDİR. Önceki tasarım telefon + SMS
/// OTP üzerineydi; hesap modeli kararıyla değişti. SMS OTP artık
/// yalnız ALTERNATİF kurtarma yolunda kullanılır.
///
/// ## ALTERNATİF: "E-posta adresime erişemiyorum"
///
/// Telefon → SMS kodu → telefon sahipliği doğrulanır → kısa ömürlü
/// KURTARMA YETKİSİ → Yeni Şifre Belirle.
///
/// ⚠ OTP OTURUM AÇMAZ. Kod yalnız telefonun kullanıcıya ait
/// olduğunu söyler; şifre değiştirme yetkisi ayrı ve sürelidir.
///
/// ## HESAP ENUMERATION YOK (K5)
///
/// ⚠ Hesap bulunsa da bulunmasa da AYNI nötr cevap verilir. "Bu
/// e-posta kayıtlı değil" ya da "Sisteme kayıtlı bir numara giriniz"
/// gibi bir uyarı BU EKRANDA YOKTUR.
/// ═══════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  // ⚠ `telefonYolu` PARAMETRESİ KALDIRILDI (ürün kararı).
  //
  // Bir tur giriş moduna bağlanmıştı: telefon modundan gelen
  // kullanıcı doğrudan telefon formunu görüyordu. Karar geri alındı —
  // ekran HER ZAMAN e-posta formuyla açılır, telefon doğrulama
  // ekranın içindeki "E-posta adresime erişemiyorum" seçeneğinden
  // ulaşılır.

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _fEmail = FocusNode();
  final _fPhone = FocusNode();

  /// Alternatif yol açık mı?
  ///
  /// ⚠ HER ZAMAN KAPALI BAŞLAR. Ana yol e-postadır; telefon
  /// doğrulaması ancak kullanıcı "E-posta adresime erişemiyorum"
  /// dediğinde açılır.
  bool _telefonYolu = false;

  bool _busy = false;

  /// Nötr başarı bildirimi — hesap var/yok bilgisi taşımaz.
  bool _gonderildi = false;

  /// Ağ/sunucu hatası — alan hatası DEĞİL, form düzeyinde.
  String? _sistemHatasi;

  /// Uyarı zamanı kuralı — öteki formlarla AYNI.
  final Set<String> _terkEdilen = {};
  bool _gonderimAninda = false;

  @override
  void initState() {
    super.initState();
    for (final e in <String, FocusNode>{
      'eposta': _fEmail,
      'telefon': _fPhone,
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
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _fEmail.dispose();
    _fPhone.dispose();
    super.dispose();
  }

  /// ⚠ YAZARKEN UYARI YOK — ortak form standardı.
  String? _kural(
      String alan, FocusNode odak, String? v, String? Function(String?) asil) {
    if (!_gonderimAninda) {
      if (odak.hasFocus) {
        return null;
      }
      if (!_terkEdilen.contains(alan)) {
        return null;
      }
      // ⚠ TRIM ŞART: düğme aktifliği `trim()` ile ölçülüyor. Kapı
      // trim etmezse yalnız boşluk içeren alan "dolu" sayılıp uyarı
      // üretir ama düğme yine pasif kalır — iki ölçü ayrışır.
      if ((v ?? '').trim().isEmpty) {
        return null;
      }
    }
    return asil(v);
  }

  /// ── ⚠ KAYITSIZ NUMARA DENETİMİ KALDIRILDI — GÜVENLİK KARARI ──
  ///
  /// Eskiden burada `_kayitsizNumaralar` kümesi tutuluyor, numara tam
  /// yazılınca depoya "bu numara kayıtlı mı" diye soruluyor ve
  /// kayıtsızsa uyarı gösterilip düğme kilitleniyordu.
  ///
  /// Bu, HESAP SAYIMINA (enumeration) açık kapı bırakıyordu:
  /// saldırgan numara deneyerek hangi numaraların sistemde kayıtlı
  /// olduğunu öğrenebiliyordu. Uyarıyı düğmeden alan altına taşımak
  /// da çözmez — sızdıran şey uyarının YERİ değil, cevabın kayıtlı ve
  /// kayıtsız numarada FARKLI olmasıdır.
  ///
  /// ⚠ YENİ KURAL: numara biçim olarak geçerliyse düğme aktiftir,
  /// kod isteği gönderilir ve HER DURUMDA aynı nötr metin gösterilir
  /// (`FormMesaj.kodGonderildiNotr`). Kayıtlıysa kod gider, değilse
  /// gitmez; ekranda fark görünmez.
  ///
  /// E-posta yolu bu ilkeyi zaten uyguluyordu; telefon yolu ona
  /// hizalandı. Kilit: test/kurtarma_ve_korunan_davranislar_test.dart

  /// Numara TAM mı? (10 hane, `5` ile başlar)
  bool get _telefonTam => Validators.phone(_phone.text) == null;

  /// ── ⚠ NUMARA DEĞİŞTİ ──
  ///
  /// Numaranın son bilinen GEÇERLİLİK durumu.
  ///
  /// ⚠ DÜĞMENİN AÇILMAMA HATASININ KÖKÜ BUYDU.
  ///
  /// Düğme `_zorunluDolu` üzerinden `_phone.text`e bakar; ama metin
  /// değiştiğinde ekran yeniden çizilmezse düğme ilk kurulduğu andaki
  /// hâlinde (alan boş → pasif) kalır. W2-2'de `setState` koşullu
  /// yapılmıştı ve tetikleyici kayıtsızlık denetimiydi; o denetim
  /// güvenlik gerekçesiyle kaldırılınca geriye TETİKLEYİCİ KALMADI.
  ///
  /// ⚠ ÇÖZÜM HER TUŞTA ÇİZMEK DEĞİL: geçerlilik DÖNDÜĞÜNDE çizilir
  /// (10. hane girilince ya da bir hane silinip geçersizleşince).
  /// Böylece hızlı yazımdaki IME sorununu büyüten "her tuşta tüm
  /// ekranı çiz" davranışı geri gelmez.
  bool _sonTelefonGecerli = false;

  /// ⚠ KAYIT DENETİMİ BURADAN KALDIRILDI (enumeration).
  ///
  /// Eskiden numara tamamlandığı anda depoya "bu numara kayıtlı mı"
  /// diye soruluyordu. Sorgunun kendisi sızıntının kaynağıydı:
  /// cevabı ekrana yansıyan her yol, saldırgana numara deneyerek
  /// hesap varlığını öğrenme imkânı verir.
  ///
  /// ⚠ Numara biçim olarak geçerliyse düğme AÇILIR; kayıtlı olup
  /// olmadığına BAKILMAZ. Kayıtlılık farkı yalnız kodun gerçekten
  /// gönderilip gönderilmediğinde ortaya çıkar ve ekranda görünmez.
  void _telefonDegisti() {
    var degisti = false;

    // ── GEÇERLİLİK DÖNDÜ MÜ ──
    final gecerli = _telefonTam;
    if (gecerli != _sonTelefonGecerli) {
      _sonTelefonGecerli = gecerli;
      degisti = true;
    }

    // Sistem hatası ekranda duruyorsa yazmaya başlayınca temizlenir.
    if (_sistemHatasi != null) {
      _sistemHatasi = null;
      degisti = true;
    }
    if (degisti) {
      setState(() {});
    }
  }

  /// ⚠ ZORUNLU ALAN DOLU MU? Düğme yalnız o zaman aktif olur.
  ///
  /// Telefon yolunda üç koşul birden aranır: alan dolu · numara TAM ·
  /// numara kayıtsız DEĞİL. Kayıtsız numarayla kod istenemez.
  /// ── ⚠ E-POSTA YOLUNDA "DOLU" YETMEZ, "GEÇERLİ" ARANIR ──
  ///
  /// Düğme yalnız alan boş değil diye aktif oluyordu; kullanıcı
  /// adresin yarısını yazınca da basılabiliyordu. Artık `Validators.
  /// email` geçmeden aktif olmaz.
  ///
  /// ⚠ UZANTI LİSTESİ TUTULMUYOR. Dünyada 1500'den fazla üst düzey
  /// alan adı var; liste tutmak gerçek adresleri reddeder. Bunun
  /// yerine BİÇİM denetleniyor: kullanıcı adı, @, alan adı ve en az
  /// iki harflik uzantı. Doğrulayıcı ayrıca yaygın sağlayıcılara
  /// benzeyen yanlış yazımları (gmial, hotmial) yakalıyor.
  bool get _epostaGecerli => Validators.email(_email.text) == null;

  bool get _zorunluDolu => _telefonYolu
      ? (_phone.text.trim().isNotEmpty && _telefonTam)
      : _epostaGecerli;

  bool _denetle() {
    _terkEdilen.addAll(const ['eposta', 'telefon']);
    _gonderimAninda = true;
    final ok = _form.currentState!.validate();
    _gonderimAninda = false;
    setState(() {});
    return ok;
  }

  /// ANA YOL — e-postaya şifre yenileme bağlantısı.
  Future<void> _baglantiGonder() async {
    if (_busy) {
      return;
    }
    setState(() {
      _sistemHatasi = null;
      _gonderildi = false;
    });
    if (!_denetle()) {
      return;
    }
    setState(() => _busy = true);
    final hata =
        await context.read<AuthController>().sifreSifirlamaIste(_email.text);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (hata != null) {
      // ⚠ SAHTE BAŞARI YOK.
      //
      // Sunucu isteği kabul etmediyse (uç yok, ağ, zaman aşımı)
      // kullanıcıya e-posta GİTMİŞ İZLENİMİ VERİLMEZ. Nötr başarı
      // metni yalnız istek gerçekten kabul edildiğinde gösterilir.
      setState(() => _sistemHatasi = hata);
      return;
    }
    setState(() {
      // ⚠ NÖTR: hesap bulunsa da bulunmasa da aynı metin (K5).
      _gonderildi = true;
    });
  }

  /// ALTERNATİF YOL — telefon sahipliği doğrulama.
  Future<void> _telefonKodIste() async {
    if (_busy) {
      return;
    }
    // Önceki denemenin nötr kutusu kalmasın; yeni sonuç bekleniyor.
    setState(() {
      _sistemHatasi = null;
      _gonderildi = false;
    });
    if (!_denetle()) {
      return;
    }
    final telefonAnlik = Validators.phoneFmt(_phone.text);
    setState(() => _busy = true);
    var ch = await context
        .read<AuthController>()
        .hesapKurtarmaKodGonder(telefonAnlik);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (ch.challengeId.isEmpty) {
      setState(() => _sistemHatasi = FormMesaj.otpGonderilemedi);
      return;
    }
    // ⚠ KAYITSIZSA DA DOĞRULAMA ADIMINA GEÇİLİR — BİLEREK.
    //
    // Eskiden burada "numara kayıtlı değil" denip akış durduruluyordu.
    // Durmanın kendisi bilgi sızdırıyordu: kayıtlı numarada ekran
    // ilerliyor, kayıtsızda ilerlemiyordu. Saldırgan için bu, evet/hayır
    // cevabı vermekle aynı şeydir.
    //
    // Artık iki durumda da AYNI adıma geçilir. Kayıtsız numaraya kod
    // GİTMEZ; kullanıcı kodu giremez ve doğrulama başarısız olur —
    // ama bu bilgi kayıt durumunu ele vermez, yanlış kod girmekten
    // ayırt edilemez.
    //
    // ⚠ NÖTR KUTU BU YOLDA GÖSTERİLMEZ: doğrulama ekranı zaten
    // açılıyor. Kodun gelmemesi durumunda yönlendirme o ekrandaki
    // "Numaranızın doğru olduğundan emin olun" satırıyla yapılır.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: telefonAnlik,
          purpose: OtpPurpose.hesapKurtarma,
          // ⚠ EKRAN KODU DOĞRULAMAZ. Sonucu use-case verir ve
          // başarıda KURTARMA YETKİSİ döner — oturum AÇILMAZ.
          dogrula: (kod) async {
            final d = await context
                .read<AuthController>()
                .hesapKurtarmaDogrula(ch.challengeId, kod);
            _kurtarmaYetkisi = d.yetki;
            return d.hata;
          },
          // ⚠ AKIŞA ÖZEL: yeni KURTARMA challenge'ı üretilir.
          yenidenGonder: () async {
            ch = await context
                .read<AuthController>()
                .hesapKurtarmaKodGonder(telefonAnlik);
            return ch.challengeId.isEmpty
                ? FormMesaj.otpGonderilemedi
                : null;
          },
          onVerified: (otpContext, _) {
            Navigator.pop(otpContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    YeniSifreScreen(kurtarmaYetkisi: _kurtarmaYetkisi),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Doğrulamadan dönen kısa ömürlü kurtarma yetkisi.
  String? _kurtarmaYetkisi;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: RefScroll(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.always,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RefBackButton(onTap: () => geriGit(context)),
                  ),
                  const SizedBox(height: 6),
                  const RefPageTitle('Şifremi Unuttum', geriDugmesi: false),
                  RefSubtitle(_telefonYolu
                      ? 'Telefon numaranızı doğrulayarak yeni şifre '
                          'belirleyebilirsiniz.'
                      : 'Hesabınıza kayıtlı e-posta adresinizi girin. '
                          'Şifrenizi yenilemeniz için size güvenli bir '
                          'bağlantı göndereceğiz.'),
                  const SizedBox(height: 12),

                  // Sistem hatası — alan altında DEĞİL.
                  if (_sistemHatasi != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _sistemHatasi!,
                        style: refText(
                            size: RF.s135,
                            weight: RF.w600,
                            color: RC.danger),
                      ),
                    ),

                  // ⚠ NÖTR BAŞARI KUTUSU — İKİ YOLDA DA AYNI YERDE.
                  //
                  // Kutu dalların DIŞINDADIR: e-posta ve telefon
                  // yollarında aynı konumda, aynı biçimde görünür.
                  // Metin hesap bulunsa da bulunmasa da DEĞİŞMEZ;
                  // fark yalnız hangi kanaldan söz edildiğidir.
                  //
                  // ⚠ İçeriği kayıt durumuna göre DEĞİŞTİRMEYİN:
                  // farklı iki cevap, hesap sayımına (enumeration)
                  // kapı açar.
                  // ⚠ KUTU YALNIZ E-POSTA YOLUNDA GÖSTERİLİR.
                  //
                  // Telefon yolunda kod istendiğinde DOĞRULAMA EKRANI
                  // açılıyor; kullanıcı isteğin gittiğini oradan zaten
                  // görüyor. Kutu hem gereksizdi hem de doğrulamadan
                  // geri dönülüp numara değiştirilince ekranda kalıp
                  // YANILTIYORDU: gönderilmemiş bir kod için
                  // "gönderildi" diyordu.
                  //
                  // E-posta yolunda ise başka geri bildirim YOK; kutu
                  // kalır. K5 gereği metin, adres kayıtlı olsun ya da
                  // olmasın AYNIDIR.
                  if (_gonderildi && !_telefonYolu)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: RefInfoBox(
                        mavi: true,
                        child: Text(
                          FormMesaj.sifirlamaGonderildi,
                          style: refText(
                              size: RF.s135,
                              weight: RF.w400,
                              color: RC.textDark,
                              height: RF.lh150),
                        ),
                      ),
                    ),

                  if (!_telefonYolu) ...[
                    RefFormField(
                      // ⚠ AYRI KİMLİK — KLAVYE TÜRÜ KARIŞMASIN.
                      //
                      // İki alan aynı konumda ve aynı tipte; anahtar
                      // verilmezse Flutter yol değişince eski
                      // Element'i yeniden kullanıyor ve e-posta alanı
                      // TELEFON klavyesiyle açılıyor.
                      key: const ValueKey('kurtarma-eposta'),
                      iconAsset: 'assets/svg/ic_mail.svg',
                      controller: _email,
                      focusNode: _fEmail,
                      enabled: !_busy,
                      hint: 'E-posta',
                      keyboardType: TextInputType.emailAddress,
                  // ⚠ E-postada baş harf büyütülmez.
                  textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                      // ⚠ ADRES DEĞİŞİNCE NÖTR KUTU KALKAR.
                      //
                      // Kutu eski adres için gönderilen isteğe aitti;
                      // yeni adres yazılırken ekranda kalması
                      // yanıltıcı olur.
                      onChanged: (_) => setState(() => _gonderildi = false),
                      validator: (v) =>
                          _kural('eposta', _fEmail, v, Validators.email),
                    ),
                    const SizedBox(height: 14),

                    RefPrimaryButton(
                      'Şifre Yenileme Bağlantısı Gönder',
                      busy: _busy,
                      // ⚠ Alan boşken PASİF — zorunluluk uyarısı
                      // hiç çıkmaz.
                      onPressed: _zorunluDolu ? _baglantiGonder : null,
                    ),
                    const SizedBox(height: 14),

                    // ── ALTERNATİF YOLA GEÇİŞ ──
                    //
                    // ⚠ Bu bir ikinci ana yol DEĞİLDİR: e-postasına
                    // erişemeyen kullanıcı için çıkış kapısıdır.
                    Center(
                      child: RefTap(
                        onTap: () => setState(() {
                          _telefonYolu = true;
                          _gonderildi = false;
                          // ⚠ Telefon yoluna geçerken geçerlilik
                          // izleyicisi alanın GERÇEK durumuyla
                          // eşitlenir; yoksa ilk tuşta düğme
                          // yanlış tarafa dönebilir.
                          _sonTelefonGecerli = _telefonTam;
                          _sistemHatasi = null;
                        }),
                        borderRadius: BorderRadius.circular(RR.r8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 10),
                          child: Text(
                            // ⚠ METİN SİMETRİK OLDU. Telefon yolunda
                            // "E-posta ile devam et" yazıyor; burada
                            // da öteki yolun ADI yazmalı. Eski metin
                            // gerekçe anlatıyordu, hedefi değil.
                            'Telefon ile devam et',
                            style: refText(
                                size: RF.s145,
                                weight: RF.w700,
                                color: RC.blue),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    RefFormField(
                      // ⚠ Ayrı kimlik — bkz. e-posta alanındaki not.
                      key: const ValueKey('kurtarma-telefon'),
                      iconAsset: 'assets/svg/ic_phone_f.svg',
                      controller: _phone,
                      focusNode: _fPhone,
                      enabled: !_busy,
                      // ⚠ "5XX XXX XX XX" BİÇİM ÖRNEĞİDİR, alan adı değil:
                      // etikette "Telefon" yazar, kutunun içinde biçim
                      // ipucu kalır.
                      etiket: 'Telefon',
                      yerTutucu: '5XX XXX XX XX',
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [TelefonBicimlendirici()],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _telefonDegisti(),
                      // ⚠ KAYITSIZ NUMARA UYARISI ALAN ALTINDA.
                      //
                      // Numara TAM ve kayıtsızsa kullanıcı hemen
                      // öğrenir; son hane silinince uyarı KALKAR
                      // (numara artık tam değil).
                      // ⚠ YALNIZ BİÇİM DENETLENİR.
                      //
                      // Kayıtsız numara uyarısı KALDIRILDI: kayıtlı ve
                      // kayıtsız numarada farklı cevap vermek hesap
                      // sayımına (enumeration) yol açıyordu.
                      validator: (v) =>
                          _kural('telefon', _fPhone, v, Validators.phone),
                    ),
                    const SizedBox(height: 14),
                    RefPrimaryButton(
                      'Doğrulama Kodu Gönder',
                      busy: _busy,
                      onPressed: _zorunluDolu ? _telefonKodIste : null,
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: RefTap(
                        onTap: () => setState(() {
                          _telefonYolu = false;
                          _sistemHatasi = null;
                          // Öteki yolun nötr kutusu taşınmaz.
                          _gonderildi = false;
                        }),
                        borderRadius: BorderRadius.circular(RR.r8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 10),
                          child: Text(
                            'E-posta ile devam et',
                            style: refText(
                                size: RF.s145,
                                weight: RF.w700,
                                color: RC.blue),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
