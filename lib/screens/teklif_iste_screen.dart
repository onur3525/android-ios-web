import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api/storage_api.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_istediklerim_screen.dart';
import 'widgets/photo_picker.dart';

/// "DOĞRUDAN TEKLİF İSTE" — hizmet alan formu (Aşama A).
///
/// `SonuclarScreen`'de "Teklif İste" ile açılır. Hizmet ve hizmet
/// veren OTOMATİK GELİR — kullanıcı burada NE hizmet NE adres
/// seçer.
///
/// ⚠ MEVCUT "İlan Ver" (`CreateListingScreen`) İLE KARIŞTIRILMAZ:
/// bu form HERKESE AÇIK bir ilan ÜRETMEZ; talep yalnız seçilen TEK
/// hizmet verene gider. `CreateListingScreen`'e DOKUNULMADI; yalnız
/// görsel bileşenleri (`RefFormCard`, `ListingPhotoPicker`) GENUİNE
/// biçimde yeniden kullanıldı.
class TeklifIsteScreen extends StatefulWidget {
  const TeklifIsteScreen({
    super.key,
    required this.kategori,
    required this.hizmet,
    required this.saglayiciId,
    required this.saglayiciAdi,
  });

  final String kategori;
  final String hizmet;
  final String saglayiciId;
  /// ⚠ HAM AD — bu ekranda daima `maskeliAd()` ile GÖSTERİLİR: teklif
  /// henüz verilmedi, hizmet veren burada hâlâ maskelidir.
  final String saglayiciAdi;

  @override
  State<TeklifIsteScreen> createState() => _TeklifIsteScreenState();
}

class _TeklifIsteScreenState extends State<TeklifIsteScreen> {
  final _aciklama = TextEditingController();
  final List<PhotoItem> _photos = [];
  IletisimTercihi _iletisim = IletisimTercihi.yalnizMesaj;
  bool _gonderiliyor = false;

  late final StorageApi _storageApi;

