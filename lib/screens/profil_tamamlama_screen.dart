import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/geri.dart';
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
import 'otp_screen.dart';
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
  }

  @override
  void dispose() {
    _telefon.dispose();
    super.dispose();
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

  Future<void> _devam() async {
    if (_mesgul || !_tamam) {
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final auth = context.read<AuthController>();
    // Telefon doğrulanmışsa kod sorulmadan kaydedilir.
    if (_telefonDogrulanmis) {
      final hata = await _kaydet();
      if (!mounted) {
        return;
      }
      setState(() => _mesgul = false);
      if (hata != null) {
        setState(() => _hata = hata);
        return;
      }
      Navigator.of(context).pop(true);
      return;
    }
    final tel = Validators.phoneFmt(_telefon.text);
    var ch = await auth.profilTelefonKoduGonder(tel);
    if (!mounted) {
      return;
    }
    setState(() => _mesgul = false);
    if (ch.challengeId == null) {
      setState(() => _hata = ch.hata ?? FormMesaj.otpGonderilemedi);
      return;
    }
    final dogrulandi = await Navigator.of(context).push<bool>(panelRotasi<bool>(
      settings: const RouteSettings(name: '/dogrulama'),
      builder: (_) => OtpScreen(
        phone: tel,
        purpose: OtpPurpose.phoneChange,
        // ⚠ Kod doğrulaması ve bilgilerin kaydı TEK istekte: kod yanlışsa
        // hiçbir şey kaydedilmez.
        dogrula: (kod) => _kaydet(challengeId: ch.challengeId, kod: kod),
        yenidenGonder: () async {
          final yeni = await auth.profilTelefonKoduGonder(tel);
          if (yeni.challengeId == null) {
            return yeni.hata ?? FormMesaj.otpGonderilemedi;
          }
          ch = yeni;
          return null;
        },
        onVerified: (otpContext, _) => Navigator.of(otpContext).pop(true),
      ),
    ));
    if (!mounted) {
      return;
    }
    if (dogrulandi == true) {
      Navigator.of(context).pop(true);
    }
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
                TextField(
                  controller: _telefon,
                  enabled: !dogrulanmis && !_mesgul,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [TelefonBicimlendirici()],
                  onChanged: (_) => setState(() => _hata = null),
                  decoration: InputDecoration(
                    labelText: dogrulanmis
                        ? 'Telefon (doğrulandı)'
                        : 'Telefon (SMS kodu gönderilecek)',
                    hintText: '05XX XXX XX XX',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RR.r13)),
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
                if (_hata != null) ...[
                  const SizedBox(height: 8),
                  Text(_hata!,
                      style: refText(
                          size: RF.s125,
                          weight: RF.w600,
                          color: RC.danger)),
                ],
                const SizedBox(height: 16),
                RefPrimaryButton(
                  dogrulanmis ? 'Kaydet ve Devam Et' : 'Kodu Gönder ve Devam Et',
                  busy: _mesgul,
                  onPressed: _tamam ? _devam : null,
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
