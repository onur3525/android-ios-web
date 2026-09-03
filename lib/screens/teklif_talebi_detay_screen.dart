import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;

/// TEKLİF TALEBİ DETAYI (Aşama E-L) — HEM hizmet alan HEM hizmet
/// veren bu ekranı görür; ROL, gösterilen alanları ve aksiyonları
/// belirler:
///
/// - `me.id == talep.saglayiciId` → HİZMET VEREN görünümü: talep
///   içeriği + fiyat/cevap girip "Teklif Ver" (bir kez, kilitlenir).
/// - `me.id == talep.hizmetAlanId` → HİZMET ALAN görünümü: gelen
///   teklifi görür, "Teklifi Seç"/"Reddet", 30 saatlik süre.
///
/// ⚠ MEVCUT `OfferDetailScreen`/`JobDetailScreen`E DOKUNULMADI — bu,
/// o ekranların kopyası DEĞİL; farklı bir modele (`TeklifTalebi`)
/// bakan YENİ ve ayrı bir ekran.
class TeklifTalebiDetayScreen extends StatefulWidget {
  const TeklifTalebiDetayScreen({super.key, required this.talepId});

  final String talepId;

  @override
  State<TeklifTalebiDetayScreen> createState() =>
      _TeklifTalebiDetayScreenState();
}

class _TeklifTalebiDetayScreenState extends State<TeklifTalebiDetayScreen> {
  final _fiyat = TextEditingController();
  final _cevap = TextEditingController();
  bool _gonderiliyor = false;

  /// ⚠ 30 SAATLİK GERİ SAYIM GÖRÜNTÜSÜNÜ TAZELEMEK İÇİN — süre
  /// GERÇEK `teklifTarihi`den hesaplanır (bkz. model); bu zamanlayıcı
  /// yalnız EKRANI dakikada bir yeniden çizer, süreyi UYDURMAZ.
  Timer? _tik;

  @override
  void initState() {
    super.initState();
    _tik = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tik?.cancel();
    _fiyat.dispose();
    _cevap.dispose();
    super.dispose();
  }

  Future<void> _teklifVer(TeklifTalebi t) async {
    final f = int.tryParse(_fiyat.text.trim());
    if (f == null || f <= 0 || _cevap.text.trim().isEmpty || _gonderiliyor) {
      return;
    }
    setState(() => _gonderiliyor = true);
    final err = await context.read<TeklifTalebiController>().teklifVer(t.id,
        fiyat: f, aciklama: _cevap.text.trim());
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    sysToastOk(context, 'Teklifiniz gönderildi.');
  }

  Future<void> _sec(TeklifTalebi t) async {
    final err = await context.read<TeklifTalebiController>().secToVer(t.id);
    if (!mounted) return;
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    sysToastOk(context, 'Teklif kabul edildi — iş aktif.');
  }

