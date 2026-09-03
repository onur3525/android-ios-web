import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/offer_controller.dart';
import '../data/controllers/region_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/mock_saglayici_dizini.dart';
import '../domain/yakinlik_saglayici.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_iste_screen.dart';

/// "BUL" AKIŞI — 3. EKRAN: SONUÇLAR
///
/// `ScanningScreen` tarama bitince buraya `pushReplacement` ile
/// geçer (geri tuşu arayan/tarayan ekrana değil, hizmet seçim
/// ekranına döner — donmuş bir tarama ekranına dönmek anlamsız
/// olurdu).
///
/// ── ⚠ AŞAMA 3 KAPSAMI ──
///
/// Gerçek hizmet veren dizini/backend YOK — `MockSaglayici` (bkz.
/// `mock_saglayici_dizini.dart`) geliştirme amaçlı sabit veridir,
/// gerçek backend varmış gibi davranılmıyor.
///
/// "Teklif İste" düğmesi seçilen hizmet vereni `TeklifIsteScreen`e
/// TAŞIR — o form gönderim başarılı olunca "Teklif İstediklerim"e
/// yönlendirir (bkz. `teklif_iste_screen.dart`).
class SonuclarScreen extends StatefulWidget {
  const SonuclarScreen({
    super.key,
    required this.kategori,
    required this.hizmet,
    required this.ilce,
    required this.il,
  });

  final String kategori;
  final String hizmet;
  final String ilce;
  final String il;

  @override
  State<SonuclarScreen> createState() => _SonuclarScreenState();
}

class _SonuclarScreenState extends State<SonuclarScreen> {
  List<({MockSaglayici saglayici, int yakinlikSirasi})> _sonuclar = const [];

  /// İlk gösterilen kayıt sayısı — "Tümünü Gör" ile açılır.
  static const _ilkGoster = 5;
  bool _tumu = false;

  @override
  void initState() {
    super.initState();
    // ⚠ AYNI YAKINLIK SOYUTLAMASI (Aşama 2 ile) — yeni bir bölge
    // kaynağı ÜRETİLMEDİ, `RegionController.districtsOf` yeniden
    // kullanıldı.
    final rc = context.read<RegionController>();
    // ⚠ GERÇEK KOORDİNAT TABANLI SIRALAMA — `IlBazliYakinlikSaglayici`
    // artık yalnız koordinatı olmayan iller için sessiz geri düşüş
    // (bkz. `KoordinatTabanliYakinlikSaglayici` içindeki kural).
    final yakinlik =
        KoordinatTabanliYakinlikSaglayici((il) => rc.districtsOf(il));
    _sonuclar = mockSaglayicilariBul(
      il: widget.il,
      ilce: widget.ilce,
      yakinlik: yakinlik,
      gercekSaglayicilar: _gercekSaglayicilariBul(
        context,
        kategori: widget.kategori,
        hizmet: widget.hizmet,
        musteriIlcesi: widget.ilce,
      ),
    );
  }

