import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/listing_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/account.dart';
import '../data/models/teklif_talebi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'job_detail_screen.dart' show maskeliAd;
import 'teklif_talebi_detay_screen.dart';

/// "TEKLİF İSTEKLERİ" — hizmet verene "Bul" akışından doğrudan
/// gönderilen taleplerin liste GÖVDESİ.
///
/// ⚠ ARTIK KENDİ BAŞINA BİR EKRAN DEĞİL: bu içerik `JobsScreen`
/// ("İşlerim") içine ÜÇÜNCÜ SEKME olarak gömülür (bkz.
/// `jobs_screen.dart`) — konteyner ekran DEĞİŞMEDİ (ürün kararı).
/// Bu yüzden `Scaffold`/geri düğmesi/başlık İÇERMEZ; yalnız gövde.
///
/// ⚠ ÜST KISIMDAKİ ARAMA ALANI + YEŞİL "Ara" DÜĞMESİ, müşterinin
/// "Hizmet Veren Bul" ekranındaki AYNI görsel dil — ama farklı iş:
/// orada YENİ hizmet verenler bulunur, burada hizmet verenin
/// KENDİSİNE GELEN taleplerin arasında hizmet adına göre FİLTRELEME
/// yapılır. Yeni bir arama motoru İCAT EDİLMEDİ, yalnız görsel
/// bileşenler (arama kutusu + yeşil "Ara" düğmesi biçimi) yeniden
/// kullanıldı.
///
/// ⚠ MEVCUT "İşlerim" (`JobsScreen`) İLE KARIŞTIRILMAZ: o ekran
/// HERKESE AÇIK ilanları listeler; bu liste yalnız belirli bu
/// hizmet verene ÖZEL gönderilen talepleri gösterir.
class TeklifIstekleriListesi extends StatefulWidget {
  const TeklifIstekleriListesi({super.key});

  @override
  State<TeklifIstekleriListesi> createState() =>
      _TeklifIstekleriListesiState();
}

class _TeklifIstekleriListesiState extends State<TeklifIstekleriListesi> {
  final _ara = TextEditingController();

  /// ⚠ Yazarken FİLTRELENMEZ — "Ara" basılınca uygulanır (referans
  /// ekranla AYNI akış: yaz, sonra Ara'ya bas).
  String _uygulananSorgu = '';

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    final tumTalepler = me == null
        ? const <TeklifTalebi>[]
        : context.watch<TeklifTalebiController>().bySaglayici(me.id);

    final sorgu = _uygulananSorgu.trim().toLowerCase();
    final talepler = sorgu.isEmpty
        ? tumTalepler
        : tumTalepler
            .where((t) => t.hizmet.toLowerCase().contains(sorgu))
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      children: [
        // ── ARAMA ALANI ──
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
                  onSubmitted: (v) => setState(() => _uygulananSorgu = v),
                  style:
                      refText(size: 14.5, weight: RF.w500, color: RC.text),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Hangi hizmette arıyorsun?',
                    hintStyle: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9AA0A6)),
                  ),
                ),
              ),
              RefAramaTemizle(
                controller: _ara,
                onTemizle: () => setState(() {
                  _ara.clear();
                  _uygulananSorgu = '';
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── "ARA" — AŞAMA 1'DEKİ YEŞİL DÜĞMEYLE AYNI GÖRSEL DİL ──
        ClipRRect(
          borderRadius: BorderRadius.circular(RR.r14),
          child: Material(
            color: HC.green,
            child: InkWell(
              onTap: () => setState(() => _uygulananSorgu = _ara.text),
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
        const SizedBox(height: 16),

        // ── TALEP KARTLARI ──
        if (talepler.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                sorgu.isEmpty
                    ? 'Henüz doğrudan bir teklif talebiniz yok.'
                    : '"$sorgu" için talep bulunamadı.',
                textAlign: TextAlign.center,
                style:
                    refText(size: RF.s14, weight: RF.w400, color: RC.textSoft),
              ),
            ),
          )
        else
          for (var i = 0; i < talepler.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _TalepKarti(talep: talepler[i], hizmetAlan: auth.accountById(talepler[i].hizmetAlanId)),
          ],
      ],
    );
  }
}

class _TalepKarti extends StatelessWidget {
  const _TalepKarti({required this.talep, required this.hizmetAlan});