  Future<void> _reddet(TeklifTalebi t) async {
    final err = await context.read<TeklifTalebiController>().reddet(t.id);
    if (!mounted) return;
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
    }
  }

  Future<void> _tamamla(TeklifTalebi t) async {
    final err = await context.read<TeklifTalebiController>().tamamla(t.id);
    if (!mounted) return;
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    sysToastOk(context, 'İş tamamlandı olarak işaretlendi.');
  }

  Future<void> _telefonAra(String? ham) async {
    final d = Validators.phoneLocal(ham ?? '');
    if (d.isEmpty) return;
    final uri = Uri.parse('tel:$d');
    final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!acildi && mounted) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Arama uygulaması açılamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TeklifTalebiController>();
    final t = controller.byId(widget.talepId);
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;

    if (t == null || me == null) {
      return const Scaffold(
        backgroundColor: RC.white,
        body: SafeArea(child: Center(child: Text('Talep bulunamadı'))),
      );
    }

    final benSaglayiciMi = me.id == t.saglayiciId;

    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: RefBackButton(),
            ),
            const SizedBox(height: 4),
            RefPageTitle('Teklif Talebi', geriDugmesi: false),
            const SizedBox(height: 12),

            RefFormCard(
              marginTop: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.hizmet,
                      style: refText(
                          size: 16.5, weight: RF.w700, color: RC.text)),
                  Text(t.kategori,
                      style: refText(
                          size: RF.s115,
                          weight: RF.w500,
                          color: RC.textSoft)),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F3F6)),
                  const SizedBox(height: 10),
                  Text('Açıklama',
                      style: refText(
                          size: RF.s12, weight: RF.w400, color: RC.grey)),
                  const SizedBox(height: 4),
                  Text(t.aciklama,
                      style: refText(
                          size: RF.s14, weight: RF.w400, color: RC.text)),
                  if (t.fotograflar.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: t.fotograflar.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(RR.r12),
                          child: Image.file(File(t.fotograflar[i]),
                              width: 64, height: 64, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
            // ── KARŞI TARAF + KONUM + İLETİŞİM ──
            RefFormCard(
              marginTop: 0,
              child: _KarsiTarafBilgisi(
                talep: t,
                benSaglayiciMi: benSaglayiciMi,
                auth: auth,
                onAra: _telefonAra,
              ),
            ),

            // ── UYGULAMA İÇİ MESAJLAŞMA — TEKLİF VERİLDİYSE ──
            //
            // ⚠ Tek tetikleyici `teklifTarihi`: telefon tercihinden
            // BAĞIMSIZ olarak her zaman kullanılabilir kanaldır.
            // "Sadece uygulama içi mesajlaşma" seçiliyse TEK kanal
            // budur; "Telefon numaramı göster" seçiliyse EK kanaldır.
            if (t.teklifTarihi != null) ...[
              const SizedBox(height: 14),
              _Mesajlasma(talep: t, benId: me.id),
            ],

            const SizedBox(height: 20),
            if (benSaglayiciMi)
              _SaglayiciAksiyonlari(
                talep: t,
                fiyatController: _fiyat,
                cevapController: _cevap,
                gonderiliyor: _gonderiliyor,
                onTeklifVer: () => _teklifVer(t),
                onTamamla: () => _tamamla(t),
              )
            else
              _HizmetAlanAksiyonlari(
                talep: t,
                onSec: () => _sec(t),
                onReddet: () => _reddet(t),
              ),
          ],
        ),
      ),
    );
  }
}

/// Karşı tarafın maskeli kimliği + konum + iletişim tercihi.
class _KarsiTarafBilgisi extends StatelessWidget {
  const _KarsiTarafBilgisi({
    required this.talep,
    required this.benSaglayiciMi,
    required this.auth,
    required this.onAra,
  });

  final TeklifTalebi talep;
  final bool benSaglayiciMi;
  final AuthController auth;
  final void Function(String? phone) onAra;

