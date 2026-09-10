import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/telefon_bicimi.dart';
import '../core/tutar_bicimi.dart';
import '../domain/hizmet_alan_ozeti.dart';
import '../core/theme.dart';
import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'provider_reviews_screen.dart';
import 'teklif_talebi_sohbet_screen.dart';
import 'teklif_talebi_yorum_screen.dart';
// ⚠ Rozet ORTAK bileşendir — ilan akışıyla aynı ölçü/renk için
// kopya çizim yapılmaz, bileşenin kendisi kullanılır.
// ⚠ Tam ekran fotoğraf görüntüleyici ORTAK bileşendir — ilan
// akışıyla aynı davranış için kopya yazılmaz.
import 'widgets/foto_goruntuleyici.dart';
import 'widgets/is_zamani_secici.dart';

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
    // ⚠ `int.tryParse` DEĞİL: alanda binlik ayracı var ("3.000"),
    // doğrudan çözümlenirse null döner ve geçerli fiyat reddedilirdi.
    final f = tutarOku(_fiyat.text);
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

  // ⚠ DÜZELTİLDİ — kullanıcı isteği: "Bul" akışında (`TeklifTalebi`)
  // normal İlan Ver akışındaki gibi ayrı bir "işi tamamla" adımı YOK
  // — hizmet alan teklifi seçtiği anda iş, uygulama için TAMAMLANMIŞ
  // sayılır (tek adımda "Kazandığım"a/"Tamamlanan İşler"e geçer).
  // Bu yüzden `secToVer` hemen ardından `tamamla` da çağrılır; UI
  // tarafında da "Teklifi Seç" butonu bu andan sonra "Yorum Yaz"a
  // dönüşür (bkz. `_HizmetAlanAksiyonlari.build()`).
  Future<void> _sec(TeklifTalebi t) async {
    final ctl = context.read<TeklifTalebiController>();
    final err = await ctl.secToVer(t.id);
    if (!mounted) return;
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    final err2 = await ctl.tamamla(t.id);
    if (!mounted) return;
    if (err2 != null) {
      sysToastErr(context, SysKind.genericError, extra: err2.message);
      return;
    }
    sysToastOk(context, 'Teklif kabul edildi — iş tamamlandı.');
  }

  Future<void> _reddet(TeklifTalebi t, {String? gerekce}) async {
    final err = await context
        .read<TeklifTalebiController>()
        .reddet(t.id, gerekce: gerekce);
    if (!mounted) return;
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
    }
  }

  // ── ⚠ "3 NOKTA → TALEBİ SİL" — `listing_detail_screen.dart`daki
  // "İlanı neden siliyorsunuz?" DESENİYLE AYNI (bottom sheet menü →
  // onay → hazır gerekçe listesi → "Diğer" ise serbest metin).
  // O ekranın private metotları BURAYA import EDİLEMEDİ, aynı genel
  // bileşenler (`RefBottomSheet`, `RefSerbestNedenSayfasi`) yeniden
  // kullanılarak BİREBİR aynı akış burada YENİDEN kuruldu.
  static const _kTalepSilmeNedenleri = [
    'İhtiyacım kalmadı / vazgeçtim',
    'Dışarıdan biri ile anlaştım',
    'Yanlış hizmet için talep oluşturdum',
    'Gelen teklif uygun değildi',
    'Diğer',
  ];

  Future<void> _talepMenusu(TeklifTalebi t) async {
    final sil = await RefBottomSheet.goster<bool>(
      context,
      title: 'Talep Seçenekleri',
      child: RefTap(
        onTap: () => Navigator.of(context).pop(true),
        borderRadius: BorderRadius.circular(RR.r12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(children: [
            const RefSvg('assets/svg/ic_trash.svg', size: 18, color: RC.danger),
            const SizedBox(width: 10),
            Text('Talebi Sil',
                style: refText(
                    size: RF.s145, weight: RF.w700, color: RC.danger)),
          ]),
        ),
      ),
    );
    if (sil != true || !mounted) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Talep silinsin mi?',
            style: refText(size: RF.s17, weight: RF.w700, color: RC.text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Sil',
                style: refText(
                    size: RF.s145, weight: RF.w700, color: RC.danger)),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    final neden = await RefBottomSheet.goster<String>(
      context,
      title: 'Talebi neden siliyorsun?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _kTalepSilmeNedenleri)
            RefTap(
              onTap: () => Navigator.of(context).pop(r),
              borderRadius: BorderRadius.circular(RR.r12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(r,
                        style: refText(
                            size: RF.s145,
                            weight: RF.w500,
                            color: RC.text)),
                  ),
                  const RefSvg('assets/svg/ic_chev.svg',
                      size: 18, color: Color(0xFFD3D8E0)),
                ]),
              ),
            ),
        ],
      ),
    );
    if (neden == null || !mounted) return;

    var gerekce = neden;
    if (neden == 'Diğer') {
      final metin = await RefBottomSheet.goster<String>(
        context,
        title: 'Silme nedeniniz',
        child: const RefSerbestNedenSayfasi(
          baslik: 'Silme nedeniniz',
          aciklama: 'Talebi neden sildiğinizi kısaca yazın. Bu açıklama '
              'HizmetCep yönetimine iletilir ve hizmet kalitesini '
              'iyileştirmek için kullanılır.',
          ipucu: 'Örn. Taşındığım için ihtiyacım kalmadı',
        ),
      );
      if (metin == null || metin.trim().isEmpty || !mounted) return;
      gerekce = 'Diğer: ${metin.trim()}';
    }

    await _reddet(t, gerekce: gerekce);
    if (!mounted) return;
    sysToastOk(context, 'Talep silindi.');
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
                  // ── ⚠ BÖLÜM SIRASI (kullanıcı kararı, 9 Eyl) ──
                  //
                  //   Hizmet / Kategori
                  //   Hizmet Zamanı   → rozet
                  //   Açıklama        → metin
                  //   Fotoğraflar     → şerit
                  //
                  // ⚠ FOTOĞRAFLAR AÇIKLAMANIN İÇİNDEN ÇIKARILDI:
                  // önceden açıklama metninin hemen altına, aynı
                  // bölümün içine çiziliyordu ve başlıksızdı —
                  // açıklamanın parçası gibi duruyordu. Artık KENDİ
                  // başlığı olan ayrı bir bölüm.
                  //
                  // ⚠ BAŞLIK BİÇİMİ TEK: üç bölüm başlığı da
                  // (`Hizmet Zamanı`, `Açıklama`, `Fotoğraflar`) aynı
                  // 12/w400/`RC.grey` ile çizilir; biri değişirse
                  // ötekiler de değişmeli.
                  //
                  // ⚠ BOŞ BÖLÜM ÇİZİLMEZ: zaman seçilmemişse ya da
                  // fotoğraf yoksa o bölüm başlığıyla birlikte HİÇ
                  // görünmez — sahipsiz başlık bırakılmaz.
                  if (t.isZamani != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F3F6)),
                    const SizedBox(height: 10),
                    Text('Hizmet Zamanı',
                        style: refText(
                            size: RF.s12, weight: RF.w400, color: RC.grey)),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      // ⚠ AYNI BİLEŞEN: `IsZamaniRozeti` — ilan
                      // akışındaki rozetle birebir aynı ölçü ve renk;
                      // "Acil" burada da KIRMIZI çıkar.
                      child: IsZamaniRozeti(t.isZamani),
                    ),
                  ],

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
                    const Divider(height: 1, color: Color(0xFFF1F3F6)),
                    const SizedBox(height: 10),
                    Text('Fotoğraflar',
                        style: refText(
                            size: RF.s12, weight: RF.w400, color: RC.grey)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: t.fotograflar.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        // ⚠ FOTOĞRAFA DOKUNUNCA TAM EKRAN AÇILIR:
                        // ilan akışının kullandığı AYNI bileşen
                        // (`FotoGoruntuleyici`). Tüm liste verilir,
                        // `baslangic: i` ile dokunulandan açılır.
                        itemBuilder: (_, i) => RefTap(
                          onTap: () => FotoGoruntuleyici.ac(context,
                              yollar: t.fotograflar, baslangic: i),
                          borderRadius: BorderRadius.circular(RR.r12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(RR.r12),
                            child: Image.file(File(t.fotograflar[i]),
                                width: 64, height: 64, fit: BoxFit.cover),
                          ),
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
                onMenuAc: () => _talepMenusu(t),
                onYorumYaz: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            TeklifTalebiYorumScreen(talep: t))),
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
          // ── ⚠ YENİ — HİZMET ALANIN TAMAMLANAN İŞ SAYISI + ÜYELİK
          // TARİHİ ──
          //
          // Kullanıcı isteği: hizmet veren, teklif verirken karşı
          // tarafın (hizmet alanın) GEÇMİŞİNİ de görebilmeli — kaç
          // iş tamamlatmış, ne zamandır üye. İki akıştaki (normal
          // İlan Ver + doğrudan Bul) tamamlanan işler TOPLANIR, tek
          // bir sayı gösterilir.
          Builder(builder: (context) {
            final tamamlanan =
                _hizmetAlanTamamlananIs(context, talep.hizmetAlanId);
            final uyelikMetni = hizmetAlan == null
                ? null
                : _uyelikTarihiMetni(hizmetAlan.kayitTarihi);
            return Row(
              children: [
                const RefSvg('assets/svg/ic_briefcase.svg',
                    size: 14, color: Color(0xFF5B6472)),
                const SizedBox(width: 5),
                Text('$tamamlanan iş tamamladı',
                    style: refText(
                        size: RF.s13,
                        weight: RF.w500,
                        color: const Color(0xFF5B6472))),
                if (uyelikMetni != null) ...[
                  const SizedBox(width: 10),
                  Text('•',
                      style: refText(
                          size: RF.s13, weight: RF.w500, color: RC.grey)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(uyelikMetni,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s13,
                            weight: RF.w500,
                            color: const Color(0xFF5B6472))),
                  ),
                ],
              ],
            );
          }),
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
                    // ⚠ KİLİTLİYKEN `deger: null` — Mesajlaşma
                    // kutusuyla TUTARLI (job_detail_screen.dart'taki
                    // AYNI düzeltme): ikisi de yalnız `not` gösterir.
                    deger: telefonAcik
                        ? _telefonGosterMetni(hizmetAlan?.phone)
                        : null,
                    not: telefonAcik
                        ? null
                        : 'Kilitli',
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
                    deger: acik ? 'Mesaj yaz' : null,
                    not: acik
                        ? null
                        : 'Kilitli',
                    kilitli: !acik,
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
        // ── ⚠ HİZMET VEREN KARTI — `sonuclar_screen.dart`/
        // `teklif_iste_screen.dart`daki AYNI TAM kart düzeni ──
        //
        // ÖNCEDEN yalnız avatar+isim+"Yorumları Gör" linkiydi.
        // İstatistikler (puan/yorum/iş) kimlik hâlâ MASKELİYKEN bile
        // gösterilir — diğer ekranlarla AYNI ilke, hizmet alan teklif
        // gelmeden önce de hizmet verenin geçmişini görebilmeli.
        Builder(builder: (context) {
          final reviews = context.watch<ReviewController>();
          final puan = reviews.averageOf(talep.saglayiciId);
          final yorumlar = reviews.byProvider(talep.saglayiciId);
          final tamamlanan = _tamamlananIsGercek(context, talep.saglayiciId);
          final hesap =
              context.read<AuthController>().accountById(talep.saglayiciId);
          // ⚠ DÜZELTİLDİ — bkz. `teklif_iste_screen.dart`daki AYNI not:
          // önceden kişisel adres kullanılıyordu, `sonuclar_screen.
          // dart`daki kartla FARKLI konum gösteriyordu.
          final konum = hesap == null || hesap.serviceDistricts.isEmpty
              ? null
              : '${hesap.serviceDistricts.first} / ${hesap.address?.city ?? ''}';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              acik
                  ? RefBasHarfAvatar(ad: talep.saglayiciAdi)
                  : const RefSvg('assets/svg/ic_avlock.svg', size: 46),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        acik
                            ? talep.saglayiciAdi
                            : maskeliAd(talep.saglayiciAdi),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s145,
                            weight: RF.w700,
                            color: RC.text)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const RefSvg('assets/svg/ic_starfill.svg',
                            size: 14, color: Color(0xFFF5A319)),
                        const SizedBox(width: 4),
                        Text(puan == null ? '—' : puan.toStringAsFixed(1),
                            style: refText(
                                size: RF.s125,
                                weight: RF.w700,
                                color: RC.text)),
                        const SizedBox(width: 4),
                        Text('(${yorumlar.length} yorum)',
                            style: refText(
                                size: RF.s12,
                                weight: RF.w400,
                                color: RC.textSoft)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const RefSvg('assets/svg/ic_briefcase.svg',
                            size: 13, color: Color(0xFF5B6472)),
                        const SizedBox(width: 5),
                        Text('$tamamlanan iş tamamladı',
                            style: refText(
                                size: RF.s12,
                                weight: RF.w400,
                                color: const Color(0xFF5B6472))),
                      ],
                    ),
                    if (konum != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const RefSvg('assets/svg/ic_pin.svg',
                              size: 14, color: Color(0xFF98A2B3)),
                          const SizedBox(width: 5),
                          Text(konum,
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w400,
                                  color: const Color(0xFF98A2B3))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),

        // ── ⚠ YORUMLAR — AYRI KART, `teklif_iste_screen.dart`daki
        // AYNI düzen: son 3 yorum, "Tümünü Gör" ──
        //
        // ⚠ Kimlik maskeliyken "Tümünü Gör" GİZLENİR — gerçek
        // `saglayiciId`ye bağlı bir ekrana gitmek kimliği dolaylı
        // yoldan İFŞA ederdi.
        //
        // ⚠ ARTIK YORUM YOKKEN DE GÖRÜNÜR — bkz. `teklif_iste_screen.
        // dart`daki AYNI düzeltme.
        //
        // ⚠ DIŞ ÇERÇEVE KALDIRILDI (kullanıcı bulgusu) — `YorumKarti`
        // ZATEN kendi çerçeveli kartını çiziyordu; bunu BİR DE dış
        // bir kutunun içine koymak "kart içinde kart", sıkışık bir
        // görünüm yaratıyordu. "Yorumlar" başlığı artık ORTALI,
        // "Tümünü Gör" artık SAĞA yaslı.
        Builder(builder: (context) {
          final reviews = context.watch<ReviewController>();
          final yorumlar = reviews.byProvider(talep.saglayiciId);
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Yorumlar',
                    textAlign: TextAlign.center,
                    style: refText(
                        size: RF.s16, weight: RF.w700, color: RC.text)),
                const SizedBox(height: 10),
                if (yorumlar.isEmpty)
                  Text('Henüz yorum yok.',
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s13,
                          weight: RF.w400,
                          color: RC.textSoft))
                else ...[
                  for (final r in yorumlar.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: YorumKarti(
                        review: r,
                        yazarAdi: context
                            .read<AuthController>()
                            .accountById(r.authorId)
                            ?.name,
                      ),
                    ),
                  if (acik && yorumlar.length > 3)
                    Align(
                      alignment: Alignment.centerRight,
                      child: RefTap(
                        onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => ProviderReviewsScreen(
                                    providerId: talep.saglayiciId,
                                    providerAdi: talep.saglayiciAdi))),
                        borderRadius: BorderRadius.circular(RR.r8),
                        child: Text('Tümünü Gör (${yorumlar.length})',
                            style: refText(
                                size: RF.s13,
                                weight: RF.w700,
                                color: RC.blue)),
                      ),
                    ),
                ],
              ],
            ),
          );
        }),
        // ── ⚠ TELEFON + MESAJLAŞMA — YAN YANA, PROVİDER TARAFINDAKİ
        // `_MiniIletisimKutusu` İLE AYNI KUTULAR (sıfırdan YAPILMADI,
        // aynı bileşen yeniden kullanıldı) ──
        //
        // ⚠ TELEFON HER ZAMAN KİLİTLİ KALIR: hizmet verenin telefonu
        // bu akışta HİÇ paylaşılmıyor (yalnız hizmet ALANIN tercihi
        // var — sağlayıcı tarafındaki kutuda). Mesajlaşma ise
        // `teklifTarihi` dolana kadar kilitli, doldu andan itibaren
        // açık.
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF1F3F6)),
        const SizedBox(height: 10),
        if (!acik)
          Text(
              'Hizmet veren teklif verdiğinde kimliği ve mesajlaşma '
              'açılacak.',
              style: refText(
                  size: RF.s12, weight: RF.w400, color: RC.textSoft)),
        if (!acik) const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── ⚠ DÜZELTİLDİ — kullanıcı bulgusu: bu kutu HER
              // ZAMAN kilitliydi ("hizmet verenin telefonu hiç
              // paylaşılmıyor" sabit kararı vardı). Hizmet verenin
              // profilinde `Account` düzeyinde ayrı bir gizlilik
              // tercihi YOK (yalnız hizmet ALANIN `iletisimTercihi`si
              // var, o da bu akışta KARŞI yönde/sağlayıcı tarafında
              // kullanılıyor) — teklif geldiğinde (`acik`) hizmet
              // verenin telefonu da diğer bilgileriyle (ad, avatar)
              // AYNI anda, koşulsuz açılır.
              Builder(builder: (context) {
                final hizmetVeren = context
                    .read<AuthController>()
                    .accountById(talep.saglayiciId);
                return Expanded(
                  child: _MiniIletisimKutusu(
                    ikon: 'assets/svg/ic_phone_f.svg',
                    etiket: 'Telefon',
                    deger:
                        acik ? _telefonGosterMetni(hizmetVeren?.phone) : null,
                    not: acik ? null : 'Kilitli',
                    kilitli: !acik,
                    onTap: acik
                        ? () => _telefonAra(context, hizmetVeren?.phone)
                        : null,
                  ),
                );
              }),
              const SizedBox(width: 11),
              Expanded(
                child: _MiniIletisimKutusu(
                  ikon: 'assets/svg/ic_chat.svg',
                  etiket: 'Mesajlaşma',
                  deger: acik ? 'Mesaj yaz' : null,
                  not: acik
                      ? null
                      : 'Kilitli',
                  kilitli: !acik,
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
    this.not,
    this.kucukDeger = false,
    this.onTap,
  });

  final String ikon;
  final String etiket;

  /// ⚠ ARTIK OPSİYONEL — job_detail_screen.dart'taki `_IletisimKutusu`
  /// İLE AYNI ilke: kilitliyken `deger` YERİNE yalnız `not`
  /// (açıklama) gösterilir. İkisi BİRDEN doluysa Telefon kutusu
  /// Mesajlaşma'dan DAHA UZUN görünüyordu — iki kutu farklı
  /// yükseklikte duruyordu (kullanıcı bulgusu, job_detail_screen.
  /// dart'ta da AYNI hataydı, orada da düzeltildi).
  final String? deger;
  final bool kilitli;

  /// Kilitliyken gösterilen açıklama — job_detail_screen.dart'taki
  /// `_IletisimKutusu.not` İLE AYNI amaç, aynı metin.
  final String? not;
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
                if (deger != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    deger!,
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
                if (not != null) ...[
                  const SizedBox(height: 2),
                  // ⚠ EK GÜVENLİK — bkz. job_detail_screen.dart'taki
                  // AYNI not.
                  Text(not!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s11,
                          weight: RF.w500,
                          color: RC.text,
                          height: RF.lh135)),
                ],
              ],
            ),
          ),
          if (kilitli) ...[
            const SizedBox(width: 6),
            // ⚠ job_detail_screen.dart'taki kilit rozetiyle AYNI —
            // önceden `Icons.lock_outline` (Material ikonu, daire
            // arka planı YOK) kullanılıyordu, uygulama genelindeki
            // diğer iletişim kutularıyla TUTARSIZDI.
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF0F4),
                shape: BoxShape.circle,
              ),
              child: const RefSvg('assets/svg/ic_plock.svg',
                  size: 14, color: RC.greyLight),
            ),
          ],
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
          Text(tutarMetni(talep.teklifFiyati!),
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
        // ── ⚠ CANLI BİNLİK AYRACI (kullanıcı isteği, 9 Eyl) ──
        //
        // "1000 yazdığında 1.000 olarak otomatik atasın; 1, 10, 100
        // haricinde sonraki büyük rakamlara otomatik nokta konulsun."
        //
        // Biçim kuralı `core/tutar_bicimi.dart` içinde TEK yerde;
        // alan onu uygular, kendi kuralını yazmaz.
        //
        // ⚠ ALAN ARTIK "3.000" GİBİ OKUNUR: gönderimde
        // `int.tryParse` ÇÖKER, bu yüzden okuma `tutarOku` ile
        // yapılır (bkz. `_gonder`).
        TextField(
          controller: fiyatController,
          keyboardType: TextInputType.number,
          inputFormatters: const [TutarBicimlendirici()],
          decoration: const InputDecoration(hintText: 'Örn. 1.500'),
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
    required this.onMenuAc,
    required this.onYorumYaz,
  });

  final TeklifTalebi talep;
  final VoidCallback onSec;

  /// ⚠ ÖNCEDEN `onReddet` — düz bir "Reddet" düğmesi doğrudan
  /// reddediyordu. Artık 3 NOKTA MENÜSÜ açıyor (`listing_detail_
  /// screen.dart`daki "İlanı neden siliyorsunuz?" DESENİYLE aynı —
  /// onay + gerekçe sorma) — bkz. `_talepMenusu()`.
  final VoidCallback onMenuAc;

  /// ⚠ Yalnız `tamamlandi` durumunda kullanılır — iş bitince
  /// "Teklifi Seç" düğmesinin YERİNİ "Yorum Yaz" alır.
  final VoidCallback onYorumYaz;

  @override
  Widget build(BuildContext context) {
    switch (talep.durum) {
      case TeklifTalebiDurumu.beklemede:
        // ── ⚠ EKSİKTİ — 3 NOKTA MENÜSÜ YALNIZ `teklifGeldi`
        // DURUMUNDA VARDI, "TEKLİFİ SEÇ" BUTONUNUN YANINDA. Hizmet
        // alan, teklif GELMEDEN ÖNCE (beklerken) talebi silme/iptal
        // etme seçeneğine HİÇ SAHİP DEĞİLDİ. `_talepMenusu()` zaten
        // vardı (Talebi Sil → onay → "neden siliyorsun?" gerekçe
        // seçimi) — burada da AYNI mekanizma, yeni bir akış İCAT
        // EDİLMEDİ.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: _BeklemeGostergesi()),
            const SizedBox(width: 8),
            RefTap(
              onTap: onMenuAc,
              borderRadius: BorderRadius.circular(RR.r13),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFECEEF2)),
                  borderRadius: BorderRadius.circular(RR.r13),
                ),
                child: const RefSvg('assets/svg/ic_dots.svg',
                    size: 18, color: RC.textSoft),
              ),
            ),
          ],
        );

      case TeklifTalebiDurumu.teklifGeldi:
        final kalan = talep.suresiDolacagiZaman?.difference(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fiyat',
                style:
                    refText(size: RF.s12, weight: RF.w400, color: RC.grey)),
            Text(tutarMetni(talep.teklifFiyati!),
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
            // ── ⚠ "TEKLİFİ SEÇ" + 3 NOKTA — YAN YANA ──
            //
            // Düz "Reddet" düğmesi KALDIRILDI; 3 nokta artık
            // `listing_detail_screen.dart`daki "İlanı Sil"le AYNI
            // akışı açıyor (onay + gerekçe sorma).
            Row(
              children: [
                Expanded(
                  child: RefPrimaryButton('Teklifi Seç', onPressed: onSec),
                ),
                const SizedBox(width: 8),
                RefTap(
                  onTap: onMenuAc,
                  borderRadius: BorderRadius.circular(RR.r13),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFECEEF2)),
                      borderRadius: BorderRadius.circular(RR.r13),
                    ),
                    child: const RefSvg('assets/svg/ic_dots.svg',
                        size: 18, color: RC.textSoft),
                  ),
                ),
              ],
            ),
          ],
        );

      case TeklifTalebiDurumu.secildi:
        // ── ⚠ ÖNCEDEN YEŞİL KUTU İÇİNDEYDİ — artık kutu YOK,
        // yalnız şık/sade bir metin (ürün kararı).
        return Text('Teklif Seçildi',
            style: refText(
                size: RF.s16, weight: RF.w700, color: HC.green));

      case TeklifTalebiDurumu.reddedildi:
        return Text('Bu teklifi reddettin.',
            style:
                refText(size: RF.s135, weight: RF.w500, color: RC.textSoft));

      case TeklifTalebiDurumu.suresiDoldu:
        return Text('Teklifin süresi doldu — artık seçilemez.',
            style:
                refText(size: RF.s135, weight: RF.w500, color: RC.textSoft));

      case TeklifTalebiDurumu.tamamlandi:
        // ── ⚠ "TEKLİFİ SEÇ" ARTIK "YORUM YAZ"A DÖNÜŞÜYOR ──
        //
        // İş tamamlanınca müşteri, mevcut ilan akışıyla AYNI
        // değerlendirme sistemine (`ReviewController`/`Review`)
        // yazan bir ekrana yönlendirilir — bkz.
        // `TeklifTalebiYorumScreen`.
        //
        // ── ⚠ YORUM YAPILDIYSA DÜĞME ÇİZİLMEZ (kullanıcı bulgusu,
        // 9 Eyl) ──
        //
        // ÖLÇÜLEN EKSİK: bu dal yorum yazılıp yazılmadığına HİÇ
        // BAKMIYORDU — `ReviewController.byTalep()` pakette vardı ve
        // teklif talebi yorumu tam bu anahtarla kaydediliyordu, ama
        // burada çağrılmıyordu. Sonuç: yorum gönderildikten sonra da
        // "Yorum Yaz" düğmesi duruyor, hâlâ yapılacak bir iş varmış
        // izlenimi veriyordu.
        //
        // ⚠ İLAN AKIŞIYLA AYNI DESEN: `offer_detail_screen.dart`
        // zaten `if (!reviewed)` ile düğmeyi gizleyip yerine durum
        // yazısı koyuyordu. Yeni bir kural İCAT EDİLMEDİ, eksik olan
        // akış ötekine EŞİTLENDİ.
        //
        // ⚠ AYNI EKRAN İKİ İŞ GÖRÜR: `TeklifTalebiYorumScreen`, kayıt
        // varsa formu değil SALT OKUNUR kartı çizer. Bu yüzden yazı da
        // düğme de AYNI hedefi açar; ayrı bir görüntüleme ekranı
        // YAZILMADI.
        final yorum = context.watch<ReviewController>().byTalep(talep.id);
        // ⚠ "İş tamamlandı." YAZISI KALDIRILDI (kullanıcı isteği,
        // 9 Eyl): altındaki "Yorum Yaz" düğmesi zaten işin bittiğini
        // anlatıyordu, satır tekrar ediyordu.
        //
        // ⚠ HİZMET VEREN TARAFINDAKİ AYNI CÜMLE KALDI: orada düğme
        // YOK, cümle kaldırılsaydı bölüm bomboş kalırdı — durumu
        // söyleyen tek şey o.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (yorum == null)
              RefPrimaryButton('Yorum Yaz',
                  iconAsset: 'assets/svg/ic_starfill.svg',
                  onPressed: onYorumYaz)
            else
              // ── ⚠ YEŞİL ŞERİT YERİNE YORUM KARTI (kullanıcı
              // isteği, 9 Eyl) ──
              //
              // ÖNCEDEN tek satırlık yeşil bir şeritti: "Yorum
              // Yapıldı (5 puan) · Görüntüle". Puanı sayı olarak
              // söylüyor, yorumun kendisini hiç göstermiyordu.
              //
              // Artık kart: yıldızlar + puan + yazılan metin. Karta
              // dokununca yine salt okunur değerlendirme ekranı
              // açılır — görüntüleme yolu KAYBOLMADI.
              //
              // ⚠ KAPSAM: gösterilen yorum YALNIZ BU TALEBE aittir
              // (`byTalep(talep.id)`); hizmet verenin öteki yorumları
              // bu kartta GÖSTERİLMEZ.
              RefTap(
                onTap: onYorumYaz,
                borderRadius: BorderRadius.circular(RR.r13),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: RC.white,
                    border: Border.all(color: const Color(0xFFECEEF2)),
                    borderRadius: BorderRadius.circular(RR.r13),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // ⚠ BEŞ YILDIZ ÇİZİLİR: dolu yıldız sayısı
                          // puandır, kalanlar soluk. Sayıyı tek başına
                          // yazmak "5 puan" gibi soyut kalıyordu.
                          for (var i = 1; i <= 5; i++) ...[
                            RefSvg('assets/svg/ic_starfill.svg',
                                size: 16,
                                color: i <= yorum.stars
                                    ? const Color(0xFFF5A319)
                                    : const Color(0xFFE1E5EC)),
                            const SizedBox(width: 3),
                          ],
                          const SizedBox(width: 5),
                          Text('${yorum.stars}.0',
                              style: refText(
                                  size: RF.s145,
                                  weight: RF.w700,
                                  color: RC.text)),
                          const Spacer(),
                          Text('Görüntüle',
                              style: refText(
                                  size: RF.s125,
                                  weight: RF.w700,
                                  color: RC.blue)),
                        ],
                      ),
                      // ⚠ METİN YALNIZ VARSA: yorum yazılmadan da
                      // puan verilebiliyor; boş satır bırakılmaz.
                      if (yorum.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(yorum.text.trim(),
                            style: refText(
                                size: RF.s135,
                                weight: RF.w400,
                                color: RC.text)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
    }
  }
}

