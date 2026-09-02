import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/validators.dart';
import '../domain/form_mesajlari.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'nav_actions.dart';
import '../core/geri.dart';
import '../core/teshis.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _cur = TextEditingController();
  /// ⚠ Enter → bir alt alana geçiş için odak düğümleri.
  final _f_cur = FocusNode();
  final _f_new1 = FocusNode();
  final _f_new2 = FocusNode();

  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  /// ── ⚠ DÜĞME AKTİFLİK KURALI ──
  ///
  /// Düğme her zaman aktifti; eksik ya da tutmayan şifreyle basılıp
  /// hata alınıyordu. Ortak kural: eksik/geçersiz girdiyle düğme
  /// AKTİF OLMAZ.
  ///
  /// ⚠ Politika tek kaynaktan (`Validators.password`); ekran kendi
  /// kuralını yazmaz.
  bool get _formGecerli =>
      _cur.text.trim().isNotEmpty &&
      Validators.password(_new1.text) == null &&
      _new2.text == _new1.text;
  bool _busy = false;

  /// Alan düzelince uyarı ANINDA kalksın — bkz. `RefTextField.alanAnahtari`.
  final _mevcutKey = GlobalKey<FormFieldState<String>>();
  final _yeniKey = GlobalKey<FormFieldState<String>>();
  final _tekrarKey = GlobalKey<FormFieldState<String>>();
  /// ⚠ Her şifre alanının maskesi BAĞIMSIZDIR.
  bool _obscure = true;
  bool _obscure2 = true;
  bool _obscure3 = true;
  String? _curError;

  /// UYARI ZAMANI — kayıt, şifre sıfırlama ve profil ekranıyla AYNI.
  ///
  /// ⚠ YAZARKEN UYARI YOKTUR.
  ///
  /// Eski davranış her tuşta ÜÇ ALANI birden doğruluyordu: tek alana
  /// bir karakter yazmak yetiyor, diğer iki satır da kırmızıya
  /// dönüyordu. Tekrar alanındaki `reset()` de düzenlemenin ortasında
  /// alan durumunu sıfırlayıp silmeyi zorlaştırıyordu.
  ///
  /// Yeni kural: uyarı YALNIZ alan terk edildikten sonra ve alan
  /// odakta DEĞİLKEN görünür.
  final Set<String> _terkEdilen = {};

  /// ⚠ YALNIZ `validate()` ÇAĞRISI SÜRESİNCE AÇIK — bkz. aynı desenin
  /// anlatıldığı `profile_info_screen`. Kalıcı bayrak, bir kez
  /// gönderime basıldıktan sonra uyarıyı ekranda ASILI BIRAKIYORDU.
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
      // ⚠ BOŞ ALAN, YAZIM SÜRECİNDE UYARI ÜRETMEZ.
      //
      // Kullanıcı bir şifre alanını doldurup sonra SİLDİĞİNDE
      // "Bu alan zorunludur" beliriyordu. Oysa silmek bir hata
      // değildir: kullanıcı yeniden yazmak üzere temizlemiş olabilir
      // ve o sırada öteki alanda çalışıyordur.
      //
      // Zorunluluk KAYBOLMADI: gönderim anında (`_gonderimAninda`)
      // boş alan yine "Bu alan zorunludur" der ve form geçmez.
      // Değişen tek şey, bunun NE ZAMAN söylendiğidir.
      //
      // ⚠ DOLU AMA GEÇERSİZ değer bu kuraldan ETKİLENMEZ: yanlış
      // yazılmış satır alandan çıkınca yine uyarı verir.
      // ⚠ TRIM ŞART: düğme aktifliği `trim()` ile ölçülüyor. Kapı
      // trim etmezse yalnız boşluk içeren alan "dolu" sayılıp uyarı
      // üretir ama düğme yine pasif kalır — iki ölçü ayrışır.
      if ((v ?? '').trim().isEmpty) {
        return null;
      }
    }
    return asil(v);
  }

  bool _hepsiniDenetle() {
    _terkEdilen.addAll(const ['mevcut', 'yeni', 'tekrar']);
    _gonderimAninda = true;
    final ok = _form.currentState!.validate();
    _gonderimAninda = false;
    setState(() {});
    return ok;
  }

  @override
  void initState() {
    super.initState();
    // Alan odaktan çıkınca "terk edildi" sayılır; odağa dönünce uyarı
    // gizlenir ama yazılan değer korunur.
    for (final e in <String, FocusNode>{
      'mevcut': _f_cur,
      'yeni': _f_new1,
      'tekrar': _f_new2,
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

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    // Güncelleme denendi: tüm alanlar denetlenir.
    setState(() => _curError = null);
    if (!_hepsiniDenetle()) {
      return;
    }
    setState(() => _busy = true);
    final err = await context
        .read<AuthController>()
        .changePassword(_cur.text, _new1.text);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _curError = err.message);
      _form.currentState!.validate();
      return;
    }
    sysToastOk(context, 'Şifreniz güncellendi');
    geriGit(context);
  }

  @override
  void dispose() {
    _f_cur.dispose();
    _f_new1.dispose();
    _f_new2.dispose();
    _cur.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠ TEŞHİS: bu akışın klavye süreleri AYRI etiketlenir.
    FocusIzle.aktifRoute = '/change-password';
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
        // Doğrulama her yeniden çizimde koşar; alan odaktaysa ya da
        // henüz terk edilmediyse `null` döner. Alanlar arası bağ
        // (mevcut şifre değişince yeni alanların yeniden
        // değerlendirilmesi) bu kip sayesinde kendiliğinden olur —
        // elle `validate()` çağırmaya gerek yoktur.
        autovalidateMode: AutovalidateMode.always,
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RefPageTitle('Şifre Değiştir'),
            const RefSubtitle(
                'Hesabınızın güvenliği için güçlü bir şifre belirleyin.'),

            // .ad-card — üç şifre alanı
            RefFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefTextField(
                    // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
                    zorunlu: true,
                    alanAnahtari: _mevcutKey,
                    // ⚠ ÜÇ ALANI BİRDEN DOĞRULAYAN `onChanged` KALDIRILDI:
                    // tek alana bir karakter yazmak diğer iki satırı da
                    // kırmızıya boyuyordu. Alanlar arası bağ artık
                    // `AutovalidateMode.always` ile kendiliğinden kurulur.
                    onChanged: (_) => setState(() {}),
                    controller: _cur,
                    focusNode: _f_cur,
                    textInputAction: TextInputAction.next,
                    // ⚠ `onEditingComplete`: varsayılan yol önce `unfocus()` çağırıp
                    // klavyeyi kapatıyordu (bkz. register_screen notu).
                    onEditingComplete: () => _f_new1.requestFocus(),
                    hint: 'Mevcut şifre',
                    obscureText: _obscure,
                    suffix: _gozDugmesi(
                        _obscure, (g) => setState(() => _obscure = g)),
                    validator: (v) {
                      // ⚠ MEVCUT ŞİFREYE YENİ KURALLAR UYGULANMAZ.
                      //
                      // Bu alan kullanıcının HÂLİHAZIRDA kullandığı
                      // şifredir. Ardışık/yaygın şifre reddi kural
                      // yürürlüğe girmeden ÖNCE açılmış hesapları
                      // kilitler — kimse şifresini değiştiremezdi.
                      // Burada yalnız uzunluk aranır; doğruluk kararı
                      // sunucunun.
                      return _kural('mevcut', _f_cur, v, (x) {
                        final t = Validators.loginPassword(x);
                        if (t != null) {
                          return t;
                        }
                        return _curError;
                      });
                    },
                  ),
                  // ⚠ Etiketler kaldırılınca dikey aralık
                  // kayboldu; kayıt ekranıyla aynı değer.
                  const SizedBox(height: 12),
                  RefTextField(
                    // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
                    zorunlu: true,
                    alanAnahtari: _yeniKey,
                    // ⚠ bkz. üstteki not — elle doğrulama YOK.
                    onChanged: (_) => setState(() {}),
                    controller: _new1,
                    focusNode: _f_new1,
                    textInputAction: TextInputAction.next,
                    // ⚠ `onEditingComplete`: varsayılan yol önce `unfocus()` çağırıp
                    // klavyeyi kapatıyordu (bkz. register_screen notu).
                    onEditingComplete: () => _f_new2.requestFocus(),
                    hint: 'Yeni şifre',
                    obscureText: _obscure2,
                    suffix: _gozDugmesi(
                        _obscure2, (g) => setState(() => _obscure2 = g)),
                    // ⚠ ŞİFRE KURALLARI + ESKİSİYLE AYNI OLMAMA.
                    //
                    // Aynı şifreyle "değiştirdim" demek yanıltıcıdır:
                    // kullanıcı hesabını güvenceye aldığını sanır, oysa
                    // sızmış olabilecek şifre hâlâ geçerlidir.
                    // Aynı denetim domain katmanında DA vardır.
                    validator: (v) => _kural(
                        'yeni',
                        _f_new1,
                        v,
                        (x) =>
                            Validators.password(x) ??
                            ((x ?? '') == _cur.text && _cur.text.isNotEmpty
                                ? FormMesaj.sifreEskisiyleAyni
                                : null)),
                  ),
                  // ⚠ Etiketler kaldırılınca dikey aralık
                  // kayboldu; kayıt ekranıyla aynı değer.
                  const SizedBox(height: 12),
                  RefTextField(
                    // ⚠ Zorunlu alan — yıldız kutunun içinde çizilir.
                    zorunlu: true,
                    alanAnahtari: _tekrarKey,
                    onChanged: (_) => setState(() {}),
                    controller: _new2,
                    focusNode: _f_new2,
                    textInputAction: TextInputAction.done,
                    hint: 'Yeni şifre tekrar',
                    obscureText: _obscure3,
                    suffix: _gozDugmesi(
                        _obscure3, (g) => setState(() => _obscure3 = g)),
                    // ⚠ DOĞRULAMA SIRASI: ÖNCE ŞİFRE KURALLARI.
                    //
                    // Önceki sıra ters kurulmuştu: eşleşme kontrolü
                    // önce çalıştığı için, kullanıcı tekrar alanına
                    // 3 harf yazar yazmaz "Şifreler eşleşmiyor"
                    // uyarısı çıkıyordu — oysa şifre henüz
                    // tamamlanmamıştı ve gerçek sorun uzunluktu.
                    //
                    // Artık aynı kurallar (en az 6, ardışık/tekrar
                    // eden/yaygın şifre reddi) BU ALANDA DA geçerlidir;
                    // eşleşme uyarısı ancak şifre geçerli olduğunda
                    // ve gerçekten farklıysa görünür.
                    // ⚠ BU ALAN YALNIZ "AYNI MI?" SORAR.
                    //
                    // Eskiden burada "mevcut şifreden farklı olmalıdır"
                    // denetimi de vardı. Sonuç yanıltıcıydı: kullanıcı
                    // yeni şifreyi iki alana da DOĞRU yazmış olsa bile
                    // tekrar satırında "mevcut şifrenizden farklı
                    // olmalıdır" görüyor, hangi alanın sorunlu olduğunu
                    // anlayamıyordu.
                    //
                    // O kural YENİ ŞİFRE alanının işidir ve orada
                    // duruyor; ayrıca domain katmanında da denetlenir.
                    // Aynı hatayı iki satırda birden söylemenin faydası
                    // yok.
                    // ⚠ REFERANS ALAN BOŞKEN EŞLEŞME SORULMAZ —
                    // yeni şifre silinince bu alanda uyarı KALMASIN
                    // (bkz. yeni_sifre_screen'deki aynı düzeltme).
                    validator: (v) => _kural(
                        'tekrar',
                        _f_new2,
                        v,
                        // ⚠ REFERANS GEÇERSİZKEN DE SORULMAZ — bkz.
                        // yeni_sifre_screen'deki aynı düzeltme. Yeni
                        // şifre kurala uymuyorsa "şifreler aynı
                        // olmalıdır" yanlış alanı işaret eder.
                        (x) => Validators.password(_new1.text) != null
                            ? null
                            : Validators.passwordRepeat(x, _new1.text)),
                  ),
                ],
              ),
            ),

            // .rg-infobox.blue{margin-top:14px}
            RefInfoBox(
              mavi: true,
              margin: const EdgeInsets.only(top: 14),
              child: Text(
                // ⚠ ORTAK DİL: parantez içi örnekler kaldırıldı.
                //
                // ⚠ SAYI EKRANA GÖMÜLMEZ — tek kaynak
                // `FormMesaj.sifrePolitikasi`. Öneri cümlesi ekranın
                // kendi ekidir; politika metni ortaktır.
                '${FormMesaj.sifrePolitikasi} Güvenliğiniz için harf '
                've rakam birlikte kullanmanızı öneririz.',
                style: refText(
                  size: RF.s135,
                  weight: RF.w400,
                  color: RC.textDark,
                  height: RF.lh150,
                ),
              ),
            ),

            // .po-next{margin-top:16px}
            const SizedBox(height: 16),
            RefNextButton(
              'Şifreyi Güncelle',
              iconAsset: 'assets/svg/ic_lockw.svg',
              busy: _busy,
              // ⚠ AYNI KURAL BURADA DA: düğme, mevcut şifre girilmeden,
              // yeni şifre politikayı geçmeden ve iki yeni alan
              // birbirini tutmadan aktif olmaz.
              onPressed: _formGecerli ? _save : null,
            ),

            // ── ŞİFREMİ UNUTTUM ──
            //
            // Kullanıcı mevcut şifresini bilmiyorsa hesabındaki
            // e-posta/telefon üzerinden sıfırlama akışını başlatır.
            const SizedBox(height: 14),
            Center(
              child: RefTextButton(
                'Şifremi Unuttum / Sıfırla',
                onPressed: _busy ? null : _sifreSifirla,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ŞİFRE SIFIRLAMA AKIŞINI BAŞLAT
  ///
  /// E-posta ve telefon KULLANICI HESABINDAN alınır; kullanıcıdan
  /// yeniden istenmez.
  ///
  /// Mock modda güvenli simülasyon yapılır (gerçek e-posta gönderilmez).
  /// API modunda `forgotStart` gerçek sıfırlama ucuna gider.
  Future<void> _sifreSifirla() async {
    final acc = context.read<AuthController>().currentAccount;
    if (acc == null) {
      return;
    }
    final eposta = acc.email.trim();
    final onay = await RefBottomSheet.goster<bool>(
      context,
      title: 'Şifre Sıfırlama',
      // ── SADE VE NET ──
      //
      // ⚠ Önceki hâl tek uzun cümleydi ve adres cümlenin içinde
      // kayboluyordu. Artık üç kısa parça var: ne olacağı, HANGİ
      // ADRESE gideceği (vurgulu kutu) ve tek eylem.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: RC.blueSoft,
              shape: BoxShape.circle,
            ),
            child: RefSvg(
              eposta.isEmpty
                  ? 'assets/svg/ic_chat.svg'
                  : 'assets/svg/ic_mail.svg',
              size: 26,
              color: RC.blue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            eposta.isEmpty
                ? 'Doğrulama kodu gönderilecek'
                : 'Sıfırlama bağlantısı gönderilecek',
            textAlign: TextAlign.center,
            style: refText(size: 16.5, weight: RF.w700, color: RC.text),
          ),
          const SizedBox(height: 10),
          // Adres/numara VURGULU kutuda — cümlenin içinde kaybolmaz.
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            decoration: BoxDecoration(
              color: RC.blueSoft,
              borderRadius: BorderRadius.circular(RR.r10),
            ),
            child: Text(
              eposta.isEmpty ? _telefonMaskeli(acc.phone) : eposta,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: refText(size: RF.s145, weight: RF.w700, color: RC.blue),
            ),
          ),
          const SizedBox(height: 16),
          RefPrimaryButton(
            'Gönder',
            iconAsset: 'assets/svg/ic_plane.svg',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (onay != true || !mounted) {
      return;
    }

    setState(() => _busy = true);
    final err =
        await context.read<AuthController>().forgotStart(acc.phone);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    // Kısa onay — adres zaten panelde gösterildi, tekrarlanmaz.
    sysToastOk(
      context,
      eposta.isEmpty ? 'Doğrulama kodu gönderildi' : 'Bağlantı gönderildi',
    );
  }

  /// `.rg-eye` — göster/gizle.
  ///
  /// ⚠ HER SATIRIN KENDİ GÖZÜ VARDIR ve YALNIZ KENDİ alanını etkiler.
  /// Önceden tek bir düğme vardı, üstelik BİRİNCİ alana konulup
  /// ÜÇÜNCÜ alanın bayrağını değiştiriyordu; diğer iki satırda göz
  /// hiç yoktu.
  ///
  /// İkon durumu: maskeliyken ÜSTÜ ÇİZİLİ göz, açıkken düz göz.
  /// Şifre gözü — BASILI TUTULDUĞU SÜRECE gösterir.
  /// Ortak davranış için bkz. `RefSifreGozu`.
  Widget _gozDugmesi(bool gizli, ValueChanged<bool> ayarla) =>
      RefSifreGozu(gizli: gizli, onDegisti: ayarla);
}

/// Sıfırlama panelinde gösterilen maskeli numara: `0555 *** ** 93`.
///
/// ⚠ Numaranın tamamı gösterilmez: panel omuz üstünden okunabilir.
/// Kullanıcının hangi hattı olduğunu anlamasına yetecek kadarı yazılır.
String _telefonMaskeli(String ham) {
  final d = Validators.phoneLocal(ham);
  if (d.length != 11) {
    return d.isEmpty ? 'Kayıtlı numara' : d;
  }
  return '${d.substring(0, 4)} *** ** ${d.substring(9)}';
}
