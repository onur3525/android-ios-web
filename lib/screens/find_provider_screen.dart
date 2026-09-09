import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/services/search_service.dart';
import '../domain/cikar_catismasi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'scanning_screen.dart';

/// "BUL" AKIŞI — 1. EKRAN: HİZMET VEREN BUL
///
/// Müşterinin belirli bir HİZMETİ arayıp o hizmeti veren hizmet
/// verenleri bulmak için girdiği başlangıç ekranı.
///
/// ⚠ BU EKRAN GENEL "USTA ARAMA" DEĞİLDİR: kullanıcı bir HİZMET seçer
/// ("Doğalgaz kaçağı tespiti"), meslek adı değil. Seçim mevcut
/// kataloğun DIŞINA çıkamaz — bkz. `_HizmetAramaAlani` altında.
///
/// ── ⚠ AŞAMA 1 KAPSAMI ──
///
/// Bu ekran; hizmet seçimi, profil adresinin okunması ve "Ara"
/// düğmesinin aktiflik kuralını kapsar. Düğmeye basınca açılacak
/// "Hizmet Verenler Taranıyor" ekranı henüz YOK — 2. aşamada
/// gelecek. Bu yüzden `_ara()` şimdilik yalnız seçili durumu taşır;
/// gerçek yönlendirme bir sonraki aşamada eklenecek.
class FindProviderScreen extends StatefulWidget {
  const FindProviderScreen({super.key});

  @override
  State<FindProviderScreen> createState() => _FindProviderScreenState();
}

class _FindProviderScreenState extends State<FindProviderScreen> {
  /// Seçilen hizmet — HER İKİSİ DE dolu olmadan arama yapılamaz.
  String? _kategori;
  String? _hizmet;

