import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/services/search_service.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'scanning_screen.dart';
import 'teklif_istediklerim_screen.dart';

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

  void _hizmetSecildi(String kategori, String hizmet) {
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
          // ⚠ Konum ikonu buradan KALDIRILDI — aşağıdaki konum
          // kartında "Konumum" yazısının SOLUNA taşındı (ürün
          // kararı). Sağ üst artık `ic_close.svg` ile "Bul" akışının
          // tamamından çıkışı sağlıyor — `SonuclarScreen`'deki X ile
          // AYNI davranış ve AYNI hedef.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const RefBackButton(),
              RefTap(
                onTap: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/customer/listings', (r) => false),
                borderRadius: BorderRadius.circular(RR.circle),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: RefSvg('assets/svg/ic_close.svg', size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RefPageTitle('Hizmet Veren Bul', geriDugmesi: false),
          RefSubtitle('Aradığın hizmeti yaz, en uygun hizmet verenleri '
              'bulalım.'),
          const SizedBox(height: 10),

          // ── ⚠ "TEKLİF İSTEDİKLERİM" GİRİŞ NOKTASI — BURAYA TAŞINDI ──
          //
          // Profil menüsündeki ayrı satır KALDIRILDI (ürün kararı):
          // bu erişim artık "Bul" akışının kendi giriş ekranında.
          Align(
            alignment: Alignment.centerRight,
            child: RefPillButton(
              iconAsset: 'assets/svg/ic_send.svg',
              label: 'Teklif İstediklerim',
              onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const TeklifIstediklerimScreen())),
            ),
          ),
          const SizedBox(height: 10),

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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RC.blueSoft,
              borderRadius: BorderRadius.circular(RR.r12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠ İKON BURAYA TAŞINDI — üst bardaki konum ikonunun
                // yeni yeri, "Konumum" yazısının SOLU.
                Row(
                  children: [
                    const RefSvg('assets/svg/ic_pin.svg',
                        size: 16, color: HC.green),
                    const SizedBox(width: 6),
                    Text('Konumum',
                        style: refText(
                            size: RF.s125,
                            weight: RF.w500,
                            color: RC.textSoft)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  adres != null
                      ? '${adres.district} / ${adres.city}'
                      : 'Profilinizde kayıtlı bir adres yok',
                  style: refText(
                      size: RF.s15, weight: RF.w700, color: RC.text),
                ),
              ],
            ),
          ),

          // ── ÜÇ AVANTAJ KARTI — HER BİRİ AYRI VE KENDİ ÇERÇEVESİNDE ──
          //
          // ⚠ Düz metin bloğu DEĞİL: her satır kendi beyaz kartında,
          // `RefMenuRow` GENUİNE yeniden kullanılarak (ikon dairesi +
          // başlık, ok/alt yazı kapalı) — profildeki menü satırlarıyla
          // AYNI bileşen, yeni bir tasarım dili İCAT EDİLMEDİ.
          _AvantajKarti(
            iconAsset: 'assets/svg/ic_search.svg',
            iconBg: const Color(0xFFE7EFFD),
            title: 'İhtiyacına uygun hizmet verenler',
          ),
          const SizedBox(height: 8),
          _AvantajKarti(
            iconAsset: 'assets/svg/ic_starfill.svg',
            iconBg: const Color(0xFFFDF4E8),
            title: 'Puan ve yorumları karşılaştır',
          ),
          const SizedBox(height: 8),
          _AvantajKarti(
            iconAsset: 'assets/svg/ic_chat.svg',
            iconBg: const Color(0xFFE7F8EC),
            title: 'Teklifini doğrudan iste',
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

/// ── ⚠ AVANTAJ KARTI — `RefMenuRow`'un GENUİNE yeniden kullanımı ──
///
/// Profildeki menü satırlarıyla AYNI ikon-dairesi + başlık düzeni;
/// yalnız her biri kendi beyaz/çerçeveli kutusuna ALINDI ki "ayrı ayrı
/// şık" görünsün — düz alt alta metin bloğu DEĞİL.
class _AvantajKarti extends StatelessWidget {
  const _AvantajKarti({
    required this.iconAsset,
    required this.iconBg,
    required this.title,
  });

  final String iconAsset;
  final Color iconBg;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: const Color(0xFFECEEF2)),
        borderRadius: BorderRadius.circular(RR.r13),
      ),
      child: RefMenuRow(
        iconAsset: iconAsset,
        iconBg: iconBg,
        title: title,
        showChevron: false,
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
                  Text('Ara',
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
        Container(
          height: 53,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: RC.white,
            border: Border.all(color: const Color(0xFFECEEF2)),
            borderRadius: BorderRadius.circular(RR.r13),
          ),
          child: Row(
            children: [
              const RefSvg('assets/svg/ic_search.svg',
                  size: 23, color: Color(0xFFA8ADB4)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ara,
                  onChanged: (v) {
                    // ⚠ Kullanıcı yazmaya devam ederken önceki seçim
                    // GEÇERSİZ sayılır — yazılan metin katalogla
                    // yeniden eşleşene kadar "Ara" pasif kalır.
                    if (widget.seciliHizmet != null) {
                      widget.onTemizle();
                    }
                    _sorgula(v);
                  },
                  style:
                      refText(size: 14.5, weight: RF.w500, color: RC.text),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Hangi hizmeti arıyorsun?',
                    hintStyle: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9AA0A6)),
                  ),
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
