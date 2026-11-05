import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/geri.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../domain/sosyal_saglayici.dart';
import '../ui/kullanim_sozlesmesi_onayi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../ui/web_panel.dart';

/// ═══════════════════════════════════════════════════════════════
/// GOOGLE / APPLE İLE KAYIT (4 Kas, kullanıcı talebi)
///
/// Google/Apple ile ilk girişte bu kimliğin HizmetCep hesabı yoksa açılır.
/// E-postalı kayıt formundaki kurallar aynen: ad + soyad, rol (giriş
/// ekranından gelindiyse sorulur) ve iki zorunlu onay (tek kaynak:
/// `KullanimSozlesmesiOnayi`). E-posta sağlayıcıdan gelir ve doğrulanmıştır;
/// şifre İSTENMEZ (giriş Google/Apple ile yapılır). Telefon ve adres
/// e-postalı kayıttaki AYNI profil tamamlama adımında istenir.
///
/// Kayıt tamamlanınca `true` ile kapanır; yönlendirmeyi çağıran yapar.
/// ═══════════════════════════════════════════════════════════════
class SosyalKayitScreen extends StatefulWidget {
  const SosyalKayitScreen({
    super.key,
    required this.belge,
    required this.saglayici,
    this.rol,
    this.ad,
    this.eposta,
  });

  final String belge;
  final SosyalSaglayici saglayici;
  final Role? rol;
  final String? ad;
  final String? eposta;

  static const rotaAdi = '/sosyal-kayit';

  @override
  State<SosyalKayitScreen> createState() => _SosyalKayitScreenState();
}

class _SosyalKayitScreenState extends State<SosyalKayitScreen> {
  final _ad = TextEditingController();
  final _soyad = TextEditingController();
  final _fSoyad = FocusNode();
  Role? _rol;
  bool _sozlesme = false;
  bool _ticariIleti = false;
  bool _mesgul = false;

  /// 4 Kas: ad ve soyad yalnız sağlayıcıdan gelmediyse (ya da geçersizse)
  /// sorulur — Google adı verir, Apple bazen vermez.
  late final bool _adGerekli;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _rol = widget.rol;
    // Sağlayıcının verdiği ad önden doldurulur (Apple adı yalnız ilk
    // girişte verir; boşsa kullanıcı yazar). Son kelime soyad sayılır.
    final parcalar = (widget.ad ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parcalar.length >= 2) {
      _soyad.text = parcalar.removeLast();
      _ad.text = parcalar.join(' ');
    } else if (parcalar.length == 1) {
      _ad.text = parcalar.first;
    }
    _adGerekli = _adHatasi != null;
  }

  @override
  void dispose() {
    _ad.dispose();
    _soyad.dispose();
    _fSoyad.dispose();
    super.dispose();
  }

  String? get _adHatasi =>
      Validators.name(_ad.text, min: 3, label: 'ad') ??
      Validators.name(_soyad.text, min: 2, label: 'soyad');

  bool get _tamam =>
      _adHatasi == null && _rol != null && _sozlesme && !_mesgul;

  Future<void> _kaydol() async {
    if (!_tamam) {
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final hata = await context.read<AuthController>().sosyalKayit(
          belge: widget.belge,
          rol: _rol!,
          ad: '${_ad.text.trim()} ${_soyad.text.trim()}',
          sozlesmeOnayi: _sozlesme,
          ticariIleti: _ticariIleti,
        );
    if (!mounted) {
      return;
    }
    if (hata != null) {
      setState(() {
        _mesgul = false;
        _hata = hata;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  InputDecoration _alan(String etiket) => InputDecoration(
        labelText: etiket,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(RR.r13)),
      );

  Widget _rolSecimi() => Row(
        children: [
          for (final r in Role.values) ...[
            if (r != Role.values.first) const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: Text(
                  r == Role.customer ? 'Hizmet Almak' : 'Hizmet Vermek',
                  textAlign: TextAlign.center,
                ),
                selected: _rol == r,
                onSelected:
                    _mesgul ? null : (_) => setState(() => _rol = r),
              ),
            ),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  Text('HizmetCep Üyelik Koşulları',
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s25,
                          weight: RF.w700,
                          color: RC.text,
                          letterSpacing: RF.lsM03)),
                  const SizedBox(height: 8),
                  Text(
                    'Hesabınızı tamamlamak için aşağıdaki koşulları kabul edin.',
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s145,
                        weight: RF.w400,
                        color: RC.textSoft,
                        height: RF.lh145),
                  ),
                  const SizedBox(height: 20),
                  if ((widget.eposta ?? '').isNotEmpty) ...[
                    Text(
                      '${widget.saglayici.ad} hesabı: ${widget.eposta}',
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s13, weight: RF.w500, color: RC.textSoft),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_adGerekli) ...[
                  TextField(
                    controller: _ad,
                    enabled: !_mesgul,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => _fSoyad.requestFocus(),
                    onChanged: (_) => setState(() => _hata = null),
                    decoration: _alan('Ad *').copyWith(
                        errorText: _ad.text.trim().isEmpty
                            ? null
                            : Validators.name(_ad.text, min: 3, label: 'ad')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _soyad,
                    focusNode: _fSoyad,
                    enabled: !_mesgul,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                    onChanged: (_) => setState(() => _hata = null),
                    decoration: _alan('Soyad *').copyWith(
                        errorText: _soyad.text.trim().isEmpty
                            ? null
                            : Validators.name(_soyad.text,
                                min: 2, label: 'soyad')),
                  ),
                  const SizedBox(height: 4),
                  ],
                  if (widget.rol == null) ...[
                    const SizedBox(height: 16),
                    Text('HizmetCep\'i nasıl kullanacaksınız? *',
                        style: refText(
                            size: RF.s14, weight: RF.w700, color: RC.text)),
                    const SizedBox(height: 8),
                    _rolSecimi(),
                  ],
                  const SizedBox(height: 16),
                  KullanimSozlesmesiOnayi(
                    enabled: !_mesgul,
                    sozlesme: _sozlesme,
                    onSozlesme: (v) => setState(() => _sozlesme = v),
                    ticariIleti: _ticariIleti,
                    onTicariIleti: (v) => setState(() => _ticariIleti = v),
                  ),
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
                    'Hesabımı Oluştur',
                    busy: _mesgul,
                    onPressed: _tamam ? _kaydol : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
