import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import '../domain/profil_menusu.dart';
import 'ref_tokens.dart';
import 'gezgin.dart';
import 'ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// MASAÜSTÜ KENAR ÇUBUĞU
///
/// Geniş web'de üst menünün yerini alır. Mobil uygulamanın alt barı
/// da üst menü de burada yoktur; gerçek bir web panelinin sol sütunu.
///
/// ## ⚠ İKİ KAYNAKTAN BESLENİR, İKİSİ DE ORTAK
///
///   · Ana gezinme (İşlerim, Kazandığım, Bildirimler …) →
///     `custNavItems`, yani alt barı besleyen AYNI liste.
///   · Profil menüsü (Hizmet Kategorilerim, Destek Merkezi, Çıkış …)
///     → `domain/profil_menusu.dart`, yani profil ekranını besleyen
///     AYNI liste.
///
/// Hiçbir öğe burada yeniden tanımlanmadı. Yeni bir menü satırı
/// eklendiğinde kenar çubuğuna kendiliğinden gelir.
///
/// ## ⚠ ROL AYRIMI VERİDE
///
/// Hizmet veren ve hizmet alan farklı öğeler görür, ama bu fark
/// `custNavItems` ve `profilMenusu(rol)` içinde tanımlı. Burada rol
/// sorgulayan tek bir satır yoktur.
///
/// ## ⚠ ARAMA YOK
///
/// Üst menüde arama vardı; kenar çubuğunda yok. Arama hizmet alanın
/// ana sayfasına ait bir araçtır — hizmet verenin ilanları zaten
/// önüne geliyor, arayacağı bir şey yok.
///
/// ## ⚠ MEVCUT GÖRSEL DİL
///
/// Logo, ikonlar, renkler ve yazı tipi mevcut sistemden. Yeni ikon
/// çizilmedi, yeni renk üretilmedi.
/// ═══════════════════════════════════════════════════════════════
class WebKenarCubugu extends StatelessWidget {
  const WebKenarCubugu({
    super.key,
    required this.items,
    required this.activeKey,
    required this.eylem,
  });

  /// Ana gezinme öğeleri — `RefBottomNav` ile AYNI tip.
  ///
  /// ⚠ Tip birebir aynı tutuldu: biri değişip öteki unutulursa
  /// derleme hatası verir, sessiz ayrışma olmaz.
  final List<
      ({
        String key,
        String label,
        String asset,
        VoidCallback onTap,
        bool rozet,
        int belirginRozetSayisi,
      })> items;

  final String activeKey;

  /// Rota dışı menü eylemleri (rol değiştir, destek, paylaş, çıkış).
  ///
  /// ⚠ KENAR ÇUBUĞU BUNLARI BİLMEZ: karşılıkları profil ekranında
  /// zaten yazılı; buraya kopyalanmadı.
  final void Function(ProfilEylemi) eylem;

  static const double genislik = 268;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final acc = auth.currentAccount;
    final rol = auth.activeRole;
    // ⚠ "İlan Ver" ANA GEZİNMEDE DEĞİL: alt barda ortadaki çentikli
    // düğmedir, bir sekme değil. Kenar çubuğunda da sekme listesine
    // karışmaz; içerik alanındaki kendi düğmesinden açılır.
    // ⚠ "PROFİL" SEKMESİ DE ÇIKARILDI: kenar çubuğunun üstündeki
    // kimlik kartı zaten profile götürüyor ve profil menüsünün
    // TAMAMI aşağıda satır satır duruyor. Ayrı bir "Profil" satırı
    // aynı yere üçüncü bir kapı açardı.
    //
    // ⚠ ALT BAR DEĞİŞMEZ: orada "Profil" sekmesi duruyor; mobilde
    // menü satırları görünmediği için oraya girişin tek yolu o.
    // ⚠ ŞU ANKİ ROTA: kenar çubuğu Navigator'ın altında çizildiği
    // için `ModalRoute` burada okunabilir. Ayrı bir durum tutulmadı.
    final acikRota = ModalRoute.of(context)?.settings.name;
    final sekmeler = items
        .where((it) => it.key != 'ilanver' && it.key != 'profil')
        .toList();

