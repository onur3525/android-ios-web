import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/account.dart';
import '../data/models/teklif_talebi.dart';
import '../domain/hizmet_alan_ozeti.dart';
import '../domain/kullanici_konumu.dart';
import '../domain/teklif_talebi_asamasi.dart';
import '../domain/yorum_gorunumu.dart' show kisaTarih;
import 'widgets/durum_rozeti.dart';
import 'widgets/yeni_mesaj_seridi.dart';
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
/// ⚠ ARAMA ÇUBUĞU / "Ara" DÜĞMESİ YOK (ürün kararı) — bu ekranda
/// yalnız gelen teklif istekleri kartları listelenir; karta
/// girilip teklif verilir. Önceden "Hizmet Veren Bul" ekranıyla
/// aynı görsel dilde bir arama alanı vardı, KALDIRILDI.
///
/// ⚠ MEVCUT "İşlerim" (`JobsScreen`) İLE KARIŞTIRILMAZ: o ekran
/// HERKESE AÇIK ilanları listeler; bu liste yalnız belirli bu
/// hizmet verene ÖZEL gönderilen talepleri gösterir.
class TeklifIstekleriListesi extends StatelessWidget {
  const TeklifIstekleriListesi({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentAccount;
    // ⚠ DÜZELTİLDİ — kullanıcı bulgusu: hizmet alan teklifi
    // SEÇTİĞİNDE (`secildi`) talep bu listede KALMAYA devam
    // ediyordu; artık "Kazandığım" bölümüne TAŞINIYOR (bkz.
    // `jobs_screen.dart`), bu yüzden burada GÖSTERİLMEZ.
    final talepler = me == null
        ? const <TeklifTalebi>[]
        : context
            .watch<TeklifTalebiController>()
            .bySaglayici(me.id)
            // ── ⚠ YALNIZ SÜREN TALEPLER (kullanıcı kuralı, 9 Eyl) ──
            //
            // ÖNCEDEN `!= secildi` idi. Ama seçim anında akış
            // `secToVer` ardından `tamamla` çağırıyor, yani durum
            // `tamamlandi` oluyordu — kart bu listede KALIYORDU.
            // Tek bir durumu dışlamak yetmez; aşama kuralı tek
            // yerden gelir.
            .where((t) => talepSurenMi(t.durum))
            .toList();

    if (talepler.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henüz doğrudan bir teklif talebiniz yok.',
            textAlign: TextAlign.center,
            style: refText(size: RF.s14, weight: RF.w400, color: RC.textSoft),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: talepler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TalepKarti(
        talep: talepler[i],
        hizmetAlan: auth.accountById(talepler[i].hizmetAlanId),
      ),
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
                      const RefSvg('assets/svg/ic_briefcase.svg',
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

                  // ── ⚠ KONUM (kullanıcı isteği, 10 Eyl) ──
                  //
                  // ÖNCEDEN "Yeni üye" / "N yıldır üye" yazıyordu.
                  // Hizmet veren için üyelik süresi teklif kararını
                  // etkilemiyor; işin NEREDE olduğu ise doğrudan
                  // etkiliyor.
                  //
                  // ⚠ MAHALLE DÂHİL: ilçe tek başına yetmiyor —
                  // "Kazandığım" kartlarında da mahalle gösteriliyor.
                  //
                  // ⚠ BİÇİM TEK KAYNAKTAN: `kullaniciKonumu`. Adres
                  // yoksa satır HİÇ çizilmez, yer tutucu konmaz.
                  if (kullaniciKonumu(context, talep.hizmetAlanId,
                          mahalleDahil: true) !=
                      null) ...[
                    Row(
                      children: [
                        const RefSvg('assets/svg/ic_pin.svg',
                            size: 13, color: Color(0xFF98A2B3)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                              kullaniciKonumu(context, talep.hizmetAlanId,
                                  mahalleDahil: true)!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: refText(
                                  size: RF.s12,
                                  weight: RF.w400,
                                  color: const Color(0xFF98A2B3))),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),

                  // ⚠ DURUM VE YENİ MESAJ YAN YANA: ikisi de kartın
                  // "şu an ne oluyor" bilgisi. Alt alta konsaydı kart
                  // uzar, liste seyrekleşirdi.
                  Row(
                    children: [
                      // ⚠ AYNI ROZET, AYNI BİLEŞEN: hizmet veren
                      // tarafında da ölçü ve canlılık kuralı aynı
                      // olmalı; iki liste ayrı çizilseydi biri
                      // güncellenip öteki eskide kalırdı.
                      //
                      // ⚠ BEKLEYEN DURUM BURADA `beklemede`DİR:
                      // hizmet veren henüz teklif vermemiştir.
                      DurumRozeti(
                        metin: metin,
                        renk: renk,
                        bekliyor: talep.durum == TeklifTalebiDurumu.beklemede,
                      ),
                      // ── ⚠ YENİ MESAJ (kullanıcı isteği, 9 Eyl) ──
                      //
                      // ⚠ İZLEYEN BU EKRANDA DAİMA HİZMET VERENDİR;
                      // okunmamış sayısı ONUN gözünden hesaplanır.
                      // Sayım `okunmamisMesajSayisi` ile TEK yerde.
                      if (okunmamisMesajSayisi(talep, talep.saglayiciId) >
                          0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: YeniMesajSeridi(okunmamisMesajSayisi(
                              talep, talep.saglayiciId)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ── ⚠ TALEP TARİHİ — KARTIN SAĞ ÜST KÖŞESİ (12 Eyl,
            // kullanıcı isteği) ──
            //
            // "Teklif talep kartlarında da sağ üst köşede ilan tarihi
            // yazılsın."
            //
            // ⚠ "Yeni işler" KARTIYLA AYNI YER VE AYNI BİÇİM: iki
            // liste yan yana sekmelerde duruyor; biri tarihi sağ üstte
            // gösterip öteki hiç göstermezse kullanıcı aynı bilgiyi
            // iki farklı yerde arar.
            //
            // ⚠ GÖRELİ SÜRE DEĞİL TARİH: detay ekranlarındaki "Talep
            // Tarihi" satırı da tarih gösteriyor.
            //
            // ⚠ ÜSTTEN HİZALI: `Row`un `crossAxisAlignment`ı `start`,
            // metin adla aynı hizada durur.
            const SizedBox(width: 8),
            Text(kisaTarih(talep.createdAt),
                style: refText(
                    size: RF.s11, weight: RF.w500, color: RC.textSoft)),
          ],
        ),
      ),
    );
  }

  /// ⚠ HİZMET ALANIN kaç işi tamamlandı — `offer_detail_screen.dart`
  /// içindeki `_tamamlananIs` (PROVIDER için) ile AYNI mantık, yalnız
  /// yön TERS: burada ilan SAHİBİNİN (`ownerId`) kaç ilanı
  /// tamamlanmış sayılıyor.
  /// ⚠ KOPYA KALDIRILDI (10 Eyl): hizmet alanın tamamlanan iş
  /// sayısı `domain/hizmet_alan_ozeti.dart` içinde TEK yerde. Bu
  /// kopya YALNIZ ilanları sayıyordu; "Bul" akışından tamamlanan
  /// talepleri hiç saymıyordu, dolayısıyla aynı kişi bu kartta daha
  /// düşük görünüyordu.
  ///
  /// ⚠ Ortak fonksiyon denetleyicileri `watch` ile okur; iş
  /// tamamlandığında bu kart da anında tazelenir.
  int _tamamlananIs(BuildContext c, String hizmetAlanId) =>
      hizmetAlanTamamlananIs(c, hizmetAlanId);



  /// ⚠ GERÇEK KAYIT TARİHİNDEN — uydurma bir süre DEĞİLDİR.
  // ⚠ `_uyelikSuresi` KALDIRILDI (10 Eyl): "Yeni üye" satırı yerini
  // konuma bıraktı; yardımcı kullanılmaz hâle geldi. Üyelik bilgisi
  // hâlâ gerekiyorsa tek kaynağı `domain/hizmet_alan_ozeti.dart`
  // içindeki `uyelikTarihiMetni`dir — burada ikinci bir tanım
  // bırakmak ikisinin ayrışmasına davetiye olurdu.



  (String, Color) _durumGoster(TeklifTalebiDurumu d) => switch (d) {
        TeklifTalebiDurumu.beklemede => ('Yanıt bekliyor', RC.blue),
        TeklifTalebiDurumu.teklifGeldi => ('Teklif verildi', HC.green),
        TeklifTalebiDurumu.secildi => ('İş aktif', HC.green),
        TeklifTalebiDurumu.reddedildi => ('Reddedildi', HC.grey),
        TeklifTalebiDurumu.suresiDoldu => ('Süresi doldu', HC.grey),
        TeklifTalebiDurumu.tamamlandi => ('İş tamamlandı', RC.blue),
      };
}
