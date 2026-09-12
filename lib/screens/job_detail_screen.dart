import 'dart:async';
import 'widgets/ilan_no_etiketi.dart';
import 'widgets/ilan_baslik_satiri.dart';
import '../domain/iletisim_maskesi.dart';
import 'widgets/is_zamani_secici.dart';
import '../domain/form_mesajlari.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../core/tutar_bicimi.dart';
import '../data/controllers/auth_controller.dart';
// ⚠ YALNIZ `Role`: fotoğraf rol bazlıdır (bkz. Account.fotografi).
import '../data/models/account.dart' show Role;
import '../data/controllers/contact_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/models/listing.dart';
import '../data/models/teklif_talebi.dart' show IletisimTercihi;
import '../data/models/offer.dart';
import '../domain/config.dart';
import '../data/controllers/profile_controller.dart';
import '../data/models/provider_approval.dart';
import 'provider_status_screen.dart';
// ⚠ `status_ui.dart` importu KALDIRILDI (10 Eyl): bu ekranda artık
// ne `offerStatusUi` ne `tl` kullanılıyor — teklif durum kutusu
// kaldırıldı ve tutarlar `core/tutar_bicimi.dart`tan biçimleniyor.
import 'widgets/hc_widgets.dart';
import 'widgets/foto_goruntuleyici.dart';
import '../ui/ref_widgets.dart';
import '../domain/kullanici_konumu.dart';
import '../domain/yorum_gorunumu.dart' show kisaTarih;
import '../ui/ref_tokens.dart';
import '../data/controllers/incelenen_ilan_controller.dart';
import 'chat_screen.dart';
import '../core/validators.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/telefon_bicimi.dart';
import 'widgets/detay_karti_parcalari.dart';
import 'widgets/teklif_tutar_karti.dart';
import 'widgets/teklif_aciklama_karti.dart';

/// Hizmet veren — İlan Detayı (HTML vProvListing):
/// ilan bilgisi + teklif formu (tutar + en az 5 kelime not) → teklifle 50 TL bloke;
/// teklif verdiyse: teklif kartı ve İletişim Bilgilerini Aç.
/// ⚠ Teklif geri çekilemez (API sözleşmesi §1).
class JobDetailScreen extends StatefulWidget {
  final String listingId;
  const JobDetailScreen({super.key, required this.listingId});
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

// ── ⚠ EKRAN KORUMASI AÇIK ──
//
// Bu ekranda iletişim açıldıktan sonra ad ve telefon görünür.
class _JobDetailScreenState extends State<JobDetailScreen>
 {
  final _amt = TextEditingController();

  /// ⚠ ZORUNLU ALANLARIN İKİSİ DE DOLU MU?
  ///
  /// Düğme yalnız o zaman aktif olur. Boş alan uyarısı hiç
  bool get _zorunlularDolu =>
      _amt.text.trim().isNotEmpty;
  /// Teklif notu — İSTEĞE BAĞLI.
  final _note = TextEditingController();
  String? _amtError, _formError;
  bool _busyOffer = false, _busyContact = false;

  /// PLATFORM ONAY DURUMU — teklif formu gösterilmeden ÖNCE okunur.
  /// Onaysız hizmet veren 403 beklemez; durumunu baştan görür.
  ProviderApprovalState? _approval;

