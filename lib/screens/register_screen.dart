import 'dart:async';
import '../domain/form_mesajlari.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/sys_state.dart';
import '../core/telefon_bicimi.dart';
import '../core/eposta_oneri.dart';
import '../core/ad_bicimi.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';
import 'otp_screen.dart';
import 'profil_tamamlama_screen.dart' show profilKapisi;
import '../domain/failures.dart' show TelefonSahiplenmeError;
import '../ui/ref_widgets.dart';
import '../ui/ref_tokens.dart';
import '../ui/web_panel.dart';
import '../data/controllers/pending_listing_controller.dart';
import '../data/models/pending_listing.dart';
import '../data/controllers/listing_controller.dart';
import '../data/repositories/oturum_tercihi.dart';
import '../data/remote/api/storage_api.dart';
import '../data/remote/api_client.dart';
import 'widgets/photo_picker.dart';
import '../core/geri.dart';
import '../core/teshis.dart';
import '../data/remote/api_config.dart';
import '../core/platform/yerel_gorsel.dart';
import '../ui/kullanim_sozlesmesi_onayi.dart';
import '../ui/panel_rotasi.dart';
import '../ui/sosyal_giris_dugmeleri.dart';

/// Kayıt — iki rol için AYNI altı alan (4 Kas, kullanıcı kararı): ad,
/// soyad, telefon, e-posta, şifre, şifre tekrar + sözleşme onayı. SMS
/// kodu, adres ve (hizmet verende) kategori/bölge profil tamamlamada.
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
  // ── ⚠ 4 KAS (kullanıcı kararı): KAYIT FORMU YALNIZ 6 ALAN ──
  // Ad, soyad, telefon, e-posta, şifre, şifre tekrar. İl/ilçe/mahalle,
  // (hizmet verende) kategori + hizmet bölgeleri ve SMS doğrulaması
  // kayıttan ÇIKTI; işlemin gerektirdiği anda `ProfilTamamlamaScreen`de
  // istenir (hizmet alan: ilk Bul / İlan Oluştur; hizmet veren: panel).
  bool _agree = false;

  /// Aydınlatma Metni onayı — ZORUNLU (16 Eki, kullanıcı kararı).
  bool _aydinlatma = false;


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
  }


  /// KAYIT SONRASI BEKLEYEN İLAN YAYINI
  ///
  /// Ön koşullar (hepsi zorunlu):
  ///   • hesap Hizmet Alan (customer) rolünde,
  ///   • hizmet alan profili TAMAM (`Account.profilTamam`: telefon SMS
  ///     koduyla doğrulandı + adres). 4 Kas: kayıt formu bunları artık
  ///     almıyor; taslak varsa kayıttan hemen sonra tamamlama ekranı
  ///     açılır (ilan oluşturma aşaması), tamamlanınca yayınlanır.
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
    // ⚠ Profil TAMAMLANMADAN yayın YOK (sunucu da reddeder).
    if (acc == null ||
        !acc.roles.contains(Role.customer) ||
        !acc.profilTamam(Role.customer)) {
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
  /// Tamamlanmış profil adresiyle konum dizesi üretir (4 Kas: adres
  /// kayıt formunda değil, profil tamamlamada alınır).
  ///
  /// Eksikse `null` döner ve yayın yapılmaz.
  String? _kayitKonumu(Account? hesap) {
    final a = hesap?.address;
    if (a == null || !a.isComplete) {
      return null;
    }
    return a.display;
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
    final storage = StorageApi(c.read<ApiClient>());
    final listingCtl = c.read<ListingController>();
    final hesap = c.read<AuthController>().currentAccount;
    final refs = <String>[];
    try {
      for (final yol in fotograflar) {
        // ⚠ WEB'DE TÜR YOLDAN ÇÖZÜLEMEZ: burada elimizde yalnız
        // KAYITLI YOL var (`PendingListingStore`), `XFile` değil.
        // Web'de o yol bir `blob:` adresidir ve uzantısı yoktur.
        //
        // ⚠ TÜR UYDURULMAZ: bilinmeyen türe `image/jpeg` demek,
        // sunucuya yanlış `Content-Type` göndermek olurdu. Fotoğraf
        // atlanır ve kayıt akışı sürer — bugünkü davranış budur.
        //
        // ⚠ ASIL ÇÖZÜM SEÇİM ANINDA: `photo_picker` artık türü
        // `XFile.mimeType`ten okuyup `PhotoItem`e yazıyor. Bu akışın
        // da yol yerine tür taşıyan bir kayıt kullanması gerekir —
        // `PendingListingStore` sözleşmesi değişmeden yapılamaz, bu
        // yüzden RAPORLANDI.
        // ── ⚠ TÜR ÖNCE TASLAKTAN OKUNUR ──
        //
        // `PendingListing.localPhotoTypes`, seçim anında
        // `XFile.mimeType`ten okunan gerçek türü taşır. Web'de yol bir
        // `blob:` adresidir ve uzantısı yoktur; yoldan türetmek
        // ÇALIŞMAZ ve fotoğraflar sessizce atlanıyordu.
        //
        // ⚠ YOLA GERİ DÜŞÜLÜR: eski taslaklarda (tür listesi yok ya da
        // kısa) ve mobilde bugünkü davranış aynen sürer.
        //
        // ⚠ TÜR UYDURULMAZ: ikisi de çözemezse fotoğraf atlanır;
        // sunucuya yanlış `Content-Type` gönderilmez.
        final sira = fotograflar.indexOf(yol);
        final taslakTuru = (sira >= 0 && sira < p.localPhotoTypes.length)
            ? p.localPhotoTypes[sira]
            : null;
        final tip = taslakTuru ?? contentTypeOf(yol);
        if (tip == null) {
          continue; // tür çözülemedi — atlanır
        }
        final boyut = await yerelBoyut(yol);
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
        // ── ⚠ EKSİK ADIM TAMAMLANDI ──
        //
        // Referans alınıyor ama dosyanın baytları gönderilmiyordu.
        // Aşağıdaki `catch` kısmi yüklemeyi zaten temizliyor; artık
        // gerçekten yükleyemediğimizde de aynı temizlik çalışır.
        final uploadUrl = res['uploadUrl'] as String?;
        if (uploadUrl == null || uploadUrl.isEmpty) {
          throw StateError('uploadUrl alınamadı');
        }
        await storage.uploadBytes(
          uploadUrl: uploadUrl,
          bytes: await yerelBaytlar(yol),
          contentType: tip,
        );
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
        ? _kayitKonumu(hesap)
        : p.location;
    if (konum == null) {
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
          // ⚠ Taslakta taşınan seçim korunur.
          isZamani: p.isZamani,
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
  bool get _formTamam => _alanlarTamam && _agree && _aydinlatma;

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
    // 4 Kas: adres ve (hizmet verende) kategori/bölge kayıtta istenmez;
    // profil tamamlamada alınır (`ProfilTamamlamaScreen`).
    return true;
  }

  Future<void> _next() async {
    if (_busy) {
      return;
    }
    // ⚠ Gönderimde TÜM alanlar denetlenir; alanlar "terk edilmiş"
    // sayılır ki uyarı gönderimden sonra da doğru yerde kalsın —
    // ama odak kuralı geri açılır, uyarı asılı kalmaz.
    _terkEdilen.addAll(_siraliAlanlar);
    _gonderimAninda = true;
    final formOk = _form.currentState!.validate();
    _gonderimAninda = false;
    setState(() {});
    if (!formOk) {
      return;
    }
    if (!_agree || !_aydinlatma) {
      sysToastErr(context, SysKind.genericError,
          extra: 'Devam etmek için sözleşmeyi onaylayınız');
      return;
    }
    setState(() => _busy = true);
    final phone = Validators.phoneFmt(_phone.text);
    // ── ⚠ 4 KAS: KAYIT SMS KODU İSTEMEZ (kullanıcı kararı) ──
    //
    // Hesap hemen açılır; telefon doğrulanmamış kaydedilir. Telefon
    // doğrulaması ve adres (hizmet verende ayrıca kategori + bölge)
    // işlemin gerektirdiği anda `ProfilTamamlamaScreen`de istenir.
    // Kayıt ile telefon doğrulaması ön yüzde de arka uçta da AYRI.
    final r = await context.read<AuthController>().register(
        phone: phone,
        pass: _pass.text,
        role: widget.role,
        otpVerified: false,
        telefonDogrulamasiz: true,
        name: '${_first.text.trim()} ${_last.text.trim()}',
        // Kayda küçük harfe çevrilmiş biçim yazılır.
        email: epostaNormalize(_email.text),
        // Sözleşme onayı domain katmanına İLETİLİR:
        // yalnız UI kontrolüne güvenilmez.
        termsAccepted: _agree && _aydinlatma);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    // Numara doğrulanmamış başka bir hesapta: numara bu kişinin ise SMS
    // koduyla doğrulayarak kayda devam eder (bir numara, bir hesap).
    if (r.error is TelefonSahiplenmeError) {
      sysToastErr(context, SysKind.genericError, extra: r.error!.message);
      await _numarayiDogrulayarakKaydol(phone);
      return;
    }
    if (r.error != null && r.account == null) {
      sysToastErr(context, SysKind.genericError, extra: r.error!.message);
      return;
    }
    await _kayitTamam(context, phone);
  }

  /// Kayıt başarılı: cihaz hesabı hatırlar, kullanıcı DOĞRUDAN kendi ana
  /// sayfasına gider (4 Kas). Kayıttan önce oturumsuz hazırlanmış bir ilan
  /// taslağı varsa kullanıcı ilan oluşturma aşamasındadır: tamamlama ekranı
  /// hemen açılır, tamamlanınca taslak yayınlanır.
  Future<void> _kayitTamam(BuildContext c, String phone) async {
    // ── ⚠ CİHAZ BU HESABI HATIRLASIN ──
    // Giriş ekranındaki AYNI mekanizma (`OturumTercihi`); yeni kaydolan
    // kullanıcı için varsayılan "hatırla"dır.
    unawaited(OturumTercihi().kaydet(phone));
    // ⚠ Bağımlılıklar gezinmeden ÖNCE okunur: kayıt ekranı aşağıdaki
    // geçişle ağaçtan çıkar, sonrasında `c.read` kullanılamaz.
    final rol = c.read<AuthController>().activeRole;
    final taslakVar = c.read<PendingListingController>().hasDraft;
    final nav = Navigator.of(c);
    nav.pushNamedAndRemoveUntil(
      rol == Role.provider ? '/provider/jobs' : '/customer/listings',
      (r) => false,
    );
    if (rol == Role.customer && taslakVar) {
      await WidgetsBinding.instance.endOfFrame;
      final baglam = nav.context;
      if (!baglam.mounted) {
        return;
      }
      if (await profilKapisi(baglam, Role.customer) && baglam.mounted) {
        await _bekleyenIlaniYayinla(baglam);
      }
    }
  }

  /// NUMARAYI SAHİPLENME — numara doğrulanmamış bir hesapta kayıtlı.
  ///
  /// ⚠ EKRAN KODU DOĞRULAMAZ: kod use-case'te doğrulanır, başarıda kısa
  /// ömürlü KAYIT YETKİSİ döner ve kayıt isteğiyle sunucuya gider; sunucu
  /// numarayı doğrulanmamış hesaptan bu yeni hesaba geçirir.
  Future<void> _numarayiDogrulayarakKaydol(String phone) async {
    setState(() => _busy = true);
    var ch = await context
        .read<AuthController>()
        .kayitKodGonder(phone, taslakKimligi: _taslakKimligi);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    // ⚠ KOD GÖNDERİLEMEDİYSE DOĞRULAMA EKRANI AÇILMAZ (15 Eki).
    if (ch.challengeId.isEmpty) {
      sysToastErr(context, SysKind.genericError,
          extra: FormMesaj.otpGonderilemedi);
      return;
    }
    await Navigator.push(
      context,
      panelRotasi<void>(
        settings: const RouteSettings(name: '/dogrulama'),
        builder: (_) => OtpScreen(
          phone: phone,
          purpose: OtpPurpose.register,
          dogrula: (kod) async {
            final d = await context
                .read<AuthController>()
                .kayitDogrula(ch.challengeId, kod);
            _kayitYetkisi = d.yetki;
            return d.hata;
          },
          // ⚠ AKIŞA ÖZEL: yeni KAYIT challenge'ı üretilir (C7).
          yenidenGonder: () async {
            final yeni = await context
                .read<AuthController>()
                .kayitKodGonder(phone, taslakKimligi: _taslakKimligi);
            if (yeni.challengeId.isEmpty) {
              return FormMesaj.otpGonderilemedi;
            }
            ch = yeni;
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
                email: epostaNormalize(_email.text),
                termsAccepted: _agree && _aydinlatma);
            if (!otpContext.mounted) {
              return;
            }
            if (r.error != null && r.account == null) {
              ScaffoldMessenger.of(otpContext)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: HC.dark,
                    content: Text(r.error!.message, textAlign: TextAlign.center)));
              Navigator.pop(otpContext); // forma geri
              return;
            }
            await _kayitTamam(otpContext, phone);
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
    // ⚠ YILDIZ SOLDA — bkz. `refYerTutucu`/`RefFieldLabel`daki AYNI
    // düzeltme; uygulama genelinde TEK, TUTARLI konum.
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: gri, children: [
        TextSpan(
          text: '* ',
          style: refText(
              size: RF.s15, weight: RF.w700, color: RC.requiredStar),
        ),
        TextSpan(text: metin),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
                // ⚠ PANELDE ZEMİN SAYDAM: `Scaffold` beyaz boyadığı için
        // şeffaf rotanın altındaki sayfa ÖRTÜLÜYORDU — modalın arkası
        // boş beyaz görünüyordu. Panelde zemin saydam olur, karartma
        // ve bulanıklık altındaki gerçek sayfaya düşer.
        //
        // ⚠ MOBİLDE DEĞİŞMEZ: `panelMi` yalnız web'de true.
        backgroundColor:
            WebPanel.panelMi(context) ? Colors.transparent : RC.pageBg,
        // ⚠ TEŞHİS: bayrak kapalıyken `Stack` tek çocukla çizilir,
        // panel `SizedBox.shrink()` döner — davranış değişmez.
        body: WebPanel(
        // ⚠ MASAÜSTÜ WEB PANELİ — ortak bileşen
        // (`ui/web_panel.dart`). Mobilde ve <1024 px'te gövdeyi
        // OLDUĞU GİBİ döndürür; bu ekranın kendi Scaffold /
        // RefScroll / adım yapısı değişmedi.
        //
        // ⚠ GÖVDENİN TAMAMI SARILIR: çok adımlı akışlarda
        // yalnız ilk adım değil, tüm gövde panelin içindedir.
        icerik: Stack(children: [
          SafeArea(
          child: SingleChildScrollView(
            // ⚠ KLAVYE AÇIKKEN EK ALT BOŞLUK — "Devam Et" butonu
            // klavyenin altında kalıp elle kaydırmak gerektiriyordu.
            // Klavye açıkken içeriğin altına klavye yüksekliği kadar
            // EK boşluk eklenir; bu, bir alana odaklanınca Flutter'ın
            // KENDİ otomatik "görünür alana kaydır" davranışının
            // (`Scrollable.ensureVisible`, TextField odaklanınca
            // dahili olarak tetiklenir) butonu da görünür alana
            // çekebilmesi için YETERLİ kaydırma payı sağlar — riskli
            // bir Scaffold yeniden yapılandırması (`bottomNavigationBar`)
            // GEREKMEDEN.
            // ── ⚠ KLAVYE DOLGUSU AĞACIN TAMAMINDAN AYRILDI
            // (kullanıcı bulgusu, 9 Eyl) ──
            //
            // BULGU: "Zorunlu alanları doldurmaya başlayınca klavye
            // zor açılıp kapanıyor; alanlara hiç dokunmadan il-ilçe-
            // mahalle seçince sorun yok."
            //
            // AÇIKLAMASI: alanlara dokunulmazsa klavye HİÇ AÇILMAZ.
            // Dokunulduğunda ise il satırına basıldığı an iki
            // animasyon üst üste biner — klavye iniyor, panel
            // çıkıyor.
            //
            // ⚠ ÖLÇÜLEN KÖK NEDEN: `MediaQuery.viewInsetsOf` DOĞRUDAN
            // bu `build` metodunda okunuyordu. Bu değer klavye
            // animasyonunun HER KARESİNDE değişir, dolayısıyla 613
            // satırlık ağacın tamamı kare başına yeniden kuruluyordu.
            //
            // ⚠ ÇÖZÜM AĞACI KÜÇÜLTMEK DEĞİL, BAĞIMLILIĞI TAŞIMAK:
            // `MediaQuery` okuması `_KlavyeDolgusu` bileşenine indi.
            // Artık klavye kareleri YALNIZ o küçük bileşeni yeniden
            // çiziyor; `child` AYNI widget örneği olarak geçtiği için
            // Flutter altındaki ağacı YENİDEN KURMAZ, yalnız dolgu
            // değerini günceller.
            //
            // ⚠ DAVRANIŞ AYNI: dolgu formülü (`24 + klavye`)
            // değişmedi; "Devam Et" düğmesi klavye açıkken yine
            // görünür alana kaydırılabiliyor.
            child: _KlavyeDolgusu(
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
              // ⚠ DÜZELTİLDİ — `AutovalidateMode.always` her odak
              // değişiminde (her `setState(() {})` çağıran focus
              // listener tetiklendiğinde, ki bu TAM OLARAK bir alana
              // dokunup klavye açılırken olur) formun TÜM 6 alanını
              // yeniden doğruluyordu — klavye açılma animasyonuyla
              // AYNI ANDA. `onUserInteraction`a geçildi: kırmızı
              // uyarı METİNLERİNİN ne zaman göründüğü zaten `_kural()`
              // fonksiyonunun KENDİ mantığıyla (odak/terkEdilen
              // kontrolü) yönetiliyor — bu değişmedi. Buton aktifliği
              // (`_formGecerli`) de `Form.validate()`den TAMAMEN
              // BAĞIMSIZ, kendi `Validators.*` çağrılarını yapıyor —
              // o da etkilenmez.
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  // ⚠ E-postada baş harf büyütülmez.
                  textCapitalization: TextCapitalization.none,
                  decoration: _dec('E-posta *', 'assets/svg/ic_mail.svg'),
                  validator: (v) => _kural(_email, v, Validators.email),
                ),
                const SizedBox(height: 12),

                // ── 4 Kas: İl/İlçe/Mahalle ve (hizmet verende) kategori +
                // hizmet bölgeleri kayıt formundan çıktı; profil
                // tamamlamada istenir (`ProfilTamamlamaScreen`).
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
                // `.rg-agree` — KULLANIM SÖZLEŞMESİ ONAYI (tek kaynak:
                // `ui/kullanim_sozlesmesi_onayi.dart`). 16 Eki: ayrı 18 yaş
                // kutusu kaldırıldı — yaş koşulu sözleşmenin 4. maddesinde.
                ValueListenableBuilder<bool>(
                  valueListenable: _alanlarGecerli,
                  builder: (_, alanlarTamam, __) => KullanimSozlesmesiOnayi(
                  key: _sozlesmeKaydirKey,
                  // ⚠ Zorunlu alanlar bitmeden işaretlenemez.
                  enabled: alanlarTamam,
                  sozlesme: _agree,
                  aydinlatma: _aydinlatma,
                  // ⚠ `_tazele()` ZORUNLU.
                  //
                  // "Devam Et" düğmesi `_formGecerli` bildirimini
                  // dinler; `setState` o bildirimi GÜNCELLEMEZ. Bu
                  // çağrı olmadan sözleşme işaretlense bile düğme
                  // pasif kalıyordu — 2. adıma hiç geçilemiyordu.
                  onSozlesme: (v) {
                    setState(() => _agree = v);
                    _tazele();
                  },
                  onAydinlatma: (v) {
                    setState(() => _aydinlatma = v);
                    _tazele();
                  },
                  ),
                ),
                const SizedBox(height: 8),
                // ── ⚠ "DEVAM ET" — GERİ ESKİ KONUMUNA ALINDI ──
                //
                // ÖNCEKİ DENEME: bu buton `Scaffold.bottomNavigationBar`a
                // taşınmıştı — TEORİDE doğru (Flutter'ın kendi garantisi
                // klavye üstünde tutar) ama PRATİKTE ekranı BOZDU: form
                // içeriği hiç görünmeyip yalnız bu buton kalıyordu, HER
                // İKİ rolde de. Kesin neden GERÇEK CİHAZDA görülmeden
                // (Flutter SDK yok, çalıştıramıyorum) DOĞRULANAMADI —
                // riski analiz etmek yerine GARANTİ ÇALIŞAN eski yapıya
                // dönüldü. Klavye sorunu AŞAĞIDAKİ `padding` ile (bkz.
                // `SingleChildScrollView`) ÇÖZÜLDÜ — Scaffold yapısına
                // DOKUNMADAN.
                ValueListenableBuilder<bool>(
                  valueListenable: _formGecerli,
                  builder: (_, gecerli, __) => RefPrimaryButton('Devam Et',
                      busy: _busy, onPressed: gecerli ? _next : null),
                ),
                // 4 Kas: Google/Apple ile kayıt (tek kaynak bileşen). Rol bu
                // ekrandaki rol; hesap varsa o rol aynı hesaba eklenir.
                // Sonrası e-postalı kayıtla AYNI (`_kayitTamam`).
                SosyalGirisDugmeleri(
                  rol: widget.role,
                  aktif: !_busy,
                  tamam: (eposta) => _kayitTamam(context, eposta ?? ''),
                ),

              ]),
            ),
            ),
          ),
        ),
          const TeshisPaneli(),
        ])),

      );

}

/// ── ⚠ KLAVYE DOLGUSU — YALNIZ KENDİSİ YENİDEN ÇİZİLİR ──
///
/// KULLANICI BULGUSU (9 Eyl): "Zorunlu alanları doldurmaya
/// başladığımda klavye zor açılıp kapanıyor, kasmaya başlıyor. Ancak
/// il-ilçe-mahalle bilgilerini diğer bilgilere hiç dokunmadan
/// girdiğimde bu sorun yok."
///
/// AÇIKLAMASI: alanlara dokunulmazsa klavye HİÇ AÇILMAZ. Dokunulunca
/// il satırına basıldığı an iki animasyon üst üste biner — klavye
/// iniyor, seçim paneli çıkıyor.
///
/// ⚠ ÖLÇÜLEN KÖK NEDEN: `MediaQuery.viewInsetsOf` doğrudan kayıt
/// ekranının `build` metodunda okunuyordu. Bu değer klavye
/// animasyonunun HER KARESİNDE değişir; `MediaQuery`ye bağlanan
/// eleman da her karede yeniden çizilir. Bağlanan eleman 613 satırlık
/// formun TAMAMIYDI.
///
/// ⚠ ÇÖZÜM AĞACI KÜÇÜLTMEK DEĞİL, BAĞIMLILIĞI AŞAĞI TAŞIMAK:
/// `MediaQuery` okuması bu küçük bileşene indi. Klavye kareleri
/// artık yalnız BURAYI yeniden çiziyor. `child` dışarıdan AYNI widget
/// örneği olarak geldiği için Flutter altındaki ağacı YENİDEN KURMAZ
/// — yalnız dolgu değerini günceller.
///
/// ⚠ FORMÜL DEĞİŞMEDİ: `24 + klavye yüksekliği`. "Devam Et" düğmesi
/// klavye açıkken yine görünür alana kaydırılabiliyor.
///
/// ⚠ `const` OLAMAZ: `child` çalışma zamanında kurulur. Ama `child`ın
/// KİMLİĞİ korunduğu sürece kazanç aynıdır — önemli olan sabitlik
/// değil, örneğin değişmemesidir.
class _KlavyeDolgusu extends StatelessWidget {
  const _KlavyeDolgusu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: child,
      );
}
