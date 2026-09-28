import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
// ⚠ `IsZamani` enum'u burada tanımlı — `_isZamani` alanı için gerekli
// (`create_listing_screen.dart`taki AYNI import notu).
import '../data/models/listing.dart';
import '../data/models/review.dart';
import '../data/models/teklif_talebi.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api/storage_api.dart';
import '../domain/config.dart';
import '../domain/form_mesajlari.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'provider_reviews_screen.dart';
import 'teklif_istediklerim_screen.dart';
import '../domain/saglayici_ozeti.dart';
import 'widgets/is_zamani_secici.dart';
import 'widgets/saglayici_ozet_satiri.dart';
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
    this.puan,
    this.yorumSayisi = 0,
    this.tamamlananIs = 0,
    this.ilce,
    this.il,
  });

  final String kategori;
  final String hizmet;
  final String saglayiciId;
  /// ⚠ HAM AD — ekranda daima MASKELİ gösterilir (maskeleme artık
  /// `SaglayiciOzetSatiri` içinde, tek yerde yapılır): teklif henüz
  /// verilmedi, hizmet veren burada hâlâ maskelidir.
  final String saglayiciAdi;

  // ── ⚠ YALNIZ KURGUSAL (MOCK) KAYITLAR İÇİN YEDEK DEĞERLER ──
  //
  // GERÇEK hesaplarda bu alanlar KULLANILMAZ: özet
  // `gercekSaglayiciOzeti` ile denetleyicilerden CANLI okunur, yani
  // yorum/iş/konum değişince bu ekran da değişir.
  //
  // Kurgusal hizmet verenin hesabı yoktur; geldiği listede görünen
  // değerler buradan taşınır ki iki kart AYNI şeyi göstersin.
  // ⚠ Sayı UYDURULMAZ: taşınmazsa 0 kalır, sahte veri üretilmez.
  final double? puan;
  final int yorumSayisi;
  final int tamamlananIs;
  final String? ilce;
  final String? il;

  @override
  State<TeklifIsteScreen> createState() => _TeklifIsteScreenState();
}

class _TeklifIsteScreenState extends State<TeklifIsteScreen> {
  final _aciklama = TextEditingController();
  final _aciklamaOdak = FocusNode();
  final List<PhotoItem> _photos = [];
  // ⚠ VARSAYILAN artık "Telefon + Uygulama İçi Mesaj" — kullanıcı
  // isteğiyle değişti (önceden "Sadece Mesaj" varsayılandı).
  IletisimTercihi _iletisim = IletisimTercihi.telefonGoster;

  /// ⚠ İSTEĞE BAĞLI: `null` = seçim yapılmadı, bu NORMAL bir
  /// durumdur ("İlan Ver" ekranındaki `_isZamani` ile AYNI kural).
  /// Seçim yapılmadan talep gönderilebilir.
  IsZamani? _isZamani;
  bool _gonderiliyor = false;

  /// ⚠ EKSİK/ANLAMSIZ AÇIKLAMA UYARISI ARTIK YAZARKEN DEĞİL, ALANDAN
  /// ÇIKINCA (ODAK KAYBINDA) GÖRÜNÜR — kullanıcı "M" gibi tek harf
  /// yazar yazmaz kırmızı çerçeve+uyarı görüyordu, henüz YAZMAYI
  /// BİTİRMEDEN. Standart form davranışı: kullanıcı alanı bir kez
  /// "ziyaret edip" TERK ETTİKTEN sonra geçerli kalır — bir daha
  /// odaklanıp DÜZELTİRSE uyarı zaten `_aciklamaEksik`/`_aciklamaAnlamsiz`
  /// `false` olduğu için kendiliğinden kalkar.
  bool _aciklamaDokunuldu = false;

  late final StorageApi _storageApi;

  @override
  void initState() {
    super.initState();
    _storageApi = StorageApi(context.read<ApiClient>());
    _aciklamaOdak.addListener(() {
      if (!_aciklamaOdak.hasFocus && !_aciklamaDokunuldu) {
        setState(() => _aciklamaDokunuldu = true);
      }
    });
  }

  @override
  void dispose() {
    _aciklama.dispose();
    _aciklamaOdak.dispose();
    super.dispose();
  }

  /// Açıklamadaki kelime sayısı.
  int _kelimeSayisi() => _aciklama.text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;