/// ⚠ `teklif_iste_screen.dart`/`sonuclar_screen.dart`daki AYNI
/// mantık — hizmet verenin SEÇİLMİŞ teklifle tamamlanmış iş sayısı.
/// Üçüncü bir kopya değil, aynı hesaplama farklı dosyalarda AYNI
/// şekilde tekrarlanıyor çünkü bu dosyalar birbirinden PRIVATE
/// (import edilemez).
int _tamamlananIsGercek(BuildContext c, String providerId) {
  final ilanlar = c.read<ListingController>().all;
  final teklifler = c.read<OfferController>();
  var n = 0;
  for (final l in ilanlar) {
    if (!l.isTamamlanmisIs) {
      continue;
    }
    final secili = teklifler
        .offersForListing(l.id)
        .where((o) => o.id == l.selectedOfferId);
    if (secili.isNotEmpty && secili.first.providerId == providerId) {
      n++;
    }
  }
  return n;
}

/// ── ⚠ "BEKLENİYOR" GÖSTERGESİ — NABIZ ATAN ANİMASYON ──
///
/// Kullanıcı isteğiyle: metin daha "canlı" olmalı, ama daha fazla
/// AÇIKLAMA eklenerek DEĞİL, GÖRSEL olarak. Önceden düz, gri, tek
/// satırlık bir `Text` idi. Şimdi hafif mavi zeminli bir kutu içinde,
/// sürekli nabız atan bir gönderi ikonu ile birlikte — "teklif
/// gerçekten iletildi, canlı olarak yanıt bekleniyor" hissi.
class _BeklemeGostergesi extends StatefulWidget {
  const _BeklemeGostergesi();

