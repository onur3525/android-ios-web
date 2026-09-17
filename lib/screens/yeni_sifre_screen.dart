import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/geri.dart';
import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../domain/form_mesajlari.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// YENİ ŞİFRE BELİRLE
///
/// ## İKİ KAYNAKTAN ÇALIŞIR
///
/// · E-POSTA RESET TOKEN'ı — derin bağlantıyla gelen, süreli ve tek
///   kullanımlık belirteç (ana yol).
/// · TELEFON KURTARMA YETKİSİ — "e-postama erişemiyorum" yolunda
///   SMS ile telefon sahipliği doğrulandıktan sonra üretilen kısa
///   ömürlü yetki (alternatif yol).
///
/// ⚠ İKİSİ DE AYNI EKRANI KULLANIR ama farklı çağrılara gider.
/// Kullanıcı için ekran aynıdır; yetkinin kaynağı gizli kalır.
///
/// ## BU EKRANDA OTP ALANI YOKTUR
///
/// OTP telefon sahipliğini doğrular; şifre değiştirme yetkisi AYRI
/// ve süreli bir yetkidir. Kod bu ekranda tekrar sorulmaz.
///
/// ## HATA SINIFLARI AYRI
///
/// ⚠ Token/yetki hatası bir ALAN hatası DEĞİLDİR: hangi şifrenin
/// yanlış olduğunu söylemez. Form düzeyinde, alanların üstünde
/// gösterilir — `validator` içine yazılmaz.
/// ═══════════════════════════════════════════════════════════════
class YeniSifreScreen extends StatefulWidget {
  const YeniSifreScreen({super.key, this.resetToken, this.kurtarmaYetkisi});

  /// E-posta bağlantısından gelen belirteç (ana yol).
  final String? resetToken;

  /// Telefon kurtarma yetkisi (alternatif yol).
  final String? kurtarmaYetkisi;

  @override
  State<YeniSifreScreen> createState() => _YeniSifreScreenState();
}

class _YeniSifreScreenState extends State<YeniSifreScreen> {
  final _form = GlobalKey<FormState>();
  final _yeni = TextEditingController();
  final _tekrar = TextEditingController();
  final _fYeni = FocusNode();
  final _fTekrar = FocusNode();

  bool _busy = false;
  bool _gizli1 = true;
  bool _gizli2 = true;

  /// Token/yetki hatası — ALAN hatası değil, form düzeyinde.
  String? _yetkiHatasi;

  /// Ağ/sunucu hatası — ayrı sınıf.
  String? _sistemHatasi;

  /// Uyarı zamanı kuralı — öteki dört formla AYNI.
  final Set<String> _terkEdilen = {};
  bool _gonderimAninda = false;