    return Container(
      width: genislik,
      decoration: const BoxDecoration(
        color: RC.white,
        border: Border(right: BorderSide(color: RC.border)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⚠ MEVCUT MARKA ASSET'İ; yeniden çizilmedi.
              // ── ⚠ LOGO UYGULAMADAKİ GİBİ: SİMGE + WORDMARK ──
              //
              // Burada yalnız `wordmark.png` çiziliyordu; uygulamanın
              // ana sayfasında ise SOLDA mavi/turuncu logo SİMGESİ,
              // yanında wordmark var. Marka eksik görünüyordu.
              //
              // ⚠ ORANLAR ANA SAYFADAN BİREBİR: simge 148/182,
              // wordmark 318/76. Yeni ölçü uydurulmadı, asset'ler
              // esnetilmedi.
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Image(
                      image: AssetImage('assets/logo/logo_mark.png'),
                      width: 32 * 148 / 182,
                      height: 32,
                      filterQuality: FilterQuality.high,
                    ),
                    SizedBox(width: 4),
                    Image(
                      image: AssetImage('assets/logo/wordmark.png'),
                      width: 20 * 318 / 76,
                      height: 20,
                      filterQuality: FilterQuality.high,
                    ),
                  ],
                ),
              ),
              // ⚠ UYGULAMANIN KENDİ ROZETİ (`RefRolEtiketi`):
              // burada ayrı bir rozet çizilmişti ve renkleri
              // uygulamadakinden FARKLIYDI (turuncu yerine mavi/yeşil
              // olmalı, ikon hizmet alanda kalkan). Kopya silindi;
              // rozet tek kaynaktan geliyor.
              RefRolEtiketi(saglayici: rol == Role.provider),
              const SizedBox(height: 14),
              // ⚠ TAM GENİŞLİK: dış sütun `start` hizalı olduğu için
              // kart içeriği kadar dar kalıyor ve ORTALAMA ETKİSİZ
              // oluyordu. Kart sütunun tamamını kaplar, içindeki
              // ortalama böylece gerçekten ortaya denk gelir.
              if (acc != null)
                SizedBox(width: double.infinity, child: _Kimlik(acc: acc)),
              const _Ayrac(),
              for (final it in sekmeler)
                _Satir(
                  ikon: it.asset,
                  baslik: it.label,
                  aktif: it.key == activeKey,
                  rozet: it.rozet,
                  sayi: it.belirginRozetSayisi,
                  onTap: it.onTap,
                ),
              for (final bolum in profilMenusu(rol)) ...[
                const _Ayrac(),
                for (final oge in bolum.ogeler)
                  _Satir(
                    ikon: oge.ikon,
                    baslik: oge.baslik,
                    // ⚠ VURGU ANA SEKMELERLE AYNI KURALDA: açık olan
                    // bölüm mavi metin, açık mavi zemin ve sol kenar
                    // çizgisi alır. Önceden hep `false` idi;
                    // kullanıcı "İşlerim" vurgulanırken "Hizmet
                    // Bölgelerim"in vurgulanmamasını tutarsız
                    // buluyordu.
                    //
                    // ⚠ ROTAYA GÖRE: öğenin rotası ile şu anki rota
                    // aynıysa aktiftir. Eylem öğeleri (rol değiştir,
                    // paylaş) bir sayfa açmadığı için hiç aktif
                    // olmaz — `rota` onlarda null.
                    aktif: oge.rota != null && oge.rota == acikRota,
                    onTap: () => _ac(context, oge),
                  ),
              ],
              const _Ayrac(),
              _Satir(
                ikon: cikisOgesi.ikon,
                baslik: cikisOgesi.baslik,
                aktif: false,
                tehlikeli: true,
                onTap: () => eylem(ProfilEylemi.cikis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ac(BuildContext context, ProfilMenuOgesi oge) {
    if (oge.rota != null) {
      // ⚠ AYNI SEBEP: ortak anahtar üzerinden.
      gezginAnahtari.currentState
          ?.pushNamed(oge.rota!, arguments: oge.rotaArgumani);
      return;
    }
    if (oge.eylem != null) {
      eylem(oge.eylem!);
    }
  }
}

/// Avatar + ad + telefon + e-posta.
class _Kimlik extends StatelessWidget {
  const _Kimlik({required this.acc});

  final Account acc;

  @override
  Widget build(BuildContext context) =>
      // ── ⚠ TIKLANABİLİR KİMLİK KARTI ──
      //
      // Referansta bu blok yalnız bilgi gösteriyordu; kullanıcı
      // fotoğrafını veya telefonunu değiştirmek için ayrı bir yol
      // aramak zorundaydı. Kart artık "Profil Bilgilerim" ekranını
      // açar — profil menüsündeki satırla AYNI rota, ikinci bir
      // düzenleme ekranı yok.
      //
      // ⚠ ORTALI: avatar, ad ve iletişim satırları sütunun ortasında.
      RefTap(
        // ⚠ `Navigator.of(context)` BURADA ÇALIŞMAZ: kenar çubuğu
        // Navigator'ın ÜSTÜNDE çizilir. Gezinme ortak anahtar
        // üzerinden yapılır (`ui/gezgin.dart`).
        // ⚠ HEDEF `/profile/info`: ad, soyad, e-posta, telefon VE
        // profil fotoğrafı artık orada. `/profile` masaüstü web'de
        // gereksiz — menüsünün tamamı bu çubukta zaten var, açılınca
        // her şey İKİ KEZ görünüyordu.
        onTap: () => gezginAnahtari.currentState?.pushNamed('/profile/info'),
        borderRadius: BorderRadius.circular(RR.r12),
        // ⚠ İPUCU YOK: `Tooltip` balonunu bir `Overlay` üzerinde
        // çizer ve ÜSTÜNDE bir `Overlay` atası arar. Kenar çubuğu
        // `GlobalWebKabugu` içinde, yani Navigator'ın ÜSTÜNDE
        // çiziliyor; Navigator'ın `Overlay`i buranın ALTINDA kalıyor.
        // Sonuç: "No Overlay widget found" ve kırmızı hata ekranı.
        //
        // ⚠ KABUĞA `Overlay` EKLENMEDİ: aynı yol `SelectionArea`
        // için denendi ve iki kez üretimi düşürdü. İpucu bir
        // kolaylıktır; kartın tıklanabilir olduğu imleçten zaten
        // anlaşılıyor.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            // ⚠ `center` + DIŞTA TAM GENİŞLİK: dış `SizedBox` sütunun
            // tamamını kaplar, bu sütun da içeriğini ORTALAR.
            //
            // ⚠ `stretch` OLMAZ: çocukları tam genişliğe ZORLAR;
            // avatar gerilir, metinler sola yapışır.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ⚠ MEVCUT AVATAR BİLEŞENİ: fotoğraf varsa onu, yoksa
              // baş harfi çizer. İkinci bir avatar mantığı yazılmadı.
              RefBasHarfAvatar(ad: acc.name, cap: 64),
              const SizedBox(height: 10),
              Text(acc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      refText(size: RF.s16, weight: RF.w700, color: RC.text)),
              const SizedBox(height: 6),
              _KimlikSatiri(
                  ikon: 'assets/svg/ic_phone.svg', metin: acc.phone),
              const SizedBox(height: 4),
              _KimlikSatiri(
                  ikon: 'assets/svg/ic_mail.svg', metin: acc.email),
            ],
          ),
        ),
      );
}