  @override
  State<_BeklemeGostergesi> createState() => _BeklemeGostergesiState();
}

class _BeklemeGostergesiState extends State<_BeklemeGostergesi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RC.blueSoft,
        borderRadius: BorderRadius.circular(RR.r13),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: RC.blue,
                shape: BoxShape.circle,
              ),
              child: const RefSvg('assets/svg/ic_send.svg',
                  size: 15, color: RC.white),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text('Hizmet verenin teklifi bekleniyor.',
                style: refText(
                    size: RF.s135, weight: RF.w600, color: RC.text)),
          ),
        ],
      ),
    );
  }
}

/// ⚠ Hizmet ALANIN (müşterinin) TAMAMLANAN iş sayısı — hizmet
/// verenin `_tamamlananIsGercek`sinin AYNADAKİ karşılığı. İki akıştaki
/// tamamlanan işler toplanır:
/// 1) Normal "İlan Ver" — bu kullanıcının SAHİBİ olduğu, tamamlanmış
///    ilanlar (`Listing.isTamamlanmisIs`).
/// 2) Doğrudan "Bul" — bu kullanıcının GÖNDERDİĞİ, `tamamlandi`
///    durumuna ulaşmış teklif talepleri.
/// ⚠ KOPYALAR KALDIRILDI (9 Eyl): hizmet alanın tamamlanan iş sayısı
/// ve üyelik metni artık `domain/hizmet_alan_ozeti.dart` içinde TEK
/// yerde. "Kazandığım" listesindeki kart da aynı kaynağı kullanıyor;
/// iki yüzey ayrı hesaplasaydı sayılar sessizce ayrışırdı.
int _hizmetAlanTamamlananIs(BuildContext c, String hizmetAlanId) =>
    hizmetAlanTamamlananIs(c, hizmetAlanId);

String _uyelikTarihiMetni(DateTime tarih) => uyelikTarihiMetni(tarih);
