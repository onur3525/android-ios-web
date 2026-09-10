import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/region_controller.dart';
import '../data/controllers/review_controller.dart';
import '../data/mock_saglayici_dizini.dart';
import '../domain/saglayici_ozeti.dart';
import '../domain/yakinlik_saglayici.dart';
import 'widgets/saglayici_ozet_satiri.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
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

  /// ⚠ KESİN ÜST SINIR — 9. hizmet veren ASLA listelenmez. Bölgede
  /// 1 varsa yalnız 1 gösterilir (yukarı doğru ZORLAMA yok, yalnız
  /// aşağı doğru KIRPMA). Bu artık MUTLAK bir sınır olduğu için
  /// "Tümünü Gör" ile daha fazlasını açma seçeneği KALDIRILDI —
  /// zaten gösterilecek daha fazlası yok.
  static const _maksimumGoster = 8;

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
    final tumSonuclar = mockSaglayicilariBul(
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
    // ⚠ SIRALAMA ZATEN `mockSaglayicilariBul` İÇİNDE YAPILDI — burada
    // yalnız KIRPILIYOR. En iyi kriterlere göre sıralı listenin İLK
    // 8'i alınır; 8'den azsa (ör. bölgede tek 1 hizmet veren varsa)
    // olduğu gibi kalır, UYDURMA/ÇOĞALTMA YAPILMAZ.
    _sonuclar = tumSonuclar.take(_maksimumGoster).toList();
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
          // ⚠ KARTTA NE GÖRÜNDÜYSE O TAŞINIR (kullanıcı kuralı,
          // 9 Eyl): kurgusal kayıtlarda hesap olmadığı için öteki
          // ekran bu değerleri başka yerden bulamaz. Gerçek
          // hesaplarda bunlar yok sayılır, canlı okunur.
          puan: s.yorumSayisi == 0 ? null : s.puan,
          yorumSayisi: s.yorumSayisi,
          tamamlananIs: s.tamamlananIs,
          ilce: s.ilce,
          il: widget.il,
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
                    // ── ⚠ BAŞLIK (kullanıcı isteği, 9 Eyl) ──
                    //
                    // "Sonuçlar" → "En Uygun Hizmet Verenler", daha
                    // kalın bir başlık görünümü istendi.
                    //
                    // ⚠ KALINLIK DEĞİL ÖLÇÜ ARTIRILDI: yazı zaten
                    // `w700` idi ve pubspec'te Poppins'in YALNIZ
                    // 400/500/700 ağırlıkları var — `w800` istenseydi
                    // sentezlenip bulanık basardı. Bu yüzden başlık
                    // hissi 16 → 18 punto ile verildi.
                    //
                    // ⚠ TEK SATIR: geri düğmesi ile X arasındaki
                    // genişliğe sığar; sığmazsa kırpılır, satır
                    // ATLAMAZ — üst bar yüksekliği sabit kalmalı.
                    child: Text('En Uygun Hizmet Verenler',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: refText(
                            size: RF.s18, weight: RF.w700, color: RC.text)),
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
                  // ── BAŞLIK — SAYI VE AD YOK, SABİT METİN ──
                  //
                  // ⚠ ÖNCEDEN "{N} hizmet veren bulundu." yazıyordu —
                  // sayı gösteriyordu. Artık liste zaten en fazla 8
                  // sonuçla SINIRLI (aşağıdaki not), bu yüzden bir
                  // sayı vermenin de anlamı kalmadı; sabit, nötr bir
                  // başlık kullanılıyor.
                  // ⚠ BAŞLIK DURUMA GÖRE (9 Eyl): kurgusal havuz
                  // kaldırıldığı için liste artık gerçekten BOŞ
                  // olabilir. Boşken "listelendi" demek yanlış olurdu.
                  // ── ⚠ ALT SATIR (kullanıcı isteği, 9 Eyl) ──
                  //
                  // Metin "İhtiyacınıza uygun hizmet verenler
                  // listelendi" oldu, ORTALANDI ve başlıktan bir tık
                  // silik kalması istendi.
                  //
                  // ⚠ SİLİKLİK RENKLE VERİLDİ: siyah (#000000) →
                  // `RC.textSoft`. Ağırlık da w600 → w500; w600
                  // pubspec'te YOK, sentezleniyordu (bkz. ilan
                  // açıklaması tipografisi kuralı).
                  //
                  // ⚠ Başlığın kendisi 18/w700 olduğu için aradaki
                  // fark hem ölçü hem renkle kuruluyor.
                  Text(
                      _sonuclar.isEmpty
                          ? 'Bu hizmet için sonuç bulunamadı'
                          : 'İhtiyacınıza uygun hizmet verenler listelendi',
                      textAlign: TextAlign.center,
                      style: refText(
                          size: RF.s135,
                          weight: RF.w500,
                          color: RC.textSoft)),
                  const SizedBox(height: 14),

                  // ── ⚠ BOŞ DURUM ──
                  //
                  // ÖNCEDEN bu ekran HİÇ boş kalmazdı: eşleşen gerçek
                  // hesap yoksa kurgusal havuz listeyi doldururdu.
                  // Kullanıcı kararıyla o havuz silindi, dolayısıyla
                  // boş durumun kendisi artık gerçek bir hâl.
                  //
                  // ⚠ SAYI YA DA TAHMİN YAZILMAZ: "yakında eklenecek",
                  // "N kişi bekleniyor" gibi bilmediğimiz şeyler
                  // söylenmez. Yalnız durum ve tek bir öneri.
                  if (_sonuclar.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                          'Seçtiğiniz hizmeti bu bölgede sunan kayıtlı '
                          'hizmet veren bulunmuyor. İlan vererek '
                          'teklif toplayabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: refText(
                              size: RF.s135,
                              weight: RF.w400,
                              color: RC.textSoft)),
                    ),

                  // ── TEK KESİNTİSİZ LİSTE — İLÇE BAŞLIĞI YOK ──
                  //
                  // ⚠ EN FAZLA 8 — `_sonuclar` zaten `initState`te
                  // kırpıldı (bkz. `_maksimumGoster`); burada TÜMÜ
                  // gösterilir, "Tümünü Gör" KALDIRILDI çünkü artık
                  // gösterilecek DAHA FAZLASI yok.
                  for (var i = 0; i < _sonuclar.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _SaglayiciKarti(
                      sira: i + 1,
                      saglayici: _sonuclar[i].saglayici,
                      il: widget.il,
                      onTeklifIste: () =>
                          _teklifIste(_sonuclar[i].saglayici),
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
          // ⚠ ÖNCEDEN `Icons.workspace_premium` (tek renkli Material
          // ikonu, altın/gümüş/bronz rengiyle boyalı) kullanılıyordu
          // — kullanıcı bunun "canlı" durmadığını belirtti. Şimdi
          // gerçek emoji madalyalar (🥇🥈🥉) — cihazın kendi renkli
          // emoji fontundan geliyor, yeni bir asset/paket YOK.
          SizedBox(
            width: 22,
            child: switch (sira) {
              1 => const Text('🥇', style: TextStyle(fontSize: 20)),
              2 => const Text('🥈', style: TextStyle(fontSize: 20)),
              3 => const Text('🥉', style: TextStyle(fontSize: 20)),
              _ => Text('$sira',
                  style: refText(
                      size: RF.s13, weight: RF.w700, color: RC.textSoft)),
            },
          ),
          const SizedBox(width: 8),

          // ── ⚠ BİLGİ SATIRI ORTAK BİLEŞENDEN ──
          //
          // KULLANICI KURALI (9 Eyl): bu karttaki bilgilerle "Teklif
          // İste" ekranındaki kartın bilgileri AYNI olmalı ve BİRLİKTE
          // değişmeli. Kopya çizim silindi; iki ekran da
          // `SaglayiciOzetSatiri`ni kullanıyor.
          //
          // ⚠ GERÇEK HESAP CANLI OKUNUR: `gercek == true` ise özet
          // denetleyicilerden ÜRETİLİR (puan, yorum, tamamlanan iş,
          // konum). Listeyi kuran anlık görüntü kullanılmaz — yorum
          // ya da iş sayısı bu ekran açıkken değişirse kart da
          // değişir.
          //
          // ⚠ MOCK KAYIT DİZİNDEN OKUNUR: kurgusal hizmet verenin
          // gerçek hesabı yoktur; değerleri `mock_saglayici_dizini`
          // sabitlerinden gelir. Denetleyicilerden okunsaydı hepsi
          // 0 çıkardı — "Teklif İste" ekranının eski hatası buydu.
          Expanded(
            child: SaglayiciOzetSatiri(
              (saglayici.gercek
                      ? gercekSaglayiciOzeti(context,
                          id: saglayici.id, ilYedegi: il)
                      : null) ??
                  (
                    id: saglayici.id,
                    adSoyad: saglayici.adSoyad,
                    puan: saglayici.yorumSayisi == 0 ? null : saglayici.puan,
                    yorumSayisi: saglayici.yorumSayisi,
                    tamamlananIs: saglayici.tamamlananIs,
                    ilce: saglayici.ilce,
                    il: il,
                  ),
            ),
          ),

          const SizedBox(width: 8),
          _TeklifIsteButonu(onTap: onTeklifIste),
        ],
      ),
    );
  }
}

