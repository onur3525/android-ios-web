import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/telefon_bicimi.dart';
import '../core/tutar_bicimi.dart';
import '../domain/hizmet_alan_ozeti.dart';
import '../domain/kullanici_konumu.dart';
import '../domain/saglayici_ozeti.dart';
import '../domain/yorum_gorunumu.dart' show kisaTarih;
import '../core/theme.dart';
import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
// ⚠ YALNIZ `Role`: fotoğraf rol bazlıdır (bkz. Account.fotografi).
import '../data/models/account.dart' show Role;
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
import 'widgets/durum_rozeti.dart';
import 'widgets/is_zamani_secici.dart';
import 'widgets/saglayici_ozet_satiri.dart';
import 'widgets/teklif_aciklama_karti.dart';
import 'widgets/teklif_tutar_karti.dart';
import 'widgets/detay_karti_parcalari.dart';
import 'widgets/ilan_baslik_satiri.dart';
import 'widgets/ilan_no_etiketi.dart';
import 'widgets/durum_seridi.dart';

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

  /// ── ⚠ "TEKLİFİNİZ GÖNDERİLDİ" ONAYI — 2 SANİYE ──
  ///
  /// Kullanıcı isteği (9 Eyl): yazı gönderim sonrası görünsün, 2 sn
  /// sonra kaybolsun.
  ///
  /// ⚠ DURUMDAN TÜRETİLMEZ: `talep.teklifTarihi != null` koşuluna
  /// bağlansaydı ekran her açıldığında yeniden görünürdü. Bu bir
  /// EYLEM ONAYI; durumu zaten teklif kartı söylüyor.
  bool _gonderimOnayi = false;

  /// ⚠ SAKLANIR VE İPTAL EDİLİR: ekran 2 sn dolmadan kapanırsa
  /// zamanlayıcı ölü bir `setState` çağırırdı.
  Timer? _onayZamanlayici;

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
    // ⚠ İPTAL ŞART: ekran 2 sn dolmadan kapanırsa zamanlayıcı ölü
    // bir `setState` çağırır.
    _onayZamanlayici?.cancel();
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
    // ── ⚠ CEVAP ZORUNLU DEĞİL (kullanıcı kararı, 10 Eyl) ──
    //
    // "Hizmet veren teklif talebine cevap vermek zorunda değil;
    // sadece fiyat verebilir."
    //
    // ÖNCEDEN boş cevapta gönderim REDDEDİLİYORDU. Oysa teklifin
    // taşıdığı asıl bilgi FİYAT; açıklama yardımcı. Zorunlu tutmak,
    // hizmet vereni anlamsız bir cümle yazmaya itiyordu.
    //
    // ⚠ FİYAT DOĞRULAMASI DURUYOR: fiyatsız teklif gönderilemez.
    // Kalkan tek şey açıklamanın zorunluluğu.
    setState(() => _gonderiliyor = true);
    final err = await context.read<TeklifTalebiController>().teklifVer(t.id,
        fiyat: f, aciklama: _cevap.text.trim());
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (err != null) {
      sysToastErr(context, SysKind.genericError, extra: err.message);
      return;
    }
    // ⚠ ALTTAKİ ONAY UYARISI KALDIRILMIŞTI (`sysToastOk` susturuldu);
    // onay artık ekranın kendi içinde, 2 saniyeliğine gösterilir.
    _onayZamanlayici?.cancel();
    setState(() => _gonderimOnayi = true);
    _onayZamanlayici = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _gonderimOnayi = false);
      }
    });
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
            // ── ⚠ ÜÇ NOKTA EKRANIN SAĞ ÜST KÖŞESİNE ALINDI
            // (kullanıcı isteği, 9 Eyl) ──
            //
            // ÖNCEDEN sayfanın ALTINDA, "bekleniyor" kutusunun
            // yanında 48x48'lik bir kutu olarak duruyordu; kutunun
            // genişliğini kısıtlıyor ve orantısız görünüyordu.
            //
            // ⚠ MENÜNÜN KENDİSİ DEĞİŞMEDİ: aynı `_talepMenusu()`
            // çağrısı — talebi silme, onay ve gerekçe sorma akışı
            // aynen duruyor. Değişen yalnız düğmenin YERİ.
            //
            // ⚠ YALNIZ HİZMET ALANDA: menü talebi silme içindir;
            // hizmet verenin böyle bir yetkisi yok, onda çizilmez.
            Row(
              children: [
                const RefBackButton(),
                const Spacer(),
                // ── ⚠ YALNIZ AÇIK TALEPTE (12 Eyl, kullanıcı
                // isteği) ──
                //
                // "Üç nokta sadece açık işlerde olacak; tamamlanan
                // işlerde buna gerek yok."
                //
                // Menü tek bir şey yapar: talebi siler. İş
                // seçildikten ya da tamamlandıktan sonra silmek bir
                // kaydı yok etmektir — yorum, puan ve karşı tarafın
                // geçmişi ona bağlıdır.
                //
                // ⚠ KOŞUL MODELDE: `silinebilir`. Ekran kendi
                // koşulunu yazmaz; `Listing.isTamamlanmisIs` ile aynı
                // desen.
                if (!benSaglayiciMi && t.silinebilir)
                  RefTap(
                    onTap: () => _talepMenusu(t),
                    borderRadius: BorderRadius.circular(RR.circle),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: RefSvg('assets/svg/ic_dots.svg',
                          size: 20, color: RC.textSoft),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            RefPageTitle('Teklif Talebi', geriDugmesi: false),
            const SizedBox(height: 12),

            RefFormCard(
              marginTop: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── ⚠ İLAN AKIŞIYLA AYNI DÜZEN (12 Eyl, ürün
                  // kararı) ──
                  //
                  // "İlan oluştururken görülen ekran Bul ekranında da
                  // aynı düzende olmalı. Aynı butonlar, aynı yerleşim,
                  // aynı assetler."
                  //
                  // Sıra `job_detail_screen` ile BİREBİR aynıdır:
                  // numara → karşı taraf → ayraç → ikon + hizmet →
                  // "Talep Detayı" → zaman → işin detayı → bilgi
                  // tablosu → fotoğraflar.
                  //
                  // ⚠ NUMARA SAĞ ÜSTTE: talepler de artık numara
                  // alıyor ve ilanlarla AYNI diziden geliyor
                  // (`IlanNoUretici`). Kullanıcı için ikisi aynı şey.
                  IlanNoEtiketi(t.talepNo),

                  // ── ⚠ KARŞI TARAF ÜSTTE ──
                  //
                  // Önceden ayrı bir ikinci kartta, EN ALTTA
                  // duruyordu. İlan akışında ilk gördüğün şey işin
                  // kimden geldiğidir; iki ekran aynı sırayı izler.
                  //
                  // ⚠ HİZMET ALAN GÖRÜNÜMÜNDE ÇİZİLMEZ: orada karşı
                  // taraf hizmet verendir ve `SaglayiciOzetSatiri`
                  // ile aşağıda gösterilir — o kartın kendi
                  // maskeleme ve adres kuralları var.
                  if (benSaglayiciMi) ...[
                    Builder(builder: (c) {
                      final hesap = auth.accountById(t.hizmetAlanId);
                      final acik = t.teklifTarihi != null;
                      final ham = hesap?.name ?? 'Hizmet Alan';
                      return SahipKarti(
                        adSoyad: acik ? ham : maskeliAd(ham),
                        acik: acik,
                        tamamlananIs:
                            hizmetAlanTamamlananIs(c, t.hizmetAlanId),
                        // ⚠ FOTOĞRAF YALNIZ KİMLİK AÇIKKEN: teklif
                        // verilene kadar iki taraf birbirine maskeli,
                        // fotoğraf da maskelemenin parçasıdır.
                        //
                        // ⚠ HİZMET ALAN ROLÜNÜN fotoğrafı okunur:
                        // çift rollü hesapta iş profili fotoğrafı
                        // burada yanlış kimliği gösterirdi.
                        fotoYolu:
                            acik ? (hesap?.fotografi(Role.customer) ?? '') : '',
                        kayitTarihi: hesap?.kayitTarihi,
                      );
                    }),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F3F6)),
                    const SizedBox(height: 12),
                  ],

                  // ── ⚠ ORTAK BAŞLIK SATIRI ──
                  //
                  // İkon + hizmet adı; üst kategori adı YAZILMAZ
                  // (12 Eyl ürün kararı). İlan akışındaki bileşenin
                  // TA KENDİSİ.
                  IlanBaslikSatiri(baslik: t.hizmet),

                  // ── ⚠ BAŞLIK "TALEP DETAYI" ──
                  //
                  // İlan akışında "İlan Detayı" yazar. Burada ortada
                  // bir ilan YOK; olmayan bir nesneye atıfta bulunmak
                  // yerine kaydın gerçek adı kullanılır.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 7),
                    child: Text('Talep Detayı',
                        style: refText(
                            size: 15, weight: RF.w700, color: RC.text)),
                  ),
                  // ── ⚠ BÖLÜM AYRAÇLARI (12 Eyl, kullanıcı bulgusu) ──
                  //
                  // "Talep detayı, zaman tercihi, işin detayı ve
                  // fotoğraflar iç içe geçmiş, ne olduğu anlaşılmıyor."
                  //
                  // Kartın ALT tablosunda zaten gri çizgiler vardı;
                  // üstteki bölümlerde yoktu.
                  //
                  // ⚠ ÇİZGİ ORTAK BİLEŞENDEN (`BolumAyraci`): renk ve
                  // boşluk orada sabit, iki detay ekranı ayrışamaz.
                  const BolumAyraci(),
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
                  // ⚠ ETİKET ADI İLAN AKIŞIYLA EŞİTLENDİ: orada
                  // "Zaman tercihi" yazıyor. Aynı alan iki ekranda
                  // iki ad taşımaz.
                  if (t.isZamani != null) ...[
                    Text('Zaman tercihi',
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
                    // ⚠ BOŞLUK YERİNE ÇİZGİ: iki bölüm arasında
                    // yalnız boşluk bırakmak ayırmaya yetmiyordu.
                    const BolumAyraci(),
                  ],

                  // ⚠ "Açıklama" → "İşin detayı": ilan akışındaki ad.
                  Text('İşin detayı',
                      style: refText(
                          size: RF.s12, weight: RF.w400, color: RC.grey)),
                  const SizedBox(height: 4),
                  Text(t.aciklama,
                      style: refText(
                          size: RF.s135,
                          weight: RF.w500,
                          color: RC.text,
                          height: RF.lh155)),

                  // ── ⚠ BİLGİ TABLOSU (ilan akışındaki `.pl-rows`) ──
                  //
                  // Bul akışında bu tablo HİÇ YOKTU: konum ayrı bir
                  // kartta, tarih ise hiçbir yerde görünmüyordu.
                  Builder(builder: (c) {
                    // ⚠ ADRES ORTAK KAYNAKTAN: `kullaniciKonumu`
                    // hesabın GÜNCEL adresini biçimlenmiş döner —
                    // ilan akışındaki satırın kullandığı AYNI
                    // fonksiyon. Elle `district / city` kurmak beşinci
                    // bir kopya olurdu.
                    final konum =
                        kullaniciKonumu(c, t.hizmetAlanId,
                            mahalleDahil: true);
                    return Container(
                      margin: const EdgeInsets.only(top: 11),
                      decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: kDetayAyracRengi))),
                      child: Column(children: [
                        BilgiSatiri(
                            ikon: 'assets/svg/ic_pin.svg',
                            etiket: 'İl / İlçe / Mahalle',
                            // ⚠ Adres girilmemişse yer tutucu —
                            // `BilgiSatiri` boş değer kabul etmez.
                            deger: konum ?? 'Belirtilmemiş'),
                        BilgiSatiri(
                            ikon: 'assets/svg/ic_nclock.svg',
                            // ⚠ "İlan Tarihi" DEĞİL: burada ilan yok.
                            etiket: 'Talep Tarihi',
                            // ── ⚠ GÖRELİ SÜRE DEĞİL, TARİH (12 Eyl,
                            // kullanıcı isteği) ──
                            //
                            // "21 dk önce" bir SAAT bilgisiydi ve
                            // kartın en üstündeki "21 dk önce" ile
                            // aynı şeyi tekrar ediyordu. Etiket
                            // "Talep Tarihi" diyorsa değer de tarih
                            // olmalı.
                            //
                            // ⚠ BİÇİM TEK KAYNAKTAN: `kisaTarih`
                            // gün/ayı iki haneye tamamlar, kart
                            // hizası bozulmaz.
                            deger: kisaTarih(t.createdAt)),
                      ]),
                    );
                  }),

                  if (t.fotograflar.isNotEmpty) ...[
                    // ⚠ TABLONUN ALT ÇİZGİSİ YOK: `BilgiSatiri` yalnız
                    // satır ARALARINA çizgi koyar. Ayraç olmadan
                    // fotoğraf başlığı tarih satırına yapışıyordu.
                    const BolumAyraci(),
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
                gonderimOnayi: _gonderimOnayi,
                onTeklifVer: () => _teklifVer(t),
                onTamamla: () => _tamamla(t),
              )
            else
              _HizmetAlanAksiyonlari(
                talep: t,
                onSec: () => _sec(t),
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
      // ── ⚠ AD / KONUM / GEÇMİŞ BLOKLARI BU KARTTAN ÇIKTI
      // (12 Eyl, ürün kararı) ──
      //
      // Aynı bilgiler artık ANA KARTIN ÜSTÜNDE, ilan akışındaki
      // `SahipKarti` ve bilgi tablosuyla çiziliyor. Burada
      // bırakılsalardı ekranda İKİ KEZ görünürlerdi.
      //
      // ⚠ GERİYE YALNIZ İLETİŞİM KUTULARI KALDI ve artık ilan
      // akışının kullandığı ORTAK bileşenle çiziliyor.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: IletisimKutusu(
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
                  child: IletisimKutusu(
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
        // ── ⚠ BEŞİNCİ KOPYA KALDIRILDI (kullanıcı bulgusu, 9 Eyl) ──
        //
        // BULGU: profilde "Karşıyaka / İzmir" yazan hizmet veren, bu
        // ekranda "Aliağa / İzmir" görünüyordu; "Bul" ekranındaki
        // kartla AYNI kişi FARKLI adresle çıkıyordu.
        //
        // KÖK NEDEN: bu ekran hizmet veren kartını KENDİ çiziyordu ve
        // konumu `serviceDistricts.first`ten alıyordu — yani hizmet
        // VERDİĞİ ilk bölgeden. Adres tutarlılığı turunda öteki dört
        // yüzey `hesap.address`e bağlanmıştı, bu kopya gözden
        // kaçmıştı.
        //
        // ⚠ NEREYE HİZMET VERDİĞİ İLE NEREDE OTURDUĞU AYRI SORULAR:
        // eşleştirme hizmet bölgesine, GÖSTERİM adrese bakar. Kart
        // artık ortak `SaglayiciOzetSatiri` + `gercekSaglayiciOzeti`
        // üzerinden çiziliyor; adres değişince beş yüzey birden
        // değişir.
        //
        // ⚠ MASKELEME: teklif gelene kadar kimlik gizlidir; `acik`
        // kuralı DEĞİŞMEDİ, yalnız bileşene parametre olarak geçti.
        Builder(builder: (context) {
          final ozet = gercekSaglayiciOzeti(context, id: talep.saglayiciId) ??
              (
                id: talep.saglayiciId,
                adSoyad: talep.saglayiciAdi,
                puan: null,
                yorumSayisi: 0,
                tamamlananIs: 0,
                ilce: null,
                il: null,
                // ⚠ YEDEK KAYIT: hesap bulunamadı, fotoğraf da yok.
                fotoYolu: '',
              );
          return SaglayiciOzetSatiri(ozet, maskeli: !acik);
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
        // ── ⚠ KONUM DEĞİŞTİ (kullanıcı isteği, 9 Eyl) ──
        //
        // "Telefon ve mesaj kartlarını OLDUĞU GİBİ, açıklama ve yorum
        // kısmının arasına konumlandır."
        //
        // ÖNCEDEN "Yorumlar"ın ALTINDAYDI: kilitli iletişim, onu
        // açıklayan not ve yorumlar arasında sıra bozuktu — önce
        // yorumlar, sonra "teklif verdiğinde açılacak" notu geliyordu.
        // Yeni sıra: özet → not → iletişim kutuları → yorumlar.
        //
        // ⚠ KUTULARIN İÇİNE HİÇ DOKUNULMADI: aynı `IletisimKutusu`
        // çağrıları, aynı kilit kuralları, aynı ölçüler. Değişen tek
        // şey bloğun dosyadaki YERİ.
        // ── ⚠ TELEFON + MESAJLAŞMA — YAN YANA, PROVİDER TARAFINDAKİ
        // `IletisimKutusu` İLE AYNI KUTULAR (sıfırdan YAPILMADI,
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
                  child: IletisimKutusu(
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
                child: IletisimKutusu(
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

// ⚠ YEREL `IletisimKutusu` SINIFI SİLİNDİ (12 Eyl).
//
// Bul akışı, ilan akışındaki iletişim kutusunun daha küçük bir
// kopyasını taşıyordu: farklı daire çapı, farklı punto, kilit
// rozeti yok. Aynı iki düğme iki ekranda iki farklı boyda
// duruyordu. Artık ikisi de `widgets/detay_karti_parcalari.dart`
// içindeki ortak `IletisimKutusu`nu çağırır.

class _SaglayiciAksiyonlari extends StatelessWidget {
  const _SaglayiciAksiyonlari({
    required this.talep,
    required this.fiyatController,
    required this.cevapController,
    required this.gonderiliyor,
    required this.gonderimOnayi,
    required this.onTeklifVer,
    required this.onTamamla,
  });

  final TeklifTalebi talep;
  final TextEditingController fiyatController;
  final TextEditingController cevapController;
  final bool gonderiliyor;

  /// ⚠ GEÇİCİ ONAY: yalnız gönderim ANINDA `true` olur, 2 sn sonra
  /// söner. Talebin durumundan TÜRETİLMEZ — türetilseydi ekran her
  /// açıldığında yeniden görünürdü.
  final bool gonderimOnayi;
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
          // ── ⚠ "GÖNDERİLDİ" ŞERİDİ ARTIK GEÇİCİ (kullanıcı
          // isteği, 9 Eyl) ──
          //
          // "Teklif gönderildiyse yazı gözüksün, 2 sn sonra
          // kaybolsun."
          //
          // ÖNCEDEN KALICIYDI: teklif verilmiş her talepte, ekran
          // her açıldığında yeniden görünüyordu. Oysa bu bir DURUM
          // değil, bir EYLEM ONAYI — ve durumu zaten altındaki
          // teklif kartı söylüyor.
          //
          // ⚠ YALNIZ GÖNDERİM ANINDA: bayrak `_gonder` başarıyla
          // dönünce açılır, 2 sn sonra kapanır. Ekrana sonradan
          // girildiğinde HİÇ çizilmez.
          if (gonderimOnayi) ...[
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
          ],
          // ⚠ ORTAK KART: "Fiyat" başlıklı düz metin yerine
          // `TeklifTutarKarti`. Hizmet alan tarafı da AYNI kartı
          // kullanır — biri değişince öteki de değişir.
          TeklifTutarKarti(talep.teklifFiyati!),
          // ⚠ AÇIKLAMA BOŞSA BÖLÜM HİÇ ÇİZİLMEZ (10 Eyl): cevap
          // artık zorunlu değil. Boşken başlık tek başına kalıp
          // altında boşluk bırakıyordu — sahipsiz başlık.
          if ((talep.teklifAciklamasi ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            // ⚠ ORTAK KART (10 Eyl): düz metin yerine çerçeveli kart,
            // ortalanmış başlık. Hizmet alan tarafı AYNI kartı
            // kullanır — biri değişince öteki de değişir.
            TeklifAciklamaKarti(
                // ⚠ KARŞI TARAFTA "Hizmet Verenin Notu" yazan şey
                // kendi tarafında "Notunuz"dur — aynı metnin iki
                // adı olmaz.
                baslik: 'Notunuz',
                metin: talep.teklifAciklamasi!.trim()),
          ],
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
          // ── ⚠ "İş tamamlandı." SATIRI KALDIRILDI (12 Eyl,
          // kullanıcı isteği) ──
          //
          // 9 Eyl'de aynı cümle HİZMET ALAN tarafından kaldırılmış,
          // burada "düğme yok, bölüm bomboş kalır" gerekçesiyle
          // BIRAKILMIŞTI. Kullanıcı kararı bu gerekçeyi geçersiz
          // kıldı: ekranda zaten "Verilen teklif" kutusu ve "Notunuz"
          // kartı var; boş kalan bir bölüm yok.
          //
          // ⚠ DAL TÜMÜYLE SİLİNDİ, boş bırakılmadı: içi boş bir
          // `else if` okuyan kişiye "burada bir şey olmalıydı" dedirtir.
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
        // ⚠ İSTEĞE BAĞLI OLDUĞU YAZILIR: alan zorunlu olmaktan
        // çıktı; kullanıcı boş bırakabileceğini bilmeli, yoksa
        // gereksiz yere doldurmaya çalışır. "Fotoğraf (Opsiyonel)"
        // ve "Hizmet Zamanı (Opsiyonel)" ile AYNI dil.
        Row(
          children: [
            // ⚠ ÜÇÜNCÜ AD KALDIRILDI (12 Eyl): aynı metin kartta
            // "Açıklamanız", formda "Cevabınız", karşı tarafta
            // "Hizmet Verenin Açıklaması" diye geçiyordu. Yazarken
            // ve okurken tek ad: "Notunuz" / "Hizmet Verenin Notu".
            Text('Notunuz',
                style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
            const SizedBox(width: 6),
            Text('(Opsiyonel)',
                style: refText(
                    size: RF.s125, weight: RF.w500, color: RC.textSoft)),
          ],
        ),
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
    required this.onYorumYaz,
  });

  final TeklifTalebi talep;
  final VoidCallback onSec;

  /// ⚠ ÖNCEDEN `onReddet` — düz bir "Reddet" düğmesi doğrudan
  /// reddediyordu. Artık 3 NOKTA MENÜSÜ açıyor (`listing_detail_
  /// screen.dart`daki "İlanı neden siliyorsunuz?" DESENİYLE aynı —
  /// onay + gerekçe sorma) — bkz. `_talepMenusu()`.
  // ⚠ `onMenuAc` KALDIRILDI (9 Eyl): üç nokta menüsü artık ekranın
  // sağ üst köşesinde, sayfa başlığının yanında. Bu bileşen menüyü
  // hiç çizmiyor, dolayısıyla geri çağrıya da ihtiyacı yok.

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
        // ⚠ ÜÇ NOKTA BURADAN ALINDI (9 Eyl): artık ekranın sağ üst
        // köşesinde. Kutu tam genişliği kullanabiliyor.
        return const _BeklemeGostergesi();

      case TeklifTalebiDurumu.teklifGeldi:
        final kalan = talep.suresiDolacagiZaman?.difference(DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⚠ ORTAK KART (bkz. hizmet veren tarafı): iki taraf da
            // aynı tutarı aynı biçimde görür.
            TeklifTutarKarti(talep.teklifFiyati!),
            // ⚠ AÇIKLAMA BOŞSA BÖLÜM HİÇ ÇİZİLMEZ (10 Eyl): hizmet
            // veren cevap yazmak zorunda değil. Boş başlık, karşı
            // tarafa "açıklama var ama okunamıyor" izlenimi verirdi.
            if ((talep.teklifAciklamasi ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              // ⚠ ORTAK KART: hizmet veren tarafıyla BİREBİR aynı
              // görünüm; değişen yalnız başlık, çünkü iki taraf aynı
              // metne kendi açısından bakıyor.
              TeklifAciklamaKarti(
                  // ⚠ "Hizmet Verenin Açıklaması" DEĞİL (12 Eyl,
                  // kullanıcı kararı): oradaki metin bir beyan değil,
                  // hizmet verenin fiyatının yanına iliştirdiği kısa
                  // bir nottur. "Açıklama" hem fazla ağır kaçıyor hem
                  // de ilan açıklamasıyla karışıyordu.
                  baslik: 'Hizmet Verenin Notu',
                  metin: talep.teklifAciklamasi!.trim()),
            ],
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
            // ⚠ ÜÇ NOKTA BURADAN DA ALINDI (9 Eyl): ekranın sağ üst
            // köşesinde TEK bir yerde. İki farklı durumda iki ayrı
            // konumda çizilmesi, menünün nerede olduğunu
            // öğrenilemez kılıyordu.
            //
            // ⚠ MENÜ AKIŞI DEĞİŞMEDİ: aynı `_talepMenusu()` — talebi
            // silme, onay ve gerekçe sorma.
            //
            // ⚠ TAM GENİŞLİK ŞART (kullanıcı isteği, 9 Eyl): üç nokta
            // yanından kalkınca düğme eski dar hâlinde kalıp "yarım"
            // görünüyordu. Saran `Column`un hizası `start` olduğu için
            // düğme kendi doğal genişliğinde kalıyordu; `SizedBox` ile
            // satırın tamamına yayılır ve yazı ortalanır.
            SizedBox(
              width: double.infinity,
              child: RefPrimaryButton('Teklifi Seç', onPressed: onSec),
            ),
          ],
        );

      case TeklifTalebiDurumu.secildi:
        // ── ⚠ İLAN AKIŞIYLA AYNI ŞERİT (12 Eyl, kullanıcı isteği) ──
        //
        // "Bul ile seçilen ilanlarda da teklif seçilince, ilan
        // oluşturma ekranındaki yazının aynısı yazılsın."
        //
        // Burada yeşil düz bir metin vardı ("Teklif Seçildi"); ilan
        // akışında ise yeşil zeminli, tik ikonlu bir şerit. Aynı olay
        // iki akışta iki farklı görünümdeydi.
        //
        // ⚠ ORTAK BİLEŞEN: `DurumSeridi`. Zemin, tik ve ölçü orada
        // tek yerde; ekran kendi şeridini çizmez.
        return const DurumSeridi('Teklif seçildi');

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
            if (yorum == null) ...[
              RefPrimaryButton('Yorum Yaz',
                  iconAsset: 'assets/svg/ic_starfill.svg',
                  onPressed: onYorumYaz),
              // ⚠ İLAN AKIŞIYLA AYNI: orada da düğmenin ALTINDA
              // "Teklif seçildi" şeridi duruyor. Seçimin yapıldığını
              // söyleyen kalıcı iz, yorum yazılana kadar kalır.
              const DurumSeridi('Teklif seçildi'),
            ] else
              // ── ⚠ KART KALKTI, SADE YAZI KALDI (kullanıcı
              // isteği, 9 Eyl) ──
              //
              // Bu bölüm sırayla üç hâl aldı: önce tek satırlık yeşil
              // şerit, sonra yıldız + puan + metin taşıyan bir kart,
              // şimdi ortalı ve sade bir yazı.
              //
              // GEREKÇE: bu ekranın ana konusu TALEP; yorum, işin
              // bittiğini söyleyen bir dipnot. Yıldızlı kart, hemen
              // üstündeki "Yorumlar" bölümüyle görsel olarak
              // yarışıyordu ve aynı yorum sayfada iki kez
              // görünüyordu.
              //
              // ⚠ GÖRÜNTÜLEME YOLU KAYBOLMADI: yazıya dokununca yine
              // salt okunur değerlendirme ekranı açılır. Kullanıcının
              // "yorumu ve puanı sonradan görebilmeli" kuralı
              // korunuyor.
              //
              // ⚠ MAVİ RENK BİLEREK: metin dokunulabilir olduğunu
              // kendisi söylemeli; kutu ya da çerçeve olmadığı için
              // tek ipucu renktir.
              // ── ⚠ İLAN AKIŞIYLA AYNI ŞERİT (12 Eyl, kullanıcı
              // isteği) ──
              //
              // Burada mavi düz bir "Yorum yapıldı" yazısı vardı;
              // dokunulabilir olduğunu yalnız RENK söylüyordu. İlan
              // akışında ise yeşil zemin, tik ve altı çizili
              // "Görüntüle" + ok vardı.
              //
              // ⚠ GÖRÜNTÜLEME YOLU AYNEN KORUNDU: dokununca yine
              // salt okunur değerlendirme ekranı açılır.
              RefTap(
                onTap: onYorumYaz,
                borderRadius: BorderRadius.circular(RR.r9),
                child: const DurumSeridi('Yorum yapıldı',
                    aksiyon: 'Görüntüle'),
              ),
          ],
        );
    }
  }
}

/// ⚠ BEŞİNCİ KOPYA KALDIRILDI (9 Eyl): hizmet verenin tamamlanmış iş
/// sayımı `domain/saglayici_ozeti.dart` içindeki `tamamlananIsSayisi`
/// ile TEK yerde. Bu dosyadaki kopya, kartın ortak bileşene
/// taşınmasıyla kullanılmaz hâle geldi.

/// ── ⚠ "BEKLENİYOR" GÖSTERGESİ — KART ROZETİYLE AYNI DİL ──
///
/// KULLANICI SORUSU (9 Eyl): "Bu ekranda da aynı yazı ve işleyişle
/// uygulandı mı?" — HAYIR, uygulanmamıştı. İki fark vardı:
///
///   1. METİN AYRIYDI — listede "Teklif bekleniyor", burada "Hizmet
///      verenin teklifi bekleniyor."
///   2. ANİMASYON AYRIYDI — listede sırayla parlayan üç nokta,
///      burada nabız atan bir gönderi ikonu.
///
/// ⚠ KULLANICININ KESİN KURALI: aynı metin/kural birden çok ekranda
/// görünüyorsa önce TEK KAYNAĞA taşınır. Noktalar artık ortak
/// `BekleyenNoktalar` bileşeninden geliyor; metin de `DurumRozeti`nin
/// kullandığı ifadeyle aynı.
///
/// ⚠ İKON KALDI, NABIZ GİTTİ: kutunun kimliği olan gönderi ikonu
/// duruyor ama artık yanıp sönmüyor. İki ayrı animasyonun aynı anda
/// oynaması "canlı" değil huzursuz görünürdü; hareket TEK yerde.
///
/// ⚠ `w600` DÜZELTİLDİ: pubspec'te Poppins'in yalnız 400/500/700
/// ağırlıkları var; `w600` sentezlenip bulanık basıyordu (ilan
/// açıklaması tipografisinde kurulan kural).
class _BeklemeGostergesi extends StatelessWidget {
  const _BeklemeGostergesi();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RC.blueSoft,
        borderRadius: BorderRadius.circular(RR.r13),
      ),
      // ⚠ GÖNDERİ İKONU KALDIRILDI (kullanıcı isteği, 10 Eyl):
      // kutunun solundaki mavi daire çıkarıldı. Kutu zaten mavi
      // zeminli ve metin ne beklendiğini söylüyordu; ikon fazladan
      // bir görsel ağırlıktı.
      child: Row(
        // ⚠ NOKTALAR SATIRIN ALTINA HİZALANIR (kullanıcı isteği):
        // ortada duruyorlardı, "Teklif bekleniyor..." gibi bir üç
        // nokta izlenimi vermiyorlardı. `end` hizası noktaları metin
        // kutusunun ALT kenarına indirir.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(kTeklifBekleniyorMetni,
                style: refText(
                    size: RF.s135, weight: RF.w700, color: RC.text)),
          ),
          const SizedBox(width: 4),
          // ⚠ ALT DOLGU: `end` hizası noktaları metin kutusunun EN
          // altına, yani alt uzantı (descender) hizasına indirir;
          // 3 px yukarı alınca yazının TABAN çizgisine oturur ve
          // gerçek bir üç nokta gibi görünür.
          const Padding(
            padding: EdgeInsets.only(bottom: 3),
            // ⚠ Kutu geniş olduğu için nokta çapı büyütüldü; kural ve
            // zamanlama AYNI bileşenden geliyor.
            child: BekleyenNoktalar(renk: RC.blue, cap: 5),
          ),
        ],
      ),
    );
  }
}


