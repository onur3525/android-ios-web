import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/geri.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/region_controller.dart';
import '../data/models/account.dart';
import '../domain/form_mesajlari.dart';
import '../ui/alt_panel.dart';
import '../ui/panel_rotasi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../ui/web_panel.dart';
import 'widgets/kategori_secim_paneli.dart';
import 'widgets/region_picker.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROFİL TAMAMLAMA — TEK EKRAN (4 Kas, kullanıcı kararı)
///
/// Kayıt formu yalnız ad, soyad, telefon, e-posta ve şifre alır. Eksik
/// kalan bilgiler işlemin gerektirdiği anda BU ekranda tamamlatılır:
///   · Hizmet alan — ilk Bul / İlan Oluştur'da: telefon + SMS kodu,
///     il, ilçe, mahalle.
///   · Hizmet veren — panel açılır açılmaz: aynıları + uzmanlık
///     kategorileri ve hizmet bölgeleri.
///
/// ⚠ TAMAMLANMIŞ PARÇA YENİDEN İSTENMEZ: doğrulanmış telefon, kayıtlı
/// adres ve hizmet listesi önceden dolu gelir; telefon doğrulanmışsa
/// kod sorulmaz. "Tamamlandı" kararı `Account.profilEksikleri` (API
/// modunda sunucu) üzerinden verilir; sunucu aynı kuralı ilan, teklif
/// ve iş listesi uçlarında da uygular.
///
/// ⚠ EKRAN KODU DOĞRULAMAZ: kod `AuthController.profiliTamamla` ile
/// sunucuya (Firebase belgesi olarak) gider; karar sunucunundur.
/// Tamamlanınca `true` ile kapanır ve kullanıcı bastığı işleme devam eder.
/// ═══════════════════════════════════════════════════════════════
/// İki SMS kodu arasındaki bekleme — sunucu kuralıyla (`smsGonderimIzni`,
/// 60 sn) ve kod ekranındaki sayaçla aynı.
const int _kSmsBeklemeSaniye = 60;

class ProfilTamamlamaScreen extends StatefulWidget {
  const ProfilTamamlamaScreen({super.key, required this.rol});

  final Role rol;

  static const rotaAdi = '/profil-tamamla';

  @override
  State<ProfilTamamlamaScreen> createState() => _ProfilTamamlamaScreenState();
}

class _ProfilTamamlamaScreenState extends State<ProfilTamamlamaScreen> {
  final _telefon = TextEditingController();
  String? _il;
  String? _ilce;
  String? _mahalle;
  final Set<String> _kategoriler = {};
  final Set<String> _bolgeler = {};
  bool _mesgul = false;
  String? _hata;

  // ── 4 Kas: SMS KODU AYNI EKRANDA ──
  // "SMS Kodu Gönder" → kod kutusu açılır, 60 sn geri sayım; sayım bitince
  // "Kodu tekrar gönder". 6 hane girilince (ya da Android'de SMS'ten
  // otomatik dolunca) düğme "Devam Et" olur; kod ve bilgiler TEK istekte
  // sunucuya gider. Gönderim kuralı (60 sn / 3 kod / 15 dk) sunucudadır;
  // ekran yalnız kalan süreyi gösterir.
  final _kod = TextEditingController();
  final _fKod = FocusNode();
  String? _challengeId;
  String? _gonderilenTelefon;
  String? _kodHata;
  bool _otomatikDogrulandi = false;
  int _sayac = 0;
  bool _kilit = false;
  Timer? _zamanlayici;

  /// 5 Kas (kullanıcı kararı): "SMS Kodu Gönder"e basıldıktan sonra —
  /// kod gelsin gelmesin, gönderim başarılı olsun olmasın — kod girilip
  /// devam edilmediği sürece sayaç bitince "Kodu tekrar gönder" çıkar.
  /// Numara değişince sıfırlanır.
  bool _gonderimDenendi = false;

  /// 3 koddan sonraki kilitte gösterilen uyarı (sunucunun metni; dakika
  /// sunucudaki tek kuraldan gelir).
  String? _kilitMesaji;
  ValueListenable<({String id, String kod})?>? _otomatikKod;

  bool get _saglayici => widget.rol == Role.provider;

