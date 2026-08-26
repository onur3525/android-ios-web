import 'dart:async';
import '../core/cihaz_butunlugu.dart';
import '../core/ekran_korumasi.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/deep_links.dart';
// ⚠ `DomainError` ve `hataBilgisi` — hata türünü saklayıp merkezden
// mesaj almak için.
import '../domain/failures.dart';
import '../domain/hata_mesajlari.dart';
import '../core/sys_state.dart';
import '../core/theme.dart';
import '../data/controllers/saved_cards_controller.dart';
import '../data/controllers/wallet_controller.dart';
import '../data/models/payment.dart';
import '../domain/config.dart';
import 'widgets/saved_cards_section.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../core/geri.dart';

/// Hizmet veren — BAKİYE YÜKLEME (sağlayıcıdan bağımsız ödeme akışı)
///
/// Referans mobil HTML `vTopup` ile birebir: serbest tutar girişi,
/// minimum tutar kuralı, kayıtlı kart listesi, varsayılan kart yıldızı,
/// ekran içinde açılan "Yeni Kart Ekle" formu ve "Bakiye Yükle" butonu.
///
/// ── GÜVENLİK: KART VERİSİ NEREDE İŞLENİR ──
///
/// Kart alanları (numara, son kullanma, CVV) bu ekranda GÖRÜNÜR —
/// referans tasarım böyledir. Ancak girilen değerler HizmetCep
/// sunucusuna GÖNDERİLMEZ ve veritabanına YAZILMAZ:
///
///   · `hosted_fields`: alanlar sağlayıcı SDK'sınca yönetilir; veri
///     doğrudan sağlayıcıya gider, tek kullanımlık `paymentToken` döner.
///     Sunucuya yalnız o token iletilir (`POST /wallet/cards`).
///   · `redirect`: kart, sağlayıcının barındırdığı sayfada girilir.
///   · `unavailable`: kart kaydı YAPILAMAZ; form açık hata verir.
///
/// Sağlayıcı seçilene kadar SDK köprüsü bağlanmamıştır ve kart kaydı
/// ÇALIŞMAZ — kullanıcıya açıkça bildirilir, sahte başarı ÜRETİLMEZ.
///
/// Akış:
///   1) Tutar seç → backend'de ödeme oturumu aç (createTopupSession)
///   2) Sağlayıcının ödeme sayfasını harici tarayıcıda aç
///   3) Kullanıcı döndüğünde sonucu BACKEND'den doğrula (confirmTopup)
///   4) Yalnız sunucu SUCCEEDED derse bakiye artmış sayılır
///
/// Redirect parametresine GÜVENİLMEZ: "başarılı" yazan bir dönüş adresi
/// tek başına ödeme kanıtı değildir; durum her zaman sunucudan okunur.
class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key});
  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

/// Ekranın akış aşaması.
enum _Stage { amount, awaitingProvider, verifying, result }