  @override
  Widget build(BuildContext context) {
    // ── ⚠ MASKELEME KURALI (güncel): hizmet veren TEKLİF VERENE
    // KADAR iki taraf da birbirine maskelidir. `teklifTarihi`
    // dolduğu AN maskeleme İKİ TARAF İÇİN de kalkar — tek
    // tetikleyici budur (bkz. model dokümanı).
    final acik = talep.teklifTarihi != null;

    if (benSaglayiciMi) {
      final hizmetAlan = auth.accountById(talep.hizmetAlanId);
      final adGoster = acik
          ? (hizmetAlan?.name ?? 'Hizmet Alan')
          : maskeliAd(hizmetAlan?.name ?? 'Hizmet Alan');
      final telefonAcik =
          acik && talep.iletisimTercihi == IletisimTercihi.telefonGoster;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hizmet Alan',
              style: refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              acik
                  ? RefBasHarfAvatar(ad: adGoster)
                  : const RefSvg('assets/svg/ic_avlock.svg', size: 28),
              const SizedBox(width: 8),
              Text(adGoster,
                  style: refText(
                      size: RF.s145, weight: RF.w700, color: RC.text)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F3F6)),
          const SizedBox(height: 10),
          Text('Konum',
              style: refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              const RefSvg('assets/svg/ic_pin.svg',
                  size: 14, color: Color(0xFF98A2B3)),
              const SizedBox(width: 5),
              Text(
                  hizmetAlan?.address != null
                      ? '${hizmetAlan!.address!.district} / '
                          '${hizmetAlan.address!.city}'
                      : 'Belirtilmemiş',
                  style: refText(
                      size: RF.s13, weight: RF.w500, color: RC.text)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F3F6)),
          const SizedBox(height: 10),
          Text('İletişim Tercihi',
              style: refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
          const SizedBox(height: 4),
          if (!acik)
            Text(
                'Teklif verdiğinizde iletişim bilgileri ve mesajlaşma '
                'açılacak.',
                style: refText(
                    size: RF.s13, weight: RF.w500, color: RC.textSoft))
          else if (telefonAcik)
            RefTap(
              onTap: () => onAra(hizmetAlan?.phone),
              borderRadius: BorderRadius.circular(RR.r13),
              child: Row(
                children: [
                  const RefSvg('assets/svg/ic_phone.svg',
                      size: 15, color: RC.blue),
                  const SizedBox(width: 6),
                  Text(
                      hizmetAlan != null
                          ? '0${hizmetAlan.phone}'
                          : 'Telefon numarası göster',
                      style: refText(
                          size: RF.s135, weight: RF.w700, color: RC.blue)),
                ],
              ),
            )
          else
            Row(
              children: [
                const RefSvg('assets/svg/ic_chat.svg',
                    size: 15, color: Color(0xFF5B6472)),
                const SizedBox(width: 6),
                Text('Sadece uygulama içi mesajlaşma — telefon gizli',
                    style: refText(
                        size: RF.s13,
                        weight: RF.w500,
                        color: const Color(0xFF5B6472))),
              ],
            ),
        ],
      );
    }

    // ── HİZMET ALAN GÖRÜNÜMÜ: hizmet veren TEKLİF VERENE KADAR
    // maskeli, sonra gerçek ad görünür. ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            acik
                ? RefBasHarfAvatar(ad: talep.saglayiciAdi)
                : const RefSvg('assets/svg/ic_avlock.svg', size: 28),
            const SizedBox(width: 8),
            Text(acik ? talep.saglayiciAdi : maskeliAd(talep.saglayiciAdi),
                style:
                    refText(size: RF.s145, weight: RF.w700, color: RC.text)),
          ],
        ),
        if (!acik) ...[
          const SizedBox(height: 6),
          Text(
              'Hizmet veren teklif verdiğinde kimliği ve mesajlaşma '
              'açılacak.',
              style: refText(
                  size: RF.s12, weight: RF.w400, color: RC.textSoft)),
        ],
      ],
    );
  }
}

/// Hizmet veren aksiyonları: teklif ver / gönderildi / iş aktifse
/// tamamla.
class _SaglayiciAksiyonlari extends StatelessWidget {
  const _SaglayiciAksiyonlari({
    required this.talep,
    required this.fiyatController,
    required this.cevapController,
    required this.gonderiliyor,
    required this.onTeklifVer,
    required this.onTamamla,
  });

  final TeklifTalebi talep;
  final TextEditingController fiyatController;
  final TextEditingController cevapController;
  final bool gonderiliyor;
  final VoidCallback onTeklifVer;
  final VoidCallback onTamamla;