  @override
  void dispose() {
    _note.dispose();
    _amt.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApproval();
      // ⚠ İlan İNCELENDİ olarak işaretlenir; liste ekranında
      // başlığı koyu ağırlıktan normale döner.
      context.read<IncelenenIlanController>().isaretle(widget.listingId);
    });
  }

  /// Onay durumu TEK KAYNAKTAN (ProfileController) okunur; mock/gerçek
  /// ayrımını port katmanı yapar. Hata durumunda ONAYLI SAYILMAZ.
  Future<void> _loadApproval() async {
    final ctl = context.read<ProfileController>();
    await ctl.loadApproval();
    if (!mounted) {
      return;
    }
    setState(() => _approval = ctl.approval ?? ProviderApprovalState.unknown);
  }


  Future<void> _placeOffer() async {
    if (_busyOffer) {
      return;
    }
    setState(() { _amtError = null; _formError = null; });
    // ⚠ `int.tryParse` DEĞİL: alan artık binlik ayracı taşıyor
    // ("3.000"); doğrudan çözümlenirse null döner ve geçerli tutar
    // REDDEDİLİRDİ (teklif talebi ekranında yaşanan aynı tuzak).
    final amount = tutarOku(_amt.text);
    var ok = true;
    if (amount == null || amount <= 0) {
      _amtError = FormMesaj.teklifTutari;
      ok = false;
    }
    setState(() {});
    if (!ok) {
      return;
    }
    setState(() => _busyOffer = true);
    final me = context.read<AuthController>().currentAccount!;
    // Bloke ve bakiye sonucu kaynağın kesin cevabından sonra yansır.
    final err = await context.read<OfferController>().placeOffer(
        listingId: widget.listingId,
        providerId: me.id,
        amount: amount!,
        note: _note.text.trim());
    if (!mounted) {
      return;
    }
    setState(() => _busyOffer = false);
    if (err != null) {
      setState(() => _formError = err.message);
      return;
    }
    sysToastOk(context, 'Teklifiniz gönderildi');
  }

  @override
  Widget build(BuildContext context) {
    // ⚠ OTURUM DÜŞERSE ÇÖKME YOK.
    //
    // Bu ekran `RoleGuard` ile SARILMAZ; `MaterialPageRoute` ile
    // doğrudan açılır. Oturum ekran açıkken düşerse (401 → logout)
    // `AuthController` bildirim yayar, `build` yeniden koşar ve
    // `currentAccount!` null denetimini patlatıp kırmızı ekran
    // üretiyordu. Artık kontrollü oturum durumu gösterilir.
    final me = context.watch<AuthController>().currentAccount;
    if (me == null) {
      return const Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(child: Center(child: SysState(SysKind.sessionExpired))),
      );
    }
    final listingCtl = context.watch<ListingController>();
    final offerCtl = context.watch<OfferController>();
    // İletişim açıldığında ekran yeniden çizilmeli (buton → sohbet).
    final contactCtl = context.watch<ContactController>();
    final auth = context.watch<AuthController>();
    final l = listingCtl.byId(widget.listingId);
    if (l == null) {
      return Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: Column(children: [
            const Expanded(
              child: Center(
                child: SysEmpty(
                    title: 'İlan bulunamadı',
                    desc: 'Bu ilan kaldırılmış olabilir.'),
              ),
            ),
          ]),
        ),
      );
    }
    final mine = offerCtl.myOfferFor(l.id, me.id);
    // ⚠ Rozet tamamlanmışlığı da kapsar (§24) — hizmet veren, işin
    // tamamlandığını ilan durumundan değil ilişkiden görür.
    //
    // ⚠ NULLABLE — "Açık" durumunda `null` döner, kullanıcı isteğiyle
    // rozet hiç çizilmez (bkz. `status_ui.dart`daki not).
    // ⚠ `listingRozetiUi` ARTIK ÇAĞRILMIYOR (9 Eyl): "Tamamlandı"
    // rozeti kaldırıldı. Yardımcının kendisi duruyor, öteki ekranlar
    // kullanıyor.
    final owner = auth.accountById(l.ownerId);

    // ⚠ MASKELEME: iletişim bilgisi AÇILMADAN önce ilan sahibinin adı
    // maskeli gösterilir (HTML `PL_OWNERS` → `PL_OWNERS_FULL`).
    final iletisimAcik = mine != null && contactCtl.isOpen(mine.id);
    final tamAd = owner?.name.trim() ?? '';
    final sahipAdi = iletisimAcik ? tamAd : maskeliAd(tamAd);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ⚠ GERİ OKU HER PLATFORMDA VARDIR (nihai karar).
            const Align(
              alignment: Alignment.centerLeft,
              child: RefBackButton(),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  border: Border.all(color: HC.border),
                  borderRadius: BorderRadius.circular(15)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── ⚠ İLAN NUMARASI KARTIN EN ÜST SAĞINDA
                // (kullanıcı isteği, 10 Eyl) ──
                //
                // ÖNCEDEN kartın ORTASINDA, kategori ikonunun
                // yanındaki sütunun içindeydi; o sütun `Expanded`
                // olduğu için numara kartın gerçek sağ kenarına
                // değil, o sütunun sağına yaslanıyordu ve ikonun
                // hizasını da bozuyordu.
                //
                // ⚠ ORTAK BİLEŞEN: `IlanNoEtiketi` kendi içinde sağa
                // yaslı; kartın TAM genişliğinde ayrı bir satır
                // olunca gerçek köşeye oturur.
                IlanNoEtiketi(l.ilanNo),

                // ── .pl-own — ilan sahibi kartı ──
                //
                // ⚠ MASKELEME: iletişim AÇILMADAN önce ad maskeli
                // (`E*** K******`) ve avatar KİLİTLİ gösterilir.
                // Açıldığında gerçek ad + doğrulama rozeti gelir.
                SahipKarti(
                  adSoyad: sahipAdi,
                  acik: iletisimAcik,
                  // ⚠ FOTOĞRAF YALNIZ İLETİŞİM AÇIKKEN: maskeleme
                  // kuralının parçasıdır, ayrı bir kural değildir.
                  //
                  // ⚠ HİZMET ALAN ROLÜNÜN fotoğrafı: ilan sahibi bu
                  // ekranda müşteri kimliğiyle görünür.
                  fotoYolu: iletisimAcik
                      ? (context
                              .watch<AuthController>()
                              .accountById(l.ownerId)
                              ?.fotografi(Role.customer) ??
                          '')
                      : '',
                  tamamlananIs: listingCtl
                      .byOwner(l.ownerId)
                      // ⚠ Tamamlanmışlık ilişkiden türetilir (§24).
                      .where((x) => x.isTamamlanmisIs)
                      .length,
                  // ⚠ YENİ — kullanıcı isteği: hizmet alanın ne
                  // zamandır üye olduğu, tamamlanan iş sayısının
                  // altına eklendi.
                  kayitTarihi: owner?.kayitTarihi,
                ),

                // .pl-div{height:1px;background:#F2F4F7;margin:12px 0}
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                      height: 1, child: ColoredBox(color: Color(0xFFF2F4F7))),
                ),

                // ── .ld-top — kategori ikonu + kategori + başlık ──
                //
                // ⚠ ORTAK BİLEŞENE TAŞINDI (12 Eyl): aynı satır
                // `listing_detail_screen`de de vardı ve iki kopya üç
                // ayrı yerde ayrışmıştı (hiza, ikon çözücü, dikey
                // hizalama değeri). Kural artık `IlanBaslikSatiri`
                // içinde tek yerde.
                //
                // ⚠ `meta` VERİLMEZ: konum + "az önce" satırı bu
                // ekranda TEKRAR ediyordu; aynı bilgi aşağıdaki
                // "İlan Detayı" bölümünde (İl/İlçe/Mahalle, İlan
                // Tarihi) zaten var.
                //
                // ⚠ İLAN NUMARASI BURAYA GİRMEZ: kartın en üstünde
                // ayrı satır olarak yukarıda çizildi.
                //
                // ⚠ DURUM ROZETİ KALDIRILDI (kullanıcı isteği,
                // 9 Eyl): "Tamamlandı" yazısı bu ekranda gereksizdi
                // — aşağıdaki teklif kartı zaten işin durumunu
                // söylüyor ve rozet, ilan numarasını sağ köşeden
                // ittiriyordu.
                IlanBaslikSatiri(baslik: l.title),
                // .pl-h2{15px/700;margin:14px 0 7px}
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 7),
                  child: Text('İlan Detayı',
                      style: refText(
                          size: 15, weight: RF.w700, color: RC.text)),
                ),
                // ── ⚠ BÖLÜM AYRAÇLARI (12 Eyl, kullanıcı bulgusu) ──
                //
                // "Talep detayı, zaman tercihi, işin detayı ve
                // fotoğraflar iç içe geçmiş, ne olduğu anlaşılmıyor."
                //
                // Kartın ALT tablosunda zaten gri çizgiler vardı;
                // üstteki bölümlerde yoktu. Etiket + değer çiftleri
                // arka arkaya dizilince tek blok gibi görünüyordu.
                //
                // ⚠ ÇİZGİ ORTAK BİLEŞENDEN: renk ve boşluk
                // `BolumAyraci` içinde: iki detay ekranı ayrışamaz.
                const BolumAyraci(),
                // ── ⚠ İŞİN YAPILMASI İSTENEN ZAMAN ──
                //
                // Hizmet veren için işin ne zaman isteneceği teklif
                // kararını doğrudan etkiler; açıklamadan ÖNCE görünür.
                //
                // ⚠ SEÇİM YOKSA HİÇ ÇİZİLMEZ — `IsZamaniRozeti`
                // `null` durumunda boş döner, yer tutucu göstermez.
                //
                // ⚠ ETİKET EKLENDİ — kullanıcı bulgusu: chip tek
                // başına ("Hemen"/"Acil") ne olduğu belirsizdi.
                if (l.isZamani != null) ...[
                  Text('Zaman tercihi',
                      style: refText(
                          size: RF.s12, weight: RF.w400, color: RC.grey)),
                  const SizedBox(height: 4),
                  IsZamaniRozeti(l.isZamani),
                  // ⚠ BOŞLUK YERİNE ÇİZGİ: 10 px'lik ara iki bölümü
                  // ayırmaya yetmiyordu.
                  const BolumAyraci(),
                ],

                // ── İLAN AÇIKLAMASI ──
                // ⚠ Referans `.pl-desc{12.8px;#3A4658;line-height:1.6}`
                // idi. Ortak standarda çekildi (bkz. listing_detail):
                // 13,5/w500/RC.text. Aynı içeriğin iki detay ekranında
                // farklı görünmesi için sebep yok.
                // ── ⚠ İLETİŞİM KAPALIYKEN MASKELİ ──
                //
                // Hizmet alan açıklamaya telefon/adres yazarak bedelli
                // iletişim adımını atlatabilir. İletişim AÇILANA KADAR
                // bu bilgiler maskelenir; açıklamanın geri kalanı
                // normal görünür.
                //
                // ⚠ İletişim açıksa metin AYNEN gösterilir (mevcut
                // `iletisimAcik` kullanılır; yeni mekanizma yok).
                //
                // ⚠ ETİKET EKLENDİ — "Zaman tercihi" ile AYNI görsel
                // dil, kullanıcı bulgusu.
                Text('İşin detayı',
                    style: refText(
                        size: RF.s12, weight: RF.w400, color: RC.grey)),
                const SizedBox(height: 4),
                Text(gorunenMetin(l.desc, iletisimAcik: iletisimAcik),
                    style: refText(
                        size: RF.s135,
                        weight: RF.w500,
                        color: RC.text,
                        height: RF.lh155)),

                // ── .pl-rows — Kategori / İl-İlçe-Mahalle / Tarih ──
                Container(
                  margin: const EdgeInsets.only(top: 11),
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: kDetayAyracRengi))),
                  child: Column(children: [
                    // ⚠ "Kategori" SATIRI KALDIRILDI (kullanıcı
                    // isteği, 10 Eyl): aynı bilgi kartın üstünde,
                    // kategori ikonunun yanında ZATEN yazıyor
                    // ("Doğalgaz"). Alt bilgi tablosunda ikinci kez
                    // tekrar ediyordu.
                    BilgiSatiri(
                        ikon: 'assets/svg/ic_pin.svg',
                        etiket: 'İl / İlçe / Mahalle',
                        // ⚠ GÜNCEL ADRES (9 Eyl): donmuş kopya
                        // yerine ilan sahibinin adresi.
                        deger: kullaniciKonumu(context, l.ownerId,
                                mahalleDahil: true) ??
                            l.location),
                    BilgiSatiri(
                        ikon: 'assets/svg/ic_nclock.svg',
                        etiket: 'İlan Tarihi',
                        // ── ⚠ GÖRELİ SÜRE DEĞİL, TARİH (12 Eyl,
                        // kullanıcı isteği) ──
                        //
                        // "Az önce" / "21 dk önce" bir SAAT
                        // bilgisiydi; etiket "İlan Tarihi" diyorsa
                        // değer de tarih olmalı.
                        //
                        // ⚠ BUL AKIŞIYLA EŞİTLENDİ: orada "Talep
                        // Tarihi" aynı biçimi kullanıyor. Aynı satır
                        // iki akışta iki farklı şey gösteremez.
                        deger: kisaTarih(l.createdAt)),
                  ]),
                ),
                // HTML vProvListing: ek fotoğraflar
                if (l.photoPaths.isNotEmpty) ...[
                  // ⚠ TABLONUN ALT ÇİZGİSİ YOK: `BilgiSatiri` yalnız
                  // satır ARALARINA çizgi koyar. Ayraç olmadan
                  // fotoğraf başlığı tarih satırına yapışıyordu.
                  const BolumAyraci(),
                  Text('Ek Fotoğraflar (${l.photoPaths.length})',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: HC.dark)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: l.photoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      // ⚠ FOTOĞRAF GERÇEKTEN ÇİZİLİR.
                      //
                      // Önceden her fotoğraf için yalnız mavi zeminli
                      // bir KAMERA İKONU çiziliyordu: hizmet veren,
                      // ilanın fotoğrafını hiç göremiyordu. Artık
                      // görsel gösterilir ve dokunulunca TAM EKRAN
                      // açılır — hizmet alan tarafıyla aynı davranış.
                      itemBuilder: (_, i) => RefTap(
                        onTap: () => FotoGoruntuleyici.ac(context,
                            yollar: l.photoPaths, baslangic: i),
                        borderRadius: BorderRadius.circular(11),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: SizedBox(
                            width: 76,
                            height: 76,
                            child: Image.file(
                              File(l.photoPaths[i]),
                              fit: BoxFit.cover,
                              // Dosya açılamazsa çökme YERİNE yer tutucu.
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: HC.softBlue,
                                child: const Center(
                                  child: RefSvg('assets/svg/ic_gallery.svg',
                                      size: 24, color: RC.blue),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 14),

            // ── ONAY DURUMU UYARISI ──
            // Onaysız hesapta teklif formu GÖSTERİLMEZ; bunun yerine
            // durum ve gerekçe açıkça anlatılır.
            // ── ⚠ ACTIVE + SEÇİLMİŞ TEKLİF = TEKLİF ALINMAZ (§22) ──
            //
            // İlan `active` kalmaya devam eder ama seçilmiş teklifi
            // varsa iş TAMAMLANMIŞTIR. Yalnız duruma bakan koşul
            // "ACTIVE olduğu için teklif verilebilir" yanılgısına
            // düşüyordu; tamamlanmışlık ayrıca denetlenir.
            if (mine == null &&
                l.status == ListingStatus.active &&
                !l.isTamamlanmisIs &&
                _approval != null &&
                !_approval!.canPlaceOffer) ...[
              ProviderStatusCard(state: _approval!),
              const SizedBox(height: 14),
            ],

            // ⚠ Aynı kapı burada da: tamamlanmış işe teklif verilemez.
            if (mine == null &&
                l.status == ListingStatus.active &&
                !l.isTamamlanmisIs &&
                (_approval?.canPlaceOffer ?? false)) ...[
              const Text('Ücretsiz Teklif Ver',
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800, color: HC.dark)),
              const SizedBox(height: 10),
              TextField(
                // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                controller: _amt,
                // ⚠ Değer değişince YALNIZ bu alanın hatası düşer;
                // öteki alanın geçerli hatası SİLİNMEZ. Düğme durumu
                // da burada tazelenir.
                onChanged: (_) => setState(() => _amtError = null),
                keyboardType: TextInputType.number,
                // ── ⚠ CANLI BİNLİK AYRACI (kullanıcı isteği, 10 Eyl) ──
                //
                // BULGU: "Bu ekranda girilen tutarlarda noktalamayı
                // teklif talebindeki gibi otomatik koymuyor."
                //
                // Teklif talebi ekranı `TutarBicimlendirici` kullanıyordu,
                // bu alan ise yalnız rakama süzüp uzunluk sınırlıyordu:
                // aynı iş için iki farklı giriş davranışı vardı.
                //
                // ⚠ `digitsOnly` KALDIRILDI: biçimlendirici zaten rakam
                // dışındaki her şeyi atıyor; ikisi birlikte çalışsaydı
                // `digitsOnly` eklenen noktaları da silerdi.
                //
                // ⚠ UZUNLUK SINIRI DA KALDIRILDI: 6 KARAKTER sayıyordu,
                // ama "1.000.000" dokuz karakter — ayraçlar eklenince
                // sınır rakamdan önce dolar ve kullanıcı tutarı
                // yazamazdı. Sınır artık biçimin kendisinde: alan
                // rakam kabul eder, üst sınır iş kuralıdır.
                inputFormatters: const [TutarBicimlendirici()],
                // ⚠ REFERANSTA BİRİM SAĞDADIR.
                //
                // Etikette `(₺)`, solda cüzdan ikonu vardı; referansta
                // ikon yok, birim alanın SAĞINDA `TL` olarak yazar.
                decoration: InputDecoration(
                    labelText: 'Teklif Tutarı',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
                      child: Text('TL',
                          style: refText(
                              size: RF.s145,
                              weight: RF.w700,
                              color: RC.text)),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: 'Teklif tutarınızı girin',
                    errorText: _amtError),
              ),
              const SizedBox(height: 12),
              // ── NOT ──
              //
              // ⚠ İSTEĞE BAĞLI: boş bırakılabilir, düğmeyi pasif
              // yapmaz. Hizmet veren isterse teklifiyle birlikte kısa
              // bir açıklama yazar.
              TextField(
                scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                controller: _note,
                onChanged: (_) => setState(() {}),
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notunuz (isteğe bağlı)',
                  hintText: 'Örn. Aynı gün gelebilirim.',
                  alignLabelWithHint: true,
                ),
              ),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(_formError!,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: HC.red)),
                ),
              const SizedBox(height: 12),
              // ⚠ Referansta düğme metni bölüm başlığıyla AYNIDIR ve
              // solunda uçak (gönder) ikonu bulunur.
              // ⚠ Referansta düğme metni bölüm başlığıyla AYNIDIR ve
              // solunda uçak (gönder) ikonu bulunur.
              //
              // `SysButton` ikon almaz; `RefPrimaryButton` alır ve
              // uygulamanın diğer birincil düğmeleri de onu kullanır.
              // ⚠ ZORUNLU ALANLAR DOLMADAN PASİF.
              //
              // Eksik formla basılabildiği için kullanıcı önce hata
              // görüyordu. Ortak kural: eksik alanla düğme aktif
              // OLMAZ, dolayısıyla "zorunludur" uyarısı da çıkmaz.
              RefPrimaryButton('Ücretsiz Teklif Ver',
                  iconAsset: 'assets/svg/ic_plane.svg',
                  busy: _busyOffer,
                  onPressed: _zorunlularDolu ? _placeOffer : null),
            ] else if (mine != null) ...[
              // ── ⚠ TEKLİF TUTARI ORTAK KARTTAN (12 Eyl, kullanıcı
              // isteği) ──
              //
              // Bu kart burada ELLE çiziliyordu ve Bul akışındaki
              // ikizinden üç yerde ayrışıyordu:
              //   · başlık "Verdiğiniz Teklif" / "Verilen teklif"
              //   · başlık ölçüsü 14.5 w800 / 12.5 w500
              //   · tutar 30 punto MAVİ / 26 punto KOYU
              //
              // Aynı bilgi, aynı kullanıcıya, iki akışta iki farklı
              // ağırlıkta görünüyordu. Kart artık `TeklifTutarKarti`;
              // ölçü ve renk tek yerde.
              //
              // ⚠ DURUM VE ZAMAN SATIRLARI GERİ GELMEDİ (9 Eyl
              // kararı): iletişim durumunu alttaki telefon/mesaj
              // kutuları söylüyor, teklifin saati kararı etkilemiyor.
              TeklifTutarKarti(mine.amount),

              // ── ⚠ "Notunuz" BÖLÜMÜ EKLENDİ (12 Eyl, kullanıcı
              // isteği) ──
              //
              // 10 Eyl'de buradan kaldırılmıştı; gerekçe "hizmet veren
              // kendi yazdığı metni kendine geri okuyor, bilgi
              // taşımıyor" idi. Kullanıcı kararı bu gerekçeyi
              // geçersiz kıldı: Bul akışının aynı ekranında "Notunuz"
              // kartı duruyor ve iki akış birebir aynı olmalı.
              //
              // ⚠ AYNI ORTAK KART, AYNI BAŞLIK: karşı tarafta
              // "Hizmet Verenin Notu" yazan şey kendi tarafında
              // "Notunuz"dur.
              //
              // ⚠ NOT BOŞSA KART HİÇ ÇİZİLMEZ: boş bir çerçeve,
              // yazılmış ama okunamayan bir mesaj izlenimi verir.
              if (mine.note.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                TeklifAciklamaKarti(
                    baslik: 'Notunuz', metin: mine.note.trim()),
              ],

              const SizedBox(height: 12),

              // ── ⚠ TUTAR/DURUM KUTUSU TAMAMEN KALDIRILDI
              // (kullanıcı isteği, 10 Eyl) ──
              //
              // Telefon ve mesaj kutularının hemen üstünde
              // "5.000 TL · Aktif" yazan çerçeveli bir kutu vardı.
              //
              // Tutar zaten hemen ÜSTÜNDEKİ mavi "Verdiğiniz Teklif"
              // kartında büyük puntoyla yazıyordu; aynı sayı aynı
              // ekranda iki kez görünüyordu. Durum rozeti de tek
              // başına bir kutuyu hak etmiyordu.
              //
              // ⚠ O TURDA TEKLİF NOTU DA GİTMİŞTİ, 12 Eyl'de GERİ
              // GELDİ: artık yukarıda "Notunuz" başlıklı ortak kartla
              // çiziliyor. Eski gerekçe ("kendi yazdığını kendine
              // okutmak bilgi taşımıyor") Bul akışıyla çelişiyordu;
              // orada aynı kart hep duruyordu.
              //
              // ⚠ KALDIRILAN ŞEY KUTUNUN KENDİSİ: "5.000 TL · Aktif"
              // satırı geri gelmedi.
              //
              // ⚠ `offerStatusUi` KALDIRILMADI — öteki ekranlar
              // kullanıyor.

              const SizedBox(height: 12),

              // ⚠ KUTULAR HER ZAMAN ÇİZİLİR.
              //
              // Kapalıyken maskeli değer ve kilit rozeti gösterilir;
              // açıldığında aynı kutular gerçek veriyle dolar. Referans
              () {
                final acik = contactCtl.isOpen(mine.id);
                // ⚠ EKSİKTİ — `Listing.iletisimTercihi` HİÇ
                // OKUNMUYORDU, telefon yalnız `acik` durumuna göre
                // (koşulsuz) gösteriliyordu. Artık ilan sahibi
                // "Sadece Uygulama İçi Mesaj" SEÇTİYSE, iletişim
                // açılsa bile telefon HİÇ gösterilmez — "Doğrudan
                // Teklif İste" akışındaki (`teklif_talebi_detay_
                // screen.dart`taki `telefonAcik`) AYNI kural.
                final telefonAcik =
                    acik && l.iletisimTercihi == IletisimTercihi.telefonGoster;
                return
                // ── `.pr-cgrid` — İKİ SÜTUNLU İLETİŞİM KARTLARI ──
                //
                // ⚠ Referansta TELEFON ve MESAJLAŞMA yan yana iki
                // kutudur; her kutuda 34px daire ikon, etiket, değer
                // ve sağda kilit rozeti bulunur.
                //
                // Önceki hâl TEK geniş satırdı ve MESAJLAŞMA kutusu
                // hiç yoktu — hizmet veren, iletişim açıldıktan sonra
                // sohbete nereden gireceğini göremiyordu.
                //
                // ⚠ `IntrinsicHeight` + `stretch` EKLENDİ — kilitliyken
                // Telefon kutusu (`deger`+`not`, 2 satır) Mesajlaşma
                // kutusundan (yalnız `not`, 1 satır) DAHA UZUNDU, iki
                // kutu FARKLI yükseklikte görünüyordu. `offer_detail_
                // screen.dart`daki AYNI çözüm buraya da uygulandı.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(
                    child: IletisimKutusu(
                      ikon: 'assets/svg/ic_phone_f.svg',
                      etiket: 'Telefon',
                      // ⚠ KİLİTLİYKEN ARTIK `null` — Mesajlaşma
                      // kutusuyla TUTARLI: ikisi de kilitliyken yalnız
                      // `not` (açıklama) gösterir, maskeli numara
                      // AYRICA gösterilmez (zaten gizli bilgi, tekrar
                      // sayılır).
                      //
                      // ⚠ ARTIK `acik` DEĞİL `telefonAcik` — bkz.
                      // yukarıdaki `telefonAcik` tanımı: ilan sahibi
                      // "Sadece Uygulama İçi Mesaj" seçtiyse iletişim
                      // açılsa bile telefon HİÇ gösterilmez.
                      deger: telefonAcik
                          ? TelefonBicimlendirici.gruplu(
                              Validators.phoneLocal(owner?.phone ?? ''))
                          : null,
                      // Referansta açık telefon BAĞLANTI gibi altı
                      // çizilidir; dokunulabilir olduğu böyle anlaşılır.
                      altiCizili: telefonAcik,
                      not: telefonAcik
                          ? null
                          : 'Kilitli',
                      kilitli: !telefonAcik,
                      onTap: telefonAcik
                          ? () => _telefonAra(context, owner?.phone)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 11), // .pr-cgrid{gap:11px}
                  Expanded(
                    child: IletisimKutusu(
                      ikon: 'assets/svg/ic_chat.svg',
                      etiket: 'Mesajlaşma',
                      // Referans: açıkken `Mesaj yaz`.
                      deger: acik ? 'Mesaj yaz' : null,
                      not: acik
                          ? null
                          : 'Kilitli',
                      kilitli: !acik,
                      // ⚠ AÇIK UÇ KAPATILDI: sohbete giriş buradan.
                      onTap: acik
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ChatScreen(offerId: mine.id)),
                              )
                          : null,
                    ),
                  ),
                ],
                  ),
                );
              }(),

              // ⚠ "İletişimi Aç" düğmesi YALNIZ kapalıyken ve teklif
              // aktifken görünür.
              if (!contactCtl.isOpen(mine.id) &&
                  mine.status == OfferStatus.active) ...[
                const SizedBox(height: 10),
                SysButton('İletişimi Aç',
                    busy: _busyContact,
                    onPressed: () async {
                      if (_busyContact) {
                        return;
                      }
                      setState(() => _busyContact = true);
                      final err = await context
                          .read<ContactController>()
                          .openShared(mine.id, actorId: me.id);
                      // ⚠ İKİ AYRI DENETİM: `setState` STATE'in
                      // mounted'ını, toast ise `context`'in canlı
                      // olmasını gerektirir.
                      if (!mounted) {
                        return;
                      }
                      setState(() => _busyContact = false);
                      if (!context.mounted) {
                        return;
                      }
                      if (err != null) {
                        sysToastErr(context, SysKind.genericError,
                            extra: err.message);
                      } else {
                        sysToastOk(context,
                            'İletişim açıldı — ücret blokenizden kullanıldı');
                      }
                    }),
              ],
              // ── ⚠ İLETİŞİM AÇILDIYSA HİZMET VERENİN AKIŞI BİTER ──
              //
              // Ürün kararı: iletişim açıldıktan sonra bu ekranda
              // HİÇBİR düğme kalmaz — ne "İletişimi Aç" ne "Teklifi
              // Geri Çek". Yerinde yalnız durum yazısı durur.
              //
              // Gerekçe: bedel tahsil edilmiştir ve iki taraf da
              // birbirine ulaşabilir. Geri çekme düğmesinin durması,
              // ücreti geri alınabilirmiş izlenimi veriyordu — oysa
              // tüketilmiş ücret İADE EDİLMEZ.
            ] else
              const SysEmpty(
                  title: 'Bu ilan teklif kabul etmiyor',
                  desc: 'İlan kapanmış ya da bir teklif seçilmiş olabilir.'),
          ]),
        ),
      ),
    );
  }
}



