import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/tutar_bicimi.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/teklif_talebi_controller.dart';
import '../data/models/teklif_talebi.dart';
import '../domain/saglayici_ozeti.dart';
import '../domain/teklif_talebi_asamasi.dart';
import 'widgets/durum_rozeti.dart';
import 'widgets/saglayici_ozet_satiri.dart';
import 'widgets/yeni_mesaj_seridi.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import 'teklif_talebi_detay_screen.dart';

/// "TEKLİF İSTEDİKLERİM" (Aşama C) — hizmet alanın "Bul" akışından
/// gönderdiği doğrudan teklif taleplerinin BAĞIMSIZ ekranı.
///
/// ⚠ ARTIK "Bul" akışının BAŞ ekranında (`find_provider_screen.dart`)
/// da AYNI liste GÖMÜLÜ olarak gösteriliyor (bkz.
/// `TeklifIstediklerimListesi` altta) — bu bağımsız Scaffold'lu hâl
/// SİLİNMEDİ çünkü `teklif_iste_screen.dart` bir talep gönderildikten
/// SONRA hâlâ BURAYA yönlendiriyor (onay + tam liste). İki KULLANIM
/// YERİ, TEK liste mantığını (`TeklifIstediklerimListesi`) paylaşır —
/// kod tekrarı YOK.
///
/// ⚠ MEVCUT "İlanlarım" (`MyListingsScreen`) İLE KARIŞTIRILMAZ: o
/// ekran HERKESE AÇIK ilanları listeler; bu ekran yalnız belirli bir
/// hizmet verene ÖZEL gönderilen talepleri listeler. İki liste ayrı
/// kalır — `MyListingsScreen`'e DOKUNULMADI.
class TeklifIstediklerimScreen extends StatelessWidget {
  const TeklifIstediklerimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  const RefBackButton(),
                  const SizedBox(width: 8),
                  Text('Teklif İstediklerim',
                      style: refText(
                          size: RF.s18, weight: RF.w700, color: RC.text)),
                ],
              ),
            ),
            const Expanded(child: TeklifIstediklerimListesi()),
          ],
        ),
      ),
    );
  }
}

/// ── ⚠ LİSTE GÖVDESİ — HEM BAĞIMSIZ EKRANDA HEM "Bul" AKIŞININ BAŞ
/// EKRANINDA GÖMÜLÜ KULLANILIR ──
///
/// Scaffold/başlık İÇERMEZ — yalnız boş-durum metni + kart listesi.
/// `find_provider_screen.dart`, "Ara" düğmesinin ALTINDA bunu
/// DOĞRUDAN gömer; talep sayısı azsa doğal olarak kısa kalır,
/// `Column` içinde `shrinkWrap` bir `ListView` kullanılır.
class TeklifIstediklerimListesi extends StatelessWidget {
  const TeklifIstediklerimListesi({super.key, this.gomulu = false});

  /// ⚠ `true` iken bu widget kendi kaydırma alanı AÇMAZ
  /// (`shrinkWrap: true`, `NeverScrollableScrollPhysics`) — çağıran
  /// (ör. `find_provider_screen.dart`) zaten kaydırılabilir tek bir
  /// `ListView` içinde olduğu için, İÇ İÇE kaydırma çakışmaz.
  final bool gomulu;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentAccount;
    final talepler = me == null
        ? const <TeklifTalebi>[]
        // ── ⚠ YALNIZ SÜREN TALEPLER (kullanıcı kuralı, 9 Eyl) ──
        //
        // "Teklifi seçtikten sonra ilgili kart Bul'da görünmemeli,
        // tamamlanan işlere taşınmalı."
        //
        // ÖNCEDEN HİÇ SÜZGEÇ YOKTU: seçilen ve tamamlanan talepler bu
        // listede kalmaya devam ediyordu; kart iki yerde birden
        // görünüyordu.
        //
        // ⚠ SÜZGEÇ BURADA YAZILMAZ: aşama kuralı
        // `domain/teklif_talebi_asamasi.dart` içinde TEK yerde. Dört
        // liste aynı kaynaktan okur.
        : surenTalepler(
            context.watch<TeklifTalebiController>().byHizmetAlan(me.id));

    if (talepler.isEmpty) {
      return gomulu
          ? const SizedBox.shrink()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Henüz kimseden teklif istemedin.\n"Bul" '
                  'üzerinden bir hizmet veren seçip teklif '
                  'isteyebilirsin.',
                  textAlign: TextAlign.center,
                  style: refText(
                      size: RF.s14, weight: RF.w400, color: RC.textSoft),
                ),
              ),
            );
    }

    return ListView.separated(
      shrinkWrap: gomulu,
      physics: gomulu ? const NeverScrollableScrollPhysics() : null,
      padding: gomulu
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: talepler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TalepKarti(talep: talepler[i]),
    );
  }
}

class _TalepKarti extends StatelessWidget {
  const _TalepKarti({required this.talep});

  final TeklifTalebi talep;