  final TeklifTalebi talep;

  /// ⚠ NULL OLABİLİR: hesap silinmiş/bulunamıyor olabilir — bu
  /// durumda istatistikler ve ad "bilinmiyor" gösterilir, ekran
  /// ÇÖKMEZ.
  final Account? hizmetAlan;

  @override
  Widget build(BuildContext context) {
    final acik = talep.teklifTarihi != null;
    final hizmetAlanAdi = hizmetAlan?.name ?? 'Hizmet Alan';
    final (metin, renk) = _durumGoster(talep.durum);

    return RefTap(
      onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
              builder: (_) => TeklifTalebiDetayScreen(talepId: talep.id))),
      borderRadius: BorderRadius.circular(RR.r13),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: RC.white,
          border: Border.all(color: const Color(0xFFECEEF2)),
          borderRadius: BorderRadius.circular(RR.r13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FOTOĞRAF — TEKLİF VERİLENE KADAR BUZLU ──
            acik
                ? RefBasHarfAvatar(ad: hizmetAlanAdi)
                : const RefSvg('assets/svg/ic_avlock.svg', size: 44),
            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AD SOYAD — MASKELİ ──
                  Text(acik ? hizmetAlanAdi : maskeliAd(hizmetAlanAdi),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s145, weight: RF.w700, color: RC.text)),
                  const SizedBox(height: 3),

                  // ── İSTEDİĞİ HİZMET ──
                  Text(talep.hizmet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s13, weight: RF.w500, color: RC.textSoft)),
                  const SizedBox(height: 6),

                  // ── KAÇ İŞ BİTİRDİĞİ ──
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_shieldok.svg',
                          size: 13, color: Color(0xFF5B6472)),
                      const SizedBox(width: 5),
                      Text(
                          '${_tamamlananIs(context, talep.hizmetAlanId)} iş '
                          'tamamladı',
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: const Color(0xFF5B6472))),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // ── KAÇ YILDIR ÜYE ──
                  Row(
                    children: [
                      const RefSvg('assets/svg/ic_clock.svg',
                          size: 13, color: Color(0xFF98A2B3)),
                      const SizedBox(width: 5),
                      Text(_uyelikSuresi(hizmetAlan?.kayitTarihi),
                          style: refText(
                              size: RF.s12,
                              weight: RF.w400,
                              color: const Color(0xFF98A2B3))),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RR.r13),
                    ),
                    child: Text(metin,
                        style: refText(
                            size: RF.s12, weight: RF.w700, color: renk)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠ HİZMET ALANIN kaç işi tamamlandı — `offer_detail_screen.dart`
  /// içindeki `_tamamlananIs` (PROVIDER için) ile AYNI mantık, yalnız
  /// yön TERS: burada ilan SAHİBİNİN (`ownerId`) kaç ilanı
  /// tamamlanmış sayılıyor.
  int _tamamlananIs(BuildContext c, String hizmetAlanId) {
    final ilanlar = c.read<ListingController>().all;
    return ilanlar
        .where((l) => l.ownerId == hizmetAlanId && l.isTamamlanmisIs)
        .length;
  }

  /// ⚠ GERÇEK KAYIT TARİHİNDEN — uydurma bir süre DEĞİLDİR.
  String _uyelikSuresi(DateTime? kayitTarihi) {
    if (kayitTarihi == null) {
      return 'Üyelik süresi bilinmiyor';
    }
    final yil = DateTime.now().difference(kayitTarihi).inDays ~/ 365;
    if (yil < 1) {
      return 'Yeni üye';
    }
    return '$yil yıldır üye';
  }

  (String, Color) _durumGoster(TeklifTalebiDurumu d) => switch (d) {
        TeklifTalebiDurumu.beklemede => ('Yanıt bekliyor', RC.blue),
        TeklifTalebiDurumu.teklifGeldi => ('Teklif verildi', HC.green),
        TeklifTalebiDurumu.secildi => ('İş aktif', HC.green),
        TeklifTalebiDurumu.reddedildi => ('Reddedildi', HC.grey),
        TeklifTalebiDurumu.suresiDoldu => ('Süresi doldu', HC.grey),
        TeklifTalebiDurumu.tamamlandi => ('İş tamamlandı', RC.blue),
      };
}