  @override
  void initState() {
    super.initState();
    _storageApi = StorageApi(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  bool get _zorunlularDolu => _aciklama.text.trim().isNotEmpty;

  Future<void> _gonder() async {
    if (!_zorunlularDolu || _gonderiliyor) {
      return;
    }
    final me = context.read<AuthController>().currentAccount;
    if (me == null) {
      return;
    }
    setState(() => _gonderiliyor = true);
    final err = await context.read<TeklifTalebiController>().gonder(
          hizmetAlanId: me.id,
          saglayiciId: widget.saglayiciId,
          saglayiciAdi: widget.saglayiciAdi,
          kategori: widget.kategori,
          hizmet: widget.hizmet,
          aciklama: _aciklama.text.trim(),
          iletisimTercihi: _iletisim,
          fotograflar: _photos.map((p) => p.localPath).toList(),
        );
    if (!mounted) {
      return;
    }
    setState(() => _gonderiliyor = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    // ── ⚠ GÖNDERİLDİ MESAJI + "TEKLİF İSTEDİKLERİM"E GEÇİŞ ──
    //
    // Bul akışının tamamını (Hizmet Seç → Tarama → Sonuçlar → Form)
    // yığından kaldırır; kullanıcı formdan geri basınca sonuçlara
    // değil, kendi talep listesine döner.
    sysToastOk(context, 'Teklif isteğin hizmet verene gönderildi.');
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(
          builder: (_) => const TeklifIstediklerimScreen()),
      (r) => r.settings.name == '/customer/listings' || r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: RefBackButton(),
          ),
          const SizedBox(height: 4),
          RefPageTitle('Teklif İste', geriDugmesi: false),
          RefSubtitle('Talebin yalnız seçtiğin hizmet verene gönderilir.'),
          const SizedBox(height: 16),

          // ── SEÇİLİ HİZMET + HİZMET VEREN — SALT OKUNUR ──
          //
          // ⚠ `RefFormCard` — "İlan Ver" ekranındaki AYNI kart
          // bileşeni; yeni bir kutu tasarımı İCAT EDİLMEDİ.
          RefFormCard(
            marginTop: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seçili Hizmet',
                    style:
                        refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
                const SizedBox(height: 4),
                Text(widget.kategori,
                    style: refText(
                        size: RF.s115, weight: RF.w500, color: RC.textSoft)),
                Text(widget.hizmet,
                    style: refText(
                        size: 16.5, weight: RF.w700, color: RC.text)),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F3F6)),
                const SizedBox(height: 10),
                Text('Hizmet Veren',
                    style:
                        refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const RefSvg('assets/svg/ic_avlock.svg', size: 28),
                    const SizedBox(width: 8),
                    Text(maskeliAd(widget.saglayiciAdi),
                        style: refText(
                            size: RF.s145, weight: RF.w700, color: RC.text)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Açıklama',
              style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 6),
          Text('Ne istediğini hizmet verene anlat.',
              style:
                  refText(size: RF.s13, weight: RF.w400, color: RC.textSoft)),
          const SizedBox(height: 10),
          TextField(
            controller: _aciklama,
            onChanged: (_) => setState(() {}),
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Açıklama yazın.',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 12),
          Text('Fotoğraf (Opsiyonel)',
              style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 8),
          // ⚠ GENUİNE YENİDEN KULLANIM: "İlan Ver" ekranındaki AYNI
          // fotoğraf seçici bileşeni. `uploadEnabled: false` — bu
          // akış için gerçek yükleme UCU YOK; fotoğraf yalnız cihazda
          // tutulur (mock).
          ListingPhotoPicker(
            photos: _photos,
            storage: _storageApi,
            uploadEnabled: false,
            sade: true,
            onChanged: (next) => setState(() {
              _photos
                ..clear()
                ..addAll(next);
            }),
          ),

          const SizedBox(height: 20),
          Text('İletişim Tercihi',
              style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 8),
          _IletisimSecenegi(
            secili: _iletisim == IletisimTercihi.telefonGoster,
            baslik: 'Telefon numaramı göster',
            aciklama: 'Hizmet veren telefonla da ulaşabilir.',
            onTap: () =>
                setState(() => _iletisim = IletisimTercihi.telefonGoster),
          ),
          const SizedBox(height: 8),
          _IletisimSecenegi(
            secili: _iletisim == IletisimTercihi.yalnizMesaj,
            baslik: 'Sadece uygulama içi mesajlaşma',
            aciklama: 'Telefon numaran hizmet verene gösterilmez.',
            onTap: () =>
                setState(() => _iletisim = IletisimTercihi.yalnizMesaj),
          ),

          const SizedBox(height: 24),
          RefPrimaryButton(
            'Teklif İste',
            iconAsset: 'assets/svg/ic_send.svg',
            busy: _gonderiliyor,
            onPressed: _zorunlularDolu ? _gonder : null,
          ),
        ],
      ),
    );
  }
}

class _IletisimSecenegi extends StatelessWidget {
  const _IletisimSecenegi({
    required this.secili,
    required this.baslik,
    required this.aciklama,
    required this.onTap,
  });

  final bool secili;
  final String baslik;
  final String aciklama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RefTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: secili ? RC.blueSoft : RC.white,
          border: Border.all(
              color: secili ? RC.blue : const Color(0xFFECEEF2)),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secili ? RC.blue : RC.white,
                border: Border.all(
                    color: secili ? RC.blue : const Color(0xFFA8ADB4),
                    width: 2),
              ),
              child: secili
                  ? const Icon(Icons.check, size: 12, color: RC.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik,
                      style: refText(
                          size: RF.s135, weight: RF.w700, color: RC.text)),
                  const SizedBox(height: 2),
                  Text(aciklama,
                      style: refText(
                          size: RF.s12,
                          weight: RF.w400,
                          color: RC.textSoft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