/// ── ⚠ KÜÇÜK BUTON — RENK MAVİ (kullanıcı kararı, 9 Eyl) ──
///
/// ÖNCEDEN `HC.green` idi (Aşama 1'deki "Ara" düğmesiyle aynı dil).
/// Kullanıcı bu ekrandaki düğmelerin MAVİ olmasını istedi; dolgu
/// `RC.blue` oldu. Ölçü, köşe yarıçapı, ikon ve tipografi
/// DEĞİŞMEDİ — yalnız dolgu rengi.
///
/// ⚠ YENİ RENK ÜRETİLMEDİ: `RC.blue` uygulamanın birincil düğme
/// rengidir (`RefPrimaryButton` de onu kullanır).
///
/// İkon
/// (`ic_send.svg`) da yeni değil — `teklif_iste_screen.dart`'taki
/// asıl "Teklif İste" gönder düğmesiyle AYNI ikon; tutarlılık için
/// tekrar kullanıldı, yeni bir görsel dil eklenmedi.
///
/// ⚠ ÖNCEDEN metin `'Teklif\nİste'` ile iki satıra ZORLANIYORDU —
/// dar ve sıkışık görünüyordu. Şimdi tek satır + ikon; kart genişliği
/// hâlâ `Expanded` bilgi sütunundan alınır, taşma OLUŞMAZ.
class _TeklifIsteButonu extends StatelessWidget {
  const _TeklifIsteButonu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RR.r13),
      child: Material(
        color: RC.blue,
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RefSvg('assets/svg/ic_send.svg', size: 14, color: RC.white),
                SizedBox(width: 6),
                Text('Teklif İste',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RC.white,
                        height: 1.0)),
              ],
            ),
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
/// `MyCategoriesScreen`).
///
/// ⚠ ARTIK LİSTENİN TAMAMI BUDUR (9 Eyl): kurgusal havuz silindi.
/// Eşleşen kayıtlı hesap yoksa liste BOŞ döner ve ekran boş durumunu
/// gösterir — sahte doluluk üretilmez.
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
        // ── ⚠ BU ALAN YALNIZ SIRALAMA İÇİNDİR, EKRANDA GÖSTERİLMEZ ──
        //
        // Kartta görünen konum `gercekSaglayiciOzeti` tarafından
        // hesabın KENDİ ADRESİNDEN okunur (kullanıcı bulgusu, 9 Eyl:
        // "adres bilgilerim farklı görünüyor").
        //
        // Buradaki ilçe ise "bu hizmet vereni bana göster" kararını
        // ve yakınlık sırasını belirler; onun için hizmet VERDİĞİ
        // bölge doğru ölçüttür. İki soru ayrıdır: nereye hizmet
        // veriyor (eşleştirme) ve nerede oturuyor (gösterim).
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

/// ⚠ KOPYA KALDIRILDI: sayım artık `domain/saglayici_ozeti.dart`
/// içindeki `tamamlananIsSayisi` ile TEK yerde tanımlı. Burada üç
/// ayrı kopya vardı ve biri değişince ötekiler sessizce ayrışıyordu.
int _tamamlananIsGercek(BuildContext c, String providerId) =>
    tamamlananIsSayisi(c, providerId);

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