  /// Telefon doğrulanmışsa alan kilitlidir, kod sorulmaz. Ekran açılırken
  /// bir kez okunur (build içinde `read` yapılmaz).
  late final bool _telefonDogrulanmis;

  @override
  void initState() {
    super.initState();
    final a = context.read<AuthController>().currentAccount;
    _telefonDogrulanmis =
        a != null && a.phoneVerified && a.phone.trim().isNotEmpty;
    if (a != null) {
      if (a.phone.trim().isNotEmpty) {
        _telefon.text =
            TelefonBicimlendirici.gruplu(Validators.phoneLocal(a.phone));
      }
      final adr = a.address;
      if (adr != null && adr.isComplete) {
        _il = adr.city;
        _ilce = adr.district;
        _mahalle = adr.neighborhood;
      }
      _kategoriler.addAll(a.categories);
      _bolgeler.addAll(a.serviceDistricts);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RegionController>().load();
      }
    });
    try {
      _otomatikKod = context.read<AuthController>().otomatikSmsKodu
        ..addListener(_otomatikKodGeldi);
    } catch (_) {
      _otomatikKod = null; // otomatik kod desteklenmiyor
    }
  }

  @override
  void dispose() {
    _otomatikKod?.removeListener(_otomatikKodGeldi);
    _zamanlayici?.cancel();
    _telefon.dispose();
    _kod.dispose();
    _fKod.dispose();
    super.dispose();
  }

  /// Android: telefon SMS'i yakaladı → kod kutusu kendiliğinden dolar.
  void _otomatikKodGeldi() {
    final o = _otomatikKod?.value;
    if (!mounted || o == null || o.id != _challengeId) {
      return;
    }
    setState(() {
      _kodHata = null;
      if (o.kod.isNotEmpty) {
        _kod.text = o.kod;
      } else {
        _otomatikDogrulandi = true; // kod girilmeden doğrulandı
      }
    });
  }

  void _sayaciBaslat(int saniye, {required bool kilit}) {
    _zamanlayici?.cancel();
    setState(() {
      _sayac = saniye;
      _kilit = kilit;
    });
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _sayac--;
        if (_sayac <= 0) {
          _sayac = 0;
          _kilit = false;
          t.cancel();
        }
      });
    });
  }

  String get _sayacMetni {
    final dk = _sayac ~/ 60;
    final sn = (_sayac % 60).toString().padLeft(2, '0');
    return dk > 0 ? '$dk:$sn' : '$_sayac sn';
  }

  bool get _kodGonderildi =>
      _challengeId != null &&
      _gonderilenTelefon == Validators.phoneFmt(_telefon.text);

  bool get _kodGirildi =>
      _otomatikDogrulandi || RegExp(r'^\d{6}$').hasMatch(_kod.text);

  /// Numara değişirse gönderilmiş kod o numaraya ait değildir: sıfırlanır.
  void _telefonDegisti(String _) {
    setState(() {
      _hata = null;
      if (_gonderilenTelefon != Validators.phoneFmt(_telefon.text)) {
        _gonderimDenendi = false;
      }
      if (_challengeId != null &&
          _gonderilenTelefon != Validators.phoneFmt(_telefon.text)) {
        _challengeId = null;
        _kod.clear();
        _kodHata = null;
        _otomatikDogrulandi = false;
      }
    });
  }

  bool get _tamam {
    if (!_telefonDogrulanmis && Validators.phone(_telefon.text) != null) {
      return false;
    }
    if (_il == null || _ilce == null || _mahalle == null) {
      return false;
    }
    if (_saglayici && (_kategoriler.isEmpty || _bolgeler.isEmpty)) {
      return false;
    }
    return true;
  }

  ({String city, String district, String neighborhood}) get _adres =>
      (city: _il!, district: _ilce!, neighborhood: _mahalle!);

  Future<String?> _kaydet({String? challengeId, String? kod}) =>
      context.read<AuthController>().profiliTamamla(
            telefon: _telefonDogrulanmis
                ? null
                : Validators.phoneFmt(_telefon.text),
            challengeId: challengeId,
            kod: kod,
            adres: _adres,
            kategoriler: _saglayici ? _kategoriler : null,
            bolgeler: _saglayici ? _bolgeler : null,
          );

  /// "SMS Kodu Gönder" / "Kodu tekrar gönder".
  Future<void> _kodGonder() async {
    if (_mesgul || !_tamam || _sayac > 0) {
      return;
    }
    final tel = Validators.phoneFmt(_telefon.text);
    setState(() {
      _mesgul = true;
      _hata = null;
      _kodHata = null;
    });
    final r = await context.read<AuthController>().profilTelefonKoduGonder(tel);
    if (!mounted) {
      return;
    }
    setState(() {
      _mesgul = false;
      _gonderimDenendi = true;
      _gonderilenTelefon = tel;
      _kilitMesaji = r.kilit ? r.hata : null;
    });
    if (r.challengeId == null) {
      if (r.kalanSaniye != null) {
        // Bekleme ya da 5 dk kilit: kalan süre geri sayımla gösterilir.
        _sayaciBaslat(r.kalanSaniye!, kilit: r.kilit);
      } else {
        setState(() => _kodHata = r.hata ?? FormMesaj.otpGonderilemedi);
      }
      return;
    }
    setState(() {
      _challengeId = r.challengeId;
      _gonderilenTelefon = tel;
      _kod.clear();
      _otomatikDogrulandi = false;
    });
    _sayaciBaslat(_kSmsBeklemeSaniye, kilit: false);
    _fKod.requestFocus();
    // Android bazen kodu gönderim yanıtından ÖNCE yakalar: kaçmasın.
    _otomatikKodGeldi();
  }

  /// "Devam Et": telefon doğrulanmışsa yalnız kayıt; değilse kod + kayıt
  /// TEK istekte (kod yanlışsa hiçbir şey kaydedilmez).
  Future<void> _devam() async {
    if (_mesgul || !_tamam) {
      return;
    }
    if (!_telefonDogrulanmis && !(_kodGonderildi && _kodGirildi)) {
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
      _kodHata = null;
    });
    final hata = _telefonDogrulanmis
        ? await _kaydet()
        : await _kaydet(challengeId: _challengeId, kod: _kod.text);
    if (!mounted) {
      return;
    }
    setState(() => _mesgul = false);
    if (hata != null) {
      setState(() {
        if (_telefonDogrulanmis) {
          _hata = hata;
        } else {
          _kodHata = hata;
          _kod.clear();
          _otomatikDogrulandi = false;
        }
      });
      return;
    }
    _zamanlayici?.cancel();
    sysToastOk(context, 'Bilgileriniz kaydedildi');
    Navigator.of(context).pop(true);
  }

  /// ⚠ Seçim sayfası bölge verisini DİNLER (`Consumer`): veri sonradan
  /// gelirse liste kendiliğinden dolar (kayıt ekranındaki eski kuralla aynı).
  Future<String?> _sec(String baslik,
          List<String> Function(RegionController r) secenekler, String? secili) =>
      altPanelGoster<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => Consumer<RegionController>(
          builder: (_, r, __) => RegionPickerSheet(
            title: baslik,
            options: secenekler(r),
            selected: secili,
            searchable: true,
          ),
        ),
      );

  /// İL SEÇİMİ — sunucudan gelen aktif iller. İl değişince ilçe, mahalle
  /// ve hizmet bölgeleri SIFIRLANIR (başka ilin ilçeleri taşınamaz).
  Future<void> _ilSec() async {
    final s = await _sec('İl Seçin', (r) => r.cityNames, _il);
    if (s != null && mounted && s != _il) {
      setState(() {
        _il = s;
        _ilce = null;
        _mahalle = null;
        _bolgeler.clear();
      });
    }
  }

  /// İlçe seçimi — ilçe değişince mahalle SIFIRLANIR (kontrollü zincir).
  Future<void> _ilceSec() async {
    final s = await _sec('İlçe Seçin', (r) => r.districtsOf(_il), _ilce);
    if (s != null && mounted && s != _ilce) {
      setState(() {
        _ilce = s;
        _mahalle = null;
      });
    }
  }

  /// Mahalle seçimi — ilçeye bağlı liste; serbest metin YOK.
  Future<void> _mahalleSec() async {
    final s = await _sec('Mahalle Seçin',
        (r) => r.neighborhoodsOf(_ilce!, city: _il), _mahalle);
    if (s != null && mounted) {
      setState(() => _mahalle = s);
    }
  }

  Future<void> _kategoriSec() async {
    final s = await altPanelGoster<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => KategoriSecimPaneli(baslangic: _kategoriler),
    );
    if (s != null && mounted) {
      setState(() => _kategoriler
        ..clear()
        ..addAll(s));
    }
  }

  Future<void> _bolgeSec() async {
    final s = await altPanelGoster<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Consumer<RegionController>(
        builder: (_, r, __) => RefMultiSelectSheet(
          title: 'Hizmet Verilen İlçeler',
          options: r.districtsOf(_il),
          initial: _bolgeler,
          tumuEtiketi: 'Tüm İlçeler',
        ),
      ),
    );
    if (s != null && mounted) {
      setState(() => _bolgeler
        ..clear()
        ..addAll(s));
    }
  }

  String _ozet(Set<String> l) {
    final s = l.toList()..sort();
    return s.length <= 2 ? s.join(', ') : '${s.take(2).join(', ')} +${s.length - 2}';
  }

  /// Kod kutusunun altı: geri sayım, "Kodu tekrar gönder" ya da 5 dk kilit.
  Widget _kodAltSatiri() {
    final kucuk = refText(size: RF.s125, weight: RF.w500, color: RC.textSoft);
    if (_kilit && _sayac > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_kilitMesaji ?? 'Çok fazla kod istendi.',
                style: refText(size: RF.s125, weight: RF.w600, color: RC.danger)),
            const SizedBox(height: 2),
            Text('Kalan süre: $_sayacMetni', style: kucuk),
          ],
        ),
      );
    }
    if (_sayac > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Text('Yeni kodu $_sayacMetni sonra isteyebilirsiniz', style: kucuk),
      );
    }
    if (!_kodGonderildi && !_gonderimDenendi) {
      return const SizedBox(height: 6);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: RefTekrarGonder(
        metin: 'Kodu tekrar gönder',
        onTap: _mesgul ? null : _kodGonder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bölge verisi gelince il/ilçe satırları tazelensin.
    context.watch<RegionController>();
    final dogrulanmis = _telefonDogrulanmis;
    return Scaffold(
      backgroundColor:
          WebPanel.panelMi(context) ? Colors.transparent : RC.pageBg,
      body: WebPanel(
        icerik: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RefBackButton(onTap: () => geriGit(context)),
                ),
                const SizedBox(height: 6),
                Text('Profilinizi Tamamlayın',
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s25,
                        weight: RF.w700,
                        color: RC.text,
                        letterSpacing: RF.lsM03)),
                const SizedBox(height: 8),
                Text(
                  _saglayici
                      ? 'Teklif verebilmek için telefonunuzu doğrulayın, '
                          'adresinizi, uzmanlık kategorilerinizi ve hizmet '
                          'bölgelerinizi girin. Bu bilgiler bir kez istenir.'
                      : 'Devam etmek için telefonunuzu doğrulayın ve adres '
                          'bilgilerinizi girin. Bu bilgiler bir kez istenir.',
                  textAlign: TextAlign.center,
                  style: refText(
                      size: RF.s145,
                      weight: RF.w400,
                      color: RC.textSoft,
                      height: RF.lh145),
                ),
                const SizedBox(height: 20),
                // 4 Kas: kutunun içinde açıklama yazısı yok — telefon ikonu
                // ve silik örnek biçim (kayıt formundaki telefon alanı gibi).
                TextField(
                  controller: _telefon,
                  enabled: !dogrulanmis && !_mesgul,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [TelefonBicimlendirici()],
                  onChanged: _telefonDegisti,
                  decoration: refIkonluAlanDekoru(
                    '5XX XXX XX XX',
                    'assets/svg/ic_phone.svg',
                    zorunlu: true,
                    suffix: dogrulanmis
                        ? const Tooltip(
                            message: 'Telefon numaranız doğrulandı',
                            child: Icon(Icons.verified_rounded,
                                color: RC.success, size: 20),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                RefRegDropdown(
                  iconAsset: 'assets/svg/ic_pin.svg',
                  label: 'İl',
                  value: _il,
                  onTap: _mesgul ? null : _ilSec,
                ),
                RefRegDropdown(
                  iconAsset: 'assets/svg/ic_build.svg',
                  label: 'İlçe',
                  value: _ilce,
                  onTap: _il == null || _mesgul ? null : _ilceSec,
                ),
                RefRegDropdown(
                  iconAsset: 'assets/svg/ic_home2.svg',
                  label: 'Mahalle',
                  value: _mahalle,
                  onTap: _ilce == null || _mesgul ? null : _mahalleSec,
                ),
                if (_saglayici) ...[
                  RefRegDropdown(
                    iconAsset: 'assets/svg/ic_grid.svg',
                    label: 'Uzmanlık Kategorileri',
                    value: _kategoriler.isEmpty ? null : _ozet(_kategoriler),
                    onTap: _mesgul ? null : _kategoriSec,
                  ),
                  RefRegDropdown(
                    iconAsset: 'assets/svg/ic_build.svg',
                    label: 'Hizmet Verilen İlçeler',
                    value: _bolgeler.isEmpty ? null : _ozet(_bolgeler),
                    onTap: _il == null || _mesgul ? null : _bolgeSec,
                  ),
                ],
                // 4 Kas: SMS kodu kutusu (en altta — hizmet alanda Mahalle'nin
                // altı). Kod gönderilene kadar pasif.
                if (!dogrulanmis) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _kod,
                    focusNode: _fKod,
                    enabled: _kodGonderildi && !_mesgul && !_otomatikDogrulandi,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    // iOS: klavyenin üstünde "Mesajlar'dan" önerisi; web:
                    // tarayıcının tek kullanımlık kod önerisi.
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) => setState(() => _kodHata = null),
                    onSubmitted: (_) => _devam(),
                    decoration: refIkonluAlanDekoru(
                      _otomatikDogrulandi
                          ? 'Numaranız otomatik doğrulandı'
                          : 'Telefonunuza gelen 6 haneli kodu girin',
                      'assets/svg/ic_plock.svg',
                      hata: _kodHata,
                    ),
                  ),
                  _kodAltSatiri(),
                ],
                if (_hata != null) ...[
                  const SizedBox(height: 8),
                  Text(_hata!,
                      style: refText(
                          size: RF.s125,
                          weight: RF.w600,
                          color: RC.danger)),
                ],
                const SizedBox(height: 16),
                // Doğrulanmış telefonda doğrudan "Devam Et"; değilse kod
                // girilene kadar "SMS Kodu Gönder", girilince "Devam Et".
                if (dogrulanmis || (_kodGonderildi && _kodGirildi))
                  RefPrimaryButton(
                    'Devam Et',
                    busy: _mesgul,
                    onPressed: _tamam ? _devam : null,
                  )
                else
                  RefPrimaryButton(
                    'SMS Kodu Gönder',
                    busy: _mesgul,
                    onPressed:
                        _tamam && !_kodGonderildi && _sayac == 0 ? _kodGonder : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ── ⚠ PROFİL KAPISI — TEK KAYNAK (4 Kas) ──
///
/// Rolün gerektirdiği bilgiler tamamsa hemen `true`; değilse tamamlama
/// ekranı açılır, tamamlanırsa `true`, vazgeçilirse `false`. Bul, İlan
/// Oluştur ve hizmet veren paneli BU fonksiyonu çağırır; ekranlar kendi
/// kuralını yazmaz. Sunucu aynı kuralı ayrıca uygular.
Future<bool> profilKapisi(BuildContext context, Role rol) async {
  Account? hesap;
  try {
    hesap = context.read<AuthController>().currentAccount;
  } on ProviderNotFoundException catch (_) {
    // Yalıtılmış widget testleri: oturum katmanı yok, kapı devre dışı
    // (son söz zaten sunucunun kapısındadır).
    return true;
  }
  if (hesap == null) {
    return false;
  }
  if (hesap.profilTamam(rol)) {
    return true;
  }
  final sonuc = await Navigator.of(context).push<bool>(panelRotasi<bool>(
    settings: const RouteSettings(name: ProfilTamamlamaScreen.rotaAdi),
    builder: (_) => ProfilTamamlamaScreen(rol: rol),
  ));
  return sonuc == true;
}
