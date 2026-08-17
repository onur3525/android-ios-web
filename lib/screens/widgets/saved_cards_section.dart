import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/kart_kurallari.dart';
import '../../core/sys_state.dart';
import '../../core/theme.dart';
import '../../data/controllers/saved_cards_controller.dart';
import '../../data/services/card_tokenization_bridge.dart';
import 'hc_widgets.dart';
import '../../ui/ref_widgets.dart';
import '../../ui/ref_tokens.dart';

/// ═══════════════════════════════════════════════════════════════
/// ÖDEME YÖNTEMİ — referans mobil HTML (vTopup) ile birebir
///
/// Görünüm ve akış referanstakiyle aynıdır:
///   · Kayıtlı kart satırları (yıldız · marka · maskeli numara · sil)
///   · Yıldız butonuyla varsayılan kart değiştirme
///   · "Yeni Kart Ekle" başlığı ekran içinde açılıp kapanır
///   · Kart Sahibinin Adı Soyadı · Kart Numarası · Son Kullanma · CVV
///   · "Bu kartı varsayılan kart olarak kaydet" onay kutusu
///   · "Kartı Kaydet" butonu
///
/// ⚠ GÜVENLİK — HAM KART VERİSİ SUNUCUYA GİTMEZ
/// Alanlar referanstaki gibi görünür, ancak girilen değerler
/// HizmetCep sunucusuna GÖNDERİLMEZ ve veritabanına YAZILMAZ.
/// Ödeme sağlayıcısının SDK'sı (hosted-fields) değerleri doğrudan
/// sağlayıcıya iletir ve tek kullanımlık `paymentToken` üretir;
/// sunucuya yalnız o token gider (`POST /wallet/cards`).
///
/// Sağlayıcı yapılandırılmamışsa (`mode = unavailable`) form
/// gönderilemez ve kullanıcıya gerekçesi açıkça gösterilir —
/// sahte kart kaydı ÜRETİLMEZ.
/// ═══════════════════════════════════════════════════════════════
class SavedCardsSection extends StatefulWidget {
  const SavedCardsSection({super.key, this.tokenizer});

  /// Kart tokenizasyon köprüsü.
  ///
  /// Normalde `null` bırakılır ve `context.read<CardTokenizer>()`
  /// üzerinden uygulamanın DI kaydından okunur. Testlerde sahte
  /// uygulama enjekte etmek için doğrudan verilebilir.
  final CardTokenizer? tokenizer;

  @override
  State<SavedCardsSection> createState() => _SavedCardsSectionState();
}

class _SavedCardsSectionState extends State<SavedCardsSection> {
  /// Referans HTML: `NEWCARD_OPEN`
  bool _yeniKartAcik = false;

  final _ad = TextEditingController();
  final _numara = TextEditingController();
  final _sonKullanma = TextEditingController();
  final _cvv = TextEditingController();

  // ⚠ ENTER/İLERİ TUŞU BİR SONRAKİ ALANA GEÇER.
  //
  // Bu formda `textInputAction` hiç verilmiyordu; tek satırlık
  // alanlarda varsayılan `done`dur, yani Enter klavyeyi kapatıyor ve
  // kullanıcı her alanı ELLE seçmek zorunda kalıyordu.
  //
  // Sıra görsel sırayla AYNI: Ad Soyad → Kart Numarası → Son Kullanma
  // → CVV. Son alanda `done`: klavye kapanır, form kendiliğinden
  // GÖNDERİLMEZ (kaydetme düğmesi ayrı kuralla çalışır).
  final _fAd = FocusNode();
  final _fNumara = FocusNode();
  final _fSonKullanma = FocusNode();
  final _fCvv = FocusNode();
  bool _varsayilanYap = true;
  String? _formHatasi;

  /// Kart numarasının YALNIZ rakamları.
  String get _haneler => _numara.text.replaceAll(RegExp(r'\D'), '');