  // ⚠ ÖNCEDEN yalnız "boş değil" kontrol ediliyordu — tek kelimelik
  // ("tamir") ya da anlamsız ("asdasd") açıklamalar geçiyordu. Şimdi
  // en az `kMinAciklamaKelime` kelime ZORUNLU.
  bool get _zorunlularDolu =>
      _aciklama.text.trim().isNotEmpty &&
      _kelimeSayisi() >= kMinAciklamaKelime &&
      !_aciklamaAnlamsiz;

  /// ⚠ CANLI KONTROL — her tuş vuruşunda değerlendirilir
  /// (`onChanged: (_) => setState(() {})` zaten build'i tetikliyor).
  /// Boş alanda uyarı ÇIKMAZ. Yazı silinip düzeltilince (ör. "Bbbb"
  /// → "B") bu KENDİLİĞİNDEN `false`e döner — ayrı bir "düzeltildi"
  /// mantığı İCAT EDİLMEDİ.
  bool get _aciklamaAnlamsiz =>
      _aciklama.text.trim().isNotEmpty &&
      Validators.anlamsizKelimeVarMi(_aciklama.text);

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
          // ⚠ SEÇİM YOKSA `null` GİDER — "belirtilmedi" demektir,
          // varsayılan bir değere ÇEVRİLMEZ.
          isZamani: _isZamani,
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

