import 'dart:io';
import '../data/services/search_service.dart';
import '../domain/form_mesajlari.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../data/controllers/auth_controller.dart';
import '../domain/cikar_catismasi.dart';
import '../data/remote/api_config.dart';
import '../data/services/otp_service.dart';
// `Role` enum'ı burada tanımlıdır; `auth_controller` onu EXPORT
// ETMEDİĞİ için geçişli çözülmez, doğrudan import gerekir.
import '../data/models/account.dart';
import '../data/controllers/listing_controller.dart';
import '../data/remote/api/storage_api.dart';
import '../data/remote/api_client.dart';
import 'widgets/photo_picker.dart';
import '../data/controllers/region_controller.dart';
import '../data/izmir.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';
import '../data/models/pending_listing.dart';
import '../data/controllers/pending_listing_controller.dart';
import 'role_select_screen.dart';
import '../core/geri.dart';
import '../data/category_tree.dart';
import '../domain/config.dart';
import '../data/controllers/profile_controller.dart';
import 'widgets/ilan_kayit_adimi.dart';
import 'widgets/ilan_otp_adimi.dart';
import '../core/validators.dart';
import '../core/teshis.dart';

/// Müşteri — İlan Oluştur 3 adım (HTML vPost):
/// 1 Kategori Seç · 2 Açıklama (en az 5 kelime) + konum · 3 Önizle & Yayınla.
/// İlan vermek ÜCRETSİZ ve SINIRSIZDIR (müşteri hiçbir aşamada ödemez).
class CreateListingScreen extends StatefulWidget {
  final String? initialCategory; // arama/kategori akışından önseçim

  /// Seçilen alt hizmet (ör. "Kombi Bakımı"). İlan başlığı olur.
  final String? initialSubService;

  /// KAYIT ÖNCESİ MOD
  ///
  /// ⚠ `true` iken kullanıcı OTURUMSUZDUR:
  ///   • fotoğraflar backend'e YÜKLENMEZ (yetki yok), yalnız cihaz
  ///     yolları taslakta tutulur,
  ///   • "Yayınla" ilanı YAYINLAMAZ; taslağı kaydedip Hizmet Alan
  ///     kayıt/doğrulama akışına geçer.
  ///
  /// Form ve görünüm AYNIDIR; yalnız yayınlama dalı değişir.
  final bool preLogin;

  const CreateListingScreen({
    super.key,
    this.initialCategory,
    this.initialSubService,
    this.preLogin = false,
  });
  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  /// Görünen adım.
  ///
  /// ⚠ Ana sayfa aramasından veya kategori ekranından gelindiğinde
  /// hizmet ZATEN SEÇİLMİŞTİR; kullanıcı aynı seçimi tekrar yapmaz.
  /// Bu durumda akış doğrudan Açıklama adımıyla başlar
  /// (bkz. `initState` ve `_kategoriOnSecili`).
  int _step = 1;

  /// Kategori dışarıdan geldi mi? (kategori seçim adımı atlanır)
  bool get _kategoriOnSecili =>
      (widget.initialCategory ?? '').trim().isNotEmpty;
  String _catQuery = '';

  /// Kategori arama alanı — seçim yapılınca metni güncellenir.
  final _aramaCtl = TextEditingController();

  /// ⚠ OTURUMSUZ AKIŞ: kayıt ve SMS doğrulama bu ekranın İÇİNDEDİR.
  /// Referans akış: 1 Kategori · 2 İlan Bilgileri · 3 Kayıt · 4 SMS.
  final _kayit = KayitVerisi();
  final _otp = OtpVerisi();
  String? _cat;