  @override
  void initState() {
    super.initState();
    for (final e in <String, FocusNode>{
      'yeni': _fYeni,
      'tekrar': _fTekrar,
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
    _yeni.dispose();
    _tekrar.dispose();
    _fYeni.dispose();
    _fTekrar.dispose();
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
      // Boşaltma yazım sürecinde uyarı üretmez.
      // ⚠ TRIM ŞART: düğme aktifliği `trim()` ile ölçülüyor. Kapı
      // trim etmezse yalnız boşluk içeren alan "dolu" sayılıp uyarı
      // üretir ama düğme yine pasif kalır — iki ölçü ayrışır.
      if ((v ?? '').trim().isEmpty) {
        return null;
      }
    }
    return asil(v);
  }

  /// ── ⚠ "DOLU" YETMEZ: KURALA UYGUN VE EŞİT OLMALI ──
  ///
  /// Düğme yalnız iki alanın boş olmadığına bakıyordu. Sonuç: altı
  /// karakterden kısa şifreyle ya da iki alan BİRBİRİNİ TUTMADAN
  /// "Şifremi Yenile" basılabiliyordu; hata ancak basıldıktan sonra
  /// çıkıyordu.
  ///
  /// Kural net: şifre politikası geçmeden VE iki alan aynı olmadan
  /// düğme aktif olmaz.
  ///
  /// ⚠ Politika tek kaynaktan gelir (`Validators.password`): en az 6
  /// karakter, ardışık/tekrarlı/yaygın şifre reddi. Ekran kendi
  /// kuralını yazmaz.
  bool get _zorunlularDolu =>
      Validators.password(_yeni.text) == null &&
      _tekrar.text == _yeni.text;

  bool _hepsiniDenetle() {
    _terkEdilen.addAll(const ['yeni', 'tekrar']);
    _gonderimAninda = true;
    final ok = _form.currentState!.validate();
    _gonderimAninda = false;
    setState(() {});
    return ok;
  }

  Future<void> _kaydet() async {
    if (_busy) {
      return;
    }
    setState(() {
      _yetkiHatasi = null;
      _sistemHatasi = null;
    });
    if (!_hepsiniDenetle()) {
      return;
    }
    // Gönderim anındaki değer — stale cevap koruması.
    final sifreAnlik = _yeni.text;
    setState(() => _busy = true);

    String? hata;
    final yetki = widget.kurtarmaYetkisi;
    if (yetki != null) {
      hata = await context
          .read<AuthController>()
          .kurtarmaSifreBelirle(yetki, sifreAnlik);
    } else {
      // ⚠ E-POSTA RESET UCU SUNUCUDA YOK.
      //
      // Sözleşmede tanımlı (`/auth/password-reset/confirm`) ama
      // yazılmadı. SAHTE BAŞARI ÜRETİLMEZ: kullanıcıya açık bilgi
      // verilir.
      hata = FormMesaj.sifirlamaGecersiz;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (hata != null) {
      setState(() => _yetkiHatasi = hata);
      return;
    }
    sysToastOk(context, FormMesaj.sifirlamaBasarili);
    // ⚠ OTURUM AÇILMAZ: kullanıcı yeni şifresiyle normal yoldan girer.
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

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
                  const RefPageTitle('Yeni Şifre Belirle',
                      geriDugmesi: false),
                  const RefSubtitle(
                      'Hesabınız için yeni bir şifre belirleyin.'),
                  const SizedBox(height: 10),

                  // ── FORM DÜZEYİNDE HATA ──
                  //
                  // ⚠ Token/yetki ve sistem hataları alan altında
                  // GÖSTERİLMEZ; hangi şifrenin yanlış olduğunu
                  // söylemezler.
                  if (_yetkiHatasi != null || _sistemHatasi != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _yetkiHatasi ?? _sistemHatasi!,
                        style: refText(
                            size: RF.s135,
                            weight: RF.w600,
                            color: RC.danger),
                      ),
                    ),

                  RefFormField(
                    iconAsset: 'assets/svg/ic_lock.svg',
                    controller: _yeni,
                    focusNode: _fYeni,
                    enabled: !_busy,
                    hint: 'Yeni şifre',
                    obscureText: _gizli1,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => _fTekrar.requestFocus(),
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        _kural('yeni', _fYeni, v, Validators.password),
                    suffix: RefSifreGozu(
                      gizli: _gizli1,
                      onDegisti: (g) => setState(() => _gizli1 = g),
                    ),
                  ),

                  RefFormField(
                    iconAsset: 'assets/svg/ic_lock.svg',
                    controller: _tekrar,
                    focusNode: _fTekrar,
                    enabled: !_busy,
                    hint: 'Yeni şifre tekrar',
                    obscureText: _gizli2,
                    // Son alan: klavye kapanır, form gönderilmez.
                    textInputAction: TextInputAction.done,
                    // ⚠ YALNIZ EŞLEŞME SORAR — şifre kuralı üst alanın
                    // işidir; aynı hatayı iki satırda söylemek hangi
                    // alanın sorunlu olduğunu gizler.
                    onChanged: (_) => setState(() {}),
                    // ── ⚠ REFERANS ALAN BOŞKEN EŞLEŞME SORULMAZ ──
                    //
                    // Kullanıcı iki alanı doldurup ÜSTTEKİNİ silince
                    // bu alan hâlâ doluydu ve "Şifreler aynı olmalıdır"
                    // uyarısı ekranda KALIYORDU. Oysa kural açık: bilgi
                    // girilip silindiğinde uyarı kalmaz.
                    //
                    // Karşılaştırılacak değer yoksa karşılaştırma da
                    // yapılmaz; alan yeniden dolunca kural işler.
                    validator: (v) => _kural(
                        'tekrar',
                        _fTekrar,
                        v,
                        // ⚠ REFERANS GEÇERSİZKEN DE SORULMAZ.
                        //
                        // Kullanıcı üst alana 3 haneli bir şifre yazıp
                        // alta 6 hane girdiğinde ekranda tek uyarı
                        // çıkıyordu: "Şifreler aynı olmalıdır". Oysa
                        // asıl sorun eşleşme DEĞİL, üst alanın kurala
                        // uymamasıydı (en az 6 karakter). Uyarı yanlış
                        // alanı işaret ediyor ve kullanıcı şifresini
                        // uzatacağına alttakini düzeltmeye çalışıyordu.
                        //
                        // Referans alan kuralı geçene kadar eşleşme
                        // sorulmaz; geçtiği anda kural işler.
                        (x) => Validators.password(_yeni.text) != null
                            ? null
                            : Validators.passwordRepeat(x, _yeni.text)),
                    suffix: RefSifreGozu(
                      gizli: _gizli2,
                      onDegisti: (g) => setState(() => _gizli2 = g),
                    ),
                  ),

                  const SizedBox(height: 8),
                  RefInfoBox(
                    mavi: true,
                    child: Text(
                      // ⚠ SAYI EKRANA GÖMÜLMEZ — tek kaynak
                      // `FormMesaj.sifrePolitikasi`. Eskiden "6"
                      // burada düz metindi ve kural değişince geride
                      // kalıyordu.
                      FormMesaj.sifrePolitikasi,
                      style: refText(
                          size: RF.s135,
                          weight: RF.w400,
                          color: RC.textDark,
                          height: RF.lh150),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RefPrimaryButton(
                    'Şifremi Yenile',
                    busy: _busy,
                    onPressed: _zorunlularDolu ? _kaydet : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
