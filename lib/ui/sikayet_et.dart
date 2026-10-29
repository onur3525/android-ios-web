import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/remote/api/sikayet_api.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/api_error_mapper.dart';
import 'alt_panel.dart';
import 'ref_tokens.dart';
import 'ref_widgets.dart';

export '../data/remote/api/sikayet_api.dart' show SikayetHedefi;

/// ═══════════════════════════════════════════════════════════════
/// ŞİKÂYET ET — TEK KAYNAK (29 Eki, TASLAK)
///
/// İlan detayı (hizmet verenin gördüğü ilan), teklif detayı (hizmet
/// alanın gördüğü hizmet veren profili) ve yorum kartı AYNI bileşeni
/// kullanır. Panel: neden (Dolandırıcılık / Hakaret / Yanıltıcı Bilgi /
/// Diğer) + isteğe bağlı açıklama ("Diğer"de zorunlu, en az 10 karakter).
///
/// ⚠ Kendi içeriğinde düğme ÇİZİLMEZ ([sahipId] oturumdaki kişiyse).
/// ⚠ Başarı bildirimi panelin İÇİNDE gösterilir (`sysToastOk` bilerek
///   sessizdir; kullanıcı şikâyetin alındığını görmeli).
/// ⚠ Mock modda ağ yoktur: panel aynı akışla "alındı" gösterir.
/// ═══════════════════════════════════════════════════════════════
class SikayetEtDugmesi extends StatelessWidget {
  const SikayetEtDugmesi({
    super.key,
    required this.hedef,
    required this.hedefId,
    this.sahipId,
    this.etiket = 'Şikâyet Et',
  });

  final SikayetHedefi hedef;
  final String hedefId;

  /// İçeriğin sahibi; oturumdaki kişiyse düğme gizlenir.
  final String? sahipId;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    final ben = context.watch<AuthController?>()?.currentAccount?.id;
    if (ben == null || (sahipId != null && sahipId == ben)) {
      return const SizedBox.shrink();
    }
    return RefTap(
      key: ValueKey('sikayet-${hedef.api}-$hedefId'),
      borderRadius: BorderRadius.circular(RR.r8),
      onTap: () => sikayetPaneliAc(context, hedef: hedef, hedefId: hedefId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.outlined_flag, size: 16, color: RC.textSoft),
          const SizedBox(width: 4),
          Text(etiket,
              style: refText(size: RF.s125, weight: RF.w500, color: RC.textSoft)),
        ]),
      ),
    );
  }
}

/// Şikâyet panelini açar (web'de ortada, mobilde alttan — `altPanelGoster`).
Future<void> sikayetPaneliAc(BuildContext context,
    {required SikayetHedefi hedef, required String hedefId}) {
  final istemci = ApiConfig.useRealApi ? context.read<ApiClient?>() : null;
  return altPanelGoster<void>(
    context: context,
    builder: (_) => SikayetPaneli(
      hedef: hedef,
      gonderici: (neden, aciklama) async {
        if (istemci == null) {
          return null; // mock mod: ağ yok
        }
        try {
          await SikayetApi(istemci).gonder(
              hedef: hedef, hedefId: hedefId, neden: neden, aciklama: aciklama);
          return null;
        } on ApiFailure catch (e) {
          return e.error.message;
        } catch (_) {
          return 'Şikâyet gönderilemedi. Lütfen tekrar deneyin.';
        }
      },
    ),
  );
}

/// Gönderici: hata metni döner; başarıda `null`.
typedef SikayetGonderici = Future<String?> Function(
    SikayetNedeni neden, String aciklama);

class SikayetPaneli extends StatefulWidget {
  const SikayetPaneli({super.key, required this.hedef, required this.gonderici});

  final SikayetHedefi hedef;
  final SikayetGonderici gonderici;

  static const int aciklamaEnFazla = 500;
  static const int digerEnAz = 10;

