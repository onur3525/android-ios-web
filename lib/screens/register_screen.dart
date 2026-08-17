import 'dart:io';
import '../domain/form_mesajlari.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/platform_kapilari.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/eposta_oneri.dart';
import '../core/ad_bicimi.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import 'otp_screen.dart';
import 'register_done_screen.dart';
import '../data/controllers/region_controller.dart';
import 'widgets/region_picker.dart';
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import '../data/services/google_auth_service.dart';
import '../data/controllers/profile_controller.dart';
import '../data/controllers/pending_listing_controller.dart';
import '../data/models/pending_listing.dart';
import '../data/controllers/listing_controller.dart';
import '../data/remote/api/storage_api.dart';
import '../data/remote/api_client.dart';
import 'widgets/photo_picker.dart';
import '../core/geri.dart';
import '../core/teshis.dart';
import '../data/remote/api_config.dart';
import 'widgets/kategori_secim_paneli.dart';

/// Kayıt Adım 1 — HTML kayıt formlarının birebir karşılığı.
/// Müşteri: ad, soyad, e-posta*, telefon, İl (yalnız İzmir), ilçe, mahalle,
/// şifre ×2, sözleşme onayı.
/// Hizmet veren: + hizmet kategorileri (çoklu) ve hizmet ilçeleri (çoklu).
class RegisterScreen extends StatefulWidget {
  final Role role;
  const RegisterScreen({super.key, required this.role});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _hood = TextEditingController();

  /// ── FORM ZİNCİRİ: GÖRÜNMEZ KADEMELER ──
  ///
  /// Form TEK EKRANDIR; kullanıcı adım adım ilerlediğini görmez. Ama
  /// içeride sıralı bir zincir vardır: bir alan tamamlanınca sıradaki
  /// alan kendiliğinden görünür alana gelir.
  ///
  ///   ad → soyad → telefon → e-posta → İL → İLÇE → MAHALLE
  ///      → şifre → şifre tekrar → sözleşme
  ///
  /// Metin alanları arasında geçiş ODAKLA yapılır (`onEditingComplete`
  /// + `scrollPadding`). Seçim satırları metin alanı olmadığı için
  /// odak alamaz; onlarda geçiş KAYDIRMAYLA yapılır.
  ///
  /// ── SEÇİMDEN SONRA SIRADAKİ ALANA KAYDIRMA ──
  ///
  /// ⚠ İl/ilçe/mahalle satırları METİN ALANI DEĞİLDİR; `scrollPadding`
  /// onlarda çalışmaz. Kullanıcı ilçeyi seçtikten sonra sıradaki alan
  /// (mahalle) ekranın altında, klavye açıksa onun ardında kalıyordu.
  ///
  /// Seçim TAMAMLANINCA sıradaki alan görünür alana getirilir.
  ///
  /// ⚠ Bu GLOBAL bir sarmalayıcı değildir: yalnız kullanıcının bir
  /// seçimi bitirdiği anda, açıkça çağrılır.
  final _ilKaydirKey = GlobalKey();
  final _ilceKaydirKey = GlobalKey();
  final _mahalleKaydirKey = GlobalKey();
  final _sozlesmeKaydirKey = GlobalKey();
  // ⚠ Şifre alanı için AYRI anahtar açılmaz: doğrulama anahtarı
  // (`_sifreKey`) zaten o alana bağlıdır ve `currentContext` verir.
  // Bir widget'a iki `key` verilemez.

