import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/validators.dart';
import '../../core/telefon_bicimi.dart';
import '../../core/ad_bicimi.dart';
import 'package:provider/provider.dart';

import '../../data/controllers/region_controller.dart';
import '../../ui/ref_tokens.dart';
import '../../ui/ref_widgets.dart';
import 'region_picker.dart';

/// İLAN AKIŞI — ADIM 3: HİZMET ALAN KAYDI
///
/// ⚠ Bu adım AYRI EKRAN DEĞİLDİR. Referans akışta kayıt, ilan
/// oluşturma göstergesinin İÇİNDE yer alır:
///   1 Kategori Seç · 2 İlan Bilgileri · 3 Kayıt · 4 SMS Doğrulama
///
/// Doğrulama kuralları `Validators` ile AYNIDIR.
///
/// ⚠ BOŞ ALAN İÇİN UYARI GÖSTERİLMEZ: zorunluluk `*` ile bellidir.
/// Uyarı yalnız alan DOLU ama GEÇERSİZ olduğunda çıkar.
class IlanKayitAdimi extends StatefulWidget {
  const IlanKayitAdimi({super.key, required this.veri, required this.onDegisti});

  final KayitVerisi veri;

  /// Geçerlilik değiştiğinde üst ekran butonu tazeler.
  final VoidCallback onDegisti;

  @override
  State<IlanKayitAdimi> createState() => _IlanKayitAdimiState();
}

/// Kayıt formunun durumu — ekran yeniden çizilse de KORUNUR.
class KayitVerisi {
  final ad = TextEditingController();
  final soyad = TextEditingController();
  final eposta = TextEditingController();
  final telefon = TextEditingController();
  final sifre = TextEditingController();
  final sifre2 = TextEditingController();

  /// ⚠ İL SABİT DEĞİLDİR — kullanıcı seçer.
  /// Önceden ekranda doğrudan "İzmir" yazıyordu; seçim yapılmamış
  /// olmasına rağmen alan dolu görünüyordu.
  String? il;
  String? ilce;
  String? mahalle;
  bool sozlesme = false;

  /// ── SEÇİMDEN SONRA SIRADAKİ ALANA KAYDIRMA ──
  ///
  /// ⚠ İl/ilçe/mahalle satırları METİN ALANI DEĞİLDİR; `scrollPadding`
  /// onlarda çalışmaz. Seçim bitince sıradaki alan ekranın altında,
  /// klavye açıksa onun ardında kalıyordu. Kayıt ekranıyla AYNI çözüm.
  final ilKaydirKey = GlobalKey();
  final ilceKaydirKey = GlobalKey();
  final mahalleKaydirKey = GlobalKey();
  final sifreKaydirKey = GlobalKey();
  final sozlesmeKaydirKey = GlobalKey();

  /// Alan odaktan çıktı mı — uyarı yalnız o zaman gösterilir.
  final Set<String> dokunulan = {};

  void dispose() {
    ad.dispose();
    soyad.dispose();
    eposta.dispose();
    telefon.dispose();
    sifre.dispose();
    sifre2.dispose();
  }

  /// Alan geçerli mi? Boşluk da GEÇERSİZDİR (uyarısı gösterilmez).
  String? _hata(String id) => switch (id) {
        'ad' => Validators.name(ad.text, label: 'ad'),
        'soyad' => Validators.name(soyad.text, label: 'soyad'),
        'eposta' => Validators.email(eposta.text),
        'telefon' => Validators.phone(telefon.text),
        'il' => il == null ? 'Bu alan zorunludur' : null,
        'ilce' => ilce == null ? 'Bu alan zorunludur' : null,
        'mahalle' => mahalle == null ? 'Bu alan zorunludur' : null,
        'sifre' => Validators.password(sifre.text),
        // ⚠ TEKRAR ALANINDA DA TÜM ŞİFRE KURALLARI GEÇERLİDİR.
        // Eşleşme uyarısı ancak şifre kuralları sağlandıktan SONRA
        // görünür; yarım yazılmış şifrede "eşleşmiyor" denmez.
        'sifre2' => Validators.passwordRepeat(sifre2.text, sifre.text),
        _ => null,
      };