  @override
  void initState() {
    super.initState();
    // Bölge verisi henüz yüklenmediyse yükle (lazy provider).
    WidgetsBinding.instance.addPostFrameCallback(
        (_) {
      final r = context.read<RegionController>();
      r.load();
      if (mounted) {
        setState(() => _city ??= r.soleCityName);
      }
    });
    // ⚠ ALT HİZMET VARSA SEÇİM ODUR.
    //
    // Önceden yalnız `initialCategory` alınıyordu; ana sayfadan
    // "Kombi Montajı" seçildiğinde ekranda kategori adı ("Doğalgaz")
    // görünüyordu. Ekran İÇİ arama zaten `altHizmet ?? kategori`
    // kullanıyordu — iki yol AYNI kurala getirildi.
    _cat = widget.initialSubService ?? widget.initialCategory;
    // ⚠ HİZMET ÖNCEDEN SEÇİLDİYSE KATEGORİ ADIMI GÖSTERİLMEZ.
    //
    // Ana sayfa aramasından gelen kullanıcı seçimini zaten yapmıştır;
    // aynı seçim tekrar sorulmaz. Akış doğrudan Açıklama ile başlar.
    // Gösterge yine 3 adımlıdır ve ilk adım TAMAMLANMIŞ görünür.
    if (_kategoriOnSecili) {
      _aramaCtl.text = widget.initialSubService ?? widget.initialCategory!;
      _catQuery = _aramaCtl.text;
      _step = 2;
    }

    // Oturumlu kullanıcıda konum PROFİL ADRESİNDEN gelir; adım 2'de
    // tekrar sorulmaz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // ⚠ GÜVENLİ OKUMA: `ProfileController` her widget ağacında
      // bulunmayabilir (ör. yalnız bu ekranı kuran testler).
      // Sağlanmadığında ekran ÇÖKMEZ; konum kayıt akışından gelir.
      Address? adres;
      try {
        adres = context.read<ProfileController>().address;
      } on ProviderNotFoundException catch (_) {
        adres = null;
      }
      // ⚠ `setState` closure'ı içinde tip daralması KORUNMAZ:
      // `adres` yeniden atanabilir yerel değişkendir. Bu yüzden
      // `final` kopya alınır.
      final a = adres;
      if (a != null && _district == null) {
        setState(() {
          _district = a.district.isEmpty ? null : a.district;
          if (a.neighborhood.isNotEmpty) {
            _hood.text = a.neighborhood;
          }
        });
      }
    });
    // ⚠ TEŞHİS: iki AKIŞ ayrı etiketlenir; sonuçlar karışmaz.
    //   preLogin=true  → /listing/new          (kayıtsız hazırlama)
    //   preLogin=false → /customer/new-listing (kayıtlı ilan)
    FocusIzle.aktifRoute =
        widget.preLogin ? '/listing/new' : '/customer/new-listing';

    _storageApi = StorageApi(context.read<ApiClient>());
  }
  final _desc = TextEditingController();
  String? _district;
  final _hood = TextEditingController();

  /// Seçili il — sunucudan gelen aktif iller arasından belirlenir.
  /// ⚠ HARD-CODE DEĞİLDİR. Bu ekranda ayrı il seçici bulunmaz;
  /// tek aktif il varsa o kullanılır (bkz. `soleCityName`).
  String? _city;
  String? _locError;
  bool _busy = false;

  /// Seçilen ilan fotoğrafları. İlan YAYINLANMADAN ÖNCE hepsinin
  /// yüklenmiş (storageRef almış) olması gerekir.
  final List<PhotoItem> _photos = [];

  /// dispose sırasında context okunamayacağı için erken saklanır.
  late final StorageApi _storageApi;

  /// Yükleme devam ediyor mu?
  bool get _photosUploading => _photos.any((p) => p.uploading);

  /// Yüklenemeyen fotoğraf var mı?
  bool get _photosFailed => _photos.any((p) => !p.isUploaded && !p.uploading);

  /// İlan yayınlandı mı? Yayınlandıysa fotoğraflar ATTACHED olur ve
  /// ekran kapanırken iptal EDİLMEZ.
  bool _published = false;

  @override
  void dispose() {
    _aramaCtl.dispose();
    _kayit.dispose();
    _otp.dispose();
    // YARIM UPLOAD TEMİZLİĞİ (best-effort): ilan yayınlanmadıysa
    // sunucudaki BEKLEYEN yüklemeler iptal edilir. Başarısız olanları
    // sunucudaki zamanlayıcı yedek olarak temizler.
    if (!_published) {
      final refs = _photos
          // ⚠ YEREL referans sunucuda yok; iptal edilemez.
          .where((p) => p.isUploaded && !p.attached && !p.yerelRef)
          .map((p) => p.storageRef!)
          .toList(growable: false);
      if (refs.isNotEmpty) {
        // Ekran kapandığı için sonuç beklenmez; hatalar yutulur.
        unawaited(_discardRefs(refs));
      }
    }
    _photos.removeWhere((p) => !p.isUploaded);
    _desc.dispose();
    _hood.dispose();
    super.dispose();
  }

  /// Ekran kapandıktan sonra da çalışabilmesi için context'ten bağımsız.
  Future<void> _discardRefs(List<String> refs) async {
    // ⚠ Mock modda referans YEREL YOLDUR; sunucuya iptal isteği
    // göndermek anlamsız ve ağ çağrısı yasak.
    if (!ApiConfig.useRealApi) {
      return;
    }
    for (final ref in refs) {
      try {
        await _storageApi.discardPending(ref);
      } catch (_) {
        // Zamanlayıcı yedek güvenlik ağıdır.
      }
    }
  }

  /// Alt buton etiketi — adıma ve role göre.
  String _butonEtiketi() {
    if (!widget.preLogin) {
      return _step < 3 ? 'Devam Et' : 'İlanı Yayınla';
    }
    return switch (_step) {
      1 || 2 => 'Devam Et',
      3 => 'Kaydı Tamamla',
      _ => 'Doğrula ve Yayınla',
    };
  }

  /// Buton pasif mi? Eksik/geçersiz veriyle ilerleme YOKTUR.
  bool get _butonKilitli {
    // ⚠ Adım 2 her iki akışta da açıklama yeterli olmadan geçilmez.
    if (_step == 2 && _kelimeSayisi() < kMinAciklamaKelime) {
      return true;
    }
    if (!widget.preLogin) {
      return false;
    }
    return switch (_step) {
      2 => _kelimeSayisi() < kMinAciklamaKelime,
      3 => !_kayit.tamam,
      4 => !_otp.tamam,
      _ => false,
    };
  }

  /// ── KAYIT + SMS DOĞRULAMA + YAYIN ──
  ///
  /// ⚠ TEK ÇAĞRI: hesap `otpVerified: true` ile oluşturulur, ardından
  /// taslak ilan bir kez yayınlanır. Çift yayın koruması
  /// `PendingListingController` içindedir.
  Future<void> _kaydolVeYayinla() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthController>();
      final r = await auth.register(
        phone: Validators.phoneFmt(_kayit.telefon.text),
        pass: _kayit.sifre.text,
        role: Role.customer,
        otpVerified: true,
        otpCode: _otp.kod,
        name: _kayit.adSoyad,
        email: _kayit.eposta.text.trim(),
        termsAccepted: _kayit.sozlesme,
      );
      if (!mounted) {
        return;
      }
      if (r.error != null || r.account == null) {
        // ⚠ SUNUCUNUN GEREKÇESİ GİZLENMEZ.
        //
        // API modunda SMS kodunu kayıt ucu doğrular; kod yanlışsa hata
        // buradan döner. Eskiden hepsi "bilgilerinizi kontrol edin"
        // diye tek mesaja indirgeniyor, kullanıcı neyi düzelteceğini
        // bilemiyordu. Kod hatası ARTIK kutuların altında görünür.
        final mesaj = r.error?.message ?? '';
        final kodHatasi = mesaj.toLowerCase().contains('kod') ||
            mesaj.toLowerCase().contains('otp') ||
            mesaj.toLowerCase().contains('doğrula');
        setState(() {
          _busy = false;
          if (kodHatasi) {
            _step = 4;
            _otp.hata = mesaj;
          }
        });
        if (!kodHatasi) {
          sysToastErr(context, SysKind.genericError,
              extra: mesaj.isEmpty
                  ? 'Kayıt tamamlanamadı — bilgilerinizi kontrol edin'
                  : mesaj);
        }
        return;
      }

      // Adres kaydı — ilan konumu buradan gelir.
      //
      // ⚠ İL SABİT DEĞİLDİR — kullanıcının kayıt formunda SEÇTİĞİ il
      // kullanılır. Seçim bir nedenle boşsa aktif il listesine,
      // o da yoksa `kCity` yedeğine düşülür.
      final il = _kayit.il ??
          context.read<RegionController>().cityName ??
          kCity;
      await context.read<ProfileController>().saveAddress(
            district: _kayit.ilce!,
            neighborhood: _kayit.mahalle!,
            city: il,
          );
      if (!mounted) {
        return;
      }

      // İlanı yayınla.
      final ok = await _ilaniYayinla(r.account!.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (ok) {
          _step = 5;
        }
      });
      if (!ok) {
        sysToastErr(context, SysKind.genericError,
            extra: 'İlan yayınlanamadı — İlanlarım ekranından '
                'tekrar deneyebilirsiniz');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        sysToastErr(context, SysKind.genericError);
      }
    }
  }

  /// Fotoğrafları yükleyip ilanı oluşturur.
  Future<bool> _ilaniYayinla(String ownerId) async {
    // ⚠ BAĞIMLILIKLAR `await`'TEN ÖNCE ALINIR.
    //
    // Aşağıdaki fotoğraf döngüsü her dosya için ağ çağrısı yapar;
    // uzun sürer. Kullanıcı bu sırada geri çıkarsa widget ağaçtan
    // kalkar ve `context.read` şu hatayı verir:
    //
    //   Looking up a deactivated widget's ancestor is unsafe
    //
    // Controller referansları burada alınınca `await` sonrası
    // `context`'e HİÇ dokunulmaz.
    final listingCtl = context.read<ListingController>();
    final sehir = context.read<RegionController>().cityName ?? kCity;
    final refs = <String>[];
    for (final foto in _photos) {
      // ⚠ MOCK MODDA SUNUCUYA YÜKLEME YOKTUR.
      //
      // `createUploadRef` bir HTTP çağrısıdır; backend bağlı
      // olmadığında hata fırlatır, aşağıdaki `catch` bunu YUTAR ve
      // `refs` BOŞ kalırdı — ilan fotoğrafsız yayınlanıyordu.
      // Mock modda dosyanın YEREL YOLU doğrudan referans olarak
      // kullanılır; ekranlar zaten yerel yolu çizebiliyor.
      if (!ApiConfig.useRealApi) {
        refs.add(foto.localPath);
        continue;
      }
      try {
        // ⚠ Gerçek imza: kind / contentType / sizeBytes → Map döner.
        final res = await _storageApi.createUploadRef(
          kind: 'listing-photo',
          contentType: 'image/jpeg',
          sizeBytes: await File(foto.localPath).length(),
        );
        final ref = res['storageRef'] as String? ?? res['ref'] as String?;
        if (ref != null && ref.isNotEmpty) {
          refs.add(ref);
        }
      } catch (_) {
        // Fotoğraf yüklenemezse ilan yine de yayınlanır.
      }
    }
    final r = await listingCtl.publish(
          ownerId: ownerId,
          title: _cat!,
          location: '${_kayit.mahalle}, ${_kayit.ilce} / '
              '${_kayit.il ?? sehir}',
          desc: _desc.text.trim(),
          photoPaths: refs,
        );
    return r.error == null;
  }

  /// KATEGORİ SEÇİMİ — ÇIKAR ÇATIŞMASI BURADA YAKALANIR.
  ///
  /// ⚠ ESKİDEN GEÇ SÖYLENİYORDU. Kural yalnız portta vardı: kullanıcı
  /// kategoriyi seçiyor, açıklamayı yazıyor, fotoğraf ekliyor ve
  /// ancak YAYINLA'ya bastığında "bu kategoride ilan açamazsınız"
  /// hatasını alıyordu. Emek boşa gidiyordu.
  ///
  /// Artık kural seçim ANINDA uygulanır: çatışan karta dokunmak
  /// seçim YAPMAZ, gerekçeyi hemen söyler. Port denetimi KALDIRILMADI
  /// (ikinci savunma).
  ///
  /// ⚠ Kural TEK KAYNAKTAN gelir: `lib/domain/cikar_catismasi.dart`.
  void _kategoriSec(String ad) {
    final me = context.read<AuthController>().currentAccount;
    final catisan = me == null
        ? null
        : catisanKategori(
            saglayiciSecimleri: me.categories, ilanBasligi: ad);
    if (catisan != null) {
      sysToastErr(context, SysKind.genericError,
          extra: catismaMesaji(catisan));
      return;
    }
    setState(() {
      _cat = ad;
      _catQuery = ad;
      _aramaCtl.text = ad;
    });
  }

  /// İLK ADIM MI? (cihazın geri tuşu ve ekrandaki ok bunu sorar)
  ///
  /// Kategori önceden seçilmişse 1. adım atlanır; o akışta ilk
  /// görünen adım 2'dir.
  bool get _ilkAdim => _step <= (_kategoriOnSecili ? 2 : 1);

  /// BİR ÖNCEKİ ADIMA DÖN — ekrandaki ok ile AYNI davranış.
  ///
  /// ⚠ CİHAZIN GERİ TUŞU DA BUNU ÇAĞIRIR. Eskiden çağırmıyordu:
  /// Android geri tuşu doğrudan rotayı kapatıyor, kullanıcı 3.
  /// adımdayken tüm ilan formundan çıkıyor ve girdiği veri
  /// kayboluyordu. Ekrandaki ok doğru çalışıyor, cihaz tuşu
  /// çalışmıyordu — iki geri yolu AYNI şeyi yapmalıdır.
  void _geriAdim() {
    if (_ilkAdim) {
      geriGit(context);
      return;
    }
    setState(() => _step--);
  }

  void _next() {
    if (_step == 1) {
      if (_cat == null) {
        sysToastErr(context, SysKind.genericError,
            extra: FormMesaj.ilanKategoriSec);
        return;
      }
      setState(() => _step = 2);
    } else if (_step == 2) {
      // ⚠ AYRI HATA METNİ YOK: yetersizlik alt satırın rengiyle ve
      // kırmızı çerçeveyle bildirilir; buton zaten pasiftir.
      setState(() => _locError = null);
      final ok = _kelimeSayisi() >= kMinAciklamaKelime;
      // ⚠ Konum bu adımda İSTENMEZ; kayıt akışında veya profil
      // adresinden gelir. Yayın anında yine de zorunludur.
      setState(() {});
      if (!ok) {
        return;
      }

      // Oturumsuzda 3 = kayıt formu, oturumluda 3 = önizleme.
      setState(() => _step = 3);
    } else if (_step == 3 && widget.preLogin) {
      // Kayıt formu — eksik/geçersizse ilerleme YOK, uyarılar açılır.
      if (!_kayit.tamam) {
        setState(() => _kayit.dokunulan.addAll(KayitVerisi.alanlar));
        return;
      }
      setState(() => _step = 4);
    } else if (_step == 4 && widget.preLogin) {
      if (!_otp.tamam) {
        return;
      }
      unawaited(_otpDogrulaVeKaydol());
    }
  }

  /// ── SMS KODU DOĞRULAMASI ──
  ///
  /// ⚠ GÜVENLİK AÇIĞI KAPATILDI.
  ///
  /// Bu adım eskiden yalnız "altı hane girildi mi" diye bakıyor, sonra
  /// doğrudan `register(otpVerified: true)` çağırıyordu. Kod HİÇBİR
  /// yerde denetlenmiyordu:
  ///   · mock/debug derlemede HERHANGİ bir altı haneli sayı hesap
  ///     açıyordu (`AuthRepository.register` istemcinin `otpVerified`
  ///     bayrağına güvenir),
  ///   · gerçek API modunda sunucu reddediyor ama kullanıcıya
  ///     "Kayıt tamamlanamadı" gibi ilgisiz bir hata gösteriliyordu.
  ///
  /// Artık kod, kayıt isteğinden ÖNCE doğrulanır. `OtpScreen` zaten bu
  /// yolu izliyordu; bu akış atlamıştı.
  Future<void> _otpDogrulaVeKaydol() async {
    if (_busy) {
      return;
    }
    setState(() {
      _otp.hata = null;
      _busy = true;
    });

    final telefon = Validators.phoneFmt(_kayit.telefon.text);

    // ⚠ SÖZLEŞME `otp_screen` İLE AYNI:
    //   · API modunda ayrı bir doğrulama ucu YOKTUR; kodu kayıt ucu
    //     doğrular. İstemci yalnız uzunluğu bakar, sonucu sunucudan
    //     bekler ve hatayı bu ekranda gösterir.
    //   · Mock modda yerel doğrulama çalışır ve YALNIZ debug
    //     derlemede geçer (`MockOtpService.verify` release'te her
    //     zaman false döner).
    final gecerli = ApiConfig.useRealApi
        ? _otp.kod.length == 6
        : await MockOtpService().verify(telefon, _otp.kod);

    if (!mounted) {
      return;
    }
    if (!gecerli) {
      setState(() {
        _busy = false;
        _otp.hata = 'Doğrulama kodu hatalı';
      });
      return;
    }
    setState(() => _busy = false);
    await _kaydolVeYayinla();
  }

  /// KAYIT ÖNCESİ: taslağı sakla ve müşteri kayıt akışına geç.
  ///
  /// ⚠ Bu noktada ilan YAYINLANMAZ ve hiçbir fotoğraf yüklenmez.
  Future<void> _taslakKaydetVeKayitaGec() async {
    // Aynı doğrulamalar geçerlidir: eksik ilanla kayıt akışına
    // gönderilmez.
    if (_cat == null) {
      sysToastErr(context, SysKind.genericError,
          extra: FormMesaj.ilanKategoriSec);
      return;
    }
    if (_kelimeSayisi() < kMinAciklamaKelime) {
      // Uyarı alt satırda ve çerçevede görünür.
      setState(() {});
      return;
    }
    // ⚠ KONUM BURADA ZORUNLU DEĞİL.
    //
    // Oturumsuz kullanıcı adresi KAYIT adımında girer; taslak boş
    // konumla saklanır ve yayın anında kayıt verisiyle tamamlanır.
    // Yayın öncesi zorunluluk `register_screen._yayinla` içinde
    // korunur — eksik konumla ilan YAYINLANMAZ.

    setState(() => _busy = true);
    final taslak = PendingListing(
      category: _cat!,
      subService: widget.initialSubService,
      description: _desc.text.trim(),
      city: _city ?? context.read<RegionController>().cityName ?? '',
      district: _district ?? '',
      neighborhood: _hood.text.trim(),
      // ⚠ Yalnız CİHAZ yolları; sunucu referansı YOK.
      localPhotoPaths:
          _photos.map((p) => p.localPath).toList(growable: false),
      createdAt: DateTime.now(),
    );
    await context.read<PendingListingController>().saveDraft(taslak);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    // Hizmet Alan kayıt akışı — rol seçim ekranı GÖSTERİLMEZ.
    // Hizmet Alan kayıt akışı — rol seçim ekranı GÖSTERİLMEZ.
    RoleSelectScreen.startRegister(context, Role.customer);
  }

  Future<void> _publish() async {
    if (_busy) {
      return;
    }

    // ── KAYIT ÖNCESİ DAL ──
    //
    // Oturum yok: ilan YAYINLANMAZ. Taslak kaydedilir ve Hizmet Alan
    // kayıt/doğrulama akışına geçilir. Yayın, kayıt tamamlandıktan
    // sonra `publishIfAny()` ile TEK SEFER yapılır.
    if (widget.preLogin) {
      await _taslakKaydetVeKayitaGec();
      return;
    }

    // FOTOĞRAF KURALI: yükleme bitmeden ilan kaydedilmez.
    if (_photosUploading) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Fotoğraflar yükleniyor — lütfen bekleyin');
      return;
    }
    if (_photosFailed) {
      sysToastErr(context, SysKind.photoUploadError,
          extra: 'Yüklenemeyen fotoğrafları kaldırın veya tekrar deneyin');
      return;
    }

    setState(() => _busy = true);
    final me = context.read<AuthController>().currentAccount!;
    // CALLBACK: watch DEĞİL read — build dışında reaktif okuma yapılmaz.
    final cityName = _city ?? context.read<RegionController>().cityName ?? '';
    // Yalnız SUNUCUDAN alınan referanslar gönderilir; yerel dosya yolu
    // hiçbir zaman ilan verisine yazılmaz.
    final refs = _photos
        .map((p) => p.storageRef)
        .whereType<String>()
        .toList(growable: false);

    // İlan sunucuda oluşana kadar başarı gösterilmez.
    final r = await context.read<ListingController>().publish(
        ownerId: me.id,
        title: _cat!,
        location: '${_hood.text.trim()}, $_district / $cityName',
        desc: _desc.text.trim(),
        photoPaths: refs);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (r.error != null) {
      sysToastErr(context, SysKind.genericError, extra: r.error!.message);
      return;
    }
    // ARTIK ORPHAN DEĞİL: ilana bağlandılar, iptal edilemezler.
    for (final p in _photos) {
      p.attached = true;
    }
    _published = true;

    // HTML vPost3: başarı ekranı gösterilir, ekrandan çıkılmaz.
    setState(() { _busy = false; _step = 4; });
  }

  // ═════════════════════════════════════════════════════════════
  // GÖRÜNÜM — referans `vPost()` → `vPost1/2/3`
  //
  //   .po-head    geri + .po-title (19px/700, ortalı) + .po-step
  //   postStepper(n)
  //   .po-divider height:1px #EEF0F3; margin:0 -16px 14px
  //   .po-foot    sabit alt şerit; .po-next (pasifken .dis #BBD0F3)
  //
  // ⚠ Referansta `AppBar` YOKTUR; başlık `.po-head` içindedir.
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // vPost3 tamamlandı ekranı: üst şerit ve alt buton ÇUBUĞU yoktur.
    // Yayın sonrası: oturumsuz akışta 5, oturumluda 4.
    if (_step == (widget.preLogin ? 5 : 4)) {
      return Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: RefScroll(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: _Adim3Tamam(
              preLogin: widget.preLogin,
              onListem: () =>
                  Navigator.pushReplacementNamed(context, '/customer/listings'),
            ),
          ),
        ),
      );
    }

    // ── ⚠ CİHAZIN GERİ TUŞU ADIMLAR ARASINDA GERİ GİDER ──
    //
    // `PopScope` olmadan Android geri tuşu rotayı KAPATIYORDU:
    // kullanıcı 3. adımdayken tuşa basınca ilan formu tamamen
    // kapanıyor, girilen kategori/açıklama kayboluyordu.
    //
    // `canPop: _ilkAdim` → yalnız İLK adımda rota kapanır; sonraki
    // adımlarda pop ENGELLENİR ve `_geriAdim` bir adım geri alır.
    // Ekrandaki ok da aynı metodu çağırır: iki geri yolu ayrışmaz.
    return PopScope(
      canPop: _ilkAdim,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _geriAdim();
        }
      },
      child: Scaffold(
      backgroundColor: RC.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefScroll(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // .po-head{gap:8px;margin-bottom:10px}
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          // ⚠ Cihazın geri tuşuyla AYNI yol (`_geriAdim`).
                          RefBackButton(onTap: _geriAdim),
                          const SizedBox(width: 8),
                          // .po-title{flex:1;center;19px/700;ls -.2}
                          Expanded(
                            child: Text(
                              'İlan Oluştur',
                              textAlign: TextAlign.center,
                              style: refText(
                                size: RF.s19,
                                weight: RF.w700,
                                color: RC.text,
                                letterSpacing: RF.lsM02,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // .po-step{#1D6BE3;14px/700}
                          Text(
                            widget.preLogin
                                ? 'Adım $_step/4'
                                : 'Adım $_step/3',
                            style: refText(
                                size: RF.s14, weight: RF.w700, color: RC.blue),
                          ),
                        ],
                      ),
                    ),

                    // Oturumsuz: 1 Kategori · 2 İlan Bilgileri · 3 Kayıt
                    //             4 SMS Doğrulama
                    // Oturumlu : 1 Kategori · 2 İlan Bilgileri · 3 Yayınla
                    RefStepper(
                        current: _step,
                        labels: widget.preLogin
                            ? const [
                                'Kategori Seç',
                                'İlan Bilgileri',
                                'Kayıt',
                                'SMS Doğrulama'
                              ]
                            : const [
                                'Kategori Seç',
                                'İlan Bilgileri',
                                'Önizle & Yayınla'
                              ]),

                    // .po-divider{height:1px;#EEF0F3;margin:0 -16px 14px}
                    //
                    // ⚠ `Container.margin` NEGATİF OLAMAZ:
                    // `margin.isNonNegative` assertion'ı ile çöker.
                    //
                    // Referanstaki `-16px` yatay margin, kapsayıcının
                    // 16px padding'ini aşıp ayracı TAM GENİŞLİK yapmak
                    // içindir. Aynı görünüm `OverflowBox` ile sağlanır:
                    // ayraç, kapsayıcıdan 2×16 = 32px daha geniş çizilir.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        height: 1,
                        child: LayoutBuilder(
                          builder: (_, kisit) => OverflowBox(
                            minWidth: kisit.maxWidth + 32,
                            maxWidth: kisit.maxWidth + 32,
                            child: const ColoredBox(color: RC.border2),
                          ),
                        ),
                      ),
                    ),

                    if (_step == 1) _adim1(context),
                    if (_step == 2) _adim2(context),
                    // Oturumsuzda 3 = kayıt, 4 = SMS; oturumluda 3 = önizle.
                    if (_step == 3 && widget.preLogin)
                      IlanKayitAdimi(
                          veri: _kayit, onDegisti: () => setState(() {})),
                    if (_step == 3 && !widget.preLogin) _adim3(context),
                    if (_step == 4 && widget.preLogin)
                      IlanOtpAdimi(
                          telefon: _kayit.telefon.text,
                          veri: _otp,
                          onDegisti: () => setState(() {})),
                  ],
                ),
              ),
            ),

            // .po-foot{padding:10px 16px calc(12px + safe-area);
            //          border-top:1px solid #F2F4F7}
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: RC.white,
                border: Border(top: BorderSide(color: RC.surface)),
              ),
              child: RefWideButton(
                _butonEtiketi(),
                busy: _busy,
                // .po-next.dis — eksik/geçersiz veriyle pasif.
                onPressed: ((_step == 1 && _cat == null) || _butonKilitli)
                    ? null
                    // Oturumsuz akışta yayın `_next` zincirinden yapılır.
                    : ((widget.preLogin || _step < 3) ? _next : _publish),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// `vPost1` — hizmet arama + kategori ızgarası.
  Widget _adim1(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .po-h2{18px/700;ls -.2}
          Text(
            'Hangi hizmete ihtiyacınız var?',
            style: refText(
              size: RF.s18,
              weight: RF.w700,
              color: RC.text,
              letterSpacing: RF.lsM02,
            ),
          ),
          // .po-sub{13px;#5B6472;margin-top:6px}
          const SizedBox(height: 6),
          Text(
            'İhtiyacınız olan hizmeti yazın, size uygun seçenekleri '
            'gösterelim.',
            style: refText(
                size: RF.s13, weight: RF.w400, color: RC.textSoft),
          ),

          // .po-search{border:1.7px solid #1D6BE3;radius:13px;
          //            padding:13px;margin-top:14px;gap:10px}
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: RC.white,
              border: Border.all(color: RC.blue, width: 1.7),
              borderRadius: BorderRadius.circular(RR.r13),
            ),
            child: Row(
              children: [
                const RefSvg('assets/svg/ic_search.svg',
                    size: 22, color: RC.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    // Odaklanınca alan klavyenin ve alt düğmenin ÜSTÜNE
                    // kaydırılır — bkz. `kAlanKaydirmaPayi`.
                    scrollPadding: const EdgeInsets.only(bottom: kAlanKaydirmaPayi),
                    controller: _aramaCtl,
                    onChanged: (v) => setState(() {
                      _catQuery = v;
                      // Yeni yazımda önceki seçim düşer.
                      _cat = null;
                    }),
                    style: refText(
                        size: RF.s145, weight: RF.w500, color: RC.text),
                    // ⚠ İKİNCİ ÇERÇEVE KÖK NEDENİ
                    //
                    // Global `inputDecorationTheme` durum border'ları
                    // (`enabledBorder`/`focusedBorder`) ve `filled`
                    // uygular. Yalnız `border:` vermek BUNU EZMEZ;
                    // dış kutunun içinde ikinci bir çerçeve çizilir.
                    //
                    // Tüm durum border'ları kapatılır, dolgu devre
                    // dışı bırakılır: görünen tek kutu dıştaki
                    // `Container`'dır.
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Hizmet veya kategori yazın '
                          '(örn. kombi, tesisat, temizlik...)',
                      hintStyle: refText(
                          size: RF.s145,
                          weight: RF.w500,
                          color: RC.greyLight),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── ARAMA ÖNERİLERİ (.po-results) ──
          //
          // Yazı varsa `Ana > Alt` kırılımlı liste; seçim yapılınca
          // kapanır. Referans `postResults()`.
          if (_catQuery.trim().isNotEmpty && _cat == null) ...[
            const SizedBox(height: 10),
            _OneriPaneli(
              sorgu: _catQuery,
              onSecim: (kategori, altHizmet) =>
                  _kategoriSec(altHizmet ?? kategori),
            ),
          ],

          // ── ⚠ KATEGORİ IZGARASI KALDIRILDI (15 Ağu, ürün kararı) ──
          //
          // İlan verme ekranında hizmet seçimi artık KARTLA değil,
          // ARAMA ile yapılır. Kullanıcı aradığı işi yazar, çıkan
          // gerçek hizmeti seçer.
          //
          // Gerekçe: katalog 640 hizmete çıktı. Fotoğraflı kart
          // ızgarası yalnız 54 KATEGORİYİ gösterebiliyordu; kullanıcı
          // "kolon hattı" ya da "sneaker tamiri" gibi bir işi
          // ızgarada BULAMIYOR, kategoriyi tahmin etmek zorunda
          // kalıyordu. Arama hepsini bulur.
          //
          // ⚠ Arama boşken ne gösterileceği AYRI BİR İŞ (popüler
          // hizmetler listesi); bu turda kapsam dışı.
          if (_catQuery.trim().isEmpty && _cat == null) ...[
            const SizedBox(height: 16),
            Text(
              'Aradığınız hizmeti yazın',
              style: refText(size: RF.s135, weight: RF.w400,
                  color: RC.textSoft),
            ),
          ],
        ],
      );

  /// `vPost2` — seçili hizmet, açıklama, fotoğraf.
  /// Açıklama yetersiz mi? (yazmaya başlandıysa uyarı gösterilir)
  ///
  /// ⚠ Boş alanda uyarı ÇIKMAZ; kullanıcı yazmaya başlayınca ve
  /// kelime sayısı eşiğin altındaysa satır kırmızıya döner.
  bool get _aciklamaEksik =>
      _desc.text.trim().isNotEmpty && _kelimeSayisi() < kMinAciklamaKelime;

  /// Açıklamadaki kelime sayısı (referans `.po-wc`).
  /// ⚠ `RegExp` build İÇİNDE kurulmaz — klavye açılış/kapanış
  /// animasyonunun her karesinde yeniden derleniyordu.
  static final RegExp _bosluk = RegExp(r'\s+');

  int _kelimeSayisi() => _desc.text
      .trim()
      .split(_bosluk)
      .where((w) => w.isNotEmpty)
      .length;


  Widget _adim2(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .po-selcard
          RefFormCard(
            marginTop: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Seçili Hizmet',
                    style: refText(
                        size: RF.s12, weight: RF.w400, color: RC.grey)),
                const SizedBox(height: 4),
                // ⚠ KARTTA YALNIZ SEÇİLEN HİZMET YAZAR.
                //
                // Altındaki "Ana > Alt" kırılımı KALDIRILDI: seçim
                // zaten tek satırda görünüyor, kırılım aynı adı ikinci
                // kez tekrar ediyordu (kategori seçildiğinde
                // "Doğalgaz / Doğalgaz" gibi).
                // ⚠ Kartta seçilen adın GÖRÜNEN hâli yazar; ızgaradaki
                // kısa adla aynı olsun diye `kategoriEtiketi` geçer.
                // Alt hizmet seçildiyse ad olduğu gibi kalır.
                // ⚠ KATEGORİ SATIRI — hizmet adı tek başına ayırt
                // etmiyor; kullanıcı ilanı OLUŞTURURKEN de hangi
                // alanda ilan verdiğini görmeli.
                if (kategoriAdi(_cat ?? '') != null)
                  Text(kategoriAdi(_cat ?? '')!,
                      style: refText(
                          size: RF.s115,
                          weight: RF.w500,
                          color: RC.textSoft,
                          letterSpacing: RF.lsM01)),
                Text(kategoriEtiketi(_cat ?? ''),
                    style: refText(
                        size: 16.5, weight: RF.w700, color: RC.text)),
              ],
            ),
          ),

          // .po-h3{16px/700;margin:16px 1px 3px} + .po-req
          Padding(
            padding: const EdgeInsets.fromLTRB(1, 16, 1, 3),
            child: Row(
              children: [
                Text('Açıklama',
                    style: refText(
                        size: RF.s16, weight: RF.w700, color: RC.text)),
                const SizedBox(width: 6),
                Text('(Zorunlu)',
                    style: refText(
                        size: RF.s125, weight: RF.w600, color: RC.danger)),
              ],
            ),
          ),
          Text('Hizmetinizle ilgili detayları yazın.',
              style: refText(
                  size: RF.s13, weight: RF.w400, color: RC.textSoft)),

          // .rv-tawrap + .rv-ta{min-height:150px;1.5px #E7EAEF;r13}
          const SizedBox(height: 8),
          // .rv-tawrap — sağ altta `.rv-cnt` karakter sayacı
          Stack(children: [
            RefTextField(
              controller: _desc,
              // ⚠ Kenarlık doğrudan alanın kendisinde renklenir;
              // dış sarmalayıcı YOK (çift çerçeve + odak kaybı).
              hatali: _aciklamaEksik,
              maxLines: 6,
              maxLength: kAciklamaMaxLength,
              // Yerleşik sayaç gizlenir; referanstaki `.rv-cnt`
              // kutunun İÇİNDE sağ altta yer alır.
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              onChanged: (_) => setState(() {}),
              // ⚠ Örnek metin KULLANILMAZ: kutuyu doldurup okunmayı
              // zorlaştırıyordu. Kısa ve yönlendirici ipucu yeterli.
              hint: 'Açıklama yazın.',
            ),
            Positioned(
              right: 14,
              bottom: 12,
              child: Text('${_desc.text.characters.length}/$kAciklamaMaxLength',
                  style: refText(
                      size: RF.s125, weight: RF.w400, color: RC.textSoft)),
            ),
          ]),

          // .po-min — TEK uyarı satırı.
          //
          // ⚠ AYRI KIRMIZI SATIR YOK: kelime sayısı yetersizse bu
          // satırın KENDİSİ kırmızıya döner ve açıklama çerçevesi de
          // kırmızı olur. İkinci bir hata metni gösterilmez.
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: refText(
                      size: RF.s125,
                      weight: RF.w400,
                      color: _aciklamaEksik ? RC.danger : RC.textSoft),
                  children: [
                    const TextSpan(text: 'En az '),
                    TextSpan(
                        text: '$kMinAciklamaKelime kelime',
                        style: refText(
                            size: RF.s125,
                            weight: RF.w700,
                            color: _aciklamaEksik ? RC.danger : RC.blue)),
                    const TextSpan(text: ' ile açıklayınız.'),
                  ],
                ),
              ),
              Text('${_kelimeSayisi()} kelime',
                  style: refText(
                      size: RF.s125,
                      weight: RF.w400,
                      color: _aciklamaEksik ? RC.danger : RC.textSoft)),
            ],
          ),

          // ⚠ KONUM ALANLARI BU ADIMDA GÖSTERİLMEZ.
          //
          // Referans adım 2 yalnız Açıklama + Fotoğraf içerir.
          // İlçe/mahalle bilgisi:
          //   • oturumsuz kullanıcıda KAYIT adımında toplanır,
          //   • oturumlu kullanıcıda PROFİL ADRESİNDEN alınır.
          // İş kuralı korunur: konum olmadan yayın YAPILMAZ
          // (bkz. `_yayinla` doğrulaması).
          if (_locError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_locError!,
                  style: refText(
                      size: RF.s125, weight: RF.w600, color: RC.danger)),
            ),

          // .po-h3 Fotoğraf (Opsiyonel)
          Padding(
            padding: const EdgeInsets.fromLTRB(1, 16, 1, 3),
            child: Row(
              children: [
                Text('Fotoğraf',
                    style: refText(
                        size: RF.s16, weight: RF.w700, color: RC.text)),
                const SizedBox(width: 6),
                Text('(Opsiyonel)',
                    style: refText(
                        size: RF.s125, weight: RF.w500, color: RC.textSoft)),
              ],
            ),
          ),
          ListingPhotoPicker(
            photos: _photos,
            storage: _storageApi,
            enabled: !_busy,
            // Referans `vPost2`: sade kutu, başlık/biçim satırı yok.
            sade: true,
            // ⚠ Kayıtsız kullanıcının yükleme yetkisi yoktur;
            // dosyalar yalnız cihazda tutulur (bkz. `preLogin`).
            uploadEnabled: !widget.preLogin,
            onChanged: (next) => setState(() {
              _photos
                ..clear()
                ..addAll(next);
            }),
          ),
          // .po-note
          const SizedBox(height: 9),
          Text(
            'İlanınızı daha iyi anlatmak için fotoğraf ekleyebilirsiniz. '
            '(Maks. 5 fotoğraf)',
            style: refText(
              size: RF.s12,
              weight: RF.w400,
              color: RC.textSoft,
              height: RF.lh145,
            ),
          ),

          // .po-freeband
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FC),
              borderRadius: BorderRadius.circular(RR.r13),
            ),
            child: Row(
              children: [
                // .po-gift{40×40;%50;#1D6BE3}
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: RC.blue, shape: BoxShape.circle),
                  child: const RefSvg('assets/svg/ic_gift.svg',
                      size: 22, color: RC.white),
                ),
                const SizedBox(width: 12), // gap:12px
                Expanded(
                  child: Text('İlan vermek ücretsizdir',
                      style: refText(
                          size: RF.s14, weight: RF.w600, color: RC.text)),
                ),
              ],
            ),
          ),
        ],
      );

  /// `vPost2` fotoğraf bölümü + önizleme (adım 3).
  Widget _adim3(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Önizle & Yayınla',
              style: refText(
                  size: 16.5, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 12),
          RefFormCard(
            marginTop: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠ KATEGORİ SATIRI — yayınlanacak ilan neye ait,
                // önizlemede de görünür.
                if (kategoriAdi(_cat ?? '') != null)
                  Text(kategoriAdi(_cat ?? '')!,
                      style: refText(
                          size: RF.s115,
                          weight: RF.w500,
                          color: RC.textSoft,
                          letterSpacing: RF.lsM01)),
                Text(kategoriEtiketi(_cat ?? ''),
                    style: refText(
                        size: RF.s16, weight: RF.w700, color: RC.text)),
                const SizedBox(height: 4),
                Text(
                  '${_hood.text.trim()}, $_district / '
                  '${context.watch<RegionController>().cityName ?? ''}',
                  style: refText(
                      size: RF.s125, weight: RF.w400, color: RC.textSoft),
                ),
                const Divider(height: 20, color: RC.border),
                // ⚠ ÖNİZLEME DE BİR İLAN SAYFASIDIR: kullanıcı burada
                // ilanının yayınlandığında nasıl görüneceğine bakar.
                // Detay ekranlarıyla AYNI standart uygulanır
                // (13,5 / w500 / RC.text / 1,55) — aksi hâlde önizleme
                // ile gerçek ilan farklı görünür.
                // Kilit: test/ilan_aciklama_tipografisi_test.dart
                Text(_desc.text.trim(),
                    style: refText(
                      size: RF.s135,
                      weight: RF.w500,
                      color: RC.text,
                      height: RF.lh155,
                    )),
              ],
            ),
          ),

          RefInfoBox(
            child: Text(
              'İlan vermek ücretsizdir ve sınırsızdır — size hiçbir ücret '
              'yansımaz. İlanınız 30 saat yayında kalır; bu sürede hizmet '
              'verenler teklif verebilir. Süre sonunda teklif seçilmezse '
              'ilan otomatik kapanır.',
              style: refText(
                size: RF.s135,
                weight: RF.w400,
                color: RC.textDark,
                height: RF.lh150,
              ),
            ),
          ),
        ],
      );

}