  @override
  Widget build(BuildContext context) {
    final (metin, renk) = _durumGoster(talep.durum);
    // ⚠ EKLENDİ — kullanıcı bulgusu: bu kart yalnız maskeli ad
    // gösteriyordu. `teklif_iste_screen.dart`/`teklif_talebi_detay_
    // screen.dart`daki AYNI hizmet veren kartı (puan, yorum sayısı,
    // tamamlanan iş, konum) — istatistikler kimlik maskeliyken bile
    // gösterilir, o ekranlardaki AYNI ilke.
    final acik = talep.teklifTarihi != null;
    // ── ⚠ KOPYA ÖZET KALDIRILDI (9 Eyl) ──
    //
    // Bu kart puanı, yorum sayısını, tamamlanan işi ve konumu KENDİ
    // hesaplıyordu — "Sonuçlar" ve "Teklif İste" kartlarıyla dördüncü
    // bir kopya. Üstelik konumu `serviceDistricts.first`ten alıyordu,
    // yani düzeltilmiş "hesabın kendi adresi" kuralının DIŞINDA
    // kalmıştı: aynı hizmet veren burada başka adresle görünüyordu.
    //
    // Artık ortak `SaglayiciOzetSatiri` + `gercekSaglayiciOzeti`.
    // Yorum/puan `context.watch` ile canlı okunduğu için yeni bir
    // değerlendirme yazıldığı anda bu kart da güncellenir.
    final ozet = gercekSaglayiciOzeti(context, id: talep.saglayiciId) ??
        (
          id: talep.saglayiciId,
          adSoyad: talep.saglayiciAdi,
          puan: null,
          yorumSayisi: 0,
          tamamlananIs: 0,
          ilce: null,
          il: null,
        );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ⚠ DURUM ROZETİ KARTIN SAĞ ÜST KÖŞESİNDE
            // (kullanıcı isteği, 10 Eyl) ──
            //
            // ÖNCEDEN özet satırının sağındaydı, yani hizmet adının
            // BİR SATIR ALTINDA başlıyordu. Artık başlıkla AYNI
            // satırda; kartın sağ üst köşesine oturuyor.
            //
            // ⚠ BAŞLIK ESNER, ROZET ESNEMEZ: uzun hizmet adları
            // rozeti ittirmesin diye başlık `Expanded` içinde
            // kırpılır.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(talep.hizmet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: refText(
                          size: RF.s145, weight: RF.w700, color: RC.text)),
                ),
                const SizedBox(width: 8),
                DurumRozeti(
                  metin: metin,
                  renk: renk,
                  bekliyor: talep.durum == TeklifTalebiDurumu.beklemede,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── ⚠ DURUM VE TUTAR, ÖZETİN SAĞINDA ──
            //
            // Kullanıcı isteği (9 Eyl): "Teklif bekleniyor / Teklif
            // geldi yazıları altta olmasın, isim bilgisinin yanında
            // yer alsın." Özet satırı ile durum AYNI hizada duruyor;
            // durum, adın hemen sağına düşüyor.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠ MASKELEME: teklif geldiyse kimlik açılır.
                Expanded(child: SaglayiciOzetSatiri(ozet, maskeli: !acik)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚠ DURUM ROZETİ BURADAN KALKTI (10 Eyl): artık
                    // kartın sağ ÜST köşesinde, başlıkla aynı
                    // satırda. Bu sütunda yalnız yeni mesaj ve tutar
                    // kaldı.
                    // ── ⚠ YENİ MESAJ (kullanıcı isteği, 9 Eyl) ──
                    //
                    // Kartta mesaj geldiğine dair hiçbir iz yoktu;
                    // anlamanın tek yolu talebi açıp sohbete
                    // girmekti. Sayım `okunmamisMesajSayisi` ile TEK
                    // yerde — iki taraf da aynı ölçütü kullanır.
                    // ⚠ İZLEYEN BU EKRANDA DAİMA HİZMET ALANDIR;
                    // okunmamış sayısı ONUN gözünden hesaplanır.
                    if (okunmamisMesajSayisi(talep, talep.hizmetAlanId) >
                        0) ...[
                      const SizedBox(height: 4),
                      YeniMesajSeridi(
                          okunmamisMesajSayisi(talep, talep.hizmetAlanId)),
                    ],
                    // ⚠ TUTAR YALNIZ GELDİYSE: teklif verilmemişken
                    // sıfır ya da yer tutucu GÖSTERİLMEZ. "TL" ve
                    // binlik ayracı `core/tutar_bicimi.dart`ta.
                    if (talep.teklifFiyati != null) ...[
                      const SizedBox(height: 4),
                      Text(tutarMetni(talep.teklifFiyati!),
                          style: refText(
                              size: RF.s135, weight: RF.w700, color: renk)),
                    ],
                  ],
                ),
              ],
            ),
            // ⚠ ALTTAKİ DURUM ROZETİ KALDIRILDI (9 Eyl): artık
            // ismin yanında, tutarla birlikte gösteriliyor.
          ],
        ),
      ),
    );
  }

  (String, Color) _durumGoster(TeklifTalebiDurumu d) => switch (d) {
        TeklifTalebiDurumu.beklemede => (kTeklifBekleniyorMetni, RC.blue),
        TeklifTalebiDurumu.teklifGeldi => ('Teklif geldi', HC.green),
        TeklifTalebiDurumu.secildi => ('İş aktif', HC.green),
        TeklifTalebiDurumu.reddedildi => ('Reddedildi', HC.grey),
        TeklifTalebiDurumu.suresiDoldu => ('Süresi doldu', HC.grey),
        TeklifTalebiDurumu.tamamlandi => ('İş tamamlandı', RC.blue),
      };
}

/// ⚠ DÖRDÜNCÜ KOPYA KALDIRILDI (9 Eyl): tamamlanan iş sayımı
/// `domain/saglayici_ozeti.dart` içindeki `tamamlananIsSayisi` ile
/// TEK yerde tanımlıdır. Bu dosyadaki kopya, kartın ortak özet
/// bileşenine taşınmasıyla kullanılmaz hâle geldi.