  /// ── "KARTI KAYDET" NE ZAMAN AKTİF? ──
  ///
  /// DÖRT ALANIN DÖRDÜ DE geçerli olduğunda. Eksik ya da hatalı tek
  /// alan varsa düğme PASİFTİR; kullanıcı sağlayıcıdan hata almadan
  /// önce uyarılmış olur.
  ///
  /// Kurallar `lib/core/kart_kurallari.dart` dosyasındadır ve kredi
  /// kartı · banka kartı · sanal kart için AYNIDIR.
  bool get _formGecerli =>
      kartAdiGecerli(_ad.text) &&
      kartNumarasiGecerli(_haneler) &&
      kartSonKullanmaGecerli(_sonKullanma.text) &&
      kartCvvGecerli(_cvv.text, _haneler);

  @override
  void initState() {
    super.initState();
    // ⚠ Her tuşta düğmenin durumu yeniden hesaplanmalı; aksi hâlde
    // form dolduğu hâlde "Kartı Kaydet" pasif kalır.
    for (final c in [_ad, _numara, _sonKullanma, _cvv]) {
      c.addListener(_alanDegisti);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SavedCardsController>().load();
      }
    });
  }

  void _alanDegisti() {
    if (mounted) {
      setState(() => _formHatasi = null);
    }
  }

  @override
  void dispose() {
    for (final c in [_ad, _numara, _sonKullanma, _cvv]) {
      c.removeListener(_alanDegisti);
      c.dispose();
    }
    // Odak düğümleri de bırakılır — sızıntı olmaz.
    for (final f in [_fAd, _fNumara, _fSonKullanma, _fCvv]) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = context.watch<SavedCardsController>();

    if (ctl.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Kayıtlı kart listesi ──
      ...ctl.cards.map((k) => _kartSatiri(context, ctl, k)),

      // ── Yeni Kart Ekle (açılır/kapanır) ──
      Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          border: Border.all(color: HC.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          InkWell(
            onTap: () => setState(() => _yeniKartAcik = !_yeniKartAcik),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Container(
                  width: 24, height: 24, alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: HC.softBlue, borderRadius: BorderRadius.circular(7)),
                  child: const Text('+',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: HC.blue)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Yeni Kart Ekle',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: HC.dark)),
                ),
                RefSvg(
                    _yeniKartAcik
                        ? 'assets/svg/ic_chev.svg'
                        : 'assets/svg/ic_chevd.svg',
                    size: 20,
                    color: RC.textSoft),
              ]),
            ),
          ),
          if (_yeniKartAcik) _kartFormu(context, ctl),
        ]),
      ),
    ]);
  }

  /// Referans HTML `.tp-card`: yıldız · marka · varsayılan · numara · sil
  Widget _kartSatiri(
      BuildContext context, SavedCardsController ctl, SavedCard k) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: k.isDefault ? HC.blue : HC.border,
            width: k.isDefault ? 1.4 : 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        // Yıldız — varsayılan kartı değiştirir
        IconButton(
          tooltip: 'Varsayılan kart yap',
          visualDensity: VisualDensity.compact,
          icon: RefSvg(
              k.isDefault
                  ? 'assets/svg/ic_starfill.svg'
                  : 'assets/svg/ic_starempty.svg',
              size: 22,
              color: k.isDefault ? RC.blue : RC.greyLight),
          onPressed: (ctl.busy || k.isDefault)
              ? null
              : () => _varsayilanYapIslemi(context, k.token),
        ),
        RefSvg('assets/svg/ic_visa.svg', size: 26, color: RC.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(k.brand,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: HC.dark)),
                if (k.isDefault) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: HC.softBlue,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Varsayılan Kart',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: HC.blue)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              // ⚠ Yalnız maskeli gösterim
              Text(k.masked,
                  style: const TextStyle(
                      fontSize: 12.5, color: HC.grey, letterSpacing: 1.1)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Kartı sil',
          visualDensity: VisualDensity.compact,
          icon: RefSvg('assets/svg/ic_trash.svg', size: 19, color: RC.greyLight),
          onPressed: ctl.busy ? null : () => _silIslemi(context, k.token),
        ),
      ]),
    );
  }

  /// Referans HTML `.tp-form` — alan sırası ve etiketleri birebir.
  Widget _kartFormu(BuildContext context, SavedCardsController ctl) {
    // ── ⚠ ALANLAR HER ZAMAN AÇIKTIR ──
    //
    // Eskiden dört alan da, onay kutusu da sağlayıcı bağlı değilse
    // `enabled:false` idi: kullanıcı hiçbir şey yazamıyordu. Bilgi
    // GİRMEK sağlayıcı gerektirmez — yalnız GÖNDERMEK gerektirir.
    //
    // Sağlayıcı bağlı değilse kayıt gene de yapılamaz; bu, düğmeye
    // basıldığında AÇIK HATA ile bildirilir (`_saglayiciTokenIste`).
    // Sahte başarı ÜRETİLMEZ.
    final tokenizer = widget.tokenizer ?? context.read<CardTokenizer>();
    final saglayiciHazir =
        ctl.entryMode != 'unavailable' && tokenizer.isConfigured;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1, color: HC.border),
        const SizedBox(height: 12),

        const Text('Kart Sahibinin Adı Soyadı',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: HC.dark)),
        const SizedBox(height: 5),
        TextField(
          // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
          // kaydırılır — bkz. `kAlanKaydirmaPayi`.
          scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
          controller: _ad,
          focusNode: _fAd,
          textInputAction: TextInputAction.next,
          onEditingComplete: _fNumara.requestFocus,
          textCapitalization: TextCapitalization.words,
          // ⚠ Kart üzerindeki ad RAKAM İÇERMEZ — rakam ve noktalama
          // baştan engellenir, sağlayıcıya hatalı ad gitmez.
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r"[A-Za-zÇĞİıÖŞÜçğöşü' ]")),
            LengthLimitingTextInputFormatter(40),
          ],
          decoration: const InputDecoration(hintText: 'Ad Soyad'),
        ),
        const SizedBox(height: 11),

        const Text('Kart Numarası',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: HC.dark)),
        const SizedBox(height: 5),
        TextField(
          // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
          // kaydırılır — bkz. `kAlanKaydirmaPayi`.
          scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
          controller: _numara,
          focusNode: _fNumara,
          // ── ⚠ PANO KAPALI ──
          //
          // Kart numarası kopyalanabiliyordu: panoya alınan numarayı
          // cihazdaki BAŞKA UYGULAMALAR okuyabilir. Seçim ve
          // kopyala/yapıştır menüsü bu alanda kapalıdır.
          enableInteractiveSelection: false,
          contextMenuBuilder: null,
          textInputAction: TextInputAction.next,
          onEditingComplete: _fSonKullanma.requestFocus,
          keyboardType: TextInputType.number,
          // ⚠ HANE SINIRI KART AİLESİNE GÖRE DARALIR.
          //
          // Sabit 16 yanlıştı: Amex 15, Diners 14 hanedir — o kartlarda
          // fazladan hane girilebiliyordu. Sınırlayıcı artık ilk
          // hanelerden aileyi bulup fazlasını KABUL ETMEZ.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _KartNumarasiFormatlayici(),
          ],
          decoration: const InputDecoration(hintText: '0000 0000 0000 0000'),
        ),
        const SizedBox(height: 11),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Son Kullanma Tarihi',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: HC.dark)),
              const SizedBox(height: 5),
              TextField(
                // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                controller: _sonKullanma,
                focusNode: _fSonKullanma,
                textInputAction: TextInputAction.next,
                onEditingComplete: _fCvv.requestFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  _SonKullanmaFormatlayici(),
                ],
                decoration: const InputDecoration(hintText: 'AA/YY'),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CVV',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: HC.dark)),
              const SizedBox(height: 5),
              TextField(
                // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                controller: _cvv,
                // ⚠ CVV panoya ALINAMAZ; kart numarasıyla birlikte
                // kopyalanması doğrudan kart bilgisi sızıntısıdır.
                enableInteractiveSelection: false,
                contextMenuBuilder: null,
                focusNode: _fCvv,
                // Son alan: klavye kapanır, form gönderilmez.
                textInputAction: TextInputAction.done,
                obscureText: true,
                keyboardType: TextInputType.number,
                // ⚠ Amex'te 4, diğerlerinde 3 hanedir; sınır kart
                // numarasından türetilir, fazlası yazılamaz.
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(kartCvvUzunlugu(_haneler)),
                ],
                decoration: InputDecoration(
                    hintText: kartCvvUzunlugu(_haneler) == 4 ? '1234' : '123'),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 6),

        CheckboxListTile(
          // ⚠ Sağlayıcıdan BAĞIMSIZ: tercih yerel bir seçimdir.
          value: _varsayilanYap,
          onChanged: (v) => setState(() => _varsayilanYap = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          title: const Text('Bu kartı varsayılan kart olarak kaydet',
              style: TextStyle(fontSize: 13, color: HC.dark)),
        ),

        if (_formHatasi != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(_formHatasi!,
                style: const TextStyle(fontSize: 12.5, color: HC.red)),
          ),

        if (!saglayiciHazir)
          InfoBox(
            child: Text(
                ctl.entryMode == 'unavailable'
                    ? 'Kart kaydı için ödeme sağlayıcısı yapılandırılmalıdır. '
                      'Yapılandırma tamamlanana kadar kart kaydedilemez.'
                    : 'Ödeme sağlayıcısı SDK entegrasyonu tamamlanmadı. '
                      'Kart kaydı şu anda yapılamıyor.'),
          ),

        const SizedBox(height: 8),
        // ⚠ DÜĞME YALNIZ FORM TAMAMSA AKTİF.
        //
        // Koşul artık sağlayıcı durumu DEĞİL, alanların geçerliliğidir:
        // eksik/hatalı bilgiyle basılamaz. Sağlayıcı bağlı değilse
        // basıldığında gerekçeli hata gösterilir.
        SysButton('Kartı Kaydet',
            busy: ctl.busy,
            onPressed:
                _formGecerli ? () => _kartiKaydet(context, ctl) : null),

        const SizedBox(height: 8),
        const InfoBox(
          child: Text(
              'Kart bilgileriniz ödeme kuruluşunun güvenli altyapısına '
              'doğrudan iletilir. Kart numarası ve CVV HizmetCep '
              'sunucularına gönderilmez ve saklanmaz.'),
        ),
      ]),
    );
  }

  Future<void> _kartiKaydet(
      BuildContext context, SavedCardsController ctl) async {
    setState(() => _formHatasi = null);

    // ── Yerel doğrulama — `lib/core/kart_kurallari.dart` ──
    //
    // ⚠ Düğme zaten `_formGecerli` ile korunuyor; bu blok İKİNCİ
    // savunmadır (programla çağrı, test, ileride başka tetikleyici).
    // Mesajlar hangi alanın hatalı olduğunu SÖYLER.
    final numara = _haneler;
    if (!kartAdiGecerli(_ad.text)) {
      setState(() => _formHatasi =
          'Kart sahibinin adı soyadı en az iki kelime olmalı ve '
          'rakam içermemelidir.');
      return;
    }
    if (!kartNumarasiGecerli(numara)) {
      setState(() => _formHatasi =
          'Kart numarası ${kartHaneSayisi(numara)} haneli ve geçerli '
          'olmalıdır.');
      return;
    }
    if (!kartSonKullanmaGecerli(_sonKullanma.text)) {
      setState(() => _formHatasi =
          'Son kullanma tarihi AA/YY biçiminde ve geçmiş olmamalıdır.');
      return;
    }
    if (!kartCvvGecerli(_cvv.text, numara)) {
      setState(() => _formHatasi =
          'Güvenlik kodu ${kartCvvUzunlugu(numara)} haneli olmalıdır.');
      return;
    }

    // ══════════════════════════════════════════════════════════════
    // TOKENİZASYON
    //
    // Kart verisi buradan İTİBAREN sağlayıcının SDK'sına devredilir.
    // Aşağıdaki çağrı, yapılandırılmış sağlayıcının hosted-fields
    // SDK'sını çalıştırır ve tek kullanımlık `paymentToken` alır.
    // HAM KART VERİSİ HizmetCep sunucusuna GÖNDERİLMEZ.
    //
    // Sağlayıcı seçilmediği için SDK köprüsü henüz bağlanmamıştır;
    // bu durumda işlem AÇIK HATA ile durur — sahte başarı ÜRETİLMEZ.
    // ══════════════════════════════════════════════════════════════
    final CardTokenResult token;
    try {
      token = await _saglayiciTokenIste(ctl);
    } on CardTokenizationException catch (e) {
      if (!context.mounted) {
        return;
      }
      setState(() => _formHatasi = e.message);
      return;
    }
    if (!context.mounted) {
      return;
    }

    final hata = await ctl.saveCard(
      paymentToken: token.paymentToken,
      holderName: _ad.text.trim(),
      makeDefault: _varsayilanYap,
    );
    if (!context.mounted) {
      return;
    }
    if (hata != null) {
      setState(() => _formHatasi = hata);
      return;
    }
    // Başarılı: form temizlenir ve bölüm kapanır.
    _ad.clear(); _numara.clear(); _sonKullanma.clear(); _cvv.clear();
    setState(() { _yeniKartAcik = false; _varsayilanYap = true; });
    sysToastOk(context, 'Kart kaydedildi');
  }

  /// Sağlayıcı SDK'sından tek kullanımlık kart tokenı ister.
  ///
  /// ⚠ Kart verisi bu noktada sağlayıcıya devredilir; HizmetCep
  /// sunucusuna GÖNDERİLMEZ.
  ///
  /// Sağlayıcı yapılandırılmamışsa `CardTokenizationException`
  /// fırlatılır — çağıran gerekçeyi kullanıcıya gösterir.
  /// Sessiz `null` veya sahte token YOKTUR.
  Future<CardTokenResult> _saglayiciTokenIste(SavedCardsController ctl) async {
    if (ctl.entryMode != 'hosted_fields' || ctl.entryConfig == null) {
      throw const CardTokenizationException(
        'PROVIDER_NOT_CONFIGURED',
        'Ödeme sağlayıcısı yapılandırılmadığı için kart kaydedilemiyor.',
      );
    }
    // Tokenizer DI'dan okunur; ekran hangi uygulamanın bağlı
    // olduğunu BİLMEZ. Sağlayıcı SDK'sı eklendiğinde burası DEĞİŞMEZ.
    final tokenizer = widget.tokenizer ?? context.read<CardTokenizer>();
    if (!tokenizer.isConfigured) {
      throw const CardTokenizationException(
        'PROVIDER_NOT_CONFIGURED',
        'Ödeme sağlayıcısı SDK entegrasyonu tamamlanmadı. '
        'Kart kaydı şu anda yapılamıyor.',
      );
    }

    final ay = _sonKullanma.text.split('/').first;
    final yil = _sonKullanma.text.split('/').last;
    return tokenizer.tokenize(
      providerConfig: ctl.entryConfig!,
      holderName: _ad.text.trim(),
      number: _numara.text.replaceAll(RegExp(r'\D'), ''),
      expMonth: ay,
      expYear: yil,
      cvv: _cvv.text,
    );
  }

  Future<void> _varsayilanYapIslemi(BuildContext context, String token) async {
    final hata = await context.read<SavedCardsController>().setDefault(token);
    if (!context.mounted) {
      return;
    }
    if (hata != null) {
      sysToastErr(context, SysKind.genericError, extra: hata);
    }
  }

  Future<void> _silIslemi(BuildContext context, String token) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kartı sil'),
        content: const Text('Bu kayıtlı kart silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true || !context.mounted) {
      return;
    }
    final hata = await context.read<SavedCardsController>().remove(token);
    if (!context.mounted) {
      return;
    }
    if (hata != null) {
      sysToastErr(context, SysKind.genericError, extra: hata);
    }
  }

  // ⚠ Yerel `_luhn` KALDIRILDI — kural artık tek merkezde:
  // `lib/core/kart_kurallari.dart` (`kartLuhn`). İki kopya olması,
  // birinin güncellenip diğerinin unutulması riskiydi.
}