// ⚠ `_KategoriCipi` KALDIRILDI.
//
// Kategori seçimi ızgaraya geçince bu çip çağrılmaz oldu.

/// `vPost3` — yayın başarılı ekranı.
class _Adim3Tamam extends StatelessWidget {
  const _Adim3Tamam({
    required this.preLogin, required this.onListem});

  final bool preLogin;
  final VoidCallback onListem;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('İlan Oluştur',
              textAlign: TextAlign.center,
              style: refText(
                  size: RF.s19, weight: RF.w700, color: RC.text)),
          const SizedBox(height: 14),
          // ⚠ Yayın sonrası: üç adım da TAMAMLANMIŞ görünür ve son
          // etiket "Yayınlandı" olur (referans `postStepper(4)`).
          RefStepper(
              current: 9,
              labels: preLogin
                  ? const [
                      'Kategori Seç',
                      'İlan Bilgileri',
                      'Kayıt',
                      'Yayınlandı'
                    ]
                  : const ['Kategori Seç', 'İlan Bilgileri', 'Yayınlandı']),

          // .po-doneico{margin-top:26px}
          const SizedBox(height: 26),
          const Center(
            child: RefSvg('assets/svg/ic_checkcircle.svg', size: 76),
          ),
          const SizedBox(height: 18),
          // .rg-done-title{25px/700;lh1.25;margin:0 10px 12px}
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('İlanınız Yayında!',
                textAlign: TextAlign.center,
                style: refText(
                  size: RF.s25,
                  weight: RF.w700,
                  color: RC.text,
                  height: RF.lh125,
                )),
          ),
          const SizedBox(height: 12),
          // .rg-done-sub{15px;lh1.5;margin:0 16px 18px}
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('İlanınız hizmet sağlayıcılara gösterilmeye başlandı.',
                textAlign: TextAlign.center,
                style: refText(
                  size: RF.s15,
                  weight: RF.w400,
                  color: RC.textSoft,
                  height: RF.lh150,
                )),
          ),

          // .po-hr{70×1;#E1E5EC;margin:6px auto 16px}
          const SizedBox(height: 6),
          Center(
            child: Container(width: 70, height: 1, color: RC.borderAlt),
          ),
          const SizedBox(height: 16),

          // .po-bell
          const Center(
            child: RefSvg('assets/svg/ic_bell.svg', size: 26, color: RC.blue),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Teklif geldiğinde size anında bildirim göndereceğiz.',
                textAlign: TextAlign.center,
                style: refText(
                  size: RF.s15,
                  weight: RF.w400,
                  color: RC.textSoft,
                  height: RF.lh150,
                )),
          ),

          // .po-cta3{margin-top:26px}
          const SizedBox(height: 26),
          RefWideButton('Aktif İlanlarımı Gör', onPressed: onListem),

          // ⚠ "Ana Sayfaya Dön" BAĞLANTISI KALDIRILDI.
          //
          // İlan yayınlandıktan sonra kullanıcının yapacağı iş
          // ilanını izlemektir; ana sayfa oradan alt navigasyonla
          // zaten bir dokunuş uzakta. İkinci bir çıkış yolu sunmak
          // kararı böler ve asıl eylemi zayıflatır.
        ],
      );
}