// ── ⚠ EKRAN KORUMASI AÇIK ──
//
// Bu ekranda kart bilgisi ve tutar görünür. Koruma açıkken ekran görüntüsü
// alınamaz ve son uygulamalar listesinde önizleme çizilmez.
class _TopupScreenState extends State<TopupScreen>
    with WidgetsBindingObserver, EkranKorumaliState<TopupScreen> {
  _Stage _stage = _Stage.amount;
  String? _error;

  /// ── ⚠ HATANIN TÜRÜ DE SAKLANIR ──
  ///
  /// Yalnız metin saklanınca kart reddi ile sunucu arızası aynı
  /// cümleye düşüyordu. Tür saklanınca `hataBilgisi` doğru başlığı
  /// verir: kart bakiyesi yetersizse "Kart bakiyeniz yetersiz",
  /// sunucu yanıt vermiyorsa "Sunucuya ulaşılamıyor".
  DomainError? _hata;
  PaymentStatus? _result;

  /// Sağlayıcı sayfasından dönüldüğünde tek sefer doğrulama yapmak için.
  bool _verifyScheduled = false;

  StreamSubscription<Uri>? _linkSub;

  /// ⚠ Riskli ortam bilgisi — engelleme DEĞİL, bilgilendirme.
  CihazDurumu? _cihaz;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ── ⚠ RİSKLİ ORTAM OKUMASI ──
    //
    // Root'lu cihazda veya yeniden paketlenmiş kopyada güvenli
    // depodaki oturum anahtarı okunabilir; kullanıcı en azından
    // BİLMELİ. İşlem ENGELLENMEZ: yanlış pozitif dürüst kullanıcıyı
    // para yükleyemez hâle getirir.
    CihazButunlugu.durum().then((d) {
      if (mounted) {
        setState(() => _cihaz = d);
      }
    });

    // PAKETLER: tek otorite backend. Açılışta yüklenir; controller
    // taze önbellek varsa gereksiz ağ çağrısı YAPMAZ.
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });

    // DERİN BAĞLANTI: uygulama AÇIK veya ARKA PLANDAYKEN gelen ödeme dönüşü.
    // (Uygulama KAPALIYKEN gelen bağlantı main.dart'ta ele alınır.)
    _linkSub = DeepLinks.instance.stream.listen((uri) {
      if (!isPaymentReturn(uri)) {
        return;
      }
      // Callback'teki "başarılı" bilgisine GÜVENİLMEZ; yalnız doğrulamayı
      // tetikler. Sonuç backend'den okunur.
      if (!_verifyScheduled) {
        _verifyScheduled = true;
        _verify();
      }
    });
  }

  @override
  void dispose() {
    _tutar.dispose();
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama ÖN PLANA döndüğünde (sağlayıcı sayfası kapandı) sonucu
  /// sunucudan doğrula. Derin bağlantı gelmese bile bu yol çalışır.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _stage == _Stage.awaitingProvider &&
        !_verifyScheduled) {
      _verifyScheduled = true;
      // Kısa gecikme: sağlayıcı yönlendirmesi tamamlansın.
      Future<void>.delayed(const Duration(milliseconds: 400), _verify);
    }
  }

  /// Seçili paket — ödeme YALNIZ bunun id'siyle başlatılır.
  /// Referans HTML `#tp-amt` — serbest yükleme tutarı.
  final _tutar = TextEditingController(text: '${DomainConfig.minTopup}');

  /// Alandaki tutarın sayısal karşılığı (rakam dışı karakter atılır).
  int get _girilenTutar =>
      int.tryParse(_tutar.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  /// ⚠ MİNİMUM YÜKLEME TUTARI KESİN SINIRDIR.
  ///
  /// `DomainConfig.minTopup` TL'nin ALTINDAKİ hiçbir tutar kabul
  /// edilmez — ne düğme aktifleşir ne ödeme oturumu açılır.
  bool get _tutarGecerli =>
      _girilenTutar >= DomainConfig.minTopup &&
      _girilenTutar <= DomainConfig.maxTopup;

  /// Üst sınır aşıldı mı? (uyarı YALNIZ bu durumda gösterilir)
  bool get _tutarCokFazla => _girilenTutar > DomainConfig.maxTopup;

  // ── ADIM 1: ödeme oturumu aç ──────────────────────────────────────────
  //
  // Referans HTML `doTopup()` karşılığı: kullanıcı serbest tutar girer,
  // minimum kuralı doğrulanır, ödeme oturumu açılır.
  Future<void> _bakiyeYukle() async {
    final ctl = context.read<WalletController>();
    if (ctl.topupInFlight) {
      return;
    }

    setState(() { _error = null; _hata = null; _result = null; });

    final tutar = _girilenTutar;
    // ⚠ İKİNCİ SAVUNMA: düğme zaten pasif ama kural burada da denetlenir.
    if (_tutarCokFazla) {
      setState(() => _error =
          'Bir işlemde en fazla ${DomainConfig.maxTopup} TL '
          'yükleyebilirsiniz.');
      return;
    }
    if (!_tutarGecerli) {
      setState(() => _error =
          'Minimum yükleme tutarı ${DomainConfig.minTopup} TL\'dir.');
      return;
    }

    // SEÇİLİ KAYITLI KART — varsa tokenı ödeme oturumuna iletilir.
    // Sunucu kartı sağlayıcıda doğrular; istemci yalnız TOKEN gönderir.
    final secili = context.read<SavedCardsController>().selectedToken;

    final (session, err) = await ctl.startTopup(
      amount: tutar,
      savedCardToken: secili,
    );
    if (!mounted) {
      return;
    }

    if (err != null) {
      // ⚠ Sağlayıcı kapalıysa kontrollü hata gelir — SAHTE BAŞARI YOK.
      //
      // Metin merkezden: sunucu yanıt vermiyorsa "Sunucuya
      // ulaşılamıyor", kart reddettiyse "Kart bakiyeniz yetersiz".
      setState(() => _error = hataBilgisi(err).baslik);
      return;
    }
    if (session == null) {
      setState(() =>
          _error = 'Ödeme oturumu oluşturulamadı. Lütfen tekrar deneyin.');
      return;
    }

    // Oturum açıldı → sağlayıcı aşamasını BAŞLAT.
    // (`_result` PaymentStatus'tür; oturum nesnesi buraya ATANMAZ.)
    await _openProvider(session);
  }

  Future<void> _openProvider(PaymentSession session) async {
    // Sağlayıcı ekranı yoksa (yönlendirme adresi gelmediyse) doğrudan
    // doğrulamaya geç — mock/SDK akışı bu yoldan ilerler.
    if (!session.canOpenProvider) {
      setState(() {
        _stage = _Stage.verifying;
        _verifyScheduled = true;
      });
      await _verify();
      return;
    }

    final uri = Uri.tryParse(session.redirectUrl!);
    if (uri == null) {
      setState(() {
        _error = 'Ödeme sayfası adresi geçersiz. Lütfen tekrar deneyin.';
        _stage = _Stage.amount;
      });
      return;
    }

    setState(() {
      _stage = _Stage.awaitingProvider;
      _verifyScheduled = false;
    });

    bool opened = false;
    try {
      // Harici tarayıcı: gömülü WebView'a göre daha güvenlidir
      // (adres çubuğu ve sertifika kullanıcıya görünür).
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!mounted) {
      return;
    }
    if (!opened) {
      // Tarayıcı açılamadı — kontrollü hata, sahte başarı YOK.
      setState(() {
        _stage = _Stage.amount;
        _error = 'Ödeme sayfası açılamadı. Cihazınızda bir tarayıcı '
            'bulunduğundan emin olup tekrar deneyin.';
      });
    }
  }

  // ── ADIM 3: sonucu SUNUCUDAN doğrula ──────────────────────────────────
  Future<void> _verify() async {
    if (!mounted) {
      return;
    }
    final ctl = context.read<WalletController>();
    if (ctl.confirmInFlight) {
      return;
    }

    setState(() {
      _stage = _Stage.verifying;
      _error = null;
    });

    final (status, err) = await ctl.confirmTopup();
    if (!mounted) {
      return;
    }

    if (err != null) {
      setState(() {
        _stage = _Stage.result;
        _result = null;
        _error = err.message;
        _hata = err;
      });
      return;
    }

    setState(() {
      _result = status;
      _stage = _Stage.result;
      _verifyScheduled = false;
    });

    if (status == PaymentStatus.succeeded) {
      sysToastOk(context,
          '${_tutar.text} TL bakiyenize yüklendi');
    }
  }

  /// Kullanıcı yeniden dener: YENİ deneme başlar (yeni idempotency
  /// anahtarı controller tarafında üretilir).
  void _retry() {
    context.read<WalletController>().resetSession();
    setState(() {
      _stage = _Stage.amount;
      _result = null;
      _error = null;
      _hata = null;
      _verifyScheduled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // İşlem sürerken buton kilitlenir; durum değişince rebuild gerekir.
    final ctl = context.watch<WalletController>();
    final busy = ctl.topupInFlight || ctl.confirmInFlight;

    // ⚠ Referansta AppBar YOKTUR; başlık sayfa içindedir.
    return Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: RefScroll(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RefDetailHeader(title: 'Bakiye Yükle'),
              const SizedBox(height: 8),
              switch (_stage) {
                _Stage.amount => _amountStep(busy),
                _Stage.awaitingProvider => _awaitingStep(),
                _Stage.verifying => _verifyingStep(),
                _Stage.result => _resultStep(),
              },
            ],
          ),
        ),
      ),
    );
  }

  // ── Aşama 1: PAKET SEÇİMİ ─────────────────────────────────────────────
  //
  // Sabit tutar listesi KALDIRILDI. Paketler yalnız backend'den gelir;
  // fiyat ve jeton miktarının tek otoritesi sunucudur.
  Widget _amountStep(bool busy) {

    // İLK YÜKLEME (elde veri yok)
    // HATA + elde veri yok → tekrar dene
    // BOŞ
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ⚠ ÜSTTEKİ BİLGİ KUTUSU KALDIRILDI.
        //
        // Aynı cümle ekranda İKİ KEZ yazıyordu: bir kutuda, bir de
        // tutar alanının hemen altında. Alanın altındaki yardım metni
        // KALDI — kural okunacağı yerde, alanın yanındadır.

        // ── Yüklenecek Tutar (serbest giriş) ──
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Yüklenecek Tutar',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: HC.dark)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
              // kaydırılır — bkz. `kAlanKaydirmaPayi`.
              scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
              controller: _tutar,
              keyboardType: TextInputType.number,
              // ⚠ TEK ALANLI FORM: geçilecek başka alan yok, `done`
              // klavyeyi kapatır. Form kendiliğinden GÖNDERİLMEZ —
              // "Bakiye Yükle" düğmesi kendi kuralıyla çalışır.
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                // ⚠ HANE SINIRI: 10000 beş hanedir; altıncı hane
                // girilemez. Kullanıcı fazladan sıfır bassa bile
                // alana yazılmaz.
                LengthLimitingTextInputFormatter(
                    '${DomainConfig.maxTopup}'.length),
              ],
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: HC.dark),
              decoration: const InputDecoration(hintText: '500'),
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
          const SizedBox(width: 8),
          const Text('TL',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: HC.grey)),
        ]),
        const SizedBox(height: 7),
        // ── ⚠ RİSKLİ ORTAM ŞERİDİ ──
        //
        // Yalnız gerçekten riskliyse çizilir: root, bağlı hata
        // ayıklayıcı ya da imza uyuşmazlığı. Temiz cihazda hiçbir şey
        // görünmez.
        if (_cihaz?.paraIcinRiskli ?? false) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Cihazınızda güvenlik riski algılandı. Ödeme bilgileriniz '
              'başka uygulamalarca okunabilir.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A6D0B)),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // ⚠ TUTAR EKSİKSE UYARI KIRMIZIYA DÖNER.
        //
        // Gri yardım metni tek başına yetmiyordu: kullanıcı 100 yazıp
        // düğmeye basıyor, neden çalışmadığını anlamıyordu.
        // ⚠ ÜST SINIR UYARISI YALNIZ AŞILINCA ÇIKAR.
        //
        // Sürekli görünen bir "en fazla 10000 TL" satırı, sınıra
        // yaklaşmayan kullanıcıyı boşuna meşgul eder. Metin ancak
        // girilen tutar sınırı geçtiğinde değişir.
        Text(
            _tutarCokFazla
                ? 'Bir işlemde en fazla ${DomainConfig.maxTopup} TL '
                    'yükleyebilirsiniz.'
                : 'Minimum yükleme tutarı ${DomainConfig.minTopup} TL\'dir.',
            style: TextStyle(
                fontSize: 12,
                fontWeight: _tutarGecerli ? FontWeight.w400 : FontWeight.w700,
                color: _tutarGecerli ? HC.grey : HC.red)),
        const SizedBox(height: 18),

        // ── Ödeme Yöntemi ──
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Ödeme Yöntemi',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: HC.dark)),
        ),
        const SizedBox(height: 10),

        // Kayıtlı kartlar + Yeni Kart Ekle (referans HTML ile birebir).
        // ⚠ Kart alanları görünür; ham veri sağlayıcı SDK'sıyla
        // doğrudan sağlayıcıya gider — sunucuya ULAŞMAZ.
        const SavedCardsSection(),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: HC.red, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        // ⚠ MİNİMUMUN ALTINDA DÜĞME PASİFTİR.
        //
        // Kural: yükleme tutarı `DomainConfig.minTopup` TL'nin ALTINA
        // İNEMEZ. Eskiden düğme basılabiliyor, hata sonradan
        // gösteriliyordu; artık geçersiz tutarla hiç başlanamaz.
        SysButton('Bakiye Yükle',
            busy: busy, onPressed: _tutarGecerli ? _bakiyeYukle : null),
      ],
    );
  }

  /// Tek paket kartı. Uzun ad, bonussuz paket ve büyük fiyat için
  /// taşma korumalı.
  // ── Aşama 2: sağlayıcı sayfası açık ───────────────────────────────────
  Widget _awaitingStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 20),
          const Text(
            'Ödeme sayfası açıldı',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: HC.dark),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ödemenizi tamamladıktan sonra bu ekrana dönün. '
            'Sonuç otomatik olarak doğrulanacaktır.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: HC.grey, height: 1.5),
          ),
          const SizedBox(height: 20),
          // Otomatik doğrulama çalışmazsa elle tetikleme.
          SysButton('Ödemeyi Kontrol Et', onPressed: _verify),
          const SizedBox(height: 8),
          RefTextButton('Vazgeç', onPressed: _retry),
        ],
      );

  // ── Aşama 3: sunucu doğrulaması ───────────────────────────────────────
  Widget _verifyingStep() => const Column(
        children: [
          SizedBox(height: 30),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 18),
          Text('Ödeme doğrulanıyor…',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: HC.dark)),
          SizedBox(height: 6),
          Text('Lütfen uygulamayı kapatmayın.',
              style: TextStyle(fontSize: 13, color: HC.grey)),
        ],
      );

  // ── Aşama 4: sonuç ────────────────────────────────────────────────────
  Widget _resultStep() {
    // ── ⚠ HATA TÜRÜNE GÖRE BAŞLIK ──
    //
    // Metin `hata_mesajlari.dart` merkezinden gelir; ekran kendi
    // cümlesini yazmaz. Kart reddi, ağ sorunu ve sunucu arızası
    // artık AYRI görünür.
    if (_hata != null) {
      final bilgi = hataBilgisi(_hata!);
      return Column(children: [
        SysState(SysKind.genericError,
            title: bilgi.baslik,
            desc: bilgi.aciklama.isEmpty ? null : bilgi.aciklama,
            action: bilgi.denenebilir ? 'Tekrar Kontrol Et' : null,
            onAction: bilgi.denenebilir ? _verify : null),
        RefTextButton('Yeni Ödeme', onPressed: _retry),
      ]);
    }

    return switch (_result) {
      PaymentStatus.succeeded => Column(children: [
          SysState(SysKind.success,
              title: 'Ödeme başarılı',
              desc: 'Bakiyeniz güncellendi.',
              action: 'Cüzdana Dön',
              onAction: () => geriGit(context)),
        ]),

      // PENDING hata değildir: sağlayıcı henüz sonuçlandırmadı.
      PaymentStatus.pending => Column(children: [
          SysState(SysKind.genericError,
              title: 'Ödeme sonuçlanmadı',
              desc: 'Bankanız ödemeyi henüz onaylamadı. '
                  'Birkaç saniye sonra tekrar kontrol edebilirsiniz.',
              action: 'Tekrar Kontrol Et',
              onAction: _verify),
          RefTextButton('Yeni Ödeme', onPressed: _retry),
        ]),

      PaymentStatus.cancelled => Column(children: [
          SysState(SysKind.genericError,
              title: 'Ödeme iptal edildi',
              desc: 'İşlemi siz sonlandırdınız. Bakiyeniz değişmedi.',
              action: 'Tekrar Dene',
              onAction: _retry),
        ]),

      PaymentStatus.expired => Column(children: [
          SysState(SysKind.genericError,
              title: 'Ödeme süresi doldu',
              desc: 'Ödeme oturumu zaman aşımına uğradı. '
                  'Lütfen yeniden başlatın.',
              action: 'Tekrar Dene',
              onAction: _retry),
        ]),

      PaymentStatus.failed || _ => Column(children: [
          SysState(SysKind.genericError,
              // ⚠ KISA VE TEK CÜMLE (ürün kararı).
              //
              // Eski metin üç cümleydi ve hiçbirini net söylemiyordu.
              // Ret sebebi sağlayıcıdan ayrı gelmediği sürece TEK
              // başlık kullanılır; "bakiyeniz değişmedi" cümlesi de
              // kaldırıldı — ödeme alınmadıysa bu zaten açıktır.
              title: 'Kart geçersiz',
              desc: 'Farklı bir kartla deneyebilirsiniz.',
              action: 'Tekrar Dene',
              onAction: _retry),
        ]),
    };
  }
}