  @override
  Widget build(BuildContext context) {
    // ⚠ TEKLİF GÖNDERİLDİYSE — KİLİTLİ, SALT OKUNUR. "Teklifi
    // Düzenle" seçeneği YOKTUR (ürün kararı).
    if (talep.teklifTarihi != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RC.blueSoft,
              borderRadius: BorderRadius.circular(RR.r12),
            ),
            child: Row(
              children: [
                const RefSvg('assets/svg/ic_checkc.svg',
                    size: 18, color: RC.blue),
                const SizedBox(width: 8),
                Text('Teklifiniz gönderildi.',
                    style: refText(
                        size: RF.s135, weight: RF.w700, color: RC.text)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Fiyat',
              style: refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
          Text('${talep.teklifFiyati} TL',
              style:
                  refText(size: RF.s18, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 8),
          Text('Açıklamanız',
              style: refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
          Text(talep.teklifAciklamasi ?? '',
              style:
                  refText(size: RF.s14, weight: RF.w400, color: RC.text)),
          if (talep.durum == TeklifTalebiDurumu.secildi) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HC.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(RR.r12),
              ),
              child: Text('Teklif kabul edildi — iş aktif.',
                  style: refText(
                      size: RF.s135, weight: RF.w700, color: HC.green)),
            ),
            const SizedBox(height: 12),
            RefPrimaryButton('İşi Tamamlandı Olarak İşaretle',
                onPressed: onTamamla),
          ] else if (talep.durum == TeklifTalebiDurumu.tamamlandi) ...[
            const SizedBox(height: 16),
            Text('İş tamamlandı.',
                style:
                    refText(size: RF.s135, weight: RF.w700, color: RC.text)),
          ] else if (talep.durum == TeklifTalebiDurumu.reddedildi) ...[
            const SizedBox(height: 16),
            Text('Hizmet alan bu teklifi reddetti.',
                style: refText(
                    size: RF.s135, weight: RF.w500, color: RC.textSoft)),
          ] else if (talep.durum == TeklifTalebiDurumu.suresiDoldu) ...[
            const SizedBox(height: 16),
            Text('Teklifin süresi doldu.',
                style: refText(
                    size: RF.s135, weight: RF.w500, color: RC.textSoft)),
          ],
        ],
      );
    }

    // ── TEKLİF VERME FORMU ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fiyatınız (TL)',
            style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
        const SizedBox(height: 8),
        TextField(
          controller: fiyatController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Örn. 1500'),
        ),
        const SizedBox(height: 16),
        Text('Cevabınız',
            style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
        const SizedBox(height: 8),
        TextField(
          controller: cevapController,
          maxLines: 4,
          decoration:
              const InputDecoration(hintText: 'Teklifinizi açıklayın.'),
        ),
        const SizedBox(height: 20),
        RefPrimaryButton('Teklif Ver',
            busy: gonderiliyor, onPressed: onTeklifVer),
      ],
    );
  }
}

/// Hizmet alan aksiyonları: gelen teklifi gör, seç/reddet, 30 saat.
class _HizmetAlanAksiyonlari extends StatelessWidget {
  const _HizmetAlanAksiyonlari({
    required this.talep,
    required this.onSec,
    required this.onReddet,
  });

  final TeklifTalebi talep;
  final VoidCallback onSec;
  final VoidCallback onReddet;

  @override
  Widget build(BuildContext context) {
    switch (talep.durum) {
      case TeklifTalebiDurumu.beklemede:
        return Text('Hizmet verenin teklifi bekleniyor.',
            style:
                refText(size: RF.s135, weight: RF.w500, color: RC.textSoft));

      case TeklifTalebiDurumu.teklifGeldi:
        final kalan = talep.suresiDolacagiZaman?.difference(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fiyat',
                style:
                    refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
            Text('${talep.teklifFiyati} TL',
                style: refText(
                    size: RF.s18, weight: RF.w700, color: RC.text)),
            const SizedBox(height: 8),
            Text('Hizmet Verenin Açıklaması',
                style:
                    refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
            Text(talep.teklifAciklamasi ?? '',
                style:
                    refText(size: RF.s14, weight: RF.w400, color: RC.text)),
            const SizedBox(height: 10),
            if (kalan != null && kalan.inMinutes > 0)
              Text(
                  'Karar vermek için ${kalan.inHours} saat '
                  '${kalan.inMinutes % 60} dakikan var.',
                  style: refText(
                      size: RF.s12,
                      weight: RF.w500,
                      color: const Color(0xFFF5820C))),
            const SizedBox(height: 16),
            RefPrimaryButton('Teklifi Seç', onPressed: onSec),
            const SizedBox(height: 8),
            RefTap(
              onTap: onReddet,
              borderRadius: BorderRadius.circular(RR.r13),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFECEEF2)),
                  borderRadius: BorderRadius.circular(RR.r13),
                ),
                child: Text('Reddet',
                    style: refText(
                        size: RF.s14, weight: RF.w700, color: RC.textSoft)),
              ),
            ),
          ],
        );

      case TeklifTalebiDurumu.secildi:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HC.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(RR.r12),
          ),
          child: Text('Teklif Kabul Edildi — iş aktif.',
              style: refText(
                  size: RF.s135, weight: RF.w700, color: HC.green)),
        );

      case TeklifTalebiDurumu.reddedildi:
        return Text('Bu teklifi reddettin.',
            style:
                refText(size: RF.s135, weight: RF.w500, color: RC.textSoft));

      case TeklifTalebiDurumu.suresiDoldu:
        return Text('Teklifin süresi doldu — artık seçilemez.',
            style:
                refText(size: RF.s135, weight: RF.w500, color: RC.textSoft));

      case TeklifTalebiDurumu.tamamlandi:
        return Text('İş tamamlandı.',
            style:
                refText(size: RF.s135, weight: RF.w700, color: RC.text));
    }
  }
}