// ⚠ `_KategoriKarti` KALDIRILDI.
//
// Kart artık `widgets/kategori_karti.dart` içinde ORTAK bileşendir;
// ana sayfa da aynısını kullanır. İki kopya ölçü olarak ayrışmıştı.

/// `.po-results` — arama önerileri.
///
/// ⚠ Kategori kırılımı GÖSTERİLMEZ: her satır kendi başına bir
/// hizmettir, kullanıcı hangi kategoriye bağlı olduğunu görmez.
class _OneriPaneli extends StatelessWidget {
  const _OneriPaneli({required this.sorgu, required this.onSecim});

  final String sorgu;

  /// (ana kategori, alt hizmet?) — kategori satırında alt hizmet null.
  final void Function(String kategori, String? altHizmet) onSecim;

  @override
  Widget build(BuildContext context) {
    // ── ⚠ ORTAK ARAMA SERVİSİ — KESİN KURAL ──
    //
    // Bu ekran KENDİ süzgecini yazıyordu ve yalnız KATALOG ADLARINA
    // bakıyordu. Sonuç: 1500 terimlik eş anlamlı sözlüğü ve alias
    // katmanı burada HİÇ çalışmıyordu.
    //
    // Somut kusur: kullanıcı "ocak" yazdığında "Sonuç bulunamadı"
    // görüyordu — oysa sözlükte "ocak bağlama", "ocak dönüşümü",
    // "ankastre ocak bağlantısı" terimleri Doğalgaz Tesisatı'na
    // bağlıydı. "doğa" çalışıyordu çünkü o katalogda geçen bir ad.
    //
    // ⚠ TÜM HİZMET/KATEGORİ ARAMALARI ORTAK SERVİSTEN GEÇER.
    // Skorlama da oradan gelir: tam eşleşme → baştan eşleşme → ad
    // içinde geçen → eş anlamlı. Yani "kolon hattı" yazıldığında adı
    // birebir eşleşen hizmet, "Doğalgaz Kolon Hattı" gibi geniş
    // adların ÜSTÜNDE çıkar.
    final sonuc = SearchService.services(sorgu.trim(), enFazla: 12);

    if (sonuc.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text('Sonuç bulunamadı',
            style: refText(
                size: RF.s135, weight: RF.w400, color: RC.textSoft)),
      );
    }

