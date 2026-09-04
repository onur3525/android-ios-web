import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// "TEKLİF TALEBİ" SOHBETİ — AYRI EKRAN.
///
/// ⚠ ÖNCEDEN detay ekranına GÖMÜLÜYDÜ (inline kutu, her zaman
/// açık). Artık `TeklifTalebiDetayScreen`deki "Mesajlaşma" kutusuna
/// dokununca BURAYA gelinir — `offer_detail_screen.dart`daki
/// `_IletisimKutusu` → `ChatScreen` deseniyle AYNI mantık: kart bir
/// ÖNİZLEME/GİRİŞ NOKTASI, gerçek sohbet kendi ekranındadır.
///
/// Metin ve TEK fotoğraf gönderimi destekler. Mevcut sohbet sistemi
/// (`ChatController`) `Listing`/`Offer` kimliğine bağlıdır ve bu YENİ
/// modele (`TeklifTalebi`) DOKUNULMADAN bağlanamaz; bu yüzden
/// mesajlar `TeklifTalebi.mesajlar` üzerinde, KENDİ bağımsız
/// zincirinde tutulur — `ChatController`a DOKUNULMADI.
///
/// Fotoğraf seçimi `image_picker` ile DOĞRUDAN yapılır
/// (`ListingPhotoPicker` çoklu-seçim/yükleme akışı için
/// tasarlanmıştı; burada tek dosya anlık gönderim ihtiyacı farklı,
/// bu yüzden o bileşen ZORLA uydurulmadı).
class TeklifTalebiSohbetScreen extends StatefulWidget {
  const TeklifTalebiSohbetScreen({
    super.key,
    required this.talepId,
    required this.baslik,
  });

  final String talepId;

  /// Üst bardaki başlık — çağıran ekran "hizmet" ya da "karşı taraf
  /// adı" geçirir; bu ekran o kararı VERMEZ.
  final String baslik;

  @override
  State<TeklifTalebiSohbetScreen> createState() =>
      _TeklifTalebiSohbetScreenState();
}

class _TeklifTalebiSohbetScreenState extends State<TeklifTalebiSohbetScreen> {
  final _metin = TextEditingController();
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _gonder({String? fotografYolu}) async {
    final t = _metin.text.trim();
    if (t.isEmpty && fotografYolu == null) return;
    final me = context.read<AuthController>().currentAccount;
    if (me == null) return;
    setState(() => _gonderiliyor = true);
    final err = await context.read<TeklifTalebiController>().mesajGonder(
          widget.talepId,
          gonderenId: me.id,
          metin: t.isEmpty ? null : t,
          fotografYolu: fotografYolu,
        );
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    _metin.clear();
  }

  Future<void> _fotografSecVeGonder() async {
    final secilen =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (secilen == null) return;
    await _gonder(fotografYolu: secilen.path);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentAccount;
    final talep =
        context.watch<TeklifTalebiController>().byId(widget.talepId);
    final mesajlar = talep?.mesajlar ?? const <TeklifMesaj>[];

    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  const RefBackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s16, weight: RF.w700, color: RC.text)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECEEF2)),
            Expanded(
              child: mesajlar.isEmpty
                  ? Center(
                      child: Text('Henüz mesaj yok.',
                          style: refText(
                              size: RF.s14,
                              weight: RF.w400,
                              color: RC.textSoft)),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        for (final m in mesajlar)
                          _MesajBalonu(m, me?.id ?? ''),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    RefTap(
                      onTap: _gonderiliyor ? null : _fotografSecVeGonder,
                      borderRadius: BorderRadius.circular(RR.circle),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: RefSvg('assets/svg/ic_cam.svg',
                            size: 22, color: RC.blue),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _metin,
                        enabled: !_gonderiliyor,
                        textCapitalization: TextCapitalization.sentences,
                        decoration:
                            const InputDecoration(hintText: 'Mesaj yaz...'),
                        onSubmitted: (_) => _gonder(),
                      ),
                    ),
                    RefTap(
                      onTap: _gonderiliyor ? null : () => _gonder(),
                      borderRadius: BorderRadius.circular(RR.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: RefSvg('assets/svg/ic_send.svg',
                            size: 22,
                            color: _gonderiliyor ? RC.textSoft : RC.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MesajBalonu extends StatelessWidget {
  const _MesajBalonu(this.mesaj, this.benId);

  final TeklifMesaj mesaj;
  final String benId;

  @override
  Widget build(BuildContext context) {
    final benim = mesaj.gonderenId == benId;
    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: benim ? RC.blueSoft : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(RR.r12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mesaj.fotografYolu != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(RR.r12),
                child: Image.file(File(mesaj.fotografYolu!),
                    width: 180, height: 180, fit: BoxFit.cover),
              ),
            if (mesaj.metin != null)
              Padding(
                padding: EdgeInsets.only(
                    top: mesaj.fotografYolu != null ? 6 : 0),
                child: Text(mesaj.metin!,
                    style: refText(
                        size: RF.s135, weight: RF.w400, color: RC.text)),
              ),
          ],
        ),
      ),
    );
  }
}