/// Kart numarası biçimlendirmesi (referans `ncNumFmt`).
///
/// ⚠ İKİ İŞ YAPAR:
///   1. Hane sayısını KART AİLESİNE göre sınırlar — fazladan rakam
///      yazılamaz (Amex 15, Diners 14, diğerleri 16).
///   2. Okunaklı gruplara ayırır (Amex `4-6-5`, diğerleri `4-4-4-4`).
class _KartNumarasiFormatlayici extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue eski, TextEditingValue yeni) {
    var rakam = yeni.text.replaceAll(RegExp(r'\D'), '');
    final sinir = kartHaneSayisi(rakam);
    if (rakam.length > sinir) {
      // ⚠ FAZLASI ATILIR, eski değere dönülmez: kullanıcı yapıştırma
      // yaptığında ilk `sinir` hane korunur.
      rakam = rakam.substring(0, sinir);
    }
    final metin = kartNumarasiBicimle(rakam);
    // ⚠ İMLEÇ KORUNUR — sona zorlanmaz.
    //
    // Eski hâl her düzenlemede imleci sona atıyordu; kullanıcı
    // ortadan veya baştan bir hane silemiyor, imleç kaçtığı için
    // tuşlar takılıyordu (aynı hata telefon alanında da vardı).
    return TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(
          offset: _imlecKonumu(yeni, metin)),
    );
  }
}