          // ── SEÇİLİ HİZMET — SALT OKUNUR ──
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
              ],
            ),
          ),

          // ── ⚠ HİZMET VEREN KARTI — `sonuclar_screen.dart`daki
          // `_SaglayiciKarti` İLE AYNI GÖRSEL DİL, AYRI KART ──
          //
          // ÖNCEDEN "Seçili Hizmet" kartının İÇİNDE, sade bir satırdı.
          // Artık Sonuçlar ekranındaki TAM kart düzeni (avatar,
          // yıldız+yorum, tamamlanan iş, konum) — yalnız SIRA/MADALYA
          // ve "Teklif İste" BUTONU YOK (zaten bu ekranın kendisi o
          // butona tıklanınca açılıyor, tekrar sayılır).
          const SizedBox(height: 12),
          // ── ⚠ KART ORTAK BİLEŞENDEN (kullanıcı kuralı, 9 Eyl) ──
          //
          // "Sonuçlar" listesindeki kartla bu kartın bilgileri AYNI
          // olmalı ve BİRLİKTE değişmeli. Buradaki kopya çizim
          // silindi; iki ekran da `SaglayiciOzetSatiri`ni kullanıyor,
          // veri `gercekSaglayiciOzeti` ile tek yerden geliyor.
          //
          // ⚠ DÜZELTİLEN İKİ SAPMA:
          //   • PUAN — burada `—`, Sonuçlar'da `0.0` yazıyordu.
          //   • KONUM — burada HER ZAMAN `serviceDistricts.first`,
          //     Sonuçlar'da müşterinin ilçesi varsa O gösteriliyordu;
          //     aynı kişi iki ekranda farklı ilçede görünüyordu.
          //
          // ⚠ MOCK KAYIT: kurgusal hizmet verenin gerçek hesabı
          // yoktur; `gercekSaglayiciOzeti` `null` döner ve ad dışında
          // sayı UYDURULMAZ — geldiği listedeki değerler
          // `widget` üzerinden taşınır.
          Builder(builder: (context) {
            final ozet = gercekSaglayiciOzeti(context,
                    id: widget.saglayiciId) ??
                (
                  id: widget.saglayiciId,
                  adSoyad: widget.saglayiciAdi,
                  puan: widget.puan,
                  yorumSayisi: widget.yorumSayisi,
                  tamamlananIs: widget.tamamlananIs,
                  ilce: widget.ilce,
                  il: widget.il,
                  // ⚠ YEDEK KAYIT: hesap bulunamadı, fotoğraf da yok.
                  fotoYolu: '',
                );
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: const Color(0xFFECEEF2)),
                borderRadius: BorderRadius.circular(RR.r13),
              ),
              child: SaglayiciOzetSatiri(ozet),
            );
          }),

          // ── ⚠ YORUMLAR — AYRI KART, SON 3 YORUM ──
          //
          // ÖNCEDEN hizmet veren kartının İÇİNDE, 5 yorum
          // gösteriyordu. Artık KENDİ kartı, 3 yorum — kullanıcı
          // isteğiyle değişti.
          //
          // ⚠ ARTIK YORUM YOKKEN DE GÖRÜNÜR — önceden `yorumlar.
          // isEmpty` iken kart TAMAMEN gizleniyordu, hizmet verenin
          // hiç yorumu olmadığı durumda kullanıcı "Yorumlar" bölümünün
          // VAR OLDUĞUNU bile göremiyordu. Şimdi boşken "Henüz yorum
          // yok." yazıyor.
          Builder(builder: (context) {
            final reviews = context.watch<ReviewController>();
            final yorumlar = reviews.byProvider(widget.saglayiciId);
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: const Color(0xFFECEEF2)),
                borderRadius: BorderRadius.circular(RR.r13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yorumlar',
                      style: refText(
                          size: RF.s14, weight: RF.w700, color: RC.text)),
                  const SizedBox(height: 8),
                  if (yorumlar.isEmpty)
                    Text('Henüz yorum yok.',
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
                    if (yorumlar.length > 3)
                      RefTap(
                        onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => ProviderReviewsScreen(
                                    providerId: widget.saglayiciId,
                                    providerAdi:
                                        maskeliAd(widget.saglayiciAdi)))),
                        borderRadius: BorderRadius.circular(RR.r8),
                        child: Text('Tümünü Gör (${yorumlar.length})',
                            style: refText(
                                size: RF.s13,
                                weight: RF.w700,
                                color: RC.blue)),
                      ),
                  ],
                ],
              ),
            );
          }),

          // ── ⚠ HİZMET ZAMANI — "İLAN VER" EKRANIYLA BİREBİR AYNI ──
          //
          // Kullanıcı isteği (9 Eyl): "İlan Ver"deki Acil / Bu hafta /
          // Esnek zaman düğmeleri, AYNI ölçü, AYNI renk ve AYNI çalışma
          // mantığıyla bu ekranda da olsun.
          //
          // ⚠ KOPYA DÜĞME YAZILMADI: `IsZamaniSecici` bileşeninin
          // KENDİSİ kullanılıyor. Ölçü, renk, "Acil kırmızı", "seçiliye
          // tekrar dokununca seçim kalkar" ve "üç seçenek
          // `IsZamani.values`tan gelir" kurallarının hepsi bileşenin
          // içinde olduğu için otomatik olarak aynı.
          //
          // ⚠ ZORUNLU DEĞİL: doğrulama, yıldız, uyarı YOK — "İlan
          // Ver"deki kuralla aynı; seçim yapılmadan talep gönderilir.
          //
          // ⚠ KONUM: hizmet veren kartının (ve ona ait "Yorumlar"
          // kartının) ALTINA, "Açıklama"nın ÜSTÜNE kondu.
          Padding(
            padding: const EdgeInsets.fromLTRB(1, 20, 1, 3),
            child: Row(
              children: [
                Text('Hizmet Zamanı',
                    style: refText(
                        size: RF.s16, weight: RF.w700, color: RC.text)),
                const SizedBox(width: 6),
                Text('(Opsiyonel)',
                    style: refText(
                        size: RF.s125, weight: RF.w500, color: RC.textSoft)),
              ],
            ),
          ),
          Text('Zaman tercihiniz varsa belirtin.',
              style: refText(
                  size: RF.s13, weight: RF.w400, color: RC.textSoft)),
          const SizedBox(height: 10),
          IsZamaniSecici(
            secili: _isZamani,
            onDegisti: (z) => setState(() => _isZamani = z),
          ),

          const SizedBox(height: 20),
          Text('Açıklama',
              style: refText(size: RF.s16, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 6),
          Text('Ne istediğini hizmet verene anlat.',
              style:
                  refText(size: RF.s13, weight: RF.w400, color: RC.textSoft)),
          const SizedBox(height: 10),
          Stack(children: [
            TextField(
              controller: _aciklama,
              focusNode: _aciklamaOdak,
              onChanged: (_) => setState(() {}),
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              // ⚠ Flutter'ın KENDİ OTOMATİK karakter sayacı GİZLENDİ —
              // kendi PADDING'İYLE geliyordu ve altındaki uyarı
              // metniyle arasında GEREKSİZ büyük boşluk bırakıyordu.
              // `create_listing_screen.dart`daki ÖZEL sayaç deseni
              // (kutunun İÇİNDE, sağ altta) buraya da uygulandı.
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              // ⚠ ARTIK SABİT (const) DEĞİL — anlamsız metin tespit
              // edilince çerçeve kırmızıya döner. Ama yalnız kullanıcı
              // alandan ÇIKTIKTAN SONRA (`_aciklamaDokunuldu`) — YAZARKEN
              // DEĞİL, aksi hâlde tek harf yazar yazmaz kırmızı görünürdü.
              decoration: InputDecoration(
                hintText: 'Açıklama yazın.',
                alignLabelWithHint: true,
                enabledBorder: _aciklamaDokunuldu && _aciklamaAnlamsiz
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RR.r13),
                        borderSide: const BorderSide(color: RC.danger),
                      )
                    : null,
                focusedBorder: _aciklamaDokunuldu && _aciklamaAnlamsiz
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RR.r13),
                        borderSide:
                            const BorderSide(color: RC.danger, width: 1.6),
                      )
                    : null,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 12,
              child: Text('${_aciklama.text.characters.length}/1000',
                  style: refText(
                      size: RF.s125, weight: RF.w400, color: RC.textSoft)),
            ),
          ]),
          // ⚠ GÖRÜNÜR KURAL — `FormMesaj.teklifAciklama` YENİDEN
          // KULLANILDI: sayı `kMinAciklamaKelime`den gelir, iki yerde
          // ayrı sayı tutulmaz.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(FormMesaj.teklifAciklama,
                style: refText(
                    size: RF.s12,
                    weight: RF.w500,
                    color: !_aciklamaDokunuldu ||
                            _aciklama.text.trim().isEmpty ||
                            _kelimeSayisi() >= kMinAciklamaKelime
                        ? RC.textSoft
                        : const Color(0xFFE5452C))),
          ),
          // ── ⚠ ANLAMSIZ METİN UYARISI — ARTIK ALANDAN ÇIKINCA
          // GÖRÜNÜR, YAZARKEN DEĞİL ──
          //
          // ÖNCEDEN her tuş vuruşunda değerlendiriliyordu — kullanıcı
          // tek harf yazar yazmaz kırmızı çerçeve+uyarı görüyordu,
          // henüz YAZMAYI BİTİRMEDEN. Artık yalnız `_aciklamaDokunuldu`
          // (kullanıcı alana bir kez girip ÇIKTI) true olunca kontrol
          // ediliyor; yazı silinip düzeltilince ikisi de KENDİLİĞİNDEN
          // kalkar.
          if (_aciklamaDokunuldu && _aciklamaAnlamsiz)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Açıklamanız anlaşılır ifadeler içermelidir.',
                  style: refText(
                      size: RF.s12, weight: RF.w600, color: RC.danger)),
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
          // ── ⚠ TEK SATIR, TIKLANINCA AŞAĞI AÇILIR ──
          //
          // ÖNCEDEN iki kart alt alta duruyordu. Artık `RefAcilirSecici`
          // — "Bul" akışı ve normal "İlan Ver" akışı AYNI bileşeni
          // paylaşır (bkz. `create_listing_screen.dart`).
          RefAcilirSecici(
            ilkSeciliMi: _iletisim == IletisimTercihi.telefonGoster,
            ilkBaslik: 'Telefon + Uygulama İçi Mesaj',
            ilkAciklama: 'Hizmet veren telefonla da ulaşabilir.',
            ikinciBaslik: 'Sadece Uygulama İçi Mesaj',
            ikinciAciklama: 'Telefon numaran hizmet verene gösterilmez.',
            onSec: (ilkSecili) => setState(() => _iletisim = ilkSecili
                ? IletisimTercihi.telefonGoster
                : IletisimTercihi.yalnizMesaj),
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

/// ⚠ KOPYA KALDIRILDI (9 Eyl): tamamlanan iş sayımı artık
/// `domain/saglayici_ozeti.dart` içindeki `tamamlananIsSayisi` ile
/// TEK yerde tanımlıdır. Bu dosyada, `sonuclar_screen.dart`ta ve
/// `offer_detail_screen.dart`ta üç ayrı kopyası vardı; biri
/// değişince ötekiler sessizce ayrışıyordu.