  /// ODAKTAKİ ALAN — uyarısı GİZLENİR.
  ///
  /// ⚠ Kullanıcı yazmayı sürdürürken uyarı gösterilmez; özellikle
  /// düzeltmeye başladığı ilk tuşta kırmızı görmemelidir. Uyarı
  /// alandan çıkınca belirir.
  String? odaktakiAlan;

  /// Ekranda gösterilecek uyarı — alan BOŞSA null döner.
  String? uyari(String id) {
    if (odaktakiAlan == id) {
      return null;
    }
    if (!dokunulan.contains(id)) {
      return null;
    }
    final bos = switch (id) {
      'ad' => ad.text.trim().isEmpty,
      'soyad' => soyad.text.trim().isEmpty,
      'eposta' => eposta.text.trim().isEmpty,
      'telefon' => telefon.text.trim().isEmpty,
      'il' => il == null,
      'ilce' => ilce == null,
      'mahalle' => mahalle == null,
      'sifre' => sifre.text.isEmpty,
      'sifre2' => sifre2.text.isEmpty,
      _ => true,
    };
    return bos ? null : _hata(id);
  }

  static const alanlar = [
    'ad', 'soyad', 'eposta', 'telefon',
    'il', 'ilce', 'mahalle',
    'sifre', 'sifre2',
  ];

  /// Tüm alanlar GEÇERLİ mi? (sözleşme hariç)
  bool get alanlarGecerli => alanlar.every((id) => _hata(id) == null);

  /// Kayıt tamamlanabilir mi?
  bool get tamam => alanlarGecerli && sozlesme;

  /// İlk geçersiz alan — butona basıldığında oraya odaklanılır.
  String? get ilkEksik =>
      alanlar.cast<String?>().firstWhere((id) => _hata(id!) != null,
          orElse: () => null);

  String get adSoyad => '${ad.text.trim()} ${soyad.text.trim()}';
}

class _IlanKayitAdimiState extends State<IlanKayitAdimi> {
  /// Verilen alanı görünür alana kaydırır — bkz. `KayitVerisi` notu.
  ///
  /// ⚠ Global bir sarmalayıcı değildir: yalnız kullanıcı bir seçimi
  /// bitirdiğinde açıkça çağrılır.
  Future<void> _gorunurYap(GlobalKey k) async {
    await WidgetsBinding.instance.endOfFrame;
    final c = k.currentContext;
    // ⚠ ÜÇ DENETİM.
    //
    // `endOfFrame` bir async gap'tir. `currentContext` null değilse
    // widget ağaçtadır, ama analyzer bunu çıkaramaz; `c.mounted`
    // açıkça yazılır. Maliyeti yok, niyeti belgeler.
    if (!mounted || c == null || !c.mounted) {
      return;
    }
    await Scrollable.ensureVisible(
      c,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.15,
    );
  }

  final _odak = <String, FocusNode>{};

  @override
  void initState() {
    super.initState();
    for (final c in [
      widget.veri.ad, widget.veri.soyad, widget.veri.eposta,
      widget.veri.telefon, widget.veri.sifre, widget.veri.sifre2,
    ]) {
      c.addListener(_degisti);
    }
    for (final id in KayitVerisi.alanlar) {
      _odak[id] = FocusNode()
        ..addListener(() {
          // Odaktan çıkınca uyarı görünür olur.
          if (!mounted) {
            return;
          }
          if (_odak[id]!.hasFocus) {
            // Odağa girildi: uyarı gizlensin, kayıt `dokunulan`
            // içinde KALIR — çıkınca yeniden görünür.
            setState(() => widget.veri.odaktakiAlan = id);
            return;
          }
          if (widget.veri.odaktakiAlan == id) {
            widget.veri.odaktakiAlan = null;
          }
          if (!_odak[id]!.hasFocus) {
            // ⚠ AD/SOYAD BİÇİMİ BURADA UYGULANIR.
            //
            // Yazarken biçimlendirmek silmeyi bozuyordu
            // (bkz. `ad_bicimi`); alandan çıkınca bir kez düzeltilir.
            if (id == 'ad') {
              adAlaniBicimle(widget.veri.ad);
            } else if (id == 'soyad') {
              adAlaniBicimle(widget.veri.soyad);
            }
            setState(() => widget.veri.dokunulan.add(id));
          }
        });
    }
  }