/// Biçimlendirme sonrası imleç konumu.
///
/// Kullanıcının imleçten ÖNCE bıraktığı RAKAM sayısı korunur; boşluk
/// ve `/` gibi eklenen ayraçlar hesaba katılarak yeni konum bulunur.
/// Böylece metin yeniden dizilse de imleç aynı rakamın ardında kalır.
int _imlecKonumu(TextEditingValue yeni, String bicimli) {
  final kesim = yeni.selection.baseOffset.clamp(0, yeni.text.length);
  final oncekiRakam =
      yeni.text.substring(0, kesim).replaceAll(RegExp(r'\D'), '').length;
  if (oncekiRakam == 0) {
    return 0;
  }
  var sayac = 0;
  for (var i = 0; i < bicimli.length; i++) {
    if (RegExp(r'\d').hasMatch(bicimli[i])) {
      sayac++;
      if (sayac == oncekiRakam) {
        return i + 1;
      }
    }
  }
  return bicimli.length;
}

/// `AA/YY` biçimlendirmesi (referans `ncExpFmt`).
///
/// ⚠ AY DÜZELTMESİ: kullanıcı ilk hane olarak 2–9 yazarsa bu bir ay
/// olamaz (20. ay yoktur); başına 0 eklenir — "9" → "09/". Böylece
/// geçersiz ay hiç oluşmaz.
class _SonKullanmaFormatlayici extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue eski, TextEditingValue yeni) {
    var rakam = yeni.text.replaceAll(RegExp(r'\D'), '');
    if (rakam.isNotEmpty) {
      final ilk = int.tryParse(rakam[0]) ?? 0;
      if (ilk > 1) {
        rakam = '0$rakam';
      }
    }
    if (rakam.length > 4) {
      rakam = rakam.substring(0, 4);
    }
    final metin = rakam.length <= 2
        ? rakam
        : '${rakam.substring(0, 2)}/${rakam.substring(2)}';
    // İmleç korunur — bkz. `_imlecKonumu`.
    return TextEditingValue(
      text: metin,
      selection:
          TextSelection.collapsed(offset: _imlecKonumu(yeni, metin)),
    );
  }
}
