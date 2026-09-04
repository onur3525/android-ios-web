import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/telefon_bicimi.dart';
import '../core/theme.dart';
import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_talebi_sohbet_screen.dart';

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
    if (_gonderiliyor) {
      return;
    }
    final f = int.tryParse(_fiyat.text.trim());
    // ⚠ ÖNCEDEN: geçersiz girişte SESSİZCE hiçbir şey olmuyordu.
    // Şimdi kullanıcıya HANGİ alanın eksik/geçersiz olduğu söyleniyor.
    if (f == null || f <= 0) {
      sysToastKural(context, 'Geçerli bir fiyat girin.');
      return;
    }
    if (_cevap.text.trim().isEmpty) {
      sysToastKural(context, 'Teklifinizi açıklayan bir cevap yazın.');
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
            // ── KARŞI TARAF + KONUM + İLETİŞİM (telefon+mesaj) ──
            RefFormCard(
              marginTop: 0,
              child: _KarsiTarafBilgisi(
                talep: t,
                benSaglayiciMi: benSaglayiciMi,
                auth: auth,
              ),
            ),

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

/// Karşı tarafın maskeli kimliği + konum + iletişim.
///
/// ⚠ İLETİŞİM ARTIK SABİT KURAL: yalnız uygulama içi mesajlaşma —
/// telefon gösterme SEÇENEĞİ kaldırıldı (ürün kararı). Bu yüzden bu
/// widget'ın artık bir "onAra" (telefon arama) bağımlılığı YOK.
class _KarsiTarafBilgisi extends StatelessWidget {
  const _KarsiTarafBilgisi({
    required this.talep,
    required this.benSaglayiciMi,
    required this.auth,
  });

  final TeklifTalebi talep;
  final bool benSaglayiciMi;
  final AuthController auth;

  void _sohbeteGit(BuildContext context, String baslik) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TeklifTalebiSohbetScreen(
          talepId: talep.id,
          baslik: baslik,
        ),
      ),
    );
  }

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
      // ⚠ Telefon YALNIZ hizmet alan "Telefon numaramı göster"
      // SEÇTİYSE açılır — "Sadece uygulama içi mesajlaşma"
      // seçiliyse teklif verilse bile telefon HİÇ açılmaz.
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
          // ── ⚠ TELEFON + MESAJLAŞMA — YAN YANA, `offer_detail_
          // screen.dart`daki `_IletisimKutusu` İLE AYNI GÖRSEL DİL ──
          //
          // O sınıf dosyaya ÖZEL (private) olduğu için buraya AYNEN
          // yeniden oluşturuldu (bkz. `_MiniIletisimKutusu` altta) —
          // yeni bir tasarım İCAT EDİLMEDİ, var olan desen taşındı.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MiniIletisimKutusu(
                    ikon: 'assets/svg/ic_phone_f.svg',
                    etiket: 'Telefon',
                    deger: telefonAcik
                        ? _telefonGosterMetni(hizmetAlan?.phone)
                        : '05** *** ** **',
                    kilitli: !telefonAcik,
                    onTap: telefonAcik
                        ? () => _telefonAra(context, hizmetAlan?.phone)
                        : null,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: _MiniIletisimKutusu(
                    ikon: 'assets/svg/ic_chat.svg',
                    etiket: 'Mesajlaşma',
                    deger: acik
                        ? 'Mesaj yaz'
                        : 'Mesaj göndermek için teklif verin',
                    kilitli: !acik,
                    kucukDeger: !acik,
                    onTap: acik
                        ? () => _sohbeteGit(context, talep.hizmet)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── HİZMET ALAN GÖRÜNÜMÜ: hizmet veren TEKLİF VERENE KADAR
    // maskeli, sonra gerçek ad görünür. ──
    //
    // ⚠ YALNIZ MESAJLAŞMA KUTUSU: hizmet verenin telefonu bu akışta
    // HİÇ paylaşılmıyor (yalnız hizmet ALANIN tercihi var — bkz.
    // yukarısı) — bu yüzden burada Telefon kutusu YOK, iki kutuya
    // zorlanmadı.
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
        ] else ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F3F6)),
          const SizedBox(height: 10),
          _MiniIletisimKutusu(
            ikon: 'assets/svg/ic_chat.svg',
            etiket: 'Mesajlaşma',
            deger: 'Mesaj yaz',
            kilitli: false,
            onTap: () => _sohbeteGit(context, talep.hizmet),
          ),
        ],
      ],
    );
  }

  String _telefonGosterMetni(String? ham) {
    final d = Validators.phoneLocal(ham ?? '');
    if (d.isEmpty) return '—';
    return TelefonBicimlendirici.gruplu(d);
  }

  Future<void> _telefonAra(BuildContext context, String? ham) async {
    final d = Validators.phoneLocal(ham ?? '');
    if (d.isEmpty) return;
    final uri = Uri.parse('tel:$d');
    final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!acildi && context.mounted) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Arama uygulaması açılamadı');
    }
  }
}

/// ── ⚠ `offer_detail_screen.dart`'taki `_IletisimKutusu`nun AYNI
/// GÖRSEL DİLDE, sadeleştirilmiş yerel kopyası ──
///
/// Orijinal sınıf dosyaya özel (private) olduğu için import
/// EDİLEMEDİ; ikon dairesi, kilitli/açık durum ve tipografi BİREBİR
/// aynı tutuldu.
class _MiniIletisimKutusu extends StatelessWidget {
  const _MiniIletisimKutusu({
    required this.ikon,
    required this.etiket,
    required this.deger,
    required this.kilitli,
    this.kucukDeger = false,
    this.onTap,
  });

  final String ikon;
  final String etiket;
  final String deger;
  final bool kilitli;
  final bool kucukDeger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kutu = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: const Color(0xFFECEEF2)),
        borderRadius: BorderRadius.circular(RR.r11),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: RC.blueSoft,
              shape: BoxShape.circle,
            ),
            child: RefSvg(ikon, size: 17, color: RC.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(etiket,
                    style: refText(
                        size: RF.s12, weight: RF.w400, color: RC.textSoft)),
                const SizedBox(height: 2),
                Text(
                  deger,
                  maxLines: kucukDeger ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: kucukDeger
                      ? refText(
                          size: 11,
                          weight: RF.w500,
                          color: RC.text,
                          height: 1.35)
                      : refText(
                          size: RF.s14, weight: RF.w700, color: RC.text),
                ),
              ],
            ),
          ),
          if (kilitli)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.lock_outline, size: 15, color: RC.textSoft),
            ),
        ],
      ),
    );
    return onTap == null
        ? kutu
        : RefTap(
            onTap: onTap,
            borderRadius: BorderRadius.circular(RR.r11),
            child: kutu,
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
          textCapitalization: TextCapitalization.sentences,
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