  /// "Teklif İste" formuna geçer — hizmet ve hizmet veren bilgisi
  /// otomatik taşınır.
  void _teklifIste(MockSaglayici s) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TeklifIsteScreen(
          kategori: widget.kategori,
          hizmet: widget.hizmet,
          saglayiciId: s.id,
          saglayiciAdi: s.adSoyad,
        ),
      ),
    );
  }

  void _cikisYap() {
    // ⚠ "Bul" akışının TAMAMINDAN çıkar (Sonuçlar → Tarama → Hizmet
    // Seç hepsi kapanır) — mevcut alt bar tuşlarıyla AYNI hedefe
    // (`/customer/listings`) gider.
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/customer/listings', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final gosterilen =
        _tumu ? _sonuclar : _sonuclar.take(_ilkGoster).toList();
    final kalan = _sonuclar.length - gosterilen.length;

    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── ÜST BAR: SOL GERİ · ORTA BAŞLIK · SAĞ X ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  const RefBackButton(),
                  Expanded(
                    child: Text('Sonuçlar',
                        textAlign: TextAlign.center,
                        style: refText(
                            size: RF.s16, weight: RF.w700, color: RC.text)),
                  ),
                  RefTap(
                    onTap: _cikisYap,
                    borderRadius: BorderRadius.circular(RR.circle),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: RefSvg('assets/svg/ic_close.svg', size: 20),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                children: [
                  // ── SONUÇ BİLGİ KARTI — DİNAMİK SAYI ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: RC.blueSoft,
                      borderRadius: BorderRadius.circular(RR.r12),
                    ),
                    child: Text(
                      '${widget.hizmet} için ${_sonuclar.length} hizmet '
                      'veren bulundu',
                      style: refText(
                          size: RF.s14, weight: RF.w600, color: RC.text),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── TEK KESİNTİSİZ LİSTE — İLÇE BAŞLIĞI YOK ──
                  for (var i = 0; i < gosterilen.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _SaglayiciKarti(
                      sira: i + 1,
                      saglayici: gosterilen[i].saglayici,
                      il: widget.il,
                      onTeklifIste: () =>
                          _teklifIste(gosterilen[i].saglayici),
                    ),
                  ],

                  if (kalan > 0) ...[
                    const SizedBox(height: 14),
                    RefTap(
                      onTap: () => setState(() => _tumu = true),
                      borderRadius: BorderRadius.circular(RR.r13),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFECEEF2)),
                          borderRadius: BorderRadius.circular(RR.r13),
                        ),
                        alignment: Alignment.center,
                        child: Text('Tümünü Gör (${_sonuclar.length})',
                            style: refText(
                                size: RF.s14,
                                weight: RF.w700,
                                color: RC.blue)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaglayiciKarti extends StatelessWidget {
  const _SaglayiciKarti({
    required this.sira,
    required this.saglayici,
    required this.il,
    required this.onTeklifIste,
  });

  final int sira;
  final MockSaglayici saglayici;
  final String il;
  final VoidCallback onTeklifIste;

  @override
  Widget build(BuildContext context) {
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
          // ── SIRA — İLK 3'TE MADALYA, SONRASI DÜZ SAYI ──
          //
          // ⚠ Projede madalya asset'i YOK; yeni bir SVG dosyası
          // ÜRETİLMEDİ — Flutter'ın kendi Material ikon setinden
          // (`Icons.workspace_premium`, gerçek madalya biçimi)
          // kullanıldı; bu proje genelinde zaten `Icons.check` gibi
          // küçük yerleşik ikonlar için yapılan aynı istisna.
          SizedBox(
            width: 22,
            child: switch (sira) {
              1 => const Icon(Icons.workspace_premium,
                  size: 22, color: Color(0xFFD4AF37)), // altın
              2 => const Icon(Icons.workspace_premium,
                  size: 22, color: Color(0xFFA8A9AD)), // gümüş
              3 => const Icon(Icons.workspace_premium,
                  size: 22, color: Color(0xFFCD7F32)), // bronz
              _ => Text('$sira',
                  style: refText(
                      size: RF.s13, weight: RF.w700, color: RC.textSoft)),
            },
          ),
          const SizedBox(width: 8),

          // ── FOTOĞRAF — TAMAMEN BUZLU ──
          //
          // ⚠ Yeni bir blur efekti/asset ÜRETİLMEDİ: `ic_avlock.svg`
          // projede zaten "kimliği gizli" avatarı temsil eden hazır
          // görsel (bkz. `job_detail_screen.dart` içindeki
          // `_SahipKarti`).
          const RefSvg('assets/svg/ic_avlock.svg', size: 46),
          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AD SOYAD — MASKELİ ──
                //
                // ⚠ `maskeliAd` YENİDEN KULLANILDI (job_detail_screen
                // içinde tanımlı, "E*** K******" biçimi) — yeni bir
                // maskeleme kuralı İCAT EDİLMEDİ.
                Text(maskeliAd(saglayici.adSoyad),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s145, weight: RF.w700, color: RC.text)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const RefSvg('assets/svg/ic_starfill.svg', size: 14),
                    const SizedBox(width: 4),
                    Text(saglayici.puan.toStringAsFixed(1),
                        style: refText(
                            size: RF.s125,
                            weight: RF.w700,
                            color: RC.text)),
                    const SizedBox(width: 4),
                    Text('(${saglayici.yorumSayisi} yorum)',
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
                    Text('${saglayici.tamamlananIs} iş tamamladı',
                        style: refText(
                            size: RF.s12,
                            weight: RF.w400,
                            color: const Color(0xFF5B6472))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const RefSvg('assets/svg/ic_pin.svg',
                        size: 14, color: Color(0xFF98A2B3)),
                    const SizedBox(width: 5),
                    Text('${saglayici.ilce} / $il',
                        style: refText(
                            size: RF.s12,
                            weight: RF.w400,
                            color: const Color(0xFF98A2B3))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          _TeklifIsteButonu(onTap: onTeklifIste),
        ],
      ),
    );
  }
}

/// ── ⚠ KÜÇÜK YEŞİL BUTON — AŞAMA 1'DEKİ "ARA" İLE AYNI TASARIM ──
///
/// Ayrı bir buton dili İCAT EDİLMEDİ: dolgu (`HC.green`), köşe
/// yarıçapı ve tipografi Aşama 1'de kurulan yeşil düğmeyle aynı;
/// yalnız kart içine sığacak ÖLÇÜDE küçültüldü.
class _TeklifIsteButonu extends StatelessWidget {
  const _TeklifIsteButonu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RR.r13),
      child: Material(
        color: HC.green,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text('Teklif\nİste',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RC.white,
                    height: 1.2)),
          ),
        ),
      ),
    );
  }
}