/// ── ⚠ UYGULAMA İÇİ MESAJLAŞMA — TEKLİF VERİLDİKTEN SONRA ──
///
/// Metin ve TEK fotoğraf gönderimi destekler. Mevcut sohbet sistemi
/// (`ChatController`) `Listing`/`Offer` kimliğine bağlıdır ve bu YENİ
/// modele (`TeklifTalebi`) DOKUNULMADAN bağlanamaz; bu yüzden
/// mesajlar `TeklifTalebi.mesajlar` üzerinde, KENDİ bağımsız
/// zincirinde tutulur — `ChatController`a DOKUNULMADI.
///
/// Fotoğraf seçimi `image_picker` ile DOĞRUDAN yapılır (`ListingPhotoPicker`
/// çoklu-seçim/yükleme akışı için tasarlanmıştı; burada tek dosya anlık
/// gönderim ihtiyacı farklı, bu yüzden o bileşen ZORLA uydurulmadı).
class _Mesajlasma extends StatefulWidget {
  const _Mesajlasma({required this.talep, required this.benId});

  final TeklifTalebi talep;
  final String benId;

  @override
  State<_Mesajlasma> createState() => _MesajlasmaState();
}

class _MesajlasmaState extends State<_Mesajlasma> {
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
    setState(() => _gonderiliyor = true);
    final err = await context.read<TeklifTalebiController>().mesajGonder(
          widget.talep.id,
          gonderenId: widget.benId,
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
    final mesajlar = widget.talep.mesajlar;
    return RefFormCard(
      marginTop: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mesajlaşma',
              style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 8),
          if (mesajlar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Henüz mesaj yok.',
                  style: refText(
                      size: RF.s13, weight: RF.w400, color: RC.textSoft)),
            )
          else
            Column(
              children: [
                for (final m in mesajlar) _MesajBalonu(m, widget.benId),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              RefTap(
                onTap: _gonderiliyor ? null : _fotografSecVeGonder,
                borderRadius: BorderRadius.circular(RR.circle),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: RefSvg('assets/svg/ic_cam.svg',
                      size: 20, color: RC.blue),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _metin,
                  enabled: !_gonderiliyor,
                  decoration: const InputDecoration(hintText: 'Mesaj yaz...'),
                  onSubmitted: (_) => _gonder(),
                ),
              ),
              RefTap(
                onTap: _gonderiliyor ? null : () => _gonder(),
                borderRadius: BorderRadius.circular(RR.circle),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: RefSvg('assets/svg/ic_send.svg',
                      size: 20,
                      color: _gonderiliyor ? RC.textSoft : RC.blue),
                ),
              ),
            ],
          ),
        ],
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
        constraints: const BoxConstraints(maxWidth: 240),
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
                    width: 160, height: 160, fit: BoxFit.cover),
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