  @override
  void initState() {
    super.initState();
    // ⚠ YENİ — kullanıcı isteği: "Bul" ikonundaki gösterge, ekran
    // açılınca silinir (alt bardaki `_talepleriGorulduIsaretleHizmetAlan`
    // ile AYNI ilke — hizmet verenin "Teklif İstekleri" sekmesindeki
    // rozetle simetrik).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthController>().currentAccount;
      if (me == null || !mounted) {
        return;
      }
      context
          .read<TeklifTalebiController>()
          .teklifleriGorulduIsaretleHizmetAlan(me.id);
    });
  }

  // ⚠ Kural TEK KAYNAKTAN gelir: `lib/domain/cikar_catismasi.dart`
  // — `create_listing_screen.dart`daki `_kategoriSec` İLE AYNI
  // desen, yeni bir kural İCAT EDİLMEDİ. Hizmet veren kendi hizmet
  // verdiği kategoride "Bul" ile ARAMA YAPAMAZ (rakiplerinden fiyat
  // toplayamasın diye — İlan Ver akışıyla AYNI gerekçe). Kontrol
  // `me.categories`i CANLI okur: rol sonradan eklenmiş olsa bile
  // aynı anda devreye girer.
  void _hizmetSecildi(String kategori, String hizmet) {
    final me = context.read<AuthController>().currentAccount;
    final catisan = me == null
        ? null
        : catisanKategori(
            saglayiciSecimleri: me.categories, ilanBasligi: hizmet);
    if (catisan != null) {
      sysToastErr(context, SysKind.genericError,
          extra: catismaMesaji(catisan));
      return;
    }
    setState(() {
      _kategori = kategori;
      _hizmet = hizmet;
    });
  }

  void _secimSifirla() {
    setState(() {
      _kategori = null;
      _hizmet = null;
    });
  }

  void _ara() {
    final adres = context.read<AuthController>().currentAccount?.address;
    // ⚠ ÖNCEDEN: adres yoksa SESSİZCE hiçbir şey olmuyordu. Şimdi
    // kullanıcı NEDEN ilerleyemediğini görüyor VE adres ekleme
    // sayfasına yönlendiriliyor — sessiz uç NOKTASI kalmadı.
    if (adres == null) {
      sysToastKural(context,
          'Arama yapabilmek için önce profilinize bir adres eklemelisiniz.');
      Navigator.pushNamed(context, '/profile/address');
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ScanningScreen(
          kategori: _kategori!,
          hizmet: _hizmet!,
          ilce: adres.district,
          il: adres.city,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adres = context.watch<AuthController>().currentAccount?.address;

    return RefPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ÜST SATIR: SOLDA GERİ, SAĞDA X (AKIŞTAN ÇIK) ──
          //
          // ⚠ Referans tasarımdaki gibi HER İKİ buton da beyaz,
          // hafif gölgeli bir daire içine alındı — `RefBackButton`
          // ve `ic_close.svg` DAVRANIŞI (hedefleri, dokunma alanları)
          // HİÇ DEĞİŞMEDİ, yalnız görsel çerçeve eklendi.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DaireCerceve(child: RefBackButton()),
              _DaireCerceve(
                child: RefTap(
                  onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/customer/listings', (r) => false),
                  borderRadius: BorderRadius.circular(RR.circle),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: RefSvg('assets/svg/bul_ic_close.svg', size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── BAŞLIK + İLLÜSTRASYON — REFERANS TASARIMDAKİ YAN YANA
          // DÜZEN ──
          //
          // ⚠ Kullanıcının sağladığı gerçek illüstrasyon asset'i
          // kullanılıyor (`assets/art/bul_character.png`) — önceki
          // turda PNG asset olmadığı için bu bölüm yalnız metinden
          // oluşuyordu.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: refText(
                        size: 27,
                        weight: RF.w800,
                        color: RC.text,
                        height: 1.1),
                    children: [
                      const TextSpan(text: 'Hizmet\n'),
                      TextSpan(
                          text: 'Veren Bul',
                          style: TextStyle(color: HC.green)),
                    ],
                  ),
                ),
              ),
              Image.asset('assets/art/bul_character.png',
                  width: 132, fit: BoxFit.contain),
            ],
          ),
          const SizedBox(height: 4),
          RefSubtitle('Aradığın hizmeti yaz, en uygun hizmet verenleri '
              'bulalım.'),
          const SizedBox(height: 18),

          _HizmetAramaAlani(
            seciliHizmet: _hizmet,
            onSecim: _hizmetSecildi,
            onTemizle: _secimSifirla,
          ),

          // ── KONUM BİLGİSİ — YALNIZ BİLGİLENDİRME ──
          //
          // ⚠ Kullanıcı burada adres SEÇMEZ. Profildeki kayıtlı
          // adres (`Account.address`) otomatik kullanılır; ekran
          // yalnız hangi konumun baz alınacağını gösterir.
          //
          // ⚠ TASARIM YENİLENDİ (referans görsel + gerçek asset'ler)
          // — arka planda `bul_location_bg.svg` gradyanı, sağda
          // GERÇEK şehir illüstrasyonu (`bul_location.png`). Buton
          // veya ok EKLENMEDİ — kart hâlâ salt bilgilendirme, `RefTap`
          // ile SARILMADI, tıklanamaz kalmaya devam ediyor.
          ClipRRect(
            borderRadius: BorderRadius.circular(RR.r16),
            child: SizedBox(
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ⚠ `RefSvg`'nin `fit:` parametresi YOK (yalnız
                  // sabit `size:`), bu yüzden arka planı KAPLAMASI
                  // gereken bu SVG için doğrudan `SvgPicture.asset`
                  // kullanıldı — `RefSvg` zaten aynı paketi sarıyor.
                  SvgPicture.asset('assets/svg/bul_location_bg.svg',
                      fit: BoxFit.cover),
                  Positioned(
                    right: -6,
                    bottom: 0,
                    child: Image.asset('assets/art/bul_location.png',
                        height: 62, fit: BoxFit.contain),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: RC.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const RefSvg('assets/svg/ic_pin.svg',
                              size: 19, color: RC.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Konumum',
                                style: refText(
                                    size: RF.s125,
                                    weight: RF.w500,
                                    color: RC.textSoft)),
                            const SizedBox(height: 2),
                            Text(
                              adres != null
                                  ? '${adres.district} / ${adres.city}'
                                  : 'Profilinizde kayıtlı bir adres yok',
                              style: refText(
                                  size: RF.s16,
                                  weight: RF.w700,
                                  color: RC.text),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ÜÇ AVANTAJ KARTI — YAN YANA, GERÇEK ASSET'LERLE ──
          //
          // ⚠ TASARIM YENİLENDİ — artık kullanıcının sağladığı gerçek
          // SVG dekoratif arka planlar (`bul_card_bg_*.svg`, iki
          // örtüşen daire deseni) ve kendi rengini taşıyan ikonlar
          // (`bul_ic_*.svg`) kullanılıyor. Önceki turda düz pastel
          // Color + tek renkli ikon vardı.
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: _AvantajKarti(
                  bgAsset: 'assets/svg/bul_card_bg_users.svg',
                  iconAsset: 'assets/svg/bul_ic_users.svg',
                  title: 'Sana uygun\nhizmet verenler',
                  aciklama: 'İhtiyacına ve konumuna uygun kişileri keşfet.',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _AvantajKarti(
                  bgAsset: 'assets/svg/bul_card_bg_star.svg',
                  iconAsset: 'assets/svg/bul_ic_star.svg',
                  title: 'Puan ve yorumları\nkarşılaştır',
                  aciklama:
                      'Gerçek kullanıcı deneyimlerini incele, doğru seçimi yap.',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _AvantajKarti(
                  bgAsset: 'assets/svg/bul_card_bg_chat.svg',
                  iconAsset: 'assets/svg/bul_ic_chat.svg',
                  title: 'Teklifini\ndoğrudan iste',
                  aciklama: 'Hızlı ve kolay bir şekilde iletişime geç.',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── "ARA" — HİZMET SEÇİLMEDEN AKTİF OLMAZ ──
          _AraButonu(
            aktif: _hizmet != null,
            onPressed: _hizmet != null ? _ara : null,
          ),
        ],
      ),
    );
  }
}

/// ── ⚠ SAYFA ÜST BUTONLARI İÇİN BEYAZ DAİRE ÇERÇEVE ──
///
/// Referans tasarımdaki gibi geri/kapat butonlarını hafif gölgeli
/// beyaz bir daire içine alır. `RefBackButton`/`RefTap`ın KENDİSİ
/// değişmedi — yalnız dışına bir görsel çerçeve eklendi.
class _DaireCerceve extends StatelessWidget {
  const _DaireCerceve({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RC.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ── ⚠ AVANTAJ KARTI — GERÇEK SVG DEKORATİF ARKA PLAN + KENDİ
/// RENGİNİ TAŞIYAN İKON ──
///
/// ⚠ TASARIM YENİLENDİ — `bgAsset` artık düz bir pastel `Color`
/// değil, kullanıcının sağladığı gerçek SVG deseni (iki örtüşen
/// daire, `card_bg_*.svg`). `iconAsset` de KENDİ RENGİNİ taşıyor
/// (`ic_users.svg` zaten turuncu, `ic_star.svg` zaten mor, vb.) —
/// bu yüzden `RefSvg`ye renk override VERİLMEDİ, ikon olduğu gibi
/// kullanıldı. Beyaz daire arka planı, ikonun pastel zemin üzerinde
/// öne çıkması için eklendi.
class _AvantajKarti extends StatelessWidget {
  const _AvantajKarti({
    required this.bgAsset,
    required this.iconAsset,
    required this.title,
    required this.aciklama,
  });

  final String bgAsset;
  final String iconAsset;
  final String title;
  final String aciklama;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RR.r16),
      child: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(bgAsset, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: RC.white,
                    shape: BoxShape.circle,
                  ),
                  child: RefSvg(iconAsset, size: 24),
                ),
                const SizedBox(height: 12),
                Text(title,
                    style: refText(
                        size: RF.s135, weight: RF.w800, color: RC.text)),
                const SizedBox(height: 6),
                Text(aciklama,
                    style: refText(
                        size: RF.s115,
                        weight: RF.w400,
                        color: RC.textSoft,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── ⚠ "ARA" DÜĞMESİ — YEŞİL, YALNIZ BU EKRANDA ──
///
/// Projedeki tek birincil düğme bileşeni `RefPrimaryButton` MAVİDİR
/// (`RG.blueCta`) — kod tabanında YEŞİL bir buton/gradyan tanımı
/// YOK. Yeni bir renk UYDURULMADI: `HC.green` (0xFF16A34A) zaten
/// `SysKind.success` için kullanılan, var olan semantik renktir.
///
/// Ölçü, köşe yarıçapı, dolgu ve tipografi `RefPrimaryButton` ile
/// BİREBİR aynı tutuldu — yalnız dolgu rengi değişti; yeni bir
/// görsel dil eklenmedi.
class _AraButonu extends StatelessWidget {
  const _AraButonu({required this.aktif, required this.onPressed});

  final bool aktif;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RR.r14),
        child: Material(
          color: HC.green,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RefSvg('assets/svg/ic_search.svg',
                      size: 18, color: RC.white),
                  const SizedBox(width: 8),
                  Text('Hizmet Verenleri Bul',
                      style: refText(
                          size: RF.s16, weight: RF.w700, color: RC.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ── ⚠ HİZMET-ZORUNLU ARAMA ALANI ──
///
/// `InlineSearchBox` (ana ekran arama kutusu) buradan KASITLI OLARAK
/// AYRIDIR: o bileşen kategori-only seçime de izin verir (bkz.
/// `_sec` içinde `h.subService` null olabilir). Bu ekranda kullanıcı
/// MUTLAKA somut bir HİZMET seçmeli — kategori seçimi kabul edilmez.
///
/// `InlineSearchBox`'ı değiştirmek ana sayfadaki kategori-gezinme
/// davranışını bozardı; bu yüzden aynı örüntü (SearchService +
/// açılır panel + X temizleme) burada YENİDEN kullanılıyor, aynı
/// bileşen ise DEĞİŞTİRİLMİYOR.
class _HizmetAramaAlani extends StatefulWidget {
  const _HizmetAramaAlani({
    required this.seciliHizmet,
    required this.onSecim,
    required this.onTemizle,
  });

  final String? seciliHizmet;
  final void Function(String kategori, String hizmet) onSecim;
  final VoidCallback onTemizle;

  @override
  State<_HizmetAramaAlani> createState() => _HizmetAramaAlaniState();
}

class _HizmetAramaAlaniState extends State<_HizmetAramaAlani> {
  final _ara = TextEditingController();
  List<SearchHit> _oneriler = const [];

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  void _sorgula(String q) {
    // ⚠ YALNIZ GERÇEK HİZMET SONUÇLARI: `subService == null` olan
    // (yalnız kategori) eşleşmeler burada elenir. Kullanıcı bir
    // hizmet seçmeden bu alan boş kalır.
    final tum = SearchService.services(q, enFazla: 200);
    setState(() => _oneriler =
        tum.where((h) => h.subService != null).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── ⚠ TASARIM YENİLENDİ (referans görsel) — daire içinde
        // arama ikonu, yumuşak gölge, İKİ SATIRLI yer tutucu (kalın
        // ana metin + gri örnek metin). `TextField`ın KENDİSİ,
        // `controller`ı, `onChanged` mantığı HİÇ DEĞİŞMEDİ — yalnız
        // görsel çerçeve ve boş durumdaki placeholder değişti.
        Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: RC.white,
            borderRadius: BorderRadius.circular(RR.r16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F3F6),
                  shape: BoxShape.circle,
                ),
                child: const RefSvg('assets/svg/ic_search.svg',
                    size: 18, color: Color(0xFF8A94A6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // ⚠ Boşken ÖZEL iki satırlı yer tutucu — Flutter'ın
                    // `hintText`i tek satır/tek stil olduğu için
                    // referanstaki İKİ satırlı, İKİ stilli görünüm
                    // (kalın ana metin + gri örnek metin) `hintText`
                    // ile yapılamıyordu.
                    if (_ara.text.isEmpty)
                      IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hangi hizmeti arıyorsun?',
                                style: refText(
                                    size: RF.s145,
                                    weight: RF.w700,
                                    color: RC.text)),
                            Text(
                                'Örn. ev temizliği, boya badana, '
                                'tesisatçı...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: refText(
                                    size: RF.s12,
                                    weight: RF.w400,
                                    color: RC.textSoft)),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _ara,
                      onChanged: (v) {
                        // ⚠ Kullanıcı yazmaya devam ederken önceki
                        // seçim GEÇERSİZ sayılır — yazılan metin
                        // katalogla yeniden eşleşene kadar "Ara"
                        // pasif kalır.
                        if (widget.seciliHizmet != null) {
                          widget.onTemizle();
                        }
                        _sorgula(v);
                      },
                      style: refText(
                          size: 14.5, weight: RF.w600, color: RC.text),
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              RefAramaTemizle(
                controller: _ara,
                onTemizle: () {
                  setState(() {
                    _ara.clear();
                    _oneriler = const [];
                  });
                  widget.onTemizle();
                },
              ),
            ],
          ),
        ),

        // ⚠ SEÇİLİ HİZMET GÖRÜNÜR ONAY: kullanıcı ne seçtiğini
        // görmeli. Panel bunun ÜSTÜNDE, yalnız yazarken çizilir.
        if (widget.seciliHizmet != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const RefSvg('assets/svg/ic_checkc.svg',
                  size: 16, color: HC.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.seciliHizmet!,
                    style: refText(
                        size: RF.s14, weight: RF.w600, color: RC.text)),
              ),
            ],
          ),
        ] else if (_oneriler.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: RC.white,
              border: Border.all(color: const Color(0xFFECEEF2)),
              borderRadius: BorderRadius.circular(RR.r13),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _oneriler.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF1F3F6)),
              itemBuilder: (_, i) {
                final h = _oneriler[i];
                return RefTap(
                  onTap: () {
                    _ara.text = h.subService!;
                    setState(() => _oneriler = const []);
                    widget.onSecim(h.category, h.subService!);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Text(h.subService!,
                        style: refText(
                            size: RF.s14, weight: RF.w500, color: RC.text)),
                  ),
                );
              },
            ),
          ),
        ] else if (_ara.text.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Sonuç bulunamadı',
              style: refText(
                  size: RF.s13, weight: RF.w400, color: RC.textSoft)),
        ],
      ],
    );
  }
}