/// ── ⚠ "BUL" AKIŞI — GERÇEK KAYITLI HİZMET VERENLERİ BULUR ──
///
/// `AuthController.saglayicilarKimSunuyor` — kendi `categories`
/// kümesinde bu hizmeti/kategoriyi SEÇMİŞ, gerçek hesaplardır (bkz.
/// `MyCategoriesScreen`). Bulunursa mock havuza EKLENİR, bulunamazsa
/// liste yalnız mock kalır — sahte "gerçek" veri ÜRETİLMEZ.
List<MockSaglayici> _gercekSaglayicilariBul(
  BuildContext context, {
  required String kategori,
  required String hizmet,
  required String musteriIlcesi,
}) {
  final auth = context.read<AuthController>();
  final me = auth.currentAccount;
  if (me == null) {
    return const [];
  }

  final hesaplar = auth.saglayicilarKimSunuyor(kategori, hizmet,
      haricTutulacakId: me.id);
  if (hesaplar.isEmpty) {
    return const [];
  }

  final reviews = context.read<ReviewController>();

  return [
    for (final acc in hesaplar)
      MockSaglayici(
        gercek: true,
        id: acc.id,
        adSoyad: acc.name,
        // ⚠ Hizmet verenin KENDİ seçtiği bölgelerden (bkz.
        // `MyAreasScreen`/`serviceDistricts`) müşterinin ilçesiyle
        // eşleşen varsa O kullanılır — gerçekten "buraya hizmet
        // veriyor" anlamına gelir. Yoksa ilk bölgesi gösterilir.
        ilce: acc.serviceDistricts.contains(musteriIlcesi)
            ? musteriIlcesi
            : (acc.serviceDistricts.isNotEmpty
                ? acc.serviceDistricts.first
                : musteriIlcesi),
        puan: reviews.averageOf(acc.id) ?? 0,
        yorumSayisi: reviews.byProvider(acc.id).length,
        tamamlananIs: _tamamlananIsGercek(context, acc.id),
        aktiflikSkoru:
            _aktiflikTahmini(context, acc.id, reviews.byProvider(acc.id).length),
      ),
  ];
}

/// ⚠ `offer_detail_screen.dart`'taki `_tamamlananIs` ile AYNI
/// mantık — o fonksiyon dosyaya ÖZEL (private) olduğu için buraya
/// yeniden yazıldı, davranışı BİREBİR aynı.
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

/// ⚠ GERÇEK HESAPLAR İÇİN "AKTİFLİK" TAHMİNİ — dürüst bir vekil
/// (proxy) değerdir, uydurma DEĞİL: tamamlanan iş ve yorum sayısı
/// arttıkça platformu gerçekten kullandığını gösterir. Gerçek backend
/// bunu yanıt süresi/son giriş gibi asıl sinyallerden hesaplayacak;
/// bu, o gelene kadarki en dürüst yaklaşıklıktır.
double _aktiflikTahmini(
    BuildContext c, String providerId, int yorumSayisi) {
  final tamamlanan = _tamamlananIsGercek(c, providerId);
  final skor = tamamlanan * 0.05 + yorumSayisi * 0.03;
  return skor > 1 ? 1 : skor;
}