  @override
  void dispose() {
    for (final f in _odak.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _degisti() {
    setState(() {});
    widget.onDegisti();
  }

  /// Enter → bir alt YAZILABİLİR alana geç.
  ///
  /// ⚠ `KayitVerisi.alanlar` listesinde `ilce` ve `mahalle` de vardır,
  /// ama bunlar metin alanı değil AÇILIR LİSTEDİR; odak düğümleri
  /// hiçbir widget'a bağlı değildir. Bağlı olmayan bir düğüme
  /// `requestFocus()` çağırmak odağı hiçbir yere götürmez, yalnız
  /// mevcut alanın odağını düşürüp klavyeyi kapatırdı. Bu yüzden
  /// yalnız AĞACA BAĞLI düğümler hedef alınır (`context != null`).
  void _sonraki(String id) {
    final i = KayitVerisi.alanlar.indexOf(id);
    for (var k = i + 1; k < KayitVerisi.alanlar.length; k++) {
      final f = _odak[KayitVerisi.alanlar[k]];
      if (f != null && f.context != null) {
        f.requestFocus();
        return;
      }
    }
    // Zincirin sonu — klavyeyi kullanıcı adına kapatmak burada
    // BEKLENEN davranıştır (son alanda Enter).
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.veri;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Hizmet Alan Kaydı',
          textAlign: TextAlign.center,
          style: refText(size: RF.s18, weight: RF.w700, color: RC.text)),
      const SizedBox(height: 6),
      Text('Hizmet almak için hesabınızı oluşturun ve hemen başlayın.',
          textAlign: TextAlign.center,
          style: refText(
              size: RF.s13,
              weight: RF.w400,
              color: RC.textSoft,
              height: RF.lh145)),
      const SizedBox(height: 14),

      // ⚠ Baş harfler BÜYÜK — Türkçe duyarlı ("onur" → "Onur",
      // "irem" → "İrem"). Klavye ipucu tek başına yeterli değildir;
      // biçim alandan çıkınca uygulanır (bkz. `adAlaniBicimle`).
      _alan('ad', 'assets/svg/ic_person.svg', 'Ad', v.ad,
          adSoyad: true),
      _alan('soyad', 'assets/svg/ic_person.svg', 'Soyad', v.soyad,
          adSoyad: true),
      _alan('eposta', 'assets/svg/ic_mail.svg', 'E-posta', v.eposta,
          klavye: TextInputType.emailAddress),

      // Telefon — yalnız rakam, 11 hane, başa otomatik `0`.
      _alan('telefon', 'assets/svg/ic_phone.svg',
          // Yalnız örnek biçim — bkz. `register_screen` notu.
          'Telefon', v.telefon,
          klavye: TextInputType.number,
          // ⚠ TEK KURAL KAYNAĞI — bkz. `TelefonBicimlendirici`.
          bicim: const [TelefonBicimlendirici()],
          // ⚠ `+90` kutusu KALDIRILDI (bkz. `register_screen` notu).
          // İşlevsiz bir açılır kutuydu; numara `0` ile başlayan yerel
          // biçimde alınıyor.
          yerTutucu: '5XX XXX XX XX'),

      // ── İL / İLÇE / MAHALLE ──
      //
      // ⚠ KAYNAK SUNUCUDUR, KODA GÖMÜLÜ LİSTE DEĞİL.
      //
      // Önceden il doğrudan `kCity` ("İzmir") yazıyor ve tıklanamıyordu;
      // ilçeler `kIzmirDistricts`, mahalleler `neighborhoodsOf()`
      // sabitlerinden geliyordu. Admin yeni bir il/ilçe/mahalle
      // eklediğinde bu ekranda GÖRÜNMEZDİ. Üçü de artık
      // `RegionController` üzerinden okunur — kayıtlı kayıt ekranıyla
      // aynı kaynak.
      //
      // İl artık ZORUNLU SEÇİMDİR: alan boş açılır, `* İl` yazar,
      // tıklanınca o an aktif olan iller listelenir.
      KeyedSubtree(
        key: v.ilKaydirKey,
        child: _secim('il', 'assets/svg/ic_pin.svg', v.il, 'İl', () async {
        final r = context.read<RegionController>();
        final s = await _secici('İl Seçin', r.cityNames, v.il);
        if (s != null) {
          v.il = s;
          // İl değişti → alt zincir GEÇERSİZ.
          v.ilce = null;
          v.mahalle = null;
          v.dokunulan.add('il');
          _degisti();
          // Zincirin sıradaki halkası.
          await _gorunurYap(v.ilceKaydirKey);
        }
      }),
      ),
      KeyedSubtree(
        key: v.ilceKaydirKey,
        child: _secim(
          'ilce',
          'assets/svg/ic_pin.svg',
          v.ilce,
          'İlçe',
          // İl seçilmeden ilçe AÇILMAZ (kısıt metinle yazılmaz).
          v.il == null
              ? null
              : () async {
                  final r = context.read<RegionController>();
                  final s = await _secici(
                      'İlçe Seçin', r.districtsOf(v.il), v.ilce);
                  if (s != null) {
                    v.ilce = s;
                    v.mahalle = null; // zincir temizliği
                    v.dokunulan.add('ilce');
                    _degisti();
                    // Sıradaki zorunlu alan görünür olsun.
                    await _gorunurYap(v.mahalleKaydirKey);
                  }
                }),
      ),
      KeyedSubtree(
        key: v.mahalleKaydirKey,
        child: _secim(
          'mahalle',
          'assets/svg/ic_home2.svg',
          // ⚠ Kısıt METİNLE belirtilmez: ilçe seçilmeden mahalle
          // seçilemez ama alan yalnız 'Mahalle' yazar.
          v.mahalle,
          'Mahalle',
          v.ilce == null
              ? null
              : () async {
                  final r = context.read<RegionController>();
                  final s = await _secici('Mahalle Seçin',
                      r.neighborhoodsOf(v.ilce!, city: v.il), v.mahalle);
                  if (s != null) {
                    v.mahalle = s;
                    v.dokunulan.add('mahalle');
                    _degisti();
                    // Adres zinciri bitti; sırada şifre var.
                    await _gorunurYap(v.sifreKaydirKey);
                  }
                }),
      ),

      KeyedSubtree(
        key: v.sifreKaydirKey,
        child: _sifre('sifre', 'Şifreniz', v.sifre),
      ),
      _sifre('sifre2', 'Şifrenizi Tekrar Giriniz', v.sifre2),

      // ── SÖZLEŞME SATIRI ──
      //
      // ⚠ KAYITLI KAYIT EKRANIYLA BİREBİR AYNI.
      //
      // Önceden `RefCheckRow` kullanılıyordu: metin tek parça, düz
      // renk, farklı punto/kalınlık ve mavi yasal bağlantılar YOKTU.
      // Referans `.rg-agree` satırı `RefAgreeRow`'dur — yazı, font,
      // renk ve boyut oradan gelir; iki ekran arasında fark kalmaz.
      //
      // ⚠ KİLİT GERİ GELDİ (kullanıcı kararı, tüm kayıt ekranlarında).
      //
      // Zorunlu alanlar tamamlanmadan sözleşme İŞARETLENEMEZ. Satır
      // soluk çizilir, dokunma yok sayılır ve yasal bağlantılar da
      // açılmaz. Kayıtlı kayıt ekranıyla (`register_screen`) AYNI
      // davranış — iki ekran arasında fark yoktur.
      //
      // İlerleme koşulu `tamam` (alanlarGecerli && sozlesme) zaten
      // yerinde; bu kilit onun ÖNÜNE eklenen ikinci savunmadır.
      RefAgreeRow(
        key: v.sozlesmeKaydirKey,
        enabled: v.alanlarGecerli,
        value: v.sozlesme,
        onChanged: (x) {
          v.sozlesme = x;
          _degisti();
        },
        parts: [
          (
            text: 'Kullanım sözleşmesi',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'slug': 'terms',
              'title': 'Kullanım Koşulları',
            }),
          ),
          (text: ' ve ', onTap: null),
          (
            text: 'gizlilik politikasını',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'slug': 'privacy',
              'title': 'Gizlilik Politikası',
            }),
          ),
          (text: ' okudum, kabul ediyorum.', onTap: null),
        ],
      ),
    ]);
  }

  /// Hatalı alan için ince kırmızı kılıf.
  /// ⚠ YALNIZ AÇILIR LİSTELER İÇİN.
  ///
  /// Metin alanlarında KULLANILMAZ: koşullu sarmalayıcı ağacın
  /// şeklini değiştirip alanı yeniden kurar ve odak düşer
  /// (bkz. `RefFormField.hatali`). Açılır listede odaklanılacak bir
  /// metin girişi olmadığı için burada güvenlidir.
  Widget _cerceve({required bool hatali, required Widget child}) => hatali
      ? Container(
          decoration: BoxDecoration(
            border: Border.all(color: RC.danger, width: 1.4),
            borderRadius: BorderRadius.circular(RR.r13),
          ),
          child: child,
        )
      : child;

  /// Bölge seçici sayfası.
  Future<String?> _secici(
          String baslik, List<String> secenekler, String? secili) =>
      // ⚠ `Colors.transparent` zemin sheet'in ARKASINI ŞEFFAF
      // bırakıyor ve altındaki form okunur hâlde görünüyordu.
      // Kayıt/adres ekranlarındaki çalışan çağrıyla AYNI:
      // beyaz zemin + üstte yuvarlatılmış köşe.
      showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => RegionPickerSheet(
          title: baslik,
          options: secenekler,
          selected: secili,
          searchable: true,
        ),
      );

  /// Form alanı.
  ///
  /// ⚠ `ipucu` ALAN ADIDIR ve kutunun ÜSTÜNDE etiket olarak çizilir.
  /// Biçim örneği ("5XX XXX XX XX") ayrı `yerTutucu` ile verilir —
  /// aksi hâlde başlıkta "5XX XXX XX XX" yazıyordu.
  Widget _alan(String id, String ikon, String ipucu,
      TextEditingController ctl,
      {TextInputType? klavye,
      List<TextInputFormatter>? bicim,
      bool adSoyad = false,
      String? yerTutucu,
      Widget? sonEk}) {
    final u = widget.veri.uyari(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ⚠ SARMALAYICI YOK — İKİSİ DE ODAĞI DÜŞÜRÜYORDU.
        //
        // 1) `Focus(focusNode: ...)`: düğüm alanın DEĞİL sarmalayıcının
        //    olduğu için `requestFocus()` odağı sarmalayıcıya veriyor,
        //    metin bağlantısı kopuyor ve Enter'da klavye kapanıyordu.
        // 2) Koşullu `_cerceve` `Container`'ı: `hatali` değişince ağacın
        //    şekli değişip alan yeniden kuruluyor, YAZARKEN odak
        //    düşüyordu. Kırmızı kenarlık artık alanın kendi kutusunda.
        RefFormField(
          focusNode: _odak[id],
          hatali: u != null,
          iconAsset: ikon,
          controller: ctl,
          hint: ipucu,
          yerTutucu: yerTutucu,
          keyboardType: klavye,
          inputFormatters: bicim,
          textCapitalization:
              adSoyad ? TextCapitalization.words : TextCapitalization.none,
          suffix: sonEk,
          textInputAction: TextInputAction.next,
          // ⚠ Varsayılan `next` yolu önce `unfocus()` çağırıp klavyeyi
          // kapatıyordu; `onEditingComplete` ile odak doğrudan geçer.
          onEditingComplete: () => _sonraki(id),
        ),
        if (u != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(u,
                style: refText(
                    size: RF.s125, weight: RF.w600, color: RC.danger)),
          ),
      ]),
    );
  }

  Widget _sifre(String id, String ipucu, TextEditingController ctl) {
    final u = widget.veri.uyari(id);
    final acik = widget.veri.dokunulan.contains('goz_$id');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ⚠ SARMALAYICI YOK — gerekçe `_alan()` içindeki nota bakınız.
        RefFormField(
          focusNode: _odak[id],
          hatali: u != null,
          iconAsset: 'assets/svg/ic_lock.svg',
          controller: ctl,
          // ⚠ ŞİFRE ALANINDA YER TUTUCU YOKTUR: biçim örneği
          // gösterilecek bir şey yok, ad etikete çıkıyor. `_alan`'a
          // eklenen `yerTutucu` yanlışlıkla buraya da yazılmıştı ve
          // `_sifre` böyle bir parametre almadığı için derleme
          // kırılıyordu.
          hint: ipucu,
          obscureText: !acik,
          // ⚠ Ara alanlar `next`, ZİNCİRİN SON ALANI `done`
          // (uygulamanın klavye standardı — `register_screen` ile aynı).
          textInputAction: id == KayitVerisi.alanlar.last
              ? TextInputAction.done
              : TextInputAction.next,
          // ⚠ Varsayılan `next` yolu önce `unfocus()` çağırıp klavyeyi
          // kapatıyordu; `onEditingComplete` ile odak doğrudan geçer.
          onEditingComplete: () => _sonraki(id),
          // ⚠ Her alanın maskesi BAĞIMSIZ ve göz BASILI TUTULDUĞU
          // SÜRECE gösterir — diğer ekranlarla aynı davranış
          // (bkz. `RefSifreGozu`).
          suffix: RefSifreGozu(
            gizli: !acik,
            onDegisti: (gizle) => setState(() {
              gizle
                  ? widget.veri.dokunulan.remove('goz_$id')
                  : widget.veri.dokunulan.add('goz_$id');
            }),
          ),
        ),
        if (u != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(u,
                style: refText(
                    size: RF.s125, weight: RF.w600, color: RC.danger)),
          ),
      ]),
    );
  }

  /// Açılır seçim satırı.
  ///
  /// ⚠ [secili] ile [placeholder] AYRIDIR. Önceden tek bir `deger`
  /// geçiliyor ve `id == 'il'` özel durumu ile il HER ZAMAN "seçilmiş"
  /// gibi (koyu metin) çiziliyordu. Artık seçim yoksa alan gri
  /// placeholder gösterir — zorunluluk `*` ile bellidir.
  Widget _secim(String id, String ikon, String? secili, String placeholder,
      VoidCallback? onTap) {
    final u = widget.veri.uyari(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cerceve(
          hatali: u != null,
          child: RefDropdownField(
            value: secili,
            placeholder: placeholder,
            onTap: onTap,
          ),
        ),
        if (u != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(u,
                style: refText(
                    size: RF.s125, weight: RF.w600, color: RC.danger)),
          ),
      ]),
    );
  }
}