/// AD MASKELEME — HTML `PL_OWNERS` biçimi
///
/// "Emre Korkmaz" → "E*** K******"
/// Her kelimenin ilk harfi kalır, kalanı yıldızlanır.
String maskeliAd(String ad) {
  final p = ad.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
  if (p.isEmpty) {
    return 'K*** K******';
  }
  return p
      .map((k) => k.characters.first + '*' * (k.characters.length - 1))
      .join(' ');
}

// ── ⚠ BAŞLIK İKONU BU DOSYADAN KALKTI (12 Eyl) ──
//
// Buradaki `kategoriIkonu` iki kez düzeltilmiş, ikisinde de yanlış
// ikon çizmeye devam etmişti:
//
//   1. İlk gövde FOTOĞRAF haritasını (`kCategoryImage`) okuyup yalnız
//      `.svg` ile bitenleri kabul ediyordu. O haritadaki değerlerin
//      hepsi `.jpg`'dir; koşul hiç sağlanmadı ve her ilanda
//      `ic_grid.svg` çıktı.
//   2. Sonraki gövde `categoryIcon(baslik)` çağırıyordu. O harita
//      KATEGORİ ADIYLA anahtarlıdır; ona hizmet adı ("Doğalgaz Kaçak
//      Kontrolü") verilince yine eşleşme olmaz ve genel yedek ikon
//      çizilirdi. Yani arıza ad değiştirip sürdü.
//
// Doğru çözüm başlıktan KATEGORİYE geçmektir ve o çözücü artık tek
// yerde: `widgets/ilan_baslik_satiri.dart` içindeki `ilanIkonu`.
// Ekranlar ikon seçmez; `IlanBaslikSatiri` çağırır.