class _KimlikSatiri extends StatelessWidget {
  const _KimlikSatiri({required this.ikon, required this.metin});

  final String ikon;
  final String metin;

  @override
  Widget build(BuildContext context) => Row(
        // ⚠ ORTALI: `Expanded` kaldırıldı, yoksa metin sola yaslanır.
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RefSvg(ikon, size: 14, color: RC.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(metin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: refText(
                    size: RF.s125, weight: RF.w400, color: RC.textSoft)),
          ),
        ],
      );
}

/// Bölüm ayracı.
class _Ayrac extends StatelessWidget {
  const _Ayrac();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, thickness: 1, color: RC.border),
      );
}

/// Menüdeki tek satır.
class _Satir extends StatelessWidget {
  const _Satir({
    required this.ikon,
    required this.baslik,
    required this.aktif,
    required this.onTap,
    this.rozet = false,
    this.sayi = 0,
    this.tehlikeli = false,
  });

  final String ikon;
  final String baslik;
  final bool aktif;
  final VoidCallback onTap;
  final bool rozet;
  final int sayi;
  final bool tehlikeli;

  @override
  Widget build(BuildContext context) {
    // ⚠ AKTİF SATIR: mavi metin, açık mavi zemin ve SOL KENARDA
    // dikey çizgi. Üçü birlikte olmalı — yalnız renk, dar bir
    // sütunda yeterince belirgin değil.
    final renk = tehlikeli
        ? RC.danger
        : aktif
            ? RC.blue
            : RC.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RefTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RR.r9),
        child: Container(
          decoration: BoxDecoration(
            color: aktif ? RC.blueSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(RR.r9),
            border: Border(
              left: BorderSide(
                color: aktif ? RC.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              RefSvg(ikon, size: 18, color: renk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refText(
                        size: RF.s135,
                        weight: aktif ? RF.w700 : RF.w500,
                        color: renk)),
              ),
              // ⚠ GÖSTERGELER ALT BARDAKİ DİLİ KORUR: nokta "yeni
              // var", sayı rozeti "kaç tane".
              if (sayi > 0)
                RefSayiRozeti(sayi: sayi, halkaRengi: RC.white)
              else if (rozet)
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: RC.blue, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