    // ⚠ Sınır ortak servise verildi (`enFazla: 12`) — kesme
    // SIRALAMADAN SONRA yapılır, güçlü eşleşme dışarı itilmez.
    final liste = sonuc;
    return Container(
      decoration: BoxDecoration(
        color: RC.white,
        border: Border.all(color: const Color(0xFFECEEF1)),
        borderRadius: BorderRadius.circular(RR.r13),
      ),
      child: Column(
        children: [
          for (var i = 0; i < liste.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: Color(0xFFF1F3F6)),
            RefTap(
              onTap: () =>
                  onSecim(liste[i].category, liste[i].subService),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── ⚠ HİZMET ADI — TEK SATIR ──
                        //
                        // "Ana > Alt" kırılımı KALDIRILDI. Kullanıcı
                        // hangi hizmetin hangi kategoriye bağlı
                        // olduğunu GÖRMEZ; her satır kendi başına bir
                        // hizmettir ve o hizmetle ilan açılır.
                        //
                        // ⚠ Kategori arka planda taşınmaya DEVAM
                        // EDER: çıkar çatışması, ilan eşleştirmesi,
                        // kategori fotoğrafı ve iletişim bedeli ona
                        // bağlıdır. Gizlenen yalnız GÖSTERİMDİR.
                        //
                        // ⚠ `label` alias adını gösterir (kullanıcı
                        // ne yazdıysa onu görür), seçime giden değer
                        // yine katalog kimliğidir.
                        Text(liste[i].label,
                            style: refText(
                                size: RF.s145,
                                weight: RF.w700,
                                color: RC.text)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