  @override
  State<SikayetPaneli> createState() => _SikayetPaneliState();
}

class _SikayetPaneliState extends State<SikayetPaneli> {
  SikayetNedeni? _neden;
  final _aciklama = TextEditingController();
  bool _gonderiliyor = false;
  bool _alindi = false;
  String? _hata;

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  String get _baslikAlti => switch (widget.hedef) {
        SikayetHedefi.ilan => 'Bu ilanı neden şikâyet ediyorsunuz?',
        SikayetHedefi.kullanici => 'Bu kullanıcıyı neden şikâyet ediyorsunuz?',
        SikayetHedefi.yorum => 'Bu yorumu neden şikâyet ediyorsunuz?',
      };

  String? get _dogrulama {
    if (_neden == null) {
      return 'Bir neden seçiniz';
    }
    final n = _aciklama.text.trim().length;
    if (_neden == SikayetNedeni.diger && n < SikayetPaneli.digerEnAz) {
      return '"Diğer" için kısa bir açıklama yazınız (en az ${SikayetPaneli.digerEnAz} karakter)';
    }
    return null;
  }

  Future<void> _gonder() async {
    final d = _dogrulama;
    if (d != null) {
      setState(() => _hata = d);
      return;
    }
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    final hata = await widget.gonderici(_neden!, _aciklama.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _gonderiliyor = false;
      _hata = hata;
      _alindi = hata == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alt = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + alt),
      child: SingleChildScrollView(
        child: _alindi ? _alindiGorunumu(context) : _form(),
      ),
    );
  }

  Widget _alindiGorunumu(BuildContext context) => Column(
        key: const ValueKey('sikayet-alindi'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Şikâyetiniz alındı',
              style: refText(size: RF.s17, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 8),
          Text(
              'Ekibimiz inceleyecek. Kurallara aykırı bulunan içerik kaldırılır. '
              'Kimliğiniz şikâyet edilen kişiyle paylaşılmaz.',
              style: refText(
                  size: RF.s135, color: RC.textSoft, height: RF.lh150)),
          const SizedBox(height: 18),
          RefPrimaryButton('Kapat', onPressed: () => Navigator.of(context).pop()),
        ],
      );

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Şikâyet Et',
              style: refText(size: RF.s17, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 4),
          Text(_baslikAlti,
              style: refText(size: RF.s135, color: RC.textSoft)),
          const SizedBox(height: 12),
          for (final n in SikayetNedeni.values)
            RefTap(
              key: ValueKey('sikayet-neden-${n.api}'),
              borderRadius: BorderRadius.circular(RR.r10),
              onTap: _gonderiliyor
                  ? null
                  : () => setState(() {
                        _neden = n;
                        _hata = null;
                      }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                child: Row(children: [
                  Icon(
                      _neden == n
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _neden == n ? RC.blue : RC.greyLight),
                  const SizedBox(width: 10),
                  Text(n.etiket,
                      style: refText(size: RF.s145, weight: RF.w500, color: RC.text)),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          RefTextField(
            key: const ValueKey('sikayet-aciklama'),
            controller: _aciklama,
            hint: 'Açıklama',
            yerTutucu: _neden == SikayetNedeni.diger
                ? 'Lütfen kısaca açıklayın'
                : 'İsterseniz kısaca açıklayın',
            zorunlu: _neden == SikayetNedeni.diger,
            enabled: !_gonderiliyor,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            inputFormatters: [
              LengthLimitingTextInputFormatter(SikayetPaneli.aciklamaEnFazla),
            ],
            onChanged: (_) {
              if (_hata != null) {
                setState(() => _hata = null);
              }
            },
          ),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_hata!,
                  style: refText(size: RF.s13, weight: RF.w500, color: RC.danger)),
            ),
          const SizedBox(height: 16),
          RefPrimaryButton('Gönder', busy: _gonderiliyor, onPressed: _gonder),
        ],
      );
}