  /// Verilen alanı görünür alana kaydırır.
  Future<void> _gorunurYap(GlobalKey k) async {
    // Panel kapanış animasyonu bitmeden kaydırma yapılırsa hedefin
    // konumu henüz doğru değildir; bir kare beklenir.
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
      // Alanı ekranın üst yarısına taşır — altında kalan alanlar da
      // görünür olur.
      alignment: 0.15,
    );
  }
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _district;                 // müşteri ilçesi
  final Set<String> _cats = {};      // sağlayıcı kategorileri
  final Set<String> _provDistricts = {}; // sağlayıcı ilçeleri
  bool _agree = false;
  bool _busyGoogle = false;

  /// Seçili il — sunucudan gelen aktif iller arasından seçilir.
  /// ⚠ HARD-CODE DEĞİLDİR; tek il varsa kendiliğinden seçilir.
  String? _city;
  bool _busy = false;

  /// ⚠ BU KAYIT DENEMESİNİN KİMLİĞİ (Y1).
  ///
  /// OTP yetkisi bu kimliğe bağlanır: başka bir taslak, farklı
  /// telefon veya sonradan açılmış bir form aynı yetkiyi kullanamaz.
  final String _taslakKimligi =
      'kayit-${DateTime.now().microsecondsSinceEpoch}';

  /// Doğrulamadan dönen kısa ömürlü kayıt yetkisi.
  String? _kayitYetkisi;

  /// Alan düzelince uyarı ANINDA kalksın; yalnız o alan yeniden
  /// doğrulanır — dokunulmamış alanlar erkenden kırmızıya boyanmaz.
  final _adKey = GlobalKey<FormFieldState<String>>();
  final _soyadKey = GlobalKey<FormFieldState<String>>();
  final _epostaKey = GlobalKey<FormFieldState<String>>();
  final _telefonKey = GlobalKey<FormFieldState<String>>();
  final _sifreKey = GlobalKey<FormFieldState<String>>();
  final _sifre2Key = GlobalKey<FormFieldState<String>>();

  /// ⚠ BÖLGE YÜKLEMESİ YALNIZ BİR KEZ PLANLANIR.
  ///
  /// `didChangeDependencies` birden çok kez çağrılabilir (bağımlılık
  /// değişimi, tema/medya değişimi). Bu bayrak olmadan her çağrıda
  /// yeni bir post-frame görevi kuyruğa girerdi.
  bool _regionYuklemePlanlandi = false;
  /// ⚠ ŞİFRE VE ŞİFRE TEKRAR MASKELERİ BAĞIMSIZDIR.
  /// Tek bayrak kullanılırsa bir göze dokunmak İKİSİNİ birden açar.
  bool _obscure = true;
  bool _obscure2 = true;

  /// ⚠ ENTER İLE SONRAKİ ALANA GEÇİŞ.
  /// Kullanıcı her alanı elle seçmek zorunda kalmaz.
  /// ⚠ İlk alanın da KALICI odak düğümü vardır (teşhis + zincir).
  /// ⚠ Buton aktifliği TÜM SAYFAYI değil yalnız butonu yeniler.
  /// Her tuşta `setState` çağırmak 6 alanlı formda klavye açılışını
  /// gözle görülür biçimde yavaşlatıyordu.
  final _formGecerli = ValueNotifier<bool>(false);

  /// ⚠ SÖZLEŞME KUTUSU İÇİN AYRI BİLDİRİM.
  ///
  /// `enabled: _alanlarTamam` doğrudan okunuyordu; ama `_tazele`
  /// yalnız `ValueNotifier` güncelliyor, `setState` ÇAĞIRMIYOR
  /// (her tuşta yeniden çizim pahalı). Sonuç: alanlar dolsa bile
  /// kutu yeniden çizilmiyor, ancak başka bir sebeple ekran
  /// tazelendiğinde "sonradan" açılıyordu.
  ///
  /// Kutu artık bu bildirimi DİNLER; alanlar tamamlandığı anda açılır.
  final _alanlarGecerli = ValueNotifier<bool>(false);

  final _fFirst = FocusNode();
  final _fLast = FocusNode();
  final _fEmail = FocusNode();
  final _fPhone = FocusNode();
  final _fPass = FocusNode();
  final _fPass2 = FocusNode();
  String? _chipsError; // kategori/ilçe seçim hataları (alan-altı)

  bool get isProvider => widget.role == Role.provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠ TEŞHİS: bayrak kapalıyken hiçbir dinleyici eklenmez.
    FocusIzle.aktifRoute = 'register/${widget.role.name}';
    FocusIzle.kaydet(_fFirst, 'Adınız');
    FocusIzle.kaydet(_fLast, 'Soyadınız');
    FocusIzle.kaydet(_fEmail, 'E-Posta');
    FocusIzle.kaydet(_fPhone, 'Telefon');
    FocusIzle.kaydet(_fPass, 'Şifre');
    FocusIzle.kaydet(_fPass2, 'Şifre Tekrar');
    // ⚠ BÖLGE VERİSİ EKRAN AÇILIRKEN YÜKLENİR.
    //
    // `ChangeNotifierProvider` LAZY'dir: `RegionController` ilk
    // okumaya kadar oluşturulmaz ve `load()` başlamaz. İlçe seçimi
    // sayfası bu yüklemeden ÖNCE açılırsa liste boş gelir ve
    // kullanıcı "Sonuç bulunamadı" görür.
    //
    // `load()` zaten yüklenmişse erken döner (tekrar istek yok).
    // Aynı desen `addresses_screen` içinde de kullanılır.
    //
    // ⚠ ÇAĞRI İLK KAREDEN SONRAYA ERTELENİR — İŞ KURALI DEĞİŞMEZ.
    //
    // `load()` ilk `await`ten ÖNCE `setBusy` + `notifyListeners`
    // çağırır. `didChangeDependencies` build aşamasının içinde
    // koştuğu için bu, hâlâ build edilmekte olan dinleyicilerde
    // `markNeedsBuild` tetikliyor ve
    // "setState() or markNeedsBuild() called during build"
    // assertion'ı atıyordu. Görev ilk kareden sonraya alınınca
    // bildirim güvenli aşamada yayılır.
    //
    // Yükleme YİNE ekran açılışında başlar; yalnız zamanlaması
    // değişti. Çift yükleme iki katmanda engellenir:
    //   1) buradaki `_regionYuklemePlanlandi` bayrağı,
    //   2) `RegionController.load()` içindeki `_tree != null` erken
    //      dönüşü ve `setBusy` kilidi (dokunulmadı).
    // Lazy provider'ı örnekle (yükleme aşağıda post-frame'de başlar).
    context.read<RegionController>();
    if (!_regionYuklemePlanlandi) {
      _regionYuklemePlanlandi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<RegionController>().load();
      });
    }
    // ⚠ İL OTOMATİK SEÇİLMEZ.
    //
    // Önceden tek aktif il varsa (`soleCityName`) alan kendiliğinden
    // "İzmir" ile doluyordu. Kullanıcı bir seçim YAPMAMIŞ oluyor,
    // buna rağmen alan seçilmiş görünüyordu. Artık alan boş açılır,
    // `* İl` yazar ve zorunlu seçim olarak davranır; listede o an
    // AKTİF olan iller görünür (admin yeni il eklerse kendiliğinden
    // listeye düşer).
  }

  /// GOOGLE İLE DEVAM (kayıt akışı)
  ///
  /// Referans `vRegStep1`: `<button class="rg-google" onclick="googleSheet()">`
  ///
  /// Login ile AYNI gerçek akış: Google'dan `idToken` alınır ve sunucuya
  /// gönderilir. Yalnız görsel buton DEĞİLDİR.
  Future<void> _googleIleDevam() async {
    if (_busyGoogle || _busy) {
      return;
    }
    setState(() => _busyGoogle = true);
    try {
      final idToken = await GoogleAuthService().signInIdToken();
      if (!mounted) {
        return;
      }
      if (idToken == null) {
        // Kullanıcı vazgeçti — hata gösterilmez.
        setState(() => _busyGoogle = false);
        return;
      }
      final err = await context.read<AuthController>().googleLogin(idToken);
      if (!mounted) {
        return;
      }
      setState(() => _busyGoogle = false);
      if (err != null) {
        sysToastErr(context, SysKind.genericError, extra: err.message);
        return;
      }
      // ══════════════════════════════════════════════════════════
      // ⚠ GOOGLE İLE KAYIT PANELE ATLAMAZ
      //
      // Google yalnız kimlik ve doğrulanmış e-posta sağlar.
      // HizmetCep zorunlulukları BYPASS EDİLMEZ:
      //   Telefon + SMS OTP · İl/İlçe/Mahalle · sözleşme onayı
      //   (Hizmet Veren için ayrıca kategori + hizmet bölgesi)
      //
      // Eksik alan varsa kullanıcı tamamlama akışına yönlendirilir.
      // ══════════════════════════════════════════════════════════
      final auth = context.read<AuthController>();
      final acc = auth.currentAccount;
      final eksik = acc?.missingSteps ?? const <OnboardingStep>[];

      if (acc == null || eksik.isNotEmpty) {
        sysToastOk(context,
            'Google hesabınız bağlandı — bilgilerinizi tamamlayın');
        // Formda kalınır; Google'dan gelen bilgiler alanlara doldurulur
        // ve kullanıcı eksikleri tamamlayıp normal akışla devam eder.
        setState(() {
          if (acc != null) {
            final ad = acc.name.trim().split(RegExp(r'\s+'));
            if (_first.text.trim().isEmpty && ad.isNotEmpty) {
              _first.text = ad.first;
            }
            if (_last.text.trim().isEmpty && ad.length > 1) {
              _last.text = ad.sublist(1).join(' ');
            }
            if (_email.text.trim().isEmpty) {
              _email.text = acc.email;
            }
          }
        });
        // ⚠ Alanlar KOD İLE dolduruldu; `onChanged` tetiklenmez.
        // Düğme bildirimi elle tazelenmezse form dolu görünür ama
        // "Devam Et" pasif kalır.
        _tazele();
        return;
      }

      // Tüm zorunluluklar tamam — panele geçilebilir.
      sysToastOk(context, 'Hoş geldiniz!');
      Navigator.of(context).pushNamedAndRemoveUntil(
        auth.activeRole == Role.provider
            ? '/provider/jobs'
            : '/customer/listings',
        (r) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busyGoogle = false);
      sysToastErr(context, SysKind.genericError,
          extra: 'Google ile devam edilemedi');
    }
  }

  /// KAYIT SONRASI BEKLEYEN İLAN YAYINI
  ///
  /// Ön koşullar (hepsi zorunlu):
  ///   • hesap Hizmet Alan (customer) rolünde,
  ///   • `Account.customerOnboardingComplete` true
  ///     (telefon+SMS OTP, e-posta doğrulaması, adres, sözleşme).
  ///
  /// ⚠ FOTOĞRAF OPSİYONELDİR: 0 fotoğrafla yayın YAPILABİLİR.
  /// Yalnız kullanıcının EKLEDİĞİ dosyalardan biri cihazdan
  /// kaybolmuşsa sessizce atılmaz — kullanıcıya sorulur.
  Future<void> _bekleyenIlaniYayinla(BuildContext c) async {
    final pending = c.read<PendingListingController>();
    if (!pending.hasDraft) {
      return;
    }
    final acc = c.read<AuthController>().currentAccount;
    // ⚠ Onboarding TAMAMLANMADAN yayın YOK.
    if (acc == null ||
        !acc.roles.contains(Role.customer) ||
        !acc.customerOnboardingComplete) {
      return;
    }

    final sonuc = await pending.publishIfAny(
      yayinla: (p, fotograflar) => _yayinla(c, acc.id, p, fotograflar),
    );
    if (!c.mounted) {
      return;
    }
    switch (sonuc) {
      case PendingPublishOutcome.yayinlandi:
        sysToastOk(c, 'İlanınız yayınlandı');
      case PendingPublishOutcome.eksikFotograf:
        await _eksikFotografKarari(c, pending);
      case PendingPublishOutcome.hata:
        sysToastErr(c, SysKind.genericError,
            extra: 'İlan yayınlanamadı — İlanlarım ekranından tekrar '
                'deneyebilirsiniz');
      case PendingPublishOutcome.yok:
        break;
    }
  }

  /// Fotoğrafları yükler ve ilanı oluşturur.
  ///
  /// Yükleme başarısız olursa `false` döner — ilan SAHTE BAŞARILI
  /// gösterilmez ve taslak korunur.
  /// Kayıt formundaki adresle konum dizesi üretir.
  ///
  /// Eksikse `null` döner ve yayın yapılmaz.
  /// ⚠ `BuildContext` ALMAZ.
  ///
  /// Eskiden `c.read<RegionController>()` çağırıyordu ve bu metot
  /// fotoğraf yükleme döngüsünden SONRA çalıştığı için context
  /// geçersiz olabiliyordu. Şehir adı artık çağıran taraftan hazır
  /// gelir; metot saf (yan etkisiz) hâle geldi.
  String? _kayitKonumu(String varsayilanIl) {
    final ilce = _district;
    final mah = _hood.text.trim();
    if (ilce == null || ilce.isEmpty || mah.isEmpty) {
      return null;
    }
    final il = _city ?? varsayilanIl;
    return '$mah, $ilce / $il';
  }

  Future<bool> _yayinla(
    BuildContext c,
    String ownerId,
    PendingListing p,
    List<String> fotograflar,
  ) async {
    // ⚠ MOCK MODDA YÜKLEME ATLANIR.
    //
    // Backend yokken her fotoğraf için istek 20sn timeout'a düşüyor
    // ve kullanıcı kayıt sonunda dakikalarca bekliyordu. Mock'ta
    // fotoğraf zaten yerel yolla taşınır; sunucu referansı gerekmez.
    if (!ApiConfig.useRealApi) {
      return true;
    }

    // ⚠ BAĞIMLILIKLAR `await`'TEN ÖNCE ALINIR.
    //
    // Aşağıda her fotoğraf için ağ çağrısı yapılır; uzun sürer.
    // Kullanıcı bu sırada ekranı kapatırsa `c.read<...>()` şu hatayı
    // verir:
    //
    //   Looking up a deactivated widget's ancestor is unsafe
    //
    // ⚠ ÇİFT YAYIN RİSKİ YOK: `publish` çağrısı bu akışta TEK
    // yerdedir ve `await` zinciri sıralıdır. Bağımlılığı önceden
    // almak çağrı sayısını DEĞİŞTİRMEZ.
    final storage = StorageApi(c.read<ApiClient>());
    final listingCtl = c.read<ListingController>();
    final sehir = c.read<RegionController>().cityName ?? '';
    final refs = <String>[];
    try {
      for (final yol in fotograflar) {
        final tip = contentTypeOf(yol);
        if (tip == null) {
          continue; // desteklenmeyen tür — atlanır
        }
        final boyut = await File(yol).length();
        // Mevcut yükleme sözleşmesi (`photo_picker` ile AYNI):
        // sunucudan referans alınır, yerel yol ilana YAZILMAZ.
        final res = await storage.createUploadRef(
          kind: 'listing-photo',
          contentType: tip,
          sizeBytes: boyut,
        );
        final ref =
            res['storageRef'] as String? ?? res['ref'] as String?;
        if (ref == null || ref.isEmpty) {
          throw StateError('storageRef alınamadı');
        }
        refs.add(ref);
      }
    } catch (_) {
      // KISMİ YÜKLEME: ilana bağlanmamış referanslar bırakılmaz.
      for (final r in refs) {
        try {
          await storage.discardPending(r);
        } catch (_) {/* temizlik hatası yayını etkilemez */}
      }
      return false;
    }

    // ⚠ TASLAK KONUMU BOŞ OLABİLİR.
    //
    // İlan akışının 2. adımında konum sorulmaz; oturumsuz kullanıcı
    // adresini KAYIT formunda girer. Taslakta konum yoksa kayıt
    // verisiyle tamamlanır. Eksikse yayın YAPILMAZ.
    final konum = p.district.trim().isEmpty || p.neighborhood.trim().isEmpty
        ? _kayitKonumu(sehir)
        : p.location;
    if (konum == null) {
      // ⚠ Fotoğraf döngüsünden sonra `c` geçersiz olabilir; toast
      // yalnız canlıysa gösterilir. Dönüş değeri DEĞİŞMEZ.
      if (c.mounted) {
        sysToastErr(c, SysKind.genericError,
            extra: 'İlçe ve mahalle bilgisi eksik — ilan yayınlanamadı');
      }
      return false;
    }

    final r = await listingCtl.publish(
          ownerId: ownerId,
          title: p.title,
          location: konum,
          desc: p.description,
          photoPaths: refs,
        );
    if (r.error != null) {
      for (final ref in refs) {
        try {
          await storage.discardPending(ref);
        } catch (_) {/* yoksay */}
      }
      return false;
    }
    return true;
  }

  /// EKSİK FOTOĞRAF — kullanıcı kararı olmadan yayın YOK.
  Future<void> _eksikFotografKarari(
      BuildContext c, PendingListingController pending) async {
    final kayip = pending.kayipFotograflar.length;
    final devam = await RefBottomSheet.goster<bool>(
      c,
      title: 'Eksik Fotoğraf',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$kayip fotoğraf cihazınızda bulunamadı. Silinmiş veya '
            'taşınmış olabilir.\n\nEksik fotoğrafları kaldırıp ilanı '
            'yayınlayabilir ya da vazgeçip İlanlarım ekranından yeniden '
            'fotoğraf seçebilirsiniz.',
            style: refText(
                size: RF.s135,
                weight: RF.w400,
                color: RC.textDark,
                height: RF.lh150),
          ),
          const SizedBox(height: 16),
          RefWideButton(
            'Eksikleri Kaldır ve Yayınla',
            onPressed: () => Navigator.of(c).pop(true),
          ),
          const SizedBox(height: 8),
          Center(
            child: RefTextButton('Şimdi Değil',
                onPressed: () => Navigator.of(c).pop(false)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (devam != true || !c.mounted) {
      // Taslak KORUNUR; ilan yayınlanmaz.
      return;
    }
    // Kullanıcı onayladı: yalnız mevcut dosyalarla (0 olabilir) yayınla.
    final sonuc = await pending.publishIfAny(
      yayinla: (p, fotograflar) => _yayinla(
          c, c.read<AuthController>().currentAccount!.id, p, fotograflar),
      eksikFotografaIzinVer: true,
    );
    if (!c.mounted) {
      return;
    }
    if (sonuc == PendingPublishOutcome.yayinlandi) {
      sysToastOk(c, 'İlanınız yayınlandı');
    } else if (sonuc == PendingPublishOutcome.hata) {
      sysToastErr(c, SysKind.genericError, extra: 'İlan yayınlanamadı');
    }
  }

  /// İL SEÇİMİ — sunucudan gelen aktif iller.
  ///
  /// ⚠ İl DEĞİŞİRSE ilçe ve mahalle SIFIRLANIR; sağlayıcı tarafında
  /// hizmet bölgeleri de temizlenir (başka ilin ilçeleri taşınamaz).
  Future<void> _ilSec(BuildContext context) async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Consumer<RegionController>(
        builder: (_, r, __) => RegionPickerSheet(
          title: 'İl Seçin',
          options: r.cityNames,
          selected: _city,
          searchable: true,
        ),
      ),
    );
    if (sel == null || !mounted || sel == _city) {
      return;
    }
    setState(() {
      _city = sel;
      // İl değişti → alt zincir GEÇERSİZ.
      _district = null;
      _hood.text = '';
      _provDistricts.clear();
    });
    // ⚠ Seçim de zorunlu alanları etkiler; düğme bildirimi tazelenir.
    _tazele();
    // Zincirin sıradaki halkası.
    await _gorunurYap(_ilceKaydirKey);
  }

  /// İlçe seçimi — `RegionPickerSheet` (kontrollü liste).
  Future<void> _ilceSec(BuildContext context) async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      // ⚠ `read` ile ANLIK liste geçilirse, veri sonradan gelse bile
      // sayfa güncellenmez. `Consumer` ile dinlenir.
      builder: (_) => Consumer<RegionController>(
        builder: (_, r, __) => RegionPickerSheet(
          title: 'İlçe Seçin',
          options: r.districtsOf(_city),
          selected: _district,
          searchable: true,
        ),
      ),
    );
    if (sel != null && mounted) {
      setState(() {
        _district = sel;
        // İlçe değişince mahalle SIFIRLANIR (kontrollü zincir).
        _hood.text = '';
      });
      _tazele();
      // Sıradaki zorunlu alan görünür olsun.
      await _gorunurYap(_mahalleKaydirKey);
    }
  }

  /// Mahalle seçimi — ilçeye bağlı liste; serbest metin YOK.
  Future<void> _mahalleSec(BuildContext context) async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Consumer<RegionController>(
        builder: (_, r, __) => RegionPickerSheet(
          title: 'Mahalle Seçin',
          options: r.neighborhoodsOf(_district!, city: _city),
          selected: _hood.text.isEmpty ? null : _hood.text,
          searchable: true,
        ),
      ),
    );
    if (sel != null && mounted) {
      setState(() => _hood.text = sel);
      _tazele();
      // Adres zinciri bitti; sırada şifre var.
      await _gorunurYap(_sifreKey);
    }
  }

  /// ⚠ KAYIT FORMU GEÇERLİ Mİ?
  ///
  /// Kurallar `Validators` ile AYNIDIR (ilan akışındaki kayıt adımıyla
  /// birebir). Sözleşme onayı da zorunludur; biri bile eksikse
  /// "Devam Et" pasif kalır.
  /// Alan değişiminde YALNIZ buton durumunu günceller.
  /// ── BOŞ ALANDA UYARI KURALI ──
  ///
  /// ⚠ Kullanıcının HENÜZ ULAŞMADIĞI boş alan uyarı göstermez.
  ///
  /// Alana bir kez dokunup yazmadan çıkmak "hata" değildir; formun
  /// altındaki dokunulmamış alanları kırmızıya boyamak kullanıcıyı
  /// hata yapmış gibi hissettirir.
  ///
  /// Boş bir alan yalnız şu iki durumda uyarı gösterir:
  ///   1. O anda GÖNDERİM denetimi çalışıyorsa, veya
  ///   2. KENDİSİNDEN SONRAKİ bir alan doldurulmuşsa — yani kullanıcı
  ///      onu atlayıp ilerlemişse.
  ///
  /// Dolu ama GEÇERSİZ alanlar bu kuraldan etkilenmez; onların uyarısı
  /// her zaman gösterilir.
  ///
  /// ⚠ BU BAYRAK KALICI DEĞİLDİR — yalnız `validate()` çağrısı
  /// süresince açıktır.
  ///
  /// Eski hâli bir kez "Devam Et"e basıldıktan sonra bir daha
  /// kapanmıyordu: kullanıcı alanı düzeltmek için içine girip yazsa
  /// bile kırmızı uyarı ekranda ASILI KALIYORDU. Gönderim anında odak
  /// kuralı atlanmalı (yoksa o sırada odaktaki alan denetlenmeden
  /// geçer), ama gönderimden SONRA normal kural yeniden geçerlidir.
  bool _gonderimAninda = false;

  /// Sıralı zorunlu metin alanları — kural bu sıraya göre işler.
  List<TextEditingController> get _siraliAlanlar =>
      [_first, _last, _phone, _email, _pass, _pass2];

  /// [c] alanından SONRAKİ alanlardan biri dolu mu?
  bool _sonrasiDolu(TextEditingController c) {
    final liste = _siraliAlanlar;
    final i = liste.indexOf(c);
    if (i < 0) {
      return false;
    }
    for (var j = i + 1; j < liste.length; j++) {
      if (liste[j].text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Boş alan için uyarı gösterilmeli mi?
  /// ⚠ BOŞ ALAN ARTIK YALNIZ GÖNDERİMDE UYARIR.
  ///
  /// Eski kural iki durumda daha uyarıyordu: alan terk edilmişse ya
  /// da SONRASI doldurulmuşsa (atlanmış alan). Yeni ürün kuralı bunu
  /// kaldırdı:
  ///
  ///   "Bilgi girilip silindiğinde ve hiçbir satırda bilgi
  ///    olmadığında katiyen uyarı olmayacak."
  ///
  /// Eksik alan artık uyarıyla değil DÜĞMEYİ PASİF TUTARAK
  /// bildiriliyor (`_formTamam`). Uyarı yalnız YANLIŞ yazılmış
  /// satırda çıkar.
  bool _bosUyariGoster(TextEditingController c) => _gonderimAninda;

  /// TERK EDİLMİŞ ALANLAR — uyarı yalnız bunlarda görünür.
  ///
  /// Alan bir kez odaktan çıktığında buraya eklenir. Gönderim
  /// denendiğinde hepsi eklenir.
  final Set<TextEditingController> _terkEdilen = {};

  /// Alanın odak düğümü — uyarı kapısında "şu an yazıyor mu?"
  /// sorusunu yanıtlar.
  FocusNode? _odak(TextEditingController c) {
    if (c == _first) {
      return _fFirst;
    }
    if (c == _last) {
      return _fLast;
    }
    if (c == _phone) {
      return _fPhone;
    }
    if (c == _email) {
      return _fEmail;
    }
    if (c == _pass) {
      return _fPass;
    }
    if (c == _pass2) {
      return _fPass2;
    }
    return null;
  }

  /// Doğrulayıcı sarmalayıcısı — UYARININ ZAMANINI belirler.
  ///
  /// Sıra:
  ///   1. Alan ODAKTAYSA uyarı YOK. Kullanıcı yazmayı sürdürüyor;
  ///      ilk harfte "geçersiz" demek yanlış ve rahatsız edici.
  ///   2. Alan HENÜZ TERK EDİLMEDİYSE ve gönderim denenmediyse uyarı
  ///      YOK. Kullanıcı oraya hiç uğramamış olabilir.
  ///   3. Alan BOŞSA, ancak gönderim denendiyse veya kullanıcı onu
  ///      atlayıp sonraki alanı doldurduysa uyarılır.
  ///   4. Diğer tüm durumlarda asıl kural uygulanır.
  String? _kural(
      TextEditingController c, String? v, String? Function(String?) asil) {
    if (!_gonderimAninda) {
      final f = _odak(c);
      if (f != null && f.hasFocus) {
        return null;
      }
      // ⚠ HİÇ UĞRANMAMIŞ ama ATLANMIŞ alan da uyarılır: kullanıcı
      // sonraki satırı doldurduysa üstteki eksik satır bildirilir.
      if (!_terkEdilen.contains(c) && !_sonrasiDolu(c)) {
        return null;
      }
    }
    if ((v ?? '').trim().isEmpty && !_bosUyariGoster(c)) {
      return null;
    }
    return asil(v);
  }

  void _tazele() {
    final v = _formTamam;
    if (_formGecerli.value != v) {
      _formGecerli.value = v;
    }
    // Sözleşme kutusunun açılma koşulu — bkz. `_alanlarGecerli` notu.
    final a = _alanlarTamam;
    if (_alanlarGecerli.value != a) {
      _alanlarGecerli.value = a;
    }
  }

  /// Gönderim koşulu: zorunlu alanlar TAMAM **ve** sözleşme onaylı.
  bool get _formTamam => _alanlarTamam && _agree;

  /// ZORUNLU ALANLAR TAMAM MI? (sözleşme HARİÇ)
  ///
  /// ⚠ Sözleşme kutusunun AÇILMA koşuludur: kullanıcı formu
  /// doldurmadan sözleşmeyi işaretleyemez.
  bool get _alanlarTamam {
    if (Validators.name(_first.text, min: 3, label: 'ad') != null ||
        Validators.name(_last.text, min: 2, label: 'soyad') != null ||
        Validators.email(_email.text) != null ||
        Validators.phone(_phone.text) != null ||
        Validators.password(_pass.text) != null ||
        _pass2.text != _pass.text ||
        _pass2.text.isEmpty) {
      return false;
    }
    // ⚠ İL ZORUNLU SEÇİMDİR — her iki rolde de.
    // Otomatik doldurma kaldırıldığı için kullanıcı gerçekten seçmeli.
    if (_city == null) {
      return false;
    }
    // Müşteri kaydında adres, sağlayıcı kaydında kategori + bölge.
    if (widget.role == Role.customer) {
      return _district != null && _hood.text.trim().isNotEmpty;
    }
    return _cats.isNotEmpty && _provDistricts.isNotEmpty;
  }

  Future<void> _next() async {
    if (_busy) {
      return;
    }
    // ⚠ Gönderimde TÜM alanlar denetlenir; alanlar "terk edilmiş"
    // sayılır ki uyarı gönderimden sonra da doğru yerde kalsın —
    // ama odak kuralı geri açılır, uyarı asılı kalmaz.
    setState(() => _chipsError = null);
    _terkEdilen.addAll(_siraliAlanlar);
    _gonderimAninda = true;
    final formOk = _form.currentState!.validate();
    _gonderimAninda = false;
    setState(() {});
    String? chips;
    if (isProvider) {
      if (_cats.isEmpty) {
        chips = FormMesaj.kategoriSec;
      } else if (_provDistricts.isEmpty) {
        chips = FormMesaj.bolgeSec;
      }
    }
    if (chips != null) setState(() => _chipsError = chips);
    // İl/ilçe/mahalle artık seçici olduğundan form validator'ına
    // takılmaz; kontrol burada yapılır (iş kuralı korunur).
    if (_city == null) {
      sysToastErr(context, SysKind.genericError, extra: FormMesaj.ilSec);
      return;
    }
    if (!isProvider &&
        (_district == null || _hood.text.trim().isEmpty)) {
      sysToastErr(context, SysKind.genericError,
          extra: 'İlçe ve mahalle seçiniz');
      return;
    }
    if (!formOk || chips != null) {
      return;
    }
    if (!_agree) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Devam etmek için sözleşmeyi onaylayınız');
      return;
    }
    setState(() => _busy = true);
    final phone = Validators.phoneFmt(_phone.text);
    // ── CHALLENGE ÜRETİLİR VE SMS GÖNDERİLİR ──
    //
    // ⚠ Eski `requestOtp` yolu bırakıldı: o yalnız kod gönderiyordu,
    // doğrulamanın sonucunu ekran veriyordu. Artık challenge
    // üretiliyor ve doğrulamayı use-case yapıyor.
    //
    // ⚠ TASLAK KİMLİĞİ: bu kayıt denemesini temsil eder (Y1).
    // Kullanıcı formu kapatıp yeniden açarsa yeni taslak üretilir ve
    // eski yetki geçersiz kalır.
    var ch = await context
        .read<AuthController>()
        .kayitKodGonder(phone, taslakKimligi: _taslakKimligi);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phone: phone,
          purpose: OtpPurpose.register,
          // ⚠ EKRAN KODU DOĞRULAMAZ. Sonucu use-case verir; başarıda
          // kısa ömürlü KAYIT YETKİSİ döner. Hesap burada OLUŞMAZ.
          dogrula: (kod) async {
            final d = await context
                .read<AuthController>()
                .kayitDogrula(ch.challengeId, kod);
            _kayitYetkisi = d.yetki;
            return d.hata;
          },
          // ⚠ AKIŞA ÖZEL: yeni KAYIT challenge'ı üretilir, eskisi
          // iptal olur (C7). Aynı taslak kimliği korunur.
          yenidenGonder: () async {
            ch = await context
                .read<AuthController>()
                .kayitKodGonder(phone, taslakKimligi: _taslakKimligi);
            return null;
          },
          onVerified: (otpContext, otpCode) async {
            final r = await otpContext.read<AuthController>().register(
                phone: phone,
                pass: _pass.text,
                role: widget.role,
                // ⚠ Bayrak DEĞİL YETKİ karar verir (Y1).
                otpVerified: false,
                kayitYetkisi: _kayitYetkisi,
                taslakKimligi: _taslakKimligi,
                otpCode: otpCode,
                name: '${_first.text.trim()} ${_last.text.trim()}',
                // Kayda küçük harfe çevrilmiş biçim yazılır.
                email: epostaNormalize(_email.text),
                categories: _cats,
                serviceDistricts: _provDistricts,
                // ⚠ E-POSTA DOĞRULANMIŞ SAYILMAZ.
                //
                // Telefon OTP'si e-postayı doğrulamaz; iki doğrulama
                // BİRBİRİNDEN BAĞIMSIZDIR. `emailVerified`
                // verilmiyor (varsayılan false).
                // Sözleşme onayı domain katmanına İLETİLİR:
                // yalnız UI kontrolüne güvenilmez.
                termsAccepted: _agree);
            if (!otpContext.mounted) {
              return;
            }
            if (r.error != null) {
              ScaffoldMessenger.of(otpContext)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: HC.dark,
                    content: Text(r.error!.message, textAlign: TextAlign.center)));
              Navigator.pop(otpContext); // forma geri
              return;
            }
            // ── KAYIT ADRESİNİ KALICI HALE GETİR ──
            //
            // Kullanıcı formda İl/İlçe/Mahalle seçti; bu değerler
            // `Account.address` modeline YAZILMALI. Aksi hâlde
            // Profil > Adreslerim boş açılır ve kullanıcı yeniden
            // seçim yapmak zorunda kalır.
            //
            // Müşteri rolüne özgüdür (sağlayıcıda hizmet bölgesi ayrı).
            // ⚠ ADRES HER ROL İÇİN KAYDEDİLİR.
            //
            // Önceden yalnız `Role.customer` dalında kaydediliyordu;
            // sağlayıcı olarak kaydolan kullanıcı sonradan müşteri
            // rolüne geçtiğinde Adreslerim ekranı BOŞ geliyordu.
            //
            // `city` de boş geçilmez: seçili il yoksa aktif il
            // kullanılır (aksi hâlde Adreslerim'de il görünmez).
            if (_district != null && _hood.text.trim().isNotEmpty) {
              final il = _city ??
                  otpContext.read<RegionController>().cityName ??
                  '';
              await otpContext.read<ProfileController>().saveAddress(
                    district: _district!,
                    neighborhood: _hood.text.trim(),
                    city: il,
                  );
              if (!otpContext.mounted) {
                return;
              }
            }
            // ── BEKLEYEN İLANI YAYINLA ──
            //
            // ⚠ Körlemesine "kayıt başarılı" callback'i DEĞİLDİR.
            // Yayın yalnız sistem kullanıcıyı TAMAMLANMIŞ Hizmet Alan
            // hesabı kabul ettiğinde yapılır: SMS OTP + e-posta
            // doğrulaması + zorunlu profil/adres + onboarding.
            //
            // Eksik varsa ilan YAYINLANMAZ; taslak korunur ve
            // kullanıcı eksikleri tamamlayınca yayınlanır.
            await _bekleyenIlaniYayinla(otpContext);
            if (!otpContext.mounted) {
              return;
            }
            Navigator.pushReplacement(otpContext,
                MaterialPageRoute(builder: (_) => const RegisterDoneScreen()));
          },
        ),
      ),
    );
  }

  /// Referans `.rg-f` kutusu — metin girdisi.
  ///
  /// ```css
  /// .rg-f    {border:1.5px solid #E7EAEF;border-radius:13px;
  ///           padding:14px 15px;gap:12px;margin-bottom:11px}
  /// .rg-ic   {flex:0 0 22px}
  /// .rg-input{font-size:15px;font-weight:500;color:#16233D;ls -.1}
  /// ```
  /// İl/İlçe/Mahalle seçicileriyle AYNI kutu ailesidir.
  /// ⚠ ZORUNLU ALAN YILDIZI: `hintText` DÜZ METİNDİR ve tek renk
  /// alır; `*` işareti gri placeholder rengini MİRAS ALIYORDU.
  /// Bunun yerine `hint` WIDGET'ı kullanılır: etiket gri kalır,
  /// yıldız bağımsız olarak `RC.requiredStar` (#FF4D4F) çizilir.
  InputDecoration _dec(String label, String icon, {Widget? suffix}) =>
      InputDecoration(
        hint: _hintYildizli(label),
        filled: true,
        fillColor: RC.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 12, 0),
          child: RefSvg(icon, size: 20, color: const Color(0xFF4A5568)),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 47, minHeight: 22),
        suffixIcon: suffix,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 24),
        border: _cerceve(RC.borderLight),
        enabledBorder: _cerceve(RC.borderLight),
        focusedBorder: _cerceve(RC.blue),
        errorBorder: _cerceve(RC.danger),
        focusedErrorBorder: _cerceve(RC.danger),
        errorStyle:
            refText(size: RF.s115, weight: RF.w600, color: RC.danger),
      );

  /// Seçim özeti: "Tesisat, Elektrik +2"
  ///
  /// ⚠ Ana forma chip DÖKÜLMEZ; tek satır özet gösterilir.
  String _ozet(Set<String> secilenler) {
    final l = secilenler.toList()..sort();
    if (l.length <= 2) {
      return l.join(', ');
    }
    return '${l.take(2).join(', ')} +${l.length - 2}';
  }

  /// Seçim çubuğunun altındaki açıklama satırı.
  Widget _altAciklama(String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 11),
        child: Text(metin,
            style: refText(
                size: RF.s125, weight: RF.w400, color: RC.textSoft)),
      );

  /// HİZMET KATEGORİLERİ — çoklu seçim.
  ///
  /// Seçimler `_cats` içinde tutulur; sheet kapanınca, widget yeniden
  /// çizilince ve doğrulama sırasında KAYBOLMAZ.
  Future<void> _kategoriSec(BuildContext context) async {
    final sonuc = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      // ── ⚠ DÜZ LİSTE DEĞİL, ARAMA TABANLI SEÇİM ──
      //
      // Rol Değiştir ve Hizmet Kategorilerim ekranlarıyla AYNI panel.
      // Eskiden 53 ana kategori onay kutusu listesiydi; kullanıcı ALT
      // HİZMET seçemiyor, "Kombi Servis" diyen usta iki alt hizmetin
      // tamamına bağlanıyordu.
      //
      // ⚠ ANA KATEGORİ SAYI SINIRI YOKTUR.
      builder: (_) => KategoriSecimPaneli(baslangic: _cats),
    );
    if (sonuc != null && mounted) {
      setState(() {
        _cats
          ..clear()
          ..addAll(sonuc);
        _chipsError = null;
      });
      // Sağlayıcı için kategori de ZORUNLU alandır — bkz. bölge notu.
      _tazele();
    }
  }

  /// HİZMET VERİLEN İLÇELER — çoklu seçim + "Tüm İlçeler".
  ///
  /// "Tüm İlçeler" ayrı bir değer DEĞİLDİR: ildeki tüm ilçeleri
  /// işaretler. Böylece mevcut iş kuralı (hizmet bölgesi listesi)
  /// değişmeden korunur.
  Future<void> _ilceSecCoklu(BuildContext context) async {
    final sonuc = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      // ⚠ Controller state'i DİNLENİR: bölge verisi sonradan gelirse
      // liste kendiliğinden dolar (boş "Sonuç bulunamadı" oluşmaz).
      builder: (_) => Consumer<RegionController>(
        builder: (_, r, __) => RefMultiSelectSheet(
          title: 'Hizmet Verilen İlçeler',
          options: r.districtsOf(_city),
          initial: _provDistricts,
          tumuEtiketi: 'Tüm İlçeler',
        ),
      ),
    );
    if (sonuc != null && mounted) {
      setState(() {
        _provDistricts
          ..clear()
          ..addAll(sonuc);
        _chipsError = null;
      });
      // ⚠ Sağlayıcı için bölge seçimi ZORUNLU alandır; düğme bildirimi
      // tazelenmezse "Devam Et" pasif kalır.
      _tazele();
    }
  }

  /// Etiket + KIRMIZI yıldız.  /// Etiket + KIRMIZI yıldız.
  ///
  /// `'Ad *'` → gri "Ad" + `#FF4D4F` "*"
  Widget _hintYildizli(String label) {
    final zorunlu = label.trimRight().endsWith('*');
    final metin = zorunlu
        ? label.trimRight().substring(0, label.trimRight().length - 1).trimRight()
        : label;
    final gri = refText(
        size: RF.s15,
        weight: RF.w500,
        color: RC.greyLight,
        letterSpacing: RF.lsM01);
    if (!zorunlu) {
      return Text(metin, style: gri, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: gri, children: [
        TextSpan(text: '$metin '),
        TextSpan(
          text: '*',
          style: refText(
              size: RF.s15, weight: RF.w700, color: RC.requiredStar),
        ),
      ]),
    );
  }

  OutlineInputBorder _cerceve(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(RR.r13),
        borderSide: BorderSide(color: c, width: 1.5),
      );

  @override
  // ── GÖRÜNÜM: referans `vRegStep1()` ──
  //   .rg-back  ·  .rg-title (25px/700, ls -.3)  ·  rgStepper(1)
  // ⚠ Referansta AppBar YOKTUR.
  @override
  void initState() {
    super.initState();
    // ── AD/SOYAD BİÇİMİ ODAK KAYBINDA UYGULANIR ──
    //
    // ⚠ Yazarken biçimlendirmek silmeyi bozuyordu (bkz. `ad_bicimi`).
    // Kullanıcı alandan çıkınca metin bir kez düzeltilir.
    _fFirst.addListener(_adOdakDegisti);
    _fLast.addListener(_soyadOdakDegisti);

    // ── UYARI KAPISI: ALAN TERK EDİLDİ Mİ? ──
    //
    // Alan odaktan çıktığında "terk edildi" sayılır ve ancak o zaman
    // uyarısı görünür. Odağa geri dönüldüğünde uyarı gizlenir; böylece
    // düzeltmeye başlayan kullanıcı ilk tuşta kırmızı görmez.
    for (final e in <TextEditingController, FocusNode>{
      _first: _fFirst,
      _last: _fLast,
      _phone: _fPhone,
      _email: _fEmail,
      _pass: _fPass,
      _pass2: _fPass2,
    }.entries) {
      e.value.addListener(() {
        if (!mounted) {
          return;
        }
        if (!e.value.hasFocus) {
          setState(() => _terkEdilen.add(e.key));
        } else {
          // Yeniden odaklanınca uyarı gizlensin diye tek bir yeniden
          // çizim yeter; kayıt `_terkEdilen` içinde KALIR.
          setState(() {});
        }
      });
    }
  }

  void _adOdakDegisti() {
    if (!_fFirst.hasFocus) {
      adAlaniBicimle(_first);
    }
  }

  void _soyadOdakDegisti() {
    if (!_fLast.hasFocus) {
      adAlaniBicimle(_last);
    }
  }

  @override
  void dispose() {
    _fFirst.removeListener(_adOdakDegisti);
    _fLast.removeListener(_soyadOdakDegisti);
    _formGecerli.dispose();
    _alanlarGecerli.dispose();
    _fFirst.dispose();
    FocusIzle.temizle();
    _fLast.dispose();
    _fEmail.dispose();
    _fPhone.dispose();
    _fPass.dispose();
    _fPass2.dispose();
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _pass2.dispose();
    _hood.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RC.pageBg,
        // ⚠ TEŞHİS: bayrak kapalıyken `Stack` tek çocukla çizilir,
        // panel `SizedBox.shrink()` döner — davranış değişmez.
        body: Stack(children: [
          SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Form(
              // ── ⚠ UYARI NE ZAMAN GÖRÜNÜR? ──
              //
              // KURAL: kullanıcı alanı DOLDURUP ÇIKINCA uyarılır.
              // Yazarken — özellikle ilk harfte — uyarı GÖSTERİLMEZ.
              //
              // ⚠ `onUserInteraction` ve `onUnfocus` bu davranışı TEK
              // BAŞINA vermiyordu: alan bir kez doğrulandıktan sonra
              // kullanıcı geri dönüp düzeltmeye başladığında ilk tuşta
              // uyarı yeniden beliriyordu.
              //
              // Bu yüzden karar `_kural` içinde VERİLİR: doğrulama her
              // yeniden çizimde çalışır (`always`) ama alan ODAKTAYSA
              // ya da HENÜZ TERK EDİLMEMİŞSE `null` döner. Böylece
              // "hangi anda uyarılır" kararı çerçeveye değil bize ait
              // olur ve testle kilitlenebilir.
              autovalidateMode: AutovalidateMode.always,
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0, top: 4),
                    child:
                        RefBackButton(onTap: () => geriGit(context)),
                  ),
                ),
                const SizedBox(height: 6),
                // .rg-title
                // .rg-title — referans metinleri
                Text(
                  isProvider ? 'Hizmet Veren Kaydı' : 'Hizmet Alan Kaydı',
                  textAlign: TextAlign.center,
                  style: refText(
                    size: RF.s25,
                    weight: RF.w700,
                    color: RC.text,
                    letterSpacing: RF.lsM03,
                  ),
                ),
                const SizedBox(height: 8),
                // .rg-sub
                Text(
                  isProvider
                      ? 'Hizmet vermek için hesabınızı oluşturun ve hemen '
                          'başlayın.'
                      : 'Hizmet almak için hesabınızı oluşturun ve hemen '
                          'başlayın.',
                  textAlign: TextAlign.center,
                  style: refText(
                    size: RF.s145,
                    weight: RF.w400,
                    color: RC.textSoft,
                    height: RF.lh145,
                  ),
                ),
                const SizedBox(height: 22),
                const RefStepper(current: 1),
                const SizedBox(height: 18),
                TextFormField(
                  // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                  // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                  scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                  key: _adKey,
                  controller: _first,
                  focusNode: _fFirst,
                  onChanged: Teshis.noOnChanged
                      ? null
                      : (v) {
                          _tazele();
                          // Alan düzelince uyarı ANINDA kalkar.
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_adKey.currentState?.hasError ?? false) {
                            _adKey.currentState?.validate();
                          }
                        },
                  textInputAction: TextInputAction.next,
                  // NEXT GEÇİŞİ İÇİN DAVRANIŞ DÜZELTMESİ
                  //
                  // ⚠ KESİN KÖK NEDEN OLARAK İLAN EDİLMEMİŞTİR.
                  //
                  // Odak geçişi `onEditingComplete` ile yapılır.
                  // Gerekçe: bu geri çağrı verildiğinde Flutter'ın
                  // `_finalizeEditing` içindeki varsayılan yolu
                  // atlanır ve geçiş TEK adımda tamamlanır; ara
                  // durum oluşmaz.
                  //
                  // Gerçek cihazda gözlenen "klavye kapanıp tekrar
                  // açılıyor" davranışının bu değişiklikle çözülüp
                  // çözülmediği CI + cihaz testiyle DOĞRULANACAK.
                  onEditingComplete: () => _fLast.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  // ⚠ Baş harfler BÜYÜK — Türkçe duyarlı.
                  decoration: _dec('Ad *', 'assets/svg/ic_person.svg'),
                  validator: (v) => _kural(_first, v,
                      (x) => Validators.name(x, min: 3, label: 'ad')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                  // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                  scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                  key: _soyadKey,
                  controller: _last,
                  onChanged: Teshis.noOnChanged
                      ? null
                      : (v) {
                          _tazele();
                          // Alan düzelince uyarı ANINDA kalkar.
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_soyadKey.currentState?.hasError ?? false) {
                            _soyadKey.currentState?.validate();
                          }
                        },
                  focusNode: _fLast,
                  textInputAction: TextInputAction.next,
                  // NEXT GEÇİŞİ İÇİN DAVRANIŞ DÜZELTMESİ
                  //
                  // ⚠ KESİN KÖK NEDEN OLARAK İLAN EDİLMEMİŞTİR.
                  //
                  // Odak geçişi `onEditingComplete` ile yapılır.
                  // Gerekçe: bu geri çağrı verildiğinde Flutter'ın
                  // `_finalizeEditing` içindeki varsayılan yolu
                  // atlanır ve geçiş TEK adımda tamamlanır; ara
                  // durum oluşmaz.
                  //
                  // Gerçek cihazda gözlenen "klavye kapanıp tekrar
                  // açılıyor" davranışının bu değişiklikle çözülüp
                  // çözülmediği CI + cihaz testiyle DOĞRULANACAK.
                  onEditingComplete: () => _fPhone.requestFocus(),
                  textCapitalization: TextCapitalization.words,
                  // ⚠ Baş harfler BÜYÜK — Türkçe duyarlı.
                  decoration: _dec('Soyad *', 'assets/svg/ic_person.svg'),
                  validator: (v) => _kural(_last, v,
                      (x) => Validators.name(x, min: 2, label: 'soyad')),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                  // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                  scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                  key: _telefonKey,
                  controller: _phone,
                  onChanged: Teshis.noOnChanged
                      ? null
                      : (v) {
                          _tazele();
                          // Alan düzelince uyarı ANINDA kalkar.
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_telefonKey.currentState?.hasError ?? false) {
                            _telefonKey.currentState?.validate();
                          }
                        },
                  focusNode: _fPhone,
                  textInputAction: TextInputAction.next,
                  // NEXT GEÇİŞİ İÇİN DAVRANIŞ DÜZELTMESİ
                  //
                  // ⚠ KESİN KÖK NEDEN OLARAK İLAN EDİLMEMİŞTİR.
                  //
                  // Odak geçişi `onEditingComplete` ile yapılır.
                  // Gerekçe: bu geri çağrı verildiğinde Flutter'ın
                  // `_finalizeEditing` içindeki varsayılan yolu
                  // atlanır ve geçiş TEK adımda tamamlanır; ara
                  // durum oluşmaz.
                  //
                  // Gerçek cihazda gözlenen "klavye kapanıp tekrar
                  // açılıyor" davranışının bu değişiklikle çözülüp
                  // çözülmediği CI + cihaz testiyle DOĞRULANACAK.
                  onEditingComplete: () => _fEmail.requestFocus(),
                  keyboardType: TextInputType.number,
                  // ⚠ TEK KURAL KAYNAĞI — bkz. `TelefonBicimlendirici`.
                  // Baştaki `0` elle yazılamaz, otomatik atanır; `5` ile
                  // başlamayan numara alana hiç girmez. Sunucuya giden
                  // değer `phoneFmt` ile 10 haneye normalize edilir
                  // (backend sözleşmesi değişmez).
                  inputFormatters: const [TelefonBicimlendirici()],
                  // Referans `rgPhone()`: `+90` ve aşağı ok alanın
                  // SAĞINDADIR (`.rg-cc{border-left:1.5px solid #E7EAEF}`).
                  // Sol tarafta yalnız `.rg-ic` alan ikonu bulunur;
                  // ülke kodu sol ek olarak üretilmez.
                  decoration: _dec(
                    // ⚠ Yalnız ÖRNEK BİÇİM yazar. "Telefon Numaranız"
                    // ifadesi kaldırıldı: satırda zaten telefon ikonu ve
                    // kırmızı zorunluluk yıldızı var, metin tekrar oluyordu.
                    // ⚠ `+90` ÜLKE KODU KUTUSU KALDIRILDI.
                    //
                    // Tek ülkede hizmet verildiği için seçim yoktu;
                    // dokunulunca yalnız "şimdilik +90" mesajı çıkan
                    // sahte bir açılır kutuydu. Numara zaten `0` ile
                    // başlayan yerel biçimde alınıyor.
                    '5XX XXX XX XX *',
                    'assets/svg/ic_phone.svg',
                  ),
                  validator: (v) => _kural(_phone, v, Validators.phone),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                  // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                  scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                  key: _epostaKey,
                  controller: _email,
                  onChanged: Teshis.noOnChanged
                      ? null
                      : (v) {
                          _tazele();
                          // Alan düzelince uyarı ANINDA kalkar.
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_epostaKey.currentState?.hasError ?? false) {
                            _epostaKey.currentState?.validate();
                          }
                        },
                  focusNode: _fEmail,
                  textInputAction: TextInputAction.next,
                  // NEXT GEÇİŞİ İÇİN DAVRANIŞ DÜZELTMESİ
                  //
                  // ⚠ KESİN KÖK NEDEN OLARAK İLAN EDİLMEMİŞTİR.
                  //
                  // Odak geçişi `onEditingComplete` ile yapılır.
                  // Gerekçe: bu geri çağrı verildiğinde Flutter'ın
                  // `_finalizeEditing` içindeki varsayılan yolu
                  // atlanır ve geçiş TEK adımda tamamlanır; ara
                  // durum oluşmaz.
                  //
                  // Gerçek cihazda gözlenen "klavye kapanıp tekrar
                  // açılıyor" davranışının bu değişiklikle çözülüp
                  // çözülmediği CI + cihaz testiyle DOĞRULANACAK.
                  // ⚠ ODAK ZİNCİRİ BOZULMAZ: e-postadan sonra ŞİFREYE
                  // geçilir.
                  //
                  // Bir ara denemede burada odak DÜŞÜRÜLÜP İL satırına
                  // kaydırılıyordu. Bu, projenin KLAVYE STANDARDINI
                  // ihlal ediyor: kullanıcı yazarken klavye
                  // kendiliğinden kapanmaz (bkz. `klavye_standardi_test`
                  // madde 4 ve 5). Kural geri alındı.
                  //
                  // ⚠ Testler kaynak metni tarar: bu dosyada odak
                  // düşürme çağrısının ADI bile geçmemelidir.
                  //
                  // Adres satırları odak alamaz; onların zinciri
                  // SEÇİM sonrası kaydırmayla yürür (il→ilçe→mahalle→
                  // şifre) ve klavyeye dokunmaz.
                  onEditingComplete: () => _fPass.requestFocus(),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('E-posta *', 'assets/svg/ic_mail.svg'),
                  validator: (v) => _kural(_email, v, Validators.email),
                ),
                // ⚠ ÖNERİ SATIRI KALDIRILDI.
                //
                // "Şunu mu demek istediniz: …@hotmail.com" satırı hem
                // kullanıcının adresini TAHMİN ediyordu hem de girilen
                // adresin hangi sağlayıcıya benzediğini ekrana yazarak
                // omuz üstünden okuyana bilgi sızdırıyordu.
                //
                // Yazım hatası artık `Validators.email` tarafından
                // GENEL bir uyarıyla reddedilir; doğru adresi kullanıcı
                // kendisi yazar. Profil ekranında da aynı kural geçerli.
                const SizedBox(height: 12),

                if (!isProvider) ...[
                  // ── İl / İlçe / Mahalle ──
                  //
                  // Referans `rgDrop()`: üçü de AYNI `.rg-f` kutu
                  // ailesini kullanır. Alt çizgili Material görünümü
                  // veya farklı üç stil KULLANILMAZ.
                  //
                  // Kontrollü seçim korunur: serbest metin yok,
                  // ilçe seçilmeden mahalle açılmaz.
                  // ⚠ İL GERÇEK SEÇİM ALANIDIR — hard-code YOKTUR.
                  // Aktif iller sunucudan gelir; bugün mock veride
                  // yalnız İzmir vardır, yeni il eklenince aynı alan
                  // onu kendiliğinden gösterir.
                  Builder(builder: (_) {
                    // ⚠ TEŞHİS E3: bölge bildirimlerinin odak üzerindeki
                    // etkisini izole etmek için `watch` yerine tek
                    // seferlik okuma kullanılır.
                    // ⚠ Otomatik seçim YOK — bkz. didChangeDependencies
                    // notu. Controller yalnız DİNLENİR: aktif il listesi
                    // sunucudan gelince alan tazelenir, ama değeri
                    // kullanıcının seçimi belirler.
                    if (Teshis.staticRegion) {
                      context.read<RegionController>();
                    } else {
                      context.watch<RegionController>();
                    }
                    return RefRegDropdown(
                      key: _ilKaydirKey,
                      iconAsset: 'assets/svg/ic_pin.svg',
                      label: 'İl',
                      value: _city,
                      onTap: () => _ilSec(context),
                    );
                  }),
                  RefRegDropdown(
                    key: _ilceKaydirKey,
                    iconAsset: 'assets/svg/ic_build.svg',
                    label: 'İlçe',
                    value: _district,
                    // ⚠ İL SEÇİLMEDEN İLÇE AÇILMAZ (mahalle zinciriyle
                    // aynı kural). Kısıt metinle yazılmaz.
                    onTap: _city == null ? null : () => _ilceSec(context),
                  ),
                  RefRegDropdown(
                    key: _mahalleKaydirKey,
                    iconAsset: 'assets/svg/ic_home2.svg',
                    label: 'Mahalle',
                    value: _hood.text.isEmpty ? null : _hood.text,
                    // İlçe seçilmeden mahalle AÇILMAZ.
                    onTap: _district == null ? null : () => _mahalleSec(context),
                  ),
                ] else ...[
                  // ── HİZMET VEREN: TEK SEÇİM ÇUBUKLARI ──
                  //
                  // ⚠ Referans `rgPickRow()` / `rgDrop()`: kategoriler ve
                  // ilçeler ANA FORMA chip olarak DÖKÜLMEZ. Ana formda
                  // yalnız tek satır özet bulunur; seçim alttan açılan
                  // çoklu seçim sayfasında yapılır.
                  RefRegDropdown(
                    iconAsset: 'assets/svg/ic_grid.svg',
                    label: 'Hizmet Kategorileri',
                    value: _cats.isEmpty ? null : _ozet(_cats),
                    onTap: () => _kategoriSec(context),
                  ),
                  _altAciklama(FormMesaj.kategoriSec),

                  Builder(builder: (_) {
                    // ⚠ TEŞHİS E3: bölge bildirimlerinin odak üzerindeki
                    // etkisini izole etmek için `watch` yerine tek
                    // seferlik okuma kullanılır.
                    // ⚠ Otomatik seçim YOK — bkz. didChangeDependencies notu.
                    if (Teshis.staticRegion) {
                      context.read<RegionController>();
                    } else {
                      context.watch<RegionController>();
                    }
                    return RefRegDropdown(
                      iconAsset: 'assets/svg/ic_pin.svg',
                      label: 'Hizmet Verilen İl',
                      value: _city,
                      onTap: () => _ilSec(context),
                    );
                  }),

                  RefRegDropdown(
                    iconAsset: 'assets/svg/ic_build.svg',
                    label: 'Hizmet Verilen İlçeler',
                    value: _provDistricts.isEmpty
                        ? null
                        : _ozet(_provDistricts),
                    // ⚠ İL SEÇİLMEDEN İLÇE AÇILMAZ.
                    onTap: _city == null ? null : () => _ilceSecCoklu(context),
                  ),
                  _altAciklama('Bir veya birden fazla ilçe seçebilirsiniz.'),

                  if (_chipsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(_chipsError!,
                          style: refText(
                              size: RF.s115,
                              weight: RF.w600,
                              color: RC.danger)),
                    ),
                ],
                const SizedBox(height: 12),

                TextFormField(
                  // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                  // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                  scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                  key: _sifreKey,
                  controller: _pass,
                  onChanged: Teshis.noOnChanged
                      ? null
                      : (v) {
                          _tazele();
                          // Alan düzelince uyarı ANINDA kalkar.
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_sifreKey.currentState?.hasError ?? false) {
                            _sifreKey.currentState?.validate();
                          }
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_sifre2Key.currentState?.hasError ?? false) {
                            _sifre2Key.currentState?.validate();
                          }
                        },
                  focusNode: _fPass,
                  textInputAction: TextInputAction.next,
                  // NEXT GEÇİŞİ İÇİN DAVRANIŞ DÜZELTMESİ
                  //
                  // ⚠ KESİN KÖK NEDEN OLARAK İLAN EDİLMEMİŞTİR.
                  //
                  // Odak geçişi `onEditingComplete` ile yapılır.
                  // Gerekçe: bu geri çağrı verildiğinde Flutter'ın
                  // `_finalizeEditing` içindeki varsayılan yolu
                  // atlanır ve geçiş TEK adımda tamamlanır; ara
                  // durum oluşmaz.
                  //
                  // Gerçek cihazda gözlenen "klavye kapanıp tekrar
                  // açılıyor" davranışının bu değişiklikle çözülüp
                  // çözülmediği CI + cihaz testiyle DOĞRULANACAK.
                  onEditingComplete: () => _fPass2.requestFocus(),
                  obscureText: _obscure,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null, // sayaç gösterilmez (HTML'de yok)
                  decoration: _dec('Şifre *', 'assets/svg/ic_plock.svg',
                      suffix: RefSifreGozu(
                        gizli: _obscure,
                        onDegisti: (g) => setState(() => _obscure = g),
                      )),
                  validator: (v) => _kural(_pass, v, Validators.password),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                  // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                  scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                  key: _sifre2Key,
                  controller: _pass2,
                  onChanged: Teshis.noOnChanged
                      ? null
                      : (v) {
                          _tazele();
                          // Alan düzelince uyarı ANINDA kalkar.
                          // ⚠ YAZARKEN UYARI ÇIKARILMAZ, YALNIZ TEMİZLENİR.
                          //
                          // Önceki hâl her tuşta doğruluyordu: kullanıcı "O" yazar
                          // yazmaz "en az 3 harf" uyarısı beliriyordu. Alan boşalınca
                          // da `reset()` çağrılıyor, bu denetleyicinin metnini YENİDEN
                          // YAZDIĞI için silme tuşu takılıyordu.
                          //
                          // Artık yalnız GÖRÜNEN bir hata varsa yeniden doğrulanır:
                          // düzelen alanın uyarısı anında kalkar, yazarken yeni uyarı
                          // çıkmaz. Zorunluluk odak kaybında ve gönderimde denetlenir.
                          if (_sifre2Key.currentState?.hasError ?? false) {
                            _sifre2Key.currentState?.validate();
                          }
                        },
                  focusNode: _fPass2,
                  textInputAction: TextInputAction.done,
                  // ⚠ SON ALAN BİTİNCE SÖZLEŞMEYE KAYDIRILIR.
                  //
                  // Klavye kapanır ve ekranın altında kalan onay kutusu
                  // görünür alana gelir; kullanıcı formu bitirdikten
                  // sonra "devam düğmesi neden pasif?" sorusuyla baş
                  // başa kalmaz.
                  onFieldSubmitted: (_) => _gorunurYap(_sozlesmeKaydirKey),
                  obscureText: _obscure2,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  decoration: _dec(
                      'Şifre tekrar *', 'assets/svg/ic_plock.svg',
                      suffix: RefSifreGozu(
                        gizli: _obscure2,
                        onDegisti: (g) => setState(() => _obscure2 = g),
                      )),
                  // Kurallar ŞİFRE alanında denetlenir; burada tek
                  // soru "aynı mı?".
                  validator: (v) => _kural(_pass2, v,
                      (x) => Validators.passwordRepeat(x, _pass.text)),
                ),
                const SizedBox(height: 8),
                // `.rg-agree` — GERÇEK onay kutusu + mavi yasal bağlantılar
                ValueListenableBuilder<bool>(
                  key: _sozlesmeKaydirKey,
                  valueListenable: _alanlarGecerli,
                  builder: (_, alanlarTamam, __) => RefAgreeRow(
                  // ⚠ Zorunlu alanlar bitmeden işaretlenemez.
                  enabled: alanlarTamam,
                  value: _agree,
                  // ⚠ `_tazele()` ZORUNLU.
                  //
                  // "Devam Et" düğmesi `_formGecerli` bildirimini
                  // dinler; `setState` o bildirimi GÜNCELLEMEZ. Bu
                  // çağrı olmadan sözleşme işaretlense bile düğme
                  // pasif kalıyordu — 2. adıma hiç geçilemiyordu.
                  onChanged: (v) {
                    setState(() => _agree = v);
                    _tazele();
                  },
                  parts: [
                    (
                      text: 'Kullanım sözleşmesi',
                      onTap: () => Navigator.pushNamed(context, '/legal',
                          arguments: {
                            'slug': 'terms',
                            'title': 'Kullanım Koşulları'
                          }),
                    ),
                    (text: ' ve ', onTap: null),
                    (
                      text: 'gizlilik politikasını',
                      onTap: () => Navigator.pushNamed(context, '/legal',
                          arguments: {
                            'slug': 'privacy',
                            'title': 'Gizlilik Politikası'
                          }),
                    ),
                    (text: ' okudum, kabul ediyorum.', onTap: null),
                  ],
                  ),
                ),
                const SizedBox(height: 8),
                // `.rg-primary` — referans metni "Devam Et"
                // ⚠ Eksik/geçersiz veriyle ilerleme YOK.
                // Yalnız BU buton yeniden çizilir; form ağacı sabit.
                ValueListenableBuilder<bool>(
                  valueListenable: _formGecerli,
                  builder: (_, gecerli, __) => RefPrimaryButton('Devam Et',
                      busy: _busy, onPressed: gecerli ? _next : null),
                ),

                // `.rg-or` + `.rg-google` — kayıt akışında da bulunur
                //
                // ⚠ iOS'TA GÖSTERİLMEZ (App Store kuralı 4.8 — bkz.
                // lib/core/platform_kapilari.dart). Ayırıcı ile düğme
                // BİRLİKTE gizlenir; sahipsiz "veya" çizgisi kalmaz.
                //
                // ⚠ ANDROID'DE HİÇBİR ŞEY DEĞİŞMEZ.
                if (googleGirisiGosterilir) ...[
                  const RefOrDivider(),
                  RefSecondaryButton(
                    'Google ile Devam Et',
                    iconAsset: 'assets/svg/ic_google.svg',
                    busy: _busyGoogle,
                    onPressed: _busy ? null : _googleIleDevam,
                  ),
                ],
              ]),
            ),
          ),
        ),
          const TeshisPaneli(),
        ]),

      );

}