// ── ⚠ `gecenSure` KALDIRILDI (12 Eyl) ──
//
// "Az önce", "25 dk önce" gibi GÖRELİ süre üretiyordu. İki detay
// ekranındaki tarih satırları da, iş kartındaki yeni tarih de artık
// `kisaTarih` ile gerçek tarih gösteriyor; fonksiyonun tek çağıranı
// kalmamıştı.
//
// ⚠ ÖLÜ BIRAKILMADI: dosyada duran bir "göreli süre" yardımcısı,
// sonraki turda birinin tarih yerine yine onu çağırmasına davetiye
// çıkarırdı — bu depoda aynı şey `tl()` ile yaşandı ve kusur dört
// tur boyunca ekran ekran dolaştı.

/// `.pl-own` — ilan sahibi kartı.
/// `<a href="tel:...">` karşılığı — telefon uygulamasını açar.
///
/// ⚠ `offer_detail_screen` içinde aynı adlı bir yardımcı vardır; ikisi
/// de dosyaya ÖZELDİR (alt çizgiyle başlar) ve birbirini görmez.
/// Ortaklaştırmak yerine kopyalanmıştır: davranış üç satırdır ve
/// paylaşılan bir yardımcı için ayrı dosya açmak fazla gelirdi.
Future<void> _telefonAra(BuildContext context, String? ham) async {
  final d = Validators.phoneLocal(ham ?? '');
  if (d.isEmpty) {
    return;
  }
  final uri = Uri.parse('tel:$d');
  final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
  // ⚠ Sahte başarı YOK: arama uygulaması açılamazsa kullanıcı uyarılır.
  if (!acildi && context.mounted) {
    sysToastErr(context, SysKind.genericError,
        extra: 'Arama uygulaması açılamadı');
  }
}

