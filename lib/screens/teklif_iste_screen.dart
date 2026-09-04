import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
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
  // ⚠ VARSAYILAN artık "Telefon + Uygulama İçi Mesaj" — kullanıcı
  // isteğiyle değişti (önceden "Sadece Mesaj" varsayılandı).
  IletisimTercihi _iletisim = IletisimTercihi.telefonGoster;
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
          Builder(builder: (context) {
            final reviews = context.watch<ReviewController>();
            final puan = reviews.averageOf(widget.saglayiciId);
            final yorumlar = reviews.byProvider(widget.saglayiciId);
            final tamamlanan =
                _tamamlananIsGercek(context, widget.saglayiciId);
            final hesap =
                context.read<AuthController>().accountById(widget.saglayiciId);
            final konum = hesap?.address == null
                ? null
                : '${hesap!.address!.district} / ${hesap.address!.city}';
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RC.white,
                border: Border.all(color: const Color(0xFFECEEF2)),
                borderRadius: BorderRadius.circular(RR.r13),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const RefSvg('assets/svg/ic_avlock.svg', size: 46),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(maskeliAd(widget.saglayiciAdi),
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
                            Text(
                                puan == null
                                    ? '—'
                                    : puan.toStringAsFixed(1),
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
                            const RefSvg('assets/svg/ic_shieldok.svg',
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
              ),
            );
          }),

          // ── ⚠ YORUMLAR — AYRI KART, SON 3 YORUM ──
          //
          // ÖNCEDEN hizmet veren kartının İÇİNDE, 5 yorum
          // gösteriyordu. Artık KENDİ kartı, 3 yorum — kullanıcı
          // isteğiyle değişti.
          Builder(builder: (context) {
            final reviews = context.watch<ReviewController>();
            final yorumlar = reviews.byProvider(widget.saglayiciId);
            if (yorumlar.isEmpty) {
              return const SizedBox.shrink();
            }
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
              ),
            );
          }),

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
            // ⚠ ARTIK SABİT (const) DEĞİL — anlamsız metin
            // tespit edilince çerçeve CANLI olarak kırmızıya döner.
            decoration: InputDecoration(
              hintText: 'Açıklama yazın.',
              alignLabelWithHint: true,
              enabledBorder: _aciklamaAnlamsiz
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RR.r13),
                      borderSide: const BorderSide(color: RC.danger),
                    )
                  : null,
              focusedBorder: _aciklamaAnlamsiz
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RR.r13),
                      borderSide: const BorderSide(color: RC.danger, width: 1.6),
                    )
                  : null,
            ),
          ),
          // ⚠ GÖRÜNÜR KURAL — `FormMesaj.teklifAciklama` YENİDEN
          // KULLANILDI: sayı `kMinAciklamaKelime`den gelir, iki yerde
          // ayrı sayı tutulmaz.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(FormMesaj.teklifAciklama,
                style: refText(
                    size: RF.s12,
                    weight: RF.w500,
                    color: _aciklama.text.trim().isEmpty ||
                            _kelimeSayisi() >= kMinAciklamaKelime
                        ? RC.textSoft
                        : const Color(0xFFE5452C))),
          ),
          // ── ⚠ CANLI ANLAMSIZ METİN UYARISI — YAZARKEN GÖRÜNÜR ──
          //
          // ÖNCEDEN yalnız GÖNDERİM ANINDA (toast ile) kontrol
          // ediliyordu. "Bbbb" gibi ardışık anlamsız harfler
          // yazılır yazılmaz çerçeve kırmızıya döner VE bu satır
          // belirir; yazı silinip düzeltilince (ör. yalnız "B"
          // kalınca) ikisi de KENDİLİĞİNDEN kalkar.
          if (_aciklamaAnlamsiz)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Anlamsız kelimeler içeriyor gibi görünüyor.',
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

/// ⚠ `offer_detail_screen.dart`'taki `_tamamlananIs` (ve
/// `sonuclar_screen.dart`daki `_tamamlananIsGercek`) İLE AYNI mantık
/// — hizmet verenin SEÇİLMİŞ teklifle tamamlanmış iş sayısı. Üçüncü
/// bir kopya değil, aynı hesaplama farklı dosyalarda AYNI şekilde
/// tekrarlanıyor çünkü bu üçü birbirinden PRIVATE (import edilemez).
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
